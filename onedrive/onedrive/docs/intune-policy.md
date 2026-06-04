## Complementary Intune policy

This remediation can be combined with a Microsoft Intune configuration profile to hide OneDrive, SharePoint Online and OneDrive for Business locations from Microsoft Office, and to disable OneDrive file synchronization on Windows endpoints.

Recommended complementary settings:

| Category | Setting | Value | Purpose |
|---|---|---|---|
| Microsoft Office 2016 > Miscellaneous | Hide file locations when opening or saving files (User) | Enabled | Hides OneDrive Personal, SharePoint Online and OneDrive for Business from Office open/save locations |
| System | Disable OneDrive File Sync | Sync disabled | Disables OneDrive file synchronization on the endpoint |

This configuration profile complements the remediation script.

The script hides OneDrive from Windows File Explorer, while the Intune configuration profile reduces OneDrive visibility and usage from Microsoft Office and the OneDrive sync engine.

See `docs/intune-policy.md` for details.
