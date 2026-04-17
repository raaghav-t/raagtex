# raagtex

A beautiful native LaTeX cockpit for fast local writing, compiling, and live document preview.

## Status
Functional Apple-platform baseline:
- macOS app with full local compile pipeline, editor, PDF preview, theming controls, and persistence.
- iPad app with native local project browsing, `.tex` editing, settings/recent-project persistence, diagnostics surface, and PDF preview.

## Implemented Baseline
- macOS SwiftUI shell with split-view navigation
- Multiple independent workspace windows (open different projects side-by-side)
- Open local project folders and discover `.tex` files
- Sidebar file explorer with nested project folders/files, quick `.tex` selection, and hidden LaTeX-generated supplementary artifacts
- Built-in editor for the selected main `.tex` file (save/revert + optional typo AutoCorrect, with `Cmd+S` save-only)
- Optional in-editor LaTeX syntax coloring tool (grayscale token differentiation)
- Configurable editor shortcut commands (math-first defaults) via Experience sidebar -> Writing -> Commands
- Choose compile engine (`pdflatex`, `xelatex`, `lualatex`) and compile via `latexmk`
- Preflight main-file validation blocks compile when required document structure is missing (`\documentclass` first non-comment line, plus `\begin{document}`)
- Structured diagnostics + raw compile log capture
- PDF preview surface (PDFKit-backed)
- Switchable editor/PDF layout with directional variants:
  - left-right
  - right-left
  - top-bottom
  - bottom-top
  - editor only (no PDF pane)
- Pop-out viewer window for detached PDF reading
- Auto-compile toggle with file-system watching
- Phase 0 local Git helpers:
  - status summary (branch + ahead/behind + dirty/conflict)
  - stage-on-save toggle
  - optional periodic auto-pull (rebase)
  - menu + sidebar actions: refresh, stage, commit, pull, push, sync
- Interface customization controls:
  - transparency slider
  - theme: light / dark / clear
  - mode: zen / debug (toggle)
  - clear-mode background effect settings:
    - native material blur toggle and material selection
    - tint color + tint opacity overlay
    - blur renderer preference (native/framework/css/fallback)
    - fallback blur radius for non-native paths
- Unified title/toolbar chrome with transparent window background support
- Recent project persistence
- Per-project settings persistence
- Sample project + smoke and unit/integration tests

## Planned V2 Scope
- Live preview sync from Mac to iPhone/iPad
- Page-change summaries after compile
- Friendlier error cards and richer diagnostics UX
- Theorem/equation/object browser
- Layout issue surfacing

## High-Level Architecture
- `Apps/MacApp`: macOS UI shell, project workflow, editor/preview, compile controls
- `Apps/iOSApp`: iPad workspace shell, project workflow, editor, diagnostics, and PDF preview
- `Core`: compile domain, latexmk runner, diagnostics parser, document state
- `Shared`: reusable models + persistence stores (recent projects/settings)
- `Examples`: small compileable sample LaTeX project

## Repository Layout
- `README.md`: project overview and status
- `SPEC.md`: product specification and boundaries
- `TASKS.md`: phased roadmap
- `AGENTS.md`: coding-agent constraints for this repo
- `.codex/config.toml`: conservative Codex defaults
- `Package.swift`: Swift package for `Core`, `Shared`, `raagtex`, and tests
- `Apps/`: app entry-point and view-model/UI code
  - `Apps/MacApp/Xcode/`: Xcode wrapper project for signing/archiving (`raagtex.xcodeproj`)
- `Core/`: compile/parsing/document-state modules
- `Shared/`: shared models/services
- `Scripts/`: local build/test/smoke helpers
- `Docs/`: architecture, design rationale, and future ideas
- `Website/`: standalone Raagtex project website page (HTML/CSS/JS)
