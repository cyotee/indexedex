# MiniMax — advisory feedback on `fullspread-se-prd-draft-r1`

## Identity

- **Assigned route label:** `minimax/MiniMax-M3` (assigned by the coordinator; a request, not a runtime attestation of model, provider, or reasoning depth).
- **Role:** independent council member, **advisory pass only**, second and final pass for this assignment.
- **Owned path:** `docs/research/fullspread-se-prd-20261030-01a18660/members/minimax/feedback.md` — this file only.
- **Not done in this pass:** no implementation, no Forge/build/test, no Git, no delegation, no edit to my original `response.md`, to `coordinator/draft.md`, to any peer file, to `coordinator/resolution.md`, to `RUN.md`, or to project code.
- **Original:** `members/minimax/response.md`, written in the initial pass and not modified since.

## Draft under review

- **File:** `docs/research/fullspread-se-prd-20261030-01a18660/coordinator/draft.md`
- **Revision:** `fullspread-se-prd-draft-r1`, dated 2026-10-30.
- **Supplied SHA-256:** `6c9d4a741bf96f5e5d1fe238459962e51568d2836e3838077c5afa1e8ff8a946`. This is **supplied provenance**, not an attestation I produced; I did not recompute it and make no claim about it.
- **Structure reviewed:** §1 goal and deltas (FS-X01…FS-X03); §2 inherited authority and §2.1 inherited IDs; §2.2 coordinator dispositions; §3 facets (FS-FACET-01, FS-FACET-02); §4 files and package (FS-ARCH-01, FS-PKG-01, FS-PKG-02); §5 money, callback and unlocked entry (FS-MONEY-01, FS-UNLOCK-01, FS-UNLOCK-02); §6 rate, quote and issuance (FS-RATE-01); §7 hook integration (FS-HOOK-01…FS-HOOK-04); §8 testing (FS-TEST-01…FS-TEST-03, FS-A01…FS-A30); §9 non-goals; §10 participation.
- **Read scope in this pass:** the frozen draft, my own original response, and the repository sources named in §3 below. I did not read any peer original, peer feedback, the resolution, or `RUN.md`.

## Disposition

**SUPPORT WITH CORRECTIONS.**

The draft is close to implementable and, on the central architectural questions, better than my original in several places: it keeps the canonical `exchangeIn` selector instead of inventing `exchangeInUnlocked`, it scopes the borrowed unlock to the one route the current hooks actually call, it asserts delta closure **per address** rather than by the manager's global counter, and it refuses to substitute the sibling provider's whole-book formula for a one-share rate.

Thirteen corrections are listed below. **C1, C2 and C3 are blocking** for the hook-integration rows: as written, FS-UNLOCK-02 would reject the hook's own outflow leg, and an implementer copying the PairToken settlement code would hit `SettlementMismatch` on every borrowed-unlock call. **C4, C5, C6 and C7 are blocking for specific acceptance rows** (FS-A24, FS-A26/FS-A27, FS-HOOK-01's `orbital/` row, FS-A29). **C8–C13 are non-blocking but should land before publication** because they change either a declared interface set, a units convention, or a harness requirement.

I withdraw my `RateFacet` proposal on the merits (see D1), and I withdraw two of my four open-owner-decision recommendations (see D2, D4).

## Material corrections

### C1 — FS-UNLOCK-02 steps 2 and 3 reject the hook's own outflow leg (blocking for FS-A25)

**Requirement:** FS-UNLOCK-02, step 2 ("`recipient == msg.sender` … Otherwise revert `InvalidUnlockedContext`") and step 3 ("The caller pays the input and receives the output").

**Evidence.** The current buffer hooks call the bound SE's exact-input route with a **third-party recipient** on the outflow leg:

- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:737` — `_unwrapSeShares` calls `IStandardExchangeIn(se).exchangeIn(IERC20(se), seIn, IERC20(t), minOut, to, false, block.timestamp)`, where `to` is the caller's chosen recipient, not the hook.
- Its call sites pass an end-user address: `…CurveQuadStableBufferHookExitTarget.sol:199`, `…CurveQuadStableBufferHookLiquidityTarget.sol:603, 683, 907, 1100`, `…CurveQuadStableBufferHookHooksTarget.sol:321`.
- Same shape in the weighted family: `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:384`.

`msg.sender` at the vault is the hook; `recipient` is the end user. The rule as written therefore rejects the outflow leg of every buffered hook that pays a user.

**Correction.** Replace the recipient-identity restriction with a funding-and-authority restriction, keeping everything the draft already got right:

1. The input is funded by the caller (`pretransferred == false`, `msg.value == 0`, the caller approves and pays).
2. A share exit burns **only the caller's own shares**; no third party's shares, and no vault-held credit from another caller.
3. The output may be delivered to a **caller-designated recipient** that is not the vault, not the caller, and not address(0).
4. The vault never accepts a foreign payer, a foreign creditor, or a caller-supplied callback payload on this path (draft step 3, retained).

The inflow leg already satisfies the tighter rule (`recipient == address(this)` == `msg.sender`, at `…CurveQuadStableBufferHookTarget.sol:707` and `…ClaimLib.sol:402`), which is why a naive reading of the current tests could pass while the outflow leg fails. Add an acceptance row: the hook's exact-in outflow to a **third-party recipient** succeeds while the manager is unlocked, and the vault's own deltas close.

### C2 — FS-UNLOCK-02 step 4 contradicts step 6 on the settlement assertion (blocking)

**Requirement:** FS-UNLOCK-02, step 4 ("Run the same planner and the same settlement code as the locked path") versus step 6 ("Do not require the manager's global nonzero-delta count to be zero").

**Evidence.** The locked path's settlement code ends with a **global** assertion: `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol`, in `unlockCallback`, ends with `if (TransientStateLibrary.getNonzeroDeltaCount(call.beforeState.config.poolManager) != 0) { revert SettlementMismatch(); }`. `getNonzeroDeltaCount` reads the manager-wide `NonzeroDeltaCount` transient slot (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol`). Inside an outer unlock the hook and the router legitimately hold open deltas, so copying that assertion verbatim makes **every** borrowed-unlock call revert `SettlementMismatch`.

**Correction.** State explicitly that the borrowed path reuses the same **settlement helpers** (the canonical sync → transfer → settle / take sequence and the family's own zero-delta bookkeeping) but **replaces** the global assertion with the per-address assertion the draft already specifies in step 6, `currencyDelta(manager, vault, currency) == 0` for each currency the call touched. The locked path keeps the global assertion, because there the family is the only actor in its own unlock.

### C3 — FS-UNLOCK-02 omits the shared transient `CurrencyReserves` hazard (blocking)

**Requirement:** FS-UNLOCK-02, steps 4 and 6 (settlement inside a borrowed unlock).

**Evidence.** The manager's sync/settle bookkeeping is **global, not per actor**:

- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/CurrencyReserves.sol` — `CURRENCY_SLOT` and `RESERVES_OF_SLOT` are single transient slots (`tstore`/`tload`), and `syncCurrencyAndReserves` overwrites both.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:228-237` — `sync(currency)` overwrites those slots with the manager's current balance of that currency.
- `PoolManager.sol:299-317` — `_settle` reads the synced currency and `reservesBefore`, computes `paid = reservesNow - reservesBefore`, credits the recipient, and calls `CurrencyReserves.resetCurrency()` on the ERC-20 branch.

So the family's `sync`/`settle` inside the outer unlock can overwrite an outer actor's outstanding sync for the same currency, and the family's own `settle()` clears the currency slot the outer actor may have been relying on.

**Correction.** Require, and test, that the borrowed path:

1. performs its `sync(currency)` → transfer → `settle()` atomically inside its own call, with no interleaved foreign transfer of that currency;
2. never calls `settleFor` for another address;
3. **reverts** rather than proceeds when the manager's synced-currency slot shows an outstanding foreign sync for a currency the family is about to sync (the family can read `CurrencyReserves.getSyncedCurrency()` before its own `sync`), rather than silently corrupting the outer actor's settlement;
4. resets the native sync immediately before any native value settlement, extending the inherited S1-NATIVE-01 rule to this path.

Note that the draft's step 6 ("Do not settle the hook's or the router's deltas") is correct but incomplete: not settling them is necessary, and not clobbering their sync state is also necessary.

### C4 — FS-A24's identity configuration is rejected at hook init in five families (blocking for FS-A24)

**Requirement:** FS-HOOK-02 ("Identity: the pool token is this vault's share …") and FS-A24.

**Evidence.** The SE-leg binding is created by `UniswapV4SeBufferHookLegLib.addPairSe(pair, se)`, which reverts `PairSeOverlap(pair, se)` when `pair == se` unless `isWrapperShareInventory(pair, se)` — and that exception requires the SE to answer selector `0x38d52e0f` with a different, non-zero underlying address (`contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol`). A fullSpread vault does not implement `asset()`, so the exception does not apply. `addPairSe` is called by:

- `stable/quad/curve/…CurveQuadStableBufferHookRepo.sol:105`
- `constantProduct/single/…SingleStandardExchangeBufferConstantProductHookRepo.sol:86`
- `weighted/…WeightedBufferHookRepo.sol:112`
- `orbital/…OrbitalBufferHookRepo.sol:133`
- `dual/…DualStandardExchangeBufferConstantProductHookRepo.sol:92-93`

The draft is right that the identity route does not call the vault's zap — the hook short-circuits it (`if (se == t) return amount;` in `…CurveQuadStableBufferHookTarget.sol:701`, and the mirror branch in `_unwrapSeShares`). But that branch is unreachable for a plain fullSpread vault in those five families.

**Correction.** Scope FS-A24 to the families that bind SE legs without `addPairSe` — the balancer-quad family stores `standardExchanges` directly (`stable/quad/balancer/…BalancerQuadStableBufferHookRepo.sol:40, 85`) — and record `PairSeOverlap(pair, se)` as the **cited validation reject** under FS-HOOK-04 for the other five, with the implementing function named.

### C5 — FS-HOOK-02's "even if they share a currency" is not achievable for two buffered legs (blocking for FS-A26/FS-A27)

**Requirement:** FS-HOOK-02 ("The primary cross-vault proof uses two vaults with different backing pool keys, even if they share a currency and the same manager") and FS-A26.

**Evidence.** `addPairSe` writes `standardExchangeOf[pair] = se` and `pairTokens._add(pair)`, and `classify(addr)` returns `LegKind.Pair` for any address present in `pairTokens` (`UniswapV4SeBufferHookLegLib.sol`). Binding two SE vaults whose buffered legs use the **same pair token** therefore overwrites `standardExchangeOf[pair]` and makes that token classify as a pair token rather than an SE leg. The guard that does exist is one-to-many in the wrong direction: `pairOfStandardExchange[se]` may hold only one pair (`SeAlreadyBound`), and `standardExchanges._contains(pair)` / `pairTokens._contains(se)` forbid a pair token that is itself an SE address.

**Correction.** State the precondition explicitly: in the multi-leg families the two-vault proof must use **two distinct buffered-leg pair tokens** (for example, two different `rateAsset` faces), or one leg must be a raw leg. "Share a currency" is acceptable only where the shared currency is not the bound pair token of both legs. Add the precondition to FS-A26 and FS-A27.

### C6 — FS-HOOK-01's `orbital/` row names accessors that do not exist (blocking for that row)

**Requirement:** FS-HOOK-01, `orbital/` row ("`se0/1/2` and `rp0/1/2`").

**Evidence.** `contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol` exposes `standardExchange(uint8 i)`, `rateProvider(uint8 i)`, `rateProviders()`, `rateProvider(address token)`, `isBuffered(uint8 i)`, `token0()`, `token1()`, `token2()`. There is no `se0/1/2` and no `rp0/1/2`.

**Correction.** Replace that row with the actual accessors. I verified the other six rows against source and they are correct: `single/` → `standardExchange`, `pairToken` (`…IUniswapV4SingleStandardExchangeBufferHook.sol`); `constantProduct/single/` → `standardExchange`, `pairToken`, `rawToken` (`…IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol`); `dual/` → `standardExchange0/1`, `token0/1` (`…IUniswapV4DualStandardExchangeBufferConstantProductHook.sol:79-82`); `weighted/` → `standardExchanges`, `rateProviders` (`…WeightedBufferHookRepo.sol:45`); `stable/quad/curve/` → fixed four legs (`…CurveQuadStableBufferHookRepo.sol:27`, `N_TOKENS = 4`); `stable/quad/balancer/` → dynamic length (`…BalancerQuadStableBufferHookRepo.sol:20`, `MIN_TOKENS = 2`).

### C7 — FS-RATE-01's low-supply revert has an unstated hook consequence, and FS-A29 does not cover it (blocking for FS-A29)

**Requirement:** FS-RATE-01 ("If total supply is below `1e18`, including zero supply, revert `InsufficientRateSupply(available, required)`") and FS-A29.

**Evidence.** The hook's provider read fails closed on any revert or zero: `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol`, `rateAfterExchange` — `if (!ok || data.length != 32) revert RateProviderFailed(); … if (rate == 0) revert RateProviderFailed();`. The existing production provider deliberately publishes a **non-zero** rate at zero supply by inverting a unit target deposit (`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`, `_initialRate`, with the comment "Hooks bind fresh SEs and read the rate on the first buffer, so invert a unit target deposit … instead of publishing 0"), and FS-RATE-01 forbids this family from doing that.

**Correction.** State the consequence rather than leaving it implicit: a buffered fullSpread leg whose total supply is below `1e18` makes the hook's first buffer fail with `RateProviderFailed`. Add an acceptance row for that failure, and record the initial-rate behaviour as a **separate requirement** if the owner wants a fresh fullSpread leg to be bindable — not as an implicit fallback inside this family, and not by reverting to the sibling provider's whole-book formula.

### C8 — FS-FACET-01: the query facet's declared interface set must gain `IRateProvider`, and the stated reason for refusing a thirteenth facet is not sound (non-blocking, but must land)

**Requirement:** FS-FACET-01 ("`getRate()` is the only new package-owned selector. It lives on `queryFacet`. Do not add a thirteenth facet.").

**Evidence.** The exemplar's query facet declares exactly one interface — `ids_[0] = type(IVault).interfaceId` (`…PairTokenStandardExchangeVaultQueryFacet.sol`) — and the package's declared interface aggregate is built from `facet_.facetInterfaces()` inside `_appendComponent` (`…PairTokenStandardExchangeVaultDFPkg.sol`). That aggregate is what `vaultTypes()` and `vaultDeclaration()` return (`contracts/interfaces/IStandardVaultPkg.sol`). A fullSpread query facet that implements `getRate()` and does not also declare `type(IRateProvider).interfaceId` would carry a selector with no advertised interface.

**Correction (a).** Require the fullSpread query facet to declare `type(IRateProvider).interfaceId` in addition to `type(IVault).interfaceId`, and state the registry-facing consequence: `vaultTypes()` and `vaultDeclaration()` now advertise `IRateProvider` for this family. `contentsId` is unaffected — it hashes the address-sorted currency faces (S1-ARCH-05). Add an acceptance row that the live proxy answers `supportsInterface(type(IRateProvider).interfaceId)` and that `vaultTypes()` contains it.

**Correction (b) — the stated reason is technically wrong.** The draft justifies refusing a thirteenth facet with "a separate facet would change `bindingHash` order without a selector the query facet cannot carry". The `bindingHash` changes **either way**: the query facet's own creation code changes when it carries `getRate()`, and its CREATE3 address is derived from that creation code, so `keccak256(abi.encode(init_))` changes in both designs. The real trade-off is the number of package inputs and one fewer CREATE3 deployment, not the hash. Recording this so the disposition is not later read as "the binding hash is preserved" — which would be false.

### C9 — §6 leaves two "rates" on one proxy with a `10^(18-d)` factor between them (non-blocking, must land)

**Requirement:** §6 table and FS-RATE-01.

**Evidence.** S1-QUOTE-02 defines the SY `exchangeRate()` as **raw rate-asset units per 1e18 raw share units** — the worked example in S1-QUOTE-02 gives `1e6` for a 1:1 whole-token/whole-share with a six-decimal rate asset. The draft's `getRate = floor(E * 1e18 / 10^d)` yields **1e18** for the same situation: an 18-decimal fixed-point number, which is the convention documented for the interface — "Returns an 18 decimal fixed point number that is the exchange rate of the token to some other underlying token" (`lib/crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol`) — and the scale produced by the sibling provider's `_normalise` (`StandardExchangeRateProviderFacet.sol`: for a six-decimal target, `mulDiv(out, 10^(36-6), shares)` returns `1e18` for the same 1:1 case).

**Correction.** Pin the units on the interface and in the §6 table: `getRate()` is an **18-decimal fixed-point** figure where `1e18` means one whole `rateAsset` per whole share; `exchangeRate()` is **raw `rateAsset` units per 1e18 raw shares**. State that the two differ by `10^(18 - d)` for a `d`-decimal rate asset and are **not** interchangeable, and extend FS-A12 to assert the exact relation rather than only that they differ. Note in the same place that the sibling provider rounds its normalisation **up** (`_normalise(..., Math.Rounding.Ceil)`) while this family rounds **down**; the draft's direction is a deliberate choice and should be labelled as a divergence from the sibling, since `IRateProvider`'s own NatSpec warns that "the caller might require a certain rounding direction".

### C10 — FS-TEST-01 picks a manager-deployment path without reconciling the two "current harness" patterns (non-blocking, must land)

**Requirement:** FS-TEST-01 ("Deploy a real `PoolManager` with `new PoolManager(address(this))` after `CraneTest.setUp()`") and the instruction to "Follow the current harness".

**Evidence.** Two current patterns exist:

- the PairToken family base deploys the manager through CREATE3 with artifact creation code — `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol`: `create3Factory.create3WithArgs(ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"), abi.encode(address(this)), keccak256(abi.encode("PairToken.Test.PoolManager")))`;
- the hook test bases use `new PoolManager(address(this))` — `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol:143` and `.../dual/TestBase_UniswapV4DualSEBCPHook.sol:94`.

`new PoolManager(...)` is **not** prohibited here: it is neither a facet nor a DFPkg, so `CLAUDE.md` item 2 and `.github/ASSISTANT_CODING.md` (which target production facet/package instantiation) do not bite. This is a consistency requirement, not a prohibition.

**Correction.** Name which path this family uses and require the family base and the hook base to share **one** manager instance. The whole borrowed-unlock scenario is about the family's backing pool and the hook's consuming pool being on the same manager; two different manager instances would make every hook row vacuous. Also require the pool-key identity of the family's backing pool to be the hookless `hooks == address(0)` key the draft already states.

### C11 — FS-PKG-02 / FS-RATE-01: the new family errors are not required to be declared (non-blocking, must land)

**Requirement:** FS-UNLOCK-02 (new error `InvalidUnlockedContext`), FS-RATE-01 (new errors `RateNormalizationOverflow`, `RateUnavailable`, `InsufficientRateSupply`), and S1-OBS-01.

**Evidence.** S1-OBS-01 requires family errors to be declared on the family interface with the canonical `@custom:signature` / `@custom:selector` tags and to be derived through the repository's verification workflow. The draft names these errors in requirements but never requires them to be declared or pinned.

**Correction.** Require `InsufficientRateSupply(uint256 available, uint256 required)`, `InvalidUnlockedContext()`, `RateUnavailable()`, `RateNormalizationOverflow()` and `SettlementMismatch` to be declared on the family interface with the canonical tags, and to be covered by the interface/selector verification step. Keep the draft's rule that no hex is written in the PRD — compute them later.

### C12 — FS-ARCH-01 leaves the harness paths conditional (non-blocking, must land)

**Requirement:** FS-ARCH-01 ("with the TestBase beside the family only if that is the current PairToken harness pattern. Follow the current harness").

**Evidence.** The condition is already answered by the source: the exemplar places `test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol` and `test/behaviors/Behavior_UniswapV4PairTokenStandardExchangeVaultPackage.sol` under `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/`.

**Correction.** Name the two paths outright rather than leaving a condition the source has already resolved.

### C13 — FS-A27's cited-reject escape should extend to FS-A24 and FS-A25 (non-blocking, must land)

**Requirement:** FS-A27, FS-A24, FS-A25.

**Evidence.** FS-A27 already allows "the row records the cited validation reject under FS-HOOK-04", with the discipline "A skipped row, `assertTrue(true)`, or a success flag alone does not close FS-A27." FS-A24 and FS-A25 carry no such clause, but per C4 and C5 some families will legitimately be unable to run the identity configuration or two legs sharing a pair token.

**Correction.** Give FS-A24 and FS-A25 the same escape clause and the same anti-self-certification discipline as FS-A27, so those families record their cited rejection rather than being recorded as passed or silently dropped.

## Dispositions of proposals the draft did not adopt

### D1 — MiniMax: a thirteenth `RateFacet` (`response.md` FS-FACET-03) — **withdrawn**

I withdraw this on the merits. One selector does not need its own cut, and keeping `PkgInit` at the exemplar's twelve fields avoids a thirteenth CREATE3 deployment and keeps the inherited `PkgInit` shape intact, which the draft's §2 inherited-authority table depends on. The substantive worry behind it — that a price authority and a discovery surface should not share a cut — is not worth a cut of its own for a single function. What survives is C8: the facet's declared interface set must include `IRateProvider`, the registry-facing advertisement must be stated and tested, and the units must be pinned (C9).

### D2 — MiniMax FS-OPEN-03: normalize `getRate` by the actual total supply when supply is below one whole share — **not adopted; I now agree with the draft**

The draft's `InsufficientRateSupply` fail-closed stance is better than my recommendation. The one-share exit is nonlinear in size, so scaling a smaller redemption up to `1e18` shares is an extrapolation the draft correctly forbids ("Do not scale a smaller redemption"); and a zero or extrapolated rate is exactly the value a downstream consumer can misread as a price. I withdraw my earlier `response.md` FS-A78 ("`getRate()` at zero supply returns `0`") and my FS-RATE-05c note about a zero-supply asymmetry. The residual consequence is a liveness gap, which C7 records.

### D3 — MiniMax FS-OPEN-01: no integrator allowlist in `PkgArgs` — **the draft's choice matches mine**

The draft reaches the same conclusion by the same reasoning (an allowlist in the vault's `PkgArgs` is circular with the hook binding). No change needed. The draft's *additional* narrowing of the borrowed path (no `pretransferred`, no `msg.value`, caller-funded input, caller-share-only burn) is an improvement on my original position and I support it — subject to C1, which repairs the one part of the narrowing that is incompatible with the current hooks.

### D4 — MiniMax FS-OPEN-04: do not install the optional transition-quote surfaces — **the draft adopts this; supported**

The draft states it explicitly in §2.1 ("`IStandardExchangeTransitionQuote`, `IStandardExchangeExternalQuote`, and `IStandardExchangeRateQuote` are out of this PRD unless a cited hook path rejects without one"). My `response.md` FS-OPEN-04 recommended the same. No change needed.

### D5 — Grok: omit `getRate` — **I disagree; the draft is right to keep it**

D60 requires a rate provider for any buffered leg, and the only production provider prices the **whole book** through `previewExchangeIn(seShare, totalSupply, rateTarget)` — a quantity that is frequently unsellable for a fullSpread vault and that the sibling provider itself calls out ("Price the entire book even when settlement cannot physically exit it"). Keeping an executable, per-share, fail-closed `getRate()` on the family is what makes a compliant provider possible at all. Without it, the only compliant path is the whole-book provider, which fails closed on exactly the vault shape this family is.

### D6 — Grok: also unlock `compound`, `donate` and the paired methods — **I agree with the draft's narrower scope, against Grok**

My own `response.md` FS-CB-04 proposed the same restriction (exact-input SE route only), for the same reason the draft gives: the current hooks do not call those methods during `beforeSwap`, and widening the borrowed path adds surface for no requested benefit. The draft's §2.2 record of this dissent is appropriate and should survive into the resolution.

### D7 — Kimi: return zero below one share — **I now agree with the draft's revert, against Kimi**

Same reasoning as D2, and stronger than my own earlier position: a zero rate is not neutral, it is a price a consumer can multiply by. The draft's `InsufficientRateSupply(available, required)` carries the diagnostic that a zero cannot.

## Limits

1. **Advisory only, one pass.** I read the frozen draft, my own original response, and the repository sources named in C1–C13. I did not read any peer original, any peer feedback, `coordinator/resolution.md`, or `RUN.md`, and I did not recompute the supplied SHA-256 — that hash is supplied provenance, not an attestation I produced.
2. **No execution.** No Forge, build, test, script, install, deploy, or Git command was run in this pass. Every correction cites a repository file and function read in this session; I confirm what the source says, not what the draft's behaviour claims will be. I make no claim that any row passes, that anything compiles, or that any gas figure holds.
3. **Line citations** are given where I confirmed them from tool output, and by function name elsewhere. Where I cite a line range that I read rather than grepped, I cite the function name as the anchor.
4. **Scope of the hook-family analysis.** I verified the binding accessors and the SE-call sites for the seven families named in FS-HOOK-01. I did not audit the hooks' internal accounting, their fee model, or their `kLast` behaviour, and I make no claim about them.
5. **The corrections are scoped to the draft.** I do not re-open the inherited PairToken economics, the PairToken stage-one acceptance matrix, or the owner decisions the draft inherits; where the draft and the stage-one PRD disagree on an inherited ID, the stage-one PRD controls, as the draft states.
6. **This is not an audit.** No security review, gas measurement, fork run, or compile check backs any statement in this file. The blocking labels (C1, C2, C3, C4, C5, C6, C7) describe where the draft contradicts the cited source or leaves a row unsatisfiable; they are not severity ratings.
7. **No implementation authorization is implied.** Nothing in this file authorizes implementation, a hook edit, a registry migration, or a deployment.
