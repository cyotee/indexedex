# Implementation evidence: APEX 2026-09-17 council remediation

Recorded after the implementation request that named this plan. Fresh deployments of corrected source are the release unit. No chain inventory, migration, or broadcast was run.

## Configuration

- Source revision at start: `2d69dc1e954f51698f7e26699940171dec2d8a3b`, dirty worktree. Unrelated pre-existing edits were left in place.
- Crane submodule: `6d42cf00fcf1a869cb8e242486e68de52a87b333`.
- Forge `1.5.1-stable` (`b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`). Solc `0.8.35` from `foundry.toml`. `via_ir=false`. Default hermetic profile.
- Runtime artifacts refreshed with `python3 scripts/forge-artifacts.py test` before the suites below.

## Acceptance

| RC | Production change | Test / exception | Result |
| --- | --- | --- | --- |
| 01 | `nonReentrant` on both standalone money entries. Finite router, Permit2, and packed Permit2 approvals. Overflow reverts `Permit2AmountOverflow`. | `Adversarial_BalancerV3SinglePoolSE.t.sol`: callback pool token, swallowed nested entry, propagated rollback, uint160 overflow. | Pass. Nested attempts hit `IReentrancyLock.IsLocked`. Propagated token revert is wrapped by `SafeTransferLib.TransferFromFailed` and rolls back. In-flight allowances equal the exact-in budget, then reset to zero. |
| 02 | Local-first shortfall uses `vault.withdraw`. | `ERC4626StandardExchange_APEX_R14.t.sol` exact-in and exact-out on a 5/3 receipt rate. Recipient delta equals the accounted due. Rounded redeem would have overpaid the 2-wei shortfall. | Pass. Existing orbital Apex008 and ERC4626 SE-matrix suites still pay quoted output and clear allowance. |
| 03 | `ReceiptBackedERC4626AccountingLib.backingReceiptUnits` is the shared Stata/generic basis, including Stata SY `exchangeRate`. | `test_RC03_bookedAToken_sameBacking_adapterAndSe`. Shared-facet suite still shows generic mode has no aToken slot. | Pass. Booked aToken increased adapter backing above the old Stata-only basis. SE preview matched `convertToShares`. |
| 04 | Cited ERC4626 comments, Balancer approval comment, and FullSpread README rewritten to current D6/D15/D17 rules. | ERC4626 R14 suite and `UniswapV4FullSpreadStandardExchangeVault_Delivery.t.sol`. | Pass. No executable change was made to match stale prose. |
| 05 | Deleted unused single-CP HookTarget `exchangeOut`. No inheritor. Installed SeTarget left in place. | `UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface.t.sol`. | Pass. Source no longer contains `maxAmountIn - amountIn` in that file. |
| 06 | `_unwrapExactTokenOut` returns nothing. Seven statement callers needed no textual edit. | Orbital Apex008 capped-unwrap success/rollback and ERC4626 SE matrix. | Pass. |
| 07 | Base helper stays checked and is now virtual. Uni V2, Camelot, Aerodrome, and Stata override with `LocalCreditLib.available`. Camelot positive output rejects a token-out deficit with `AmountOutNotMet(amountOut, 0)`. | `test_RC07_activeSurplus_deficitAuthorizesZero` calls the real Uni V2 override. EOA pretransfer on the production vault still reverts `EOAPretransferNotAllowed`. Existing Uni V2 remediation suite stays green. | Pass. A supported public route that creates `balance < book` without storage writes or burns was not found. The focused helper is the PRD exception. |
| 08 | Zap-out comparison reverts `UniswapV2LpBacking.InsufficientLPBacking(held, required)` (`0xc4021158`). Other empty reverts in the file were not changed. | `test_RC08_namedLpBacking_focusedCheck_fundedExitStillPays`. | Pass. Below reverts with both values. Equal and above succeed. A funded share exit still pays. The deficit branch was not reached by a supported zap-out without forbidden setup. |

Final command covered those suites after artifact refresh: 123 tests passed, 0 failed.
