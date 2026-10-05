# Astra — leveraged wsNET combined cross-review

2026-10-03. Read complete Grok (109 lines), MiniMax (231), and Kimi (66) originals together. No cross-review artifacts read; originals frozen. This report is the only write.

**Notation:** B = `lib/crane/contracts/external/morpho/blue/`; N = `lib/crane/contracts/protocols/pol/net/src/`; R = `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`; H = `contracts/hooks/uniswap/v4/standardExchange/weighted/`.

## 1. Correct interpretation and source-level feasibility

**One pooled borrower vault with two alternative bound reporting providers is coherent.** It need not lend USDG, maintain user-owned Morpho positions, or sum those providers into NAV. My original preference for equity accounting is not a prohibition against deliberately headroom-priced trading. Grok's rejection for the current family describes present scope, not technical impossibility; MiniMax's supposed source-level impossibility is false.

`B/interfaces/IMorpho.sol:16–20` explicitly puts `supplyShares`, `borrowShares`, and `collateral` in the **same Position**. One address can hold all three; borrowing against posted collateral does not require redepositing proceeds. Separate ledgers exist inside the record. A pooled vault can manage `onBehalf=address(this)` without every shareholder authorizing Morpho (`B/Morpho.sol:466–469`). TurboRouter's user-owned positions are one implementation model, not a protocol requirement.

Third parties can fund `repay` and `supplyCollateral` without borrower authorization (`B/Morpho.sol:269–319`); authorization protects borrow/withdrawal. MiniMax's claim that outsiders cannot rescue a position is incorrect. Its forced per-user/nontransferable-share architecture substitutes another product for the requested pooled vault.

PRD **v0.36:172,327–340** and supply-only component D6 remain permission boundaries. A new borrower component/family amendment is required before implementation, not before evaluating viability. A liquidation also does not necessarily make an otherwise positive-equity pooled vault insolvent or erase all collateral.

## 2. Debt, headroom and share-accounting corrections

**MiniMax and Kimi omit Morpho virtual offsets.** After accrual, debt is `ceil(b*(A+1)/(T+1e6))`, not `ceil(b*A/T)` (`B/libraries/SharesMathLib.sol:20–43`; `libraries/periphery/MorphoBalancesLib.sol:109–118`). TurboRouter's simplified view is not the canonical debt calculator. Interest increases debt assets, not the borrower's shares; ordinary rebase/interest alone does not invalidate an exact-full-share repayment count, contrary to MiniMax.

For raw collateral c, raw USDG debt D, oracle P scaled 1e36, target t scaled 1e18, fixed positive P,t:

```
V = floor(cP/1e36)
cRequired = ceil(ceil(D*1e18/t)*1e36/P)
W = max(c-cRequired,0)
Hbudget = max(floor(V*t/1e18)-D,0)
```

This gives Grok a closed W inverse under the stated snapshot assumptions: invert the two nested floors successively. New borrowing still requires replaying share rounding and liquidity checks. MiniMax reverses W's sign and uses LLTV instead of target for H. Those are not the requested capacities. At zero debt, **W=c**, not infinity; TurboRouter explicitly returns zero LTV at zero borrow shares (`N/lending/TurboRouter.sol:313–323`).

In continuous whole-token units, with price p and target τ:

`H=max(τpC-D,0)=τpW`.

**Kimi's sum identity is wrong.** Joint actions x collateral withdrawn and y additionally borrowed obey `τpx+y≤τpC-D` when initial slack is nonnegative. Separate maxima are not simultaneously spendable; partial actions can coexist. Grok's “mutually exclusive” therefore applies to exhausting either maximum, not to every combination. Cash-capped executable H need not equal τpW.

At target, W=H=0 although E=pC−D>0. Kimi's “either headroom as NAV overstates” is too broad: it can understate equity or erase it. The objection is wrong claim semantics and route-dependent issuance, not always numerical overvaluation. Above-target, liquidatable, and insolvent are distinct conditions. Deposits/repayments **can** restore target, contrary to Kimi's blanket wording.

MiniMax's “repayment must burn shares” conflates **Morpho debt shares** with vault equity shares. A funded USDG capital contribution used to repay debt increases equity and can mint fairly priced vault shares. A gift mints none. No phantom equity burn is warranted. Donations do not inherently print infinite shares: that depends on defective zero-state/accounting rules, not the existence of a headroom view.

My equity-accounting recommendation stands: price funded issuance/redemption against coherent pre-operation equity, allocate actual costs, and preserve remaining debt ownership. If deliberately choosing custom headroom prices, specify the resulting transfers of value rather than claiming ordinary pro-rata equity fairness.

## 3. Unwind feasibility and restrictions

Agreement: repayment callbacks can finance an unwind without an external flash loan. Morpho reduces debt before callback, then pulls repayment assets (`B/Morpho.sol:281–295`). A callback may withdraw, unwrap/unstake, sell, and pay debt; full conversion can leave **only USDG**. Conversion costs and available proceeds, not endpoint labels, govern feasibility.

Important qualification to Grok/Kimi's liquidity/oracle discussion: collateral withdrawal does **not** require available USDG loan liquidity (`:323–341`); borrowing does (`:258–259`). Full-share repay makes health return true without reading the oracle (`:515–538`), enabling debt-free collateral withdrawal even if LoopbackOracle reverts. Partial debt-bearing exits still need the health read. Swap/InverseBond and external transfer failures remain separate blockers. Do not unnecessarily impose a broken valuation read before risk-reducing full-close execution.

TurboRouter settles up to eight rebases before **turbo**, not before every unwind; unwind processes staking touches in its callback (`N/lending/TurboRouter.sol:163–167,264–275,302–307`). Treat that loop's resource bound as an engineering question, not a proven bounded keeper guarantee.

## 4. Oracle, yield and concentration

MiniMax's oracle expression omits `/1e9` for the nine-decimal index; its upper cap is **5× backing**, not backing (`N/lending/LoopbackOracle.sol:66–75`). Stale/divergent oracle **reverts**, rather than lowering its price to the floor. Constants alone do not certify deployed warmup. sNET supply changes during rebase (`N/StakedNET.sol:83–98`), contrary to MiniMax's constant-supply claim.

**Queued emissions matter:** current below-NAV premium stops new rewards, but a previously funded queue may still increase index on the next processed rebase. Thus Grok/Kimi's instantaneous “below NAV implies flat index” needs qualification (`N/Staking.sol:134–150`).

MiniMax's arithmetic `0.0045*(.04/.75)*1095=.2628` is **26.28% simple annualized**, not .26%, and is not APY or a current rate. More importantly, Distributor reward uses NET total supply, while funded holder growth depends on queued profit divided by circulating staked participation (`N/Distributor.sol:56–69`; `StakedNET.sol:86–97`). Neither a premium threshold nor “normal borrowing APR” establishes positive carry. Report equity/share performance net of external contributions, not total collateral growth from new deposits or donations.

All correctly reject an unconditional majority-supply price floor. Encumbrance may influence demand/float, but marginal trades and liquidation exits can still move NET below the discounted, capacity-limited buyback. Rebase, oracle credit and liquidation realization remain distinct risks.

## 5. Provider compatibility and constructive choices

**Kimi's empty-provider claim is stale:** current `R/StandardExchangeRateProviderFacet.sol:90–94,147–165` attempts an initial rate by inverting a unit deposit; it returns zero only when that probe fails/returns zero. Actual zero configured rates are explicitly rejected by `H/…HookClaimLib.sol:94–100`, not merely an unverified domain concern. MiniMax's “zero rate in the borrow sense” does not address this behavior.

Two selectable providers are legitimate. Adding W/H or reading the same full share balance twice is not legitimate portfolio accounting. Independent claims could exist with explicit partition/waterfall; Kimi's “insolvency by construction” is too absolute.

**Constructive alternatives:** (A) pooled transferable equity shares plus two bound capacity providers and route management; (B) a custom headroom-priced hook with separate ownership accounting, shared-slack transitions and explicit zero-headroom behavior; (C) separate leverage DETF if different reserve/issuance economics are desired. None requires user-owned positions or suppressing the original goal.

**Falsifiable gates:** no unbacked claims across NET/sNET/wsNET/USDG round trips; projected and executed debt/target inequalities agree; full redemption clears liabilities; zero-headroom positive equity remains represented; changing target alone mints no equity; costs/donations are attributed once; partial and full closes work under their declared oracle/cash failure matrix. Unresolved: custom pricing distributional effects, target/bands, conversion-cost budget, maintenance incentives and crisis policy.

Confidence **high** on cited mechanics/math; **medium** on architecture recommendation; profitability and live compatibility unproved. Sources: current local code, Blue v1.0.0 vendor baseline, NetNet 2026-08-28 dump, PRD v0.36/plan v0.10. Primary source previously accessed 2026-10-03: https://raw.githubusercontent.com/morpho-org/morpho-blue/main/src/Morpho.sol . No new execution or live-state claims. This completes Astra's bounded round.
