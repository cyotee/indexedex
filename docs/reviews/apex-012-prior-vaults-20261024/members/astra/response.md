# Identity

- Run ID: apex-012-prior-vaults-20261024
- Member label: astra
- Profile: research
- Phase: initial independent response
- Owned path: /Users/cyotee/Projects/indexedex/docs/reviews/apex-012-prior-vaults-20261024/members/astra/response.md
- Requested role: council-member
- Requested model: chatgpt-subscription/gpt-6-astra:high
- Actual model, account route, and reasoning setting: not exposed
- Peers read before submission: no

# Question and targets

What can IndexedEx take from the completed vault survey for APEX-2026-012's liquidity-manipulation claim?

Read targets:

- `.omo/ulw-research/20261023-171500/SYNTHESIS.md`, cited below as synthesis.
- `.omo/ulw-research/20261023-171500/sources-ledger.md`, cited by S-number.
- `docs/reviews/apex-012-auditor-claim-20261024/REPORT.md`, especially "What the auditor claims," "The auditor's fix, not adopted here," and "Against the clarification."

The relevant distinction is between **pricing a holder's entitlement from a hypothetical sale through other people's liquidity** and **returning the holder's share of assets**. The survey primarily tested a different property: whether a one-token view rate reads same-pool spot. Passing or failing that property does not establish resistance to the depth-only claim.

# Evidence

| Inspected design | What the admitted evidence establishes | Relevance to this liquidity claim |
| --- | --- | --- |
| IndexedEx UpperLowerWings | `getRate` uses the liquidation quote; the quote simulates selling the opposing token. The claim report adds that deposit and redeem use live `slot0`, liquidity, and the tick bitmap, excluding only the vault's own liquidity. Sources: S2-S3; synthesis, "Quote functions in the recommendation set"; claim report, "What the auditor claims." | This is the demonstrated depth-dependent design in the admitted report. Adding third-party depth improves the simulated sale and increases the payout quote without a corresponding contribution to the vault. The settled path means blocking unlocked calls or removing the sleeve is not sufficient. |
| Gamma V4 | `WithdrawLogic` values shares using `poolManager.getSlot0`. Sources: S13; synthesis, "Quote functions in the recommendation set." | Live spot remains part of withdrawal valuation. The survey does **not** establish that this withdrawal formula reads external depth or suffers the same fixed-price added-liquidity attack. It is not an evidenced remedy, but its spot read alone does not prove the liquidity claim against Gamma. |
| Arrakis V2 | `Underlying.underlying` reads `slot0`, calculates token amounts from liquidity, and returns two amounts. Sources: S4; synthesis, "Executive summary" and "Quote functions in the recommendation set." | The surveyed two-token entitlement differs from Wings' hypothetical one-token liquidation. It remains spot-sensitive, but the survey does not show that adding someone else's depth at unchanged spot increases those principal token amounts. This is a historical structural precedent, not a current deployment recommendation: the survey records V1/V2 deprecation in S24. |
| Charm | `getTotalAmounts` / `_amountsForLiquidity` reads `slot0`; shares represent pro-rata claims on two token amounts. Sources: S14; synthesis, "Executive summary" and "Quote functions in the recommendation set." | Like Arrakis V2, this supports studying a two-token pro-rata entitlement rather than pricing an opposing-token sale. It does not establish an invariant one-token payout, and its amounts still vary with spot. |
| Steer | `getTotalAmounts` returns two tokens and the integrator supplies a market price. Sources: S15; synthesis, "Quote functions in the recommendation set." | This separates inventory reporting from valuation, but delegates the consequential choice. The survey does not establish a withdrawal formula or depth-independent settlement. An integrator could put the same vulnerable liquidation quote back on top. |
| Panoptic CollateralTracker | `convertToAssets` uses stored `s_poolAssets + s_inAMM`, rather than live pool spot. It is options collateral, not an LP vault. Sources: S16; synthesis, "Executive summary" and "Quote functions in the recommendation set." | The inspected conversion is not repriced merely because an unrelated caller adds pool depth, assuming its stored accounting and share supply are unchanged. This supports a conversion-accounting pattern, not proof of a complete fee-earning LP withdrawal mechanism with the required payout invariant. |
| Maker GUniLPOracle | External USD oracles supply a valuation price; `peek` / `read` return the last `poke`; `poke` is time-limited. `seek` still calls the vault, and Arrakis V2 underlying accounting still reads `slot0` for the fee tick even with a supplied price. Source: synthesis, "Alternative precedent, not the recommendation," identifying commit `0d25676e0956fc3a5359431c708106547c4fef26`. | A cached mark does not change between updates merely because live depth changes. The survey does not establish that a vault pays withdrawals at that mark, that the mark is continuously realizable, or that refreshes cannot absorb manipulated inputs. |

# Conclusions

## 1. Live spot dependence is not proof of live depth dependence

**Wings is the clear affirmative answer for live-depth-priced withdrawals. Gamma V4, Arrakis V2, and Charm are affirmative answers for live-spot-sensitive valuation or token amounts, but they cannot all be labeled susceptible to this liquidity attack on that basis.**

For Wings, the adverse mechanism is explicit in the claim report: deposit at the honest value, add liquidity, redeem against the inflated liquidation value, then remove liquidity. The remaining holders fund the difference. That is stronger and more specific evidence than the survey's old classification, "This is the bug" (S2-S3; synthesis, "Quote functions in the recommendation set").

For Gamma V4, the survey establishes a live spot mark, not the effect of changing depth while holding spot fixed (S13). For Arrakis V2 and Charm, the same limitation matters in the other direction: their two-token approach may avoid the hypothetical-sale channel even though it failed the survey's spot-independent, one-token-rate requirement (S4, S14). The premise "reads slot0, therefore does not stop this claim" is too broad.

## 2. Two useful precedents, with narrower guarantees than a complete fix

**Arrakis V2 and Charm: pro-rata two-token settlement.** The useful inference is that, at fixed spot, fixed vault-owned liquidity and inventory, fixed accrued fees, and fixed supply, merely adding another LP's liquidity need not change the holder's two-token principal entitlement. There is no need to value a hypothetical sale through that added depth to determine the token pair owed. This addresses the depth-only mechanism by changing what is owed, not by producing an invariant single-token liquidation value (S4, S14; synthesis, "Executive summary" and "Quote functions in the recommendation set").

The cost is the **one-token exit**. The holder receives two assets and bears any subsequent conversion. LP fee earning need not be abandoned by this structural choice, but amounts remain spot-sensitive. Adding an automatic one-token conversion would require a separate settlement analysis; the surveyed pro-rata precedent does not certify that extension. Arrakis V2 also carries the recorded deprecation limitation (S24). Neither protocol should be presented as already proving the full Wings lifecycle safe.

**Panoptic: stored single-token conversion accounting.** An external liquidity change cannot directly change a conversion formula whose inputs are unchanged stored assets and supply. That is a useful accounting property (S16; synthesis, "Executive summary"). It is not evidence that Panoptic supplies the requested combination of LP swap-fee earning, immediate one-token withdrawal, and depth-independent payout.

The cost or unresolved requirement is the connection between **accounted value and assets actually available for payout**. Panoptic's inspected contract is options collateral. The survey does not document a drop-in Uniswap LP equivalent or establish the applicable withdrawal restrictions. It therefore does not support promising unrestricted immediate redemption or claiming that a specific fee stream is retained.

The synthesis's own "Recommendation" proposes retaining LP swap-fee earning while crediting target tokens only on settled accounting events and leaving the other token outside the rate until conversion. That records a tradeoff: unconverted inventory and uncredited fees are absent from the published rate. It does not prove how a complete vault realizes one-token exits, allocates conversion results, or prevents depth-sensitive accounting events from changing holder payouts. This is a proposed pattern, not an inspected protocol implementing the whole answer, and not an adopted IndexedEx decision.

## 3. A cached external mark is a weaker, conditional precedent

**Maker GUniLPOracle** supports insulating a *published mark between updates* from transaction-local pool changes. It does not establish an invariant withdrawal payment. The recorded cost is freshness: reads return the last `poke`, with the synthesis reporting a default one-hour `hop`. The mark is not demonstrated to be a continuously executable one-token rate. It also introduces external-oracle and refresh assumptions; the recorded live fee-tick read prevents describing the underlying valuation path as wholly detached from pool state (synthesis, "Alternative precedent, not the recommendation").

The survey does not show that this choice requires giving up LP fee earning. Nor does it show that preserving fee earning is enough to make redemption at the cached mark solvent or fair. Using it as a complete fix would exceed the admitted evidence.

**Accordingly, the survey proves no inspected design delivers all three of fee earning, continuously available one-token exits, and payouts invariant to permitted liquidity changes.** It supports a two-token entitlement alternative and a stored-accounting conversion alternative, each with the limits above. The cached-oracle precedent is evidence about publication, not settlement.

## 4. Findings that must not be carried over as liquidity-claim answers

- **Visor 2021 and Gamma 2024:** their recorded incidents concern spot-priced minting and a single-sided deposit-ratio exception with price manipulation. They do not establish the added-depth mechanism or validate a remedy for it (S22-S23; synthesis, "Exclusions from primary postmortems").
- **ICHI and Revert:** a spot/TWAP guard or an oracle switching from `slot0` to `observe` addresses a price input. The survey provides no invariant against added liquidity at unchanged spot. ICHI's current Solidity was not inspected (S9-S11, S17; synthesis, "Gaps"). These are not supported liquidity-claim fixes.
- **Arrakis modular/Pro and Steer:** a rebalance oracle, a rate consumed by a strategy, or an instruction that the caller apply market prices does not establish safe share settlement (S5-S8, S15). The missing withdrawal guarantee must not be supplied by inference.
- **Balancer's ERC4626RateProvider:** forwarding `getRate` to `convertToAssets` does not constrain what the underlying conversion reads or how redemption pays. S21 was not independently reread by the survey lead. Interface compatibility is not economic protection.
- **Panoptic and the synthesis recommendation:** removing pool reads from `getRate` alone is insufficient if deposit, redemption, or accounting updates still transfer value using the manipulated quote (S16; synthesis, "Recommendation" and "Exclusions from primary postmortems"). The prior recommendation is evidence of a proposal, not an owner decision or a proven payout invariant.
- **Bunni v2 and unresolved candidates:** the exploitation warning is not evidence of this particular failure mechanism, and the unread postmortem cannot supply one (S18, S25). The gaps for other surveyed candidates cannot be turned into suggested fixes (synthesis, "Gaps").

# Limits

This response interprets the admitted synthesis, source ledger, and claim report. It does not independently inspect protocol implementations or reopen listed URLs. The stated attack outcomes are the claim report's account, not reproduced results. The fixed-spot pro-rata argument and unchanged-storage argument are explicitly conditional inferences, not completed protocol security reviews.

No peer responses were read. No new protocol search, sub-agents, Forge, tests, Git, installs, implementation, or Wings redesign were undertaken. The survey does not support an unconditional claim that any inspected vault preserves a continuously executable one-token payout through every permitted liquidity change.
