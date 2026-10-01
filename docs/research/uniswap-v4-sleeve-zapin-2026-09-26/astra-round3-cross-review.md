# Astra — round 3 combined cross-review

**2026-09-26. Research only.** Read the three round-3 originals together as untrusted evidence; no cross-review artifacts read. All originals preserved. No code, shell, tests or delegation. **PZ-1–8 remain fixed.** References to peers below mean their round-3 original reports; **V/** means `contracts/protocols/dexes/uniswap/v4/` and **Common** means its `UniswapV4StandardExchangeCommon.sol`.

## 1. Corrected recommendation: four actionable owner questions

### Q1 — What minimum execution protection must the existing ABI enforce?

**Recommend:** retain the ABI and allow zero user minimum only if mandatory protocol execution bounds still apply. Select maximum incremental price impact/fee exposure, policy mutability, and whether the product additionally promises deviation protection against an independent reference. Such a reference would require explicit freshness/availability rules; neither this review nor DETF law mandates TWAP.

**Disagreement:** Grok Q1 recommends a package-constant spot-relative impact cap; Kimi Q2 recommends zero as an opt-out from economic protection. I favor Grok's mandatory-cap direction but do **not** equate it with fair-starting-price protection. A package constant is one governance/design option, not an already-approved choice. Independent-reference protection remains a separate owner choice, not a solver detail.

`minShares` limits the number minted. It can protect a well-quoted trade, but is not an independent fair-value guarantee: both caller basket C and post-swap incumbent denominator B respond to price/fees. Kimi's claim that any economic loss must shrink m proportionally is too broad. Requiring a positive minimum, as MiniMax suggests, is also insufficient: one wei remains practically unprotected. Final minimum/deadline, finite swap limits and approved economic bounds must compose rather than substitute for one another.

### Q2 — Which hook/fee behaviors are required, and which may fail closed?

**Recommend:** approve a concrete supported-market/behavior matrix. Unsupported composition must revert atomically and preview as unavailable; preserve blocked sleeve operation and existing non-composition routes. Supported hooks require correct actual-delta attribution, fee bounds and projected behavior—not merely a recognized address-bit pattern or responsive getter.

**Disagreement:** Grok Q2 limits launch to no-hook/current-projectable cases; MiniMax and Kimi classify support as engineering. Exact adapters are engineering, but losing deposits into an intended market is a product compatibility choice. Grok's conservative scope is reasonable **subject to a consumer/market audit**; `_supportsProjectedHook` is evidence of current quote capability, not sufficient authentication or a complete safety proof. `V/UniswapV4QuoteService.sol:19–57` currently recognizes Pons-shaped data and otherwise may leave amounts unadjusted.

### Q3 — What compatibility changes are allowed to establish current-call funding provenance?

**Recommend:** preserve legitimate push consumers through audited, authenticated, one-use funding credit where feasible. If that cannot be specified safely, approve rejection of unverifiable idle pretransfer claims only after documenting affected callers and their pull/handshake migration. Preserving the selector does not preserve compatibility when `pretransferred=true` starts reverting.

**Disagreement:** Grok, MiniMax and Kimi prefer idle pull-only rejection. I agree this is safer than swapping unidentified balances, but their restriction cannot be presented as already satisfying PRD ZA-18's legitimate-consumer requirement. Nor may the same provenance issue on preserved blocked routes be called an accepted donation-capture policy: D29 includes donations in incumbent assets; it does not authorize stealing them.

`Common:1270–1288` establishes a real local evidence gap: unbooked face balance is not source identity. MiniMax's nonce/bitmap proposal addresses replay only; it needs a binding to an actual authenticated delivery. Its claimed second-call replay is not proved: existing deposit code synchronizes reserves (`V/UniswapV4StandardExchangeInBase.sol:306–307`; `Common:605–612`). The threat is genuine, but neither a repeat-mint exploit nor a complete mitigation was demonstrated.

### Q4 — What bounded numerical loss and tiny-deposit rejection policy is acceptable?

**Recommend:** approve an explicit relative economic alignment-loss ceiling plus a separately proven integer-flooring allowance. Failed convergence or inability to mint nonzero shares within that ceiling reverts. Do not introduce an idle sleeve-only fallback or alternate issuance formula. Precise solver limits, token-unit arithmetic and realized-loss checks are engineering.

**No proven threshold exists in this council evidence.** Grok's one-share/absolute-floor condition, MiniMax's raw `1e6` counter minimum and share floors, Kimi's sleeve-floor-derived minimum, and my original candidate **1 bp** are proposals—not accepted or validated tolerances. Sleeve deadband measures inventory-placement drift, not allowable issuance loss. One share can be economically large, while one raw token unit has different meaning across decimals. Do not hardcode these suggestions without a worked economic bound and production-path tests.

## 2. Caller-selected lock mode: mandatory evidence, not automatic risk acceptance

MiniMax's statement that users cannot control the gate is false for contract callers: local `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55–64` exposes unlock and calls that caller's callback. It can invoke the vault there and obtain the preserved blocked branch, then redeem after returning to idle.

Grok and Kimi correctly identify the mode differential, but I reject **accept-and-disclose before analysis** as sufficient. Different share quotes alone do not prove a profitable cycle. Model input/output funding, self-LP repricing, fees, sleeve cover, price impact and redemption state for both directions and repeated cycles. Compare extraction attributable to the change against ordinary market/inventory arbitrage; do not require the impossible absence of all market arbitrage.

**Important Kimi correction:** sleeve assets do not directly earn pool fees, but shares minted for sleeve deposits participate in the vault's complete backing and subsequent earnings. There is no separately disenfranchised “sleeve depositor” share class in this path (`InBase:292–307`; `Common:619–630`). “Blocked depositor earns no fees” is not a compensating economic protection.

This is a release-blocking **analysis/test obligation**, not a fifth question reopening PZ-8. If a material unintended extraction is demonstrated, stop and return with exact evidence for remediation authorization. No exploit is confirmed here, and no pricing change or caller allowlist is authorized.

## 3. Arithmetic and scope corrections: engineering, not owner questions

- **Zero deployed:** Kimi Q5's `D=0 ⇒ F*=0` contradicts the accepted fixed point. For F=120, D=0, p=.2, T=120 and F*=20; feasible dual inventory can deploy 100. Existing free inventory can pay blocked withdrawals without any deployed position. No new all-free exception is needed. Recovery still requires the appropriate currencies/depth and positive-reserve accounting.
- **Decimal floor:** MiniMax Q3's 0.01-token example is wrong under its stated 18-decimal convention. Target `0.01/6≈0.0016667` tokens is about `1.6667e15` raw units, **above**, not below, the `1e12` floor by roughly 1,667 times (`Common:353–364`). A blanket thin-book exclusion does not follow.
- **Skew example:** for T=(220,110), targets are `(36⅔,18⅓)`, not 18⅓ for both tokens. Kimi mislabels the token0 target. F=(128⅓,18⅓) has material token0 surplus; that is accepted PZ-7 behavior.
- **Coupled placement:** at fixed price, maximize feasible liquidity under both currency constraints; never borrow the scarce sleeve to consume abundant residual. `F−pD=(1+p)(F−F*)`; use the specified deadband units consistently. Deadband allows no-op tolerance, not deliberate undershooting to gain more L. Grok Q4 is a useful implementation invariant, not a new product-policy vote.
- **Bootstrap:** MiniMax Q4 is resolved already. Reject one-token activation before composition; do not ask whether an internal swap replaces dual funding.
- **Reporting:** disclose spendable F, deployed D, uncollected E, target and material residual/cause. Version/relabel existing free/total views or add an explicitly named deployed-relative view; consumer compatibility review determines the surface. Absolute deviation is not synonymous with surplus: report shortages separately. No global oracle semantic change.
- **Attribution:** preserve post-swap B, entire caller C including sleeve, and once-only fees through placement. MiniMax's `R_pre` preview notation must not reintroduce its previously rejected pre-swap denominator. Quote and execution use B(x); no unsafe dust fallback.

## 4. Confidence and remaining uncertainty

**High:** accepted-policy arithmetic, share-accounting distinctions, permissionless local lock selection and the provenance evidence gap. **Unverified:** cross-mode profitability, exact hook matrix, provenance consumer compatibility, safe solver tolerance and numerical convergence. No new external API assertions were required; findings above are grounded in directly read local sources and the latest PRD. No claimed unanimity, proven exploit or passing-test evidence. Return these four questions and engineering obligations to the owner without reopening PZ-1–8.
