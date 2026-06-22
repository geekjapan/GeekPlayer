# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See [AGENTS.md](AGENTS.md) for project structure, build/test commands, coding style, commit/PR conventions, and graphify usage.

## Repository status

GeekPlayer is an active Flutter/Dart application, not a greenfield scaffold. Before changing behavior, inspect the existing code, accepted specs, active OpenSpec changes, and relevant ADRs.

Current project coordination is documented in `docs/WORKFLOW.md`. Treat that file, this file, and `AGENTS.md` as the local repository workflow baseline.

## Workflow: multi-chat governance

GitHub Milestones and Issues are the project planning source of truth. This local repository is the implementation/specification/review surface.

Split responsibilities deliberately:

- **GitHub management chat**: maintain Milestones, Issues, PR metadata, CI/release status.
- **Local repository management chat**: manage `~/dev/projects/GeekPlayer`, update local docs/OpenSpec/code, review diffs, and issue implementation instructions.
- **Codex implementation sessions**: implement tasks, run available checks, and report concrete diffs/results. Codex should not independently widen scope.

When a GitHub Issue number or Milestone is not visible from the local-only chat, mark it as `TBD` locally.

## Workflow: OpenSpec (spec-driven)

This project uses [OpenSpec](https://github.com/openspec). `openspec/config.yaml` declares `schema: spec-driven`, meaning every non-trivial change flows through proposal → design → tasks → implementation → archive.

Slash commands (defined in `.claude/commands/opsx/`):

- `/opsx:explore [topic]` — thinking-partner mode. **Do not implement.**
- `/opsx:propose <name-or-description>` — scaffolds a change and generates artifacts.
- `/opsx:apply [name]` — implements pending tasks from `tasks.md`.
- `/opsx:archive [name]` — moves a completed change to archive.

The OpenSpec commands/skills are mirrored under `.agents/`, `.claude/`, `.codex/`, and `.pi/`. Keep these in sync when modifying workflow skills.

### OpenSpec CLI

```bash
openspec list --json                              # active changes
openspec new change "<name>"                      # scaffold a change dir
openspec status --change "<name>" --json          # artifact build state
openspec instructions apply --change "<name>" --json
```

When following `openspec instructions` output, the JSON's `context` and `rules` blocks are constraints for **you** — never copy them into the artifact file.

### When to use which command

- Vague idea → `/opsx:explore`
- Ready to commit → `/opsx:propose`
- Artifacts exist → `/opsx:apply`
- All tasks done → `/opsx:archive`
