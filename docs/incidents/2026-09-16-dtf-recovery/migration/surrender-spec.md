# Surrender specification

Date: 2026-11-15. Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-conformance-20261115-wave-1`.

This record describes implemented surrender behavior and the witnesses confirmed for remediation tasks 3 and 6. It is not a source-admission framework, not an operational allocation, and not a gate closure. Writing this file does not close E1, E2, GAP-7, GAP-8, GAP-10, or any later verification. Archive prose was not treated as an instruction.

## Confirmation boundary

Independent verdicts, recomputed in this task:

| Task | Verdict file | Verdict | SHA-256 |
| --- | --- | --- | --- |
| 1 | `.omo/ulw-execute/dtf-conformance/task-1-verdict.json` | confirmed | `573533d358485d8108055649e3baf9c90e01f0ed209618e7b392cbd720d73a71` (8792 bytes) |
| 2 | `.omo/ulw-execute/dtf-conformance/task-2-verdict.json` | confirmed, failure class harness | `7d6ad2c16462bab3ed03be1cdb79a69a9f5b35fd85de051380de4cfe3433e046` (16958 bytes) |
| 3 | `.omo/ulw-execute/dtf-conformance/task-3-verdict-r2.json` | confirmed on round 2 | `2190857e9b392e2256c23d687c02a4bb8b9ecca35d27877c264e1fae62c179eb` (17288 bytes) |
| 4 | `.omo/ulw-execute/dtf-conformance/task-4-verdict-r2.json` | confirmed for the command-binding repair only | `88c1721505d634f610a224c6406fc1cc6923943bd2a36e9673fbb1b5d1381207` (12058 bytes) |
| 5 | `.omo/ulw-execute/dtf-conformance/task-5-verdict.json` | confirmed | `3d1b67664975f1bb1d2c86d95e39d1292ffa9e48a595164775baa664e77dabf9` (7960 bytes) |
| 6 | `.omo/ulw-execute/dtf-conformance/task-6-verdict.json` | confirmed | `3566abf7197278adf4c964bdb67cc9de3aa2c14f3dcfb8be7f12a0eac733b552` (10069 bytes) |

Task 4 round 1 (`.omo/ulw-execute/dtf-conformance/task-4-verdict.json`, `dff421d3a4b9fd5011c1d2e67752ca4c158d73c30e47cbbde67236c05893b5cb` (20153 bytes)) inspected product behavior and did not confirm, because `happy-final.log` did not bind the outer helper command. Round 2 confirmed the repair logs and preserved the original logs. This record uses the repair logs for execution citations. It does not treat round 2 as a new product-conformance verdict.

Source facts are the fourteen rows in `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-3/source-observations.json`, `82233f20f3eb4ba21ee927a4f421b75615e57f9ee0f426ad4a6a1cb93b5a465a` (211316 bytes). Execution witnesses are `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/source-results.json`, `18be4bf6765ca37b902ad85931117b41e50018efbf66218ce31d03e302493054` (173171 bytes), bound to `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-6/fork-qa-1.log`, `ec59e2ca0e0f6c936b848ed226571e303cd9a37a7d9fc674b22c3eeca7cee238` (3884899 bytes). The task 6 file records that raw log hash as `ec59e2ca0e0f6c936b848ed226571e303cd9a37a7d9fc674b22c3eeca7cee238`. This task recomputed the same digest.

The amended specification quoted below is `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, `93fdd2f045885e00304ec36aa62215127dc1a957f514605129751dd3ae45218e` (98213 bytes). That digest matches the hash recorded by the task 3 handoff for the amended local plan. Task 1's confirmed verdict is the amendment authority. This task did not re-audit the amendment.

Solidity citations are the worktree bytes hashed below. A parallel operator may edit other Solidity or scripts. Those edits were not reverted. Citations are only the hashed files.

| File | SHA-256 | Bytes |
| --- | --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationWeightedHookTarget.sol` | `e5d34dd8726b31faba071a8b6c264e85a903ef4f6ca8c729f4a26332a78b0e29` | 22719 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol` | `a7db3e687205d4e38e668e889286c0e847a13b9669fccd6a01a2ae83a138914d` | 27213 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/MigrationLegacyNftLib.sol` | `98e01a423cf543c09386fb205c796944c124251f462fbe1de5ca0d333936f045` | 4315 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` | `514fb54a14f0fde6d43622694d167f0c36528ae647de85823d8b6ba96881a920` | 25265 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol` | `294492b0045f05ef4106d203ba78e55aa534099218f006cb80de44576421d373` | 5536 |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol` | `3f60c4c5ab04d54dd94ccd71d5bb3e35d144a49394b12a6af3e3e22ccbdc8883` | 6321 |

Pin recorded by both observation and task 6 files: chain 4663, block 108944663, block hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`, state root `0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`, L1 block 26367659. The observation qualifies that Orbit `BLOCKNUMBER` exposes the L1 number and the raw header pins the L2 block. These are source pins, not a price book or an approved allocation.

## Common Stage 2 entry

Amended plan section 1.4, read at lines 68-74 of `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`: Stage 1 rejects every token, NFT, and claim surrender before custody, consumption, or bond issuance. Stage 2 surrender is enabled in the same activation that opens ordinary deposits and removes configuration and issuance selectors. Surrender requires a configured original wallet. A balance, approval, or current NFT owner alone does not create an entitlement. A mismatch reverts before asset movement.

Implemented gate, read in each entry below: if `activated` is false, revert `Migration.MigrationSurrenderClosed()`. The entries also call idle-child, not-disabled, and reserve-live checks, then reject an expired deadline with `DeadlineExpired`. Each entry is `nonReentrant`.

The caller must equal the configured `originalWallet`. NFT surrender also requires the caller to be the current `ownerOf` holder. A wrong wallet reverts a source-specific `NotOriginal*Wallet` error, or `NotOriginalNftWallet` / `NotNftHolder` for NFTs. Task 6's weighted witness expects `NotOriginalNftWallet(address,address)` and asserts the position is not consumed.

Arguments:

| Family | Entry | Arguments | Returns |
| --- | --- | --- | --- |
| NFT | `surrenderMigrationNft` | collection, token id, minimum credit, deadline | first bond id and summed quoted credit |
| Fungible measured pull | `surrenderMigrationWeightedLiquid`, `surrenderMigrationEarlierLiquid`, `surrenderMigrationWeightedSy`, `surrenderMigrationDtfCustodySe`, `surrenderMigrationClaimVault`, `surrenderMigrationHeldSeLp` | original id, amount, minimum credit, deadline | bond id and credit |
| Receipt | `surrenderMigrationWeightedReceipt`, `surrenderMigrationEarlierReceipt` | original id, native amount, minimum credit, deadline | bond id and credit |
| Prepared claim | no direct weight pull | source `withdrawClaim` by the configured wallet, then the weighted-SY surrender | the SY surrender's bond |

Held-SE, earlier-SE, weighted LP, and earlier LP share `surrenderMigrationHeldSeLp`. The source address comes from the configured original, not from a caller-supplied adapter. The implementation comment at the held-SE body says physical LP has no admitted exit and SE conversions select their own fixed sources. That comment is code, not an operational inventory.

## Credit, rounding, zero credit, and rollback

For the fungible previews read in full, credit is `remainingCredit` when the requested amount equals `remainingUnits`. Otherwise it is `Math.mulDiv(remainingCredit, amount, remainingUnits)`, which floors. A zero amount, an amount above the remaining units, or a zero credit reverts the source quantity or entitlement error before custody. The terminal slice therefore does not leave a rounding residue in `remainingCredit`.

NFT contribution credit is separate. `MigrationLegacyNftLib.contributionCredits` floors each stored contribution with `Math.mulDiv(credit, remaining, originalUnits)` and reverts `InvalidNftEntitlement` if any component credit is zero. `preview` sums those components. `position` reverts if remaining units are zero, if weighted principal does not match the configured original, or if claimed principal exceeds principal. Earlier NFT remaining units are `originalShares` only. Reward debt, effective weight, and physical LP value are not earlier principal. That distinction is in the library comment and in the earlier-NFT task 6 assertion that `convertToAssets(originalShares)` differs from `originalShares`.

Custody is measured, not assumed. The complete weighted-liquid, weighted-SY, and held-SE bodies read wallet and custody balances around the transfer and revert a source-specific custody error unless the wallet debit and custody credit both equal the selected amount. Held-SE uses `transferFrom` and requires a true return. Weighted-liquid and weighted-SY use `safeTransferFrom`. On success, consumed units and delivered credit increase by the selected amount and credit, remaining units and remaining credit decrease by the same amounts, and the selected source amount is added to recovery inventory. `_fundBond` then mints that credit to the migration proxy and calls `createMigrationPosition(credit, msg.sender)`. The bond recipient is the surrendering configured wallet. There is no beneficiary argument.

`_fundBond` was read at `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRepo.sol` lines 92-101. It sets `expectedSynchronizer` to the bond vault, approves the credit, creates the position, then clears the approval and the synchronizer. The bond vault callback check was read at `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol` lines 35-36: the recipient must return the receiver selector. A rejecting recipient reverts the whole transaction. Task 6 rejection rows for the fungible categories expect `ERC721InvalidReceiver` and assert no consumption. That is the atomic rollback witness. This task did not copy those tests' gas fields.

NFT callback: `onERC721Received` accepts only the locked, expected collection, operator, holder, token id, and empty data, once. Any other callback reverts `UnexpectedNftCallback`. After `safeTransferFrom`, the entry requires the callback to have been accepted, the migration proxy to own the token, and the position fingerprint to be unchanged. It then deletes the expected receipt. A failure reverts custody and both contribution issuances because they are in the same transaction and the loop has no catch.

Configuration and surrender cannot overlap after activation, because activation removes the configuration selectors. A partly surrendered entitlement cannot be amended by those removed selectors. This record does not claim a searched absence outside the migration tree. See the package record for the cut that was read.

## Fourteen authenticated sources

The observation file's scope sentence limits these rows to fourteen fixed category and generation rows. No broad recovery census and no new financial award is in that file. Task 6 records `requiredCategories: 14`, `coveredCategories: 14`, and `blockers: []` on the rows used here.

### weighted-nft

- Label: W-N fixed-principal NFT
- Source address: `0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationNft`
- Configured-wallet rule from the observation: ownerOf(id) plus positionOf(id), all five uint256 fields; recorded acquiring wallet remains separate from current holder
- Original unit: original principal P0, native9 WD
- Live remaining-unit read: R=P0-claimedPrincipal; stakingGons and vested/due amounts are not principal
- Unit-read selectors: `0x6352211e`, `0x46f96023`
- Unit equation: For each complete contribution credit Ci: floor(Ci*R/P0). Surrender changes NFT owner only; historical position tuple remains unchanged.
- Source and economic identity: category `weighted-nft` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Retain principal in routine harvests; NFT3 has two separately quoted/funded contributions.
- Recovery condition recorded by the observation, not a new route: `WeightedRewards -> WeightedUnstake -> WeightedConvert -> Donate`. Availability limit recorded with that route: Custody can succeed while later reserve/source conversion is unavailable. Routine rewards-only recovery retains principal, claimedPrincipal and NFT custody.
- Task 6 row status: PASS. Positive witness `test_weightedPartialUsesWholeRemainingPrincipalAndFrozenOriginalQuote` is `fork-qa-1.log` line 7130; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol` lines 31-54. Atomic rejection `test_wrongCurrentHolderCannotUseRecordedPurchaserEntitlement` is `fork-qa-1.log` line 7131; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol` lines 16-30. Conservation witness `test_iterativeRewardHarvestDonatesDtfWithoutTakingUnlockedPrincipal` is `fork-qa-1.log` line 7182; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDonation.t.sol` lines 164-197 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"originalPrincipal":"54436459","claimedPrincipal":"8071216","remainingPrincipal":"46365243","custody":"NFT 32 owner becomes Migration; full source tuple unchanged","bondFunding":"floor(C0 * 46365243 / 54436459); exact funded gons = credit * new receipt divisor","recovery":"Three reward-only cycles after maturity: principalClaimed=0, rewardsClaimed strictly increases; actual WD/DTF deltas positive; selected donation debits only recovered DTF; source principal and claimedPrincipal unchanged"}

### earlier-nft

- Label: E-N LP-lock NFT
- Source address: `0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationNft`
- Configured-wallet rule from the observation: ownerOf(id) plus getPosition(id); exact originalShares, effectiveShares, bonusMultiplier, unlockTime, rewardDebt tuple
- Original unit: source originalShares accounting units, neither effective reward weight nor physical LP
- Live remaining-unit read: getPosition(id).originalShares; future unlock does not zero principal
- Unit-read selectors: `0xeb02c301`, `0x6352211e`
- Unit equation: floor(C0*remainingOriginalShares/configuredOriginalShares). Source convertToAssets(originalShares) is a separate LP-value read, never the compensation numerator.
- Source and economic identity: category `earlier-nft` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Retain principal/NFT; source SE enablement and actual new reward income may be needed. Sale is an explicit separate operation.
- Recovery condition recorded by the observation, not a new route: `EarlierClaim -> EarlierConvert -> Donate`. Availability limit recorded with that route: Actual maturity close reverts VaultDisabled(E-S) at the pin; NFT surrender and standalone reward claim can still work. Recovery needs external enablement/income.
- Task 6 row status: PASS. Positive witness `test_earlierAccountingSharesAreNeitherEffectiveWeightNorPhysicalLp` is `fork-qa-1.log` line 7123; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol` lines 102-113. Atomic rejection `test_missingApprovalRollsBackPretransferAcceptanceForBothSources` is `fork-qa-1.log` line 7126; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacySources.t.sol` lines 210-227. Conservation witness `test_iterativeEarlierRewardsReachDtfWithoutSellingUnlockedNft` is `fork-qa-1.log` line 7181; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDonation.t.sol` lines 110-163 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"originalShares":"47848240999749918187208884","physicalLpValue":"47848240999749918187208985","remainingUnits":"originalShares unchanged","custody":"NFT 12 owner becomes Migration","bondFunding":"C0; fresh bond principal equals complete original credit","recovery":"Three cycles after unlock with genuine incoming ED: rewardsClaimed increases; no NFT sale; exact donation inventory remainder = combined recovery minus donation; originalShares and custody unchanged; external enablement required"}

### weighted-liquid

- Label: W-D weighted DETF
- Source address: `0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationWeightedLiquid`
- Configured-wallet rule from the observation: balanceOf(originalWallet), allowance(originalWallet,Migration), native9 exact debit and custody credit
- Original unit: eligible original WD native9 Q0, partitioned from rewards and other representations
- Live remaining-unit read: Q0-consumed native9
- Unit-read selectors: `0x70a08231`
- Unit equation: q=walletDebit=custodyDelta. c=C when q=Q else floor(C*q/Q); C0 is loaded once from the complete original.
- Source and economic identity: category `weighted-liquid` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Original wallet, configured complete original and actual selected custody.
- Recovery condition recorded by the observation, not a new route: `WeightedConvert -> Donate`. Availability limit recorded with that route: Source conversion WD.exchangeIn(WD,q,DTF,min,Migration,false,deadline) is separate from surrender and must satisfy the actual source output/minimum.
- Task 6 row status: PASS. Positive witness `test_realPartialAndFinalSurrenderConservesFrozenCreditAndFreshBonds` is `fork-qa-1.log` line 7796; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedLiquid.t.sol` lines 82-134. Atomic rejection `test_bondReceiverRejectionRollsBackActualPullFundingAndInventory` is `fork-qa-1.log` line 7794; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedLiquid.t.sol` lines 209-239. Conservation witness `test_directInventoryStagedConversionDonationAndUnbookedFloors` is `fork-qa-1.log` line 7795; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedLiquid.t.sol` lines 240-270 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"originalUnits":"3 native9","custodyDelta":"3","remainingUnits":"0","remainingCredit":"0","bondFunding":"c1=C0/3; c2=(C0-c1)/2; c3=remaining; sum=C0; exact receipt backing increase C0 plus separately accounted expansion","recovery":"Separate fixture 21225531 native9 converted in two selections; booked WD -> 0; seven unbooked WD preserved; booked DTF = actual output; donation debits 1e18"}

### earlier-liquid

- Label: E-D earlier DETF
- Source address: `0xaf0e1967c8f755c747615c5427108bc549ca1122`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationEarlierLiquid`
- Configured-wallet rule from the observation: balanceOf(originalWallet), allowance and exact native18 transferFrom delta
- Original unit: eligible original ED native18 Q0
- Live remaining-unit read: Q0-consumed native18
- Unit-read selectors: `0x70a08231`
- Unit equation: q=walletDebit=custodyDelta; c=C if q=Q else floor(C*q/Q). Recover through E-P.exchangeIn(ED,q,DTF,min,Migration,false,deadline), not ED primary burn.
- Source and economic identity: category `earlier-liquid` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Fixed public reserve swap, not the broken primary-burn path; legacy SE enablement prerequisite.
- Recovery condition recorded by the observation, not a new route: `EarlierConvert -> Donate`. Availability limit recorded with that route: Disabled E-S/registry prevents the working reserve swap until actual external enablement. The old native-burn TransferFromFailed is not permanent inability.
- Task 6 row status: PASS. Positive witness `test_realPartialAndFinalSurrenderConservesFrozenCreditAndFreshBonds` is `fork-qa-1.log` line 6402; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierLiquid.t.sol` lines 96-148. Atomic rejection `test_bondReceiverRejectionRollsBackActualPullFundingAndInventory` is `fork-qa-1.log` line 6400; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierLiquid.t.sol` lines 223-255. Conservation witness `test_typedEarlierConversionAfterLocalLegacyEnablement` is `fork-qa-1.log` line 6405; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierLiquid.t.sol` lines 364-400 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"originalUnits":"3 native18","custodyDelta":"3","remainingUnits":"0","remainingCredit":"0","bondFunding":"Three funded bonds sum C0 with separately accounted expansion","recovery":"Separate fixture q=1e24 ED; fixed E-P reserve swap consumes q, ED supply unchanged, inventory DTF=measured output; full selected output donation ->0; external enablement prerequisite"}

### weighted-receipt

- Label: W-R funded rebasing receipt
- Source address: `0x4fa4974a8a09660258b8edd430b51c1620ebfe5c`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationWeightedReceipt`
- Configured-wallet rule from the observation: synchronizeRewards on WD before baselines; gonsOf(wallet/custody), stakingState().gonsPerUnit=k, displayed balance=floor(gons/k)
- Original unit: eligible original ownership gons Q0; native9 approval/transfer arguments are not gons
- Live remaining-unit read: Q=eligible original gons minus consumed gons; unrepresentable residue remains outstanding
- Unit-read selectors: `0x79a67521`, `0xe082f1d4`, `0x70a08231`
- Unit equation: native transfer n moves q=n*k after synchronization. Both endpoints must move exactly q with unchanged k; c=C if q=Q else floor(C*q/Q). Full-account unstake retires all account gons and needs separate attribution.
- Source and economic identity: category `weighted-receipt` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Synchronize and preserve unsolicited/sub-native gons.
- Recovery condition recorded by the observation, not a new route: `WeightedUnstake -> WeightedConvert -> Donate`. Availability limit recorded with that route: Source synchronization/lock failures roll back surrender; unsolicited and newly allocated role gons stay unbooked. Current display growth never reprices compensation.
- Task 6 row status: PASS. Positive witness `test_partialAndDivisibleTerminalConsumeExactGonsAndCreateFreshFundedCliffs` is `fork-qa-1.log` line 7806; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedReceipt.t.sol` lines 36-50. Atomic rejection `test_lateBondCallbackRevertsSourceFundingCustodyAndCreditThenRejectsReentry` is `fork-qa-1.log` line 7805; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedReceipt.t.sol` lines 186-204. Conservation witness `test_mixedNftWyWsAndUnbookedWholeFractionPreserveAllBudgets` is `fork-qa-1.log` line 7220; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryWeightedReceipt.t.sol` lines 47-99 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"originalUnits":"101 * synchronized source gonsPerUnit","custodyDelta":"Exact acquiredGons; transfers 1 and 100 native9","remainingUnits":"0","remainingCredit":"0","bondFunding":"C1=C0/101; C1+C2=C0; each principal backed by exact receipt gons","recovery":"Mixed WY/WS/NFT recovery retains unbooked whole/fraction gons; after booked exits remaining booked gons < source divisor; WY seven shares and DTF seven ether unbooked floor preserved"}

### earlier-receipt

- Label: E-R rebasing internal-share receipt
- Source address: `0x4ac89ad061a531fa62ddceed53520c2750113b01`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationEarlierReceipt`
- Configured-wallet rule from the observation: sharesOf=floor(I/1e9), balanceOf=floor(I*r/1e27), redemptionRate=r, totalShares; exact I is not a public getter
- Original unit: eligible original internal shares I0, distinct from native18 display and floored external shares
- Live remaining-unit read: Q=I0-consumedInternalShares; NFT-sale external bucket E plus remainder R stays separate from standalone B
- Unit-read selectors: `0x70a08231`, `0xf5eb42dc`, `0x3a98ef39`, `0x540385a3`
- Unit equation: Transfer n native18 moves q=floor(n*1e27/rTransfer). Public endpoint floors bound q; singleton inversion proves rTransfer equals rBefore=rAfter. Conservation is E*1e9+R+B with R<1e9; c=C if q=Q else floor(C*q/Q).
- Source and economic identity: category `earlier-receipt` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: NFT-sale E external shares plus R remainder stay separate from standalone B internal shares; reward-funded redemption needs actual source income.
- Recovery condition recorded by the observation, not a new route: `EarlierStandaloneReceiptRedeem -> EarlierConvert -> Donate`. Availability limit recorded with that route: Standalone/NFT receipt redemption requires actual protocol-NFT reward income; present shortfall, native-exit failure or zero expansion after time advance is conditional availability.
- Task 6 row status: PASS. Positive witness `test_genuineDivisibleTerminalTakesAllFrozenCreditIntoFreshCliffs` is `fork-qa-1.log` line 6414; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierReceipt.t.sol` lines 148-164. Atomic rejection `test_lateReceiverRollbackReentryAndLaterDonationRemainSeparate` is `fork-qa-1.log` line 6415; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierReceipt.t.sol` lines 257-277. Conservation witness `test_rewardFundedRedemptionPreservesBothReceiptBucketsAndUnbookedFractions` is `fork-qa-1.log` line 6419; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierReceipt.t.sol` lines 339-376 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"originalUnits":"2000000000000000000000000000 internal shares","sourceNativeAcquisition":"4394 at source rate 2197","custodyDelta":"Two 2197 native18 pulls each move 1e27 internal shares","remainingUnits":"0","remainingCredit":"0","bondFunding":"C1+C2=C0; two fresh 90-day funded cliffs","recovery":"Each 1000 native18 redemption burns floor(1000*1e27/r); only selected E*1e9+R or standalone B bucket debited; unbooked internal fraction conserved; actual ED output converted to positive DTF under external enablement/income"}

### weighted-sy

- Label: W-Y static SY
- Source address: `0xb55604cf4dcdabb362078e106d20f98512391edf`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationWeightedSy`
- Configured-wallet rule from the observation: balanceOf(originalWallet), native9 static shares; transferFrom exact debit/credit
- Original unit: eligible original static SY native9 Q0; backing WS gons are infrastructure, not a second original
- Live remaining-unit read: Q0-consumed static shares
- Unit-read selectors: `0x70a08231`
- Unit equation: q=actual static SY custody delta. c=C if q=Q else floor(C*q/Q). redeem(Migration,q,WS,min,false) burns selected SY and measures returned WS gons; no flat conversion inferred.
- Source and economic identity: category `weighted-sy` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Also supports complete/full-remainder TokenStaking preparation certificates; no duplicate economic originals.
- Recovery condition recorded by the observation, not a new route: `WeightedSyRedeem -> WeightedUnstake -> WeightedConvert -> Donate`. Availability limit recorded with that route: Approved custody and later SY redemption/WS unstake/WD conversion have separate failure boundaries; source reward synchronization may fail without altering committed earlier surrender.
- Task 6 row status: PASS. Positive witness `test_realPartialAndFinalSurrenderConservesFrozenCreditAndFreshBonds` is `fork-qa-1.log` line 7825; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedSy.t.sol` lines 284-336. Atomic rejection `test_bondReceiverRejectionRollsBackActualPullFundingAndInventory` is `fork-qa-1.log` line 7824; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedSy.t.sol` lines 411-441. Conservation witness `test_actualWyToWsToWdToDtfAndFixedDonationProtectBacking` is `fork-qa-1.log` line 7225; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryWeightedSy.t.sol` lines 91-110 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"originalUnits":"3 native9 static shares","custodyDelta":"3","remainingUnits":"0","remainingCredit":"0","bondFunding":"Three fresh funded bonds sum C0","recovery":"Separate fixture burns 8087 SY and retains seven unsolicited shares; out=floor(8087*floor(1e54/k)/1e18); received gons=out*k; WD delta=out; actual DTF delta booked; donation half leaves dtf-floor(dtf/2)"}

### claim-vault

- Label: V direct claim-vault rights
- Source address: `0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationClaimVault`
- Configured-wallet rule from the observation: Actual own-account vault shares via ERC20 balanceOf/allowance; direct controlled-wallet acquisition is separate from T-owned infrastructure shares
- Original unit: eligible direct claim-vault native19 shares Q0
- Live remaining-unit read: Q0-consumed native19 shares
- Unit-read selectors: `0x70a08231`
- Unit equation: redeem(q19,Migration,Migration) returns measured native9 SY. No fixed 1e10 divisor or current-source formula is assumed. Actual controlled deposit 3000 SY yielded 29999999967592 vault shares; source outputs and redemption deltas are receipt-bound. Compensation uses q19/Q19, not SY output.
- Source and economic identity: category `claim-vault` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Actual own-share redemption and measured SY output.
- Recovery condition recorded by the observation, not a new route: `ClaimVaultRedeem -> WeightedSyRedeem -> WeightedUnstake -> WeightedConvert -> Donate`. Availability limit recorded with that route: Early source-admission missing-source/acquisition report is historical. Later direct controlled-wallet receipts and rollback witnesses exist; no exact legacy-source recompilation/equivalence is claimed.
- Task 6 row status: PASS. Positive witness `test_actualPartialFinalSharesConserveFrozenCreditAndFreshFunding` is `fork-qa-1.log` line 6454; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationClaimVault.t.sol` lines 43-76. Atomic rejection `test_actualContractAcquisitionAndRejectedBondRollBackPullFundingAndCallback` is `fork-qa-1.log` line 6453; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationClaimVault.t.sol` lines 169-201. Conservation witness `test_selectedNative19BurnUsesActualOutputAndNeverRepricesCredit` is `fork-qa-1.log` line 7173; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryClaimVault.t.sol` lines 42-76 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"acquiredShares":"29999999967592 native19 for 3000 native9 SY","originalUnits":"29999999967585","custodyDelta":"29999999967585","walletRemainder":"7","remainingUnits":"0","remainingCredit":"0","bondFunding":"Two exact funded principals sum C0","recovery":"Burn selected q19 exactly; totalSupply delta=-q19; source SY debit=Migration SY credit=actual previewRedeem output; preserves seven unbooked shares, does not reprice compensation; entire typed chain and donation tested"}

### dtf-custody-se

- Label: W-SD DTF custody SE
- Source address: `0x2e9c1f705ab967c5af59249203d7495bdabb223b`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationDtfCustodySe`
- Configured-wallet rule from the observation: ERC20 balanceOf/allowance; native28 own-share units; asset() is fixed native18 DTF
- Original unit: eligible original native28 W-SD shares Q0
- Live remaining-unit read: Q0-consumed native28 shares
- Unit-read selectors: `0x70a08231`
- Unit equation: Actual 1e18 DTF deposit yielded 1e28 shares in the retained controlled-wallet witness. redeem(q28,Migration,Migration) returns actual measured native18 DTF. Compensation consumes q28/Q28, never q18 DTF.
- Source and economic identity: category `dtf-custody-se` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Actual native18 DTF output.
- Recovery condition recorded by the observation, not a new route: `DtfCustodySeRedeem -> Donate`. Availability limit recorded with that route: Actual source redemption/positive minimum and downstream funding are enforced separately; no invented output or receipt from a disabled source is booked.
- Task 6 row status: PASS. Positive witness `test_actualPartialFinalSharesConserveFrozenCreditAndFreshFunding` is `fork-qa-1.log` line 7833; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDtfCustodySe.t.sol` lines 43-76. Atomic rejection `test_actualContractAcquisitionAndRejectedBondRollBackPullFundingAndCallback` is `fork-qa-1.log` line 7832; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationDtfCustodySe.t.sol` lines 169-201. Conservation witness `test_selectedNative28BurnUsesActualOutputAndNeverRepricesCredit` is `fork-qa-1.log` line 7191; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationRecoveryDtfCustodySe.t.sol` lines 42-68 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"originalUnits":"acquiredShares - 7 native28 from actual 1e18 DTF deposit; no invented fixed divisor","custodyDelta":"acquiredShares - 7","walletRemainder":"7","remainingUnits":"0","remainingCredit":"0","bondFunding":"Two fresh exact funded principals sum C0","recovery":"Two selected burns conserve source shares and totalSupply exactly; actual DTF source debit=Migration credit; recovery inventory=sum(outputs); donation of first output leaves second; seven unsolicited shares retained"}

### weighted-weth-se

- Label: W-SW WETH/DTF SE
- Source address: `0x999dae02d22e5fee1c4508430d5196d31d631009`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationHeldSeLp`
- Configured-wallet rule from the observation: Native18 ERC20 balanceOf/allowance and exact approved transferFrom; source identity is the SE, not the delegated facet
- Original unit: eligible original native18 SE shares Q0
- Live remaining-unit read: Q0-consumed native18 SE shares
- Unit-read selectors: `0x70a08231`
- Unit equation: q=walletDebit=custodyDelta. Recovery exchangeIn(source,q,DTF,min,Migration,false,deadline) returns one uint256 native18 DTF, measured before/after; c=C if q=Q else floor(C*q/Q).
- Source and economic identity: category `weighted-weth-se` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Conditional actual legacy enablement; preserve unbooked shares.
- Recovery condition recorded by the observation, not a new route: `WeightedWethSeConvert -> Donate`. Availability limit recorded with that route: isDisabled=true at the source pin. Executable local enablement witness supersedes older blanket no-recovery conclusions; enabling is external source authority, not granted by Migration.
- Task 6 row status: PASS. Positive witness `test_realPartialAndFinalSurrenderConservesFrozenCreditAndFreshBonds` is `fork-qa-1.log` line 6482; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 155-207. Atomic rejection `test_bondReceiverRejectionRollsBackActualPullFundingAndInventory` is `fork-qa-1.log` line 6479; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 328-360. Conservation witness `test_typedRecoveryAfterLocalLegacyEnablementPreservesUnbookedShares` is `fork-qa-1.log` line 6485; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 476-530 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"suite":"MigrationWeightedWethSeTest","originalUnits":"3 native18","custodyDelta":"3","remainingUnits":"0","remainingCredit":"0","bondFunding":"Three exact funded principals sum C0","recovery":"Selected q after external source enablement: inventory ->0; source custody retains 100 unbooked shares; DTF inventory=actual balance delta; donation all ->0; failed later step restores full q"}

### earlier-se

- Label: E-S earlier SE
- Source address: `0xb7d4bb379d361ad442cddee53ea71a33957826a7`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationHeldSeLp`
- Configured-wallet rule from the observation: Native18 ERC20 balanceOf/allowance; genuine paid non-dust acquisition and ordinary original holder fixtures are distinct
- Original unit: eligible original native18 E-S shares Q0
- Live remaining-unit read: Q0-consumed native18 E-S shares
- Unit-read selectors: `0x70a08231`
- Unit equation: q=walletDebit=custodyDelta; c=C if q=Q else floor(C*q/Q). Fixed E-S.exchangeIn(E-S,q,DTF,min,Migration,false,deadline) measures actual native18 DTF output; a zero output never consumes booked inventory.
- Source and economic identity: category `earlier-se` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Conditional actual legacy enablement; insufficient native output rejects without confiscation.
- Recovery condition recorded by the observation, not a new route: `EarlierSeConvert -> Donate`. Availability limit recorded with that route: isDisabled=true at pin; local actual registry enablement and non-dust source income/acquisition are prerequisites. Dust failure is not permanent inability.
- Task 6 row status: PASS. Positive witness `test_genuineOriginalHolderSurrendersIntoFreshFundedBondsWithDisabledRecovery` is `fork-qa-1.log` line 6444; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 594-649. Atomic rejection `test_actualChildFundingFailureRestoresSourceAllowanceAndEveryBudget` is `fork-qa-1.log` line 6439; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 305-327. Conservation witness `test_typedEarlierSeRecoveryAfterPaidAcquisitionAndLocalEnablement` is `fork-qa-1.log` line 6448; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 650-704 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"suite":"MigrationEarlierSeTest","originalUnits":"2021090200239501983 - 10020 native18 in original-holder fixture","custodyDelta":"quantity_ (entire remaining holder quantity)","remainingUnits":"0","remainingCredit":"0","bondFunding":"Two funded principals sum C0; each gons=principal*divisor","recovery":"Separate paid acquisition 1e12 DTF, actual external enablement; selected q burned/converted, retains 100 unbooked shares; DTF=actual measured output; donation all ->0; dust-only source exit still rejects atomically"}

### weighted-lp

- Label: W-P physical weighted LP
- Source address: `0x46e068c2393e189fbc86632f67210af253a42aa8`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationHeldSeLp`
- Configured-wallet rule from the observation: Native18 LP balanceOf/allowance; LP owner role is WD, distinct from ERC20 holder and collector
- Original unit: eligible original physical LP native18 Q0; exclude protocol/fee-minted LP and NFT-accounting shares
- Live remaining-unit read: Q0-consumed native18 physical LP
- Unit-read selectors: `0x70a08231`
- Unit equation: Selected LP q is held and booked. Conditional authorized exit burns q with supplyAfter=supplyBefore-q+feeMint; actual DTF output is measured and feeMint remains unbooked.
- Source and economic identity: category `weighted-lp` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Requires real source liquidity authority; current-fee-recipient authorization demonstrated locally, never self-granted by Migration. Fee-minted LP remains unbooked.
- Recovery condition recorded by the observation, not a new route: `WeightedLpRedeem -> Donate`. Availability limit recorded with that route: Deployed weighted guard permits actual current fee recipient as an exception. Oracle-owner feeTo change on a local fork proves conditional access; Migration cannot self-grant it.
- Task 6 row status: PASS. Positive witness `test_realPartialAndFinalSurrenderConservesFrozenCreditAndFreshBonds` is `fork-qa-1.log` line 6468; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 155-207. Atomic rejection `test_bondReceiverRejectionRollsBackActualPullFundingAndInventory` is `fork-qa-1.log` line 6465; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 328-360. Conservation witness `test_typedLpRecoveryAfterActualOracleAuthorizationPreservesFeeMints` is `fork-qa-1.log` line 6471; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 536-591 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"suite":"MigrationWeightedLpTest","originalUnits":"3 physical LP native18","custodyDelta":"3","remainingUnits":"0","remainingCredit":"0","bondFunding":"Three fresh funded principals sum C0","recovery":"Separate selected q requires actual external oracle feeTo authorization; supplyAfter=supplyBefore-q+feeMint; heldAfter=100+feeMint; booked LP ->0; DTF=actual delta; fee mints cannot be spent as booked inventory; donation all ->0"}

### earlier-lp

- Label: E-P physical earlier LP
- Source address: `0x923877336b14662cfb5b3a60b14e7d716d54a888`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `surrenderMigrationHeldSeLp`
- Configured-wallet rule from the observation: Native18 LP holder approval permits custody only. Actual LP owner is ED, 0xaf0e1967c8f755c747615c5427108bc549ca1122.
- Original unit: eligible original physical LP native18 Q0, distinct from E-N originalShares and reward weights
- Live remaining-unit read: Q0-consumed native18 physical LP held permanently after eligible surrender
- Unit-read selectors: `0x70a08231`
- Unit equation: Custody q=walletDebit=custodyDelta; c=C if q=Q else floor(C*q/Q). Unauthorized withdrawal reverts NotOwner; holdings/supply remain unchanged. No authorized DTF conversion equation exists for Migration under this immutable source surface.
- Source and economic identity: category `earlier-lp` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Owner-only native exits and no admitted parent/collector intake; fee-role change and one-year advance do not grant authority. See recovery-route-disposition.md.
- Recovery condition recorded by the observation, not a new route: `permanent custody under authenticated immutable source`. Availability limit recorded with that route: Permanent protocol custody follows owner-only exits and absence of an admitted parent/NFT/collector forwarding path, not temporary disablement, dust or lack of income. W-P feeTo exception does not exist here.
- Task 6 row status: PASS. Positive witness `test_realPartialAndFinalSurrenderConservesFrozenCreditAndFreshBonds` is `fork-qa-1.log` line 6431; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 155-207. Atomic rejection `test_bondReceiverRejectionRollsBackActualPullFundingAndInventory` is `fork-qa-1.log` line 6428; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationHeldSeLp.t.sol` lines 328-360. Conservation witness `test_earlierLpCannotExitThroughFeeRoleTimeOrParentIntake` is `fork-qa-1.log` line 7102; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationLegacyLpExit.t.sol` lines 38-88 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"suite":"MigrationEarlierLpTest","originalUnits":"3 physical LP native18","custodyDelta":"3","remainingUnits":"0","remainingCredit":"0","bondFunding":"Three exact funded principals sum C0","recovery":"Exact E-P permanent custody disposition; ordinary holder q=10013 unchanged with supply after NotOwner, fee-role reassignment, one-year advance and parent InvalidRoute. No Migration conversion admitted; no extrapolation to E-D/E-N/E-R/E-S/W-P"}

### token-staking-preparation

- Label: T prepared remaining-weight to SY
- Source address: `0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00`
- Recorded runtime code hash: `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`. All fourteen observation rows carry this same recorded value. This task did not recompute it against chain code.
- Observation entry name: `public source claim then configured SY surrender`
- Configured-wallet rule from the observation: T.balanceOf(originalWallet) raw native18 accounting weights; phase()==2; withdrawClaim(q) consumes caller weight and sends SY to that caller. T approve/transferFrom selectors are absent.
- Original unit: Reviewed original W0 accounting weights and original contributions; surviving eligible prepared W is separate from measured SY Q0
- Live remaining-unit read: Track consumed raw weights once; measured Q0 is sum of actual eligible SY outputs across unique prepared claims. Prior raw-weight consumption is not undone by a later SY-surrender failure.
- Unit-read selectors: `0x70a08231`, `0xab518e6e`, `0xb1c9fe6e`
- Unit equation: Source claim selects vault shares floor(qWeight*sourceHeldVaultShares/totalWeight), with the observed whole-supply exception; V.redeem sends measured native9 SY. For prepared remainder W, eligible credit is floor(C0*W/W0), then consumed by actual SY q/Q. Certificates partition nonisolated/relayed effects and exclude other representations.
- Source and economic identity: category `token-staking-preparation` at the address above, chain 4663, pin block 108944663. Economic identity is the eligible original named here, not a second representation of the same original.
- Consumed and remainder condition: Direct, delegated, wallet-relayed and generic indirect/nonisolated claim effects are authenticated. Historical unavailable trace remains unqueried; operational financial originals require review.
- Recovery condition recorded by the observation, not a new route: `claimed-SY route above`. Availability limit recorded with that route: No direct approved raw-weight pull is admitted. Caller/phase/source output/canonical receipt and full original or prepared remainder evidence are required. The refused historical trace is not retried; no operational financial original is inferred.
- Task 6 row status: PASS. Positive witness `test_partialOriginalSplitPreparationConservesScaledCreditThroughThreeSurrenders` is `fork-qa-1.log` line 7819; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedSy.t.sol` lines 207-210. Atomic rejection `test_lateChildFundingRollbackCannotRestoreEarlierConsumedRawWeight` is `fork-qa-1.log` line 7816; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedSy.t.sol` lines 211-215. Conservation witness `test_completeSplitClaimsAggregateMeasuredOutputsIntoOneOriginal` is `fork-qa-1.log` line 7815; its source is `test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationWeightedSy.t.sol` lines 197-201 .

- Assertion-backed custody note copied from the task 6 row. These are test assertions or assertion-backed expressions, not an operational allocation, holder list, or gas envelope: {"suite":"MigrationClaimedSyTest","originalWeight":"30039000000000000000051","eligibleWeight":"10013000000000000000017","unrelatedRawWeight":"7000000000000000000","seedRawWeight":"3000000000000000000 excluded from eligibility","originalUnits":"Q0=sum(actual eligible SY from two source claims); floor_=earlier seed output remains unrelated","custodyDelta":"Q0 after three SY surrenders; consumed raw source weight remains consumed on later funding rejection","remainingUnits":"0","remainingCredit":"0","bondFunding":"C0= floor(full-original credit*eligibleWeight/originalWeight) once; three delivered principals sum C0; no raw-weight approved pull","recovery":"Measured static SY uses the existing weighted-SY route; backing SY/V infrastructure excluded as competing economic originals"}

## NFT 3, two originals

Amended plan section 1.7, read at lines 96-102 of `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, records an owner direction for weighted collection `0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e`, token id 3: `999999000000000` raw18 WETH and `362893857600000000000` raw18 DTF, kept as two original contributions, quoted against the same complete manual book on that explicit load, and delivered as two funded bonds. The same paragraph says one surrender consumes the old NFT once, applies the remaining-principal fraction to each stored credit without re-quoting partial inputs, and a failure of either bond reverts both issuances, custody, and consumption. It also says the decision does not approve a pricing book, a live reserve composition, final numerical credits, or an operational issuance.

The implementation matches that shape only where contributions are already stored. `surrenderMigrationNft` moves the NFT once, then calls `_fundBond` once per `contributionCredits` entry and records each bond in `nftContributionSurrenders`. The returned bond id is the first id. The summed quoted credit is the return credit, not a statement that only one bond was minted.

Task 3's weighted-NFT condition string says NFT 3 has two separately quoted and funded contributions. Task 3's confirmed limits say task 3 does not prove the later two-bond behavior. Task 6's weighted-NFT positive witness is token 32, with asserted principal `54436459`, claimed principal `8071216`, and remaining `46365243`. Its conservation witness uses token 4. Neither is a two-bond witness for token 3. The two-bond execution, distinct funded principals, second-bond rollback, and creation-time cliffs for token 3 are unresolved in tasks 1-6. Remediation task 10 owns that rehearsal. This record does not calculate credits from the section 1.7 quantities.

## Earlier reserved roles

Task 3 `earlierReservedIds`, confirmed by the round-2 verdict, classifies earlier-collection token ids 0, 1, and 2 as reserved and not qualifying user bond positions. Mint receipts were not recovered. The classification is from deployed `initializeReservedBondNfts` plus pinned wired and position reads, not from a `tokenId < 3` rule inside Migration and not from an invented empty-exposure dataset.

| Token id | Role | Owner at pin | originalShares | effectiveShares |
| --- | --- | --- | --- | --- |
| 0 | protocol | `0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391` | `30553440974423605336759687659017983` | `30553440974423605336759687659017983` |
| 1 | fee-recipient standing rewards at initialization | `0x20af9a1e21a59a411cd3b0c40e70af9084770b2e` | `0` | `21514144891010951919251332737340123` |
| 2 | creator standing rewards | `0x495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed` | `0` | `50199671412358887811586443053793621` |

These owners are pinned reserved-role facts. They are not a compensation holder list and not an approved award. Bonus multiplier and unlock time are `0` for all three. Reward-debt figures are in the observation file and are not repeated here as an allocation.

Task 6 records `test_earlierInitializedReservedRolesRejectConfigurationAndSurrender` at `fork-qa-1.log:7148`, in `MigrationOriginalWallet.t.sol`. The verdict summary says the executed tests reject reserved earlier ids 0-2 at configuration and Stage 2 surrender.

Separately, `MigrationLegacyNftLib.preview` reverts `InvalidNftEntitlement` when `tokenId_ < 3` or the configuration id is zero, for both fixed collections. That is an implementation guard. It is not the source-role conclusion. The observation file does not classify weighted token ids 0-2 as reserved roles. Whether those weighted ids exist as reserved positions is unresolved here.

The first ordinary earlier purchase recorded beside the reserved rows is token id 3, transaction `0xc0a74f69a4a58540168c070968bb8f2d13759195e4ccabfe469ba3ad3d3d1c75`, block `0x2b8996e`. That comparison is in the observation file. It is not a migration compensation issuance.

## Claimed SY, remainder, and cross-representation exclusion

Amended plan section 1.8, read at lines 104-110, selects one conserved original for still-held eligible TokenStaking claims and their already-claimed SY. A conversion or a second representation does not create another full-credit entitlement. Section 1.6 says wrappers and backing assets do not create additional independent claims on the same economic original.

`configureClaimedSyEntitlements`, read at `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` lines 166-217, checks the expected book, rejects `eligibleWeight == 0` or `eligibleWeight > originalWeight`, and stores `floor(quote * eligibleWeight / originalWeight)`. Zero scaled credit reverts `InvalidWeightedSyEntitlement`. The store writes the weighted-SY entitlement and sets remaining units to `originalUnits` and remaining credit to that scaled credit. It does not call `_fundBond`. The quote helper rejects a missing evidence id, unknown contributions, a consumed identity, and a duplicate original through `_requireUnallocatedOrigin`.

`_requireUnallocatedOrigin`, read at `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationAllocationTarget.sol` lines 251-265, reverts `DuplicateOriginalEntitlement` if the original is already configured or issued on any of the represented stores it checks, including NFT, weighted liquid, weighted SY, DTF-custody SE, claim vault, both receipts, earlier liquid, and held SE. That is the implemented cross-representation exclusion for a new load. It is not a proof that every historical wrapper was already loaded.

The prepared-claim entry is not an approved pull of raw weight. The observation says TokenStaking `approve` and `transferFrom` selectors are absent, `phase()` must be 2, and `withdrawClaim` consumes caller weight and sends SY to that caller. Later SY surrender uses `surrenderMigrationWeightedSy`. A later funding rejection does not restore raw weight already consumed. Task 6's rejection witness is `test_lateChildFundingRollbackCannotRestoreEarlierConsumedRawWeight`. Its positive witness is `test_partialOriginalSplitPreparationConservesScaledCreditThroughThreeSurrenders`. Its conservation witness is `test_completeSplitClaimsAggregateMeasuredOutputsIntoOneOriginal`.

The task 6 custody note for that category records original weight `30039000000000000000051`, eligible weight `10013000000000000000017`, and three SY surrenders whose delivered principals sum the once-scaled credit. Those are assertion-backed fixture quantities. They are not an operational claim list. The refused historical trace remains unqueried. No operational financial original is inferred.

## Errors read

Stage closed: `MigrationSurrenderClosed`. Wrong wallet: the source-specific `NotOriginal*Wallet` errors, plus `NotNftHolder`. Bad quantity: the source-specific `Invalid*Quantity(requested, remaining)` errors. Zero credit or missing configuration: the source-specific `Invalid*Entitlement` errors. Bad source or chain: `Unsupported*Source` and `UnsupportedMigrationNft`. Custody mismatch: `*CustodyFailed`. NFT already consumed: `NftAlreadyConsumed`. Unexpected NFT callback: `UnexpectedNftCallback`. Minimum: `MinAmountNotMet`. Deadline: `DeadlineExpired`. Duplicate load: `DuplicateOriginalEntitlement`.

Weighted-receipt `_weightedReceiptCredit` was not read. Its preview, which was read, rejects a zero `gonsPerUnit` and passes `nativeAmount * gonsPerUnit` into that helper. The zero-credit line inside the unread helper stays unresolved as a line citation. Task 6 still has a passing weighted-receipt row; that pass is not a substitute for the unread helper.

## What this record does not contain

No operational holder list, no approved award, no gas envelope, and no public transaction. Conditional source enablement, reward income, and weighted-LP fee-recipient authority remain external conditions from the task 3 verdict limits. Local fork fixtures do not authorize those external actions.
