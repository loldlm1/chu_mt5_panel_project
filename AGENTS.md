# Project instructions — Chu Sniper Manager

Follow the applicable global Codex instructions from the active `.codex/AGENTS.md` and its `workflow/` references when running in Codex CLI. Project constraints below take precedence where more specific.

## Agent skills

### Issue tracker
Stories, specifications and tickets live in this repository's GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels
Use Matt's five canonical triage roles when available; where the host cannot create labels, the issue body carries its status. See `docs/agents/triage-labels.md`.

### Domain docs
Single-context MQL5 project. Read `GLOSSARY.md` and applicable `docs/adr/` entries. See `docs/agents/domain.md`.

## Engineering scope
- Use Matt-only engineering flow: setup → specification → tickets → implementation → independent Standards/Spec review → pull request.
- Favor small, readable MQL5 modules and explicit descriptive names; do not add external libraries or speculative abstractions.
- Preserve the existing public EA inputs, chart UI behavior, order calculations, magic-number and symbol filters, approved Demo/Real hedging eligibility gates, pending-order logic, partial closes, break-even and trailing semantics.
- Do not silently alter order execution, risk formulas, or account eligibility while performing a structural refactor.
- Keep `Experts/Chu_Sniper_Manager.mq5` as the EA entry point. Local modules live under `Experts/ChuSniper/`.
- A no-errors MetaEditor compilation and manual behavior checks are required acceptance evidence. Static comparisons are useful but are NOT compilation or runtime verification.
- The EA supports operator-directed execution in Demo and Real hedging accounts as explicitly approved in story #22. Development, agent actions and verification must never place real trades or use live-account verification. Test only in MetaTrader demo/Strategy Tester.
- Avoid unrelated infrastructure, repeated end-to-end tests, artificial coverage targets, generated reports, and unnecessary filesystem artifacts.
- Create changes in a review branch and PR. Never merge into `main` without the owner's explicit authorization.
- When MetaEditor is unavailable, report the exact blocker and request the user's MetaEditor compilation log; do not claim the code compiled.

## Versioning and changelog
- Every accepted code update delivered through a PR must increment the project version and update `CHANGELOG.md`, the current version in `README.md`, and `#property version` in the main EA, before the authorized squash merge.
- Use project versions `MAJOR.MINOR.PATCH`: increment MINOR for new functionality, PATCH for compatible fixes, and MAJOR for breaking releases. Use one version per merged update, not per intermediate QA commit.
- MQL5's two-component metadata maps `MAJOR.MINOR.PATCH` to `MAJOR.YYY`, where YYY is MINOR × 10 + PATCH padded to three digits (e.g. 0.13.0 → 0.130; 0.13.1 → 0.131; 0.14.0 → 0.140). Carry into the next minor after patch 9, or major after minor 99, to keep the metadata strictly increasing. The project changelog uses the three-component version; do not claim Market compatibility without a real compiler check.
- Identify the version in the PR and squash commit; use a matching Git tag when the host supports it. No deployment, Market publication or GitHub Release is implicit in a merge.
- For a version-only metadata change after user QA, verify the exact diff contains no executable change; report that the new metadata has not been compiled if MetaEditor is unavailable.
