# Architecture Notes (Initial)

## Modules
- `Apps/MacApp`: macOS UI shell and app lifecycle
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
- smoke + unit/integration tests

## TODO
- Add an Xcode workspace/project wrapper if product distribution requires App bundle workflows beyond SwiftPM executable use
- Define compile service interfaces and parser contracts
- Define cross-device sync boundaries for V2
