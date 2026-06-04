# Complementary Intune policy

## Objective

This Intune configuration profile complements the OneDrive remediation scripts.

The objective is to reduce OneDrive visibility and usage on Windows endpoints managed by Microsoft Intune.

## Recommended profile

| Setting | Value |
|---|---|
| Profile type | Settings catalog or Administrative Templates |
| Platform | Windows |
| Assignment | Device pilot group first |
| Scope | Windows endpoints where OneDrive must be hidden or disabled |

## Configuration settings

### Microsoft Office 2016

| Setting | Value |
|---|---|
| Category | Microsoft Office 2016 > Miscellaneous |
| Policy | Hide file locations when opening or saving files (User) |
| Value | Enabled |

### Effect

This setting hides cloud file locations when users open or save files from Microsoft Office applications.

It targets:

- OneDrive Personal
- SharePoint Online
- OneDrive for Business

## System

| Setting | Value |
|---|---|
| Category | System |
| Policy | Disable OneDrive File Sync |
| Value | Sync disabled |

### Effect

This setting disables OneDrive file synchronization on the Windows endpoint.

## Script and policy behavior

| Component | Purpose |
|---|---|
| Detection script | Checks whether OneDrive Explorer visibility is correctly configured |
| Remediation script | Applies registry configuration to hide OneDrive from File Explorer |
| Intune policy | Hides Office cloud locations and disables OneDrive file sync |

## Important notes

This policy does not uninstall OneDrive.

It reduces OneDrive visibility and disables synchronization, but access to OneDrive from the web may still be possible unless controlled separately.

## Risks

Potential impacts:

- Users may no longer see OneDrive or SharePoint Online locations in Office
- OneDrive synchronization will be disabled
- Teams or SharePoint workflows may be impacted if users rely on synced libraries
- Existing Microsoft 365 user habits may be affected

## Recommended rollout

1. Deploy to a pilot device group.
2. Validate File Explorer behavior.
3. Validate Office open and save locations.
4. Validate Teams and SharePoint workflows.
5. Monitor Intune deployment status.
6. Expand progressively.

## Rollback

To roll back:

1. Disable or remove the Intune configuration profile.
2. Revert the remediation script settings.
3. Restart Windows Explorer.
4. Reboot the device if required.
5. Validate OneDrive visibility and synchronization behavior.
