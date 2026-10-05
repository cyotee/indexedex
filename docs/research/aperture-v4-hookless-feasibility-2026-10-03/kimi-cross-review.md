# Kimi K3 — combined cross-review, Aperture feasibility round (sole)

**Date:** 2026-10-03. Inputs as untrusted attributed evidence: `astra-original.md`, `grok-replacement-original.md`, `minimax-original.md`. My original preserved. Local verifications this review: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol:37–40` (combined swap fee = `protocolFee + lpFee − protocolFee·lpFee/1e6`, rounded up — confirms Astra's citation and the quadratic's `f`); `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Utils.sol:54–60,105–113` ("In V4, amountSpecified is negative for exact input"; positive for exact output — confirms Grok's sign-flip catch). No new external fetches; pinned Aperture sources were fully read in my first pass.

## 1. The decisive conflict: polynomial degree — MiniMax's cubic/Abel-Ruffini claim is algebraically wrong

MiniMax (§2.3) asserts the whole-book alignment is **degree 3 in x with F>0**, **degree 4+ with E≠0**, **degree 5+ multi-position**, and invokes Abel-Ruffini non-solvability. Astra (§5), Grok (§5), and I (§4) each derived **degree 2**, with three independent coefficient sets. I rechecked the algebra in `x` (MiniMax's variable) rather than `t`, and the quadratic is exact:

Token0-in, continuous, combined fee `f`, `g = 1−f`, active `L`, incumbent `l`, `1/t = 1/s + g·x/L` (**1/t is linear in x** — the key fact):

```
C0 = c − x
C1 = y = L·g·x·s² / (L + g·x·s)
B0(x) = (F0′ + l(1/s − 1/u)) + [l(1+f)·g/L]·x          := β0 + μ0·x   (linear in x, F0′ = F0+E0ⁱⁿⁱᵗ)
B1(x) = (F1′ − l·w) + l·t             with t = L·s/(L + g·x·s)
```

Alignment `(c−x)·B1 = y·B0`: multiply through by `(L + g·x·s)`: LHS = `(c−x)·[(F1′−l·w)(L+g·x·s) + l·L·s]` — degree 2. RHS = `L·g·s²·x·(β0 + μ0·x)` — degree 2. **Quadratic in x**, matching the quadratic in `t` (the variables are Möbius-related, so solvability is equivalent: solve `t` in radicals, recover `x = L(s−t)/(g·s·t)`).

MiniMax's error is identifiable in its own text (:192): it substitutes `(p_T − p_lower) ≈ x·p_0²/(L + x(1−f)p_0)` — that is the form of `p_T − p_0` (displacement from *current* price), not `p_T − p_lower` (displacement from the *range bound*). `p_T − w = (L(s−w) − w·g·x·s)/(L+g·x·s)`, whose numerator is linear in `x` — no cubic arises. Its supporting intuitions are exactly backwards: **F terms are constants in x** (they cannot raise degree), and **own-LP fee accrual `(f−φ)·l·(1/t − 1/s)` is linear in `1/t`, hence linear in `x`** — E≠0 changes coefficients, not degree. Multi-position: out-of-range wings are `t`-independent constants; multiple active positions aggregate as `(Σl_k)/t` and `(Σl_k)·t` (Astra's fixed-active-set point) — same basis, still quadratic. Positions add **boundaries**, not degree. What genuinely breaks the closed form is what Astra and I said: integer staircases (per-step fee/Q128-growth/principal floors), boundary crossings (L and active-set changes), and placement rounding — **integer and segmentation issues, not polynomial degree**. Abel-Ruffini is a non-sequitur here; MiniMax's "Aperture's quadratic of claim 'solves zap-in for hookless' is false" overcorrects past the truth into a different error. Recorded as a correction with the derivation above as the checkable evidence.

With V4 protocol fee `φ` (hookless ≠ fee-free — verified `ProtocolFeeLibrary.sol:37–40`): the impact/gross-up uses combined `f`; the own-LP accrual coefficient uses `(f−φ)` (Astra's `η = (l/L)(f−φ)`; Grok's `ρ(1−φ)`). Degree preserved. Grok's self-flagged caveat (:78) about its `B′0 = B0 + ρx` is resolved: `ΔD0 = ρ·g·x`, `ΔE0 = ρ(f−φ)x`, so `ΔB0 = ρ(1−φ)x` — consistent with all three quadratic forms.

## 2. Other verified corrections and attributions

- **V3→V4 sign flip (Grok's catch, locally confirmed):** V3 positive exact-input `amountSpecified` vs V4 **negative** (`UniswapV4Utils.sol:54–60`). My port map omitted this; a literal port inverts the swap. Credited and adopted.
- **mintOptimal vs mintFromTokenIn (MiniMax's emphasis corrected):** MiniMax's "there is no autonomous single-token path" is true only of the *third-token* surface (`mintFromTokenIn`, caller-split swapData0/1). Our case — depositing a **pool** token — is `mintOptimal` with the other desired amount zero and empty `swapData`, which MiniMax's own text (:117) admits is autonomous (direct pool swap, on-chain sizing). Grok and Astra state this correctly; my original stated it correctly. No error of fact remains among the three; MiniMax's headline is misleading for the pool-token scalar case that matters here.
- **Return-numbers vs executed plan:** unanimous — `getOptimalSwap` returns `(amountIn, amountOut, zeroForOne, sqrtPriceX96)`; `Automan` executes swap+mint+refund. Aperture hands no plan to an external caller; our planner pattern (pure computation + separate execution) matches naturally.
- **Global sqrt limits (Grok, Astra):** `_poolSwap` uses `MIN/MAX_SQRT_RATIO ± 1` — Aperture has no per-call impact bound; our 50 bp price check and 10 bp shortfall must wrap the port (my original concurred; their evidence is the SwapRouter read I did not separately fetch — attributed).
- **Bitmap word-stepping and fee-floor inconsistencies (Astra's new cautions):** uni-v3-lib `nextInitializedTick` has its own uncapped word-scanning loop and skips word boundaries, while core steps at word boundaries too — step *partition* affects integer fee/amount rounding, so D30-exact preview parity requires walking core-compatible step targets, and upstream itself mixes floor vs round-up fee gross-ups between the boundary helper and the final amount calc. Both are acceptance-gate items; credited.
- **Unlocked view vs forbidden nested execution:** unanimous that the view is callable any time and execution needs an unlock, with `AlreadyUnlocked` on nesting. Precision note (against MiniMax :211's framing): V4 technically permits pool actions by any caller while *someone else's* session is open — the prohibition on using a foreign session is **our law** (PRD §4 sleeve-only), not a protocol revert; Astra frames it correctly as law (:178). Any change there is an owner decision, not an Aperture consequence.
- **License precision (correcting my own "no source porting" overstatement):** the pinned BUSL's change date (2026-07-01) has passed, so the work is now **GPL-2.0-or-later** — Astra is right that this is neither "MIT/permissive" nor a "perpetual production ban": copying is *permitted* under copyleft, which our BUSL-style tree cannot accept without counsel; equation-level reimplementation remains the practical path. Astra and MiniMax both report `uni-v3-lib` as GPL-2.0-or-later — my "likely GPL-3.0" guess is corrected (their attributed reads; I did not re-fetch).
- **Audit ≠ pinned commit (MiniMax's good evidence point):** the Narya.ai audit (May 2023, commit `2a8975e9`) predates the pinned commit (Nov 2025) — the traced code is unaudited-by-that-report. Adopted.
- **Pinned build config (Astra):** solc 0.8.26, optimizer 4,294,967,295 runs, via_ir=false vs our 0.8.35/runs-1 — arithmetic identical, gas profile not; noted for the later benchmark gate.
- **Upstream tests are approximate (Astra, MiniMax):** fuzz parity vs aggregator routes within `max(liquidity/1000, 1e6)` and 1% handler tolerances on a mainnet fork — evidence the implementation is an analytic candidate with rounding, not an exact-integer optimality theorem. All four of us converge here; the vendor ~10k-gas text remains unmeasured.
- **Zero-L segments:** Grok (untested coefficient divisions), MiniMax (consume-all then revert at execution), Astra (bounded boundary traversal, never divide by zero) — reconciled as: skip zero-L segments in the bounded walk; certificate must require `L>0` in the solved segment.

## 3. Corrections to my own original

1. Add the V4 sign flip to the port map (Grok).
2. Parameterize the protocol take explicitly in my coefficients: `E0` accrual uses `(f−φ)`, gross-up uses combined `f` (Astra/Grok formulations are tighter than my "f = total fee" shorthand for ownership).
3. License framing refined per §2 (GPL conversion; reimplementation path unchanged).
4. `uni-v3-lib` license corrected to GPL-2.0-or-later (attributed).
5. My "no impact bound on the swap itself" stands, now strengthened by the global-limits evidence.

## 4. Final feasibility answers (Kimi, post-review)

1. **One V4 hookless position: YES, conditional port.** Unanimous across all four. Port = StateLibrary/extsload reads, static PoolKey fee, negative `amountSpecified`, unlock/settle wrapper, salt, native face, work-capped walk (or single-segment reject), our 50 bp/10 bp/1 bp checks around it. Aperture's V3 bytecode does not call V4; no official hookless V4 port was found by any of us (absence of evidence recorded).
2. **Whole-book vault: CONDITIONALLY YES — strengthened.** The alignment equation is **quadratic** in each fixed segment with arbitrary F/E constants, own `l`, own-LP fee accrual, and protocol take (three independent derivations now on record; MiniMax's contrary degree claims refuted above). Remaining honest gates: (a) integer-exact verification layer (1 bp inequality acceptance, core-compatible step partitioning per Astra); (b) segment policy — certificate+reject vs owner-approved capped monotone discovery; (c) placement-loss attribution inside the verification; (d) reject-policy liveness measurement; (e) multi-boundary bookkeeping for wings. This is derivation-complete, proof-and-port pending — not a ready mechanism, and not algebraically impossible either.
3. **Autonomous Orbital/SY nesting: NO from Aperture.** Unanimous: NFT surface, no fungible shares, exact-input only, idle-state only; blocked stays sleeve-only F1/F2 by law; `_faceForClaim`/`_invertBufferForEffective`/`zapSplitWad` are untouched (exact-share and sphere inverses are different problems — all four agree, including MiniMax §6).

## 5. Ranked readiness and unresolved proof gates

(1) Whole-book one-segment quadratic candidate + exact certificate — strongest next proof target (now triangulated); (2) single-position V4 port — most mature mechanism; (3) bounded whole-book segment walk with core-compatible stepping — after integer invariants close; (4) Orbital — separate work, unaffected. Gates: independent re-derivation check of all coefficient sets; exhaustive small-integer domains; word-boundary/own-boundary crossing tests; protocol-fee on/off; `l = L` and `l < L`; zero-L; fee near 1e6; signed-coefficient/discriminant width; preview == execution bitwise; liveness of the reject policy; adversarial same-tx cycles; pinned-state benchmarking only afterward. No consensus claim; no gas claim. Stop for the human.
