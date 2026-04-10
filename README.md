# Git Actions

A monorepo containing shared GitHub Actions and reusable workflows for meldoc repositories.

## Structure

Each action or reusable workflow is stored in its own directory under `actions/`:

```
git-actions/
├── actions/
│   ├── example-action/      # Example action structure
│   │   ├── action.yml       # Action metadata and definition
│   │   └── README.md        # Action-specific documentation
│   └── [other-actions]/     # Each action in its own directory
│       ├── action.yml
│       └── ...
└── .github/
    └── workflows/
        └── release.yml      # Automated release workflow
```

## Using Actions

Actions from this repository can be used in your workflows by referencing the action path and tag:

```yaml
- uses: meldoc-io/git-actions/actions/action-name@action-name/v1.0.0
```

### Example

```yaml
name: My Workflow
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: meldoc-io/git-actions/actions/example-action@example-action/v1.0.0
        with:
          input1: 'custom-value'
```

## Adding a New Action

1. Create a new directory under `actions/` with your action name:
   ```bash
   mkdir -p actions/my-new-action
   ```

2. Create an `action.yml` file in the new directory:
   ```yaml
   name: 'My New Action'
   description: 'Description of what this action does'
   inputs:
     input1:
       description: 'Input description'
       required: true
   runs:
     using: 'composite'
     steps:
       - run: echo "Action implementation"
         shell: bash
   ```

3. Create a `README.md` file documenting your action:
   - Usage examples
   - Input/output descriptions
   - Any additional documentation

4. Commit and push your changes. The release workflow will automatically:
   - Detect the new action
   - Create an initial version tag (v1.0.0)
   - Create a GitHub Release

## Versioning

Actions are versioned independently using Semantic Versioning (SemVer) in the format:
```
{action-name}/v{major}.{minor}.{patch}
```

Examples:
- `example-action/v1.0.0`
- `cc-pr-review/v2.1.3`

### Automatic Version Bumping

The release workflow automatically determines the version bump type based on commit messages using [Conventional Commits](https://www.conventionalcommits.org/):

- **Major** (`v1.0.0` → `v2.0.0`): Breaking changes
  - Commit messages containing `break!`, `breaking!`, or `!:` trigger a major bump
- **Minor** (`v1.0.0` → `v1.1.0`): New features
  - Commit messages starting with `feat:` or `feature:` trigger a minor bump
- **Patch** (`v1.0.0` → `v1.0.1`): Bug fixes and other changes
  - Commit messages starting with `fix:` or `bugfix:` trigger a patch bump
  - Default for other changes

### Manual Release

You can manually trigger a release for a specific action:

1. Go to the **Actions** tab in GitHub
2. Select the **Release Actions** workflow
3. Click **Run workflow**
4. Choose:
   - **Action name**: The specific action to release (leave empty to auto-detect all changed actions)
   - **Version bump**: The type of version bump (major, minor, patch)

## Release Workflow

The `release.yml` workflow automatically:

1. **Detects Changes**: On push to `main`/`master`, it identifies which actions have been modified
2. **Determines Version**: Calculates the next version based on:
   - Previous tags for the action
   - Commit message types (conventional commits)
   - Manual version bump selection (if triggered manually)
3. **Creates Tags**: Creates a new tag in the format `{action-name}/v{version}`
4. **Generates Release Notes**: Creates release notes from commit messages
5. **Creates GitHub Release**: Publishes a release with the tag and notes

## Supported Action Types

This repository supports:

- **Composite Actions**: Actions defined with `action.yml` using the `composite` runs type
- **Reusable Workflows**: Workflows defined with `.yml` files in `.github/workflows/` (to be added)

## Contributing

When making changes to actions:

1. Follow [Conventional Commits](https://www.conventionalcommits.org/) for commit messages to ensure proper versioning
2. Update the action's `README.md` if you change inputs, outputs, or behavior
3. Test your action before pushing
4. The release workflow will handle versioning and release creation automatically

## Examples

See the `actions/example-action/` directory for a complete example of an action structure.
