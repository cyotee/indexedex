# Grok requirements check — draft remediation PRD

- Reviewer: Grok (xai/grok-4.7)
- Date: 2026-09-25
- Draft read: `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md`
- Authority used: that draft, the APEX remediation PRD, and the 2026-09-25 owner follow-up already written into the draft.
- No owner question is open. An implementer can execute the draft without a new product ruling if the alternative branches below are read as closed by existing law, not as permission to invent the other branch.

No question is asked of the human. None of the remaining choices changes the correction or the acceptance test once the existing rulings are applied.

## Owner follow-up already closed

| Item | Classification | Citation |
| --- | --- | --- |
| Migration, registry disablement, historical fork replay, live-instance inventory, APEX-2026-001-M2 | Already answered | Draft “Owner follow-up” and disposition row for 001-M2. Do not reopen. |
| Fresh deployments of corrected source are the release unit | Already answered | Same follow-up. Source edits in RC-01 through RC-08 are the work. |
| Preserved Uniswap V3/V4 trees are not a new-deploy source | Already answered | Draft “Owner follow-up” and “Accepted product law”. Do not edit those trees to satisfy RC-04 or RC-07. |

## Confirmed requirements

### RC-01 — Balancer adapter lock and allowance

- Classification: already answered, plus implementer detail
- Citation: draft RC-01 acceptance; APEX D15, D16, D30, D34; `BalancerV3SinglePoolStandardExchange.sol:69-103`, `131-192`, `262-275`
- Correction: add one reentrancy guard from funding through reserve sync. Approve only the amount that route is authorized to spend (`quotedUsed` on a false-flag pull, the D15 credit budget on a true-flag exact-out). Clear that allowance before a successful return.
- “Including on revert” does not authorize `try`/`catch`. D30 and D34 already require the revert to propagate and the transaction to roll back approvals with everything else. Do not add a cleanup catch.
- The downstream router lock is not a substitute. D32 public-pretransfer rejects stay rejects. D12 resting credit is not given a sender.
- Allowance width, Permit2 `uint160` capping, and which existing reentrancy error to reuse are implementer details. They do not change the acceptance test: reentry cannot complete a second money entry; success leaves router and Permit2 allowances at zero and `_tokenReserve` equal to the post-settlement balance.

### RC-02 — ERC-4626 local-first payout

- Classification: already answered
- Citation: draft RC-02; APEX R14.15, which says underlying-output routes spend local backing and then withdraw the required shortfall; Stata already calls `withdraw` at `AaveV3StataStandardExchangeCommon.sol:94`; current defect at `ERC4626StandardExchangeCommon.sol:87-91`
- Do not treat the draft’s “book the remainder **or** exact-asset withdrawal” as an open economics choice. R14.15 and the Stata peer select exact-asset withdrawal of the shortfall. The recipient receives exactly the accounted due amount. A redemption surplus is not paid to the recipient and is not a new fee-to-`feeTo` path.
- Exact-input return value equals that recipient delta. Orbital capped unwrap against this SE leaves no operation-created face above the opening balance. Pre-existing D12 face stays out of that assertion.
- Which existing orbital suite file hosts that one assertion is implementer detail.

### RC-03 — Stata aToken in backing

- Classification: already answered
- Citation: APEX R14 / D45, the paragraph that begins “Stata also counts any already-booked local aToken value at its underlying-equivalent accounting value”; draft RC-03 first acceptance bullet; `_stataBacking` at `AaveV3StataStandardExchangeCommon.sol:52-58`; adapter addition at `ReceiptBackedERC4626Target.sol:183-198`
- The draft sentence “If product law instead excludes aToken” is not an open branch. D45 already includes already-booked aToken. Both the adapter and the SE, SY, and transition-quote paths must use that same calculation. Do not drop aToken from the adapter to make the smaller `_stataBacking` look consistent.
- Do not retain new aToken input instead of `depositATokens`. Do not attribute an unsolicited aToken transfer to a depositor. Do not change reward forwarding at `AaveV3StataStandardExchangeCommon.sol:182-198`.
- Calling the shared backing function, rather than inventing a second aToken rate, is implementer detail. The acceptance test is same entitlement on one production Stata proxy when booked aToken is nonzero, and no aToken term in generic ERC-4626 mode.

### RC-04 — Stale comments and FullSpread README

- Classification: already answered
- Citation: draft RC-04; APEX D6, D15, D17, D28, R13; cited lines `ERC4626StandardExchangeOutTarget.sol:17-20`, `ERC4626StandardExchangeCommon.sol:201-211` and `277-281`, `ERC4626StandardExchangeInTarget.sol:126`, `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32-38`
- Edit text only. The replacement text is the executable rule already locked: no exact-input refund, pull-delta equality, exact self-share burn, exact-output refund capped at `credit - used`, dust retained as book, false-flag exact-out pulls quoted used.
- Do not change FullSpread pull code. Do not edit preserved historical Uniswap source. No new money test is required.

### RC-05 — Unused single-CP `exchangeOut`

- Classification: implementer detail
- Citation: draft RC-05; `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754`; installed path `SeTarget.sol:836-864`
- Delete the unused function, or make it call the installed guarded helper. Either meets the acceptance test. Installed selectors do not change if the function is not on the cut. Do not recut the facet. This does not change D15.

### RC-06 — Orbital unwrap return value

- Classification: implementer detail
- Citation: draft RC-06; D25; `OrbitalBufferHookCommon.sol:550-565`
- Return the shares the SE pulled, or remove the unused return and update callers. Either meets the acceptance test. Keep approve-to-cap and approve-back-to-zero. A short delivery still reverts. Do not pay the unused approval to the caller. MiniMax’s functional dissent does not reopen the requirement.

### RC-07 — `BasicVaultCommon` deficit panic

- Classification: already answered
- Citation: APEX R9: availability is zero when booked is at least balance, and a deficit must not fall through to the whole balance; family insolvency errors stay outside the helper. Draft RC-07. Code: `BasicVaultCommon.sol:33-36`, `77-103`, `120-135`
- On D16 paths, `balance < book` authorizes zero new credit. A request above that zero reverts the family’s existing insufficient-credit error, not an empty panic, and does not pay booked inventory. Do not invent a new error.
- Adding the contract-caller check on the base pull, or proving each D16 public entry cannot reach the unguarded base, both satisfy D9. The four production heirs of `BasicVaultCommon` found in this tree are Uniswap V2, Camelot, Aerodrome, and Stata, and those overrides already call `requirePretransferCaller`. Confirm that list before editing the base. Preserved Uniswap V3/V4 do not inherit this helper; do not change them.
- Listing those consumers is implementer work, not a new ruling.

### RC-08 — Uniswap V2 bare `revert()`

- Classification: implementer detail
- Citation: draft RC-08; `UniswapV2StandardExchangeOutTarget.sol:578-580`
- Keep the same comparison. Revert a named error that carries both compared values. A new custom error is not a function selector. Do not weaken the check or change the refund. The error’s name is not product law.

## Explicitly not open

| Item | Classification | Citation |
| --- | --- | --- |
| D12 non-atomic contract pretransfer, including EIP-7702 and contract wallets | Already answered. Do not “fix” it. | Draft accepted-law list; D12, D28, D44 |
| D32 public-pretransfer rejects | Already answered | Draft accepted-law list |
| Dust to `feeTo` | Already answered. Do not revive it. | D6; RC-04 non-goal |
| Stata incentive rewards to `feeTo` | Already answered. Out of this correction. | Draft RC-03 non-goal; `AaveV3StataStandardExchangeCommon.sol:182-198` |
| FullSpread callback-donation refund enlargement (F-M3-01) | Already answered. Not a requirement. | Draft “Dissent and items that are not requirements” |
| Hook helper missing a redundant `used > credit` revert (Grok-5) | Already answered. Not a requirement unless a caller reaches the helper without both bounds. | Same dissent section |
| Unused `_refundPairDust` `to` parameter | Already answered. Optional, not required. | Same dissent section |
| Withdrawn `beforeSwap` guard claim | Already answered. Refuted, not an accepted residual. | Disposition table |
| Weighted-dust High claim | Already answered. Refuted as High. D12 / D36 remainder is not a new defect. | Disposition table |
| 001-M preserved expression | Already answered. Leave the preserved tree. Do not select it for a new deployment. | Owner follow-up; disposition row 001-M |

## Questions for the human

None. The draft’s “or” branches do not need a new ruling:

- RC-03’s exclude-aToken alternative is closed by D45.
- RC-01’s “cleared on revert” is closed by D30 / D34 transaction rollback.
- RC-02’s redeem-and-book alternative is closed by R14.15’s withdraw-the-shortfall rule and the Stata peer.
- RC-05, RC-06, and RC-08 mechanism or naming choices do not change the acceptance assertions.
