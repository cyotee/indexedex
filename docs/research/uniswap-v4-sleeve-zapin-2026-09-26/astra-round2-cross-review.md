# Astra — round 2 combined cross-review

**2026-09-26. Research only.** Read the Grok, MiniMax M3 and Kimi K3 round-2 originals together as untrusted evidence. No cross-review artifact read; originals preserved. No shell, tests, implementation or delegation. **V/** below means `contracts/protocols/dexes/uniswap/v4/`; **Common** is `V/UniswapV4StandardExchangeCommon.sol`. Peer references are to their round-2 originals in this directory.

## 1. Concrete answer and change from my original

**Yes:** retain the existing route, swap only current-call input, allocate toward **20% of owned deployed principal**, then mint a proportional claim on the complete owned book. There is a simple existing issuance formula, provided the contribution and incumbent book are correctly identified.

**Astra changes recommendation, not history:** my round-2 original recommended LP-ratio composition plus min-ratio issuance with disclosed surplus donation. Grok's book-aligned proposal better matches the owner's phrase “proportional allocation of deployed reserve + liquidity sleeve.” I now recommend **post-swap whole-book alignment and existing min-ratio issuance**, with material undeployed residue honestly permitted for skewed books. This changes the preferred trade-off, not the original mathematical findings. The owner must confirm that residual policy rather than have it hidden as dust.

No consensus is claimed on snapshot mechanics: MiniMax and Kimi's frozen pre-swap denominators are wrong for the recommended economic intent.

## 2. Attributed corrections

### Grok

Agree with the fixed point, separate fee treatment, post-swap incumbent denominator, V4-local policy interpretation, unchanged numeric .20 default, and exact book-aligned min-ratio (`Grok:11–52,62–76`).

Clarify three points:

- Securely delivered pretransfers are potentially caller contribution; “pretransferred balances already on diamond stay in R” (`:40`) must not exclude legitimate current-call credit. Conversely, raw unbooked balance does not prove provenance.
- Alignment is not necessarily accurate to “1 wei” (`:52`) across arbitrary decimals, large supply and solver tolerances. Specify reserve/share-unit rounding bounds and bounded solver failure.
- “No incumbent liquidation” (`:43`) must mean no incumbent **swap funding**. Owner-authorized add/remove placement can withdraw incumbent liquidity to refill sleeve. Pure removal is not a prohibited inventory trade.

The p=.20 number and p=1 algebra are consequences of resolved owner input, not questions to reopen.

### MiniMax M3

Its fixed-point derivation is correct, but several later claims contradict it or the accounting:

- Add/remove placement does not balance a skewed **total** book (`MiniMax:52`). It changes custody, not token composition.
- Reject the frozen `F_pre+D_pre` denominator (`:60–67,114`) and especially subtracting `sleeve_held` from caller credit. **Caller-owned contribution includes both its deployed and retained sleeve portions.** Subtraction undercredits deposits, potentially counting flows twice.
- Uncollected fees being included by `_freeBalancesForShareMath` does not make them spendable F (`:29,107`). Fees collected during placement are not new caller input (`:71`). Collection before the swap cannot collect fees not yet earned by that swap.
- Its numerical example (`:77–96`) is expressly admitted wrong and should not enter the PRD. At fixed price, a single full-range position cannot accept arbitrary independent token amounts; binding-token math leaves residue, not invented principal.
- Reject .25 recalibration (`:110,120`), retained imported NFT ticks and native exclusion (`:128–129`). Owner chose .20 of deployed; current imports convert to full-range managed backing (`V/UniswapV4StandardExchangePositionImportTarget.sol:77–94`).
- The currently implemented dual branch is min-ratio. Invariant growth exists for single-sided inputs; calling the existing helper with two positive amounts does not select it (`Common:700–712`). Generalizing it would be a separate economic change.

### Kimi K3

Agree that whole-book alignment makes proportional issuance simple, but correct the operational recipe:

- `F*=pT/(1+p)` is **not** equivalent to freezing `pD_pre` (`Kimi:12,31`). Use post-composition placement inventory, not the old deployed denominator.
- Its call-start denominator (`:24,28–34`) neither captures endogenous LP repricing nor reserves swap-earned fees exclusively for incumbents. Its separate instruction to subtract caller deltas from post-swap totals produces a **post-swap**, not pre-swap, incumbent book. Use the latter consistently.
- Calling uncollected E “sleeve” (`:9,16`) conflates accounting assets and available withdrawal cover. Collected fees can raise the fixed-point target immediately; they need not first be deployed.
- Book-aligned skew leaves potentially **material residual inventory**, not necessarily “harmless dust” (`:24`). Always composing to the book does not guarantee maximal deployability.
- Reject .25 default recommendation (`:56`). Resolved p=0 target also does not mean every blocked withdrawal always fails (`:14`): deposits, donations or residuals can leave spendable F despite a zero target.

## 3. Formula and conservation conditions

Use distinct quantities per token:

```
D = vault-owned deployed principal at actual pool price
F = actual spendable held balance
E = earned but uncollected fees
A = D + F + E                   // complete ownership book
T = D + F                       // currently placeable inventory
F* = floor(pWad*T/(1e18+pWad))
```

Collect E before idle planning when possible; collection changes E into F exactly once. Include residual E in ownership, not liquidity coverage. For .20, F*=T/6; for effective zero, F*=0; for one WAD, F*=T/2. Stored zero remains fallthrough. Deadband stays `max(absoluteFloor,5%*F*)`. Apply only to V4 consumers, not globally to the oracle or other vault families.

Let S be pre-mint supply. After the caller's swap, let C be remaining authenticated input plus actual counter-token output, net actual swap costs. **Include every retained caller sleeve token in C.** Let B=A−C at that post-swap accounting boundary. B includes incumbent repriced principal, existing sleeve/donations and all incumbent earned fees, collected or not.

For positive B:

```
m = min(floor(S*C0/B0), floor(S*C1/B1))
```

This ensures `S*(Bi+Ci)/(S+m) >= Bi` for each token. When `C0/B0=C1/B1`, issuance is proportional apart from rounding. The solver must seek alignment against **B(x)**, because its chosen swap x changes price, deployed principal and fees—not merely against a fixed pre-call ratio.

Place assets, reconcile attribution and mint last. Pure principal placement and fee collection preserve A=B+C. Newly earned pre-mint fees and unsolicited donations belong to B; actual attributable placement charges/rounding reduce C. If placement hooks change price or produce other economic deltas, update attribution explicitly or fail closed—do not subtract C from totals using a stale B. The formula proves issuance non-dilution relative to **post-trade B**, not that incumbents escaped market impact from their own LP trading.

**Code verification:** deployed amounts read current price (`Common:470–506`); fees are separately added for share accounting (`:619–643`); idle rebalance collects fees and measures actual free balances (`:751–766`). These facts settle the pre/post-swap and F/E disagreements.

## 4. Feasibility: proportional issuance is not full deployment

At a fixed two-sided in-range price, deployed principal has ratio `q0:q1` per unit liquidity. Exact `F=pD` for both tokens requires `T0/T1=q0/q1`. Arbitrary skewed totals violate this condition; add/remove operations cannot fix it.

Example: post-swap B=(200,100), S=100, LP ratio 1:1. Book-aligned C=(20,10) mints 10 shares, with totals (220,110). At p=.20, token1 permits at most 91⅔ deployed on each side while retaining its policy sleeve. F=(128⅓,18⅓); token0 target is 36⅔. **Token0 residual above target is 91⅔, not dust.** Placement can nevertheless increase L from a smaller starting position.

Alternatively C=(10,10), aligned to LP rather than B, mints only 5 shares under min-ratio: the caller donates surplus token1. Invariant growth would mint approximately 7.47 and redistribute token-specific entitlements. Neither alternative is equivalent to exact proportional joining.

## 5. Remaining choices and handoff

Recommend confirming **post-swap book alignment + min-ratio + explicit material-residue allowance**. If the owner instead prioritizes LP-aligned deployment, surplus donation or changed imbalance pricing must be explicitly selected. Exact simultaneous sleeve targets cannot be guaranteed on arbitrary skew under current-call-only trading.

Remaining engineering/product choices: supported hook set; swap bounds/reference and ABI-compatible exposure; solver/rounding tolerances; clearly enumerated dust/no-depth/failure outcomes. No TWAP mandate follows from DETF law. Required economic/settlement failures revert; do not silently skip composition.

Preserve dual bootstrap, full-range imports, native/WETH settlement, Multi no-swap and blocked sleeve operation. Validate donor/pretransfer provenance, replay, callback donations, self-LP fees and transition/SY quotes through real production tests; no results are claimed here.

**Confidence:** high in fixed-point algebra, issuance proof and code-grounded corrections; medium in implementation attribution/solver coverage. No new external API claim needed retrieval; prior Context7-first evidence remains applicable. Original reports remain unchanged.
