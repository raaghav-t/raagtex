# UI Design Decisions (V1)

This project aligns the initial UI shell with Apple Human Interface Guidelines and keeps a restrained native style.

## Applied Principles
- Navigation uses a split-view layout with a leading sidebar for workspace/project switching.
- Primary actions are in a compact top control bar (open, main file, engine, auto-compile, compile).
- Material backgrounds are used sparingly to support a calm layered feel without reducing readability.
- Compile diagnostics and raw log are separated in a simple segmented inspector to avoid clutter.
- Empty states use system `ContentUnavailableView` for native guidance.

## Source References
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

## TODO
- Validate contrast and spacing against final typography scale once the app target is wired in Xcode.
- Add keyboard navigation and VoiceOver pass for diagnostics list and compile controls.
