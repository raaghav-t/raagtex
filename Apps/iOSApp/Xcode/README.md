# Xcode Wrapper (iOS)

This folder contains an iOS Xcode project wrapper for simulator/device runs.

## Open
- Open [raagtex-ios.xcodeproj](/Users/raaghavt/Documents/GitHub/raagtex/Apps/iOSApp/Xcode/raagtex-ios.xcodeproj)
- Select target `raagtex-ios`

## Signing (Device)
In **Signing & Capabilities**:
1. Team: your Apple Developer team
2. Bundle Identifier: `com.raaghavt.raagtex.ios` (or your unique variant)
3. Signing Certificate: Apple Development

## Regenerate project
If sources/settings change, regenerate from `project.yml`:

```bash
cd Apps/iOSApp/Xcode
xcodegen generate
```
