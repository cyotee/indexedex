# Blocker-report review

## Identity

- Run ID: se-fullspread-blockers-review-20261102
- Profile: review
- Council kind: full
- Question: Is `IMPLEMENTATION_PLAN_BLOCKERS.md` consistent across its locked answers, complete enough to rewrite the full-spread PRD, and clear enough that two implementors would not diverge?
- Target: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`
- Context, not targets: the full-spread PRD in the same directory, and `docs/vaults/PRETRANSFER_DIRECTIVE.md`
- Draft reviewed: `coordinator/draft.md`, ID `draft-se-fullspread-blockers-review-20261102-r1`. That file was not edited after advisory. Fingerprint: not computed.
- Coordinator mode: invoking-agent. The coordinator is not an independent vote.
- Requested members: astra (`chatgpt-subscription/gpt-6-astra:high`), grok (`xai/grok-4.7:xhigh`), minimax (`minimax/MiniMax-M3`), kimi (`kimi-coding/k3.1-pro:high`). All four initial responses and all four advisory responses settled. Runtime identity beyond those requested strings was not exposed.
- Advisory: Astra requested changes. Grok requested changes. MiniMax supported with reservations. Kimi supported with reservations. None rejected the verdict.
- This report does not authorize implementation and does not authorize a PRD edit.
- Owner answers after publication, 2026-11-02: the first deposit's fee is taken from the minted shares, `added liquidity - 1,000`, as on a later deposit. A donation or compound that already holds both tokens is a proportional deposit and does not swap. Those answers are recorded in the blockers file. They are not council votes.

## Verdict

The blocker report is not ready to be the sole instruction for rewriting the PRD.

The large locks agree. The sleeve is gone. The usage fee is taken from the new shares and clamped at 30%. Swap limits stay unbounded. The vault has no rate. A pretransfer uses the unbooked balance up to the caller's maximum, and the refund is that maximum minus the amount used, in the provided token. A lock is not a defect because the PRD still says the old thing.

The defect is that several locked sentences name different outcomes, and several others still leave an observable choice. A rewriter who copies the file as it stands will delete a later lock or ship two vaults. This report names those sentences. It does not choose the product answers.

## What can be copied

- There is no local liquidity sleeve and no sleeve-adjustment swap.
- `compound()` and `donate()` use `onlyOwnerOrOperator`. A deposit, a withdrawal, and `exchangeIn` do not call them. The owner accepts a sandwich of that maintenance call.
- The entry and redemption price limits stay unbounded. The sentence "a redemption swaps only the withdrawn net" is not in this list. The net is not defined. See F17.
- A call with no fees, no donation, and no booked remainder returns unchanged and emits nothing. The later summary that a no-fee `compound()` returns unchanged is not copyable. It drops the booked-remainder exception. See F17.
- Positive supply with zero deployed liquidity is not given a denominator.
- A borrowed exit uses the open unlock, does not call `unlock()` again, and has no sleeve fallback.
- `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)` have no other arguments.
- The B-13 lock matches `docs/vaults/PRETRANSFER_DIRECTIVE.md`.
- The 1,000-share floor is minted to `address(0)` through `_mint`. Library assignment and liquidity-only issuance stay as written.

## Findings

Each fix direction is advice. None of it was applied. None of it is a new lock.

### F1. Genesis credit is stated two ways

- Location: B-01, the `grossShares` paragraph. B-10, "The depositor receives `added liquidity - 1,000`." The already-locked list repeats the B-10 sentence.
- Requirement: one genesis credit, one fee base, and one supply increase.
- Impact: at a 30% fee, B-01 credits `(added liquidity - 1,000) - feeShares`. B-10 credits `added liquidity - 1,000`. "Supply grows only by `grossShares`" fights the floor mint if read as a global cap. "To the depositor" does not say whether that is `msg.sender` or the route recipient. B-10's later formula uses `totalShares`. A rewrite that writes `totalSupply` there points at a different variable.
- Fix direction: lock one genesis figure and say who receives the net. Scope the supply sentence so the floor mint survives. Use B-10's `totalShares` name unless the file equates it with `totalSupply`. This report does not choose the recipient.

### F2. Donation and booking are two swap policies

- Location: B-05, an underlying donation swaps its own tokens, and a share donation burns shares and does not run that swap. Booking section, both tokens from any mix do not swap, and `donate()` also compounds.
- Requirement: one rule for a donation that arrives while the other token is booked, and one rule for a share donation.
- Impact: a gift of token0 while token1 is booked is a swap under B-05 and a matched no-swap deposit under the booking rule. A share donation is said not to swap, while `donate()` is also said to compound fees and booked balances. Two implementors can still diverge after the underlying case is settled.
- Fix direction: state the precedence. State whether a share donation processes underlying fees and booked balances. A proposal that the booking rule governs the combined balance is a proposal, not a lock. MiniMax did not treat this interaction as a defect.

### F3. `reserves()` has no composition

- Location: B-06, the local reserve term remains the last committed snapshot. Booking section, `reserves()` excludes the booked remainder and uncollected fees. B-07, `localReserves()` is not restored. PRD FS-OWN-07, read in the initial pass, includes fees owed to the position and not yet collected.
- Requirement: one return value, one included set, and one computer.
- Impact: one reader returns a last-committed local balance. Another returns the deployed position only. Inside the deployed term, one reader includes uncollected fees and another excludes them. Storing Reserves Lens does not say `reserves()` calls it. One implementor uses that lens. Another uses the position-amount read.
- Fix direction: name the included balances, including whether uncollected fees are in or out, and name the computer or say it is still open. This report does not choose either.

### F4. The refund base is not defined when the maximum exceeds the unbooked balance

- Location: B-13, the refund is the caller's maximum minus the amount used. Booking section, a non-atomic pretransfer can be booked.
- Requirement: the admitted input, the refund base, and the failure behavior have to agree.
- Impact: the booking of a non-atomic pretransfer is already accepted. This report does not reopen it. The remaining gap is a declared maximum above the unbooked balance. If the maximum is 100, the unbooked balance is 60, and 40 is used, a refund of maximum minus used still asks for 60 after 40 has been spent. Clipping the input does not settle that.
- Fix direction: lock the backing condition, the admitted amount, the refund base, and whether the call reverts. Do not treat clipping, rejection, or a revised maximum as already chosen.

### F5. "Scarcer" and "best-effort" are still choices

- Location: booking section, the scarcer token is fully used. B-11, a remainder after a best-effort deposit is booked and is not itself a revert.
- Requirement: one comparison, one equal case, one result when a positive balance adds no liquidity, and one result when the swap fails.
- Impact: a raw-balance comparison and a pool-price comparison pick different tokens. A positive combined balance that cannot be added as liquidity can succeed and be booked, or fail before any event. "Best-effort" can mean the swap still reverts on failure, or that the failure is swallowed and the balance is booked.
- Fix direction: lock those four results. This report does not define scarcer, does not choose exhaustion versus dust, and does not choose a swallowed revert. If a price is used, the available reference is the pool's own price. Do not add an independent price source.

### F6. Closed notes delete swaps the locks keep

- Location: N-03, one maintenance swap, and a pool swap for `exchangeIn` only. Matrix section, booked-remainder rows cannot pass because unused input is refunded.
- Requirement: a closed note must not forbid a swap a lock keeps.
- Impact: N-03 deletes the donation swap, the booked-remainder swap, and the withdrawn-net redemption swap. The matrix sentence drops the rows that would test booking, because it treats every remainder as user unused input. It also does not say that an exact-output preview returns zero.
- Fix direction: N-03 closes only the sleeve-adjustment swap. User unused input is refunded. A maintenance remainder is booked. Those are different rows. The exact-output preview returns zero. This report does not restore a swap by itself.

### F7. "No fee cap" can delete the 30% clamp

- Location: B-02, no new price check, tick bound, or fee cap. B-01, the usage fee is clamped at `3e17`.
- Requirement: the swap sentence must not withdraw the usage-fee clamp.
- Impact: a rewriter who copies the B-02 sentence into the constraints deletes the clamp or leaves two rules.
- Fix direction: scope the sentence to the swap. It adds no swap price check, no tick bound, and no pool-fee cap. It does not withdraw the clamp.

### F8. "The owner is `feeTo()`" is not the guard's identity

- Location: B-02, `onlyOwnerOrOperator`, and "The owner is `feeTo()`." The already-locked list repeats both.
- Requirement: one authorization rule.
- Impact: the guard authorizes the diamond owner or an operator. `feeTo()` is the fee recipient. The file also says the owner accepts a sandwich and will tell users that the protocol manager can do it. It does not say `feeTo()` is that caller. This report does not add that intent. One implementor leaves the diamond owner alone. Another sets the owner to the fee collector, or authorizes `feeTo()` in place of the owner.
- Fix direction: say which identity changes, and what happens if `feeTo()` later changes. This report does not choose.

### F9. The share unit is still a choice

- Location: B-10, a share-side scale may sit on the stored balances, and no such scale is required. PRD FS-OWN-27 says share `decimals()` is 18.
- Requirement: one external share unit.
- Impact: a constant scale cancels in the mint ratio and does not cancel in `totalSupply`, holder balances, the floor, previews, or a minimum-out. Two implementors can follow B-10 and ship different ERC-20 units.
- Fix direction: forbid the optional scale, or require one stated scale and apply it to the floor, mints, burns, and previews. The existing `decimals() = 18` sentence is not withdrawn by this finding. The chosen unit has to be consistent with whatever that sentence becomes. This report does not pick the unit and does not reopen the metadata sentence by itself.

### F10. `Compounded()` has no predicate, and one-sided routes have no named event

- Location: B-11, emit `Compounded()` when fees are compounded, and correlate a caller deposit or withdrawal by "the Standard Exchange event." B-12 names that event only for the bundle routes.
- Requirement: one emission rule for every maintenance outcome, and one correlation rule for a one-sided route.
- Impact: a donation-only call, a remainder-only `compound()`, and a call that deploys nothing can emit or not. A one-sided `exchangeIn` or a one-token exit has no named vault event. One indexer uses `Transfer` plus the PoolManager events. Another waits for an event the file does not name.
- Fix direction: define the marker by outcome, and name the one-sided correlation event or say there is none. This report does not name one.

### F11. The fee is not named on every route it could reach

- Location: B-01, the fee applies to a one-sided deposit and a bundle deposit, and names `previewExchangeIn` and `minAmountOut`. FS-OWN-09 maps the bundle preview to `previewExchangeBundleInForSingleOut`. That name is a PRD mapping. It was not found as a Solidity function under `contracts/` in the initial pass. FS-OWN-25 says `exchangeIn` supports an underlying-to-underlying swap.
- Requirement: every share-minting preview returns the net, and a route that mints no shares is either in or out of the fee.
- Impact: one implementor nets only `previewExchangeIn` and leaves the bundle preview gross. Whether the underlying-to-underlying route takes a share fee is open. That half was MiniMax's finding, not Grok's. This report does not answer it.
- Fix direction: name every share preview the fee changes, including the bundle preview. Say whether the underlying-to-underlying route takes a share fee.

### F12. A failed quote and the quote engine are still open

- Location: B-06, an unsupported view returns zero, and an out-of-gas revert is an EVM error. N-04, a quote that cannot finish reverts, and the pricing engine is a question if the item is reopened. N-04 also says the plan must not invent a minimum tick spacing. FS-OWN-22, as cited there, accepts any initialized hookless pool.
- Requirement: one result for a supported quote that cannot finish. The engine is a separate choice if successful amounts can differ.
- Impact: unsupported-route zero is locked. EVM exhaustion is already excluded from the vault-error rule. Those are not interchangeable with a supported quote that cannot finish. Two engines that both revert on failure can still return different successful amounts and use different gas. Kimi treats the mechanism as not an external rule once the failure result is one sentence. Grok and MiniMax do not. That disagreement is not resolved.
- Fix direction: lock the failed-preview result. Do not treat the engine as closed. The no-new-step-cap and no-new-minimum-spacing sentences already in N-04 stay. This report does not pick the engine or the result.

### F13. The batch-swap sentence names no operation

- Location: B-02, this vault cannot be included in a batch swap with other Uniswap V4 pools. The next sentence says that is not a revocation of the borrowed-unlock path or of FS-HOOK-02.
- Requirement: a recorded limitation names the call it forbids, or says it is a disclosure and not a revert.
- Impact: one implementor reverts inside a multi-pool unlock. Another leaves FS-HOOK-02 in force. Both can claim the paragraph.
- Fix direction: name the forbidden call, or say the sentence adds no revert. This report does not choose.

### F14. The package input ABI is still optional

- Location: N-05, `PkgInit.wrappedNative` may remain only if it must equal the network constant.
- Requirement: one package input ABI.
- Impact: keeping the field changes deployment call data and the binding hash. Removing it does too. Naming the stored components does not close field names, types, order, or initialization sources.
- Fix direction: keep the field and require equality with the network `WETH` constant, or remove it. State the public package schema. The repo that stores the constant can stay internal. There is still no `wrappedNative()` getter. This report does not choose.

### F15. The seven-address write and the getter ABI are not one rule

- Location: B-07, initialization writes the seven addresses into the Protocol Aware Repo, and the repo is not given a second per-vault copy. `StateView` is stored and is not the vault's dependency. The Crane directory `lib/crane/contracts/protocols/dexes/uniswap/v4/aware` exists and was empty when checked in the initial pass.
- Requirement: one runtime source for the seven addresses, one rule for `StateView`, and one public getter ABI.
- Impact: "second copy" can forbid the instance write the previous sentence requires. One implementor writes each instance repo. Another reads the package immutables and leaves the repo empty. A third calls `StateView` because it was stored. The facet-versus-repo wiring is also unnamed: if the repo is a separate contract, initialization needs a path to it. Listing component names does not specify `salt()`, `positionLiquidity()`, signatures, or return types. A ban on a family `poolManager()` or `poolKey()` selector, copied alone, can be read as removing the Crane getters that B-07 makes callable.
- Fix direction: name the canonical write, say whether this vault calls `StateView`, and list the external getters. Keep the family-selector ban paired with those Crane getters. A single per-instance copy is a proposal, not a source-verified rule. This report does not choose the wiring.

### F16. The consumer list is pass work, and the hook binding is unnamed

- Location: B-08, the PRD pass enumerates consumers of the old 32-byte return. The lock does not make that list. The hook configures an instance for this vault and one rate target. `PkgArgs` carries `reserveVault`, `rateSubject`, and `rateTarget`, and the lock does not say which subject and target the required rows use.
- Requirement: the tuple change is incomplete until the consumers are named. That naming is work of the comprehensive PRD pass. It is not a gate that must finish before the pass starts. The draft's contrary sentence is withdrawn.
- Impact: a spot check in the initial pass found `WrappedStandardExchangeRateProviderTarget` returning `(false, 0)` when `data.length != 32`, and hook libraries reverting `RateProviderFailed` on the same check. That list was not completed. Grok also cited a non-empty state path that calls `quoteTotalSupply` and `quoteAssets`. That citation was not re-read in finalization. It remains a member-supplied gap, not a confirmed interface requirement. One fixture can price the share. Another can price a different subject and still claim the row is configured.
- Fix direction: the pass enumerates the consumers and names `rateSubject` and `rateTarget` for the required rows. This report does not compile the list and does not name the subject.

### F17. Stale sentences would make the rewrite wait or drop a lock

- Location: the heading "Audit tests that wait on an open decision." The 039 row still says the expectation waits. B-03's concluding summary says a no-fee `compound()` returns unchanged. The already-locked list says a redemption pays the caller's fraction, and also says a withdrawal pays only the principal fraction. The booking section has no identifier.
- Requirement: a closed decision must not still say it waits, and a summary must not be wider than the lock.
- Impact: a rewriter waits on 039 after B-13 locked it. A retitle that says every row in that section waits would reopen 023, 024, and 048, whose rows already match the locks. The B-03 summary drops the booked-remainder exception that the decision line keeps. "The caller's fraction" can include booked fees. Keeping those fees out of the payout does not say they are out of the swapped quantity.
- Fix direction: retitle the audit section without reopening 023, 024, or 048. The 039 expectation is the pretransfer directive. Give the booking section an identifier. Say the redemption pays the principal fraction and does not swap collected fees, or leave that quantity open on purpose. This report does not assign the identifier.

### F18. Three copy defects that do not need a new economic choice

- Location: B-05, `donate` reverts when `totalSupply` is zero, and no error is named. `lib/crane/contracts/interfaces/IStandardExchangeOut.sol`, `previewExchangeOut` returns `uint256 amountIn`, read in finalization. B-06 says that preview returns zero.
- Requirement: one error identity, and a zero preview that cannot be read as a successful quote of zero input.
- Impact: two implementors can declare different errors for the same revert. A caller cannot tell a locked zero from a real quote that needs no input.
- Fix direction: name the error, or say the revert has no new error. Say that a zero `previewExchangeOut` is the unsupported-route sentinel, not a quote. This report does not name the error.

## PRD sentences that must not be left standing

These were read in the initial pass unless a row says otherwise. They are the current PRD. A pass that edits only the IDs named inside each lock leaves them in force. This table is not the full invalidation list. The blockers file's own `PRD:` lines are also incomplete. Extending those lines, or stating that the pass owns the enumeration, is part of making the file a rewrite instruction. This report does not do that edit.

| Sentence | What replaces it, if the locks are copied |
| --- | --- |
| FS-OWN-07, local-plus-deployed, including fees owed and not yet collected | F3. The replacement composition is not written. |
| FS-OWN-13, the sleeve is used when deployed liquidity is insufficient | B-02. |
| FS-OWN-17, wrap before the amount enters the sleeve | B-02. The WETH-only caller rule stays. |
| FS-OWN-25, `exchangeIn` supports an underlying-to-underlying swap | Not replaced. F11 must say whether that route takes a share fee. |
| FS-OWN-27, share `decimals()` is 18 | Not withdrawn. F9 says the chosen unit must match whatever this sentence becomes. |
| FS-OWN-30, a redemption pays the caller's fraction of the booked local reserve | F17. The quantity is not one sentence. |
| FS-MONEY-01, `unlockCallback` calls `_compound` before deposit and withdrawal | B-02. |
| FS-MONEY-01, `_withdraw` pays pro-rata idle | F17. |
| FS-A05, genesis credits the minted shares and follows FS-MONEY-01 | F1. The netting figure is not one sentence. |
| FS-A09, `previewExchangeOut` reverts | B-06. The preview returns zero. F18 says that zero is not a quote. |
| FS-A11, withdrawal includes pro-rata idle, and compound runs before deposit and withdrawal | B-02 and the booking section. |
| FS-A33, borrowed execution uses the same compound as the locked path | B-02. |
| FS-A01, `poolManager()` is absent from the reviewed manifest | Read in finalization. F15 must not be applied so that this absence deletes the Crane getter B-07 makes callable. |

## Advisory dissent that remains

| Topic | Positions | Final |
| --- | --- | --- |
| Donation versus booking | Astra and Grok treat the interaction as a contradiction. MiniMax does not. | F2 records both. It does not adopt a precedence. |
| Quote engine | Grok and MiniMax say successful amounts can differ, so the engine is still a choice. Kimi says the mechanism is not an external rule once the failure result is one sentence. | F12 does not close it. |
| `feeTo()` | Grok alone raised the identity gap and rejected an added intent. The other three did not flag it. MiniMax did not treat the draft as rejecting an owner intent. | F8 states the file's words and adds no intent. |
| Non-atomic pretransfer | Astra and Kimi say the booking acceptance already exists. The draft had reopened it. | F4 leaves that acceptance standing. |
| Consumer-list sequencing | Astra and Kimi say enumeration is pass work, not a precondition. | F16 withdraws the gate. |

## Coverage

| Item | Result |
| --- | --- |
| B-01 | F1 and F11 |
| B-02 | F6, F7, F8, F13 |
| B-03 | Decision line copyable. Summary is F17. |
| B-04 | Copyable |
| B-05 | F2 and F18 |
| B-06 | F3, F12, and F18 |
| B-07 | F15 |
| B-08 | F16. The lock is clear. The list and the binding are not. |
| B-09 | Copyable |
| B-10 | F1 and F9 |
| B-11 | F5 and F10 |
| Booking section | F2, F3, F4, F5, and F17 |
| B-12 | Copyable |
| B-13 | Lock copyable. F4 is the refund-base gap. F17 is the stale 039 row. |
| N-01, N-02, N-06, N-07 | Not a defect. N-02 does not repair F1. |
| N-03 | F6 |
| N-04 | F12 |
| N-05 | F14 |
| Matrix and audit table | F6 and F17 |

## Limits

- Static review. No project tests were run. Agreement is not proof that the locked economics execute.
- The draft was preserved. Changes after advisory are coordinator revisions, not member-approved text.
- The consumer list was not completed. The rate-provider state-path citation was not re-read in finalization.
- The PRD table is a checked set, not every sentence in the PRD.
- This report does not edit the blockers file or the PRD.
- This report does not authorize implementation.
