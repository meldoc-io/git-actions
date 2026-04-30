# Sync Meldoc Documentation

Composite GitHub Action that pulls the latest documentation from the Meldoc platform and opens (or updates) a pull request whenever the local checkout diverges from the server.

Designed to be run on a cron schedule so that edits made directly in Meldoc end up back in the repository as a reviewable PR.

## Quick Start

```yaml
# .github/workflows/sync-docs.yml
name: Sync Docs from Meldoc

on:
  schedule:
    - cron: '0 18 * * *' # daily at 18:00 UTC
  workflow_dispatch: {}

# Avoid overlapping runs (e.g. cron + manual dispatch)
concurrency:
  group: sync-docs
  cancel-in-progress: false

permissions:
  contents: write
  pull-requests: write

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout default branch
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Sync from Meldoc
        uses: meldoc-io/git-actions/actions/sync-docs@sync-docs/v1
        with:
          token: ${{ secrets.MELDOC_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          base_branch: main
          auto_merge: false
```

### Version Options

- **Major version tag** (recommended): `@sync-docs/v1` — automatically uses the latest v1.x.x release
- **Specific version**: `@sync-docs/v1.0.0` — pins to an exact version
- **Latest from main**: `@main` — not recommended for production

## What This Action Does

1. **Checks the token** — exits gracefully with a `::notice::` annotation if `token` is empty
2. **Installs the Meldoc CLI** via the official install script
3. **Pulls documentation** with `meldoc pull --token <token> <pull_args>`. The default `--local --yes` only updates files that already exist locally and never adds new ones — safe for an unattended cron
4. **Computes the diff** by walking `git status --porcelain` filtered by the `paths` globs (modified, added, renamed, untracked)
5. **Skips quietly** if there are no changes — emits `::notice::`, leaves no PR behind
6. **Opens or updates a PR** via `peter-evans/create-pull-request@v7`, committing only the files matching `paths`
7. **Optionally enables auto-merge** when `auto_merge: true`, using the requested `merge_method`

## Inputs

| Input            | Required | Default                                     | Description                                                                                                                                                |
| ---------------- | -------- | ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `token`          | Yes      | —                                           | Meldoc authentication token. The action exits with a notice when empty so a missing secret does not fail the workflow                                      |
| `github_token`   | Yes      | —                                           | GitHub token used to push the sync branch and open the PR. Needs `contents: write` and `pull-requests: write`                                              |
| `base_branch`    | No       | (repo default)                              | Branch the PR targets. Empty string lets `peter-evans/create-pull-request` pick the repository default                                                     |
| `pr_branch`      | No       | `docs/auto-sync`                            | Head branch the action pushes to. Reused across runs — the same PR is updated when new changes arrive                                                      |
| `pr_title`       | No       | `chore(docs): sync from Meldoc`             | PR title                                                                                                                                                   |
| `commit_message` | No       | `chore(docs): sync from Meldoc`             | Commit message used for the synced changes                                                                                                                 |
| `labels`         | No       | `documentation,automated`                   | Comma-separated labels applied to the PR                                                                                                                   |
| `paths`          | No       | `**/*.meldoc.md\nmeldoc.config.yml`         | Newline-separated globs. Files outside these globs are ignored both for diff detection and for the commit, so unrelated working-tree noise stays out       |
| `pull_args`      | No       | `--local --yes`                             | Extra arguments passed to `meldoc pull`. See `meldoc pull --help` for options like `--tracked`, `--resolve <ours\|theirs\|merge>`, `--no-assets`           |
| `auto_merge`     | No       | `false`                                     | When `true`, enables GitHub auto-merge on the PR. Requires the repository setting "Allow auto-merge"                                                       |
| `merge_method`   | No       | `squash`                                    | Merge method passed to `gh pr merge --auto`: `merge`, `squash`, or `rebase`                                                                                |

## Outputs

| Output          | Description                                                              |
| --------------- | ------------------------------------------------------------------------ |
| `has_changes`   | `true` when `meldoc pull` produced changes that match `paths`            |
| `changed_files` | Newline-separated list of changed files (empty when `has_changes=false`) |
| `pr_number`     | Number of the created/updated PR                                         |
| `pr_url`        | URL of the created/updated PR                                            |

## Required Permissions

The job using this action needs:

```yaml
permissions:
  contents: write       # push the sync branch
  pull-requests: write  # create / update the PR (and auto-merge)
```

`secrets.GITHUB_TOKEN` is enough for both. If you also want PRs to trigger downstream `pull_request` workflows, pass a GitHub App token instead — pushes authenticated by `GITHUB_TOKEN` do not fire those events.

## Behavior

### Cron / scheduled runs

This is the primary use case. Pair the action with a `schedule:` trigger and a stable `pr_branch` so the same PR is updated as new server-side edits arrive.

### Manual `workflow_dispatch`

Works the same as the cron run. Useful for forcing a sync after editing on the platform.

### No changes

Emits a `::notice::` annotation and exits with `has_changes=false`. The job stays green and no PR is created.

### Auto-merge for clean syncs

Set `auto_merge: true` when you trust the platform-side editor and want the PR to merge on its own once CI is green. The action calls `gh pr merge --auto --<merge_method>` after the PR is created or updated.

## Token Setup

1. Generate a Meldoc token in your workspace settings
2. Store it as a GitHub repository secret (e.g. `MELDOC_TOKEN`)
3. Pass it to the action via the `token` input

If the token is missing or empty, the action skips itself with a notice annotation rather than failing — handy when you copy the workflow to a repo before the secret is provisioned.

## Notes

- The default `pull_args=--local --yes` deliberately avoids creating new files locally. If you also want platform-only docs to be pulled into the repo, drop `--local` (the action will then commit any new `*.meldoc.md` it sees)
- `paths` is also passed to `peter-evans/create-pull-request` as `add-paths`, so the commit contains exactly what the diff step reported — nothing more
- The PR branch (`pr_branch`) is reused across runs and not deleted; this keeps a single rolling sync PR instead of opening a new one each day
