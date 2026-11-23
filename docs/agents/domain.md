# Domain documentation

Single-context Expert Advisor project. Read root `GLOSSARY.md` before modifying code, and read applicable ADRs under `docs/adr/` if they exist.

Retain these terms consistently in issues, tests, code and documentation:
- **EA:** the chart-attached Expert Advisor.
- **panel:** clickable chart interface and preview.
- **position scope:** one selected position or a group, restricted by symbol, direction and optional magic filter.
- **order plan:** entry, stop loss, take profit, estimated loss and volume before order submission.
- **break-even:** cost-adjusted level estimated from positions and deals.
- **trade management:** stop improvement, trailing, realized-profit partial closes and close-all.
- **demo/hedging gate:** account eligibility for execution.

Do not invent a new domain model or persistence layer for a structural refactor. Raise conflicting existing decisions explicitly.
