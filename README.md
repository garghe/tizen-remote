# TV Remote (Samsung Tizen)

Simple iPhone remote for Samsung Tizen TVs (2016+, tested target: 2024/2025 models).

**Features:** finds TVs on your Wi-Fi network · Power · Source · Mute · Volume · arrow buttons + OK · Back · Home · Netflix / Disney+ / Apple TV shortcuts.

## How it works
- **Discovery:** scans your Wi-Fi subnet for Samsung's API on port 8001. You can also add a TV by IP (the **+** button).
- **Control:** secure WebSocket on port 8002. The first time, the TV asks you to **Allow** the "iPhone Remote" device. The app saves the token, so the TV asks only once.
- **Power on:** uses Wake-on-LAN. On the TV, turn on *Settings › General › Network › Expert Settings › Power On with Mobile*.

## Test with TestFlight (no Mac needed)
One-time setup:
1. **Apple Developer account** (paid) → note your **Team ID** (developer.apple.com › Membership).
2. **App Store Connect › Users and Access › Integrations › App Store Connect API** → create a key with **Admin** role. Download the `.p8` file and note the **Key ID** and **Issuer ID**.
3. **App Store Connect › Apps › +** → New App, iOS, bundle ID `com.garghe.tizenremote` (register it first in developer.apple.com › Identifiers if it isn't listed). To use a different bundle ID, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`.
4. In this GitHub repo: **Settings › Secrets and variables › Actions** → add:
   - `APPLE_TEAM_ID`
   - `ASC_KEY_ID`
   - `ASC_ISSUER_ID`
   - `ASC_KEY_P8` (paste the whole contents of the .p8 file)

Then: **Actions › TestFlight › Run workflow**. After ~10–20 min of processing, the build shows up in the TestFlight app on your iPhone (add yourself as an internal tester in App Store Connect › TestFlight).

## Build locally with Xcode (optional)
```bash
brew install xcodegen
xcodegen generate
open TizenRemote.xcodeproj
```
Select your team under *Signing & Capabilities*, then run on your iPhone.
