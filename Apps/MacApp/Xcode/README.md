# Xcode Wrapper (macOS Release)

This folder contains a signing/archive-ready Xcode project for macOS App Store distribution.

## Open
- Open [raagtex.xcodeproj](/Users/raaghavt/Documents/GitHub/raagtex/Apps/MacApp/Xcode/raagtex.xcodeproj)
- Select target `raagtex`

## Signing
In **Signing & Capabilities**:
1. Team: your Apple Developer team
2. Bundle Identifier: `com.raaghavt.raagtex`
3. Signing Certificate: Apple Distribution (for archive)
4. Keep **App Sandbox** enabled
5. Keep **User Selected File Read/Write** enabled via `raagtex.entitlements`

## Versioning
In target settings:
- Marketing Version: `1.0`
- Current Project Version: increment build number each upload

## Archive
1. Product -> Archive
2. Organizer -> Distribute App -> App Store Connect -> Upload

## Regenerate project
If sources/settings change, regenerate from `project.yml`:

```bash
cd Apps/MacApp/Xcode
xcodegen generate
```
