# Publish Meldoc Documentation

Composite GitHub Action that publishes documentation to the Meldoc platform. It installs the Meldoc CLI and delegates all change detection and publishing logic to `meldoc ci`.

## Quick Start

Add this to your workflow:

```yaml
# .github/workflows/publish-docs.yml
name: Publish Documentation

on:
  push:
    branches:
      - main
    paths:
      - '**/*.meldoc.md'
      - 'meldoc.config.yml'
  workflow_dispatch:
    inputs:
      publish_all:
        description: 'Publish all documentation (ignore diff)'
        type: boolean
        default: false

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Full history for accurate diff

      - name: Publish documentation
        uses: meldoc-io/git-actions/actions/publish-docs@main
        with:
          token: ${{ secrets.MELDOC_TOKEN }}
          publish_all: ${{ github.event.inputs.publish_all == 'true' }}
```

### Version Options

You can use different version formats:

- **Major version tag** (recommended): `@publish-meldoc-docs/v1` - automatically uses the latest v1.x.x release
- **Specific version**: `@publish-meldoc-docs/v1.0.0` - pins to exact version
- **Latest from branch**: `@main` - uses latest from main branch (not recommended for production)

## Inputs

| Input         | Required | Default | Description                                              |
| ------------- | -------- | ------- | -------------------------------------------------------- |
| `token`       | Yes      | —       | Meldoc authentication token                              |
| `publish_all` | No       | `false` | Publish all documentation files, ignoring diff detection |

## What This Action Does

The action performs the following steps:

1. **Checks token**: If token is not provided, the action skips execution gracefully
2. **Installs Meldoc CLI**: Downloads and installs the Meldoc CLI tool
3. **Publishes documentation**: Runs `meldoc ci` which handles change detection and publishing automatically
   - If `publish_all=true` on manual trigger: runs with `--all` flag to publish everything
   - Otherwise: the CLI detects changed files and publishes only what's needed

## Behavior

### Push Events

On `push` events, `meldoc ci` automatically detects changed documentation files and publishes only the differences.

### Manual Trigger

For `workflow_dispatch` events:

- If `publish_all=true`: publishes all documentation files (`meldoc ci --all`)
- Otherwise: runs standard change detection via `meldoc ci`

### Token Handling

- The `token` input is required
- The action will check if the token is empty and skip execution gracefully if it is

## Required Permissions

No special permissions are required. The action only needs:

- `contents: read` - to read repository files (default permission)

## Meldoc Token Setup

You need to create a Meldoc authentication token and store it as a GitHub secret:

1. Generate a token in your Meldoc workspace
2. Add it as a GitHub secret named `MELDOC_TOKEN` (or any name you prefer)
3. Pass it to the action via the `token` input
