# Kimi initial independent response

## Identity

- Member: `kimi`
- Profile: `review`
- Phase: initial independent response
- Requested role: `council-member`
- Requested model and reasoning: `kimi-coding/k3.1-pro:high`, global route
- Other runtime identity: not exposed
- Peers read before submission: no

## Disposition

**requested-changes**

The blockers file is consistent across almost all of its locked answers and provides enough coverage to drive the comprehensive PRD rewrite. Two sentences are not yet clear enough to copy without risking divergent implementations: the Protocol Aware Repo storage sentence in B-07 and the overstated-maximum pretransfer refund rule in B-13.

## Review findings

### 1. B-07 gives the Protocol Aware Repo two incompatible storage instructions

**Location:** B-07, the paragraph beginning "When the package initializes a vault instance," especially the adjacent sentences requiring initialization to write all seven immutable addresses into the Protocol Aware Repo and then saying, "The repo is not given a second per-vault copy of the addresses."

**Why two readers could diverge:** The first sentence makes the repo the per-instance storage destination for the package's seven immutable addresses. The second can be read as prohibiting a per-vault copy in that same repo, or as prohibiting only a duplicate copy somewhere else. One implementor could initialize all seven values once in each vault's Protocol Aware Repo; another could conclude that the addresses must remain only in package immutables or that some second repo write is forbidden. Those readings produce different initialization and storage requirements.

**Fix direction:** Clarify which storage location is canonical and what "second" refers to. If the intent is one per-vault copy in the Protocol Aware Repo and no duplicate in the full-spread family repo or another instance repo, say that distinction explicitly in the PRD rewrite. If no per-vault copy is intended, reconcile that with the initialization write instead of preserving both instructions.

### 2. B-13 does not define execution and refund ordering when the declared maximum exceeds the held balance

**Location:** B-13, the paragraph beginning "The vault does not ask where the tokens came from," particularly: "If that maximum is larger than the unbooked balance, refund the unbooked balance. Do not refund maximum minus used in that case, and do not pull the shortfall." The admitted `PRETRANSFER_DIRECTIVE.md` uses the same rule, so it does not resolve the ordering.

**Why two readers could diverge:** The rule does not say whether an overstated maximum makes the call a full-refund/no-use case, or whether execution may use part of the held balance before the refund. It also does not say whether "the unbooked balance" is measured before or after the amount used. For example, with 100 tokens held, a maximum of 200, and 60 otherwise usable, one reader could cap execution at the held balance and refund what remains; another could read the sentence as requiring all 100 to be refunded and no shortfall to be pulled. The latter cannot also spend 60 of the same 100. The formula for the other branch explicitly subtracts the amount used, which makes the missing ordering in this branch material.

**Fix direction:** State the overstated-maximum control flow before copying it into the PRD: whether the operation uses nothing and refunds the entire pre-execution unbooked balance, or uses a capped amount and refunds the post-execution unbooked balance. Define the balance measurement point and the amount usable in this branch so the refund and no-pull rules can be implemented together.

## Coverage

The following locked items and notes were checked for internal contradictions, missing requirements, and implementation-choice ambiguity. Except for the two findings above, their requirements are clear enough for the comprehensive PRD pass; differences from the older PRD are intentional replacements, not defects.

| Item | Coverage and result |
| --- | --- |
| B-01 | Netting the usage fee out of newly minted shares, genesis treatment, zero mints, the 30% vault-side clamp, WAD precision, pass-through exclusion, and net-share previews are mutually consistent. No additional unbacked mint remains authorized. |
| B-02 | Sleeve removal, owner/operator-only compounding, unbounded entry and redemption limits, withdrawn-net redemption quantity, accepted sandwich exposure, and borrowed-unlock batch composition are consistent. The audit disposition correctly does not claim the accepted exposure is absent. |
| B-03 | The no-fee/no-donation/no-remainder no-op is consistent with processing a booked remainder and with B-11's event rule. |
| B-04 | The zero-deployed-liquidity denominator is closed by the sleeve-free state argument and the retained floor; no alternate denominator is introduced. |
| B-05 | Donation access control, one-token and combined-two-token behavior, zero-supply revert, share-donation burn, and remainder booking are coherent with the common booking rule. |
| B-06 | Zero-return unsupported previews, reverting unsupported execution, non-reverting busy views, and deployed-only live reserves form one consistent replacement for the older view rules. |
| B-07 | The seven package bindings, Crane facet inputs, instance position identity, and `StateLibrary` position read are specified; only the Protocol Aware storage sentence is defective, as finding 1 describes. |
| B-08 | The vault remains rate-free while hooks use externally deployed vault/target rate-provider instances. Required token0/token1 and multiple-target scenarios are named, and the useful provider count is expressly not a cap. The 64-byte preview-consumer enumeration is correctly assigned to the single PRD pass. |
| B-09 | Borrowed one-token exit uses the open manager directly, withdraws and swaps only the caller's fraction, settles the vault's own deltas, and has no sleeve fallback or new token-unit error. |
| B-10 | Genesis, later mint, and burn formulas consistently use raw V4 liquidity and whole supply including the floor. Token decimals and share metadata do not rescale those formulas. |
| B-11 | The argument-free `Compounded()` event, PoolManager amount evidence, no-op behavior, and best-effort remainder booking do not conflict. |
| Donation and compound booking | Combined-balance processing, proportional use of the scarcer token, actual-held-balance booking, failure propagation, withdrawal-fee booking, deployed-only reserves, and later reprocessing are specified without leaving a sleeve mechanism in place. |
| B-12 | Both paired event names and their sole indexed `caller` argument are fully specified; amount evidence remains in ERC-20 and PoolManager events. |
| B-13 | Attribution to the declared unbooked balance, exclusion of booked remainders and parked shares, contract-only pretransfer, and non-atomic caller risk are clear. Only the overstated-maximum branch needs finding 2's clarification. |
| N-01 | The address-zero floor remains locked through `_mint`; the rejected receiver helper is not part of that path. |
| N-02 | The fee base excludes both the floor and fee-on-fee compounding and agrees with B-01. |
| N-03 | Sleeve-adjustment swapping is removed without removing the separately locked entry, redemption, donation, compound, or pass-through swaps. |
| N-04 | The owner deliberately leaves quoter versus analytic implementation to engineering and forbids turning that choice into a product cap, spacing rule, partial fill, or undocumented failure mode. This is an explicit implementation choice, not an unresolved product requirement. |
| N-05 | WETH-only caller flow, native wrapping at the pool boundary, and removal of `PkgInit.wrappedNative` and its getter are consistent. |
| N-06 | Assigning already specified operations to `SwapProjection` and `ExecutionPreparation` is expressly delegated code organization; no economic choice is left open. |
| N-07 | Liquidity-only issuance stays closed, consistently with B-04 and B-10. |
| Matrix and audit sections | The integration-matrix addition, exact-output rejection adaptations, stale-evidence replacement, and APEX-2026-023/024/039/048 dispositions agree with their governing locks. The three plan-scope items remain integration-matrix coverage, integration tests, and vulnerability-absence tests without contradicting retained mechanisms. |
| Already-locked summary | The summary agrees with the detailed locks on the floor, rate absence, WETH, refunds, bundle balancing, redemption, borrowed unlocks, sleeve removal, share units, maintenance, reserves, views, events, pretransfers, fees, aware facets, and rate providers. No additional divergence was found there. |

## Conclusion

The file is ready for the comprehensive PRD rewrite only after the two wording issues above are resolved or explicitly interpreted by the owner. The rest of the locked answers and notes supply a coherent replacement basis, including the required matrix, audit, and 64-byte preview-consumer follow-up work.

## Limits

This is an independent review of the admitted blockers file and optional context only. It does not authorize implementation, a PRD edit, or a blocker edit, and it does not certify the proposed vault's security.
