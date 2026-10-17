# Grok completeness — REQ-03 PRD

- **Date:** 2026-10-14
- **PRD:** `docs/reviews/apex-req-03-custody-negatives/REMEDIATION_PRD.md`, re-read in full.
- **Question:** Does this PRD leave a decision for a later implementer?
- **Answer:** No. The owner rulings and acceptance criteria close the three repairs. No sentence is added.

## Closed, not reopened

- **REQ-03-R1.** The owner ruling is to let the observation deposit finish, separate from the rollback test. The callback records the nested attempt and the `IsLocked` rejection, then returns. The test reads that record after the finished call. A wrong nested error or a nested success fails that test. The rollback test still expects `TransferFromFailed` and keeps the no-partial-credit assertions. The outer selector is not changed to `IsLocked`. The vault is not mocked. That is enough to implement. The dissent sentence about storage dying inside a reverted callback applies to the rollback test, not to the observation test, whose callback returns.
- **REQ-03-R2.** After the successful exact-output call, total supply equals the captured supply plus the requested shares. The existing rejection and success assertions stay. No other success metric is requested.
- **REQ-03-R3.** The directory list in the PRD is the inventory. The implementer adds those directories and does not choose families. The two cited files are selected because their directories are on the list. The two roots and the two already-named custody files stay. Bare `expectRevert()` in a selected file still fails the scanner. Those directories were present when checked: `vaults/standard/erc4626`, `vaults/standard/exchange/protocols/morpho/blue`, `protocols/staking/rebasingVault`, `protocol/staking/rocket-pool`, `protocol/staking/lido`, `protocol/staking/etherfi`, `protocol/lending/aave/v3.6`, `protocol/lending/aave/cross-version`, `protocol/dexes/uniswap/v2`, `protocol/dexes/camelot/v2`, `protocol/dexes/aerodrome/v1`, `protocols/dexes/aerodrome/slipstream`, `protocol/dexes/balancer/v3`, `protocols/dexes/balancer/v3`, and `vaults/detf`.

No remaining choice blocks an implementer.

I did not run Forge.
