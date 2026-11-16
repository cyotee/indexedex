# Recovery route disposition after the owner clarification

The owner requires repeated reward harvests while retaining unlocked old-bond principal. Permanent custody is accepted only where the existing source offers no authorized DTF recovery path, including later harvests. This report does not authorize public source configuration or assume rewards accrue merely because time passes.

## Executable routes

| Holding | Installed route | Evidence and conditions |
| --- | --- | --- |
| Weighted old NFT rewards | WeightedRewards -> WeightedUnstake -> WeightedConvert -> Donate | Three time-separated reward cycles passed while old principal, claimed principal and NFT custody stayed unchanged (mon_5GQSN1AN32VY96KY). Principal-bearing stages remain explicit, not routine. |
| Earlier old NFT rewards | EarlierClaim -> EarlierConvert -> Donate | EarlierClaim settles the parent's public expansion/compound path before measuring the selected NFT reward. EarlierConvert uses the working public EL pool swap, not the broken ED native burn. Three cycles with genuine incoming old reward tokens passed, retaining both old NFT principals and donating combined DTF (mon_ECKRXEJK0N0WBD4B). Legacy SE enablement is an external prerequisite. |
| Earlier liquid ED | EarlierConvert: ED approved to fixed EL; EL.exchangeIn(ED,...,DTF,...,Migration,false,deadline) | Actual source swap and actual Migration conversion/donation passed (mon_5GQSN1AN32VY96KY and mon_XRKRKDTVYEAH1EFT). The initially attempted native exit's TransferFromFailed is preserved; it does not establish permanent irrecoverability. |
| Earlier receipt from NFT sale | EarlierNftReceiptRedeem -> EarlierConvert | Actual reward-funded ED.redeemClaim returns ED when protocol-NFT rewards are available. Exact internal-share debit preserves the NFT external-share balance plus its sub-1e9 remainder. Actual proxy tests passed with source internal-slot READS as an independent oracle (mon_KS7C5HW2V49KYD8Y). |
| Standalone earlier receipt | EarlierStandaloneReceiptRedeem -> EarlierConvert | Same source primitive with its separate standalone internal-share budget. No overlapping debit, no use of unsolicited shares; real late-batch rollback and oversized-selection negatives passed. Native immediate-DTF exits and reward-shortfall fallback still fail, so inputs must be simulated and may need to wait for real source income. |
| W-SW and E-S shares | WeightedWethSeConvert / EarlierSeConvert -> Donate | Actual Migration conversion/donation and late-batch rollback passed after real registry enablement on local forks.100 unsolicited units stayed protected. Earlier dust below one raw DTF unit correctly rejects; a genuine paid non-dust source acquisition supplies the positive witness. |
| Weighted physical LP | WeightedLpRedeem -> Donate | The ACTUAL deployed policy permits the current fee recipient to remove liquidity. Source-only and actual Migration tests passed after the real legacy oracle owner set the recipient on local forks. Protocol-fee LP minted during exit remains unbooked and protected. This external global role change is not performed by the Migration adapter and is not authorized for public use. |

Source runtime and command evidence is under b2-public-exit-probe-20261113/. Earlier snapshot-only conclusions that both LPs or all earlier liquidation were impossible are superseded by the executable distinctions above.

## Earlier physical LP: permanent custody under the existing immutable source

This is the sole permanent-custody disposition, not a blanket conclusion about earlier NFTs, ED or receipts.

- Fixed LP0x923877336b14662cFb5B3A60b14e7d716d54A888 is owned by the earlier DETF contract, not the migrating holder or Migration proxy.
- Its runtime-bound withdrawal facet0x81Fb72511016B42437FE1ac2d5Bdb0bA82f14A35 has hash0xca224a1792b0b9339c1c5c999c4d5e99bd33f25f8387da864d6eabb4d1d6b398. Its archived source lines7632-7639 enforce owner-only removal; unlike the weighted deployment, it has no current-fee-recipient exception.
- All three native withdrawals, including withdrawSeShares (which does not unwrap a disabled SE), use that guard (source lines14724-14751). Receiving or approving LP does not grant this role.
- A real-holder test showed NotOwner before and after an actual local fee-recipient change and a one-year advance, with unchanged holdings/supply. The parent's public LP intake still rejected InvalidRoute after its actual registry enablement. Test: MigrationLegacyLpExitTest::test_earlierLpCannotExitThroughFeeRoleTimeOrParentIntake; mon_KS7C5HW2V49KYD8Y, gas553301, pass.
- The parent's acceptedBondTokens contains only DTF and SE shares; its actual settlement accepts those sources, not physical LP (archived earlier parent lines25106-25123,25862-25866). Its claimLiquidity accepts only its NFT, receipt or self and selects their recorded protocol/bond custody, not an arbitrary caller's LP (lines24999-25014).
- The old NFT's createPosition, add/remove protocol-position and transferHeldToken operations require the old DETF owner contract. Sending LP into the old protocol as a donation provides no matching DTF recovery or user position and is not an acceptable custody escape.
- The deployed collector's manager surface only transfers fees and synchronizes reserves; it is not an arbitrary LP executor (archived FeeCollectorManagerFacet lines5019-5045). Even granting the current fee-recipient role does not relax this earlier deployment's owner-only guard.

Accruing value or waiting does not change this caller restriction. No existing authorized forwarding or wrapping path for the surrendered physical LP was established. The implementation therefore retains the eligible surrendered LP permanently under Migration custody, without pretending it was liquidated or changing the compensation already delivered. This conclusion is bounded to the authenticated immutable deployment and available protocol interfaces; it is not a claim that no unrelated future market could ever value the token.

## Future rewards versus current availability

At the pin, simply advancing one year produced zero pending earlier-parent expansion. Actual new external reward-token income made protocol receipt redemption and subsequent DTF swap succeed. Tests use genuine previously held tokens, not injected source balances. They demonstrate behavior WHEN income arrives, not a promise of yield. Small DTF recoveries can be accumulated/combined before reserve donation reaches native minimum size; they are not forfeited.

Routine operator scenarios must retain old principal, including matured principal. Full claims, principal claims and old-NFT sales remain separately selected capabilities for explicit later decisions and tests; maturity is not an automatic liquidation instruction.

## Verification limits

These paths have focused source/proxy proofs, but the final broad regression, gas-envelope witness, updated reward-only CLI rehearsal and independent delta gate are still being completed. Raw source records, failed attempts and the first REJECT report remain preserved. Operational original contributions, source-enablement/role decisions and deployment/funding approvals remain separate inputs.
