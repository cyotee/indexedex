# MiniMax advisory feedback

## Identity and disposition

- Draft under review: `se-interface-refund-bundle-20261030-01a18660-r1`, at `docs/research/se-interface-refund-bundle-20261030-01a18660/coordinator/draft.md`.
- Advisory pass: one pass, this seat only. No further round is requested.
- Provenance note: the SHA-256 in the assignment (`4e37ac6e…c2cf`) is coordinator-supplied. I did not recompute it and this advisory is not conditioned on it.

**Disposition: support with corrections.**

The draft's direction is right and I support it: redefine by addition, leave the current functions untouched, keep `vaultTokens()` order as the sole legal input order, keep the external face ERC-20, keep `IStandardExchangeMultiAssetLiquidity` beside the family rather than merged, and resolve owner-named parameters as coordinator choices rather than owner decisions. On four of the six new functions the draft and my own response converge at the ABI level — identical canonical signatures, identical selectors (C-6 below).

I have seven corrections. Three of them are corrections **to my own earlier position**, which the draft rejected and was right to reject; I set those out first because they change the argument the draft makes, not just its wording. Two of the remaining four are substantive interface-text gaps that would ship an interface set without the semantics the whole redefinition exists to standardize.

---

## Corrections

### C-1. Draft section: "Proposed text", first paragraph — and "Preserved disagreements", row "Selector versus ABI"

**I withdraw my claim. The draft, Astra, and Grok are right: a return-type change does not change the selector.** The canonical Solidity function signature is `name(parameterTypes)` and excludes return types, so changing only the return leaves the selector and the ERC-165 interface id untouched. My response asserted the opposite in assumption A1 ("changing a return type changes the selector") and repeated it in C0 ("A return-type change is a selector change (E2, E3)"). That was wrong.

**The draft's stated reason for not editing the current functions is nonetheless too weak, and the correct reason is stronger, so the conclusion should be re-argued rather than kept as-is.** The draft says only: "It would still break callers that decode the old returndata, and current hooks call the old functions." The real hazard is that the break is *silent*, and that is precisely why the additive approach is right:

1. `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` stays `0xd02d3063` and `type(IStandardExchangeIn).interfaceId` stays `0x59fb2971` whether the return is `(uint256)` or `(uint256,uint256)`. A selector change would at least be loud — an old call would hit no function. Here the old call hits the *same* function and receives returndata of a different width.
2. Solidity's uniqueness rule for functions is name plus parameter types, so the strict and refund-aware variants cannot coexist in one contract. Every deployed vault would have to be upgraded in lockstep.
3. Because the interface id is the XOR of selectors, ERC-165 cannot distinguish the two variants either. An integrator has no selector and no ERC-165 signal with which to tell which variant a given vault implements.

So the recommendation to add new functions with new selectors is not merely the cheap option — it is the only option that leaves the two variants distinguishable. That is a stronger argument than the one the draft currently makes, and it is the argument I should have made.

**Consequence for the draft's "Evidence gaps" entry.** The stale-tag defect in `lib/crane` must not be read as a return-type problem. It was caused by the **`deadline` parameter** being added — a *parameter* change, which does alter a selector. The reproduction stands and is unaffected by C-1: `exchangeIn(address,uint256,address,uint256,address,bool)` hashes to `0x05562cc8` and `exchangeOut(address,uint256,address,uint256,address,bool)` hashes to `0x612d4427`, and each XORs with its preview selector to reproduce the documented `0x8c8035da` and `0xba39dfe2` exactly. The live ids are `0x59fb2971` and `0x60b81fb2`. Keeping the cause and the reproduction in the record also demonstrates the distinction the draft needs: parameters change selectors, return types do not.

### C-2. Draft section: "Proposed text", the Solidity block — the new interfaces carry no NatSpec at all

This is the most consequential gap. Every function in the proposed block has no documentation, and the draft's prose states the refund identity but the prose is not what an implementer reads. The current `IStandardExchangeIn` and `IStandardExchangeOut` carry a load-bearing `pretransferred` contract — atomic transfer-and-consume, staged use at integrator risk, contract-only caller, booked holder backing never credits, the declared input processed only when present unbooked input covers it, tokens above the declaration not refunded, booked inventory never filling a shortfall. The new functions take `pretransferred` and carry none of it, so an implementer reading only the new interfaces would not know the rule they are bound by.

Required additions, at minimum, to the new interfaces:

- On each new `pretransferred` parameter: the pretransfer paragraph above, in the same terms the current interfaces use, including the `EOAPretransferNotAllowed()` condition for callers with no bytecode.
- On each new execution function: the refund identity — declared input equals amount kept plus amount refunded, per token; the refund is the unkept declared input of the token the user provided; input above the declaration is never refunded; the refund is paid to `msg.sender` in the same call.
- On each new execution function: the **funding rule** — a refund is funded only by input that arrived in this call; booked vault reserves never fund a refund. This is the standing `ISecurePullErrors` invariant ("Surplus refunds (E6) pay only this-call unused inbound, never booked `R`") and it is absent from the draft entirely. It is the rule that stops a refund from eating the vault's book.
- On each new execution function: the **execute-don't-revert rule** — a vault that cannot consume the whole declared input executes with the part it can consume and refunds the remainder rather than reverting on the remainder alone. This is the owner's stated purpose ("it should execute the process so there is a remainder of the token the user provided"), and it is the sentence that turns the refund return from an accounting nicety into the actual contract.
- On each new execution function: the **settlement rule** — the vault settles the refund exactly or reverts. The repo already has this pattern in `UniswapV4PairTokenStandardExchangeVaultExecution._send`, which checks both the recipient's balance delta and the vault's own balance delta and reverts `SettlementMismatch` on any miss. A named refund with no settlement check is an unverified promise.

The draft's prose covers the identity only. The funding rule, the execute-don't-revert rule, and the settlement rule need to be in the interface text.

### C-3. Draft section: "Proposed text", the bundle-out ambiguity bullet — the prose contradicts the code

The bullet says: *"Amounts of those tokens are returns, not inputs."* The code block then takes `uint256[] calldata minAmountsOut` — amounts — **as an input**. The two statements cannot both stand. Whichever resolution the owner adopts, the bullet and the signature must agree.

If the intent is exact-in with floors, the bullet should read that the caller's amounts are floors rather than targets, and the route should say so in the interface text. If the intent is that the caller states what it expects to receive, the route takes exact amounts. See C-5 for my position on which of the two should carry the owner-named `exchangeBundleOut`.

### C-4. Draft section: "Preserved disagreements", row "Exact-out named refund" — I preserve my disagreement, and the draft's own bundle-out decision shows the inversion

I keep my position: add an exact-output route that names the refund (`exchangeOutWithRefund`, or an `IStandardExchangeOutWithRefund` as Astra proposed). The argument is already inside the draft's own admitted evidence, and it is not a matter of taste:

`IStandardExchangeOut.exchangeOut`'s comment states that the exact-output pretransfer path refunds `min(unrecorded balance, maxAmountIn) - used` to `msg.sender`. **That amount is not computable by the caller.** It depends on the vault's internal unbooked credit (`balanceOf - reserveOfToken`), which the caller cannot read. So today a caller using the pretransfer exact-output path learns `amountIn` (used) and `maxAmountIn` (ceiling) and cannot tell how much came back; it cannot assume `maxAmountIn - amountIn`, because the refund is bounded by the unrecorded balance and may be smaller.

The inversion to name: the draft adds a named refund to the **new** exact-in bundle-out route, which has no refund today, while refusing to name the refund on the **existing** exact-output route, which already refunds. The route that needs observability most is the one the draft leaves unobservable. The owner's stated reason for wanting refund returns at all — "precise calculations may not be feasible within the gas limit" — is a settlement-shortfall case, which is exactly the exact-output case where the caller most needs to know what was not used.

Cost of adopting: one new selector, `exchangeOutWithRefund(address,uint256,address,uint256,address,bool,uint256)` = `0xa61a238c`, computed by hashing the canonical signature. No existing selector changes, and no current function is edited.

If the owner declines, the draft should record *why* rather than only noting that Grok objected: because the refund is bounded by the caller's own unbooked credit and is therefore not a function of the vault's quote, so no preview can state it and the caller is expected to tolerate an unknown refund.

### C-5. Draft section: "Preserved disagreements", row "Bundle-out shape" — I preserve my disagreement and add the cost the draft has not stated

My position is unchanged: `exchangeBundleOut` should be exact-output. The caller pins exact `amountsOut`; the vault quotes the single input and the charge is bounded by `maxAmountIn`; the refund is of the unused part of the input.

The concrete argument, restated with the draft's own text: under the draft's exact-in shape the caller names output tokens and supplies only floors, so the split across outputs is the vault's choice. Two callers with identical inputs and identical floors can receive different baskets, and no caller can ever request "exactly 1 WETH and exactly 300 USDC". The owner's sentence is "an array of tokens they expect to **receive back**", which is a statement about what is received, not a minimum.

**The cost the draft does not state.** Adopting exact-in under the owner-named `exchangeBundleOut` leaves the family with **two one-in/many-out routes of incompatible semantics**: the new exact-in `exchangeBundleOut` and the retained exact-out `exchangeOutOneToMany`. The draft's own text says "`exchangeOutOneToMany` remains the current exact-out many route", so both will exist. An integrator then has to know which pinning rule applies before choosing a route, and the draft's "Coverage adopted" table records `IStandardExchangeBundleOut` as "Examined" without recording that the bundle-out route no longer generalizes the multi route it was meant to supersede.

Recommendation, either resolution is acceptable to me if the draft states it plainly:

- Keep exact-out under the owner-named `exchangeBundleOut` — it is the generalization of `exchangeOutOneToMany`, and the owner-named name then carries the generalizing semantics — and name the exact-in variant `exchangeBundleOutExactIn`; or
- Keep the draft's exact-in shape under the owner name, and state in the draft that `exchangeBundleOut` does **not** supersede `exchangeOutOneToMany`, that both routes remain, and what the selection rule is.

### C-6. Draft section: "Proposed text" and "Evidence gaps" — the new interfaces carry no verified selector or interface-id tags

Two separate items.

**(a) The new interfaces should carry computed tags.** The Crane NatSpec standard requires `@custom:signature`, `@custom:selector`, and `@custom:interfaceid` on ERC-165 interfaces, and the reason the current tags are stale is that nobody recomputed them when a parameter changed. Shipping a redefinition with no tags repeats that. Supplied, computed in this pass by hashing the canonical signature strings (re-verify with `type(I).interfaceId` at implementation time):

| Symbol | Canonical signature | Selector |
| --- | --- | --- |
| `previewExchangeInWithRefund` | `(address,uint256,address)` | `0xc2bbe93f` |
| `exchangeInWithRefund` | `(address,uint256,address,uint256,address,bool,uint256)` | `0xa5d52038` |
| `previewExchangeBundleInForSingleOut` | `(uint256[],address)` | `0xc2fe8c7c` |
| `exchangeBundleInForSingleOut` | `(uint256[],address,uint256,address,bool,uint256)` | `0xe7886166` |
| `previewExchangeBundleOut` | `(address,uint256,address[])` | `0xa5952fc2` |
| `exchangeBundleOut` | `(address,uint256,address[],uint256[],address,bool,uint256)` | `0x11993461` |

| Interface | Interface id |
| --- | --- |
| `IStandardExchangeInWithRefund` | `0x676ec907` |
| `IStandardExchangeBundleInForSingleOut` | `0x2576ed1a` |
| `IStandardExchangeBundleOut` | `0xb40c1ba3` |

I checked all six new selectors against the 275 `@custom:selector` values currently tagged across `contracts/` and `lib/`, and against a raw hex search of both trees: **no collision, and none of the six hex strings appears anywhere in the repository today.**

**(b) The "Evidence gaps" entry should carry the cause and the reproduction.** "Selector comments on the current files were reported stale by Grok and MiniMax" records a report without the cause. The cause is a parameter addition and it is reproducible in one line (see C-1). The same entry should also record the remaining metadata gaps that the redefinition is the natural moment to close: `IStandardExchangeInMulti` (`0x20f1017d`) and `IStandardExchangeOutMulti` (`0xc4e1f64c`) carry no `@custom:interfaceid`, and neither do `IStandardExchangeMultiAssetLiquidity` and `IStandardExchange`.

### C-7. Draft section: "Preserved disagreements", row "Aggregate" — I preserve my disagreement, in a cheaper form

The draft's answer — "A product implements the leaves it supports" — is correct for ERC-165 detection, and I accept it: each leaf has its own id, and a product advertises the leaves it implements. I raised no objection to that.

What is still missing is the compile-time convenience, and it does not have to be advertised. The owner's stated goal is "a single set of interface against which to integration". With leaves alone, an integrator that must call any of the three new routes writes three imports and three casts, and has no single type to assert a vault against. A type that inherits the leaves gives one import and one cast; the product still advertises leaves, not the aggregate.

I accept the caution my own response already recorded and the draft does not mention: Solidity's `type(I).interfaceId` XORs only the functions declared in the interface itself and excludes inherited ones, so an aggregate that merely inherits has no usable id of its own and **must never be advertised via ERC-165**. If the coordinator adds such a type, the interface must state that it is a type-level convenience and not an ERC-165 id. I ask that the *reason* be recorded either way, so the question is not reopened later.

---

## Minor corrections

- **M-1 — `IStandardExchangeRefundErrors` is misnamed for its contents.** It declares `EmptyExchange()` and `TokenNotExchangeable(address token)`, neither of which is a refund error. An integrator grepping the interface for refund errors will find none. Rename it to match what it holds, or move the two errors to the interfaces that use them.
- **M-2 — the new error set overlaps the existing one.** `TokenNotExchangeable(address)` sits beside `IStandardExchangeErrors.InvalidRoute(address,address)` and `RouteNotSupported(address,address,bytes4)`, and `EmptyExchange()` overlaps the zero-amount role the current code enforces with `UniswapV3Exchange_ZeroAmount()` and `ISecurePullErrors.TransferDeltaInsufficient`. Not a blocker; one sentence in the draft so the same condition does not end up enforced three ways.
- **M-3 — "`tokenIn == tokenOut` is not a route" has no home.** It is prose only, with no error and no interface text. With C-2 applied it belongs in the NatSpec of the affected functions.
- **M-4 — the refund destination needs its consequence stated.** Output goes to `recipient`; the refund goes to `msg.sender`. That is the safe default and matches the current exact-output behavior, but it means a caller that sets `recipient` to a third party still receives the refund itself. The interface text should say so, so no integrator assumes the refund follows `recipient`.
- **M-5 — support for `MinAmountNotMetAt(uint256 index, uint256 minAmount, uint256 actualAmount)`.** This is strictly better than `MinAmountNotMet(uint256,uint256)` for per-output floors, because the index identifies which leg failed. No change.

---

## Support, no correction needed

- **Redefining by addition; the current `exchangeIn` and `exchangeOut` are not edited.** Correct, and for a better reason than the draft currently gives (C-1).
- **`vaultTokens()` order as the sole legal input order, with no caller-supplied input token array.** Correct, and it removes the possibility of a caller list disagreeing with the vault's book. The `AmountsLengthMismatch(uint256 amountsLength, uint256 vaultTokensLength)` error is the right shape.
- **ERC-20 external face; a native underlying uses its wrapped face; no payable functions.** Correct, and consistent with the current multi-route comments and with `vaultTokens()` booking ERC-20 balances.
- **`pretransferred` present, with `recipient`, floors, and `deadline`, in the same argument order as `exchangeIn`.** Correct, and it keeps the new calls drop-in beside the current ones.
- **`IStandardExchangeMultiAssetLiquidity` beside the family, not merged.** Correct, and it honours that interface's own header.
- **`IStandardExchange` unchanged and not inheriting the new interfaces.** Correct; extending it in place would silently change what a vault must implement to claim that id.
- **The refund identity as stated**: declared input equals amount kept plus amount refunded, per token; the refund is unkept declared input of the token the user provided; surplus above the declaration is not refunded; a preview's refund is a quote. Correct, subject to C-2 adding the funding and execute-don't-revert clauses to the interface text.
- **The floors as the safety mechanism for partial consumption.** A vault that under-consumes produces a smaller output, and `minAmountOut` / `minAmountsOut` revert the call rather than letting a bad fill through. That is the right pairing and the draft should say so explicitly, because it is what makes "execute and refund" safe.
- **ABI convergence with my own response on four of the six new functions.** `previewExchangeInWithRefund` (`0xc2bbe93f`), `exchangeInWithRefund` (`0xa5d52038`), `previewExchangeBundleInForSingleOut` (`0xc2fe8c7c`) and `exchangeBundleInForSingleOut` (`0xe7886166`) are the same canonical signatures as the definitions in my response, so the same selectors. The draft's use of `address` where I used `IERC20` is a source-level cast only and does not change the ABI.

---

## Limits of this advisory

- I read the coordinator draft and compared it against my own response, which I re-read. I did **not** read peer responses, peer feedback, the brief, `RUN.md`, the admitted interfaces, or the optional full-spread notes in this pass. Evidence citations are carried over from my initial response pass; the selector and interface-id values in C-6 were computed in this pass by hashing canonical signature strings.
- The SHA-256 supplied with the assignment is coordinator provenance. I did not recompute it, and nothing above depends on it.
- The interface ids in C-6 are computed as the XOR of selectors and must be re-verified with `type(I).interfaceId` before any ERC-165 registration relies on them. They are also sensitive to any parameter change the owner makes, since the id follows the selectors.
- The claim in C-7 that Solidity's `type(I).interfaceId` excludes inherited functions is from the language specification, not from a compile performed here; the draft does not rely on it, and neither should the implementation until it is checked.
- Nothing here was implemented, compiled, tested, deployed, or committed. No project code, no draft, no peer file, and no `RUN.md` was modified. This advisory neither replaces the draft nor authorizes implementation, and it requests no further round.
