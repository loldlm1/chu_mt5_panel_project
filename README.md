# Chu Sniper Manager (MQL5)

Expert Advisor for MetaTrader 5. The source-of-truth entry point is `Experts/Chu_Sniper_Manager.mq5`.

## Baseline

The initial `main` commit imports original v0.12 logic from the supplied UTF-16 LE source, as GitHub-readable UTF-8 with the original characters/behavior preserved.

## Scope of the first change

Reorganize the current single-file EA into small MQL5 headers without changing trading behavior or the public inputs. See the parent story and tickets under [GitHub Issues](https://github.com/loldlm1/chu_mt5_panel_project/issues).

## Build (MetaEditor)

Place the `Experts/` tree under the MetaTrader 5 data folder's `MQL5/Experts/`, keeping the relative header paths unchanged. Open `Chu_Sniper_Manager.mq5` in MetaEditor and press **F7**.

The equivalent command-line call in a configured Windows/MetaEditor environment is:

```text
MetaEditor64.exe /compile:"<full path>/Chu_Sniper_Manager.mq5" /log
```

Review the resulting compiler log. Only a real compiler invocation with 0 errors qualifies as compile-pass evidence. Use a demo hedging account or MT5 Strategy Tester for runtime checks; no live trading.

## Workflow

The project reads `AGENTS.md`, `docs/agents/` and `GLOSSARY.md`. Matt Pocock's workflow in Codex CLI is the native reference; GitHub-only sessions may reproduce its issue/PR convention but cannot claim to run Codex CLI skills or delegates.
