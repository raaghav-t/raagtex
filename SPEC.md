# LaTeX Cockpit - Initial Product Spec

## Product Vision
LaTeX Cockpit is a calm, native Apple experience for local LaTeX workflows: write in your preferred editor, compile quickly, and keep PDF output and compile state central.

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
- macOS app scaffold
- Choose/open a LaTeX project
- Choose a main `.tex` file
- Compile via `latexmk`
- Basic structured compile output model
- PDF preview pane
- Auto-compile toggle
- Recent project persistence
- Settings model for engine/main file/auto-compile

## V2 Features
- Paired iPhone/iPad viewer
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
- macOS as primary V1 target
- iOS scaffold for future companion support
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
