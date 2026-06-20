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

Always create a dedicated feature branch before starting feature/change work (e.g., `feature/<kebab-name>`); never commit feature work directly to `main`. Use one branch per OpenSpec change (or per coherent group of sequenced changes) and merge back via PR.

GitHub Milestones and Issues are the project planning surface. Before starting non-trivial development, documentation, release, or workflow work, make sure there is a GitHub Issue assigned to the appropriate Milestone. Link the Issue from the related OpenSpec change and reference it in the PR.

Use short imperative subjects such as `Add OpenSpec contributor guide`.

Pull requests should include the related OpenSpec change when applicable, a concise summary, validation commands and results, and screenshots only for UI-visible changes.

## Agent-Specific Instructions

OpenSpec is authoritative for specifications, tasks, and acceptance criteria. For implementation, use a test-first loop when behavior is clear. For bugs or unexplained failures, reproduce and diagnose before changing code.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, invoke the `skill` tool with `skill: "graphify"` before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
