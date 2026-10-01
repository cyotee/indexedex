# Kimi K3 — Cross-review (one combined pass): static-fee policy

**Date/access date:** 2026-09-27 · **Researcher:** Kimi K3 · Peer originals read as untrusted evidence: Astra, Grok, MiniMax M3 (same directory). No cross-review artifacts read. My original (`kimi-original.md`) preserved unchanged. Every load-bearing claim re-verified against local code and the **current** PRD revision.

## 0. Load-bearing context change (verified, affects everyone)

The PRD was revised again before/during this round. Current `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:44-48`:
- **D17–D19:** the combined exact-output-plus-rebalance route is **unsupported in this release by owner decision**; attempts must revert `InvalidRoute`; previews reject; no solver/inverse/maintenance-omission fallback. Astra's "Z" citation is accurate (verified).
- **D20:** 25/50/10 bp protections are now **owner-approved requirements**, 1 bp alignment bound stands (no longer provisional).
- **D21:** maintenance proportionality target = the position's token requirements at the **current pool price** via exact finite-range math; sufficient = ≤1 bp normalized composition mismatch; **prefer placement without swaps when sufficient**; stop when both thresholds pass.
Consequences: static-only admission is a deployment-compatibility proposal (the current decision table does **not** state it — Astra's framing verified); it does **not** restore or enable any combined route; hook-model gating's remaining role this release is quote honesty and future route restoration (D18).

## 1. Verified claims (direct re-checks)

| Claim under dispute | Verdict | Evidence |
|---|---|---|
| Existing quoter includes protocol fee | **TRUE** | `UniswapV4Quoter._loadQuotePool` (`lib/crane/.../v4/utils/UniswapV4Quoter.sol:205-211`): reads slot0 `protocolFees`, selects direction (`getZeroForOneFee`/`getOneForZeroFee`), sets `ctx.lpFee = calculateSwapFee(protocolFee, lpFee)`. `_creditInsideFees` (:214-226) subtracts the protocol portion from simulated fee growth. All V4FS quote paths route through this quoter. |
| Static-fee pools can still carry amount-altering hook deltas | **TRUE** | `Hooks.sol:268-281` (beforeSwap specified-delta), `Hooks.sol:230-246` (add/remove liquidity return deltas), afterSwap deltas. None require dynamic fee. |
| `setProtocolFee` has no PoolManager-lock restriction | **TRUE** | `ProtocolFees.sol:34-40` — controller-only, no `onlyWhenUnlocked`. Changeable any time, incl. between preview and execution txs; `Pool.swap` snapshots slot0 at swap start (`Pool.sol:288-313`). |
| Deployment rejection is structural, not a whitelist | **TRUE** | `LPFeeLibrary.sol:16,31-33` exact-equality flag; D14 intact; fee dynamicness is on-chain-determinable (PRD §10). |
| Init-time pool existence not required by key validity | **TRUE** | Key fee immutable whether or not the pool exists; only the key can ever initialize the pool (fee is in the key ⇒ no fee spoofing window). Quoter/ops already revert on uninitialized (`UniswapV4Quoter.sol:168` requires `sqrtPriceX96 != 0`). |
| 100% static fee is core-valid but product-dead | **TRUE** | `MAX_LP_FEE = 1_000_000` = 100% (`LPFeeLibrary.sol:25-26`); exact-in consumed entirely as fee, exact-out reverts `InvalidFeeForExactOut` (`Pool.sol:315-321`). |
| Pons pools unaffected by dynamic rejection | **TRUE** | Pons fixture uses static fee 0 (`TestBase_UniswapV4StandardExchange_PonsV2.sol:66`); only IndexedEx Orbital/Weighted hook pools are dynamic (`.../weighted/UNISWAP_V4_WEIGHTED_SWAP_HOOK_PRD.md` D68) and become unbindable. |
| Protocol/LP split at accrual | **TRUE** | `Pool.sol:389-413`: protocol share `(amountIn+feeAmount)·pf/1e6` (rounds down, "favor LPs") removed before `feeGrowthGlobal` update — so actual LP accrual nets protocol fee; vault's `feeGrowthInside`-based accounting inherits this correctly. |

## 2. Corrections to peers

**MiniMax M3 (substantive):**
1. `MAX_LP_FEE = 1_000_000` is **100%**, not "1.0%" (§2.1 table; 100× error).
2. "Protocol fee invisible to FullSpread accounting / previews omit it / execution always pays it" — **wrong** for quote paths: the quoter composes directional protocol fee into every quote (§1 row 1), contradicting his own §2.3. True remnants: no `MAX_PROTOCOL_FEE` check in the vault package (PoolManager enforces validity at set, `ProtocolFees.sol:36`), and `_slot0()`'s protocolFee/lpFee destructure is unused for *position* math (which needs neither). His §6 table's "preview omits" row should read: previews via the quoter already include it.
3. Pons `afterSwap` delta is **modeled exactly** (two floored bps cuts on the unspecified leg — verified against `PonsV2MemeHook.sol:495-504` matching `QuoteService.sol:50-58`), not an unmodelled "band"; for validated launches, preview == execution modulo replicated integer floors.
4. His deploy-time hook-decode (R-2) is now moot for its stated purpose (combined route release-unsupported, D17); keep modeled-hook gating for quote honesty only.
5. His `_fee()`-unused grep finding is **correct and useful** (no runtime consumer of `poolKey.fee` in the package today) — see my correction #4.

**Grok (minor):**
1. `UniswapV4Utils.sol:17` comment ("protocol takes from lpFee") — misleading as a charging model; verified. Also note `:18` — that library is single-tick-only and unsuitable for multi-step quotes regardless. Skill `uniswap-v4-fees` v0.1.0 has the same flaw (Astra §5; verified — its "percentage of the LP fee" diagram and `getStaticFee` sketch do not match `LPFeeLibrary`/`ProtocolFeeLibrary`). Documentation errata recorded; no edits.
2. His conditional initialized-check ("if the pool already exists") plus Astra's don't-prohibit-deploy-before-init is the correct final form (my correction #2).

**Astra (minor):** no substantive errors found; her fee arithmetic (f=3000, h=1000 → 3997 pips) recomputes correctly; her 100%-fee recommendation is the best-reasoned option on record (see §4).

## 3. Corrections to my own original

1. **Stale PRD basis.** I wrote against the pre-D17 revision. Re-scoped per §0: combined routes revert `InvalidRoute` for **all** pools this release regardless of fee/hook model; my "unmodelled-hook ⇒ combined InvalidRoute" framing is subsumed. Static-only admission changes deployment compatibility only.
2. **R3 downgraded.** My "require initialized pool + `slot0.lpFee == key.fee` at deploy" is too strong (Astra's objection verified): deploying before pool initialization is inert, not unsafe; the key's fee can never be spoofed at later initialization. Final form: enforce static-identity at deploy (flag + range); verify fee equality when initialized (non-canonical-manager sanity); enforce initialization at *use* (already inherent).
3. **100% boundary.** My "flag, don't invent a cap" is refined by Astra's proposal, which I now adopt as the recommendation: deterministic, separately named rejection of `fee == MAX_LP_FEE` recorded as a *product restriction* (not an encoding error), no arbitrary lower ceiling, and never divide by `(1e6 − fee)` at zero — with "accept and let routes truthfully fail" presented as the rejected alternative (MiniMax's accept-at-max test embodies it).
4. **Nuance on "models only key.fee misprices".** Existing quote paths already source fees correctly (quoter, live slot0, directional, combined — §1 row 1) and `poolKey.fee` currently has **no runtime consumer** (MiniMax's grep, consistent with my reads). The mispricing risk is forward-looking: any new closed-form/solver math must source fee exactly as the quoter does (never `_fee()` alone, never cached protocol fee). My R4 stands with this sharper target.

## 4. Consensus, dissent, and the minimum safe answer

**Legitimate consensus (all four, verified):** fee readable (immutable key + live slot0); no rejection exists today (`DFPkg.initAccount:271-298` stores verbatim; `processArgs:257-265` checks only TWAP/PoolManager binding); exact-equality dynamic check at deployment is deterministic, D14-compatible, not hook admission; static LP fee immutable for pool lifetime; protocol fee directional (12+12 bits, ≤1000 pips), controller-mutable without lock, charged to the swapper combined (`calculateSwapFee`), must be read live; static fee ≠ static total cost (hook deltas/callbacks possible on static pools → deployer assurance + measured fills + honest quote labeling); quoter already documents dynamic-pool limitation (`UniswapV4Quoter.sol:17,99-111`).

**Residual dissent:** (a) 100%-fee handling — Astra/me: separately named product rejection; MiniMax: accept at max. Owner-visible choice; recommendation: reject. (b) Deploy-time pool-initialization requirement — resolved to conditional (my correction #2). (c) MiniMax's protocol-fee-invisibility claims — corrected, not dissent (§2).

**Minimum safe answer to the human (policy proposal, not PRD change):**
> New FullSpread V4 instances accept only valid static-LP-fee PoolKeys: revert at instance creation when `poolKey.fee == LPFeeLibrary.DYNAMIC_FEE_FLAG` (exact equality) and validate `fee ≤ MAX_LP_FEE` without stripping flag bits (reject malformed encodings like `0x800000|3000`; reject `fee == 1_000_000` under a separately named product-restriction error, pending owner confirmation). Calculations source fees exactly as the existing quoter does: live slot0 LP fee (identical to `key.fee` on static pools) combined with the **live, direction-specific** protocol fee via `ProtocolFeeLibrary.calculateSwapFee`; protocol fee is never cached or deploy-frozen. Static-only admission certifies nothing about hook deltas or callbacks; deployer hook assurance (D14), measured-fill settlement, the D20 protections (25/50/10/1 bp, owner-approved), and no-vanilla-quote-as-exact for unmodeled hooks are unchanged. This policy does not restore the release-unsupported combined exact-output-plus-rebalance route (D17–D19); `InvalidRoute` applies to it regardless of fee model.

**Confidence:** high on all verified mechanics and on the peer corrections (each re-checked against code 2026-09-27; Context7 `/uniswap/v4-core` consistent, non-pinning). **Gaps:** no chain queries (deployed-instance fee bindings unverified); upstream `main` is not a deployment pin; 100%-fee rejection awaits owner confirmation as the single open product choice.
