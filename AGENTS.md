# Agent Guidelines for LaTeX Cockpit

## Core Expectations
- Prefer SwiftUI for UI work.
- Use AppKit/UIKit only when SwiftUI cannot reasonably satisfy the requirement.
- Keep diffs minimal, reversible, and tightly scoped to the requested milestone.
- Preserve a calm, Apple-like visual tone; avoid dense IDE-style UI choices.
- Avoid heavy dependencies unless there is a clear, documented justification.

## Architecture and Scope
- Favor clear modular boundaries (`Apps`, `Shared`, `Core`) over convenience coupling.
- Keep shared models/platform-independent logic in shared/core modules.
- Update `README.md`, `SPEC.md`, and/or `Docs/` when architecture or behavior changes.
- Do not overbuild beyond the requested phase/milestone.
- In early setup, favor stubs/scaffolds over speculative full implementations.

## Quality and Verification
- When adding code, include a lightweight verification path (build target, smoke test, or script).
- Keep TODOs explicit where major technical decisions are still open.
- Do not introduce networking/collaboration features unless explicitly requested.
