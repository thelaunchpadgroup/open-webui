# Setting Up Microsoft 365 Authentication and OneDrive Integration

This guide explains how to configure Microsoft 365 authentication and OneDrive integration with Open WebUI.

## Table of Contents
- [Setting Up Microsoft 365 Authentication and OneDrive Integration](#setting-up-microsoft-365-authentication-and-onedrive-integration)
  - [Table of Contents](#table-of-contents)
  - [Registering an Application in Microsoft Entra ID](#registering-an-application-in-microsoft-entra-id)
  - [Configuring Authentication](#configuring-authentication)
  - [Setting Up API Permissions](#setting-up-api-permissions)
  - [Finding Required Configuration Values](#finding-required-configuration-values)
  - [Configuring Open WebUI](#configuring-open-webui)
  - [Testing the Integration](#testing-the-integration)
  - [Troubleshooting](#troubleshooting)

## Registering an Application in Microsoft Entra ID

1. **Sign in to the Microsoft Entra Admin Center**:
   - Go to [https://entra.microsoft.com](https://entra.microsoft.com)
   - Sign in with your Microsoft 365 administrator account

2. **Navigate to App Registrations**:
   - In the left sidebar, scroll down to "Applications"
   - Click on "App registrations"
   - If you don't see it, use the search bar at the top and search for "App registrations"

3. **Register a New Application**:
   - Click on "+ New registration" at the top
   - Enter a name for your application (e.g., "TechGPT")
   - Under "Supported account types", select one of these options:
     - "Accounts in this organizational directory only" (for internal use only)
     - "Accounts in any organizational directory" (for multi-tenant use)
     - "Accounts in any organizational directory and personal Microsoft accounts" (for both organizational and personal accounts)
   - Add a redirect URI:
     - Platform: Web
     - URL: `https://your-openwebui-domain/oauth/microsoft/callback`
     - Replace `your-openwebui-domain` with your actual domain
   - Click "Register"

## Configuring Authentication

1. **Navigate to Authentication**:
   - After creating the app, click on "Authentication" in the left menu
   - Verify the redirect URI is correctly configured
   - Under "Implicit grant and hybrid flows", check:
     - "ID tokens (used for implicit and hybrid flows)"
   - Under "Advanced settings", set "Allow public client flows" to "Yes"
   - Click "Save"

2. **Configure Token Configuration (Optional)**:
   - Click on "Token configuration" in the left menu
   - This section allows you to include additional user information in the authentication tokens
   - For most Open WebUI implementations, the default token configuration is sufficient
   - If needed, you can add optional claims like:
     - "email" (to ensure email address is always included in the token)
     - "name" (to include the user's display name)
     - "preferred_username" (to include the user's username)
   - These optional claims can be useful if you're experiencing issues with user information not being properly populated in Open WebUI

## Setting Up API Permissions

1. **Navigate to API Permissions**:
   - Click on "API permissions" in the left menu
   - Click "Add permissions"
   - Select "Microsoft Graph"
   - Choose "Delegated permissions"
   - Add the following permissions:
     - `email`
     - `offline_access`
     - `openid`
     - `profile`
     - `User.Read`
     - For OneDrive integration, also add:
       - `Files.Read` (minimum required)
       - `Files.ReadWrite` (if you want users to be able to upload files)
     - For group-based access control, add:
       - `GroupMember.Read.All`
   - Click "Add permissions"

2. **Grant Admin Consent**:
   - Click "Grant admin consent for [your organization]"
   - Click "Yes" to confirm

## Finding Required Configuration Values

After setting up your application, you'll need to gather several values for configuring Open WebUI:

1. **Application (Client) ID**:
   - On the application's "Overview" page
   - Copy the "Application (client) ID" value
   - This will be used for both `MICROSOFT_CLIENT_ID` and `ONEDRIVE_CLIENT_ID`

2. **Directory (Tenant) ID**:
   - On the application's "Overview" page
   - Copy the "Directory (tenant) ID" value
   - This will be used for both `MICROSOFT_CLIENT_TENANT_ID` and `ONEDRIVE_SHAREPOINT_TENANT_ID`

3. **Client Secret**:
   - Click on "Certificates & secrets" in the left menu
   - Click "+ New client secret"
   - Add a description and choose an expiration period
   - Click "Add"
   - **IMPORTANT**: Copy the secret value immediately, as you won't be able to see it again after leaving the page
   - This will be used for `MICROSOFT_CLIENT_SECRET`

4. **SharePoint URL** (for organizational accounts):
   - This is your organization's SharePoint URL, typically in the format:
   - `https://[company-name].sharepoint.com`
   - This will be used for `ONEDRIVE_SHAREPOINT_URL`

## Configuring Open WebUI

Once you have all the required values, update the environment variables in your Open WebUI deployment:

1. **Configure environment variables**:
   - You'll need to set the following environment variables with your configuration values:

   ```bash
   # OneDrive Integration
   ENABLE_ONEDRIVE_INTEGRATION=True
   ONEDRIVE_CLIENT_ID=your-client-id
   ONEDRIVE_SHAREPOINT_URL=https://yourcompany.sharepoint.com
   ONEDRIVE_SHAREPOINT_TENANT_ID=your-tenant-id

   # Microsoft 365 Authentication
   MICROSOFT_CLIENT_ID=your-client-id
   MICROSOFT_CLIENT_SECRET=your-client-secret
   MICROSOFT_CLIENT_TENANT_ID=your-tenant-id
   MICROSOFT_REDIRECT_URI=https://your-openwebui-domain/oauth/microsoft/callback

   # OAuth Settings
   ENABLE_OAUTH_SIGNUP=True
   OAUTH_MERGE_ACCOUNTS_BY_EMAIL=True
   OAUTH_ALLOWED_DOMAINS=yourcompany.com,otherdomain.com
   ```

2. **Add the environment variables to your deployment method**:
   - If using Docker, add these variables to your `docker-compose.yaml` file
   - If using Kubernetes, add these variables to your deployment manifest
   - If deploying directly, add these variables to your environment

3. **Update Dockerfile.custom**:
   - Add the following to your `technologymatch/Dockerfile.custom` to ensure the environment variables are set:

   ```dockerfile
   # Add Microsoft 365 and OneDrive configuration
   ENV ENABLE_ONEDRIVE_INTEGRATION=${ENABLE_ONEDRIVE_INTEGRATION:-False}
   ENV ONEDRIVE_CLIENT_ID=${ONEDRIVE_CLIENT_ID:-}
   ENV ONEDRIVE_SHAREPOINT_URL=${ONEDRIVE_SHAREPOINT_URL:-}
   ENV ONEDRIVE_SHAREPOINT_TENANT_ID=${ONEDRIVE_SHAREPOINT_TENANT_ID:-}
   
   ENV MICROSOFT_CLIENT_ID=${MICROSOFT_CLIENT_ID:-}
   ENV MICROSOFT_CLIENT_SECRET=${MICROSOFT_CLIENT_SECRET:-}
   ENV MICROSOFT_CLIENT_TENANT_ID=${MICROSOFT_CLIENT_TENANT_ID:-}
   ENV MICROSOFT_OAUTH_SCOPE=${MICROSOFT_OAUTH_SCOPE:-"openid email profile"}
   ENV MICROSOFT_REDIRECT_URI=${MICROSOFT_REDIRECT_URI:-}
   
   ENV ENABLE_OAUTH_SIGNUP=${ENABLE_OAUTH_SIGNUP:-False}
   ENV OAUTH_MERGE_ACCOUNTS_BY_EMAIL=${OAUTH_MERGE_ACCOUNTS_BY_EMAIL:-False}
   ```

## Testing the Integration

1. **Restart Open WebUI**:
   - After configuring the environment variables, restart your Open WebUI instance

2. **Test Authentication**:
   - Go to your Open WebUI login page
   - You should now see a Microsoft/Office 365 login option
   - Click on it and test the login process

3. **Test OneDrive Integration**:
   - After logging in, go to a chat or document upload area
   - Look for an option to upload files from OneDrive
   - Test uploading files from your OneDrive account

   > **Note**: Our TechnologyMatch customization simplifies the OneDrive integration to only use organizational accounts, removing the personal account option. This is implemented as a vertical slice in `technologymatch/custom/onedrive-organizations/`. See the README.md in that folder for more details.

## Troubleshooting

If you encounter issues with Microsoft 365 authentication or OneDrive integration, try the following:

1. **Check Redirect URI**:
   - Ensure the redirect URI in Microsoft Entra ID exactly matches the one used by Open WebUI
   - The correct path should be `/oauth/microsoft/callback` (not `/api/auth/callback/microsoft`)
   - The URI is case-sensitive and must include the protocol (https://)

2. **Verify Environment Variables**:
   - Double-check that all environment variables are correctly set
   - Ensure there are no typos in the client ID, tenant ID, or client secret

3. **Check API Permissions**:
   - Verify that the required API permissions are granted
   - Ensure admin consent has been provided for the permissions

4. **Check Logs**:
   - Review the Open WebUI logs for any error messages related to OAuth or Microsoft integration
   - Enable more verbose logging if needed

5. **Browser Developer Tools**:
   - Use browser developer tools to check for any JavaScript errors or failed network requests

For additional assistance, check the Open WebUI documentation or contact support.