# Deployment Guide

This guide covers store registration, running the EFB app on simulators, emulators, and physical devices.

## Store Registration & Prep

Before you can publish to either store, you need developer accounts and listing assets ready.

### Apple App Store

1. **Enroll in the Apple Developer Program** at [developer.apple.com/programs](https://developer.apple.com/programs). Costs $99/year. Identity verification can take 24–48 hours, so start here first.
2. **Register a Bundle ID** in the Apple Developer portal under **Certificates, Identifiers & Profiles** (e.g. `com.yourcompany.efb`). This must be globally unique.
3. **Create your app in App Store Connect** at [appstoreconnect.apple.com](https://appstoreconnect.apple.com). This is where you manage builds, listings, and submissions.
4. **Prepare listing assets:**
   - App name, description, keywords, and category
   - Screenshots for each supported device size (6.7", 6.1", etc.)
   - App icon (1024x1024)
   - Privacy policy URL (required)
   - Support URL
5. **Add a data accuracy disclaimer** — Aviation apps may get extra review scrutiny. Include something like "not for primary navigation" to preempt reviewer questions.

### Google Play Store

1. **Register a Google Play Developer account** at [play.google.com/console](https://play.google.com/console). One-time $25 fee. Registration is instant.
2. **Generate an upload signing key** — Google Play requires signed builds. Let Google manage the app signing key (recommended), but you still need an upload key:
   ```bash
   keytool -genkey -v -keystore ~/efb-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Keep this keystore safe — it cannot be changed later.
3. **Prepare listing assets:**
   - App name, short description, and full description
   - Screenshots (phone, optionally tablet)
   - Feature graphic (1024x500)
   - App icon (512x512)
   - Privacy policy URL (required)
   - Content rating questionnaire (completed in the Play Console)

### Both Stores

- **Privacy policy** — Required by both stores. Since the app accesses location, weather, and flight data, disclose what data is collected and whether anything is stored server-side.
- **Support website** — Both stores require a support URL. Can be a simple landing page.
- **DUNS number** — Only needed if publishing as an organization on Apple. Not required for individual accounts.

## iOS

### Prerequisites

- **Xcode** installed from the Mac App Store
- **CocoaPods** for iOS dependency management

```bash
# Accept Xcode license and install command-line tools (first time only)
sudo xcodebuild -license accept
xcode-select --install

# Install CocoaPods
sudo gem install cocoapods
# Or: brew install cocoapods

# Install iOS dependencies
cd mobile/ios && pod install --repo-update && cd ..
```

### Running on iOS Simulator

```bash
# Open the iOS Simulator app
open -a Simulator
# Pick a device from Simulator menu: File > Open Simulator > iOS XX > iPhone XX

# Verify Flutter sees the simulator
flutter devices

# Run the app
cd mobile
flutter run
```

If multiple devices are connected, specify one: `flutter run -d "iPhone 16"`.

The first build takes a few minutes. After that, press `r` in the terminal for hot reload, `R` for hot restart.

### Running on a Physical iPhone

#### 1. Connect your iPhone

Plug it in via USB/USB-C. When prompted on the phone, tap **Trust This Computer**.

#### 2. Enable Developer Mode (iOS 16+)

On your iPhone, go to **Settings > Privacy & Security > Developer Mode**, toggle it on, and restart the device.

#### 3. Set up signing in Xcode

Open the Xcode workspace:

```bash
open mobile/ios/Runner.xcworkspace
```

In Xcode:

- Select the **Runner** project in the left sidebar
- Select the **Runner** target
- Go to the **Signing & Capabilities** tab
- Check **Automatically manage signing**
- Under **Team**, select your Apple ID (if it's not listed, add it via Xcode > Settings > Accounts > `+` > Apple ID)
- Change the **Bundle Identifier** to something unique, e.g. `com.yourname.efb` — Apple requires this to be globally unique

You don't need a paid Apple Developer account ($99/yr) for personal testing — a free Apple ID works, but apps expire after 7 days and you're limited to 3 apps on the device at a time.

#### 4. Trust the developer profile on your iPhone

The first time you run an app from your Apple ID:

- On your iPhone go to **Settings > General > VPN & Device Management**
- Tap your Apple ID under "Developer App"
- Tap **Trust**

#### 5. Run from the terminal

```bash
cd mobile
flutter devices              # Find your device name (e.g. "Noah's iPhone")
flutter run -d "Noah's iPhone"
```

### iOS Troubleshooting

- **General diagnostics** — Run `flutter doctor -v` to identify issues.
- **"Could not launch"** — You haven't trusted the developer profile yet (see step 4 above).
- **"No provisioning profile"** — Re-open Xcode, make sure automatic signing is on and the bundle ID is unique.
- **"Device is locked"** — Unlock your phone before running.
- **Signing errors on simulator** — Open `mobile/ios/Runner.xcworkspace` in Xcode, go to **Signing & Capabilities**, and select a team (your personal Apple ID works for simulators).
- **Network/API connection** — Your phone and Mac must be on the same WiFi network for the app to reach the backend. Replace `localhost` in `lib/services/api_client.dart` with your Mac's local IP (find it with `ipconfig getifaddr en0`).

## Android

### Prerequisites

- [Android Studio](https://developer.android.com/studio) installed
- Accept Android SDK licenses: `flutter doctor --android-licenses`

### Running on Android Emulator

```bash
# Open Android Studio > Tools > Device Manager > Create Virtual Device
# Select a device (e.g., Pixel 7) and download a system image (e.g., API 34)
# Click "Finish" to create, then press the play button to launch

# Verify Flutter sees the emulator
flutter devices

# Run the app
cd mobile
flutter run
```

### Running on a Physical Android Device

#### 1. Enable Developer Options

On your Android device:

- Go to **Settings > About Phone**
- Tap **Build Number** 7 times to enable Developer Options
- Go back to **Settings > System > Developer Options**
- Enable **USB Debugging**

#### 2. Connect and authorize

Plug in via USB. When prompted on the phone, tap **Allow USB Debugging** and check "Always allow from this computer".

#### 3. Run from the terminal

```bash
cd mobile
flutter devices              # Verify the device appears
flutter run
```

### Android Troubleshooting

- **General diagnostics** — Run `flutter doctor -v` to identify issues.
- **Emulator is slow** — Ensure hardware acceleration (HAXM/HVF on Mac) is enabled in Android Studio's SDK Manager under **SDK Tools > Android Emulator Hypervisor Driver**.
- **Apple Silicon Macs** — Use an **arm64-v8a** system image for the emulator — these run natively without translation.
- **Network/API connection** — Android emulators use `10.0.2.2` to reach the host machine's `localhost`. For physical devices, use your Mac's local IP (find it with `ipconfig getifaddr en0`).
