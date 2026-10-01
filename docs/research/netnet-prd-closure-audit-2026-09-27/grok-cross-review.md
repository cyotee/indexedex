# Grok closure-audit cross-review

| Field | Value |
| --- | --- |
| Routing | `xai/grok-4.6` (not 4.7). Own original untouched. Full Astra, MiniMax, Kimi. No peer cross-reviews. |
| Date | 2026-09-27 |

**Rule:** close **policy** questions; keep **proofs** open. No new owner Q without an irreducible source conflict. **None found.**

---

## Rejected claims

| Claim | Why |
| --- | --- |
| MiniMax: `StakedNET.sol` gons **is** PRD §10.2 | `balanceOf = gons/gonsPerFragment` and `fundedRebasingSupply = total − staking inventory` are **Olympus index math**, not `B = DETF.balanceOf(sNET-DETF)`, `bal(h)=floor(B·u_h/U)`. Do **not** mandate gons. |
| Kimi: `RebasingDETFTokenRepo` cached `shares·rate/SHARE_UNIT` **is** the missing §10.2 doc | Cached/extractable **receipt rate** ≠ live **held DETF B**. D60 Balancer-stable tree is **reference-only**. **Do not claim the intended `docs/plans/detf/` file was found** (directory empty). |
| MiniMax: build a **new** `PendleNetNetSY` because vendor templates lack NetNet SY | Configured **market SY is discovered**, not authored. **Rate provider ≠ SY.** `ExitQueryTarget.assetInfo` describing **hook LP** does not require a new Pendle SY. |
| MiniMax SY factory `0x466C…` / UniV2 factory `0x8bcE…` as settled pins | Not independently verified here; **NN-01 evidence**, not design. |
| MiniMax `MAX_N=8` ⇒ split hooks | Four legs **fit**. Not a product issue. |
| MiniMax `StakedNET MAX_SUPPLY` as DETF horizon | Wrong asset. |
| Kimi NN-19 “include **hostile balance reads**” | Reopens **v0.27 / NN-03**: failed **required** reads may revert; **no** survival/quarantine acceptance. |
| Kimi: Truncated TWAP **ring/cardinality** as the arithmetic contract | Tick/log integrator. **Reuse search structure only.** Do **not** invent a **3601-slot** bound or **unsampled history replay**. |
| Sourcify exact_match ≡ **current runtime** | Verification-service snapshot, **not** latest-block code (NN-01). |
| Grok original: unmatched inner join **donates** like V2 | **Reject.** PRD forbids **unpriced donations**. Refund/account residuals; do not credit callers with whole-balance leftovers (`Astra` correct). |
| Partial first-mint ⇒ skip full book | `firstJoinMustBeFullBook()==true`. `isLive()` needs **all** legs. Direct **SY capital** **is** allowed; empty **earned interest** ≠ unfunded SY. Partial helper **does not** waive full-book bootstrap. |

---

## Itemwise status

| NN | Status | Accepted source-derived answer | Still open (proof, not vote) |
| --- | --- | --- | --- |
| **01** | Policy closed | Manifest rules + 4 Pendle anchors recorded. Pair **verify before impl** (§8). | Live hashes, tax, oracle terms, SY conversion. Sourcify ≠ runtime. |
| **02** | Policy closed | NFT-owned holder; whole-PkgArgs hash; returned noteId; excess→same NFT; aggregate `redeem(to)` only. | Scan **measurement**; H01 late-gift **class**; H03 empty retirement. |
| **03** | **Closed** | Full expected-set sync; A11 isolate fee **transfer**; essential read fail **reverts**. | Do **not** add hostile-`balanceOf` survival to A19. |
| **04** | Policy closed | No mid reset; final E→E+1; new type lock. Bonus `DETFBondNFTMathLib:17–50`. **Don’t copy** linear `_claim`. | Live BondTerms vs next-epoch **only if incompatible**. |
| **05** | Policy closed | 50/20/10/20; synthetic NET; `C=1e18`; opening `1000e18`; usage K-growth; seigniorage split. | Custom **rated** PLP/YT, SY, SE mapping. |
| **06** | Spec-from-source | **Outer:** `BasePoolMath` unbalanced/exact-out (`:126–205`, `:277–342`); **not** wrapper `:472–498`. **Inner:** two-stage `floor(h·K/H)` then `floor(pos·L/S)`, `floor(pos·Y/S)`. Join: `min(d·S/R)` **after** accepted ratios; **refund unmatched**. | Written rounding table + last-exit/rollover vectors. |
| **07** | Spec-from-source | Shared-SY held-first (§6.2); burn on **owned** book (§7.2); `qQuote=q` on reinvest. Weighted `computeInGivenExactOut` + `ceil(q*WAD/(WAD+p))` for **Weighted layer only**. | **Composed** SY/zap/tax inverse **unproven**. ERC-4626 withdraw still required. |
| **08** | Spec-from-source | §10.4 G/U/B/R; `Target:629–668` G+lead+**required legs including SY seed**. Principal ≠ interest. | Unit map for non-NET extras; **full-book** live transition. |
| **09** | Spec-from-source | `C(t)=∫price dt`; 3600s arithmetic; prior-price×Δt; two series. UniV2-style **price×time** (`Astra` PairOracle) **not** ticks. Absent TWAP = above-1 **branch**, not a print. Rate fail ≠ missing history. | Interface + checkpoint semantics. **No** unobserved continuous replay. |
| **10** | Evidence | §4.5 sample rate; provider **separate** from hook balances **and** from market SY. Pendle preview **off-chain**. | Configured SY `getTokensOut` / decimals / scaled18 **on-chain**. **Don’t author a SY.** |
| **11** | Spec-from-source | YT `:43–57`/`:63–79` + `PendleYieldToken` third-party claim; Common `:80–105` credit ≠ force-claim. | Ledger SM. Incentive spendability **only if** `getRewardTokens()` **lists interest token**. |
| **12** | Policy + **gap** | Adopt **§10.2 B/U** in the plan. `DETFSeigniorageShareLib:18–33` standing **top-up** (Astra). | **No** gons, **no** Balancer cached-rate as mandatory. Missing cited doc **stays missing**. |
| **13** | **Maintenance** | Family approval = **intent**. Shared FoT/L2 law **unchanged**. | Maintainer file. Not this council. |
| **14** | Spec-from-source | Keep-YT `ActionAddRemoveLiqV3:236–303`; exits `ActionMiscV3:129–240`; factory-first; atomic; A11 isolated. | Call/arg table; old/new SY (NN-10). |
| **15** | Policy closed | Rebond new tokenId; old rights kept; unlock 0 = Pendle maturity. | Terminal SM only. |
| **16** | Plan | DFPkg + OutTarget **seven** exact-out classes (`Astra :57–113`). Binding: **`asset()`/pair tokens/factory/registry**, empty SE OK. Tax in SE. | Exhaustive selector matrix. Failures ≠ missing TWAP. |
| **17** | Plan | Holder CREATE2 + PkgArgs hash; DETF salt `"NET-DETF"`; hook **flag-mine**. | Authority graph. `hook_factory` profile vs CLAUDE default/fork = **plan/NN-13**, not product. |
| **18** | Evidence | `floor(S0·n/200)` no cap; domain from **Weighted/BasePoolMath** guards. | **Measured** gas/N* later. No invented ring size. |
| **19** | Plan | A01–A50 → TestBase vectors. **Exclude** NN-03 survival. | Unwritten ≠ passed. |
| **20** | Editorial | Repair §10.2 **citation** to “not located; use §10.2 text.” | No fake history. |

---

## Keep from all three

Astra’s BasePoolMath **ordering**, V2 **no-donation** inner, Keep-YT/exit selectors, Weighted-only inverse, tick-oracle **ban**, empty staking-doc **honesty**. MiniMax/Kimi: weights/`C=1e18`, fee split, holder salt, full-book bootstrap **as policy**. Kimi: `firstJoinMustBeFullBook` vs partial mint **tension** — resolve by **full book**, not partial live.

Grok original: dispositions stand **except** inner donation wording and any implication that Weighted exact-out **closes** composed inverses.

---

## Handoff

Write the **plan** with these mappings. **Do not** freeze execution where NN-01/10/12-reference/composed-inverse/A19 proofs are absent. **Do not** ask the owner for fees, weights, locks, SY authorship, or hostile-token survival.
