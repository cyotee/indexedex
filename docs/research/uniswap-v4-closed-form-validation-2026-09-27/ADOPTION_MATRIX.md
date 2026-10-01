# Closed-form adoption matrix

Date: 2026-09-27. Recommendation: **adopt none**.

| ID | Status | Why |
|---|---|---|
| CF-R | `REFUTED` as a 1 bp integer repair | Production `SwapMath` at the fee-bearing root misses by 2 bp. The uncapped root also needs about 465 bp of price movement, outside the 25 bp cap. |
| CF-M | `CONTINUOUS_ONLY` | The pre-swap sizing shortcut misses by 102 bp in the Python swap vector. The full post-mint repair chain was not integer-certified. |
| CF-D | `REFUTED` for adoption | It depends on CF-R for the maintenance leg. |
| CF-X | `UNRESOLVED` | External removal-then-swap was not executed against PoolManager. Do not treat the blocked inverse as this route. |
| CF-B | `REFUTED` as a universal inverse | Production `_singleExit(50, 50, 13, 100)` returns 11, short of requested 12. The predecessor also returns 11. |
| CF-U | `UNRESOLVED` | Dual-output plus repair was not simulated as a combined transition. |
| CF-G | `REFUTED` for the two-check claim | `supply=1000`, reserves `50`, output `5`: candidates 52 and 53 both forward to 3. |
| CF-Q | `REFUTED` | Sizing goes through `UniswapV4Quoter`, whose quote loop is at `UniswapV4Quoter.sol:172-176`. |

`ADOPTABLE_WITHIN_DOMAIN` was not awarded. The Solidity proof checks production math libraries. It does not yet call `exchangeOut` on a registry-deployed vault proxy.

A 25 bp price clamp is closed form and reduced one fixture from 1,840 bp to 1,747 bp. That is incremental progress, not a completed repair and not an adoption candidate.
