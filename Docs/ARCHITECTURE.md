# Architecture Notes (Initial)

## Modules
- `Apps/MacApp`: macOS UI shell and app lifecycle
  - `Apps/MacApp/Xcode/raagtex.xcodeproj`: signing/archive wrapper for App Store distribution
- `Apps/iOSApp`: iPad UI shell and app lifecycle
- `Shared`: shared app-facing models/services
- `Core`: domain primitives for compile, parsing, and document state
- `Package.swift`: builds `Core`, `Shared`, and executable `raagtex`

## Current State
V1 baseline is implemented for local macOS workflows, plus a native iPad workspace shell:
- local project open and `.tex` discovery
- main-file/engine settings persistence
- `latexmk` compile runner and diagnostics parser
- PDF preview shell and compile output panes
- auto-compile watcher with debounce and coalesced refresh scheduling (to avoid repeated full-tree scans)
- macOS template library surfaces for document/style `.tex` templates with a file-menu manager and add-style flow
- shared `GitService` for Phase 0 local git status + stage/commit/pull/push workflows
- smoke + unit/integration tests
- iPad project open + `.tex` editing + diagnostics/PDF surfaces using shared models/services

## TODO
- Define compile service interfaces and parser contracts
- Define cross-device sync boundaries for V2
