# ============================================================
# Script      : Detect-HideOneDrive-Explorer.ps1
# Auteur      : Soham Kopp
# Objectif    : Détecter les entrées OneDrive visibles dans l'Explorateur Windows
# Contexte    : SYSTEM via Intune Remediation
# Logs        : C:\ProgramData\Microsoft\IntuneManagementExtension\Logs
#
# Exit 0      : Conforme, pas de remédiation
# Exit 1      : Non conforme, remédiation requise
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

$ScriptName = "REM-WIN-Hide-OneDrive-Explorer"
$LogDir     = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile    = Join-Path $LogDir "$ScriptName-Detect.log"

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

Write-Log "==================== Début détection ===================="
Write-Log "Contexte d'exécution : $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Log "SID courant : $([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)"

$UserSids = Get-LoadedUserSids

if (!$UserSids) {
    Write-Log "Aucun profil utilisateur chargé correspondant à S-1-5-21 ou S-1-12-1."
    Write-Output "Aucun profil utilisateur chargé"
    exit 0
}

$NonCompliant = $false

foreach ($Sid in $UserSids) {

    Write-Log "Analyse du SID : $Sid"

    $NameSpacePaths = @(
        "Registry::HKEY_USERS\$Sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace",
        "Registry::HKEY_USERS\$Sid\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace"
    )

    $SyncRootPath = "Registry::HKEY_USERS\$Sid\Software\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager"

    foreach ($NameSpacePath in $NameSpacePaths) {

        if (!(Test-Path $NameSpacePath)) {
            Write-Log "Chemin absent : $NameSpacePath"
            continue
        }

        $Entries = Get-ChildItem -Path $NameSpacePath -ErrorAction SilentlyContinue

        foreach ($Entry in $Entries) {

            $Key = Get-Item -Path $Entry.PSPath -ErrorAction SilentlyContinue
            $DefaultValue = $Key.GetValue("")

            $IsKnownGuid = $KnownGuids -contains $Entry.PSChildName
            $IsKeywordMatch = Test-KeywordMatch -Texts @(
                $Entry.PSChildName,
                $DefaultValue
            )

            if ($IsKnownGuid -or $IsKeywordMatch) {
                Write-Log "Non conforme NameSpace : SID=$Sid ; Path=$NameSpacePath ; Entry=$($Entry.PSChildName) ; Name=$DefaultValue"
                $NonCompliant = $true
            }
        }
    }

    if (Test-Path $SyncRootPath) {

        $SyncRootEntries = Get-ChildItem -Path $SyncRootPath -ErrorAction SilentlyContinue

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
                Write-Log "Non conforme SyncRootManager : SID=$Sid ; Entry=$($Entry.PSChildName) ; UserSyncRoot=$($Props.UserSyncRoot)"
                $NonCompliant = $true
            }
        }
    }
    else {
        Write-Log "SyncRootManager absent pour SID=$Sid"
    }

    foreach ($Guid in $KnownGuids) {

        $ClsidPath = "Registry::HKEY_USERS\$Sid\Software\Classes\CLSID\$Guid"
        $ValueName = "System.IsPinnedToNameSpaceTree"

        if (Test-Path $ClsidPath) {
            $PinnedValue = Get-ItemPropertyValue -Path $ClsidPath -Name $ValueName -ErrorAction SilentlyContinue

            if ($PinnedValue -ne 0) {
                Write-Log "Non conforme CLSID : SID=$Sid ; GUID=$Guid ; $ValueName=$PinnedValue"
                $NonCompliant = $true
            }
        }
    }
}

if ($NonCompliant) {
    Write-Output "Non conforme : OneDrive détecté dans l'Explorateur"
    Write-Log "Résultat final : NON CONFORME"
    exit 1
}
else {
    Write-Output "Conforme : aucune entrée OneDrive détectée dans l'Explorateur"
    Write-Log "Résultat final : CONFORME"
    exit 0
}
