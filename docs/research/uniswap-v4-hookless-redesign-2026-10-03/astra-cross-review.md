# Astra — single combined cross-review

**2026-10-03.** Continued original Astra session. Read all three complete active originals together: `grok-replacement-original.md`, `minimax-original.md`, and `kimi-original.md`. Grok is the human-authorized, peer-informed replacement, not an independent blind confirmation of my original. Its assertion that MiniMax/Kimi originals did not exist is not current evidence: both were supplied and read here. No replaced-Grok original, cross-review, or synthesis was read. My original remains unchanged. No tests, shell, implementation, delegation, or gas measurements were performed. No consensus claimed.

**Authoring incident:** I accidentally created `as-cross-review.tmp` in this directory containing only `placeholder`, outside the sole assigned output. I disclosed this in chat. No deletion/move was attempted; authorized cleanup is needed. This report is the intended assigned output.

## 1. Outcome and corrections to Astra

I change my overall ranking: **proportional basket core with separately maintained reserved liquidity is the strongest adoption baseline; uniform internal CP settlement is a conditional research candidate, not yet my preferred adoption.** Neither currently supplies a proved, fully search-free replacement for every autonomous Orbital/SY operation.

Evidence changing my view is specific:

1. **Grok and Kimi correctly emphasize already-sized redemption.** Idle exact-input redemption need not become local-cover-only to remove search. `HCommon.sol:168–192` already selects proportional liquidity and the opposing entitlement, then forward-quotes that fixed amount. My local-only recommendation was an economic restriction of my proposed internal-market design, not a computational necessity.
2. **MiniMax identifies an additional real outer search I omitted:** `OMath.sol:321–364`, `_zapSplitWadPacked`, bisects the sphere residual up to 64 iterations. My original named the face and buffer inversions but left this under an insufficiently specific “outer zap proof” gap. Eliminating those two inversions still leaves this third search.
3. **My invariant statement was too broad.** `B0*B1/S²` nondecrease applies to the frozen-book internal CP operations and suitably rounded proportional book payouts. An idle position removal can separately incur principal-rounding loss. It must not be included without that loss term. Neither statement proves market-value preservation.
4. **My proposed 50 bp internal-price limit is a new policy.** It does not preserve D20's external pool-price control. I said owner approval was necessary; I now emphasize that its economic calibration and relationship to 1 bp share rounding remain unsolved, not implementation details.

Notation: `H` concatenates `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVault`; `O` concatenates `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook`. These are literal path prefixes.

## 2. Attributed review: Grok replacement

**Agreements.** Basket issuance, forward redemption, separate public maintenance, and truthful loss of idle unilateral entry are a defensible baseline. A continuous polynomial is not automatically the integer post-swap/placement predicate. Whole active pool liquidity and the vault's owned liquidity must remain distinct. Fixed-state internal-curve reasoning is not a release proof.

**Corrections/objections:**

* Grok's `_faceForClaim` “up to 8 probes” description is wrong. `OExitQuoteLib.sol:357–371` continues its while-loop until the bracket closes. Eight limits the interpolated guesses; subsequent ordinary bisections continue. MiniMax repeats this error.
* Grok's rank-1 instruction to “deposit the already-sized offered face” cannot replace an inverse for a Hookless route which that same design makes invalid while idle. It can only work on still-supported scalar domains, or after changing the asset/interface to an already available basket/share. It also changes outer surplus allocation, not just computation.
* Grok's full-fill-only redemption is an explicit proposed restriction, not current behavior. `HQuoteService.sol:45–50,98–99` permits terminal-price-limit partial fills; `HCommon.sol:219–225` returns unswapped opposing entitlement to the booked holder inventory. Keep this disclosed residual policy unless the owner chooses rejection. Reaching a work limit away from the terminal price remains failure.
* “Cannot preserve” and “a quadratic cannot be the sizing equation” are too categorical. A rounded analytic candidate followed by one exact certificate could define a useful **restricted reject domain**. No general impossibility theorem or liveness proof was supplied. Failure of one candidate does not prove no feasible candidate exists.
* Pairing internal scalar entry/exit does not remove external hedging through in-kind exits or an external market. Conversely, pool-priced exits are not automatically forbidden by mathematics; they require explicit arbitrage economics. This is an economic approval question, not a universal interface rule.

## 3. Attributed review: MiniMax M3

**Agreements.** Composition and repair searches are distinct; full-range, fee ownership, booking, family separation and fixed protections matter. The sphere residual search is real. General two-leg exact-output redemption is not provided by the existing searched inverse.

**Material objections:**

1. **The proposed deposit sizing is missing.** `HQuoteService.sol:113–141` quotes input for an already specified output `params_.amount`. It does not choose the output or caller swap split that satisfies `(c-x)*B_other(x)=Q(x)*B_in(x)`. A one-core-step quote plus placement is not a deposit-sizing formula. Both proposed ranks 1 and 3 lack that decisive equation. A differently named `quoteDepositSingle` interface does not fill it in.
2. **Placement formula is incorrect.** Inside the range, each `getLiquidityForAmounts(q,a,b,budget0,0)` or `(q,a,b,0,budget1)` returns zero: it already takes the minimum of both token constraints. Taking the minimum of those calls therefore produces zero liquidity. Use one call with both budgets, or the two distinct one-token helpers; see the equations below.
3. **Conservation is misstated.** `F+D+E` does not equal the vault's ERC20 balance. Locally held spendable custody is F after exclusions; D is PoolManager position principal and E is uncollected fees. Full local synchronization must not write the economic book as the local reserve snapshot.
4. **Fee growth is not the vault's fee amount.** `floor(lpFee*2^128/L)` is growth per liquidity; own earned increment requires the second multiplication/floor by owned liquidity, with checkpoint semantics (`HTransitionPlanner.sol:158–165`).
5. **Forward is not inverse.** One `_claimIn(amount)` cannot replace `_faceForClaim(desired)` unless the input amount has independently been sized or the product changes to spend-all-and-allocate-excess. `ReceiveShares` likewise changes held share quantity; it is not `_amountInForZapMint` (`HInQueryTarget.sol:99–106`).
6. **Outer searches cannot be excluded from the composability claim.** The question expressly asks for autonomous search-free alternatives rather than relocating sizing. MiniMax honestly flags a remaining sphere search, but therefore does not establish its headline end-to-end recommendation.
7. **NAV need not contain a search.** `m=floor(S*(p·C)/(p·B))` is direct arithmetic given prices. Rejecting it for oracle/manipulation risk is reasonable; saying valuation necessarily relocates a sizing loop is not.

The missing-fixture report describes MiniMax's access experience, not this checkout. Both fixtures were readable in my original; the TestBase was freshly read here at `:19–61`. I cannot infer why environments differed.

## 4. Attributed review: Kimi K3

**Agreements.** Proportional funding, separating maintenance, explicit conversion-domain failures, and recognizing that one sized redemption swap is not discovery are sound. Its `m=min floor(S*a_i/B_i)`, `C_i=ceil(m*B_i/S)` pair is a useful capped-basket design.

**Material objections:**

1. **Blocked entitlement is not sleeve ownership.** `floor(r*F_i/S)` silently forfeits the redeemer's deployed/earned claim while burning r shares. Entitlement must use B (or the adopted whole-book scalar settlement), then require sufficient F to pay. With S=100, B=120 and F=20, a 10-share proportional token entitlement is 12, not 2; paying 2 is not merely a cover check.
2. **F1/F2 are not generally linear.** F1 is square-root invariant growth for two positive backing legs; F2 is a proportional exit plus internal CP conversion with nested floors. Linear formulas apply only to explicitly one-backed-leg domains. See `StandardExchangeConstantProduct.sol:49–64,78–110`.
3. **Refunds amend product law.** Existing exact-in refunds nothing, PRD `:269,398–419`. Refund-capable capped joins require explicit amendments to D8/D15 and funding semantics, not merely D7 while declaring D8–D16 unchanged. Retain-and-book excess with min-ratio issuance is not “NAV territory”; it is the current intentional Multi policy.
4. **Orbital cannot generally source the missing token with its own sphere swap.** The supplied fixture binds p0 and p1 while the nested vaults pair them with separate `seOther0`/`seOther1` (`TestBase_UniswapV4Detf_Orbital_Univ4Se.sol:36–55`). Being an AMM does not make those other tokens available as bound sphere legs. While already unlocked, a separate external PoolManager conversion also cannot be assumed available under the sleeve-only product policy.
5. **Scalar SY cannot simply alias a dual deposit/in-kind vector payout.** `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:20–42,50–76` takes one input/output token and delegates scalar SE calls. Basket core requires an explicit converter, a basket/share input asset, or narrower supported-token discovery. R9 equivalence is not automatically preserved.
6. **Refund does not make arbitrary x economically safe.** It limits contributed surplus; it does not undo a poorly priced swap, external slippage, same-pool incumbent repricing or placement costs. Buffered-leg free face is dust/refund, not ordinary Orbital backing (Orbital PRD `:58–65`).
7. The general “no arithmetic inverse” assertion is unproved. And Pons hook charges do not automatically apply to Orbital's own sphere swaps. A later Pons amendment must follow actual Pons execution, separately approved.

Kimi's 10,000-unit cutoff is sufficient for its isolated ceil loss but unnecessarily rejects some exact-ratio tiny joins. Prefer the exact existing 1 bp cross-product inequality. Placement loss is additional and cannot be hidden in that ceil bound.

## 5. Correct placement, conservation, and refund boundaries

After collecting E once and excluding all caller/refund/payout liabilities, let `T_i=D_i+F_i`, `t_i=floor(T_i*p/(1e18+p))`, `b_i=T_i-t_i`. For Q=2^96 and interior `a<q<b` (here a,b are sqrt endpoints; use distinct budget names in implementation):

```
L0 = floor(budget0 * floor(q*b/Q) / (b-q))
L1 = floor(budget1 * Q / (q-a))
Ltarget = min(L0,L1)
```

At/below the lower endpoint only token0 constrains placement; at/above the upper endpoint only token1 does. Preserve uint128, int128 settlement and max-liquidity-per-tick bounds. Source: Crane `LiquidityAmounts.sol:19–44,56–76`; `HInventoryMath.sol:216–244`.

This is a target, not proof of final funding or both sleeve bands. For addition delta-l:

```
debt_i = amount_i(delta-l, roundUp)
F_i' = F_i - debt_i
D_i' = amount_i(final-l, roundDown)
loss_i = (F_i+D_i) - (F_i'+D_i')
```

For removal, add rounded-down proceeds to F instead. Recompute final T, target and cover. `HInventoryMath.sol:253–292` explicitly records loss. Thus `B_after=B_before+C-payout-refund-loss` for a no-swap workflow with caller funding counted consistently; placement does not create backing, but integer representation/settlement can reduce it. Pool swaps additionally require their token deltas, incumbent repricing and own fees.

Grok's “rounding loss stays booked” is insufficient: a lost unit cannot remain an owned asset. Post-mint placement charges all then-current shareholders unless explicitly allocated otherwise. My baseline prefers deferred maintenance so ordinary mint conservation has no hidden placement cost. Owner selection of immediate placement needs an exact attribution policy.

A fixed stencil is not automatically exempt from the task's “probe sequence” definition merely because it has two or three candidates. The old plan permits its stencil; this research must distinguish that from a new strict search-free claim. For an unambiguous ordinary path, compute **one** deterministic target, validate exact settlement, and defer/reject placement if it fails—do not adaptively optimize candidate quantities. Prove any fixed rounding correction before treating it as arithmetic rather than sizing discovery.

For a new capped/refundable basket route: measure actual credited a, compute C, and refund only `a-C`; pull mode can instead pull exactly C. Unclaimed surplus and booked F are never refund budgets. Preserve source-agnostic eligible pretransfer claims. Snapshot fees and caller credit before collection, payout/refund before full local synchronization. Existing exact-in retains all declared credit unless the owner explicitly changes that contract.

## 6. Autonomous composition: what is actually available

**Search-free capabilities supported by the evidence:** known basket joins; known-share in-kind exits; idle known-share external conversion with a bounded forward quote; F1 scalar mint and exact-share inverse in its currently blocked domain; F2 scalar redemption with actual local cover; share receipt and rate scaling. None implies universal availability.

For my conditional uniform-F1 design, the proposed replacement remains concrete:

1. Convert desired rated-native claim to a required integer share quantity using the configured rate and decimal-aware ceiling.
2. Invoke `quoteInputForExactShares(state,requiredShares)` under the newly approved idle/blocked invariant policy.
3. Validate available credit and one actual forward result, then execute a matching exact-share or exact-input route. Preserve the exact choice: an exact-input call may mint more shares, so it cannot be modeled as an exact-share call silently.

This could replace the two buffer inversions, **not** `_zapSplitWadPacked`. Cheap inner calls leave the latter a sizing search. A new deterministic outer split or an exact raw-share basket interface is required. A fixed split followed by one proportional join can be search-free but trades away optimal consumption and needs explicit residual ownership, minima and honest rejection; it is not a proven compatible implementation here. The established B6 flexible share-basket surface is the conservative capability to retain, without claiming scalar SY is thereby solved.

## 7. Economics across routes

Uniform internal settlement removes a manager-state pricing switch, not external arbitrage. A continuous illustrative book B=(100,100), S=100, token1 worth two token0 externally: deposit 21 token0, ideal invariant mint 10 shares, then in-kind redeem those 10/110 shares for (11,100/11). External value is about 29.18 token0, exceeding 21 before costs. Scaling units makes integer dust small. This is **not** a tested exploit or an admitted transaction under my proposed 50 bp guard; it demonstrates why the fixed-book invariant does not prove economic neutrality. The same marginal adverse selection can exist for smaller trades when internal and external prices differ. Actual pool/fee/cover/repricing costs must be included in executable adversarial analysis.

Retaining existing blocked F1 while removing idle composition also retains this economic issue: unlock context is not itself trusted price validation. Attackers may sequence an outer unlock, internal settlement, and later idle redemption. Local cover limits immediate payout, not valuation loss or cumulative turnover. No cooldown/campaign cap is proposed. Whether these are acceptable paid-arbitrage economics or unacceptable holder subsidy needs explicit owner judgment and quantified later evidence.

## 8. Final ranking and human checkpoint

1. **Proportional basket core; retained-and-booked exact-in excess; separate reserved-sleeve maintenance; known-share idle redemption retained.** Strongest source-supported accounting baseline. Explicitly loses idle scalar pair→share buffering and does not satisfy the full original Orbital/SY requirement unchanged. Preserve blocked routes only with an explicit cross-mode economic gate.
2. **Uniform internal CP scalar routes** if autonomous scalar entry is essential and the owner accepts a second internal market, cover-limited exits and changed bounds. Existing arithmetic is a starting point, not economic approval. Outer sphere search remains to be redesigned.
3. **One-candidate certified external zap** as a later restricted optimization, only after a genuine sizing equation and nontrivial supported domain are supplied. A one-step quote alone is insufficient.
4. **Oracle-NAV issuance** only under a separately specified oracle/economic product; not the default.

**Concrete owner decisions:** choose lost scalar routes versus internal-market economics; retain exact-in no-refund law versus approve capped/refundable joins; select deferred versus immediate placement and loss attribution; approve any new internal-price/rounding bounds without mislabeling D20; select outer Orbital basket-only support or explicit search-free split semantics; retain terminal partial-fill residual policy versus full-fill rejection. Pons remains separate and unchanged absent its own approved scope.

**PRD closure:** amend D1–8 as applicable to the selected admission/refund/order policy, D15 if exact-in refunds change, D18–19 for maintenance separation, D20/D25 if guard meanings change, and D27/D30 for complete route/parity tables. Keep D9–12/D21 on separate maintenance unless explicitly changed. Preserve D13–14, D16, closed-form-only D17, D22–24/D26/D28–29/D31. Update corresponding DETF/SY and Orbital product law; no implementation may infer these amendments from a council vote.

**Unsolved proofs/release gates:** nontrivial certified deposit-sizing domain; rounding-aware placement and exact entitlement reconciliation; full outer split/inverse/state/rate parity; cross-state internal/external/in-kind economic cycles; donation/pretransfer/refund safety; blocked-cover failures; zero/one-sided/import/native/mixed-decimal domains; current runtime/source pins. Later agents must use production-path proxies, build current artifacts before tests, replay the funded-binding fixtures including seed 16222, and measure complete nested calls under unchanged 31M/32M constraints. Passing tests or agreement proves neither security nor economic soundness.

## 9. Evidence and limitations

All fresh accesses: **2026-10-03**. Current CLAUDE, PRD funding/interleaving/booking sections, canonical IndexedEx testing skill and current source were re-read; canonical Crane architecture/deployment/testing/adversarial skills were read in the original session. Context7 `/uniswap/v4-core` preceded fresh library verification. Primary: https://raw.githubusercontent.com/Uniswap/v4-core/main/test/utils/LiquidityAmounts.sol (upstream main, pragma ^0.8.20); local Crane port pragma ^0.8.24. Repository compiler baseline remains 0.8.35, optimizer 1, no via-IR from the original direct configuration read. Upstream main is not a deployed-version pin.

Two mistaken ordinary paths were missing and were not retried: `contracts/vaults/standard/exchange/protocols/uniswap/v4/libraries/LiquidityAmounts.sol` and `contracts/vaults/standard/yield/NativeStandardYieldTarget.sol`. Actual source locations were read respectively under `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/` and the glob-discovered `contracts/vaults/standard/sy/`. No guard denial or genuine SDK unavailability occurred.

Confidence high in the cited sizing/interface/accounting errors; medium in the restricted architectural ranking; unresolved in economic acceptability, integer liveness and measured performance. This is my sole combined cross-review, returned for human/moderator decision. Stop; no further round or execution authorized.
