# ***************************************************************************************************************
# Nom du script         : snapshot_datasource.ps1
# Auteur                : Rim CHATTI
# Date                  : 01/04/2025
# Objet                 : Script de création et mise à jour d'un snapshot pour une source de données
# Paramètres d'entrée   : Nom du serveur, chemin de la DataSource, base cible, nombre de tentatives, délai entre tentatives
# Paramètres de sortie  : Aucun
# ***************************************************************************************************************
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$ServerName, # Nom du serveur
    [Parameter(Mandatory = $true)] [string]$DataSourcePath,  # Chemin de la Data Source
    [Parameter(Mandatory = $true)] [string]$DatabaseName,  # Nom de la base
    [Parameter(Mandatory = $true)] [int]$MaxRetryCount,  # Nombre maximal de tentatives
    [Parameter(Mandatory = $true)] [int]$DelayBetweenRetries # Délai entre tentatives
)
 
$global:ErrorActionPreference = 'Stop'
 
######## Étape 1 : Génération d'un nom unique pour le snapshot ########
function Generate-SnapshotName {
    $prefix = "$DatabaseName`_Snapshot"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    return "$prefix`_$timestamp"
}
 
$fullUrl = "http://$ServerName/Reports/api/v2.0/DataSources"
$AdminDatabase = 'AdminDB'
 
######## Étape 2 : Récupération de la DataSource ########
function Fetch-DataSource {
    try {
        Write-Host "Récupération de la DataSource depuis : $fullUrl"
        $response = Invoke-RestMethod -Uri $fullUrl -UseDefaultCredentials
        $dataSource = $response.value | Where-Object { $_.Path -eq $DataSourcePath }
        if (-not $dataSource) {
            throw "DataSource non trouvée: $DataSourcePath"
        }
        Write-Host "DataSource trouvée : $($dataSource.Name)"
        return $dataSource
    }
    catch {
        Write-Host "Erreur lors de la récupération de la DataSource : $($_.Exception.Message)"
        throw
    }
}
 
######## Étape 3 : Création du snapshot ########
function Create-Snapshot {
    try {
        $dataSource = Fetch-DataSource
        
        if ($dataSource.ConnectionString -match "Data Source=([^;]+)") {
            $ServerInstance = $matches[1]
        } else {
            throw "Impossible de récupérer le serveur depuis la connexion."
        }
        
        # Vérifier si la base de données existe
        $dbExist = Invoke-Sqlcmd -Query "
            SELECT COUNT(*) FROM sys.databases WHERE name = '$DatabaseName'
        " -ServerInstance "$ServerInstance" -Database "master" -Encrypt Optional
       
        if ($dbExist -eq 0) {
            throw "Erreur : la base de données '$DatabaseName' n'existe pas sur le serveur '$ServerInstance'"
        }
       
        $SnapshotName = Generate-SnapshotName
        Write-Host "Déclenchement de la création du snapshot"
        Invoke-Sqlcmd -Query "
            EXEC admin.CreateSnapshot
                @DatabaseName = '$DatabaseName',
                @SnapshotName = '$SnapshotName'
        " -ServerInstance "$ServerInstance" -Database "$AdminDatabase" -Encrypt Optional
       
        return $SnapshotName
    }
    catch {
        Write-Host "Erreur SQL : $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}
 
######## Étape 4 : Mise à jour du DataSource ########
function Update-Snapshot {
    $snapshotName = Create-Snapshot
    Write-Host "Nom du snapshot : $snapshotName"
   
    $dataSource = Fetch-DataSource
    $newConnectionString = $dataSource.ConnectionString -replace 'Initial Catalog=[^;]*', "Initial Catalog=$snapshotName"
   
    $update = @{
        Id               = $dataSource.Id
        Name             = $dataSource.Name
        ConnectionString = $newConnectionString
    } | ConvertTo-Json
   
    Write-Host "Mise à jour de la Data Source..."
    Invoke-RestMethod -Method PATCH -Uri "$fullUrl/$($dataSource.Id)" `
        -Body $update `
        -ContentType "application/json" `
        -UseDefaultCredentials
   
    Write-Host "Data source modifiée: $newConnectionString"
}
 
####### Exécution avec gestion des tentatives #######
$NbRetry = 0
while ($NbRetry -lt $MaxRetryCount) {
    try {
        Write-Host "Tentative $($NbRetry + 1) de mise à jour de la Data Source..."
        Update-Snapshot
        Write-Host "Mise à jour réussie."
        break
    }
    catch {
        Write-Host "Erreur lors de la mise à jour de la Data Source : $($_.Exception.Message)"
        Start-Sleep -Seconds $DelayBetweenRetries
        $NbRetry++
    }
}
 
Write-Host "Script terminé avec succès." -ForegroundColor Green
