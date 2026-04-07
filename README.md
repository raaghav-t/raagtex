# raagtex

A beautiful native LaTeX cockpit for fast local writing, compiling, and live document preview.

## Status
Functional macOS-first baseline with compile pipeline, built-in editor, PDF preview, theming controls, and project/settings persistence.

## Implemented Baseline
- macOS SwiftUI shell with split-view navigation
- Open local project folders and discover `.tex` files
- Built-in editor for the selected main `.tex` file (save/revert + optional typo AutoCorrect)
- Choose compile engine (`pdflatex`, `xelatex`, `lualatex`) and compile via `latexmk`
- Structured diagnostics + raw compile log capture
- PDF preview surface (PDFKit-backed)
- Switchable editor/PDF layout (side-by-side or vertically stacked)
- Pop-out viewer window for detached PDF reading
- Auto-compile toggle with file-system watching
- Interface customization controls:
  - transparency slider
  - theme: light / dark / custom accent
  - mode: zen / debug
- Recent project persistence
- Per-project settings persistence
- Sample project + smoke and unit/integration tests

## Planned V2 Scope
- iPhone/iPad viewer companion
- Live preview sync from Mac to iPhone/iPad
- Page-change summaries after compile
- Friendlier error cards and richer diagnostics UX
- Theorem/equation/object browser
- Layout issue surfacing

## High-Level Architecture
- `Apps/MacApp`: macOS UI shell, project workflow, editor/preview, compile controls
- `Apps/iOSApp`: iOS companion scaffold for future live preview
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
- `Core/`: compile/parsing/document-state modules
- `Shared/`: shared models/services
- `Scripts/`: local build/test/smoke helpers
- `Docs/`: architecture, design rationale, and future ideas
