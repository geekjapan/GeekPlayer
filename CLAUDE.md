# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository status

GeekPlayer is an active Flutter/Dart application, not a greenfield scaffold. The app source lives under `app/`; tests, CI workflows, OpenSpec artifacts, ADRs, release docs, and cross-agent workflow files already exist. Before changing behavior, inspect the existing code, accepted specs, active OpenSpec changes, and relevant ADRs rather than assuming conventions need to be created from scratch.

Current project coordination is documented in `docs/WORKFLOW.md`. Treat that file, this file, and `AGENTS.md` as the local repository workflow baseline.

## Workflow: multi-chat governance

GitHub Milestones and Issues are the project planning source of truth. This local repository is the implementation/specification/review surface that mirrors GitHub decisions into OpenSpec artifacts, code, tests, and documentation.

Because the operating chat may not expose DevSpace and GitHub tools together, split responsibilities deliberately:

- GitHub management chat: maintain Milestones, Issues, PR metadata, CI/release status.
- Local repository management chat: manage `~/dev/projects/GeekPlayer`, update local docs/OpenSpec/code, review diffs, and issue implementation instructions.
- Codex implementation sessions: implement tasks, run available checks, and report concrete diffs/results. Codex should not independently widen scope beyond the linked Issue/OpenSpec change.

When a GitHub Issue number or Milestone is not visible from the local-only chat, do not invent it. Mark it as `TBD` locally and let the GitHub management chat reconcile it.

## Workflow: OpenSpec (spec-driven)

This project uses the [OpenSpec](https://github.com/openspec) experimental workflow. `openspec/config.yaml` declares `schema: spec-driven`, meaning every non-trivial change is expected to flow through proposal → design → tasks → implementation → archive.

Slash commands (defined in `.claude/commands/opsx/`):

- `/opsx:explore [topic]` — thinking-partner mode. Read code, sketch options, but **do not implement**. May produce OpenSpec artifacts.
- `/opsx:propose <name-or-description>` — scaffolds a change at `openspec/changes/<name>/` and generates `proposal.md`, `design.md`, `tasks.md` in dependency order.
- `/opsx:apply [name]` — implements pending tasks from a change's `tasks.md`, ticking checkboxes as it goes.
- `/opsx:archive [name]` — moves a completed change into `openspec/changes/archive/`.

The OpenSpec commands/skills are mirrored under `.agents/`, `.claude/`, `.codex/`, and `.pi/` so agent harnesses see the same workflow. Keep these directories in sync when modifying workflow skills.

### OpenSpec CLI

The slash commands shell out to an `openspec` CLI. Commonly invoked subcommands:

```bash
openspec list --json                              # active changes
openspec new change "<name>"                      # scaffold a change dir
openspec status --change "<name>" --json          # artifact build state + applyRequires
openspec instructions <artifact-id> --change "<name>" --json
openspec instructions apply --change "<name>" --json
```

When following `openspec instructions` output, the JSON's `context` and `rules` blocks are constraints for **you** — never copy them into the artifact file. Use `template` as the file's structure.

### When to use which command

- Vague idea, no commitment yet → `/opsx:explore`
- Ready to commit to building something → `/opsx:propose`
- Artifacts exist, time to code → `/opsx:apply`
- All tasks checked off → `/opsx:archive`

`/opsx:apply` may be invoked mid-workflow (before every artifact is done) and may surface design issues that require pausing to update artifacts. It is fluid, not phase-locked.

## Directory layout

- `openspec/config.yaml` — schema declaration; add `context:` and per-artifact `rules:` here when project conventions stabilize.
- `openspec/changes/` — active changes, each in its own subdirectory with proposal/design/tasks artifacts.
- `openspec/changes/archive/` — completed changes.
- `openspec/specs/` — capability specs (created as changes land).
- `.agents/`, `.claude/`, `.codex/`, `.pi/` — per-harness skill and command definitions; identical OpenSpec skills under each.

## Conventions

- **Branch per feature (always)**: before starting any feature/change implementation, create a dedicated feature branch off the default branch (e.g., `feature/<kebab-name>`). Never commit feature work directly to `main`. One branch per OpenSpec change (or per coherent group of sequenced changes); merge back via PR.
- **GitHub Milestone / Issue tracking (always for non-trivial work)**: roadmap and development work is tracked through GitHub Milestones and Issues. Before starting non-trivial implementation, docs, release, or workflow work, confirm or create the matching GitHub Issue and assign it to the appropriate Milestone in the GitHub management chat. Link that Issue from the related OpenSpec change and reference it in the PR. If the local-only chat cannot verify the Issue, record `GitHub Issue: TBD` rather than guessing.
- **Issue → OpenSpec → branch/PR alignment**: default to one GitHub Issue per OpenSpec change and one branch/PR per change. Split only when a CI-friendly or review-friendly batch boundary is explicitly documented.
- Change names are kebab-case (e.g., `add-user-auth`), derived from a short description of the work.
- Task checkboxes in `tasks.md` are toggled `- [ ]` → `- [x]` immediately on completion, one at a time.
- `openspec/config.yaml` is the right place to record project-wide context (tech stack, domain, commit style) once decided — it propagates into every artifact's generation context.
