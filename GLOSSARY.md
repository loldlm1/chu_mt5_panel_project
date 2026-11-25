# Chu Sniper Manager — glossary

- **Expert Advisor (EA):** MQL5 program attached to an MT5 chart.
- **Panel:** chart controls for order preparation and position management.
- **Position scope:** currently selected side and group mode, respecting `IncludeOtherPositions` and `Magic`.
- **Order plan:** entry price, stop loss, take profit, risk mode, volume and estimated loss.
- **Pending order:** a buy/sell stop or limit derived from planned entry versus current quote.
- **Break-even:** estimated closing price that offsets swap and allocated entry fees.
- **BE projection:** movable hypothetical closing level and estimated P/L; only an explicit Aplicar nivel click requests BE stop modifications. Its pinned side is selected from eligible holdings at activation; a fresh executable quote must strictly cross the requested level before exact/adapted application. Automatic trailing is independent.
- **Trailing stop:** objective/distance/hybrid stop tracking from favorable price movement.
- **Hedging eligibility:** operator-directed trading is supported on Demo and Real retail hedging accounts; development and verification remain Demo/Tester only.
- **Broker constraints:** fresh stops/freeze distances, tick size, Bid/Ask, permitted order modes and volume restrictions; OrderCheck and server retcodes remain authoritative.
- **Baseline:** original v0.12 source retained as the main branch's initial revision.
