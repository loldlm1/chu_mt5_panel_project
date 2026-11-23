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
- Preserve the existing public EA inputs, chart UI behavior, order calculations, magic-number and symbol filters, demo/hedging gates, pending-order logic, partial closes, break-even and trailing semantics.
- Do not silently alter order execution, risk formulas, or account eligibility while performing a structural refactor.
- Keep `Experts/Chu_Sniper_Manager.mq5` as the EA entry point. Local modules live under `Experts/ChuSniper/`.
- A no-errors MetaEditor compilation and manual behavior checks are required acceptance evidence. Static comparisons are useful but are NOT compilation or runtime verification.
- Never place real trades or use live-account verification. Test only in MetaTrader demo/Strategy Tester.
- Avoid unrelated infrastructure, repeated end-to-end tests, artificial coverage targets, generated reports, and unnecessary filesystem artifacts.
- Create changes in a review branch and PR. Never merge into `main` without the owner's explicit authorization.
- When MetaEditor is unavailable, report the exact blocker and request the user's MetaEditor compilation log; do not claim the code compiled.
