# OneDrive - Hide Explorer Locations

## Overview

This Intune remediation hides OneDrive locations from Windows File Explorer.

The goal is not to uninstall OneDrive, but to reduce its visibility in environments where OneDrive is not used or not authorized.

## Scripts

| Type | Path |
|---|---|
| Detection | `detection/Detect-HideOneDrive-Explorer.ps1` |
| Remediation | `remediation/Remediate-HideOneDrive-Explorer.ps1` |

## Deployment method

Use Microsoft Intune Remediations:

```text
Intune admin center
> Devices
> Remediations
> Create script package
