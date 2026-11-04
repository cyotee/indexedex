# Member feedback

## Identity

- Run ID: v4-own-vault-spec-20261027-01a177b3
- Member label: minimax
- Phase: advisory review
- Owned path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/minimax/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: council-member; model and reasoning not exposed; task ID st_01a17cf8 (given by this assignment); session ID not exposed
- Fresh or continued: continued
- Initial response path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/minimax/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-v4-own-vault-spec-20261027-01a177b3-r1
- Path: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/draft.md
- Fingerprint supplied by the coordinator: 2e2c595866b5475ba8802496f7606df9dbc5fc7cfef2b46a65175581f6750ea8
- Fingerprint independently computed: not computed
- Draft bytes opened: opened in full. The file's own Draft identity lines carry `- Draft ID: draft-v4-own-vault-spec-20261027-01a177b3-r1` and `- Path: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/draft.md`, which match the assigned identity, so this is the assigned draft.

## Disposition

- Disposition: support-with-reservations
- This file replaces a missing initial response: no
- **Draft fairly records my position: yes, with one divergence I flag as A1.** The draft adopts the receipt shape I proposed (Decision 1, one homogeneous liquidity-unit receipt for one `(pool, range, salt)`), the one-share-one-range binding (Decision 2), the token-unit per-share fee accumulator held outside `U` (Decision 3), the atomic single-target exit with a slice-bounded sale (Decision 5), the diamond-as-position-owner boundary with a dual guard on the callback (Decision 6), and the `getRate` withdrawal-and-sale preview with a revert set (Decision 7). The Preserved disagreements table names my position correctly on all four rows I contributed to, including that I included a single-token zap route as a separate route with an explicit non-claim. The draft's Decision 4 omits that route; I had recorded that the rest of the specification is unchanged if the conservative choice is taken, so the omission is a settled disagreement rather than a misrecording, and the draft preserves my non-claim as a condition on any later addition. The one place where the draft's rules are not mine is the `unclaimed_i` payment rule in Decision 3, which the draft does not list as a divergence: see A1.
- **A later agent can implement this without the excluded third-party source: yes.** The specification is complete on its own terms. It re-derives the share equation from IndexedEx's own converter and the coordinator's re-read of `BetterMath._convertToShares`, `_convertToAssets` and the `UniswapV2StandardExchangeInTarget` exact-in LP branch; it fixes the fee accumulator algebra in full; it gives a normative deposit sequence and a normative exit sequence; it names the fee collection requirement, the diamond boundary, the `getRate` preview and the invariants. The only mechanical gap is the pool-side collection operation, which A2 asks the coordinator to name. Nothing in the draft requires, or invites, a look at the excluded implementation: the draft's own text says gaps must not be filled from it, and the design deliberately makes the receipt an internal ledger rather than a second transferable token, which is materially different from an external pair-token design.
- **`getRate` was redefined as NAV: no.** The draft states it three times and consistently: "It is not `liquidateAll(book) / S`. It is not a NAV mark. This council does not redefine it" (Decision 7), "It is not an issuance input" (Decision 7), and "It does not redefine `getRate` as NAV" (opening). The preview is built from the same withdrawal-and-sale path as the exit, the same rounding direction as execution, and it is excluded from the issuance path by Decision 1 and Decision 8 item 2. The draft also rejects the synthetic constant at zero supply, which matches my position.
- **Any requirement reconstructs excluded source: no.** Every requirement traces to an IndexedEx file the draft cites, to the public Uniswap v4 protocol semantics, or to generic accounting that the draft derives on its face. The receipt, the fee accumulator, the slice-bounded sale, the diamond boundary and the `getRate` preview are all derivable from the admitted sources and the prior reports. I found no requirement whose shape, constant, or control flow could only be satisfied by reading the excluded implementation, and the draft explicitly withholds the right to fill gaps from it.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| A1 | Decision 3, the exit sentence "An exit, after the pre-burn settle, pays `floor(unclaimed_i * sharesBurned / balanceBefore)` of each currency and reduces `unclaimed_i` by that amount"; Decision 8 item 11 | The exit pays a pro-rata slice of an account-level `unclaimed_i` pool rather than the burned shares' own entitlement. After a partial redemption the residual `unclaimed_i` is not reachable through the `owed_i` settle path, because the balance change resets `debt_i` to `floor(newBalance * feePerShare_i / Q)`, which makes the next `owed_i` zero. "A transfer settles both sides" does not say where the sellor's `unclaimed_i` goes, so a residual can be orphaned against a balance that has moved to the buyer. As written, the rules do not determine what a partial redeemer receives, which is exactly the kind of gap this specification has to close for an implementer. | State one rule that binds `unclaimed_i` to the retained balance and closes the transfer case. Minimal form: either pay the burned shares' own entitlement at redemption and keep the remainder bound to the retained balance, or require the account's `unclaimed_i` to be paid in full or moved to `dust_i` at every transfer and every partial redemption, so no residual is ever stranded. Add the matching invariant to Decision 8. |
| A2 | Decision 3, evidence class: "Pool fee-growth field names were not re-read by the coordinator. The implementer must collect what the pool owes this position, in token units"; and the "Fee-growth mechanism" row of Preserved disagreements | The draft freezes the fee collection outcome but not the operation. Leaving the operation unnamed means an implementer could satisfy "collect what the pool owes" with a price-based read, which the draft forbids elsewhere, and would discover the problem only after the accounting design is fixed. The draft already identifies this as unresolved. | Add one sentence stating that collection is a liquidity modification on the same `(pool, range, salt)` position with a zero liquidity delta, that it returns the accrued fee amounts in token units in the caller's delta, and that the delta must be settled before the callback returns. Field-level pool math may remain unfrozen; the operation should not. |
| A3 | Decision 6, evidence class ("Diamond proxy as callback target is an inference from Crane delegatecall"); Evidence gaps, "No PoolManager trace was executed" | The two load-bearing sentences of Decision 6, that the pool's position owner is the address the pool manager calls back and that the callback must run on the diamond, are classed as an inference. The public Uniswap `v4-core` source settles them directly: `PoolManager.unlock` calls `IUnlockCallback(msg.sender).unlockCallback(data)`, `PoolManager.modifyLiquidity` passes `owner: msg.sender` into the pool's position store, and the position key is `keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))`. These are public, non-excluded sources. Leaving them as an inference forces the later implementer either to re-derive a settled rule or to treat it as unverified. | Cite the public `v4-core` lines in Decision 6's evidence class and change the class from inference to source observation of a public source. Keep the statement that no PoolManager trace was executed and that no Crane delegatecall was traced. |
| A4 | Decision 8, the twelve-item list | The list omits two properties that the other decisions already imply and that a later agent would otherwise not test: that no non-zero pool delta remains at the end of any vault callback, and the incumbent non-dilution property of a correctly funded deposit, which is the acceptance identity the swap-capture report treats as the core of a price-free join. | Add the delta-settlement invariant to the list, and add the incumbent non-dilution invariant stated as the incumbent's liquidity claim before and after a correctly funded deposit, with the stated rounding dust bound. |

## What was not adopted from others

- Peer responses read: not read. The only peer-derived material I saw is the draft's own Preserved disagreements table and Coverage adopted from responses table, which I reviewed as part of the assigned draft.
- Peer feedback read: not read
- Unread members treated as support: no

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- One coordinator claim was independently checked against an admitted source and confirmed: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol`, `initAccount` lines 552-581, sets the share decimals literal `18` and the decimal offset literal `9`. No hash command was run for the draft fingerprint, and none was computed.
