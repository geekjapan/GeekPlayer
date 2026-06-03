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

Use short imperative subjects such as `Add OpenSpec contributor guide`.

Pull requests should include the related OpenSpec change when applicable, a concise summary, validation commands and results, and screenshots only for UI-visible changes.

## Agent-Specific Instructions

OpenSpec is authoritative for specifications, tasks, and acceptance criteria. For implementation, use a test-first loop when behavior is clear. For bugs or unexplained failures, reproduce and diagnose before changing code.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **GeekPlayer** (3180 symbols, 3391 relationships, 7 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/GeekPlayer/context` | Codebase overview, check index freshness |
| `gitnexus://repo/GeekPlayer/clusters` | All functional areas |
| `gitnexus://repo/GeekPlayer/processes` | All execution flows |
| `gitnexus://repo/GeekPlayer/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
