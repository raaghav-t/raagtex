# LaTeX Cockpit

A beautiful native LaTeX cockpit for fast local writing, compiling, and live document preview.

## Status
Functional V1 foundation (macOS-first) with compile pipeline, PDF preview shell, project/settings persistence, and test scaffolding.

## Implemented V1 Baseline
- macOS SwiftUI shell with split-view navigation
- Open local project folders and discover `.tex` files
- Choose main `.tex` file and compile engine (`pdflatex`, `xelatex`, `lualatex`)
- Compile via `latexmk`
- Structured diagnostics + raw compile log capture
- PDF preview surface (PDFKit-backed)
- Auto-compile toggle with file-system watching
- Recent project persistence
- Per-project settings persistence (engine/main file/auto-compile)
- Sample project + smoke and unit/integration tests

## Planned V2 Scope
- iPhone/iPad viewer companion
- Live preview sync from Mac to iPhone/iPad
- Page-change summaries after compile
- Friendlier error cards and richer diagnostics UX
- Theorem/equation/object browser
- Layout issue surfacing

## High-Level Architecture
- `Apps/MacApp`: macOS UI shell, project workflow, preview, compile controls
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
- `Package.swift`: Swift package for `Core`, `Shared`, and tests
- `Apps/`: app entry-point and view-model/UI code
- `Core/`: compile/parsing/document-state modules
- `Shared/`: shared models/services
- `Scripts/`: local build/test/smoke helpers
- `Docs/`: architecture, design rationale, and future ideas
