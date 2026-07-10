# CI iPad Build Guide — Unsigned IPA via AltStore

> **Push code to GitHub → Actions builds unsigned IPA → AltStore installs on your iPad A16**
>
> No paid Apple Developer Program ($99/yr) needed. No certificates. No provisioning profiles.

---

## How It Works

Your Hackintosh can't detect your iPad via USB — that's actually fine. This workflow:

1. **Builds the app** on GitHub's macOS runner (Xcode 26, iPadOS 26 SDK)
2. **Strips all Apple signing** (no certificate, no provisioning profile)
3. **Packages it as an unsigned `.ipa`** (just a zip of the `.app` bundle)
4. **AltStore signs it on your iPad** using your free Apple ID — no computer needed

---

## Setup (takes 2 minutes)

### 1. Push your code to GitHub

```bash
git add .
git commit -m "Add CI build workflow"
git push
```

### 2. Trigger a build

1. Go to your repo on GitHub → **Actions** tab
2. Click **🏗️ Build Unsigned IPA (AltStore)** in the left sidebar
3. Click **Run workflow** → **Run workflow**
4. Wait ~8-12 minutes

### 3. Download the IPA

When the build finishes:
1. Click the completed workflow run
2. Scroll to **Artifacts** section
3. Click **Inscribe-Unsigned** to download the `.ipa`

### 4. Install via AltStore

1. **Transfer the `.ipa` to your iPad** — AirDrop, iCloud Drive, Google Drive, email, or just download it directly on the iPad from GitHub's mobile site
2. Open **AltStore** on your iPad
3. Go to **My Apps** → tap **+** in the top-left corner
4. Select the `.ipa` file
5. AltStore signs and installs it — **done!**

---

## Day-to-Day Workflow

```
code → git push → Actions builds (~10 min) → download IPA → AltStore install
```

To re-build without pushing code:
- Go to **Actions** → **🏗️ Build Unsigned IPA (AltStore)** → **Run workflow**

The 7-day expiry applies (free Apple ID). AltStore can auto-refresh if your iPad and a computer running AltServer are on the same Wi-Fi.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Build fails at archive step | Check that the scheme name matches your project. Open `Package.swift` in Xcode once to auto-generate schemes |
| IPA downloads but AltStore can't open it | Make sure you downloaded the `.ipa` artifact (not the source code zip). Try re-downloading |
| AltStore says "could not find app" | The `.ipa` must contain a `Payload/` folder with the `.app` inside. Unzip to verify |
| AltStore install fails | Free accounts are limited. Make sure you're not exceeding the 3-app sideload limit. Refresh AltStore first |
| Build says "Xcode 26 not found" | GitHub's macOS runner image may have shifted. Check the build logs for available Xcode versions and update accordingly |
| App crashes on launch | Run it from Xcode's simulator once to catch any Swift issues, or check the device crash logs |
