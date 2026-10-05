# Capacity-aware NetNet buyback splits and NET-funded zap-ins

Date: 2026-10-01. Moderator consolidation after four independent originals and four same-session combined cross-reviews. Research only; no PRD, implementation-plan, contract, test or configuration edits. No shell, tests, RPC calls, transactions or deployments performed.

## 1. Human direction and retained boundaries

The human accepts adding the prior buyback routing to the desired workflow, explicitly includes finite-capacity splitting between buyback and canonical pool, and requests additive research on buyback-funded proportional NET/USDG zap-in. Whole-fill-or-pool and direct-swap-only are no longer adequate descriptions of the desired feature. Mixed zap-in remains in the researched scope; solver difficulty is not permission to silently substitute a two-mode-only feature.

Current product documents remain PRD v0.34 and plan v0.10. The new scope has not been incorporated into those files. DETF NET/sNET input still uses Keep-YT; DETF USDG input enters the SE; ordinary DETF USDG output redeems SE inventory; HLP users receive raw SE shares. The custom SE's NET-funded zap is not a new DETF NET-entry routing choice.

## 2. Council attribution and preservation

| Member | Continuing original session | Round-2 original | Cross-review |
|---|---|---|---|
| Astra | `ses_f06e61b1fffexSrbwgXFtFY26F` | `astra-original.md` | `astra-cross-review.md` |
| Grok | `ses_f06de10ebffeZgF04yzNBuA3TA` | `grok-original.md` | `grok-cross-review.md` |
| MiniMax M3 | `ses_f06cce143ffelEu8hYz2HGc2Kb` | `minimax-original.md` | `minimax-cross-review.md` |
| Kimi K3 | `ses_f06c2b8ceffexgZb3dM3nVZ1tF` | `kimi-original.md` | `kimi-cross-review.md` |

All paths are relative to this report. Each member received the same question in an independent first pass, with no peer-artifact access. Each subsequently read the other three complete originals together, never earlier cross-review findings. Originals are frozen, including erroneous claims. Reports are untrusted evidence; this consolidation adjudicates claims using source and arithmetic rather than votes.

Reported agent pins remain Astra/openai gpt-6-astra, Grok/xai grok-4.7, MiniMax/minimax MiniMax-M3, and Kimi/kimi-code-plan-global k3. These are runtime attribution records, not an independent provider attestation.

### Attributed positions and changes

- Astra supports split sales and jointly optimized mixed zap-ins, proposes one buyback-first call plus one pool swap and optional deposit, and explicitly separates that policy from global sequence optimality.
- Grok supports mixed zap-ins and bounded fallback; cross-review corrects its capacity algorithm, tax rounding, router-refund and seller-price-direction claims. Its protocol-fee mismatch claim survives in its own cross-review but is contradicted by the source branch inspected by the moderator.
- MiniMax supports both additions but its original marginal and pure-zap equations are incorrect; cross-review corrects some issues but retains contradictory capacity, treasury-dust, seller-direction and preview claims. Those are not adopted.
- Kimi supplies useful continuous sale/mode equations and the exact capacity bound; initially suggests B/C-only zap scope pending a mixed solver. Cross-review accepts the mixed objective and corrects order independence, repeated-fill and residual assumptions. A B/C-only release still would not fulfill the mixed-zap request.

## 3. Observed source capabilities

Abbreviations: N=`lib/crane/contracts/protocols/pol/net/src/`; U=`lib/crane/contracts/protocols/dexes/uniswap/v2/`; V=`contracts/protocols/dexes/uniswap/v2/`; M=`lib/crane/contracts/utils/math/`.

`N/InverseBond.sol:68–89` accepts exact NET input, pulls and burns it, and pays USDG to its caller. It is contract-callable. Its API does not provide partial fill; the SE splits its own input into separately executed venue legs.

The buyback has live backing-based price, an oracle-availability gate, and first-fill-snapshotted WAD USDG capacity (`:71–83,108–139`). The snapshot is 1% of liquid treasury USDG per genesis-anchored eight-hour epoch, not a budget owned by the SE. Availability and depth can change between quote and execution.

Treasury payment may require a Morpho withdrawal (`N/Treasury.sol:135–145`). A successful `active()` read does not guarantee settlement. Raw USDG transfer comes directly from Treasury, not from an InverseBond USDG balance.

## 4. Exact single-fill capacity and transfer arithmetic

For positive buyback price P, NET native unit U=1e9, USDG factor F=10^(18-decimals), remaining WAD capacity C, and raw NET sold b:

```text
w(b) = floor(b*P/U)           // WAD USDG budget consumption
q(b) = floor(w(b)/F)          // raw USDG actually paid
bMax = ceil((C+1)*U/P) - 1
     = floor(((C+1)*U - 1)/P)
```

Derivation: floor(bP/U)<=C iff bP<(C+1)U. The formula is a mathematical bound; use overflow-safe full-precision evaluation, input/supply bounds, positive-price checks, and the external function's arithmetic domain. Include active/oracle checks; skip positive NET fills producing zero raw USDG. C=0 does not license zero-payout microfills.

`floor(C*U/P)` is safe but can underfill; decrementing it cannot find the maximum. The discarded sub-raw-unit value is never received by the SE and cannot be assigned to a user, vault or fee recipient. Capacity nevertheless debits w(b), not q(b)*F. Source: `N/InverseBond.sol:75–88`.

Taxable NET transfer receipt is exactly `T(g)=g-floor(g*t/10000)`, not floor(g*(10000-t)/10000). For positive required net n and t<10000, minimum gross is `floor((n-1)*10000/(10000-t))+1`. Resolve actual sender/receiver mappings and exemptions each relevant state. Ordinary user/SE/InverseBond endpoints are expected untaxed when neither is a taxed pair; a generic contract caller need not be an ordinary wallet. Source: `N/NET.sol:121–145,201–219`.

For a mixed zap, the pool-sale NET portion and the direct-deposit NET portion may each be taxed. They are different portions, not a blanket 10% tax on the entire input. An LP exit's pair→SE NET receipt may also be taxed before the splitter sees it.

## 5. Split sales: maximize final USDG

For one buyback-first call at fixed price p, in normalized continuous units with initial synchronized reserves X NET/Y USDG, AMM input receipt fraction a, swap multiplier gamma=.997, and operation-owned NET A:

```text
f(m) = Y*gamma*a*m/(X+gamma*a*m)
output = p*b + f(m)
b+m=A; 0<=b<=min(A,buybackCapacityInNET)
f'(m) = Y*gamma*a*X/(X+gamma*a*m)^2
```

Interior optimum satisfies f'(m)=p, with boundaries imposed by input and capacity. Compare marginal returns, not whole-trade average prices. A buyback can be useful even if the pool offers a better first-unit price, because subsequent pool marginal output declines. If p exceeds the initial pool marginal and the model's assumptions hold, capacity-first is valid for a pure sale; that special case is not a universal allocator and does not carry over to zaps.

For LP/share→USDG exits, burn the allocated LP first, including reference fees and tax, then apply the sale allocator to actually received NET plus the USDG already realized. Preview must project that same post-burn state. This is the existing DETF's USDG-output benefit.

## 6. NET-funded zap-in: three allocations, one LP objective

Split operation-owned NET A into:

```text
b = NET sold to buyback
m = NET sold to canonical pool
d = NET retained for liquidity deposit
A=b+m+d                         // before any explicitly returned residual
Q=buybackUSDG(b)+poolUSDG(m)
```

Three candidates must remain representable: pool-only conversion, buyback-only conversion, and mixed conversion. Buyback-only means no pool swap; the final LP deposit still occurs and changes pool reserves.

The objective is actual final LP tokens or user SE shares. It is not maximum intermediate USDG, and cannot be implemented by selling all capacity then using the old one-sided zap solver.

### Clean continuous model, not an implementation formula

Use previous notation plus deposit NET receipt fraction h and LP supply S; ignore integer floors, feeTo LP minting, reserve/balance divergence and SE fee dilution for this derivation:

```text
Q=p*b+f(m)
X'=X+a*m; Y'=Y-f(m)
L=S*min(h*d/X', Q/Y')
```

Balanced deposits require h*d/X'=Q/Y'. The gross NET/USDG sending ratio is X'/(h*Y'), not X'/Y'. For no pool swap (m=0):

```text
b=h*A*Y/(p*X+h*Y)
```

For mixed conversion the balanced constraint gives:

```text
b(m)=[h*(A-m)*(Y-f(m))-f(m)*(X+a*m)]
     /[h*(Y-f(m))+p*(X+a*m)]

L(m)=S*h*[p*(A-m)+f(m)]
     /[h*(Y-f(m))+p*(X+a*m)]
```

Optimize L over feasible m including buyback capacity, nonnegative d, one-venue endpoints and interior stationary points. This is a different objective from sale marginal equality. These equations do not prove an integer-optimal neighbor set or gas-bounded solver.

### Illustrative example: no fees/taxes, constant bid, not a live quote

Pool reserves 100 NET/100 USDG, LP supply 100, input 100 NET, buyback price 1 USDG/NET:

- Unlimited buyback: sell 50 NET, retain 50 NET, deposit 50 NET+50 USDG; receive 50 LP.
- Buyback limited to 20 USDG: sell 20 NET to buyback; a balanced mixed candidate sells approximately 22.4745 NET to the pool for 18.3503 USDG; retain approximately 57.5255 NET. Deposit that NET with approximately 38.3503 USDG against post-swap reserves 122.4745 NET/81.6497 USDG; receive approximately 46.9694 LP.
- Pool-only no-fee zap: sell approximately 41.4214 NET and receive approximately 41.4214 LP.

The mixed candidate demonstrates the requested composition. It is not an executable fee/tax quote or proof of global optimality. It also shows why rerunning the stock one-sided zap on the remaining 80 NET ignores the 20 USDG already obtained and gives the wrong allocation.

## 7. Reuse, exact execution, projection and residuals

`U/services/UniswapV2Service.sol:339–414` computes a pool-only sale then deposits. Its balancing helper does not accept the buyback's pre-existing USDG or replay NetNet transfer taxes. Reuse vetted primitive arithmetic and interfaces, not the unchanged orchestration.

`U/stubs/UniV2Router02.sol:41–84` chooses nominal optimal amounts and pulls only those amounts. It does not refund ERC20 leftovers. Ordinary nominal-ratio router logic is insufficient for a grossed-up NET deposit that is taxed in transit. Pair mint uses actual balance deltas. Use a tax-aware deposit composition/direct-pair mechanism that preserves net proportions and recipient limits, rather than silently donating the excess USDG.

Pair feeTo LP minting precedes user LP computation. Contrary to Grok's claim, `M/ConstProdUtils.sol:951–959` explicitly selects canonical `5*rootK+rootKLast` arithmetic for share16666–16667; it agrees with `_calculateProtocolFeeMint:984–995`. No formula replacement is justified by the alleged mismatch. Preserve actual fee recipient/supply/timing and initialization behavior.

Recommended residual policy for this new composition: minimize excess transfers and explicitly return operation-attributable unspent NET/USDG to the funding caller/router, with an approved recipient rule. This is a proposed addition, not a generic balance sweep or a claim that the reference exact-input routes already refund unused maxima. `contracts/vaults/basic/BasicVaultCommon.sol:108–137` only refunds bounded exact-output pretransfer credit and books remaining surplus on sync. Leaving an unbooked residual for later is not a payer-owned claim under the selected public pretransfer policy. Treasury's fractional payout truncation is a different issue and creates no SE residual token.

Execution-transition quotes must reflect venue allocations, capacity consumption, NET burn, treasury changes, actual pool-swap reserve movements, net deposit receipts, LP supply and SE-share mutations. Accounting valuation excludes ownership of unused public buyback capacity. The provider/preview coupling identified in round1 remains a required separation; canonical-only execution projections cannot describe a mixed execution.

Exact-output USDG requires minimizing total gross input with capacity and both floor layers. Exact LP/share output requires inverse of the full transition with forward verification and rounding residual semantics. No native InverseBond exact-output API exists. Preserve existing canonical exact-output routes; do not drop interfaces or substitute unbounded Newton iteration.

## 8. Execution order, call count and fallback

One buyback followed by at most one canonical swap, then a deposit, is a sensible bounded policy proposal, not a proof of global best execution. It supports both requested venue splitting and mixed zaps.

Order is not exactly independent: fee-retaining AMM swaps increase k and can increase treasury POL valuation and a later bid (`N/Treasury.sol:94–117`). A higher bid benefits the NET seller, although it can reduce NET capacity for a fixed USDG budget. Sequential buybacks can also increase the next bid because below-backing burns shrink supply faster than treasury value. Therefore repeated calls are not proven dominated; no recommendation should claim that one fill maximizes payout across arbitrary sequences.

Suggested product boundary: optimize within one explicitly selected sequence and at most one buyback call, with no arbitrary microfill/replay loop. If broader sequence optimization is desired, specify it separately with gas and integer bounds.

Before effects, read current capacity and recompute the allocation. If less buyback is available, recompute the entire mixed zap: preserve the needed NET deposit and re-solve the pool sale, rather than sending the old bid amount blindly to the pool. A specified fallback can catch a reverted buyback and recompute from restored operation balances. The reverted subcall undoes its internal pull/burn/payment; allowance and caller bookkeeping still need explicit handling.

Never weaken the original minUSDG/minLP/minShares/maxInput/deadline. Revert the complete operation if final limits cannot be met, including rollback of any prior successful legs. No canonical or buyback preview guarantees cross-block delivery, and a retry need not make a persistent treasury-withdrawal failure disappear. A user may set a minimum above the canonical-only quote; fallback then may legitimately be unavailable.

## 9. Unresolved proof and policy obligations

Confirmed feasible direction: use the buyback as one capped source of USDG for a proportional deposit, together with pool conversion when useful. The exact integer allocator is not completed or tested.

Remaining engineering work includes: rounding-complete capacity/input domains, optimizer exactness or documented error bounds, gas-bounded mixed allocation, exact-output inverse, full state projection, balance/reserve and fee-recipient edge cases, original-limit fallback, and deployed dependency parity. Evaluating a continuous stationary point and a few neighboring integers is not yet a proof under all tax/payout/LP floors.

Policy checkpoints, not repeated approval of split scope: call-count/order bounds; explicit operation-residual recipient rule; revert versus limit-preserving retry; exactness or acceptable bounded quality of the allocator. The existing custom-family no-required-exemption decision is not reopened. No arbitrary SDK, multi-block session, new fee, or invented dust token is required.

Moderator rejects residual report errors: MiniMax's conservative capacity quotient is not unsafe; its marginal/no-fee zap formulas are wrong; treasury fractional payout is not stuck at InverseBond; RFV is not unchanged by a cash-funded payout; protocol fee share is not a mutable per-pair rate under canonical V2; Astra's h-factor equation explicitly models taxed deposits. Kimi's claim of four-way canonical-floor-only preview agreement is unsupported; the moderator requires truthful projected execution plus original user limits. Grok's counterexample to the generic fee formula does not apply to the actual Uniswap special case. Passing research review is not economic/security proof.

## 10. Evidence and confidence

High confidence in ABI/capacity semantics, tax rounding, proportional-receipt requirements, source reuse boundaries and requested workflow feasibility. Medium confidence in the clean continuous optimization derivations and bounded execution-policy recommendation. No certification of integer global optimality, current liquidity, deployed equivalence, gas efficiency or profitability.

Sources inspected directly by the moderator include current CLAUDE, PRD:266–390, plan:475–569, canonical crane-architecture skill, N/InverseBond:64–141, N/Treasury:82–147, U/UniV2Router02:35–119, U/UniswapV2Service:335–429, M/ConstProdUtils:920–1029, and BasicVaultCommon:85–149. Prior-round directly inspected NET tax and SE execution/provider files remain cited above.

NetNet provenance remains 2026-08-28 source dump, deployed compiler0.8.30 versus Crane0.8.35 per VENDOR.md; not fresh runtime evidence. Upstream pair source is Solidity0.5.16, fetched from unpinned master. Context7 `/uniswap/v2-core` used before primary web research; its generated example prose does not supersede actual pair mint code (initial minimum liquidity is permanently locked, not awarded to the depositor).

Primary URLs accessed 2026-10-01:

- https://raw.githubusercontent.com/Uniswap/v2-core/master/contracts/UniswapV2Pair.sol — fetched directly.
- https://docs.netnet.capital/treasury — official search evidence this round; fetched directly in round1 and by researchers this round.
- https://docs.netnet.capital/mechanism — official search evidence.
- https://docs.netnet.capital/risks — official search evidence confirms public capacity is limited; no dated webpage depth number is adopted as live state.
- https://raw.githubusercontent.com/Uniswap/v2-periphery/master/contracts/UniswapV2Router02.sol — Astra primary fetch, unpinned master/Solidity0.6.6.

## Separate implementation handoff

None authorized. Research artifacts only were written. A subsequent documentation task can incorporate the accepted scope and resolved policy into PRD/plan; it must not invent completion of the mixed integer solver or authorize implementation merely by writing a plan. Stop at the human checkpoint.
