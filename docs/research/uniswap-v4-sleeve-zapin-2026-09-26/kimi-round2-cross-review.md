# Kimi K3 — Round 2 cross-review (2026-09-26)

Reviews the three round-2 ORIGINALS (astra/grok/minimax) as untrusted evidence. My round-2 original is preserved; revisions are labeled. Code re-verified directly: `UniswapV4StandardExchangeCommon.sol:626-648, 685-713, 734-739, 996-999, 1260-1297`, `UniswapV4StandardExchangeInBase.sol:154-167, 273-315`. No tests/shell/code edits.

## 1. Converged answers (all four, or three-plus-verified)

1. **Fixed point:** `F*_i = p/(1+p)·T_i`, `D*_i = T_i/(1+p)`, computed **once** per token, then place once. Freezing `p·D_pre` chases itself (deploying raises D and the target) — Grok's "naive chase" example and MiniMax's self-corrected §3.3 both confirm; my round-2 agreed. MiniMax's botched first numerical pass (its own lines 84-85) is exactly the failure mode the fixed point avoids; its self-correction lands on the same formula.
2. **Endpoints:** stored `0` = oracle fallthrough, not explicit 0% (D8; Grok cites `VaultFeeOracleQueryFacet.sol:322-330` — unverified by me, consistent with D8 law); resolved `p=0` ⇒ `F*=0`; `p=1` ⇒ `F*=T/2` — **100%-sleeve is inexpressible** and the draft's 100%-liquid exception must be removed (Astra §2; Grok table; I agree). Deadband constants unchanged, applied to the smaller `F*` (≈0.83% of T per token at p=0.2; Astra/MiniMax/me agree; do not widen tests).
3. **Owner's 20%-of-deployed is literal — I retract my round-2 O1** (I had recommended re-anchoring to 0.25e18 to preserve cover). Grok is right: keep the stored number, reinterpret locally for V4 SE placement only, no global oracle change, no new field, no silent re-store. Factual disclosure only: blocked cover per token drops from 20% to 16.67% of total; existing deployed instances/settings change meaning without any storage write — requires an explicit owner/release acknowledgment (MiniMax R-3d, Astra §2 "old instances require explicit treatment").
4. **Fees:** `D` = principal only. Idle path collects preexisting fees before planning (`_collectManagedFeesIfIdle`, existing pattern `InBase.sol:281`), so E→F exactly once; E is **never spendable cover** — verified: blocked payout already checks raw `balanceOf` (`InBase.sol:157`), and share math includes E via `_freeBalancesForShareMath` (`Common.sol:626-631`, comment at 646-647 "fees belong to all outstanding shares"). My round-2 said "fees stay in F" — imprecise; Astra's three-way split (D principal / spendable F / E disclosed-but-not-cover, collapsed by collect-on-idle) is the correct statement and I adopt it.
5. **Issuance:** existing dual min-ratio branch `m = min(S·C0/B0, S·C1/B1)` (`Common.sol:700-704`) — no new NAV, no formula change. For a book-aligned basket (C = a·B) it is exactly proportional and equals the invariant-growth result `S·a` (MiniMax's observation is correct *only under alignment*; see §2.3 for its misuse). Invariant-growth stays on genuine single-sided paths (blocked route); it must not be generalized to composed dual inputs (Astra §4 line 62 — it would reduce incumbent per-token entitlement).

## 2. Corrections and my revisions

### 2.1 Pre-swap vs post-swap incumbent book — I revise to post-swap (Grok/Astra correct; MiniMax wrong)
My round-2 O3 recommended a call-start snapshot. Grok (step 4) and Astra (§3 step 3) convinced me otherwise, with a concrete reason: the caller's swap moves the pool price **against the vault's own full-range position**, changing incumbent `D` composition and accruing self-LP fees endogenously. Measuring B pre-swap makes the final conservation identity fail (`final book ≠ B + C`, difference = incumbent repricing + self-LP fees = an unmeasured transfer). The converged rule: **measure the total owned book at post-swap state, subtract the caller's measured basket C to obtain incumbent B.** Then (a) incumbent repricing and self-LP fees stay with incumbents exactly, (b) `B + C == actual final book` holds by construction, (c) the entitlement guarantee `S·(B_i+C_i)/(S+m) ≥ B_i` is checkable token-by-token. MiniMax R-4c ("`reserve_iBefore = F_pre + D_pre` immutable") bakes in the pre-swap snapshot — wrong for the same reason; "immutable incumbent" is only true if the incumbent doesn't LP the pool being traded, which is false here.

### 2.2 Caller basket C retains its sleeve portion — MiniMax's formula is a bug
MiniMax §3.2 (line 64): `amount_iAdded = deposited_i + swapped_i − sleeve_held_i` **subtracts** the sleeve-retained portion of the caller's own basket from their credited contribution. Wrong: the caller paid the full basket; the retained-sleeve portion is vault-owned book acquired from the caller and backs shares like any other free inventory. Under-crediting donates caller value to incumbents on every zap. Correct: **C = full post-swap basket (deployed + retained portions); placement is share-neutral** (D13 principle; Astra's "C is remaining credited input plus actual swap output, net actual costs" and Grok's `c` are both correct). Placement (free↔deployed split) must not enter issuance at all.

### 2.3 Ratio choice — the one real remaining issuance decision
- **Min-ratio is exact only for a book-aligned basket.** Astra's skew example (`B=(200,100)`, LP-aligned `C=(10,10)` ⇒ `m=5`, surplus token1 donated) and Grok's (`R=(130,100)`, `c=(5,5)` binds on token0) both demonstrate LP-aligned composition donates on a skewed book. **Reject LP-aligned as default** (Grok, me-round-2).
- **Book-aligned skew leaves material residue, not dust.** My round-2 called residue "harmless dust" — overstated. On `R=(200,100)` with book-aligned `C=(20,10)`, CL deployment binds on token1; the token0 excess above deployable is *material* and stays sleeve (issuance-neutral but deployment-incomplete), and book-aligned deposits never change the book ratio, so the skew persists until withdrawals/price moves/other flows correct it. Astra's horn is symmetric: LP-aligned deploys more but donates.
- **Honest infeasibility (converged, Astra line 64):** current-call-only swaps cannot simultaneously deliver neutral proportional issuance AND full deployment on a skewed book. Recommendation: **book-aligned default (zero redistribution without explicit owner acceptance), residue disclosed and measurable**; LP-aligned-with-disclosed-donation or a capped hybrid only by explicit owner choice. This is the single remaining issuance gate.

### 2.4 Other corrections
- **MiniMax "moderator PRD not present on disk" (its §7 gaps): false** — `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` exists; I read it this round. Local evidence gap, not absence.
- **MiniMax invariant-growth recommendation (R-4a "either is honest"):** misleading; the formulas coincide only for aligned baskets. Default must be the existing dual min-ratio branch; invariant-growth on skewed composed inputs redistributes incumbent entitlement (Astra §4).
- **Astra's pretransfer flag — verified TRUE in code.** `_secureTokenTransfer` (`Common.sol:1270-1289`) with `pretransferred=true` credits `amountIn ≤ U` where `U` = face unbooked balance (`B_face − (R − deployed)`); it does **not** prove the caller transferred it. A prior donation sitting unbooked can be captured as "pretransferred" principal by the next caller. Pre-existing surface (repo adversarial catalog I), but it directly threatens caller-basket isolation: the zap spec must either accept-and-test this (donation capture race) or tighten provenance. Not a blocker for the formula; a required adversarial test (ZA-6/ZA-10).
- **Astra `VaultFeeOracleRepo.sol:68-69` WAD-bounded validation** and Grok's `VaultFeeOracleQueryFacet.sol:322-330` fallthrough lines: unverified by me, consistent with D6/D8 law; low risk.

## 3. Converged specification (formula + conservation/snapshot conditions)

**Idle composed route (existing `exchangeIn`, mint-last):**
1. If idle: collect preexisting fees E→F (once).
2. Pull current-call input via existing measured-delta secure pull. Donations/pre-existing unbooked balances are never swap input (owner rule 2).
3. Swap only that tranche so the resulting basket `C` matches the **post-swap incumbent whole-book ratio** `B0:B1` (book-aligned default, §2.3). Bounded solver (precedent `Common.sol:182-200`), user `minCounterOut`/finite price limit; atomic revert on failure (ZR-4).
4. **Post-swap measurement:** `B = (post-swap D from CL math + spendable F) − C`, each asset once; self-LP fees and repricing remain in B.
5. Placement, add/remove only (D28): per-token `F*_i = p/(1+p)·T_i` on `T = B + C` (fixed, from this measurement), within deadband; placement is share-neutral and never changes `T`, B, or C. Residue on skewed books is expected and disclosed.
6. Mint `m = min(floor(S·C0/B0), floor(S·C1/B1))`; enforce `minSharesOut`. Conservation check: `B + C` == independently measured final book; entitlement `S·(B_i+C_i)/(S+m) ≥ B_i` per token.

**Blocked route:** unchanged (`_executeZapInDeposit` sleeve mint, no swap/unlock, raw-balance cover checks). **Bootstrap:** D59 unchanged. **Imports:** current full-range conversion. **Native:** WETH face, settlement-only unwrap. **Public rebalance:** add/remove-only toward the same `F*`; backlog unrepaired (owner rule 2).

## 4. Truly remaining owner choices

1. **Skew policy (only issuance gate left):** book-aligned + disclosed material residue (recommended) vs LP-aligned + disclosed donation vs capped hybrid.
2. **Release acknowledgment:** existing 0.20e18 settings silently change meaning (20% of deployed = 16.67% of total); confirm no re-anchor (owner already chose literal 20% deployed).
3. **Bounds source and supported-hook set / fail-closed behavior** (still open; no TWAP mandate from DETF law).
4. **Pretransfer provenance:** accept donation-capture race with adversarial tests, or tighten (implementation-level, must be decided before coding the zap path).

## 5. Dissent record

- **Astra vs Grok/me on default ratio:** Astra defaults LP-aligned + disclosed donation; Grok and I default book-aligned + partial deployment. Presented as owner choice 1 with my recommendation.
- **MiniMax pre-swap immutable snapshot and sleeve-subtraction:** rejected (§2.1, §2.2).
- All else converged. Confidence: high on §1, §2.1–2.3 (code-verified), §3; medium on solver bounds under manipulated quotes. Originals preserved; this is my only round-2 cross-review artifact.
