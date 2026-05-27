# Repository Guidelines

## Project Structure & Module Organization

GeekPlayer is currently a greenfield repository. There is no application source tree, build system, or test suite yet.

- `README.md` contains the placeholder project name.
- `CLAUDE.md` documents the current agent workflow and repository status.
- `openspec/config.yaml` declares the `spec-driven` OpenSpec workflow.
- `openspec/changes/` will hold active change proposals, designs, and task lists.
- `openspec/specs/` will hold accepted capability specs as the product takes shape.
- `.claude/`, `.codex/`, and `.pi/` contain agent workflow definitions and should stay aligned when workflow skills change.

When adding code, introduce conventional top-level directories such as `src/`, `tests/`, and `assets/` only as part of an approved change.

## Build, Test, and Development Commands

No language toolchain is defined yet, so there are currently no repository build, test, lint, or dev-server commands.

Use OpenSpec for non-trivial work:

- `openspec list --json` lists active changes.
- `openspec new change "<kebab-case-name>"` creates a change scaffold.
- `openspec status --change "<name>" --json` checks artifact status.
- `openspec instructions apply --change "<name>" --json` retrieves implementation instructions.

Once a stack is selected, document its commands here before relying on them.

## Coding Style & Naming Conventions

Prefer minimal, reversible changes. Do not introduce public behavior, persistence formats, APIs, CLIs, or compatibility expectations without an OpenSpec change.

Use kebab-case for OpenSpec change names, for example `add-playback-queue`. Keep Markdown concise and use fenced code blocks for commands. Follow the formatter and linter of the chosen stack once one exists.

## Testing Guidelines

No test framework or coverage target exists yet. New implementation work should define targeted tests alongside the chosen stack. Name tests after observable behavior, and keep them close to the code unless the stack establishes a separate convention such as `tests/`.

Before reporting completion, run relevant tests, lint/typecheck commands if available, OpenSpec validation when specs change, and `git diff --check`.

## Commit & Pull Request Guidelines

Git history currently contains only `Initial commit`, so no project-specific commit convention has emerged. Until one is adopted, use short imperative subjects such as `Add OpenSpec contributor guide`.

Pull requests should include the related OpenSpec change when applicable, a concise summary, validation commands and results, and screenshots only for UI-visible changes.

## Agent-Specific Instructions

OpenSpec is authoritative for specifications, tasks, and acceptance criteria. For implementation, use a test-first loop when behavior is clear. For bugs or unexplained failures, reproduce and diagnose before changing code.
