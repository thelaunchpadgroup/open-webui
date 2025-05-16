# OneDrive Organizations-Only Integration

This folder contains customizations to simplify the OneDrive integration to only use organizational (work/school) accounts, removing the personal account option for enterprise deployments.

## Purpose

For corporate deployments, we want to:
1. Simplify the user experience by removing the choice between personal and work OneDrive accounts
2. Ensure users only connect to corporate SharePoint/OneDrive resources
3. Avoid confusion when users attempt to connect personal accounts in a corporate environment

## Customizations

### 1. OneDrive File Picker Patch (`onedrive-file-picker.ts.patch`)

Modifies the default OneDrive file picker to always use 'organizations' as the authority type by default:

```diff
-private currentAuthorityType: 'personal' | 'organizations' = 'personal';
+// TechnologyMatch customization: Always default to organizations
+private currentAuthorityType: 'personal' | 'organizations' = 'organizations';
```

This single-line change ensures that:
- The Microsoft Authentication Library (MSAL) always uses the organizational endpoints
- Auth redirects go to the correct Azure Active Directory tenant
- SharePoint/OneDrive for Business APIs are used instead of personal OneDrive APIs

### 2. Simplified Input Menu (`InputMenu.svelte`)

Replaces the dropdown submenu for OneDrive with a single option for "Microsoft OneDrive" that directly uses the organizations account type:

- Removes the submenu structure that offered a choice between personal and work accounts
- Shows a single "Microsoft OneDrive" option with "SharePoint" as the subtitle
- Calls the `uploadOneDriveHandler` with 'organizations' parameter directly

## Implementation

These customizations are applied during the Docker build process:
1. The `InputMenu.svelte` file is directly copied to replace the original
2. The patch is applied to modify the OneDrive file picker authority type

## Configuration Requirements

To use this customization, you need to configure the following environment variables:
- `ENABLE_ONEDRIVE_INTEGRATION=True`
- `ONEDRIVE_CLIENT_ID` - Azure app registration client ID
- `ONEDRIVE_SHAREPOINT_URL` - Your SharePoint URL (e.g., https://mycompany.sharepoint.com)
- `ONEDRIVE_SHAREPOINT_TENANT_ID` - Your Azure tenant ID
- `MICROSOFT_CLIENT_ID` - Same as ONEDRIVE_CLIENT_ID
- `MICROSOFT_CLIENT_SECRET` - Azure app registration client secret
- `MICROSOFT_CLIENT_TENANT_ID` - Same as ONEDRIVE_SHAREPOINT_TENANT_ID
- `MICROSOFT_REDIRECT_URI` - OAuth callback URL (https://your-domain/oauth/microsoft/callback)

## Azure App Registration Requirements

The Azure app registration must have:
1. Web platform authentication enabled
2. Redirect URI set to `https://your-domain/oauth/microsoft/callback`
3. Microsoft Graph API permissions:
   - Files.Read.All
   - Sites.Read.All
   - User.Read

See the Microsoft setup documentation in `technologymatch/docs/microsoft-setup.md` for more details.