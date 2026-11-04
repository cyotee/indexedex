# Gate review

Recommendation: APPROVE

Blockers: []

## Evidence

Reviewed `SYNTHESIS.md` and `sources-ledger.md` in `.omo/ulw-research/20261023-171500/` against all four conditions. The recommended `getRate = accounted target tokens * 1e18 / supply` reads a stored counter and supply, explicitly excluding same-pool spot, `slot0`, quoters, and hypothetical liquidation. The recommendation retains in-range Uniswap swap fees, credited to accounting only upon actual target-token settlement. The synthesis explicitly excludes Visor 2021 and Gamma 2024 spot-based share minting; ledger S22 and S23 contain the respective primary URLs, and both primary reports were independently opened for this review. S23 is Gamma's January 23, 2024 review of the January 4, 2024 incident. No sentence claims a production LP vault already implements the recommended rate: the executive summary explicitly reports no inspected match, and Panoptic is identified only as an accounting-shape reference, not an LP-vault implementation. Approval covers these four recommendation gates, not implementation correctness or the safety of future conversion and deposit logic.
