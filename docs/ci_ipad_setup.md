# CI iPad Build Setup Guide

> **One-time setup on your Hackintosh** → then GitHub Actions builds the IPA → AltStore installs it on your iPad

---

## Part 1: Hackintosh — Generate Certificates (do this once)

### 1.1 Open the project in Xcode

```bash
open Package.swift
```

Xcode will resolve packages and auto-generate shared schemes. Wait for it to finish indexing.

### 1.2 Sign in with your Apple ID

- Xcode → **Settings** (⌘,) → **Accounts** tab
- Click **+** → **Apple ID** → sign in with your free developer account
- You'll see "Inscribe" appear under **iOS Development** once Xcode detects your team

### 1.3 Get your iPad's UDID

If you can connect the iPad to your Hackintosh via USB:
1. Open **Finder** → select your iPad → click the serial number until UDID appears
2. Copy it (⌘C)

If USB doesn't work on your Hackintosh:
1. On your iPad, open [getmyudid.com](https://getmyudid.com) in Safari
2. Tap **I Agree** → **Allow** configuration profile → **Close**
3. Go to **Settings** → **General** → **VPN & Device Management** → install profile
4. The UDID appears on the page — copy it

### 1.4 Register the device on Apple Developer

1. Go to [developer.apple.com/account/resources/devices/add](https://developer.apple.com/account/resources/devices/add)
2. Sign in with your Apple ID
3. Paste your iPad's UDID, give it a name (e.g., "My iPad")
4. Click **Continue** → **Register**

### 1.5 Let Xcode create a provisioning profile

1. In Xcode, select **Product → Build For → Running** (⌘R) with your iPad as the destination
   - If your iPad isn't listed as a destination, go to **Window → Devices and Simulators**
   - If it shows up, Xcode will auto-generate a **development provisioning profile**
   - If it doesn't (USB issues on Hackintosh), use the manual approach below instead
2. If asked about certificates, choose **Automatically manage signing**
3. After the build succeeds, the profile is saved at:
   `~/Library/MobileDevice/Provisioning\ Profiles/`

> **Can't build to iPad?** Xcode still auto-generates profiles when you select
> **Product → Archive** — but Archive may be greyed out until you build once.
> Workaround: first build for **Any iOS Simulator** (Product → Build), then Archive becomes available.

### 1.6 Export the development certificate

1. Open **Keychain Access** (Applications → Utilities)
2. In the left panel, select **login** → **My Certificates**
3. Find your **Apple Development** certificate (it usually starts with "Apple Development:" followed by your name or email)
4. Right-click → **Export** → choose a password
5. Save as `development.p12` somewhere safe

### 1.7 Find the provisioning profile

The profile is stored at:

```
~/Library/MobileDevice/Provisioning\ Profiles/
```

Look for the most recently modified `.mobileprovision` file. To identify which one is for Inscribe:

```bash
grep -l "Inscribe" ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision
```

Copy that file somewhere safe as `inscribe.mobileprovision`.

---

## Part 2: GitHub — Add Secrets

### 2.1 Base64-encode the files

On your Hackintosh terminal:

```bash
# Encode the certificate
base64 -i ~/Desktop/development.p12 | pbcopy
# → paste this into the GitHub secret IOS_DEV_CERTIFICATE

# Encode the provisioning profile
base64 -i ~/Desktop/inscribe.mobileprovision | pbcopy
# → paste this into the GitHub secret IOS_PROVISIONING_PROFILE
```

### 2.2 Add secrets to GitHub

1. Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** and add these 3 secrets:

| Secret Name | Value |
|-------------|-------|
| `IOS_DEV_CERTIFICATE` | base64 of your `development.p12` |
| `IOS_CERT_PASSWORD` | the password you set when exporting the .p12 |
| `IOS_PROVISIONING_PROFILE` | base64 of your `inscribe.mobileprovision` |

### 2.3 Update ExportOptions.plist

Open `ExportOptions.plist` in this repo and replace `YOUR_TEAM_ID` with your actual Team ID:

1. Find your Team ID at: [developer.apple.com/account/#MembershipDetails](https://developer.apple.com/account/#MembershipDetails)
2. Look for **Team ID** in the Membership Details section
3. Edit `ExportOptions.plist` and replace `YOUR_TEAM_ID`

### 2.4 Update workflow env vars to match your profile

In `.github/workflows/build-ipad.yml`, update **both** env vars at the top of the file:

```yaml
# ⚠️ Update these to match your actual provisioning profile
PRODUCT_BUNDLE_IDENTIFIER: com.yourname.InscribeApp
PROVISIONING_PROFILE_SPECIFIER: "iOS Team Provisioning Profile: com.yourname.InscribeApp"
```

To find the exact values, inspect your profile:

```bash
security cms -D -i ~/Desktop/inscribe.mobileprovision | plutil -p - | grep -E "Name|application-identifier"
```

The **application-identifier** maps to `PRODUCT_BUNDLE_IDENTIFIER` (minus the team ID prefix).
The **Name** is the exact `PROVISIONING_PROFILE_SPECIFIER` value.

---

## Part 3: Trigger the Build

### 3.1 Push to GitHub

```bash
git add .
git commit -m "Add CI iPad build workflow"
git push
```

### 3.2 Monitor the build

1. Go to your GitHub repo → **Actions** tab
2. Click the **Build for iPad** workflow
3. Watch it build (takes ~5-10 minutes)
4. When done, download the **Inscribe-iPad** artifact (.ipa file)

---

## Part 4: Install on iPad via AltStore

### 4.1 Install AltStore

1. **On a Windows PC or Mac** (any computer you have):
   - Download AltServer from [altstore.io](https://altstore.io)
   - Install and run it
   - Connect your iPad via USB
   - Click AltServer icon → **Install AltStore** → select your iPad
   - Enter your Apple ID credentials

2. **On your iPad:**
   - **Settings** → **General** → **VPN & Device Management** → trust the AltStore developer profile
   - Open AltStore

### 4.2 Enable Developer Mode (required once)

Before any sideloaded app can run, enable this on your iPad:

**Settings → Privacy & Security → Developer Mode → ON**

Your iPad will restart. This is a one-time requirement.

---

### 4.3 Install the IPA

1. Transfer the `.ipa` file to your iPad (AirDrop, iCloud Drive, email, or download from GitHub on the iPad itself)
2. On your iPad, tap the `.ipa` file → **Share** → **AltStore** → **Install**
3. AltStore will sign and install the app
4. The app appears on your home screen

### 4.4 Handle the 7-day expiry

Free developer accounts expire after 7 days. AltStore can auto-refresh:

1. Open AltStore on your iPad
2. Go to **My Apps**
3. Swipe down to refresh
4. Your iPad and AltServer PC/Mac need to be on the same Wi-Fi

Alternatively, every 7 days:
- Download a fresh IPA from GitHub Actions
- Re-install via AltStore

---

### 4.5 Verify Your Setup (catch issues early)

After setting up the certificate and profile on your Hackintosh, run these checks:

#### Check the certificate is valid
```bash
security find-identity -v -p codesigning
```
You should see your **Apple Development** certificate listed.

#### Find your provisioning profile name
```bash
# Find the right profile file
ls -lt ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision | head -5

# Decode it to see the Name and bundle ID
security cms -D -i ~/Library/MobileDevice/Provisioning\ Profiles/inscribe.mobileprovision 2>/dev/null | plutil -p - | grep -E "Name|application-identifier"
```

The **Name** value is what goes into `PROVISIONING_PROFILE_SPECIFIER` in the workflow.

#### Check bundle ID matches
The provisioning profile has a fixed bundle ID. Update `PRODUCT_BUNDLE_IDENTIFIER` in `build-ipad.yml` to match it.

---

## Part 5: Day-to-Day Workflow

Once everything is set up, your daily flow is:

```
code → git push → Actions builds IPA (~8 min) → download → AltStore install
```

To re-trigger without pushing code:
1. Go to your GitHub repo → **Actions** tab
2. Click **Build for iPad** in the left sidebar
3. Click **Run workflow** → **Run workflow**

Free account note: you'll need to re-install every 7 days. AltStore can refresh wirelessly if your iPad and AltServer computer are on the same Wi-Fi.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `No signing certificate` | Re-export .p12 from Keychain Access, ensure it's an **Apple Development** cert |
| `Provisioning profile not found` | Check the profile name in the workflow YAML matches what Xcode generated |
| `No device in profile` | Ensure your iPad's UDID is registered at [developer.apple.com](https://developer.apple.com/account/resources/devices/add) |
| Build succeeds but IPA won't install | Free accounts need **Developer Mode** enabled on the iPad: **Settings → Privacy & Security → Developer Mode → ON** |
| Certificate expired | Re-export from Keychain Access (your free dev cert is valid for 7 days) |
