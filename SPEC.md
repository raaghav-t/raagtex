# raagtex - Initial Product Spec

## Product Vision
raagtex is a calm, native Apple experience for local LaTeX workflows: write in your preferred editor, compile quickly, and keep PDF output and compile state central.

## Target Users
- Researchers and students working on papers/theses with local LaTeX projects
- Technical writers who prefer native tools and local-first workflows
- Engineers/scientists who iterate quickly between source and compiled PDF

## Design Principles
- Calm, elegant, native Apple-feeling UI
- "Liquid glass" visual language, restrained and readable
- Fast compile-feedback loop
- PDF and compile state are central surfaces
- Avoid cluttered IDE aesthetics
- Prioritize local-first workflow

## V1 Features
- macOS app shell with built-in editor + preview (with optional typo AutoCorrect and adjustable editor text size)
- Optional in-editor LaTeX syntax coloring tool (initial grayscale palette)
- Configurable keyboard shortcuts for LaTeX wrapping/snippet insertion (math-first defaults) with user-editable mappings
- Choose/open a LaTeX project
- Choose a main `.tex` file
- Browse project files from a sidebar explorer, pick `.tex` files directly, and hide common LaTeX-generated supplementary artifacts
- Template workflow for new files:
  - document-template and style-template `.tex` libraries
  - in-app manager (`File -> Edit Templates…`) with text preview, PDF-preview placeholder toggle, and editable template display names independent of file names
  - one-click style insertion into current project (`File -> Add Style…`)
- Compile via `latexmk`
- Preflight guard that blocks compile attempts when the selected main file is not a valid document shell (`\documentclass` + `\begin{document}`)
- Basic structured compile output model
- PDF preview pane with optional pop-out viewer window and directional editor/preview layouts (left-right, right-left, top-bottom, bottom-top) plus an editor-only mode (no PDF pane)
- Auto-compile toggle
- Phase 0 local Git workflow helpers (status/stage/commit/pull/push/sync, with optional stage-on-save and auto-pull)
- Recent project persistence
- Settings model for engine/main file/auto-compile/theme/mode/transparency/layout/editor text size plus clear-mode background blur/material/tint controls with fallback renderer options
- UI themes include light, dark, and clear-transparency variants
- iPad app shell with:
  - local folder opening
  - `.tex` file browser and picker
  - built-in text editor with save/revert
  - persisted main-file + engine settings and recent projects
  - diagnostics + compile-state panel
  - embedded PDF preview

## V2 Features
- Live preview sync from Mac to iPhone/iPad
- Page-change summary after compile
- Friendlier error cards
- Theorem/equation/object browser
- Layout issue surfacing

## Non-Goals
- Full text editor replacement
- Overleaf clone
- Real-time collaboration in V1
- Custom TeX distribution
- Cross-platform scope beyond Apple stack in V1

## Technical Direction
- Native Apple-stack project
- SwiftUI-first approach
- macOS + iPad as primary local workflow targets
- iOS compile execution remains constrained by platform process limits; synced artifacts from macOS remain part of roadmap
- Shared reusable module boundaries for models/services
- Keep third-party dependencies minimal unless justified
- Local compile execution with `latexmk` (system TeX install)

## Risks / Open Questions
- TeX distribution compatibility differences across user environments
- Sandboxing/path access implications for project and compiler invocation
- How much compile output normalization is needed for useful UX in V1
- PDF preview performance and update strategy on frequent recompiles
- File-watching strategy tradeoffs (latency vs battery/CPU)
- iOS companion transport choice for V2 sync (local network, peer-to-peer, etc.)
- TODO: Decide initial state persistence layer (`UserDefaults` vs lightweight store)
- TODO: Define compile cancellation and queuing behavior
