# Remaining work

- **Date:** 2026-10-17
- **Status:** Work queue. This is not a new audit and not permission to edit code.
- **Source:** The unfinished items named from `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md`. Closed and withdrawn items are not repeated here.
- **Rule:** Except for the Crane delivery below, every item is unverified. Confirm it against current source before writing a repair. Do not treat this list as proof that the defect still exists.

## Not in this queue

REQ-02, REQ-03, REQ-04, REQ-C04, REQ-C06, REQ-SEP-01, REQ-SEP-04, REQ-H03's source edit, and REQ-ADJ-01 are closed. The legacy V4 package gaps are withdrawn. The missing REQ-ADJ-01 execution report is a documentation gap and is not a task here.

The deleted tree is `contracts/protocols/dexes/uniswap/v4`. The supported V4 vaults under `contracts/vaults/standard/exchange/protocols/uniswap/v4/` are not that deletion.

## 1. Deliver the REQ-H03 Crane revision — closed 2026-10-17

IndexedEx commit `b8dbdf4102ccddedc3f46b6acf8f3d3006a378fe` records Crane `90203dbc261abe7b6cf03a46cdb8e8c3869b43f2` (`fix(erc20): report insufficient balance when burning shares`). That revision contains the short-burn check. Crane `main` matches `origin/main`. The working copies are clean for this path.

## 2. Stage-1 items never verified

Controlling text: `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md`. These were not re-read in the 2026-10-14 application round. No repair is authorized until a verification pass confirms the current code still breaks the requirement.

### REQ-05 — Closed 2026-10-17

The held-token credit check is present for V3, hookless, Pons, and wings. Confirmation: `docs/reviews/apex-req-05-execution-confirmation/REMEDIATION_PRD.md`. This close did not rerun Forge.

### REQ-06 — Closed 2026-10-18

`maxRedeem` returns the share balance. The stale `maxWithdraw` assertion was replaced with the preview of that balance. Confirmation: `docs/reviews/apex-req-06-execution-confirmation/REMEDIATION_PRD.md`. This close did not rerun Forge.

- **Severity claimed:** Low. Not reconfirmed.
- **Claim:** `maxRedeem` must be the largest owner share amount that `redeem` can pay from held receipts. It must not call `maxWithdraw` or `convertToShares`. `maxWithdraw` must equal `previewRedeem(maxRedeem(owner))`.
- **Files named then:** `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol` and `ReceiptBackedERC4626AccountingLib.sol`.
- **Next action:** Read the current formula. If it already matches, close the item. If not, write a PRD for that formula only.

### REQ-07 — Closed 2026-10-18

The gas-gated self-snapshot is absent from the current rate provider. This is not a finding that the September alert was mistaken. Confirmation: `docs/reviews/apex-req-07-close/REMEDIATION_PRD.md`. This close did not rerun Forge.

### REQ-08 — Withdrawn 2026-10-18

Owner ruling: agent evidence records are not a task. Missing maps, regenerated logs, and `scripts/r12_selector_size_compare.py` are not production code or tests. This withdrawal does not merge hookless and Pons, and it does not restore the deleted legacy package.

## 3. September items never verified

Controlling text: `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`. Later explicit-holder law and the legacy V4 deletion do not close these. RC-01 and RC-04 are not in this queue.

### RC-02 — Closed 2026-10-18

The helper withdraws the exact shortfall. The recipient receives the accounted amount. The rounded share cost stays on the Standard Exchange. Confirmation: `docs/reviews/apex-rc-02-payout/REMEDIATION_PRD.md`. This close did not rerun Forge.

### RC-03 — Closed 2026-10-18

The Stata exchange and the shared adapter use one backing calculation. Booked aToken counts on both when it is registered. Confirmation: `docs/reviews/apex-rc-03-backing/REMEDIATION_PRD.md`. This close did not rerun Forge.

### RC-05 — Closed 2026-10-18

The unused `exchangeOut` is gone. The remaining function refunds only `credit - used` through the guarded helper. Confirmation: `docs/reviews/apex-rc-05-refund/REMEDIATION_PRD.md`. This close did not rerun Forge.

### RC-06 — Closed 2026-10-18

The unwrap returns no share count. It cannot report the approval cap as shares spent. Astra, Grok, and Kimi agreed. MiniMax's saved first pass agreed. Its cross-review file was not saved. The owner treated the item as already covered. Note: `docs/reviews/apex-rc-06-unwrap/REMEDIATION_PRD.md`.

### RC-07 — Closed 2026-10-18

Owner ruling: false alert. The base helper still panics, but no active path reaches it. Do not edit the base helper. This is not a four-member council close. MiniMax did not answer. Note: `docs/reviews/apex-rc-07-surplus/REMEDIATION_PRD.md`.

### RC-08 — Closed 2026-10-18

Both OutTarget equality stops revert `LPReserveMismatch(uint256 held, uint256 booked)`. The less-than check is unchanged. Confirmation: `docs/reviews/apex-rc-08-execution-confirmation/REMEDIATION_PRD.md`. This close did not rerun Forge.

## Order

No open payment item remains. RC-08 is closed.

A verification that finds no remaining defect closes that item. It does not authorize the next edit.
