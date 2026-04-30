# Review Meldoc Documentation

Composite GitHub Action that runs an **advisory** AI review of pull requests from the perspective of Meldoc documentation: is the doc in sync with the code, and is the doc itself healthy.

## What it checks

- **Code changed, doc did not** — when changed code affects documented behavior (public API, contracts, flags, schema), flags that the related `*.meldoc.md` may need an update.
- **Doc changed** — checks frontmatter validity, broken links, markdown health, and claims about code that no longer hold.
- **Both changed** — verifies the doc and code changes are consistent with each other.

It finds related docs **semantically** — by symbols, feature names, and path proximity — so you don't need a fixed naming convention between code and docs.

## Advisory only

This action never demands changes. It posts **one sticky** PR comment with findings phrased as suggestions ("consider updating…", "this may need to reflect…"). If nothing is off, it says so.

The comment is identified by an HTML marker (`<!-- meldoc-review:v1 -->`) so re-runs on the same PR **update the same comment** instead of stacking new ones on every push.

No MCP servers required — everything runs against the local checkout.

## Comment shape

The model picks one of three terse templates:

**A. No doc update needed** (code change touched no documented behavior):

```
**Meldoc** — no doc update needed for this change.

<sub>Advisory only · [job log](…)</sub>
```

**B. Docs and code look in sync** (a doc was touched, or both, and they line up):

```
**Meldoc** — docs and code look in sync.

<sub>Advisory only · [job log](…)</sub>
```

**C. Findings**:

```
### Meldoc Review — N possible drift item(s), advisory only

- `path/to/file.ts` — what's off, suggested action
- `path/to/doc.meldoc.md` — what's off, suggested action

<sub>Advisory only · authors decide what to act on · [job log](…)</sub>
```

One bullet per file (issues combined). Suggestion language only ("consider…", "may need to reflect…") — never "must" or "required".

## Quick Start

```yaml
# .github/workflows/review-docs.yml
name: Review Docs
on:
  pull_request: # opened + synchronize + reopened by default

permissions:
  contents: read
  pull-requests: write
  id-token: write
  actions: read

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: meldoc-io/git-actions/actions/review-docs@review-docs/v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Version Options

- **Major version tag** (recommended): `@review-docs/v1` — automatically uses the latest v1.x.x release
- **Specific version**: `@review-docs/v1.0.0` — pins to an exact version
- **Latest from main**: `@main` — not recommended for production

## When does it run?

Plain `on: pull_request:` already covers the default activity types `opened`, `synchronize`, `reopened`. **`synchronize` fires on every new push to the PR head, including after a rebase** (rebase = force-push of rewritten commits) — so re-runs on new commits and rebases are automatic, no extra config needed.

The sticky-comment script keeps that clean: every re-run finds the existing comment by its HTML marker and patches it in place instead of posting a new one. One PR = one live advisory comment.

### Manual re-run via label

When you want to re-trigger the review without pushing a new commit (e.g. after editing a `*.meldoc.md` file you previously skipped), add `labeled` to the trigger and gate the job on a specific label:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, labeled]

jobs:
  review:
    if: github.event.action != 'labeled' || github.event.label.name == 'rerun:meldoc'
    runs-on: ubuntu-latest
    steps:
      - uses: meldoc-io/git-actions/actions/review-docs@review-docs/v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Remove rerun label
        if: always() && github.event.action == 'labeled' && github.event.label.name == 'rerun:meldoc'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: gh pr edit ${{ github.event.pull_request.number }} --remove-label 'rerun:meldoc' --repo ${{ github.repository }}
```

Apply the `rerun:meldoc` label to force a re-run; the cleanup step removes it so the same trick works again next time.

## Inputs

| Input               | Required | Default                                                          | Description                                                                                                                                                                                                                                                                                |
| ------------------- | -------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `anthropic_api_key` | Yes      | —                                                                | Anthropic API key                                                                                                                                                                                                                                                                          |
| `prompt`            | No       | *(built-in)*                                                     | Full override for the review prompt. The PR context header is still prepended                                                                                                                                                                                                              |
| `allowed_tools`     | No       | `Read,Grep,Glob,Write,Bash(gh pr diff:*),Bash(gh pr view:*)`     | Comma-separated list of allowed Claude tools. Must include `Write` so the model can save the comment body for the post-step                                                                                                                                                                |
| `track_progress`    | No       | `"false"`                                                        | Show progress tracking comments on the PR. Setting `"true"` forces tag mode in `claude-code-action`, which wraps the prompt in a generic PR-reviewer system prompt and dilutes the Meldoc instructions on large diffs                                                                       |
| `allowed_bots`      | No       | `""`                                                             | Comma-separated list of bot accounts allowed to trigger reviews, or `'*'` for all. `claude-code-action` rejects bot-initiated runs by default — listed bots bypass that check. Empty by default; override at the call site to also review release/dependency-bot PRs                       |
| `comment_marker`    | No       | `<!-- meldoc-review:v1 -->`                                      | HTML marker used to identify and update the sticky comment across re-runs. Bump the version suffix when you change the comment shape so old comments aren't overwritten                                                                                                                    |
| `strict`            | No       | `"false"`                                                        | When `"true"`, fail the workflow step if the review reports findings. The comment is still posted before the failure. Default keeps the action advisory — sticky comment posted, step always succeeds                                                                                       |

## Outputs

| Output   | Description                                                                                                                                                  |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `status` | Review outcome detected from the comment body — one of `clean`, `findings`, or `unknown` (e.g. when the model failed to produce a comment). Useful for conditional downstream steps without enabling `strict` |

## Strict mode (opt-in)

By default the action is **advisory**: it posts a comment and the step always succeeds. If you want CI to gate on doc/code drift, enable `strict`:

```yaml
- uses: meldoc-io/git-actions/actions/review-docs@review-docs/v1
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    strict: 'true'
```

In strict mode, when the model produces a Template C body (`status=findings`), the post-step **posts the comment first**, then exits 1 — so authors see exactly what to address before CI turns red. `status=clean` and `status=unknown` (e.g. the model failed to produce a comment) never fail the step.

If you want finer control, skip `strict` and branch on the `status` output:

```yaml
- id: review
  uses: meldoc-io/git-actions/actions/review-docs@review-docs/v1
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}

- if: steps.review.outputs.status == 'findings'
  run: echo "::warning::Meldoc review found drift items — see PR comment."
```

## Threshold

- Purely internal changes (refactors, perf, logs, test fixtures) — no flag, even if a related doc exists
- Public-facing changes (signatures, contracts, flags, schema) — flag if the doc wasn't updated
- Code with no related doc — no flag (not everything needs documenting)

## Required Permissions

```yaml
permissions:
  contents: read        # read repo files
  pull-requests: write  # post the sticky advisory comment
  id-token: write       # OIDC token for claude-code-action
  actions: read         # read workflow run info (job log link, run metadata)
```

All four are required — `claude-code-action` reads run metadata via the GitHub API, so omitting `actions: read` produces 403s on the upstream step.

## How it works

```text
checkout
   ↓
anthropics/claude-code-action  ← agent mode (no prompt wrapping)
   • The model reads the PR via `gh pr diff` / `gh pr view`
   • Picks one of three comment templates (A, B, C above)
   • Saves the rendered body to $RUNNER_TEMP/meldoc-comment.md
   ↓
scripts/sticky-comment.sh  ← runs even if the model failed (`if: always()`)
   • Looks for an existing PR comment containing the marker
   • PATCH /issues/comments/{id} if found, else POST /issues/{n}/comments
```

The post-step requires `gh` and `jq` (both present on standard `ubuntu-latest` runners) and uses the workflow's default `GITHUB_TOKEN`.

## Pairing with other actions

This action targets **doc/code drift** specifically. Run it in its own job alongside any general code-review action — they don't interfere and post distinct comments.

```yaml
jobs:
  review-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: meldoc-io/git-actions/actions/review-docs@review-docs/v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

See also [`publish-docs`](../publish-docs) (push-triggered publisher) and [`sync-docs`](../sync-docs) (cron-triggered sync from Meldoc to a PR).
