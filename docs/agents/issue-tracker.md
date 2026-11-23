# Issue tracker: GitHub

Issues and specs live in [loldlm1/chu_mt5_panel_project](https://github.com/loldlm1/chu_mt5_panel_project/issues).

## Conventions
- In Codex CLI, use `gh issue create/view/edit` after confirming `gh repo view --json nameWithOwner` targets this repository.
- This ChatGPT session may use the connected GitHub integration instead of `gh`, but must report missing native API operations.
- Publish one parent story/spec issue, then child tickets in blocker-first order.
- Use native sub-issues and dependencies if the available GitHub interface supports them. Otherwise put `Part of #<parent>` and `Blocked by #<issue>` explicitly in ticket bodies.
- A ticket with open blockers is not ready to start. Do not close the parent story before all work is accepted.
- Link the PR to the story and tickets; final merge and issue closure require user acceptance.
- Use `ready-for-agent` when the label exists, and record readiness in the issue body if it is unavailable.

## Pull requests as a triage surface
**PRs as a request surface: no.** Only dedicated issues are triaged.
