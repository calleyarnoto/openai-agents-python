# PR Review Skill

This skill automates pull request review by analyzing code changes, checking for common issues, and providing structured feedback.

## What it does

- Analyzes diff of changed files in a pull request
- Checks for code style violations and potential bugs
- Verifies test coverage for new/modified code
- Summarizes changes and suggests improvements
- Posts a structured review comment to the PR

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `pr_number` | string | yes | The pull request number to review |
| `repo` | string | no | Repository in `owner/repo` format (defaults to current repo) |
| `review_level` | string | no | `light`, `standard`, or `thorough` (default: `standard`) |
| `post_comment` | boolean | no | Whether to post the review as a PR comment (default: `true`) |

## Outputs

| Name | Description |
|------|-------------|
| `review_summary` | Markdown-formatted review summary |
| `issues_found` | Number of issues identified |
| `approved` | Boolean indicating if changes look good to merge |

## Usage

```yaml
skill: pr-review
inputs:
  pr_number: "42"
  review_level: thorough
  post_comment: true
```

## Notes

- Requires `GITHUB_TOKEN` environment variable with `pull_requests: write` permission
- For large PRs (>500 changed lines), `thorough` review may take longer
- The skill respects `.agents/skills/code-change-verification` results when available
