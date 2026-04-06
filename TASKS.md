# Implementation Tasks

## Phase 0 - Scaffold
- [x] Repository layout and baseline documentation
- [x] Minimal app entry-point stubs for macOS and iOS
- [x] Shared/core module folders with placeholder types
- [x] Sample LaTeX project and script stubs

## Phase 1 - macOS Shell App
- [x] Split-shell UI (sidebar, preview area, compile output area)
- [x] Project chooser/open flow
- [x] Settings model (engine/main file/auto-compile)
- [x] Recent project persistence

## Phase 2 - Compile Pipeline
- [x] `latexmk` compile runner service
- [x] Compile lifecycle state updates in app state
- [x] Raw compile stdout/stderr capture
- [x] Lightweight structured diagnostics parsing

## Phase 3 - PDF Preview + Project State
- [x] PDF preview surface wired to compiled artifact path
- [x] Main file selection and project state integration
- [x] Auto-compile trigger with file-system watcher + debounce
- [x] Error and status state propagation to UI

## Phase 4 - Polished UX
- [ ] Accessibility pass (VoiceOver + keyboard focus traversal)
- [ ] Better diagnostic grouping (error cards + source jump hooks)
- [ ] Unified command menu and more keyboard shortcuts
- [ ] Expand smoke/regression coverage around watcher and settings persistence

## Phase 5 - iOS Live Viewer
- [ ] Pairing/session model between macOS and iOS app
- [ ] Live preview transfer protocol and reconnection policy
- [ ] Page-change summary pipeline
- [ ] Hardened offline behavior and companion UX polish
