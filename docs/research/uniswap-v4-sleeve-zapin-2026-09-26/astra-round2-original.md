# Astra — round 2 independent original

**2026-09-26; research only.** Existing route and current-call-only swaps are resolved. No current-round peers or cross-review artifacts accessed; no execution performed. Read the moderator draft as prior context, not authority over the new owner input. Below, **V/** means `contracts/protocols/dexes/uniswap/v4/`; **Common** is its `UniswapV4StandardExchangeCommon.sol`.

## 1. Yes: swap → placement → mint-last is implementable

The owner's sequence is sound with an explicit two-token incumbent/contribution separation. Placement need not introduce a new valuation model. My earlier statement that economics needed specification should not imply an insoluble problem: **the existing proportional formula works exactly when the contribution matches the incumbent whole-book ratio.** Mint-last alone does not establish that ratio or identify principal.

Existing code already provides geometric-mean initial issuance, dual min-ratio issuance, and single-sided invariant growth (`Common:685–712`). Preserve dual-funded activation; apply the composed route only after activation.

## 2. New denominator: owned deployed principal

Define each token's actual held sleeve `F`, vault-owned deployed principal `D` from exact CL math, and uncollected earned fees `E`. Ownership book is `B=D+F+E`; external LP inventory never enters it (`Common:619–643`).

**Owner's policy:** `F=pD`. For placement inventory `T=D+F`, solve simultaneously:

```
F* = p/(1+p) × T
D* = 1/(1+p) × T
```

With WAD parameters: `F*=floor(T*pWad/(1e18+pWad))`, subject to token/liquidity rounding. Do not repeatedly aim at `p × pre-move D`.

Example: `D=100,F=40,p=.2,T=140`: deploy 16⅔, reaching `D=116⅔,F=23⅓`. Deploying 20 to reach the old target produces `(120,20)`, below policy.

**Fees recommendation:** E belongs in share accounting, but is neither spendable F nor deployed principal D. Collect fees before idle placement planning: E becomes F exactly once, then eligible excess compounds into D. Recompute after newly collected fees; uncollectable E stays separately disclosed, not sleeve coverage. Blocked operations cannot count E as spendable.

At effective `p=0`, target F is zero. Stored zero remains oracle fallthrough, not a guaranteed zero override. At `p=1`, F=D: **half total**, not all-liquid. Remove the draft's 100%-liquid exception. Current oracle percentage validation is bounded at WAD (`contracts/oracles/fee/VaultFeeOracleRepo.sol:68–69`); an all-liquid mode is not implied by the new semantics.

Retain deadband `max(absoluteFloor,5%×F*)`; at p=.2 this is about 0.833% of T, previously 1%. This is a deliberate policy change, not reason to widen tests.

Supersede draft §4/G3 and relevant local D17/D27 targets. Scope interpretation to V4 consumers; do not globally rewrite other families' oracle meaning. Audit V4 runtime, public rebalance, previews/transition state (`InQueryTarget:121–127`), events/UI, defaults/overrides and tests. Existing numeric settings acquire different semantics; old instances require explicit deployment/version treatment.

## 3. Simple issuance and attribution

Let S be outstanding supply, **B** the incumbent two-token book valued at the actual post-composition pool state, and **C** the actual attributable caller basket after swap costs.

Recommended existing proportional rule:

```
m = min(floor(S*C0/B0), floor(S*C1/B1))
```

For positive B, this guarantees `S*(Bi+Ci)/(S+m) >= Bi` token-by-token. If `C0/B0=C1/B1=a`, then `m≈aS` and both sides are exactly proportional apart from rounding. No numeraire or new NAV is needed.

**Snapshot sequence:**
1. Establish authenticated input credit and S; distinguish donations from input before trading.
2. Swap only that credit. C is remaining credited input plus actual swap output, net actual costs—not arbitrary balance growth.
3. Before placement, measure total owned book at post-swap price and subtract C to obtain B. Thus incumbent CL repricing and own-LP swap fees stay with incumbents; pre-swap denominators are inappropriate.
4. Add/remove liquidity toward policy, tracking principal movements separately from fee collection. Collection alone changes neither B nor C. Assign newly earned pre-mint fees/donations to B; charge measured placement costs/rounding to C. For accounting-neutral placement, B/C remain unchanged. Reconcile final total as B+C before minting m and enforcing minShares.

This simple snapshot assumes placement does not induce another unmodeled price-changing trade. Hook-induced trades/charges require explicit attribution or rejection; do not infer C from final-total minus a stale B. Mint-last does not authorize rebalance to consume incumbent assets as swap input.

## 4. The remaining ratio choice is real but small

Illustrations ignore price movement/fees, already incorporated in B/C:

- Aligned book: `B=(120,120),S=120,C=(12,12)` gives m=12. At p=.2 final total `(132,132)` allocates D=(110,110), F=(22,22).
- Skewed book: `B=(200,100),S=100`; post-swap LP ratio 1:1 and `C=(10,10)` gives **m=5**. Incumbents retain token0 entitlement and gain token1; surplus is donated, not neutrally credited.
- Align C to **whole book**, `(20,10)`: m=10; min-ratio and invariant-growth agree. But that 2:1 contribution cannot all deploy into a 1:1 LP while satisfying both sleeve targets.

Alternative invariant-growth rule `m=S*(sqrt((B0+C0)(B1+C1))/sqrt(B0*B1)-1)` gives approximately **7.47** shares for `(10,10)`. It credits imbalance under existing constant-product economic logic, but reduces incumbent entitlement to one token while increasing the other. It is not equivalent to proportional joining; generalizing it to composed dual inputs changes today's branch.

**Recommend LP-ratio composition plus existing min-ratio issuance**, explicitly disclosing skew-surplus donation and protecting with final minShares. If that donation is unacceptable, approve whole-book-aligned composition with more undeployed residual, or invariant-growth dual issuance. Current-call-only trading cannot promise both perfect global deployment and neutral proportional joining of every skewed book.

## 5. Remaining decisions and evidence

Owner choices: approve the skew treatment above; approve fee classification; select swap bounds/supportable hooks. Preserve blocked sleeve economics, full-range imports and WETH-facing native settlement under alignment §24.7.1. Required trading/placement failures revert; previews include economic costs and placement rounding. No mandatory TWAP follows from DETF law.

Pretransfer deserves explicit validation: `Common:1274–1288` credits available unbooked balance, not independently proven transfer provenance. Do not assume it distinguishes a donor from the caller; test donation/pretransfer replay before claiming current-call isolation.

Require independent numerical/invariant tests for new denominator/endpoints, skew examples, self-LP fees, fee collection, rounding, callback donations and blocked parity. **Confidence:** high in algebra and existing formula compatibility; medium in attribution implementation. Local solc 0.8.35; upstream/deployment pin remains unverified. No new external API claim or external query was needed.
