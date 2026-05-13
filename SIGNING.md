# Code Signing & Notarization Guide

This guide walks you through setting up Apple Developer ID signing and notarization so users can download and open your DMG without Gatekeeper warnings.

---

## Prerequisites

- An active **Apple Developer Program** membership ($99/year)
- macOS with Xcode Command Line Tools installed
- Admin access to this GitHub repository (for automated releases)

---

## Step 1: Create a Developer ID Application Certificate

**Important:** You currently have an **Apple Development** certificate, which is for local development and App Store distribution only. For distributing outside the App Store (GitHub releases), you need a **Developer ID Application** certificate.

### On the Apple Developer website

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list)
2. Click the **+** button to add a new certificate
3. Under **Services**, select **Developer ID Application**
4. Follow the instructions to create a **Certificate Signing Request (CSR)** using Keychain Access on your Mac
5. Upload the CSR and download the `.cer` file
6. Double-click the `.cer` file to install it in your **login** keychain

### Verify installation

```sh
security find-identity -v -p codesigning
```

You should see an entry like:

```
Developer ID Application: Your Name (TEAMID)
```

---

## Step 2: Export the Certificate for GitHub Actions

GitHub Actions needs the certificate in `.p12` format.

1. Open **Keychain Access** on your Mac
2. Select **login** keychain → **My Certificates**
3. Find **Developer ID Application: Your Name (TEAMID)**
4. Right-click → **Export**
5. Choose format: **Personal Information Exchange (.p12)**
6. Set a strong export password and save as `certificate.p12`
7. Move it to this project directory

### Convert to base64 for GitHub Secrets

```sh
cd /path/to/this/project
base64 -i certificate.p12 -o certificate.b64
```

The content of `certificate.b64` is what you'll paste into the `MACOS_CERTIFICATE` secret.

**Delete `certificate.p12` from your project folder after uploading to GitHub.**

---

## Step 3: Create an App-Specific Password for Notarization

Apple requires an app-specific password for notarization (you cannot use your regular Apple ID password).

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in with your Apple ID
3. Go to **App-Specific Passwords**
4. Generate a new password (e.g., "WinEventLogViewer-Notarize")
5. Copy the password — you will only see it once

---

## Step 4: Find Your Team ID

If your Apple Developer account belongs to multiple teams, you need your Team ID.

```sh
xcrun notarytool store-credentials \
  --apple-id "your@apple.id" \
  --team-id "YOURTEAMID" \
  --password "your-app-specific-password"
```

Or find it at [Membership Details](https://developer.apple.com/account#MembershipDetailsCard).

---

## Step 5: Test Locally

Set the environment variables and build:

```sh
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARIZATION_USERNAME="your@apple.id"
export NOTARIZATION_PASSWORD="your-app-specific-password"
export NOTARIZATION_TEAM_ID="YOURTEAMID"  # optional

./script/create_dmg.sh
```

The script will:
1. Build the release app
2. Sign the app with your Developer ID + hardened runtime
3. Create the DMG
4. Sign the DMG
5. Submit to Apple for notarization
6. Staple the notarization ticket to the DMG

After it completes, verify:

```sh
spctl -a -t open --context context:primary-signature -v dist/WindowsEventLogViewer.dmg
```

You should see:
```
dist/WindowsEventLogViewer.dmg: accepted
source=Notarized Developer ID
```

---

## Step 6: Configure GitHub Secrets

For automated releases via GitHub Actions, add these secrets to your repository:

1. Go to your repository on GitHub → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** for each:

| Secret Name | Value |
|-------------|-------|
| `MACOS_CERTIFICATE` | Contents of `certificate.b64` (base64-encoded .p12) |
| `MACOS_CERTIFICATE_PWD` | The export password you set when exporting the .p12 |
| `MACOS_KEYCHAIN_PWD` | Any strong temporary password (used only in CI) |
| `CODESIGN_IDENTITY` | Full certificate name, e.g. `Developer ID Application: Your Name (TEAMID)` |
| `NOTARIZATION_USERNAME` | Your Apple ID email |
| `NOTARIZATION_PASSWORD` | The app-specific password from Step 3 |
| `NOTARIZATION_TEAM_ID` | Your Apple Team ID (optional) |

---

## Step 7: Publish a Release

Once secrets are configured, push a version tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will:
1. Build the app on macOS
2. Import your signing certificate
3. Sign and notarize the DMG
4. Upload `WindowsEventLogViewer.dmg` to the GitHub release page

---

## Troubleshooting

### "No identity found" during signing

Your certificate isn't in the default keychain, or its name doesn't match `CODESIGN_IDENTITY`. Run:

```sh
security find-identity -v -p codesigning
```

and copy the exact name shown in quotes.

### Notarization fails with invalid credentials

- Make sure you're using an **app-specific password**, not your Apple ID password
- If your account has multiple teams, you **must** provide `NOTARIZATION_TEAM_ID`
- Check that your Apple Developer Program membership is active

### Gatekeeper still warns after notarization

Make sure you **stapled** the ticket. The `create_dmg.sh` script does this automatically, but you can verify:

```sh
xcrun stapler staple dist/WindowsEventLogViewer.dmg
```

If it says "The action worked", the ticket is stapled. If it says "no tickets found", the notarization may still be processing.
