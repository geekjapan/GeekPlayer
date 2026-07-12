# Repository Guidelines

## Project Structure & Module Organization

GeekPlayer is an active Flutter/Dart application. Do not treat it as a greenfield scaffold. Before changing behavior, inspect the existing code, accepted specs, active OpenSpec changes, and relevant ADRs.

- `app/` contains the Flutter project, application code, tests, platform scaffolding, packaging helpers, and generated localization/license files.
- `docs/` contains conventions, ADRs, release notes, roadmap, handoff material, and the multi-chat development workflow (`docs/WORKFLOW.md`).
- `CONTEXT.md` defines project domain language and should be kept aligned with design decisions.
- `openspec/config.yaml` declares the `spec-driven` OpenSpec schema and project-wide artifact rules.
- `openspec/changes/` holds active change proposals, designs, and task lists; completed changes move to `openspec/changes/archive/`.
- `openspec/specs/` holds accepted capability specs — update them through OpenSpec archive/sync flows, not ad hoc edits.
- `.github/workflows/` contains CI and release workflows.
- `.agents/`, `.claude/`, `.codex/`, and `.pi/` contain per-harness skill and command definitions (identical OpenSpec skills under each). Keep these in sync when modifying workflow skills.

When adding code, follow the existing `app/lib/core/...` and `app/lib/features/<feature>/{data,domain,presentation}` layout unless an approved OpenSpec change or ADR says otherwise.

## OpenSpec Workflow (spec-driven)

Every non-trivial change flows through proposal → design → tasks → implementation → archive.

Harness slash commands (Claude Code form shown; equivalents exist under each harness dir):

- `/opsx:explore [topic]` — thinking-partner mode. **Do not implement.**
- `/opsx:propose <name-or-description>` — scaffolds a change and generates artifacts.
- `/opsx:apply [name]` — implements pending tasks from `tasks.md`.
- `/opsx:archive [name]` — moves a completed change to archive.

When to use which: vague idea → `explore`; ready to commit → `propose`; artifacts exist → `apply`; all tasks done → `archive`.

CLI:

```bash
openspec list --json                              # active changes
openspec new change "<kebab-case-name>"           # scaffold a change dir
openspec status --change "<name>" --json          # artifact build state
openspec instructions apply --change "<name>" --json
openspec validate --all --strict                  # validate artifacts
```

When following `openspec instructions` output, the JSON's `context` and `rules` blocks are constraints for **the agent** — never copy them into the artifact file.

## Build, Test, and Development Commands

Flutter/Dart commands, when the toolchain is available:

- `cd app && dart format --output=none --set-exit-if-changed .`
- `cd app && flutter analyze --fatal-infos`
- `cd app && flutter test`
- `cd app && dart run build_runner build --delete-conflicting-outputs` when generated Riverpod/drift/localization code must be refreshed.

Some local environments do not have Flutter/Dart installed. In that case, record the local limitation and rely on GitHub Actions for Flutter format/analyze/test, while still running `openspec validate --all --strict` and `git diff --check` locally.

## Multi-Chat Governance

GitHub Milestones and Issues are the project planning source of truth; this local repository is the implementation/specification/review surface. `docs/WORKFLOW.md` defines the current split — treat that file plus this one as the local workflow baseline.

Split responsibilities deliberately:

- **GitHub management chat**: maintain Milestones, Issues, PR metadata, CI/release status.
- **Local repository management chat**: manage `~/dev/projects/GeekPlayer`, update local docs/OpenSpec/code, review diffs, and issue implementation instructions.
- **Codex implementation sessions**: implement tasks, run available checks, and report concrete diffs/results. Codex should not independently widen scope.

When a GitHub Issue number or Milestone is not visible from the local-only chat, mark it as `TBD` locally rather than guessing.

## Coding Style & Naming Conventions

Prefer minimal, reversible changes. Do not introduce public behavior, persistence formats, APIs, CLIs, or compatibility expectations without an OpenSpec change.

Use kebab-case for OpenSpec change names, for example `add-playback-queue`. Keep Markdown concise and use fenced code blocks for commands. Follow the formatter and linter of the chosen stack once one exists.

## Testing Guidelines

No test framework or coverage target exists yet. New implementation work should define targeted tests alongside the chosen stack. Name tests after observable behavior, and keep them close to the code unless the stack establishes a separate convention such as `tests/`.

Before reporting completion, run relevant tests, lint/typecheck commands if available, OpenSpec validation when specs change, and `git diff --check`.

## Commit & Pull Request Guidelines

Always create a dedicated feature branch before starting feature/change work (e.g., `feature/<kebab-name>`); never commit feature work directly to `main`. Use one branch per OpenSpec change (or per coherent group of sequenced changes) and merge back via PR.

Before starting non-trivial development, documentation, release, or workflow work, make sure there is a GitHub Issue assigned to the appropriate Milestone in the GitHub management chat. Link the Issue from the related OpenSpec change and reference it in the PR.

Default mapping: one GitHub Issue → one OpenSpec change → one feature branch / PR. Split larger Issues into smaller OpenSpec changes only when the batch boundary, parent Issue, and validation reason are documented.

Use short imperative subjects such as `Add OpenSpec contributor guide`.

Pull requests should include the related OpenSpec change when applicable, a concise summary, validation commands and results, and screenshots only for UI-visible changes.

## Agent-Specific Instructions

OpenSpec is authoritative for local specifications, tasks, and acceptance criteria; GitHub Issues/Milestones are authoritative for planning and prioritization.

For implementation, use a test-first loop when behavior is clear. For bugs or unexplained failures, reproduce and diagnose before changing code. Codex should implement against the linked Issue/OpenSpec tasks and should not widen scope without returning to the reviewer/instruction chat.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, invoke the `skill` tool with `skill: "graphify"` before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
