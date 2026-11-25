# Chu Sniper Manager (MQL5)

Expert Advisor for MetaTrader 5. The source-of-truth entry point is `Experts/Chu_Sniper_Manager.mq5`.

## Baseline

The initial `main` commit imports original v0.12 logic from the supplied UTF-16 LE source, as GitHub-readable UTF-8 with the original characters/behavior preserved.

## Current version — v0.16.0

See [CHANGELOG.md](CHANGELOG.md) for the history of accepted updates and versioning conventions. The EA metadata is `#property version "0.160"`; the project version is v0.16.0. Track new work in [GitHub Issues](https://github.com/loldlm1/chu_mt5_panel_project/issues).

## Build (MetaEditor)

Place the `Experts/` tree under the MetaTrader 5 data folder's `MQL5/Experts/`, keeping the relative header paths unchanged. Open `Chu_Sniper_Manager.mq5` in MetaEditor and press **F7**.

The equivalent command-line call in a configured Windows/MetaEditor environment is:

```text
MetaEditor64.exe /compile:"<full path>/Chu_Sniper_Manager.mq5" /log
```

Review the resulting compiler log. Only a real compiler invocation with 0 errors qualifies as compile-pass evidence. Use a demo hedging account or MT5 Strategy Tester for runtime checks; no live trading.

## Workflow

The project reads `AGENTS.md`, `docs/agents/` and `GLOSSARY.md`. Matt Pocock's workflow in Codex CLI is the native reference; GitHub-only sessions may reproduce its issue/PR convention but cannot claim to run Codex CLI skills or delegates.

## Panel preferences

`PanelTheme` selects the original or Pandora panel palette. Chart style always follows Pandora. Drag the header or resize corner; minimize to quick market buttons. Per-chart state is stored in the terminal's MQL5 Files sandbox and keyed by a hidden chart-profile identity, account, symbol and magic. Keep the chart/profile to restore state; deleting it or the state file starts fresh. Tester runs do not restore saved state. Quick BUY/SELL uses configured SL points, R:B and current risk; it does not send the prepared manual order. Demo and Real hedging are supported; netting and contest accounts are view-only. Fresh panels default to 1% of balance per new entry, and existing preferences are restored. Grupo imposes no artificial group risk or position ceiling; broker volume and margin limits still apply.

## Broker protection

At preparation/edit and explicit confirmation, new entry levels are validated against current Bid/Ask, stops level and tick size. A changed manual projection requires confirmation again; quick market entries adapt automatically and send once, after OrderCheck. Money/percent sizing is recalculated using the effective stop. Fixed lots are preserved or rejected. Existing pending modifications and BE/trailing respect freeze constraints; automatic adaptations never weaken existing protection. No unprotected fallback or automatic order retry. Actual fills and losses can differ from estimates; accepted requests are not proof of a fill. All development/QA remains Demo/Tester only.

## Interactive BE preview

Break-even displays an estimated closing level for the selected side/scope. Drag the BE line freely and inspect the projected net P/L, balance percentage and retracement while moving it. Releasing or canceling a drag does not apply any BE-related broker modification. Only a separate deliberate click on `Aplicar nivel` applies the current projection through the existing per-ticket broker-aware BE logic. The estimate is not a realized result or a guarantee that every position can accept the level. Automatic trailing, when enabled, continues independently and may change actual stops during preview. Demo and Real hedging compatibility is a continuing requirement; development verification remains Demo/Tester only.

On BE activation, a sole eligible direction is selected automatically; if both BUY and SELL are open, use the selected side. A prepared order keeps its own direction and prices; the BE side is labeled and persisted separately. Existing CSM140 state is read and upgraded to CSM160 on save. At explicit Apply, each position requires its fresh executable quote to have strictly crossed the requested BE (Bid > BE for BUY, Ask < BE for SELL). Otherwise no stop modification is sent. After crossing, exact or existing broker-aware improving adaptation is allowed; frozen/rejected/no-improvement tickets retain their protection. No deferred execution. Automatic trailing does not use this crossing requirement.
