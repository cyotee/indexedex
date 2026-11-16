# Source route matrix

Date: 2026-11-10. Task 1 synthesis. This file does not approve allocations, close a route, or change a product rule.

## E1/E2 disposition

**E1_DISPOSITION: NOT_CLOSED.**

E1 is not closed. Some source capabilities passed on a pinned or separately labeled fresh fork. Required protection or harvest routes failed, and no category demonstrated one atomic operation that binds the current owner, consumes the entitlement, takes custody and funds a fresh bond with complete rollback.

FAIL routes:

- weighted NFT approved-operator recipient redirection
- earlier mature close and receipt redemption VaultDisabled
- earlier SE and weighted WETH-leg SE exits VaultDisabled
- earlier fungible LP UnsupportedRoute and NotOwner
- weighted fungible LP NotOwner on exact-in and proportional exits

UNPROVEN boundaries:

- atomic Migration handoff for every category
- other-sources historical custody after HTTP 429
- complete earlier source authentication after Sourcify 404
- wrong-owner mature-close authorization masked by VaultDisabled
- direct SY to DTF and disabled-state matrix
- user authority over infrastructure-held SE and LP balances
- on-chain absence of SE, fungible LP, and native ETH exposure
- MigrationLegacySources Foundry suite was not executed

**E2_DISPOSITION: FAIL.**

Ordinary legacy transfers do not maintain contribution ancestry or prequoted credit. The weighted DETF counterexample shows two histories with identical balance observations and different required credits. An immutable permissionless history verifier was not established and is UNPROVEN, not a speculative PASS. Frozen allowances, payer signatures, mutable roots and mandatory wrappers are rejected constraints, not available fixes. Machine field `e2Verdict` is `FAIL_CURRENT_INTERFACES`. `ATTRIBUTION_COUNTEREXAMPLE_PASS` is not an E2 pass.

**TASK1_COMPLETE: false.** Reporting acceptance is a blocker record: every required category has executable evidence or a named blocker. Gate closure is not met. Implementation is not authorized.

Producer reports: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/provenance/report.md](evidence/provenance/report.md); [attribution-spec.md](attribution-spec.md).

## Recorded and fresh pins

Historical pin, chain 4663, block 108944663, hash `0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`, state root `0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`. Weighted custody, the earlier-cp Alchemy retry, and the attribution witness used this pin. Other-sources authenticated this header and a TokenStaking totalSupply read, then stopped on HTTP 429. That is not historical custody.

Fresh pins, not historical:

- Earlier-cp public replay: block 110859526, hash `0x95e705f74dedcea73e2c87c4276435e1ccb498680f1c46e25fba8bb1aa0cac36`.
- Other-sources full run: block 110862604, hash `0x4097f2411c284e399051ef93ab5ff2f46b0230e49a2a0c685d2c4e3acb36ff80`.
- Other-sources native LP replay: block 110860459, hash `0xd5df213bed280397043210c7e927207971def5b71dcedf81e94a4240d4a736a1`.

Earlier receipt displayed supply is `57898677945502333609` at the historical pin and `57898677945502049312` at the fresh pin. They are not normalized.

The pre-incident block 64394556 and attack block 64394557 are not this pin. No funded snapshot is in the bundle. C0 was not computed.

## Summary

| id | verification | E1 | E2 | address |
| --- | --- | --- | --- | --- |
| weighted_detf | FAIL | UNPROVEN | FAIL | 0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7 |
| earlier_cp_detf | FAIL | FAIL | FAIL | 0xaf0E1967c8F755c747615c5427108Bc549CA1122 |
| weighted_nft | FAIL | FAIL | UNPROVEN | 0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E |
| earlier_cp_nft_lp_lock | FAIL | FAIL | UNPROVEN | 0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391 |
| weighted_sdetf | UNPROVEN | UNPROVEN | UNPROVEN | 0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c |
| earlier_cp_receipt | FAIL | FAIL | UNPROVEN | 0x4AC89aD061A531FA62ddceED53520C2750113b01 |
| weighted_sy | UNPROVEN | UNPROVEN | UNPROVEN | 0xB55604CF4dcdABB362078e106D20F98512391EdF |
| tokenstaking_claim | UNPROVEN | UNPROVEN | UNPROVEN | 0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00 |
| claim_vault | UNPROVEN | UNPROVEN | UNPROVEN | 0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0 |
| underlying_se_earlier | FAIL | FAIL | UNPROVEN | 0xb7D4Bb379d361aD442Cddee53EA71A33957826A7 |
| underlying_se_weighted_weth | FAIL | FAIL | UNPROVEN | 0x999DaE02D22E5FEe1c4508430D5196d31d631009 |
| underlying_se_weighted_dtf | UNPROVEN | UNPROVEN | UNPROVEN | 0x2E9C1F705aB967c5Af59249203d7495bDabb223b |
| underlying_se_shares | FAIL | FAIL | UNPROVEN | three identities; do not collapse |
| fungible_lp_earlier | FAIL | FAIL | UNPROVEN | 0x923877336b14662cFb5B3A60b14e7d716d54A888 |
| fungible_lp_weighted | FAIL | FAIL | UNPROVEN | 0x46E068c2393e189Fbc86632f67210aF253a42Aa8 |
| fungible_lp_token | FAIL | FAIL | UNPROVEN | two identities; distinct from both NFT models |
| native_eth | UNPROVEN | UNPROVEN | UNPROVEN | native |
| weth | UNPROVEN | UNPROVEN | UNPROVEN | 0x0bd7d308f8e1639fab988df18a8011f41eacad73 |

No verification cell is PASS. PASS inside a later field is a demonstrated source capability, not route closure.

## Rows

### weighted_detf

Plan category: both DETF generations. Required: yes. Generation: weighted.

Recorded identity: Weighted DETF, 9-decimal liquid token. Plan section 2.1 and ENTITLEMENT_LEDGER_PROVENANCE.md section 3.2.

Fresh or pinned execution identity: Same address. Fresh other-sources name() returned DTF-DETF, decimals 9, at the fresh pin. Not relabeled as the historical pin.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `balanceOf(address)` `0x70a08231`: uint256
- `approve(address,uint256)` `0x095ea7b3`: bool
- `transferFrom(address,address,uint256)` `0x23b872dd`: bool
- `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` `0xd02d3063`: one uint256; current repository interface is two-value and was not substituted
- `previewExchangeIn(address,uint256,address)` `0x89d61912`: one uint256

Code identity: Proxy runtime keccak 0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601 is shared and insufficient. ERC20 facet 0x1d17acA0e0717d90cea916372070a1BE4652223F runtime 0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50, Sourcify match not exact_match.

- source: **PASS**. Pinned historical address, facet binding and deployed ERC20 source authenticated by the weighted probe. requested historical pin block 108944663 hash 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733 chain 4663; not a fresh block Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/probe.results.json](evidence/weighted/probe.results.json); [evidence/weighted/probe.sources.json](evidence/weighted/probe.sources.json).
- unit: **PASS**. 9 decimals. Native DETF units. Not 18-decimal earlier DETF and not gons. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/source-state-summary.json](evidence/weighted/source-state-summary.json).
- ownership: **PASS**. balanceOf reads current units. Ordinary transfer changes balances and emits Transfer with no Migration callback. Current balance is not contribution ancestry. Evidence: [evidence/weighted/probe.sources.json](evidence/weighted/probe.sources.json); [attribution-spec.md](attribution-spec.md).
- custody: **PASS**. Pinned local fork transferFrom custody succeeded. Fixture is EOA 0x000000000000000000000000000000000000c057, not a Migration proxy. Rollback restored. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/probe.results.json](evidence/weighted/probe.results.json).
- remaining-unit: **UNPROVEN**. balanceOf is a current unit read, not remaining attributable credit. Mixed transfer history is not recoverable from the balance. Unknown ancestry is not zero. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/weighted/report.md](evidence/weighted/report.md).
- harvest: **PASS**. Pinned staged exchangeIn to DTF succeeded. direct-first-run measured 38283506 raw DETF to 216228659430800592372 raw DTF. That delta is a measured conversion, not an entitlement. Direct SY to DTF was not this row. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/direct-first-run.results.json](evidence/weighted/direct-first-run.results.json).
- proof: **FAIL**. E2 balance-only attribution FAIL on this token. Witness histories H1/H2 end at the same balances and require different credits. No post-activation authenticated history verifier was established. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/attribution/witness-r3.results.json](evidence/attribution/witness-r3.results.json).
- verification: **FAIL**. Not supported. Custody and staged harvest evidence do not close E1 atomic Migration handoff or E2. Address existence is not support. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: No VaultDisabled result recorded for this DETF exchangeIn path on the pinned fork.

Fixture: Weighted probe local custodian EOA; not MigrationLegacySources.

### earlier_cp_detf

Plan category: both DETF generations. Required: yes. Generation: earlier_cp.

Recorded identity: Earlier CP DETF, 18-decimal liquid token.

Fresh or pinned execution identity: Same address. Fresh name() returned WETH / Down to Finance Uniswap V4 DETF, decimals 18. Pinned Alchemy replay and fresh replay are separately labeled.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `sellPositionToDetfNft(uint256,address)` `0x6b7d927e`: uint256 principal shares
- `closeBondMature(uint256,uint256[],address,uint256)` `0x7c212893`: uint256[]
- `redeemClaim(uint256,address,uint256,address,uint256)` `0xbfe55606`: uint256
- `transfer / balanceOf` `0xa9059cbb / 0x70a08231`: bool / uint256

Code identity: Core facet 0x8333749Cc7b1f66b5be568257d362aA749497Cf0 hash 0x5b5f12902a0baeb235ec2dc91794c425a0c60a439a7d9070cb1abb17b094389d. Missing facet 0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE Sourcify HTTP 404, observed hash 0xa289425ebf221bd44551376c3459083a4d53eb30f485b48e783bf8291f7a05d6, selectors 0x6a4d3f12, 0xf5ee7c5b, 0x36abf3dc, 0x7cc34bb4. A name read of MultiAssetStandardVaultFacet is not verified source.

- source: **UNPROVEN**. Relevant verified core facet matched observed runtime. Complete source authentication is UNPROVEN because one routed facet returned Sourcify HTTP 404. requested historical pin block 108944663 hash 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733 chain 4663; not a fresh block. separately labeled fresh block 110859526 hash 0x95e705f74dedcea73e2c87c4276435e1ccb498680f1c46e25fba8bb1aa0cac36; not the historical pin. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.source.json](evidence/earlier-cp/probe-alchemy-retry.source.json).
- unit: **PASS**. 18 decimals on the pinned and fresh reads. Not 9-decimal weighted DETF credit. Evidence: [evidence/earlier-cp/probe-alchemy-retry.summary.json](evidence/earlier-cp/probe-alchemy-retry.summary.json); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md).
- ownership: **PASS**. balanceOf and transfer move current units. The same generic transfer interface has no Migration callback. Acquisition cost in the frozen ledger is unproved. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [attribution-spec.md](attribution-spec.md); [evidence/provenance/report.md](evidence/provenance/report.md).
- custody: **PASS**. Pinned Alchemy retry transferred 1000000000000000000 raw old DETF with an equal recovery delta. Fresh replay is separately labeled and is not this historical PASS. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.json](evidence/earlier-cp/probe-alchemy-retry.json).
- remaining-unit: **UNPROVEN**. A liquid balance does not identify original ETH/DTF components or remaining prequoted credit. Provenance observed 6 rows and left acquisition unproved. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md); [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json).
- harvest: **FAIL**. This liquid token was custodied, not redeemed through the disabled underlying vault in that liquid-transfer case. Mature close and receipt redemption, which are the position harvest routes, revert VaultDisabled. Do not treat liquid custody as a harvest PASS. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.json](evidence/earlier-cp/probe-alchemy-retry.json).
- proof: **FAIL**. Attribution-spec records the same transfer-interface blocker. The H1/H2 witness transactions ran against weighted DETF, not this token. Acquisition history is also incomplete. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/provenance/report.md](evidence/provenance/report.md).
- verification: **FAIL**. Not supported. Incomplete source authentication, disabled harvest routes, and the transfer-interface attribution blocker remain. Address existence is not support. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: Underlying SE 0xb7D4Bb379d361aD442Cddee53EA71A33957826A7 reverts VaultDisabled(address), selector 0x1ba84b43, on mature close and receipt redemption.

Fixture: Recovery EOA 0x100000000000000000000000000000000000c001. Not a Migration proxy.

### weighted_nft

Plan category: both NFT models. Required: yes. Generation: weighted.

Recorded identity: Fixed-principal funded bond NFT. Purchased IDs 3-45. IDs 0-2 reserved. Not an LP lock and not a fungible LP.

Fresh or pinned execution identity: Weighted custody evidence is the historical pin, not a fresh-block fallback. IDs 44-45 are post-incident purchases inside that pin, not pre-incident snapshot positions.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `ownerOf(uint256)` `0x6352211e`: address; zero observed for burned/nonexistent is not custody
- `positionOf(uint256)` `0x46f96023`: principal, claimedPrincipal, stakingGons, startTimestamp, vestingDuration
- `previewClaim(uint256)` `0xae648e90`: vestedPrincipal, principalRemaining, principalDue, rewardsDue
- `safeTransferFrom(address,address,uint256)` `0x42842e0e`: none
- `claimBond(uint256,address)` `0x084c59ae`: two uint256
- `claimPrincipal / claimRewards` `0xf400c743 / 0x6c7b69cb`: uint256 / uint256

Code identity: Funded bond facet 0x3a07364eabA092472d40F0e6788b8891A31faD4D runtime 0x325a3b9bf3e616386e03d2a14d0a1fb29820f104a5f433d0b08a88dbdd0bef52. Generic ERC721 facet 0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279 is Sourcify match, not exact_match.

- source: **PASS**. Historical chain, selector bindings and deployed bond source authenticated. requested historical pin block 108944663 hash 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733 chain 4663; not a fresh block Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/probe.sources.json](evidence/weighted/probe.sources.json); [evidence/weighted/deployed-source-extracts.json](evidence/weighted/deployed-source-extracts.json).
- unit: **PASS**. Fixed principal is 9-decimal DETF units. Remaining principal is principal minus claimedPrincipal. Rewards and currently due principal are different quantities. Example, not an award: NFT 4 original 281387179, claimed 0, remaining 281387179, currently due 86292556. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/source-state-summary.json](evidence/weighted/source-state-summary.json).
- ownership: **PASS**. ownerOf is the current owner. NFT 26 owner at the pin is 0x2e69E40C4a4Ab5CA6826850F347acf8076a8063e, not the original purchaser. Approval is not beneficiary authentication. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/probe.historical-receipts.json](evidence/weighted/probe.historical-receipts.json).
- custody: **PASS**. Whole-NFT safeTransferFrom of ID 3 moved the identity with position fields unchanged. direct-first-run claimBond then measured 4308806205 raw sDETF and burned the NFT. Repeat claim failed. EOA fixture, not Migration callback. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/direct-first-run.results.json](evidence/weighted/direct-first-run.results.json); [evidence/weighted/probe.results.json](evidence/weighted/probe.results.json).
- remaining-unit: **PASS**. Remaining total principal is readable as principal minus claimedPrincipal for extant positions. Burned IDs 25 and 42 and nonexistent 46 revert ERC721NonexistentToken 0x7e273289. A zero ownerOf is not eligibility. Reward-only after full principal claim has remaining principal 0 and must not gain credit from gons. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/source-state-summary.json](evidence/weighted/source-state-summary.json).
- harvest: **FAIL**. Staged claim, unstake and DTF conversion succeeded for the custodian, including 24312424763253115621623 raw DTF in direct-first-run. The same deployed claim accepts an approved operator and an arbitrary nonzero recipient. Operator 0x...0a11 paid 4308806205 raw sDETF to 0x...0bad. That is a source-protection FAIL, not a custody miss. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/direct-first-run.results.json](evidence/weighted/direct-first-run.results.json); [evidence/weighted/deployed-source-extracts.json](evidence/weighted/deployed-source-extracts.json).
- proof: **UNPROVEN**. Identity-local attribution is feasible. Integrated surrender, credit consumption, descendant nonduplication and a fresh 90-day bond were not executed. C0 is not computed. Withdrawn principal is not a second descendant award. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/weighted/report.md](evidence/weighted/report.md).
- verification: **FAIL**. Not supported. Operator redirection is an incompatible source behavior. Atomic Migration handoff and zero-principal migration rejection are UNPROVEN. Reserved and burned reads are not awards. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: Approved-operator recipient redirection is accepted by deployed _claim. Adapter must bind the current owner and a fixed recovery recipient.

Fixture: EOA custodian 0x000000000000000000000000000000000000c057. Attacker/operator fixtures end 0a11 and 0bad.

Preserved rule, not executed: award = floor(C0 * remainingPrincipal / originalPrincipal) on one frozen funded snapshot; C0 = U(ETH, E0) + U(DTF, D0). P0 zero, nonexistent, burned, or remaining principal zero is ineligible. No configuration premint. This unit computed no C0 and approved no award.

### earlier_cp_nft_lp_lock

Plan category: both NFT models. Required: yes. Generation: earlier_cp.

Recorded identity: LP-share lock NFT. Not the fungible LP at 0x923877336b14662cFb5B3A60b14e7d716d54A888. Not funded DETF principal.

Fresh or pinned execution identity: Same address. Pinned Alchemy custody is historical. Fresh replay is separately labeled and does not replace the pin.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `getPosition(uint256)` `0xeb02c301`: originalShares, effectiveShares, bonusMultiplier, unlockTime, rewardDebt
- `originalSharesOf(uint256)` `0x0f3767df`: uint256 LP accounting shares
- `ownerOf(uint256)` `0x6352211e`: address
- `pendingRewards(uint256)` `0x7dcb2abf`: uint256 old DETF
- `claimRewards(uint256,address)` `0x6c7b69cb`: uint256
- `lpToken()` `0x5fcbd285`: address
- `convertToAssets(uint256)` `0x07a2d13a`: LP assets

Code identity: DETFNFTVaultFacet 0x3AB85813785b43B864F9C171F7ac97d6B76c459b hash 0xe44c05ff19808e8e7096c7e470cb1d40ddaf057f4e53818f1e749621d3632027. NewLock topic 0x6c9c08a1f1b7feb37476c6618f41abf6bb2f0ed71f504b88f6503b3a2a8475e5. No claimedPrincipal field was observed.

- source: **UNPROVEN**. NFT facet runtime matched. Full dependency authentication remains UNPROVEN because a different DETF facet is missing. requested historical pin block 108944663 hash 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733 chain 4663; not a fresh block Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.source.json](evidence/earlier-cp/probe-alchemy-retry.source.json).
- unit: **PASS**. originalShares are LP accounting shares, 18-decimal asset conversion observed. effectiveShares include reward weight. Neither is fixed DETF principal. NFT 4 originalShares 2281854312954086546. Do not rename these fields. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.summary.json](evidence/earlier-cp/probe-alchemy-retry.summary.json).
- ownership: **PASS**. ownerOf read and transfer demonstrated. NFT 4 owner at the tested pin was 0x230f95db9644C5b3608bA676D18426d03e435B1D before custody. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.json](evidence/earlier-cp/probe-alchemy-retry.json).
- custody: **PASS**. Pinned transfer 0x3e3b2b3d5ad372acb94c7f5b2af467e4aba3a310be6b0fdd06316d909953e398 moved NFT 4. Reward claim 0x5dfa0bfd67a8a62b6db4867245de7a3e2332195d97a75219bc0b6dd6e9ca1d45 paid 309005608995105 raw old DETF and left original shares unchanged. Locked NFT 3 custody retained lock and shares. These hashes were found in probe-alchemy-retry.json. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.json](evidence/earlier-cp/probe-alchemy-retry.json).
- remaining-unit: **PASS**. Live originalShares remain after reward claim. Sale zeroes all five fields and burns the identity. There is no claimedPrincipal partial-withdrawal model. ID 999999 absent. Standing ID 1 has zero original shares and was restricted. Still-locked shares are not zero merely because withdrawal is unavailable. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.summary.json](evidence/earlier-cp/probe-alchemy-retry.summary.json).
- harvest: **FAIL**. Sale to receipt 0x3d54621af7e5dff968aed64f3639d0222170d962ead7c80339f39a33ede46042 succeeded and created a descendant receipt, not a second award. closeBondMature 0x61fb08ec01b576756fa25ae3ab9631613f140471c843576a2eac3774a7ff37a1 reverted VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7). Wrong-owner mature-close authorization is masked and UNPROVEN. Approved-operator reward redirection reverted; that PASS is not a mature-close authorization PASS. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.json](evidence/earlier-cp/probe-alchemy-retry.json).
- proof: **UNPROVEN**. 16 purchase receipts matched frozen inputs. Routed DTF is not a second contribution. Descendant receipt is not an independent award. Integrated credit and fresh bond were not executed. S011 does not contain these purchase receipts, so independent provenance replay is ABSENT_UNPROVEN. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/provenance/report.md](evidence/provenance/report.md); [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json).
- verification: **FAIL**. Not supported. Mature withdrawal is blocked. LP shares are not funded principal. Atomic Migration handoff is UNPROVEN. Distinct from the fungible LP row. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: VaultDisabled blocks closeBondMature. Deployed public closeBondMature body does not show a holder check before DETF-only child retirement; the probe reaches VaultDisabled first.

Fixture: Recovery EOA 0x100000000000000000000000000000000000c001. Attacker fixture ends bad1.

### weighted_sdetf

Plan category: sDETF/earlier receipts. Required: yes. Generation: weighted.

Recorded identity: 9-decimal rebasing receipt. Replay in gons. Summing Transfer amounts is not a balance.

Fresh or pinned execution identity: Custody evidence is the historical pin. No fresh-block relabel.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `gonsOf(address)` `0x79a67521`: uint256
- `stakingState()` `0xe082f1d4`: seven uint256: totalGons, gonsPerUnit, accountedBacking, allocationDust, stakingDust, feeWeight, creatorWeight
- `exchangeIn(...)` `0xd02d3063`: one uint256

Code identity: Facet 0xB7581fe833a2B2380DD786B345D61FFB734D36EB runtime 0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361. Pinned gonsPerUnit 876973181092115404940326782759509937.

- source: **PASS**. Pinned facet and deployed staking source authenticated. Current worktree receipt target hash differs and was not substituted. requested historical pin block 108944663 hash 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733 chain 4663; not a fresh block Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/source-comparison.json](evidence/weighted/source-comparison.json); [evidence/weighted/probe.sources.json](evidence/weighted/probe.sources.json).
- unit: **PASS**. 9-decimal nominal units plus internal gons. A partial unstake debits amount times current index. A full-account unstake debits remaining gons, including the final fraction. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/deployed-source-extracts.json](evidence/weighted/deployed-source-extracts.json).
- ownership: **PASS**. balanceOf and gonsOf read current receipt ownership. They do not identify original ETH/DTF credit. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [attribution-spec.md](attribution-spec.md).
- custody: **PASS**. Pinned transferFrom of 38283506 raw sDETF then unstaked to the same raw DETF amount in direct-first-run. Rollback restored. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/direct-first-run.results.json](evidence/weighted/direct-first-run.results.json).
- remaining-unit: **UNPROVEN**. Current gons fix representation, not mixed contribution ancestry. Provenance has 198 observed rows and route UNPROVEN. Later holders of claimed descendants are UNPROVEN. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md); [attribution-spec.md](attribution-spec.md).
- harvest: **PASS**. Unstake to DETF and DETF exchangeIn to DTF succeeded on the pinned fork for the tested custodian amount. That is a staged source conversion, not a Migration donation. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/probe.results.json](evidence/weighted/probe.results.json).
- proof: **UNPROVEN**. Complete mixed contribution and prequoted-credit ancestry is UNPROVEN. Gons are not a sufficient ancestry proof. A receipt descendant of an NFT claim is not a second purchase. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/weighted/report.md](evidence/weighted/report.md).
- verification: **UNPROVEN**. Not supported. Source custody and unstake passed. Attribution, descendant nonduplication and atomic bond creation did not. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: No disabled-state result recorded for this unstake path.

Fixture: Same weighted EOA custodian. Not MigrationLegacySources.

### earlier_cp_receipt

Plan category: sDETF/earlier receipts. Required: yes. Generation: earlier_cp.

Recorded identity: 18-decimal rebasing receipt. Latest-state observation in the frozen ledger is not a pinned historical balance census. Exception C2 leaves the supply gap UNKNOWN and not allocatable.

Fresh or pinned execution identity: Pinned displayed supply 57898677945502333609. Fresh displayed supply 57898677945502049312. These are not one number.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `sharesOf(address)` `0xf5eb42dc`: external accounting shares
- `totalShares()` `0x3a98ef39`: external accounting shares
- `redemptionRate()` `0x540385a3`: WAD rate; observed 2197
- `convertToShares / convertToClaim` `0xc6e6f592 / 0x2fbc6fea`: source-specific quantities
- `redeem(uint256,address,bool)` `0x5236be40`: uint256 pair-token output

Code identity: Facet 0x25E611FB63Eb904776678286EF5cbe2a931B4f9A hash 0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc. SHARE_SCALE 10^9. SHARE_UNIT 10^27. External shares lose internal precision.

- source: **PASS**. Receipt facet runtime matched on the pinned replay. This does not authenticate the missing DETF facet. requested historical pin block 108944663 hash 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733 chain 4663; not a fresh block Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.source.json](evidence/earlier-cp/probe-alchemy-retry.source.json).
- unit: **PASS**. 18 decimals. Transfer of 1000000000000000000 raw receipt produced displayed 999999999999999999 and 455166135639508420573509330905780 external shares. Not 1:1 with DETF or LP. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.summary.json](evidence/earlier-cp/probe-alchemy-retry.summary.json).
- ownership: **PASS**. Displayed balance and sharesOf move on transfer. The emitted native amount is not an exact displayed-balance delta. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [attribution-spec.md](attribution-spec.md).
- custody: **PASS**. Pinned receipt transfer custody succeeded. Sale of NFT 4 minted 4322 raw receipt and 1967558883021387942 external shares to recovery. That descendant is one representation, not a second award. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.json](evidence/earlier-cp/probe-alchemy-retry.json).
- remaining-unit: **UNPROVEN**. Holder-sum versus supply discrepancy is unresolved. Provenance status OBSERVED_LATEST_STATE. Do not assign the gap to users. Do not treat a blank acquisition field as zero. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md); [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json).
- harvest: **FAIL**. redeemClaim 0xe4359e06c585390d0c6e33cfb105c2384f58c4f9b44d75e1e0c566a2a97109e9 reverted VaultDisabled. Direct receipt redeem 0x22fb95c8bfd0b3f7c58faa20f4672371f4740ffb8a3276cccb3ff2a731880a0d also reverted VaultDisabled and is UNPROVEN as an alternate route, not a PASS. Custodied assets remained. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.json](evidence/earlier-cp/probe-alchemy-retry.json).
- proof: **UNPROVEN**. Rounded share conversion does not prove mixed original credit. Complete ancestry is UNPROVEN. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md).
- verification: **FAIL**. Not supported. Custody passed. Required redemption is blocked by VaultDisabled. Supply gap remains UNKNOWN. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/provenance/report.md](evidence/provenance/report.md).

Disabled or incompatible behavior: VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7) on both tested redemption routes.

Fixture: Recovery EOA. Not a Migration proxy.

### weighted_sy

Plan category: SY. Required: yes. Generation: weighted.

Recorded identity: 9-decimal wrapper shares. Not a second claim on backing sDETF.

Fresh or pinned execution identity: Fresh name() returned SY Staked DTF-DETF, decimals 9. Weighted custody evidence itself is the historical pin.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `yieldToken()` `0x76d5de85`: address; assigned sDETF
- `exchangeRate()` `0x3ba0b9a9`: uint256 WAD; pinned 1140285725447928057
- `getTokensOut()` `0x071bc3c9`: address[]
- `previewRedeem / redeem` `0xcbe52ae3 / 0x769f8e5d`: uint256 / uint256

Code identity: Facet 0x4B6e65CfC9a16aae0DfA4257A680f4697275e5fc runtime 0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d. Pinned wrapper holds 54373903589043794139626986358920462592399234625 gons, represented as 62001786099 raw sDETF.

- source: **PASS**. Pinned SY facet and deployed source authenticated. Current worktree SY target hash differs and was not substituted. requested historical pin block 108944663 hash 0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733 chain 4663; not a fresh block Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/source-comparison.json](evidence/weighted/source-comparison.json).
- unit: **PASS**. 9-decimal static shares. Each share converts through 1e36 gons and the funded exchange rate. Conversion dust is retained by the source. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/deployed-source-extracts.json](evidence/weighted/deployed-source-extracts.json).
- ownership: **PASS**. Share balanceOf is current wrapper ownership. It is not a second balance of the backing receipt. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [attribution-spec.md](attribution-spec.md).
- custody: **PASS**. Pinned transferFrom custody of 8094 SY then redeem paid 9245 sDETF and the surrendered SY balance became zero in direct-first-run. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/direct-first-run.results.json](evidence/weighted/direct-first-run.results.json).
- remaining-unit: **UNPROVEN**. Shares and backing are one economic claim. Provenance has 17 observed share rows. Wrapper ancestry through later transfers is UNPROVEN. Crediting both wrapper and backing would double count. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/provenance/report.md](evidence/provenance/report.md).
- harvest: **UNPROVEN**. Staged SY to sDETF to DETF to DTF passed, including 52221256856930805 raw DTF from the 9245 sDETF in direct-first-run. Direct SY to DTF was not tested. No selector-existence claim is made for the untested route. Claim-vault redemption into this SY is a different row. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/direct-first-run.results.json](evidence/weighted/direct-first-run.results.json).
- proof: **UNPROVEN**. One economic claim rule is required and not implemented as a Migration nullifier. Full wrapper ancestry is UNPROVEN. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/weighted/report.md](evidence/weighted/report.md).
- verification: **UNPROVEN**. Not supported. Staged redemption passed. Direct route, ancestry and atomic bond creation did not. Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: Disabled-state matrix was not executed.

Fixture: Weighted EOA custodian.

### tokenstaking_claim

Plan category: TokenStaking/claim-vault rights. Required: yes. Generation: weighted.

Recorded identity: Legacy TokenStaking. 18-decimal DTF-denominated weights. Not an ERC-20 and not DETF units. Frozen ledger has 92 observed weight rows.

Fresh or pinned execution identity: Historical Alchemy read totalSupply 15338080546808403036783930 at block 108944663. Historical custody acquisition then HTTP 429. Fresh custody is not that historical read.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `reassign(address,uint256)` `0xcc447fba`: none
- `withdrawClaim(uint256)` `0xa224dcb7`: uint256
- `claimVault()` `0xab518e6e`: address
- `balanceOf(address)` `0x70a08231`: uint256 weight
- `approve/transfer/transferFrom` `unbound`: facet binding zero; name() and decimals() reverted

Code identity: Fresh binding facet 0x9C90d4a476f3473b9a0e32B530aF3474271a80B1 runtime 0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742. Current TokenStakingTarget.sol explains the mechanism and is not authenticated legacy bytecode. Source phase observed 2 (Wrapped).

- source: **UNPROVEN**. Historical code and totalSupply were read. Historical source acquisition stopped on HTTP 429, so historical custody is UNPROVEN. Fresh routing is separately labeled. separately labeled fresh block 110862604 hash 0x4097f2411c284e399051ef93ab5ff2f46b0230e49a2a0c685d2c4e3acb36ff80; not the historical pin Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-alchemy.json](evidence/other-sources/probe-alchemy.json); [evidence/other-sources/probe-alchemy-r2.json](evidence/other-sources/probe-alchemy-r2.json); [evidence/other-sources/alchemy-retry-receipt.json](evidence/other-sources/alchemy-retry-receipt.json).
- unit: **PASS**. Weights are DTF-denominated and not DETF. decimals() reverted, so 18 decimals is the recorded ledger unit, not a fresh decimals() success. Do not invent a decimals read. Evidence: [../ENTITLEMENT_LEDGER_PROVENANCE.md](../ENTITLEMENT_LEDGER_PROVENANCE.md); [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json).
- ownership: **PASS**. Holder-only reassign. No operator pull and no Migration callback. Claim holder 0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3 is an actual recorded EOA, not an infrastructure contract. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.json](evidence/other-sources/probe-public-r4.json).
- custody: **PASS**. Fresh-pin reassign 0x1ef021c20f3e08df3ebd722e1f9c44b180c7e913972ac33b1df11f78c9e177ae moved 64890781291192882058375 weight to custodian 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 and left the former holder at 0. This is not a historical-pin custody PASS. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.json](evidence/other-sources/probe-public-r4.json).
- remaining-unit: **PASS**. Remaining exercisable weight is balanceOf. After reassign the original holder retained none of that weight. Zero reassignment, zero claim and a second withdrawClaim reverted. This does not value the weight as credit. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- harvest: **PASS**. Fresh staged withdrawClaim 0x965e7f7265aa42a3837370a5715a33232b6688f186ab1b12052abaf5826f8ce5 consumed the custodied weight and paid 117153341 raw SY. Not 1:1. Repeat claim reverted. Integrated Migration issuance remains UNPROVEN. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.json](evidence/other-sources/probe-public-r4.json).
- proof: **UNPROVEN**. No operator pull or callback. Allocation ancestry and post-activation proportional credit are UNPROVEN. Weights and claim-vault SY are one remaining claim, not two. The migration adapter 0xC84999F31eA72A793a65ce73aa05ff624FDCBB51 is a recorded collective input, not this token. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/provenance/report.md](evidence/provenance/report.md); [../ENTITLEMENT_LEDGER_PROVENANCE.md](../ENTITLEMENT_LEDGER_PROVENANCE.md).
- verification: **UNPROVEN**. Not supported. Fresh mechanical surrender and SY conversion passed. Historical custody, user-wide exposure and atomic credit did not. HTTP 429 is a provider gap, not proof the mechanism is incompatible. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: ERC-20 transfer surface is unbound. Holder reassignment exists.

Fixture: Actual claim holder impersonated on the fresh fork. Custodian 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266.

### claim_vault

Plan category: TokenStaking/claim-vault rights. Required: yes. Generation: weighted.

Recorded identity: Claim vault holds SY for old TokenStaking claims. Provenance modeled 74 related inventory rows as SY-related custody, not a proved vault-share balance.

Fresh or pinned execution identity: Fresh name() returned Wrapped SY Staked DTF-DETF, decimals 19, at separately labeled fresh block 110862604 hash 0x4097f2411c284e399051ef93ab5ff2f46b0230e49a2a0c685d2c4e3acb36ff80. That pin is not historical. Do not relabel the frozen 74 rows as 19-decimal balances.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `balanceOf / transfer / transferFrom / approve` `0x70a08231 / 0xa9059cbb / 0x23b872dd / 0x095ea7b3`: uint256 / bool / bool / bool
- `redeem(uint256,address,address)` `0xba087652`: uint256

Code identity: Diamond proxy shares runtime hash 0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601. That hash does not identify behavior. Fresh behavior was executed, not independently source-verified.

- source: **UNPROVEN**. Fresh routing and decimals were read. Historical custody acquisition did not complete. Frozen rows are related inventory, not proved balances. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/provenance/report.md](evidence/provenance/report.md); [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json).
- unit: **PASS**. Fresh decimals() returned 19. Redemption output is 9-decimal SY. The two units must not be collapsed. Provenance's SY unit describes the related inventory model, not this fresh decimals read. Evidence: [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json); [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json).
- ownership: **UNPROVEN**. balanceOf is implemented. The fresh custody fixture impersonated TokenStaking 0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00, and probe-public-r4.summary.json marks fixtureMayBeInfrastructure true. That is not proof a user can command TokenStaking to surrender these shares. Wrong-operator transferFrom reverted. Do not read the TokenStaking weight-holder EOA as the holder of these shares. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- custody: **PASS**. Fresh mechanical transferFrom of 2769125838408621163 raw shares from impersonated TokenStaking 0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00. Holder remainder 274143458002453495139. Capability PASS is not user authority and not a historical-pin PASS. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- remaining-unit: **PASS**. Remaining shares were read back after transfer. After redemption custody shares were 0. This is not remaining migration credit. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- harvest: **PASS**. Fresh ERC-4626 redeem paid 276912584 raw 9-decimal SY. Mechanical only. Do not also credit the SY and the weight. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- proof: **UNPROVEN**. Allocation ancestry UNPROVEN. One remaining claim with TokenStaking weights. Current RebasingAwareERC4626Target.sol is explanatory, not authenticated legacy code. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/other-sources/report.md](evidence/other-sources/report.md).
- verification: **UNPROVEN**. Not supported. Fresh mechanical custody and redemption passed from the TokenStaking infrastructure holder. User authority, historical custody, and ancestry did not. Not a second award beside TokenStaking or SY. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: Not effectively disabled in the fresh registry read. That is not historical proof.

Fixture: Impersonated TokenStaking infrastructure holder on the fresh fork. Historical custody UNPROVEN.

### underlying_se_earlier

Plan category: underlying SE shares. Required: yes. Generation: earlier_cp.

Recorded identity: Earlier standardExchangeVault. Provenance had 0 standalone SE-share position rows: ABSENT_NOT_PROVED, not proved absent.

Fresh or pinned execution identity: Fresh name() UniV4 Vault of (WETH / DTF), decimals 18. Same name as weighted WETH-leg SE, different address. separately labeled fresh block 110862604 hash 0x4097f2411c284e399051ef93ab5ff2f46b0230e49a2a0c685d2c4e3acb36ff80; not the historical pin

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `balanceOf / transferFrom` `0x70a08231 / 0x23b872dd`: uint256 / bool
- `exchangeIn(...)` `0xd02d3063`: not successfully executed

Code identity: Shared proxy runtime hash is insufficient. Fresh behavior executed. Not independent source verification.

- source: **UNPROVEN**. Address resolved by earlier DETF standardExchangeVault() and registry membership. Frozen position rows do not prove absence. Historical other-sources custody UNPROVEN. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/provenance/report.md](evidence/provenance/report.md).
- unit: **PASS**. 18 decimals on the fresh read. Not the 28-decimal weighted DTF custody shares. Evidence: [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json); [evidence/other-sources/report.md](evidence/other-sources/report.md).
- ownership: **UNPROVEN**. Fresh transferFrom used an infrastructure holder. That proves token mechanics, not that a user can command the holder to surrender. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- custody: **PASS**. Fresh mechanical transferFrom of 2402083350942343165016427703439986226 raw shares and rollback PASS. Not user authority and not historical. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- remaining-unit: **PASS**. Holder and custody balances were read back. After failed harvest, custody remainder stayed equal to q. Not attributable credit. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- harvest: **FAIL**. WETH and DTF exact-in exits revert VaultDisabled(source), selector 0x1ba84b43. Same disabled vault blocks earlier NFT mature close and receipt redemption. No re-enable was performed. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md).
- proof: **UNPROVEN**. Mixed ancestry UNPROVEN. Zero frozen rows are not absence. Infrastructure balance is not user eligibility. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/provenance/report.md](evidence/provenance/report.md).
- verification: **FAIL**. Not supported. Harvest from the tested custodian is blocked. User exposure is UNPROVEN, not absent. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: Registry isDisabled true for this source on the fresh pin. Pinned earlier-cp calls revert the same VaultDisabled address.

Fixture: Infrastructure holder impersonation. fixtureMayBeInfrastructure true.

### underlying_se_weighted_weth

Plan category: underlying SE shares. Required: yes. Generation: weighted.

Recorded identity: Recorded in the provenance address map. No standalone position rows. Not proved absent.

Fresh or pinned execution identity: Fresh name() UniV4 Vault of (WETH / DTF), decimals 18. Do not merge with 0xb7D4 despite the same name. separately labeled fresh block 110862604 hash 0x4097f2411c284e399051ef93ab5ff2f46b0230e49a2a0c685d2c4e3acb36ff80; not the historical pin

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `redeem(address,uint256,address,uint256,bool)` `0x769f8e5d`: uint256; call reverted
- `exchangeIn(...)` `0xd02d3063`: call reverted

Code identity: Shared proxy runtime hash is insufficient. Fresh behavior executed. Not independent source verification.

- source: **UNPROVEN**. Resolved by weighted deployment exports, registry membership and source metadata. Historical custody UNPROVEN. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json).
- unit: **PASS**. 18 decimals. Distinct from the 28-decimal DTF custody shares. Evidence: [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json).
- ownership: **UNPROVEN**. Infrastructure-holder impersonation only. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md).
- custody: **PASS**. Fresh mechanical transferFrom of 23634291028048331275075 raw shares and rollback PASS. Not historical and not user authority. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- remaining-unit: **PASS**. Balances read back. Failed harvest left custody remainder equal to q. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- harvest: **FAIL**. SY redemption and Standard Exchange exact-in to WETH and DTF revert VaultDisabled(source). Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- proof: **UNPROVEN**. Mixed ancestry and user exposure UNPROVEN. Evidence: [attribution-spec.md](attribution-spec.md).
- verification: **FAIL**. Not supported. Tested exits are disabled. Do not omit because the frozen ledger had no position rows. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/provenance/report.md](evidence/provenance/report.md).

Disabled or incompatible behavior: Registry isDisabled true on the fresh pin.

Fixture: Infrastructure holder.

### underlying_se_weighted_dtf

Plan category: underlying SE shares. Required: yes. Generation: weighted.

Recorded identity: Recorded in the provenance address map. No standalone position rows. Not proved absent.

Fresh or pinned execution identity: Fresh name() Wrapped Down to Finance, decimals 28. separately labeled fresh block 110862604 hash 0x4097f2411c284e399051ef93ab5ff2f46b0230e49a2a0c685d2c4e3acb36ff80; not the historical pin

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `redeem(uint256,address,address)` `0xba087652`: uint256
- `exchangeIn(...)` `0xd02d3063`: bound; redemption used the ERC-4626 route

Code identity: Shared proxy runtime hash is insufficient. Fresh redemption executed. Not independent source verification.

- source: **UNPROVEN**. Resolved by registry and metadata. Historical custody UNPROVEN. A successful fresh redemption does not make the other two SE exits supported. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json).
- unit: **PASS**. 28 decimals in, 18-decimal DTF out. Do not treat as 18-decimal vault shares. Evidence: [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json); [evidence/other-sources/report.md](evidence/other-sources/report.md).
- ownership: **UNPROVEN**. Infrastructure-holder impersonation only. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md).
- custody: **PASS**. Fresh mechanical transferFrom of 1622646459016401842967981100000000 raw shares and rollback PASS. Not historical. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- remaining-unit: **PASS**. Balances read back. After redemption custody shares were 0. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- harvest: **PASS**. Fresh ERC-4626 redemption paid 162264645901640184296798 raw DTF. This PASS is not a PASS for the disabled SE shares and is not a historical-pin PASS. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- proof: **UNPROVEN**. User ancestry and eligible exposure UNPROVEN. Output DTF is recovery inventory, not a new contribution. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/other-sources/report.md](evidence/other-sources/report.md).
- verification: **UNPROVEN**. Not supported. One fresh redemption passed. Historical custody, user authority and ancestry did not. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: Not effectively disabled on the fresh registry read. The other two SE identities are disabled.

Fixture: Infrastructure holder.

### underlying_se_shares

Plan category: underlying SE shares. Required: yes. Generation: both.

Recorded identity: Provenance category underlying_se_shares: 0 rows, ABSENT_NOT_PROVED, route UNPROVEN.

Fresh or pinned execution identity: Three fresh identities with different decimals and harvest results. Same displayed name on two 18-decimal vaults is not identity.

Same address across labels: false. Relabeled as historical: false.

Child rows: underlying_se_earlier, underlying_se_weighted_weth, underlying_se_weighted_dtf.

- source: **UNPROVEN**. Identities resolved. Historical custody and user exposure not proved. Frozen absence is not on-chain absence. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/provenance/report.md](evidence/provenance/report.md).
- unit: **PASS**. Earlier 18, weighted WETH-leg 18, weighted DTF custody 28. Units are source-specific. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md).
- ownership: **UNPROVEN**. Tested holders are infrastructure. User command of those holders is not proved. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md).
- custody: **PASS**. Fresh mechanical custody passed for all three. Not historical and not user-authority proof. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- remaining-unit: **PASS**. Raw balances read back per identity. Not credit. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- harvest: **FAIL**. Earlier and weighted WETH-leg exits FAIL VaultDisabled. Weighted DTF custody redemption PASS on the fresh pin only. A parent PASS is forbidden. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md).
- proof: **UNPROVEN**. Mixed ancestry UNPROVEN for all three. Evidence: [attribution-spec.md](attribution-spec.md).
- verification: **FAIL**. Not supported. Category retained. Child failures are not omitted by the one successful redemption. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [attribution-spec.md](attribution-spec.md); [evidence/provenance/report.md](evidence/provenance/report.md).

Disabled or incompatible behavior: Two disabled, one not disabled. Do not blanket the category.

Fixture: Infrastructure holders.

### fungible_lp_earlier

Plan category: fungible LP tokens. Required: yes. Generation: earlier_cp.

Recorded identity: Physical reserve LP returned by earlier NFT lpToken(). Provenance fungible_lp_token category had 0 position rows, ABSENT_NOT_PROVED. Distinct from the NFT lock.

Fresh or pinned execution identity: Fresh name() SSEBCP-WETH-DTF-V4-DETF-DTF, decimals 18. separately labeled fresh block 110862604 hash 0x4097f2411c284e399051ef93ab5ff2f46b0230e49a2a0c685d2c4e3acb36ff80; not the historical pin. Native replay is a third pin.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `exchangeIn(...)` `0xd02d3063`: reverted UnsupportedRoute 0x5d5fe824
- `withdrawSeShares(uint256,address,uint256,uint256,uint256)` `0x84eb9bce`: reverted NotOwner 0x245aecd3
- `exitProportional / exitProportionalFlexible` `0x8b72d9e5 / 0x94b74d12`: selector absent on this LP

Code identity: Shared proxy runtime hash is insufficient. owner() is earlier DETF 0xaf0E1967c8F755c747615c5427108Bc549CA1122. ownerOnlyLiquidity() reverted; that is not a false reading.

- source: **UNPROVEN**. Address identified by NFT lpToken() and registry. Historical custody UNPROVEN. Not independent source verification. Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json).
- unit: **PASS**. 18 decimals. Not NFT token IDs and not LP accounting shares stored in the NFT. Evidence: [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md).
- ownership: **UNPROVEN**. owner() is the earlier DETF. The impersonated balance holder in the JSON evidence.owner field is the earlier NFT escrow 0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391. Those are different facts. User authority is UNPROVEN. Evidence: [evidence/other-sources/probe-native.summary.json](evidence/other-sources/probe-native.summary.json); [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json); [evidence/other-sources/report.md](evidence/other-sources/report.md).
- custody: **PASS**. Fresh mechanical transferFrom of 1075167226680908457977200216751522 raw shares and rollback PASS. Not historical and not user authority. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- remaining-unit: **PASS**. Balances read back. Failed exits left the custodied q unchanged. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json); [evidence/other-sources/probe-native.summary.json](evidence/other-sources/probe-native.summary.json).
- harvest: **FAIL**. Exact-in to earlier DETF and DTF reverted UnsupportedRoute. Native withdrawSeShares 0x1fc18e1c68581f11d2eab00d4e6ee1020bd699dd6d4b124f1bd5e92726ab9b36 reverted NotOwner(custodian). Proportional selectors are absent. Output deltas were zero. This does not prove every owner-mediated recovery is impossible. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-native.summary.json](evidence/other-sources/probe-native.summary.json).
- proof: **UNPROVEN**. User ancestry UNPROVEN. NFT lock and this fungible token are separate claims and must not be merged or omitted. Evidence: [attribution-spec.md](attribution-spec.md); [evidence/provenance/report.md](evidence/provenance/report.md).
- verification: **FAIL**. Not supported. Tested new-custodian exits failed. Distinct from the LP-lock NFT row. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: Not the VaultDisabled error. Failures are UnsupportedRoute and NotOwner. Registry did not mark this source effectively disabled.

Fixture: Earlier NFT escrow impersonated. owner() is the earlier DETF.

### fungible_lp_weighted

Plan category: fungible LP tokens. Required: yes. Generation: weighted.

Recorded identity: ENTITLEMENT_LEDGER_PROVENANCE.md calls this address the weighted reserve hook and says reserve settlement is not a user contribution.

Fresh or pinned execution identity: Same address. Fresh name() is SE Weighted Buffer Hook LP, decimals 18. owner() is weighted DETF. ownerOnlyLiquidity() is true. The ledger role and the fresh token name are two labels of one address, not two contracts. This unit does not convert the infrastructure label into user eligibility.

Identity note: Recorded role and fresh name differ in wording. Address, fresh name, owner() and failed custodian exits are all preserved. No reclassification.

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `exchangeIn(...)` `0xd02d3063`: reverted NotOwner
- `redeem(address,uint256,address,uint256,bool)` `0x769f8e5d`: reverted NotOwner
- `exitProportional` `0x8b72d9e5`: reverted NotOwner; tx 0x907c88a4a1c017b13b12a35dabd5e06ec1d5caefcf940499b6f8273ea2576e06
- `exitProportionalFlexible` `0x94b74d12`: reverted NotOwner; tx 0x4ab538ea64295736b32a289811d1f875f967dbae0b0602f9bf6baea54003d24d
- `withdrawSeShares` `0x84eb9bce`: selector absent
- `owner()` `0x8da5cb5b`: 0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7
- `ownerOnlyLiquidity()` `0xfe884e28`: true

Code identity: Shared proxy runtime hash is insufficient. getTokensOut advertised five addresses. That advertisement is not an executed exit.

- source: **UNPROVEN**. Address is in the frozen ledger and the provenance address map. Fresh LP behavior was executed. Historical custody UNPROVEN. Not independent source verification. Evidence: [../ENTITLEMENT_LEDGER_PROVENANCE.md](../ENTITLEMENT_LEDGER_PROVENANCE.md); [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json).
- unit: **PASS**. 18 decimals on the fresh read. Not an NFT id and not a hook-only non-token if the fresh fungible surface is the evidence. The recorded infrastructure role is preserved beside that unit. Evidence: [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json); [../ENTITLEMENT_LEDGER_PROVENANCE.md](../ENTITLEMENT_LEDGER_PROVENANCE.md).
- ownership: **UNPROVEN**. owner() is the weighted DETF. JSON evidence.owner for the custody case is the fee collector 0x20af9A1e21a59a411cd3b0c40E70AF9084770b2E, the impersonated balance holder. Do not read that field as owner(). User authority is UNPROVEN. Evidence: [evidence/other-sources/probe-native.summary.json](evidence/other-sources/probe-native.summary.json); [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json); [evidence/other-sources/report.md](evidence/other-sources/report.md).
- custody: **PASS**. Fresh mechanical transferFrom of 15166467477246491 raw shares and rollback PASS. Not historical and not user authority. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- remaining-unit: **PASS**. Balances read back. Failed exits left q unchanged. Not credit. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json); [evidence/other-sources/probe-native.summary.json](evidence/other-sources/probe-native.summary.json).
- harvest: **FAIL**. All tested exact-in outputs and both bound proportional exits reverted NotOwner(custodian). Output deltas were zero. Owner-mediated recovery was not proved impossible and was not proved available. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-native.summary.json](evidence/other-sources/probe-native.summary.json).
- proof: **UNPROVEN**. User ancestry UNPROVEN. Settlement flowing through this address is not a user contribution, per the frozen ledger. Fresh custody does not reverse that rule. Evidence: [../ENTITLEMENT_LEDGER_PROVENANCE.md](../ENTITLEMENT_LEDGER_PROVENANCE.md); [attribution-spec.md](attribution-spec.md).
- verification: **FAIL**. Not supported. Category not omitted because the ledger called the address a hook. Hook label is not deleted. Custodian exits failed. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [../ENTITLEMENT_LEDGER_PROVENANCE.md](../ENTITLEMENT_LEDGER_PROVENANCE.md); [attribution-spec.md](attribution-spec.md).

Disabled or incompatible behavior: Not VaultDisabled. NotOwner and ownerOnlyLiquidity true. Registry did not mark it effectively disabled.

Fixture: Fee collector balance holder. owner() is the weighted DETF.

### fungible_lp_token

Plan category: fungible LP tokens. Required: yes. Generation: both.

Recorded identity: Provenance fungible_lp_token: 0 rows, ABSENT_NOT_PROVED, route UNPROVEN. NFT LP lock is a different category.

Fresh or pinned execution identity: Earlier LP and weighted hook-named LP both have fresh 18-decimal fungible surfaces and failed new-custodian exits.

Same address across labels: false. Relabeled as historical: false.

Child rows: fungible_lp_earlier, fungible_lp_weighted.

- source: **UNPROVEN**. Identities resolved. Frozen position absence is not on-chain absence. Historical custody UNPROVEN. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/provenance/report.md](evidence/provenance/report.md).
- unit: **PASS**. Both fresh reads are 18 decimals. NFT lock shares remain a separate unit. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md).
- ownership: **UNPROVEN**. Contract owner() and impersonated balance holder differ on both tokens. User authority UNPROVEN. Evidence: [evidence/other-sources/probe-native.summary.json](evidence/other-sources/probe-native.summary.json).
- custody: **PASS**. Fresh mechanical custody passed for both. Not historical and not user authority. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- remaining-unit: **PASS**. Raw balances read back. Not credit. Evidence: [evidence/other-sources/probe-public-r4.summary.json](evidence/other-sources/probe-public-r4.summary.json).
- harvest: **FAIL**. Both tested custodian exit sets FAIL. Failure modes differ: UnsupportedRoute/NotOwner versus NotOwner/ownerOnlyLiquidity. Do not collapse the errors. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-native.json](evidence/other-sources/probe-native.json).
- proof: **UNPROVEN**. User ancestry UNPROVEN. Separate from NFT locks. Evidence: [attribution-spec.md](attribution-spec.md).
- verification: **FAIL**. Not supported. Category retained. Not merged into the NFT rows. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [attribution-spec.md](attribution-spec.md); [evidence/provenance/report.md](evidence/provenance/report.md).

Disabled or incompatible behavior: Not a disabled-vault result.

Fixture: Infrastructure holders.

### native_eth

Plan category: provenance coverage, not a surrender substitute. Required: yes. Generation: contribution.

Recorded identity: Native ETH was not reconstructed. Blank is UNKNOWN, not zero.

Fresh or pinned execution identity: No fresh native-ETH custody probe. Do not infer it from WETH.

Same address across labels: false. Relabeled as historical: false.

- source: **UNPROVEN**. No source contract. Provenance status ABSENT_NOT_PROVED. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md); [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json).
- unit: **UNPROVEN**. 18-decimal convention is recorded for ETH inputs. No reconstructed quantity. Unknown is not zero. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md).
- ownership: **UNPROVEN**. No owner read. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md).
- custody: **UNPROVEN**. No custody transaction. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md).
- remaining-unit: **UNPROVEN**. No remaining-unit read. Not zero. Evidence: [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json).
- harvest: **UNPROVEN**. No harvest route demonstrated. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md).
- proof: **UNPROVEN**. Not joined into contribution totals. NFT 3 weighted direct native ETH is UNKNOWN in provenance. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md).
- verification: **UNPROVEN**. Not supported. Not omitted. Not converted to zero. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md); [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json).

Disabled or incompatible behavior: Not applicable. No route was executed.

Fixture: None.

### weth

Plan category: provenance coverage, not a surrender substitute. Required: yes. Generation: contribution.

Recorded identity: 18-decimal WETH input. Partial inbound evidence. Not renamed to ETH. Post-cutoff coverage unproved.

Fresh or pinned execution identity: Fresh name() WETH, decimals 18. That metadata read is not a surrender route. separately labeled fresh block 110862604 hash 0x4097f2411c284e399051ef93ab5ff2f46b0230e49a2a0c685d2c4e3acb36ff80; not the historical pin

Same address across labels: true. Relabeled as historical: false.

Selectors:

- `name()` `0x06fdde03`: WETH
- `decimals()` `0x313ce567`: 18

- source: **PASS**. Address and 18-decimal unit are recorded and freshly named. Route support is not implied. Evidence: [../ENTITLEMENT_LEDGER_PROVENANCE.md](../ENTITLEMENT_LEDGER_PROVENANCE.md); [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json).
- unit: **PASS**. 18 decimals. Separate from native ETH. Evidence: [evidence/other-sources/probe-public-r4.sources.json](evidence/other-sources/probe-public-r4.sources.json); [evidence/provenance/report.md](evidence/provenance/report.md).
- ownership: **UNPROVEN**. 27 transfer rows are partial inbound evidence. A WETH balance is not a migration surrender right. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md); [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json).
- custody: **UNPROVEN**. No WETH surrender custody was the subject of these probes. WETH appears as a harvest output candidate that failed when the SE was disabled. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/provenance/report.md](evidence/provenance/report.md).
- remaining-unit: **UNPROVEN**. No remaining eligible WETH unit was established. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md).
- harvest: **UNPROVEN**. Disabled SE exact-in routes toward WETH failed. That failure is recorded on the SE rows. WETH itself is not a proved harvest destination for a new custodian. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md).
- proof: **UNPROVEN**. Partial inbound evidence only. Highest CSV row is not the query boundary. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md).
- verification: **UNPROVEN**. Not supported as a surrender source. Not omitted. Not renamed to ETH. Evidence: [evidence/provenance/report.md](evidence/provenance/report.md); [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json).

Disabled or incompatible behavior: Not a vault. Related SE exits that target it are disabled.

Fixture: None for surrender.

## Recorded identities that are not surrender rows

- DTF `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01`, 18 decimals. Quote input and recovery output. Routed intermediate DTF is not a second contribution. Evidence: [../ENTITLEMENT_LEDGER_PROVENANCE.md](../ENTITLEMENT_LEDGER_PROVENANCE.md).
- TokenStaking migration adapter `0xC84999F31eA72A793a65ce73aa05ff624FDCBB51`. Recorded collective input. Not a substitute for the weight token. Not re-probed here. Route UNPROVEN. Evidence: [../ENTITLEMENT_LEDGER_PROVENANCE.md](../ENTITLEMENT_LEDGER_PROVENANCE.md).
- Registry `0x09682b00D873D913ada0bB69B4D4c9631810d0bc`. `vaultsOfToken` selector `0x2b9fc930`. Forty-three observed identities are not admission. Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md).
- Rehearsal export `0x8ff37779B8Fe866470aEcf64910F4Bf899d73705`. Ledger says no code at the pinned head. This unit did not reread code. Not a source and not support. Evidence: [../ENTITLEMENT_LEDGER_PROVENANCE.md](../ENTITLEMENT_LEDGER_PROVENANCE.md).

## Preserved failures

### E2-interface

- Class: product-blocker. Status: **FAIL**. Producer: attribution.
- Balance-identical histories require unequal credits. Witness exit 0 printed ATTRIBUTION_COUNTEREXAMPLE_PASS. That is counterexample success, not E2 closure.
- Evidence: [attribution-spec.md](attribution-spec.md); [evidence/attribution/witness-r3.results.json](evidence/attribution/witness-r3.results.json).

### E1-atomic-handoff

- Class: product-blocker. Status: **UNPROVEN**. Producer: all custody producers.
- No probe executed integrated entitlement consumption and fresh funded bond creation.
- Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/other-sources/report.md](evidence/other-sources/report.md); [attribution-spec.md](attribution-spec.md).

### weighted-operator-redirect

- Class: product-blocker. Status: **FAIL**. Producer: weighted.
- Approved operator directed claimBond to a stranger.
- Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/weighted/probe.results.json](evidence/weighted/probe.results.json).

### earlier-vault-disabled

- Class: product-blocker. Status: **FAIL**. Producer: earlier-cp.
- VaultDisabled on closeBondMature, redeemClaim and receipt redeem.
- Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.json](evidence/earlier-cp/probe-alchemy-retry.json).

### earlier-missing-facet

- Class: product-blocker. Status: **UNPROVEN**. Producer: earlier-cp.
- Sourcify HTTP 404 for facet 0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE.
- Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md); [evidence/earlier-cp/probe-alchemy-retry.source.json](evidence/earlier-cp/probe-alchemy-retry.source.json).

### earlier-masked-auth

- Class: product-blocker. Status: **UNPROVEN**. Producer: earlier-cp.
- Wrong-owner mature close reaches VaultDisabled before authorization can be judged.
- Evidence: [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md).

### other-historical-429

- Class: harness-gap. Status: **UNPROVEN**. Producer: other-sources.
- Login-shell Alchemy authenticated the pin, then eth_getCode and later eth_call returned HTTP 429. No Anvil child. Not a missing credential.
- Evidence: [evidence/other-sources/probe-alchemy.json](evidence/other-sources/probe-alchemy.json); [evidence/other-sources/probe-alchemy-r2.json](evidence/other-sources/probe-alchemy-r2.json); [evidence/other-sources/alchemy-retry-receipt.json](evidence/other-sources/alchemy-retry-receipt.json).

### public-historical-unavailable

- Class: harness-gap. Status: **UNPROVEN**. Producer: other-sources.
- Public provider eth_getCode code -32000, historical state b1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071 not available. Preserved before fresh fallback.
- Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public.json](evidence/other-sources/probe-public.json).

### se-lp-exits

- Class: product-blocker. Status: **FAIL**. Producer: other-sources.
- Disabled SE exits and owner-restricted LP exits from the new custodian.
- Evidence: [evidence/other-sources/report.md](evidence/other-sources/report.md); [evidence/other-sources/probe-public-r4.json](evidence/other-sources/probe-public-r4.json); [evidence/other-sources/probe-native.json](evidence/other-sources/probe-native.json).

### receipt-supply-gap

- Class: evidence-limit. Status: **UNPROVEN**. Producer: provenance.
- Exception C2 leaves earlier receipt supply gap UNKNOWN and not allocatable. Pinned and fresh displayed supplies differ and are not normalized.
- Evidence: [evidence/provenance/report.md](evidence/provenance/report.md); [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md).

### manifest-drift

- Class: evidence-limit. Status: **FAIL**. Producer: provenance.
- CUSTODY_AND_HARVEST.md and LOSS_AND_RECOVERY_LEDGER.md no longer match manifest.json. Frozen CSV/JSON still matched. Manifest was not edited.
- Evidence: [evidence/provenance/report.md](evidence/provenance/report.md); [evidence/provenance/reconciliation.json](evidence/provenance/reconciliation.json).

### provenance-rpc

- Class: harness-gap. Status: **UNPROVEN**. Producer: provenance.
- cast chain-id --rpc-url robinhood_mainnet_alchemy exited 1 because ALCHEMY_KEY was absent in that process. This unit did not rerun it.
- Evidence: [evidence/provenance/report.md](evidence/provenance/report.md).

### weighted-harness-429

- Class: harness-gap. Status: **preserved**. Producer: weighted.
- Initial async receipt failure and two Alchemy HTTP 429 fork loads remain archived. They are not product evidence. Direct alias fork completed.
- Evidence: [evidence/weighted/initial-run.results.json](evidence/weighted/initial-run.results.json); [evidence/weighted/rate-limited-run.results.json](evidence/weighted/rate-limited-run.results.json); [evidence/weighted/loopback-rate-run.results.json](evidence/weighted/loopback-rate-run.results.json); [evidence/weighted/cleanup-audit.json](evidence/weighted/cleanup-audit.json).

### earlier-harness

- Class: harness-gap. Status: **preserved**. Producer: earlier-cp.
- Original probe.json and probe-alchemy429.json HTTP 429 remain. probe-fresh1.json preserves the classifier that summed every nonpayer DTF inflow. Corrected classifier matched 16 rows.
- Evidence: [evidence/earlier-cp/probe.json](evidence/earlier-cp/probe.json); [evidence/earlier-cp/probe-alchemy429.json](evidence/earlier-cp/probe-alchemy429.json); [evidence/earlier-cp/probe-public429.json](evidence/earlier-cp/probe-public429.json); [evidence/earlier-cp/probe-fresh1.json](evidence/earlier-cp/probe-fresh1.json); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md).

### other-harness

- Class: harness-gap. Status: **preserved**. Producer: other-sources.
- Non-login missing ALCHEMY_KEY, public receipt race, rollback tracing gaps, and parser hex mishandling remain in probe-public through probe-public-r3. They are not product proof.
- Evidence: [evidence/other-sources/probe-public.json](evidence/other-sources/probe-public.json); [evidence/other-sources/probe-public-r2.json](evidence/other-sources/probe-public-r2.json); [evidence/other-sources/probe-public-r3.json](evidence/other-sources/probe-public-r3.json); [evidence/other-sources/probe.json](evidence/other-sources/probe.json).

### attribution-harness

- Class: harness-gap. Status: **preserved**. Producer: attribution.
- Initial arithmetic-expectation failure and witness-r2 exit 2 cleanup classification remain. witness-r2 had already executed the counterexample. Neither is hidden or treated as E2 closure.
- Evidence: [evidence/attribution/witness.results.json](evidence/attribution/witness.results.json); [evidence/attribution/witness-r2.results.json](evidence/attribution/witness-r2.results.json); [attribution-spec.md](attribution-spec.md).

### funded-c0-absent

- Class: operational-input. Status: **UNKNOWN**. Producer: provenance.
- No funded snapshot quote book. C0 was not computed. Absence is not a new pricing policy and is not route support.
- Evidence: [evidence/provenance/report.md](evidence/provenance/report.md).

### lsp-timeouts

- Class: tooling. Status: **UNVERIFIED**. Producer: weighted, other-sources, attribution.
- Producer LSP diagnostics timed out or were not claimed clean, except earlier-cp reported none. This unit does not claim a new LSP result.
- Evidence: [evidence/weighted/report.md](evidence/weighted/report.md); [evidence/other-sources/report.md](evidence/other-sources/report.md); [attribution-spec.md](attribution-spec.md); [evidence/earlier-cp/report.md](evidence/earlier-cp/report.md).

## What remains unclosed

E1 atomic handoff is UNPROVEN for every row. E2 is FAIL for ordinary fungible attribution and UNPROVEN for categories whose ancestry was not given a compliant verifier. Disabled vaults and owner-only LP exits are concrete harvest failures, not a request for a new owner policy. Missing funded C0 is an operational input, not a computed award. No category was dropped.

Machine companion: [source-manifest.json](source-manifest.json).
