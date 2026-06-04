# ============================================================
# Script      : Remediate-HideOneDrive-Explorer.ps1
# Auteur      : Soham KOPP
# Objectif    : Masquer OneDrive / OneDrive Entreprise dans l'Explorateur Windows
# Contexte    : SYSTEM via Intune Remediation
# Logs        : C:\ProgramData\Microsoft\IntuneManagementExtension\Logs
# Backup      : C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OneDriveExplorerBackup
#
# Notes :
# - Ne supprime pas les fichiers utilisateur
# - Ne désinstalle pas OneDrive
# - Masque les entrées Explorer : NameSpace + SyncRootManager + CLSID
# ============================================================

$ErrorActionPreference = "Stop"

$ScriptName = "REM-WIN-Hide-OneDrive-Explorer"
$LogDir     = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$BackupDir  = Join-Path $LogDir "OneDriveExplorerBackup"
$LogFile    = Join-Path $LogDir "$ScriptName-Remediate.log"

# Production : laisser $false.
# Si $true, explorer.exe sera redémarré pour appliquer visuellement immédiatement.
$RestartExplorerForPilot = $false

# Mot-clé générique. Ajouter le nom du tenant uniquement si l'entrée ne contient pas OneDrive.
$Keywords = @(
    "OneDrive"
)

# GUID standard OneDrive connu.
$KnownGuids = @(
    "{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
)

if (!(Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

if (!(Test-Path $BackupDir)) {
    New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $LogFile -Value $Line
}

function Test-KeywordMatch {
    param(
        [string[]]$Texts
    )

    foreach ($Text in $Texts) {
        if ([string]::IsNullOrWhiteSpace($Text)) {
            continue
        }

        foreach ($Keyword in $Keywords) {
            if ($Text -like "*$Keyword*") {
                return $true
            }
        }
    }

    return $false
}

function Get-LoadedUserSids {
    Get-ChildItem "Registry::HKEY_USERS" -ErrorAction SilentlyContinue |
    Where-Object {
        $_.PSChildName -match "^(S-1-5-21-|S-1-12-1-)" -and
        $_.PSChildName -notmatch "_Classes$"
    } |
    Select-Object -ExpandProperty PSChildName
}

function Set-ClsidHidden {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sid,

        [Parameter(Mandatory = $true)]
        [string]$Guid
    )

    $ClsidPath = "Registry::HKEY_USERS\$Sid\Software\Classes\CLSID\$Guid"

    if (!(Test-Path $ClsidPath)) {
        New-Item -Path $ClsidPath -Force | Out-Null
        Write-Log "Clé CLSID créée : $ClsidPath"
    }

    New-ItemProperty `
        -Path $ClsidPath `
        -Name "System.IsPinnedToNameSpaceTree" `
        -PropertyType DWord `
        -Value 0 `
        -Force | Out-Null

    Write-Log "CLSID masqué : SID=$Sid ; GUID=$Guid ; System.IsPinnedToNameSpaceTree=0"
}

function Backup-RegistryKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegPath,

        [Parameter(Mandatory = $true)]
        [string]$BackupFile
    )

    try {
        & reg.exe export $RegPath $BackupFile /y | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Sauvegarde créée : $BackupFile"
        }
        else {
            Write-Log "Sauvegarde échouée : $RegPath ; ExitCode=$LASTEXITCODE"
        }
    }
    catch {
        Write-Log "Sauvegarde impossible : $RegPath ; Erreur=$($_.Exception.Message)"
    }
}

try {
    Write-Log "==================== Début remédiation ===================="
    Write-Log "Contexte d'exécution : $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Log "SID courant : $([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)"

    $UserSids = Get-LoadedUserSids

    if (!$UserSids) {
        Write-Log "Aucun profil utilisateur chargé correspondant à S-1-5-21 ou S-1-12-1. Rien à corriger."
        Write-Output "Aucun profil utilisateur chargé"
        exit 0
    }

    foreach ($Sid in $UserSids) {

        Write-Log "Traitement du SID : $Sid"

        $SafeSid = $Sid -replace '[\\/:*?"<>|]', "_"

        $NameSpaceItems = @(
            @{
                PsPath  = "Registry::HKEY_USERS\$Sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace"
                RegPath = "HKU\$Sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace"
                Name    = "DesktopNameSpace"
            },
            @{
                PsPath  = "Registry::HKEY_USERS\$Sid\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace"
                RegPath = "HKU\$Sid\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace"
                Name    = "MyComputerNameSpace"
            }
        )

        $SyncRootPsPath  = "Registry::HKEY_USERS\$Sid\Software\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager"
        $SyncRootRegPath = "HKU\$Sid\Software\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager"

        # 1. Sauvegardes avant modification.
        foreach ($Item in $NameSpaceItems) {
            if (Test-Path $Item.PsPath) {
                $BackupFile = Join-Path $BackupDir "$SafeSid-$($Item.Name).reg"
                Backup-RegistryKey -RegPath $Item.RegPath -BackupFile $BackupFile
            }
            else {
                Write-Log "Sauvegarde ignorée, chemin absent : $($Item.PsPath)"
            }
        }

        if (Test-Path $SyncRootPsPath) {
            $BackupFile = Join-Path $BackupDir "$SafeSid-SyncRootManager.reg"
            Backup-RegistryKey -RegPath $SyncRootRegPath -BackupFile $BackupFile
        }
        else {
            Write-Log "Sauvegarde SyncRoot ignorée, chemin absent : $SyncRootPsPath"
        }

        # 2. Masquer les GUID OneDrive connus.
        foreach ($Guid in $KnownGuids) {
            Set-ClsidHidden -Sid $Sid -Guid $Guid
        }

        # 3. Supprimer les entrées OneDrive dans Desktop\NameSpace / MyComputer\NameSpace.
        foreach ($Item in $NameSpaceItems) {

            if (!(Test-Path $Item.PsPath)) {
                Write-Log "Chemin absent : $($Item.PsPath)"
                continue
            }

            $Entries = Get-ChildItem -Path $Item.PsPath -ErrorAction SilentlyContinue

            foreach ($Entry in $Entries) {

                $Key = Get-Item -Path $Entry.PSPath -ErrorAction SilentlyContinue
                $DefaultValue = $Key.GetValue("")

                $IsKnownGuid = $KnownGuids -contains $Entry.PSChildName
                $IsKeywordMatch = Test-KeywordMatch -Texts @(
                    $Entry.PSChildName,
                    $DefaultValue
                )

                if ($IsKnownGuid -or $IsKeywordMatch) {

                    $DynamicGuid = $Entry.PSChildName

                    Write-Log "Entrée OneDrive NameSpace détectée : SID=$Sid ; Type=$($Item.Name) ; GUID=$DynamicGuid ; Name=$DefaultValue"

                    Set-ClsidHidden -Sid $Sid -Guid $DynamicGuid

                    Remove-Item -Path $Entry.PSPath -Recurse -Force
                    Write-Log "Entrée NameSpace supprimée : $($Entry.PSPath)"
                }
            }
        }

        # 4. Supprimer les entrées OneDrive dans SyncRootManager.
        if (Test-Path $SyncRootPsPath) {

            $SyncRootEntries = Get-ChildItem -Path $SyncRootPsPath -ErrorAction SilentlyContinue

            foreach ($Entry in $SyncRootEntries) {

                $Props = Get-ItemProperty -Path $Entry.PSPath -ErrorAction SilentlyContinue

                $IsKeywordMatch = Test-KeywordMatch -Texts @(
                    $Entry.PSChildName,
                    $Props.DisplayNameResource,
                    $Props.UserSyncRoot,
                    $Props.IconResource,
                    $Props.ProviderID
                )

                if ($IsKeywordMatch) {
                    Write-Log "Suppression SyncRootManager : SID=$Sid ; Entry=$($Entry.PSChildName) ; UserSyncRoot=$($Props.UserSyncRoot)"
                    Remove-Item -Path $Entry.PSPath -Recurse -Force
                }
            }
        }
        else {
            Write-Log "SyncRootManager absent pour SID=$Sid"
        }
    }

    if ($RestartExplorerForPilot -eq $true) {
        Write-Log "Redémarrage Explorer activé pour pilote"

        Get-Process explorer -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2

        Write-Log "Explorer arrêté. Il sera relancé automatiquement ou à la prochaine session utilisateur."
    }
    else {
        Write-Log "Redémarrage Explorer désactivé. Effet visible après relance Explorer, reconnexion ou redémarrage."
    }

    Write-Output "Remédiation terminée avec succès"
    Write-Log "Résultat final : REMÉDIATION OK"
    exit 0
}
catch {
    Write-Output "Erreur remédiation : $($_.Exception.Message)"
    Write-Log "ERREUR : $($_.Exception.Message)"
    exit 1
}
