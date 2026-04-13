# Architecture Notes (Initial)

## Modules
- `Apps/MacApp`: macOS UI shell and app lifecycle
  - `Apps/MacApp/Xcode/raagtex.xcodeproj`: signing/archive wrapper for App Store distribution
- `Apps/iOSApp`: iOS viewer scaffold and lifecycle
- `Shared`: shared app-facing models/services
- `Core`: domain primitives for compile, parsing, and document state
- `Package.swift`: builds `Core`, `Shared`, and executable `raagtex`

## Current State
V1 baseline is implemented for local macOS workflows:
- local project open and `.tex` discovery
- main-file/engine settings persistence
- `latexmk` compile runner and diagnostics parser
- PDF preview shell and compile output panes
- auto-compile watcher with debounce
- shared `GitService` for Phase 0 local git status + stage/commit/pull/push workflows
- smoke + unit/integration tests

## TODO
- Define compile service interfaces and parser contracts
- Define cross-device sync boundaries for V2
