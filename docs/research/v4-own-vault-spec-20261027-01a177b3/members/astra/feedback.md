# Member feedback

## Identity

- Run ID: v4-own-vault-spec-20261027-01a177b3
- Member label: astra
- Phase: advisory review
- Owned path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/astra/feedback.md
- Requested role: council-member
- Requested model and reasoning: chatgpt-subscription/gpt-6-astra:high
- Actual role, model, and reasoning: not exposed
- Task ID: st_01a17cf6, supplied in this advisory assignment
- Session ID: not exposed
- Fresh or continued: continued
- Initial response path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/astra/response.md
- Initial response preserved: yes

## Draft under review

- Draft ID: draft-v4-own-vault-spec-20261027-01a177b3-r1
- Path: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/draft.md
- Fingerprint supplied by the coordinator: frozen-file sha256 `2e2c595866b5475ba8802496f7606df9dbc5fc7cfef2b46a65175581f6750ea8`
- Fingerprint independently computed: not computed
- Draft bytes opened: yes, the assigned path was opened and the returned draft text was read. Its Draft ID and path match this assignment. Its internal pre-insertion fingerprint is explicitly a different stage; I have not treated that value as the supplied frozen-file fingerprint.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no
- Dissent fairly recorded: partially. The basket choice and exclusion of a vault entry swap are recorded correctly. The draft mischaracterizes the basket as incompatible with a single-denominator liquidity-unit mint and omits why attached, fungible fees mattered to my one-share preview. See C1 and C2.
- Implementable without excluded source: the intended design can be developed without excluded source, but this draft is not yet a self-consistent implementable specification. Its account-specific fee exit has no defined account-independent `getRate`; its fee dust equation can overlap holder liabilities; and terminal and transfer behavior require decisions. These gaps can be resolved using the stated accounting and permitted IndexedEx/protocol context, not excluded materials.
- `getRate` redefined as NAV: no. The draft expressly rejects whole-book NAV and uses withdrawal and sale. The problem is different: the fee part of that preview is undefined for an anonymous whole share under the adopted account-specific fee ledger.
- Requirements reconstruct excluded source: no requirement I read appears to do so. The proposed equations and boundaries can be assessed on their own. I did not compare them with excluded material and cannot independently certify the provenance of text supplied by other participants.

The exact V2 conversion, one-range restriction, no vault swap on entry, slice-bounded exit, and atomic failed-sale rule are useful requirements. My requested changes concern the consistency of the adopted design, not a demand that the coordinator select my basket.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| C1 | Decision 1 rejected basket; Preserved disagreements | My basket uses the same single-denominator V2 liquidity-unit share conversion. It separately requires native-token fee matching. The draft's reason for treating it as a different mint obscures the actual choice. | Say the rejected feature is componentwise fee funding and attached fungible fee entitlement, not a departure from the requested mint equation. Preserve my concern that an account-history-dependent fee payout conflicts with an anonymous one-share preview. |
| C2 | Decisions 2, 3, 5, and 7 | Fee payout depends on the holder's `unclaimed` and balance history. `getRate()` receives no holder and cannot determine the fee claim of an arbitrary whole share. Transfer leaves old fees with the sender, so the fee claim is not carried by the fungible receipt described in Decision 2. | Choose one consistent contract: attached fungible fees with funded admission, or explicitly separate historical fee claims from the share's redeemable property and provide separate fee-claim operations. If using detached claims, the actual shares-only redemption and `getRate` must match; do not include an invented average historic fee claim in the rate. |
| C3 | Decision 3 accumulator and dust equations | The index retains fractional entitlement across collections while the proposed dust ledger declares those same fractions non-holder property after each collection. Later cumulative rounding can make both ledgers claim the same tokens. | Specify one conservation-safe fixed-point liability/remainder scheme. Do not classify index-backed fractional carry as permanently unowned dust. Define the precision, bounds, remainder ownership, and maximum payable liability, then require the counterexample below to reconcile. |
| C4 | Decision 3 transfers; normative exit sequence | Full transfer can leave positive `unclaimed` on an account with zero shares and no specified claim path. Also, unsynced fees travel with a transferred balance while previously synced fees remain with the sender, making historical ownership depend on collection timing. The exit sequence does not explicitly reset the holder's debt after burning. | Define whether fee rights travel or detach. For detached rights, sync before transfers if pre-transfer earnings remain with the sender, provide a claim route requiring no share balance, and update debt after every burn. For attached rights, transfer the appropriate fee claim consistently. Specify collection custody separately from removed principal. |
| C5 | Stored `d = 9`; Decisions 5 and 8; bootstrap and terminal behavior | Symmetric offsets alone do not guarantee complete final withdrawal once fractional share burns are allowed. The stated equations permit zero supply with residual position liquidity, or a remaining balance whose redemption rounds to zero. | Add an explicit, consistent lifecycle policy for minimum redeemable units, fractional burns, final withdrawal, residual liquidity/fees, and subsequent bootstrap. Do not silently sweep residual capital or change the final-exit equation. A stricter share-unit granularity or a different coherent policy must be chosen and tested. |
| C6 | Decision 7; pool binding in Decisions 2 and 6 | The preview does not explicitly bind the sale to the post-removal pool state and tick changes, establish the supported hook/fee domain, or define canonical sale limits. The revert set omits zero normalized rate and explicit unavailable one-whole-share sizing. | Require sequential simulation of exact removal then full-input sale, using the same limits and rounding as execution. Fix the supported pool domain or specify how hook/dynamic-fee behavior is simulated. Revert on incomplete fills, inconsistent state, unavailable whole-share removal, malformed dependency results, and zero normalized output. |
| C7 | Decision 8, invariant 12 | "A one-share round trip is not profitable" has no domain or numeraire and is stronger than both the supplied conclusions and the draft's execution-exposure disclaimer. Fees and market movement can also make positive returns legitimate. | Replace it with a fixed-state, no-accrual, no-swap liquidity-unit conversion inequality. Keep any target-denominated profitability claim explicitly unproved unless a separate precise domain and proof are supplied. |
| C8 | Normative deposit/exit sequences; callback authorization | The normative flows omit an entry minimum-share bound and deposit deadline, explicit caller-attributed input budgets, and sufficient callback context to bind the permitted operation. Sync-before-pull also leaves cohort attribution unspecified if external calls alter pool fees before addition/mint. | Bind caller, receiver, pool/range, operation, amount budgets, and single-use callback authorization. Require minimum shares and deadlines, and reject unexpected fee/pool changes between the acceptance checkpoint and mint. Use verified pre/post liquidity deltas rather than merely assigning the observed liquidity to `U`. |

### C2: The rate cannot select a unique historical fee claim

**Static inference from the draft's equations.** Let two accounts each hold exactly one whole share. The first has `unclaimed_T = 100`; the second has `unclaimed_T = 0`, having minted after the old fees were checkpointed. Suppose there are no pending fees and no opposing fee claims.

Their principal removals are identical. Decision 3 nevertheless makes the first whole-share redemption receive 100 more target units than the second. An address-independent `getRate()` cannot equal both actual exits.

Using `feePerShare * 10^18 / Q` is not a solution: that ignores each account's debt and can assign old fees to a newly minted share. Using aggregate unclaimed fees divided by supply is also not the specified actual redemption. It would invent a synthetic average fee entitlement.

A principal-only, ex-distribution share rate can be coherent if the real shares-only redemption likewise excludes detached historical fees and a separate operation pays those claims. That is an explicit product/interface decision, not a silent reinterpretation of the current account-dependent redemption. An optional combined wallet exit can then return both, but it is not the universal one-share rate.

My initial basket instead keeps fee entitlement attached to every fungible receipt and funds that entitlement at admission. This was a reason for the choice, not only an alternative old-fee protection mechanism.

### C3: The proposed dust separation is arithmetically inconsistent

**Static arithmetic, not an executed test.** Choose a permitted index scale `Q = 10^18` and one account holding the full supply `S = 3 * 10^9`. Two fee collections each receive one native token unit, with no supply changes.

For each collection:

```text
indexIncrement = floor(10^18 / (3 * 10^9)) = 333333333
floor(indexIncrement * S / Q) = 0
dustIncrement = 1
```

After both collections:

```text
feePerShare = 666666666
dust = 2
holderClaim = floor((3 * 10^9) * 666666666 / 10^18) = 1
collected = 2
```

The holder now has a one-unit claim while the draft labels both collected units as non-holder dust. Holding the dust forever rather than sweeping it does not correct the overlapping ownership categories.

The issue is cumulative fixed-point carry, not a demand for a larger `Q`. Moving the same remainder into a different number of bits does not make this per-collection classification valid.

### C4: Transfer and fee custody need complete rules

**Static inference.** With no independent claim function, an account that transfers its entire share balance retains `unclaimed` but can never redeem shares to receive it. Retained fee rights need their own callable lifecycle, including a target-only failed-sale rule or explicit in-kind claim semantics.

The draft also syncs on deposit, exit, and `sync`, but not on transfer. If old earnings belong to the sender, a transfer before collection and a transfer after collection must not assign those same earnings to different people. If old earnings instead travel with the share, previously accumulated `unclaimed` must travel consistently too. The current text implements neither uniform rule.

Finally, "tokens the pool pays because liquidity was removed fund that payment" should distinguish principal from already collected fees. A fee collected in an earlier `sync` is held in fee escrow and paid from that escrow; it cannot require a second pool payment during removal. Principal and newly collected fees need separate deltas, with no double attribution.

### C5: A terminal-state counterexample under the selected offset

**Static arithmetic, not a runtime trace.** Write `v = 10^9`. Starting from empty, deposit three raw liquidity units:

```text
U = 3
S = 3v
```

Redeem `s = v + 1` shares using the specified inverse:

```text
uOut = floor((v + 1) * 4 / (4v)) = 1
U_after = 2
S_after = 2v - 1
```

Now redeem all remaining shares:

```text
uOut = floor((2v - 1) * 3 / (3v - 1)) = 1
U_final = 1
S_final = 0
```

These are positive-liquidity redemptions; the zero-output guard does not prevent them. The draft must decide who owns that remaining unit, whether new deposits may occur, and how fees on it are classified.

This does not disprove the adopted V2 converter. It shows that importing its equation and offset is insufficient to define this new vault's complete lifecycle. My initial `d = 0`, `S = U` proposal avoided this particular fractional-share mismatch; the coordinator may choose another explicit policy.

### C6-C8: Scope the remaining verification obligations

The draft need not derive or copy a third-party implementation. It does need to settle the input contract of its own quote and money paths.

The quote must use the active-liquidity and initialized-tick state after removing the quoted slice. A sale sized from the slice but priced against the unmodified pool is still not its actual withdrawal-and-sale preview. Full input consumption and a nonzero normalized rate must be checked even when the raw target quote is positive.

A pool key binds a hook address; it does not by itself define an exact simulator for arbitrary hook behavior or dynamic fees. Restricting the initial domain, as my response proposed, is one available decision. A broader domain requires corresponding semantic requirements, not an instruction to find the missing behavior in excluded source.

The limited conversion invariant I support is:

```text
With no intervening state change, fee accrual, or swaps:
redeemLiquidity(mintShares(u)) <= u
```

That is an integer liquidity-unit property. It is not a no-profitable-target-round-trip theorem.

## What was not adopted from others

- Peer responses read: not read. The assigned draft's descriptions of their positions were read as coordinator-supplied summaries, not independently verified peer evidence.
- Peer feedback read: not read.
- Unread members treated as support: no.
- No proposal was adopted because the draft attributed it to a majority. Concerns above follow from the draft's own equations and the initial-response context retained in this conversation.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- Inherited parent permissions are not evidence of confinement.
- This review opened only the specified draft and feedback template. It did not open peer files, the resolution, the final, or `RUN.md`.
- No hash command, project test, implementation, dependency installation, deployment, Git operation, or sub-agent launch was performed.
- Counterexamples are static arithmetic and reasoning about the proposed equations, not deployed-contract findings.
- The original response was not modified. Only this assigned feedback artifact was written.
