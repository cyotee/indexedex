# Astra — single combined cross-review

**2026-09-26. Research only.** Read Grok, MiniMax M3 and Kimi K3 originals together, in full, as untrusted evidence. No cross-review artifacts read. All originals preserved. No shell, tests, implementation or delegation. This is the one cross-review returned to the moderator, not final consolidation.

**References:** peer line numbers refer to `grok-original.md`, `minimax-original.md`, and `kimi-original.md` in this directory. **V/** abbreviates `contracts/protocols/dexes/uniswap/v4/`; **Common** and **InBase** are the corresponding `UniswapV4StandardExchangeCommon.sol` and `UniswapV4StandardExchangeInBase.sol`.

## 1. Agreements and changes to Astra's position

All three identify the same material mechanism as Astra: the single-token deposit does not swap; tail deployment offers only excess above each sleeve target; in-range liquidity binds on the scarce token. PM idle/locked versus in-session/unlocked and the need to retain blocked sleeve operations are substantially agreed. No peer provides executed evidence of a new solution.

**Astra retains:** caller-attributable composition rather than permissionless whole-book trading; both-token initial funding; policy percentage of each token's total; explicit user-swap preview; current full-range import/native authority; issuance attribution as an unresolved economic specification.

**New evidence sharpening my original:** direct inspection of `V/UniswapV4StandardExchangePositionImportTarget.sol:77–94,100–109` confirms conversion in actual code, not merely mandated conversion: it collects the imported NFT's assets, requires positive initial shares, finishes imported conversion, and creates the managed full-range book. This directly rules out peer proposals designed around retaining imported narrow ticks.

**Clarifications to Astra's original:** “swap before mint” is a necessary sequencing recommendation for the proposed depositor-funded route, not proof that incumbent losses are isolated. Caller-only execution still trades against and changes the vault's own LP position. Also, a single-token deposit does not universally fail to deploy: existing counter-token excess, later fees, price changes, or valid one-sided boundary geometry can change the outcome. The reproducible problem assumes a two-sided in-range book with no counter-token excess. No universal forever/100%-idle claim is justified.

## 2. Grok: mostly agree, with material corrections

**Agree:** narrow user-route supersession; blocked behavior unchanged; no public inventory swaps; post-swap CL ratio rather than raw 50/50 or skewed total-book ratio; minShares plus trading protection; current tests' overly wide sleeve tolerances (Grok:14–24,29–44,51–74).

**Objections:**

- **Import policy:** R4 and A-Z8 (Grok:55,98) revive out-of-range imported backing. D57/§24.7.1 requires conversion, and current import code performs it. Test converted full-range deposits, not preservation of narrow NFT ticks. Historical deployed instances require a separate migration/scope decision.
- **Cost attribution:** “swap-before-mint charges [all costs] to depositor” (Grok:67) is too strong without an issuance equation. Repricing incumbent deployed amounts and own-LP earned fees must be excluded from new principal; transformed input may be unbalanced against the incumbent total book. Current dual min-ratio is not automatically fair for this route.
- **Swap budget:** “only incoming excess” is useful as a cap but underspecified as an algorithm. Counter-token obtained by the swap also increases its target sleeve; the swap changes incumbent deployed amounts. Solve final balances jointly, rather than reserve p of original input and blindly halve the remainder.
- **Impact bounds:** a cap relative to already-manipulated spot does not itself reject manipulated spot. A-Z10 needs a defined reference or must assert only bounded incremental execution impact. No verified TWAP requirement follows.

## 3. MiniMax M3: useful opt-in alternative, unsafe details

**Agree:** a separate explicitly bounded zap selector can preserve legacy route behavior and expose `minCounterOut` alongside `minSharesOut`; the dedicated zap can reject blocked operation while existing exchangeIn retains sleeve compatibility (MiniMax:102–117,154). This is a coherent *alternative product choice*, not already approved.

**Corrections:**

1. `Common:698–712` uses proportional amount/supply math only when an existing reserve is zero; normal one-token deposits into a dual book use invariant growth. MiniMax:40 misstates the ordinary formula. Neither “sleeve >100%” nor “already 100% sleeve” follows (MiniMax:24,43): free/total cannot exceed 100% under reconciled nonnegative accounting.
2. The no-swap shape is changing; calling it a user operation does not preserve all of D27/D32 by relabeling. Local-buffer D27 is not DETF-alignment D27. Do not import unrelated DETF reserve rules or invent an alignment decision number.
3. MiniMax's first-mint acceptance (166,186,194) conflicts with preserving D59 and its own contrary statements. An initialized pool and an activated vault are different; no swap is guaranteed in an empty-liquidity pool. Retain actual dual-funded activation, no swap-to-bootstrap exception here.
4. `_executeDirectSwapIn` is not a clean composition primitive: it transfers output to a recipient, synchronizes the book, and tail-rebalances (`InBase:72–86`). Sequentially calling it and the dual-deposit routine risks premature bookkeeping/deployment and attribution mistakes. Existing helpers that open unlock cannot simply be called inside an already-open callback. No implementation recipe is approved.
5. A normal full-transaction revert rolls back transfers and shares; it does not strand the user's principal. Reject the “revert → loses tokens” rationale for catch/refund (MiniMax:236). Gas costs remain distinct. Its blocked “keep credit after revert” statements conflict with its atomic dedicated-selector rejection; choose one explicit route contract.
6. Reject unapproved import exclusion and native-position exclusion (73,240–241). Current imports convert; native PoolKeys use WETH-facing sleeve/settlement. Reject `_syntheticOfPair`-style SE gating derived from DETF issuance law (213).
7. “Dual min quote strictly less than single quote” (161) is not established across differing prices, fees, reserves and quantities. A 100%-liquid policy also conflicts with unconditional positive-L acceptance; it needs an explicit route outcome.

The missing test-path evidence in MiniMax is resolved by Astra's original citations to `test/foundry/spec/protocol/dexes/uniswap/v4/`; it is not evidence that tests are absent.

## 4. Kimi K3: disagree with the proposed economic design

Kimi:39,49 expressly retains mint-before-swap and socializes residual loss; Kimi:55–57 recommends excluding the swap from the main preview. **I dissent.** Identical minted shares do not protect economic value when a subsequent trade reduces their backing. A user minimum tested before that trade does not cap incumbent-holder loss. A bounded socialized portfolio trade is a separate product policy, not an accounting-neutral placement operation. It requires explicit approval even if a price guard bounds it.

Also reject:

- A mandatory bound-TWAP minOut inferred from DETF price-gate law (42). A poke/accessor is not proof of a suitable security oracle, window, freshness, history or fail-closed behavior.
- Old imported-tick preservation (43,80), superseded by current law and conversion code.
- Automatic skip-on-swap-failure (62,87) as fulfillment of “swap and deploy.” It can preserve the reported undeployment while presenting success.
- Assuming spot approximation plus deadband proves ratio correctness or loss bounds (44). Deadband is an inventory-placement tolerance, not a price-protection rule.
- “Donation between mint and swap impossible—atomic” (66). External token/hook callbacks can transfer assets during a transaction. Atomicity is rollback, not absence of interleaved external behavior. No exploit is asserted; the negative test is required.

Kimi's later-deposit backlog repair proposal also spends incumbent inventory unless explicitly capped to new contribution. It is broader than Astra/Grok's recommended scope.

## 5. Precise recommended PRD decisions

**Recommended, not approved:**

1. Make idle single-token deposit composition part of the **user route**; keep blocked exchangeIn sleeve-only, with no attempted swap. Preserve public/tail rebalance as add/remove-only and Multi's exact-two-positive-input no-swap contract.
2. Restrict composition input to verified current-call contribution. No authorization to swap incumbent sleeve, donations or blocked backlog. State prominently that clearing existing backlog is **not guaranteed**. If clearing backlog is the human's primary requirement, obtain a separate whole-book-trading decision rather than claiming this narrow solution satisfies it.
3. Prefer enhancing existing exchangeIn behavior to address the actual reported route. An opt-in selector alone leaves existing callers unchanged; choose it only with an explicit product/integrator migration decision. If the existing ABI cannot express adequate limits, approve an additive bounded route and truthful capability/preview disclosure instead of silently choosing weak defaults.
4. Finalize issuance only after measuring composition results with a separately specified incumbent-book treatment. No approved issuance formula emerges from this council. Preserve complete-book/once-only fee accounting and prove old/new-holder attribution, own-LP fee effects, mixed-decimal rounding and round-trip safety.
5. Preserve live per-token **p of total**, exact post-swap CL sizing, policy sleeve, current deadband and dual activation. Retain native/WETH and converted-import routes. Define dust, boundary prices, no-depth and p=100% outcomes; never force fee-bearing swaps merely to claim deployment progress.
6. Preview the economic user swap and issuance, including hook/protocol costs and actual-fill semantics. Transition projections and SY consumers must match. Placement-only movements may remain excluded from scalar share previews, but not from projected state when consumers need that state.
7. Required composition/slippage/funding failures revert atomically; do not silently fall back after attempting an idle zap. Separately identify benign dust/policy no-ops and any permitted deferred placement. `Common:734–738` is not catch-isolated despite its BestEffort name.
8. Specify user deadline/minShares, swap bounds and their price reference. A TWAP may be chosen only after explicit oracle design review; DETF law mandates neither a TWAP nor an SE synthetic-price gate. Price-impact caps, user minimums and independent-reference deviation checks address different risks.

**Acceptance:** preserve Astra's production-path tests; add incumbent/new-holder attribution and self-LP effects, strict repeated-deposit sleeve/L checks, callback-time donation and cross-facet reentry, manipulated starting price versus incremental impact, partial fills and full rollback. Test whichever route decision is approved through actual consumers; scalar preview equality alone is insufficient.

## 6. Remaining approval blockers and confidence

Unresolved: existing-route change versus opt-in migration; contribution-only versus backlog mandate; exact issuance/fee attribution; slippage reference, limits and oracle failure policy; deployment guarantee versus explicit deferral/dust/p=100%; supported hook/quote set. These are not settled by majority agreement or passing tests.

**Confidence:** high on root cause, current authority, import conversion and identified code-helper behavior; medium on architecture recommendations; unresolved on economic proof and safe numerical solver. No new external-library claims were needed: this review uses local source and authority, plus the Context7-first/primary-source evidence recorded in Astra's original (accessed 2026-09-26). Versions remain local solc 0.8.35 / Crane 0.1.0-public-preview; exact upstream port/deployment pins remain unverified. Originals are not revised by this review.
