# Grok original — PRD closure audit (v0.29)

| Field | Value |
| --- | --- |
| Routing | Process **`xai/grok-4.6`**. `RESEARCH_COUNCIL.md` pins **4.7**; **not relabeled**. Same session. |
| Date | 2026-09-27 |
| Inputs | Whole PRD v0.29 + tracker. CLAUDE; `crane-architecture` (now readable at `lib/crane/.claude/skills/…`); IndexedEx adversarial/testing/V4-hook skills. No new-round peers. |

**Missing once:** `docs/plans/detf/` **empty** (PRD §10.2’s cited staking PRD absent). `lib/crane/contracts/external/uniswap/v2/core/contracts/UniswapV2Pair.sol` = `RC_UNAVAILABLE`. No local arithmetic-TWAP library found this pass.

**Not reopened:** Weighted four-leg custody; weights 50/20/10/20; synthetic `C=1e18` / opening `1000e18`; oracle usage/seigniorage; holder PkgArgs hash; same-NFT excess; pre-maturity rebond + old NFT; no intermediate lock reset / final E+1 / independent new locks; NN-03 failure scope.

**No genuine product blocker** found (no demonstrated source incompatibility that changes selected economics). Missing code ≠ missing PRD.

---

## NN-01 … NN-20

| ID | Disposition | Class |
| --- | --- | --- |
| **01** | Constants + manifest **rules** in §16.1; pair `0x59F95461…B54` still **verify-before-impl** (§8). Live hashes/oracle terms/SY/depository **evidence**. | evidence |
| **02** | Custody/timing **answered**. Residual: H01 late-gift **classification**, H03 mature-empty retirement, scan **measurement**. No repeat lock vote. | plan + evidence |
| **03** | **CLOSED** product. Sync + A11 as written. History → 14/18/19. | answered |
| **04** | Timing **answered**. Bonus = `DETFBondNFTMathLib.sol:17–50`. **Do not copy** linear principal `_claim` (`DETFFundedStakingMath.sol:96–116`) — PRD §10.3 already adapts cliff. Escalate **only** if live `minLockDuration` > next-epoch seconds (needs NN-01 terms). | source-map / plan |
| **05** | Weights/fees/synthetic **answered** §§4.4/4.6/7.1.4. Left: custom **rated** vectors (PLP/YT zap-out, SY, SE). | plan (integration) |
| **06** | Source-map outer BasePoolMath + inner V2-min-ratio. | plan |
| **07** | Transitions from §§6.2/7.2–7.4 + exact-out helpers below. | plan |
| **08** | First-bond **G/U/B/R** §10.4 + `firstJoinMustBeFullBook`. Empty SY skipped in synthetic, not relabeled yield. | plan |
| **09** | 3600s **arithmetic** `C(t)` selected. **Do not import Uni V3 geometric ticks.** Interface Markdown = plan. Zero synthetic ≠ below-peg TWAP. | plan |
| **10** | Provider formula §4.5; Pendle preview **off-chain warning**; SE sampling `StandardExchangeRateProviderFacet.sol:61–124`. Conversion proof = NN-01. | plan + evidence |
| **11** | Ledger from BasicVaultCommon + YT force-claim. Same-token **incentive spendability** only if configured collision **exists**. Destinations settled. | plan (conditional) |
| **12** | Normative formula **is PRD §10.2**. Cited `docs/plans/detf/` **missing**. **Do not substitute gons/K.** | plan (restate §10.2) |
| **13** | Custom-family **intent** ≠ instruction bypass. FoT-negative L2 remains in shared law. | **maintenance authority** |
| **14** | §§11.1–11.4 call order; Keep-YT split; A11 isolated. | plan |
| **15** | §12.4 lifecycle. Terminal H01/H03 in the plan, not a new lock questionnaire. | plan |
| **16** | Pin `UniswapV2StandardExchangeDFPkg.sol` + facets; tax in SE not hook; binding ≠ token list. | plan |
| **17** | Hook **flag-mine** vs instance salt `"NET-DETF"`; PkgInit/Args §4.1. | plan |
| **18** | `floor(S0*n/200)` overflow-safe, **no cap**. Don’t invent gas. | plan |
| **19** | A01–A50 → numeric tests later. Unwritten tests ≠ passed. | plan / later evidence |
| **20** | Editorial reconcile. | editorial |

---

## Derived mappings (use these, don’t “derive later”)

### Outer HLP (NN-06/07) — Balancer, not wrapper approx

`BasePoolMath.sol:277–342` exact-out BPT:

1. `newBalances[i]=current[i]-1`; subtract `exactAmountOut` on out-index.  
2. `currentInvariant = computeInvariant(current, ROUND_UP)`.  
3. `invariantRatio = computeInvariant(new, ROUND_UP).divUp(currentInvariant)`.  
4. `taxable = invariantRatio.mulUp(current[out]) - new[out]`.  
5. `fee = taxable.divUp(fee.complement()) - taxable`.  
6. `bptIn = totalSupply.mulDivUp(currentInv - invWithFees, currentInv)` **round up**.

Wrapper `singleExitExactOutSharesIn` (`Math.sol:472–498`) **grosses full out as taxable** — **forbidden** as the selected debit (PRD §4.3). Swaps: `quoteExactIn/Out` `:186–227` (`computeOutGivenExactIn` / `computeInGivenExactOut` + fee on input / `grossUpExactOut`). First mint: `firstMintSharesFull` `:234–243` = `V - 1000`. Unbalanced joins: BasePoolMath invariant path, `dexSwapFeeOfVault` imbalance — **not** usage-fee haircut.

### Inner PLP/YT (NN-06) — V2-like min-ratio

Proportional book (PRD §7.1): `floor(h*K/H)` then `lpIn=floor(pos*L/S)`, `ytIn=floor(pos*Y/S)`. Join shares when live: `proportionalJoinShares` `:260–277`:

`shares = min_i (amount_i * supply / reserve_i)` over positive reserves; unused excess **donates to remaining HLP** (V2 leftover). First inner mint: analogous `sqrt`/`min` not required if using Weighted `V` on outer only — inner is **two-token proportional**, `MINIMUM_LIQUIDITY=1000` (`Math.sol:33`). Unequal Keep-YT: mint to **min ratio**, leftover PLP or YT stays in sub-reserve (C11). Exit: §7.1.2 pre/post-expiry (matched PT/YT redeem, excess AMM on **post-burn** state).

### Rated vectors (NN-05 leftover)

| Pricing | Custody | Rate |
| --- | --- | --- |
| DETF 50% | raw hook DETF | excluded from synthetic mark |
| NET 20% | PLP/YT subshares | §7.1.2 zap-out → NET, **once** |
| sNET 10% | held SY + net claim | reusable SY→sNET provider §4.5 |
| USDG 20% | SE **shares** | SE rate-provider sample |

Count once. Reward USDG / fee payables **out**. Force-claim SY: `InterestManagerYT.sol:43–57` pays **hook**; `BasicVaultCommon.sol:80–105` `U=balance−reserve` must **not** credit that as caller HLP.

### Bootstrap (NN-08)

§10.4: `G=Q(A)`, `U=Q(A*M/WAD)`, `B=(1-p)U`, `R=pU+pG`, mint **G+B+R** only. `otherPayment = wadToNative(other, floor(G*P0_other/1e9))`. `UniswapV4DetfTarget.sol:629–668` full-book join. Zero interest: SY book 0 until claims; don’t seed fake yield.

### Exact-out (NN-07)

ERC-4626 `withdraw`: invert selected **swap or burn** quote (PRD §7.4) — not “unsupported.” Hook: `quoteExactOut` `:209–227`. HLP single-token exact-out: **BasePoolMath** above. Insufficient SY/owned book → **revert whole tx**.

### TWAP (NN-09)

`TWAP=(C(t)−C(t−3600))/3600`. Accumulate **prior price × Δt** before a change. Two series, two consumers. No local arithmetic accumulator found — **implement that contract**; Uni V3 tick oracle is **wrong model**. `previewSynthetic==0` is not a 1h below-peg print.

### Staking (NN-12)

```text
B = DETF.balanceOf(sNET-DETF)
balance(h) = floor(B * shares(h) / U)   // U>0
```

Mint-to-custody raises B; expansion mints DETF **and** fee/creator **internal shares** (changes U). **Gons rebase** (`DETFFundedStakingMath._rebase`) is Universal funded-index, **not** this. Missing `docs/plans/detf/` §3.1: **copy §10.2 into the plan** as the adopted edge rules (U=0, standing recipients, post-mint deposit ratio).

### Bonds (NN-04/08)

`_effectiveLockDuration` clamps min/max (`Common.sol:104–109`). Bonus quadratic `:17–50`. Custom **principal cliff** vs linear `_claim` = **adapt predicate**, already selected.

### SY (NN-10)

`rate = floor(a * 10^syDec * 1e18 / (q * 10^outDec))`. `exchangeRate()` ≠ sNET quote until denomination proven. Preview caveat stands.

### SE (NN-16)

Reference DFPkg `:4–64` + installed facets. Tax `floor(gross*bps/10000)` in SE (§8). Canonical pair identity in **package**, not hook. Empty correctly bound SE **allowed**.

### Deploy (NN-17)

Hook: registry `deployHookVault` + **mineNonce** (V4-hook skill). DETF instance salt **`"NET-DETF"`**. `calcSalt` hashes whole PkgArgs including owner.

### Authority (NN-13)

Owner approved **this family** FoT NET + rebasing sNET. Shared `INDEXEDEX_AGENT_LAW` / L2 **unchanged**. Handoff needs **maintainer** scoped exception record — this audit cannot write it.

---

## Residual (not questionnaires)

- **NN-01** live pins.  
- **NN-04** only if measured oracle min-duration conflicts next-epoch.  
- **NN-11** only if **real** interest-token incentive collision.  
- **NN-02/15** late-gift/retirement **classification** if it would **reassign entitlements** (excess beneficiary already same-NFT).  
- **NN-13** instruction file.

Confidence: **high** on dispositions and cited math; **none** on live config, gas, or executed parity.
