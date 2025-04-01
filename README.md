# PoswerShell-snapshot

## Description
PoswerShell-snapshot est un script PowerShell permettant d'automatiser la création de snapshots de bases de données et la mise à jour des sources de données associées.


## Fonctionnalités
- 📌 **Création automatique d'un snapshot** avec un nom unique
- ✅ **Vérification de l'existence de la base** avant toute opération
- 🔄 **Mise à jour dynamique des sources de données**
- ⚠️ **Gestion des erreurs** avec plusieurs tentatives en cas d'échec

  ## Prérequis
- PowerShell 5.1 ou version supérieure
- Module `SqlServer` installé (`Install-Module -Name SqlServer` si nécessaire)

## Utilisation
Exécutez le script en passant les paramètres requis :
```powershell
.\snapshot_modifRSdatasource.ps1 -PBIRSServerName "monServeur" -DataSourcePath "/Data Sources/dsExample" -NomBase "MaBase" -MaxRetryCount 5 -DelayBetweenRetries 30
```
### Paramètres
| Paramètre             | Description                                  |
|----------------------|----------------------------------------------|
| `PBIRSServerName`    | Nom du serveur Power BI Report Server       |
| `DataSourcePath`     | Chemin de la source de données à modifier   |
| `NomBase`           | Nom de la base de données concernée         |
| `MaxRetryCount`      | Nombre maximal de tentatives en cas d'erreur |
| `DelayBetweenRetries`| Temps d'attente entre chaque tentative (s)  |
