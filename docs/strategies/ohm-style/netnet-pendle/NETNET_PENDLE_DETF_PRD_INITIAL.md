# NetNet–Pendle Liquidity Acquisition DETF — Initial PRD

- Version: 0.1 — preserved initial review draft.
- Prepared: 2026-09-21, using the environment date. Earlier conversation sources also carried 2026-09-17 annotations; neither date certifies live deployment state.
- Status: **research/product draft; not implementation or deployment authorization**.
- Intended consolidated document: `NETNET_PENDLE_DETF_PRD.md` in this directory.
- Scope: proposed NetNet-specific, epoch-aware DETF family; unified Pendle strategy custody, SE facades, canonical V2 USDG liquidity leg, external NetNet bond wrapper, and PENDLE harvesting.
- Document owner: council moderator. This initial version must remain unchanged during the review round.

## 1. Purpose and success criteria

The product accumulates collectively owned Pendle liquidity. It may deliberately prefer greater durable principal liquidity over the return from holding YT alone. Public arbitrage is an intended executor of strategy management, not a condition the product seeks to eliminate.

Measure Pendle exposure in underlying-equivalent units, separately by maturity; raw LP-token counts across different markets are not comparable. Report net acquisitions, income converted into principal, asset retention, fees, tax, execution costs, external capital contributions, liabilities, and backing per outstanding DETF. Deposit-funded growth and newly emitted NET must not be labeled investment profit.

There is no guarantee of positive income, preserved USDG value, a sustained NET premium, a rebase, permanent removal of NET from circulation, or superior returns to YT-only or unlevered staking alternatives.

## 2. Authority, terminology and boundaries

This document records the user's selected design direction and identifies unresolved requirements. It does not supersede `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, or `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` D32–D66 / §24. A later approved specification must enumerate any authorized departures before implementation.

**Current policy conflicts:** NET is conditionally fee-on-transfer; sNET is a rebasing underlying. The repository currently forbids both as configured underlying token classes. The user has selected taxed canonical NET/USDG liquidity economically; that does not constitute an implemented or silently approved policy exception. No exemption, allowlist or alternate token face is invented by this draft. An active tax exemption does not itself change the repository policy. This is an implementation blocker, not an unresolved choice of venue.

Current DETF law mandates reserve-swap fallback, first-bond-anchored expansion epochs and funded linear bond vesting. This proposed family selects removal of automatic fallback and underlying-state synchronization, and explores different locks and issuance routes. These differences require explicit reconciliation; existing Universal DETF behavior must not be silently changed.

Use production role names (`rateAsset`, `pairToken`, `vaultShare`, `detfToken`, `rebasingClaimToken`) rather than hardcoding product names. NET/sNET/USDG are economic denominations in this draft until approved token surfaces and route bindings are specified. DETF, sDETF and their wrappers retain current nine-decimal requirements unless expressly superseded; normalize each external asset according to verified metadata.

Distinguish three LP types: Pendle market LP, canonical NET/USDG V2 LP, and the DETF's own V4 reserve-hook LP. They are not interchangeable assets or entitlements.

## 3. Selected requirements

| ID | Requirement selected in the discussion |
| --- | --- |
| R01 | Principal objective: grow common Pendle liquidity using capital entry, managed income and public trading. |
| R02 | One unified Pendle strategy vault holds and manages LP, retained YT, earned claims and related cash. SE-compatible facades provide contextual entry points to that same state machine. |
| R03 | Capital routes assigned Keep YT acquire PT/SY LP and retain the associated YT. Direct LP bonds instead acquire ordinary PT/SY LP without retaining additional YT. |
| R04 | Public reserve swaps remain available and intentionally invite economically useful arbitrage. Incoming external assets can be deployed as ordinary Pendle LP while earned income funds output. All acquired LP is common backing. |
| R05 | The USDG leg is a real canonical NET/USDG V2 position held through an SE vault and rated in USDG. It replaces virtual USDG for the selected first version. |
| R06 | Applicable NET tax is accepted as an operating cost. Previews and execution account for every taxable transfer and automatically recognize active endpoint exemptions. |
| R07 | Valuation uses current holdings and actual YT coverage. Principal-bundle value and separately accrued income are counted once. |
| R08 | Synchronization uses NetNet's processed epoch state, not an assumed wall-clock delay. |
| R09 | Rollover is an explicit permissionless operation receiving a target market and validating it. Already deployed active markets are eligible candidates; self-creation is not mandatory. |
| R10 | At Pendle expiry, operations requiring new LP deposits into that market revert; principal-exit paths remain subject to actual funding and supported conversion routes. |
| R11 | The new family does not automatically substitute a reserve swap for a blocked primary operation. Public pool trading is separate. Primary eligibility and failure behavior remain open. |
| R12 | An optional external NetNet bond position uses the user's claimed reserve portion and is represented by a wrapping NFT. Collected NET must reenter NET-DETF, be staked and remain locked under that same NFT. |
| R13 | Attributable PENDLE incentives go to the current `feeTo()`. YT-derived SY interest stays in the strategy. The future PENDLE-DETF is outside this release. |

## 4. Architecture and custody

```text
Uniswap V4 DETF reserve: self-leg + configured external legs
  ├── Principal SE facade ──┐
  ├── Income SE facade ─────┴── Unified Pendle strategy vault
  │                             ├── Pendle LP
  │                             ├── Retained YT
  │                             └── Accrued SY / claimed income
  └── USDG-targeted V2 SE ────── Canonical NET/USDG V2 LP

Separate user-owned bond-wrapper accounting
  └── NetNet bond notes → harvested NET → locked staked NET-DETF
```

Facades are not required to have independent physical inventory or different economic beneficiaries. They identify quote/settlement context while the unified vault controls backing and updates all affected representations. "Facade" does not prescribe Solidity `delegatecall` or a deployment technology.

Every facade must have defined token/share ownership, mint/burn authorization, transfer/approval behavior, buffering/unbuffering, rate units and settlement authority. A shared getter alone does not establish hook compatibility. Projected changes through one facade must be visible when another facade quotes the same transaction.

Orbital, Curve-style stable, Balancer-style stable on V4, and Weighted are candidates. Selection of one initial host versus multiple variants is OPEN. Balancer-style mathematics on V4 is not a Balancer-hosted DETF excluded by D60. No new host or successful reuse of every existing host is asserted.

Preserve actual protocol ownership through the outer reserve LP and facade shares. Externally owned hook LP or SE shares must not be included in DETF-owned backing. Existing funded sDETF custody is not spendable strategy capital.

## 5. Acquisition and route requirements

| Operation | Intended asset transition | Unresolved details |
| --- | --- | --- |
| Keep-YT capital entry | Input → eligible SY; tokenize part into PT+YT; add PT plus remaining SY to liquidity; retain YT | Exact input list, allocation, whether all such entries require bonds |
| Direct liquidity bond | Payment → ordinary Pendle PT/SY LP without additional retained YT; purchased DETF enters staking/escrow | Pricing, incentive treatment, cliff versus linear release |
| Elected income reinvestment | Attributable existing income → Keep-YT position; participation converted into the selected short lock | Eligibility, ownership debit and exact unlock event |
| USDG leg deposit | USDG → taxed NET/USDG V2 liquidity → SE shares | Tax-aware zap split and sleeve/buffering behavior |
| USDG leg withdrawal | SE shares → V2 LP withdrawal and required conversion → USDG | Net output, tax, impact and cost attribution |
| External NetNet bond election | Authorized user reserve entitlement → USDG or eligible V2 LP → external bond note | Primary-redemption authorization and payment selection |

An ordinary Pendle LP is not naked PT. Adding LP without YT changes aggregate YT coverage. Buying YT alone is not an equivalent route to acquiring an LP+YT bundle; any future optimizer must compare defined terminal inventories and the liquidity-acquisition objective, not unrelated APYs.

Candidate inputs discussed were USDG, NET, sNET, series-specific PT/YT and SE shares. This list is not a promise of deployable support. Token policy, exact direction, available maturity and immutable route discovery must be resolved. Stable strategy shares may roll between markets; arbitrary future PT/YT addresses do not automatically appear in fixed DETF route tables.

## 6. Public swaps as management

Immediate processing into productive positions is the selected starting premise, not a promise that no transient cash, rounding dust or unjoinable residual can exist. Do not assume cross-protocol callbacks or pool locks are absent.

For eligible external-token trades, the intended policy sells earned income while acquiring ordinary Pendle LP. Common income is deliberately exchanged for common principal; one displayed reserve decreasing while another increases is not inherently improper.

The USDG leg uses its own V2 buffering and redemption policy. The final route matrix must specify how cross-leg operations compose this with Pendle acquisition. The same inbound token amount cannot simultaneously fund both V2 and Pendle positions.

| Trade class | Accounting requirement |
| --- | --- |
| External token → another external token | Debit actual delivered output; assign actual acquired position and costs once |
| External token → existing NET-DETF | External assets may increase strategy backing; the sold DETF comes from existing inventory unless a separately authorized issuance occurs |
| NET-DETF → external token | Received DETF is reserve inventory, not new external investment capital; it remains outstanding unless explicitly burned |

NET and sNET payout concepts can draw from the same earned SY. Shared liquidity must be debited once and all affected facade states updated coherently. Existing exclusive payables are unavailable to common management operations.

The curve should discourage crossing from income settlement into LP liquidation. Exact curve, fee/spread policy, liquidation boundary and behavior at zero income are OPEN. Distinguish backing valuation from any management-oriented pricing adjustment, including its effect on synthetic pricing and expansion. Profitable arbitrage can be intended compensation; no requirement of zero arbitrage profit is imposed. Repeated extraction caused by stale or contradictory state is not an accepted strategy expense.

## 7. Accounting, valuation and primary exits

Common assets comprise the Pendle principal bundle, attributable accrued income, claimed cash and owned V2 exposure. Count shares or their underlying assets, not both. A joint LP+YT exit valuation includes consumed YT; do not additionally add its residual value elsewhere. Claiming moves a receivable into cash; it does not create a second gain.

User-segregated external bonds are excluded from common backing. Alternatively, consolidated reporting may include those assets with their matching liabilities deducted exactly once. PENDLE earmarked for `feeTo()` is excluded from holder NAV or offset by an explicit payable. Never both exclude an asset and subtract it again as a liability.

If primary proportional redemption is selected, attribution follows actual protocol-owned reserve LP and facade entitlements, including the self-leg and external LP ownership. A conceptual entitlement `q` yields component allocations `qC`, `qL`, `qY` (plus the attributable V2 component), not an unrestricted claim on all common cash. Process the entitled income first, then the entitled principal bundle. This is not the public swap pricing rule. Availability, gates, eligible assets and post-lock rights remain OPEN.

Before expiry, pair withdrawn PT with only the YT allocated to that exit. Define the treatment of unmatched PT and excess YT without borrowing another claimant's entitlement. After expiry PT can redeem without YT; historical earned claims remain attributable to the earning address. Equal initial capital or costless maturity transition is not guaranteed.

Distinguish current inventory accounting, protected issuance/expansion valuation, and executable trade-size output. The current StandardExchangeRateProvider samples share-conversion previews and scales them; it is not automatically a whole-position liquidation oracle. Compatibility with facade-dependent changes must be demonstrated.

## 8. Canonical V2 USDG leg and tax behavior

Selected chain: Robinhood mainnet, `4663`. Selected pair: `0x59F95461E68e0c77605299791E1449f175165B54`. Verify deployed token identities, factory, fee parameters and code before implementation. Standard V2 LP fee behavior is background evidence, not live fee certification. NET's transfer tax is separate from market-maker fees.

Read `taxEnabled()`, `taxTotalBps()`, `isTaxedPair(address)` and `isTaxExempt(address)` from the actual NET contract. For gross transfer `x`, if tax is enabled, neither endpoint exempt, and either endpoint mapped:

```text
tax = floor(x * taxBps / 10000)
received = x - tax
```

Otherwise expected receipt is `x`. Apply the predicate to every actual transfer endpoint, not a generic "vault exempt" flag. Active exemptions automatically select the correct branch; queued exemptions do not. No owner-maintained false tax override is proposed. This design does not depend on NetNet granting an exemption.

NET transfers on swaps, joins and LP burns may be taxable. A zap can incur multiple taxable transfers; the V2 LP token transfer itself is not NET tax. Pair-reported gross outputs may differ from what the vault receives. Net-input constant-product mechanics remain valid; nominal-input route assumptions must be corrected.

Previews must include the actual route, tax state, exact rounding, DEX fees and price impact. Execution measures received assets and LP, preserves the pre-operation snapshot, excludes pre-existing balances from contribution credit, and enforces final recipient minima. Mint shares against actual acquired backing. Known tax must not be hidden in a generic slippage allowance. Costs of user operations and authorized collective management must be attributed explicitly.

## 9. Epoch synchronization and previews

Net staking exposes `epoch() → (length, number, end, distribute)`. The inspected implementation applies the previously queued distribution when circulating stake exists, advances one epoch, then checkpoints and requests the next distribution. `Distributor.nextReward()` is prospective; it is not the already funded queued amount.

Use verified epoch state and a last-processed marker. A timestamp grace such as 60 seconds may be considered but is not proof of execution. Zero reward is valid. Do not require positive yield to release funds or permanently block settlement.

Previews must model the same ordered transitions as execution from the same starting state: underlying processing, claim/index changes, applicable DETF expansion, tax, quote, issuance, staking and lock attribution. They must not invent historical prices, predict unknown future transactions, or count unminted projected rewards as already funded balances. Underlying catch-up and DETF catch-up are separate operations.

NET rebase eligibility, DETF synthetic expansion and Pendle maturity are distinct concepts. Exact new-family expansion formula, epoch participation snapshot, handling of near-boundary entries and delayed processing remain OPEN. Synchronization is selected; reverting to the first-bond clock is not silently selected as an alternative.

## 10. Locks and issuance

Three position classes require explicit release schedules:

1. Elected income reinvestment: intended short commitment associated with an underlying processed epoch.
2. Direct ordinary-LP bonds: intended commitment to Pendle market maturity.
3. External NetNet bond-wrapper NFT: all proceeds reinvested, staked and retained under that NFT until its approved release condition.

For each, decide cliff versus linear release, final unlock, partial harvests, rewards during lock, minimum holding time, boundary eligibility and whether rollover changes any date. No schedule is invented here. A duration ending at maturity is not equivalent to a maturity cliff.

Bond-only fresh issuance and disabling direct staking were proposed, but the final entry/exit matrix is OPEN. Public swaps stay available. Removal of automatic fallback does not decide whether primary gates remain or what failure returns.

Elective conversion of already owned equity into locked participation must preserve its value except explicit costs/incentives. If implemented through burn/reissue, it is not automatically the ordinary incentivized bond path: do not manufacture a new matching self-leg, duration bonus or recursive rewards merely by recycling the same capital. Funded staking backing must not be spent on LP acquisition.

## 11. Rollover and expired-market operation

Expose a permissionless explicit rollover operation taking `targetMarket` (name/signature is conceptual). A target may be an existing active market; missing reverse lookup is not a requirement to create one's own market.

Validate trusted deployment provenance; SY/PT/YT and underlying identity; future expiry; applicable maturity window; usable liquidity and initialization; fee/curve configuration; and execution bounds. Numerical bounds and selection rules are OPEN. A caller cannot redirect assets or choose economically unconstrained parameters.

Settle attributable old LP, matured PT, earned interest and incentives; acquire the selected successor position; preserve all collective and NFT liabilities. The successor acquisition mode and treatment of residual old assets are OPEN. Preserve access to historical earning addresses after rolling.

When a market expires, reject any operation requiring a deposit into its LP. Preserve supported principal exits; do not imply expired YT continues earning. Document which public swaps remain executable without depositing into expired LP. No new mint or trader activity is required just to make a rollover trigger callable.

Whether rollover is atomic or a rigorously specified staged process is OPEN. Partial failure must not produce duplicate claims or stranded user rights. New-market oracle readiness, zero-income bootstrap, maintenance incentives and stale pricing require explicit policies.

## 12. External NetNet bond-wrapper feature

The user elects to move their authorized portion of DETF reserves into a NetNet protocol bond. Burn the surrendered DETF only as part of the successfully funded purchase; do not leave the same claim outstanding in the common reserve.

Inspected NetNet interface:

```text
deposit(marketId, amount, maxPriceWad, to) → (noteId, payout)
market 0: USDG payment
market 1: canonical NET/USDG V2 LP payment
redeem(to): collect all currently vested notes owned by msg.sender
```

LP payment is valued at NetNet's RFV formula, not full market exit proceeds. Compare direct LP payment against taxed liquidation into USDG under the selected policy; do not force either market. Include deadline, minimum payment proceeds, maximum bond price and minimum NET payout in the composed operation. Enforce actual receipt and external capacity/freshness failures atomically.

The depository mints the entire NET payout into itself at purchase: vesting is funded, not an expectation of future minting. Native notes are `notes[owner][noteId]`, not transferable NFTs. Local code uses two-day linear vesting while older interface prose mentions five days; verify deployed code and note timestamps.

A wrapper NFT must control the external note entitlement. Depositing a note directly to a user does not give a separate NFT control over it. Determine safe note custody, provenance and authorization before implementation. User-exclusive notes and proceeds are not simultaneously common DETF backing.

**Mandatory reinvestment:** every collected vested NET amount must enter the NET-DETF strategy, produce DETF against actual contributed assets, be staked, and remain attributed and locked under the same wrapper NFT. This supersedes earlier discussion of optional raw NET or immediately unlocked staking payouts. The user cannot withdraw these intermediate proceeds through an alternate claim route. Reinvested principal is not free protocol earnings.

Track unclaimed external notes, harvested pending NET, minted DETF and staking receipts as stages of the same entitlement. If NFT transfers are enabled, transfer control over every remaining component exactly once. Release and retirement conditions are OPEN. If reinvestment fails, either the whole harvest reverts or pending NET stays segregated and locked; this failure policy is OPEN, not permission for an unrestricted raw-NET escape.

**Engineering blocker:** anyone may buy notes for an arbitrary recipient, while native redemption iterates all the caller's notes. Unsolicited notes can enlarge an escrow's redemption workload. Separate escrows do not by themselves eliminate this risk; wrappers cannot reject upstream deposits without a callback or add missing upstream per-note/batch redemption. Establish a viable attribution and liveness design before implementation. The external-bond wrapper and existing DETF purchase-bond NFT are distinct obligations even if components are reused.

## 13. Pendle incentive collection

Discover market reward tokens and claim rewards attributable to the actual LP-holding custody address. Inspected Pendle V7 market reward accounting is integrated with LP holdings; separate external gauge staking is not assumed. `redeemRewards(user)` pays the entitled user, not necessarily the caller. Verify any external wrapper/custodian separately.

Forward attributable PENDLE incentives to the dynamically resolved current `feeTo()`. Keep YT-derived SY interest in the strategy. Do not send all discovered reward tokens indiscriminately; policy for other reward tokens is OPEN.

Track new claims and previously harvested, attributable PENDLE; permissionless third-party claiming must not strand rewards by defeating a current-call balance-delta calculation. Never sweep unrelated balances. Exclude fee-owned PENDLE from holder NAV or recognize its payable once. Define forwarding-failure behavior without miscrediting holders or losing the fee entitlement.

PENDLE emissions are not guaranteed, including on newly created markets. The future PENDLE-DETF, its staking and downstream investment policy are outside this PRD.

## 14. Open decisions and engineering gates

| ID | Owner/product decision still required |
| --- | --- |
| O01 | Formal authority to resolve the FoT and rebasing-underlying conflicts; exact permitted token surfaces and family-law supersession. No implicit exception. |
| O02 | Final entry/primary-redemption/direct-staking matrix, gating and failed-primary behavior; public swaps and removed automatic fallback remain selected. |
| O03 | Release schedule for all three lock classes, including the wrapper NFT's reinvested portions, participation cutoff and rewards while locked. |
| O04 | First V4 hook or supported variants, pricing/liquidation-aversion formula, fees and treatment of zero income. |
| O05 | NET-synchronized DETF expansion/eligibility semantics and numerical calibration. Existing D52 removal of DETF catch-up caps is not reopened by generic trading budgets or external NetNet capacity. |
| O06 | Complete directional route matrix, allocation/optimization objectives, cost allocation, shared-state economic measurements and bootstrap assets/prices. |
| O07 | Rollover target rules, allocation mode, residual handling and atomic/staged failure behavior. |
| O08 | External note custody/NFT transfer policy, reinvestment failure handling and policy for non-PENDLE incentive tokens. |

Engineering gates are not owner preferences: coupled facade transition/settlement compatibility; tax-aware V2 implementation feasibility; external-note aggregate-redemption liveness; deployment identity/code revision; quote/execution parity; runtime gas bounds; external price/index/epoch behavior. Approval does not substitute for evidence.

## 15. Acceptance criteria for a later authorized implementation

| ID | Required evidence |
| --- | --- |
| A01 | Reconcile common assets, exclusive NFT assets, payables, reserve LP, SE shares and outstanding token liabilities without double inclusion or subtraction. |
| A02 | Prove facade cross-effects and sequential projected quotes agree with actual settlement under every supported hook; reject unsupported routes truthfully. |
| A03 | Cover partial YT coverage, no retained YT, excess YT, claim ownership after transfers, expiry and roll; do not assume unchanged LP contents. |
| A04 | Taxed/untaxed NET hops, rounding, enabled/mapped/exempt states, queued exemptions, mixed decimals, multi-hop joins/exits and actual recipient minima. |
| A05 | No false pretransfer credit, donation capture, surplus refunds, self-issued-backing inflation, unauthorized access or callback/reentrancy extraction. |
| A06 | Distinguish swap inventory transfers, primary burn, fresh bond issuance and equity conversion; verify all selected fee and incentive equations. |
| A07 | Boundary/delayed/zero NET epochs, queued versus prospective distributions, DETF supply projection and entry/exit eligibility parity. |
| A08 | Prove each lock/release schedule and full/partial claim; no raw NET or unlocked-stake bypass for external bond proceeds. |
| A09 | External bond note ownership/provenance, unsolicited notes, aggregate redemption gas/liveness, NFT transfer if enabled, purchase failure and claim/reinvest failure. |
| A10 | Malicious or unsuitable rollover targets, old reward claims, expired deposit rejection and retained exit liveness, including failed staged transitions if selected. |
| A11 | PENDLE attribution, zero incentives, other reward tokens, permissionless prior claiming, `feeTo()` rotation and failed forwarding. |
| A12 | Economic scenarios: no new deposits, zero yield, NET/USDG decline, income depletion, costly tax churn, external-price manipulation, split/direct/round-trip swaps and mass exits. Measure LP acquisition and costs, not gross volume alone. |

Use production-first registered components and appropriate hermetic/fork evidence under the canonical testing rules. No tests, simulations, deployments or transactions were run to author this document. Passing tests and council agreement are not security or profitability proof.

## 16. Evidence register and provenance

Paths are repository-relative; line ranges refer to inspected snapshots, not immutable revision pins. Revalidate after code changes. Historical market addresses/expiry in research are leads, not current market selection. The earlier recorded Pendle series expired at 2026-09-17 00:00 UTC.

| Ref | Source / observed scope |
| --- | --- |
| E01 | `CLAUDE.md:25–46`; `docs/agent/INDEXEDEX_AGENT_LAW.md:67–209` — current naming, token policy, ownership and testing constraints. |
| E02 | `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` D32–D66 / §24, especially `1007–1125` — funded bonds, linear vesting, gates and mandatory fallback in current law. |
| E03 | `contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md:1264–1438` — route/binding references; conflicting legacy bond text remains subordinate to E02. |
| E04 | `lib/crane/contracts/protocols/pol/net/src/NET.sol:121–145,184–252`; `src/interfaces/INET.sol:31–77`; `src/Constants.sol` within that Net directory — transfer predicates and exemption state. |
| E05 | `lib/crane/contracts/protocols/pol/net/src/Staking.sol:129–150`; `src/interfaces/IStaking.sol:27–35`; `src/Distributor.sol:43–98` — epoch queue and prospective minting. |
| E06 | `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:88–198` — payments, funded notes, aggregate claims, RFV and vesting. |
| E07 | `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:60–139`; `contracts/interfaces/IStandardExchangeTransitionQuote.sol:17–58` — sampled rates and projected-state interfaces. |
| E08 | `lib/crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol:156–211` — existing router/burn paths do not establish tax-aware delivery. |
| E09 | `docs/detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md:107–190` — historical chain/pair/Pendle identity and wrapper observations, not live verification. |
| E10 | Canonical skills read directly: `lib/crane/.claude/skills/crane-architecture/SKILL.md`; `.claude/skills/indexedex-adversarial-testing/SKILL.md`; current router/catalog. |

Primary public sources accessed in the preceding research discussion (reported dates 2026-09-17 and 2026-09-21; session/environment discrepancy retained, not silently backdated):

- https://docs.netnet.capital/official-channels
- https://docs.netnet.capital/FEES.HTM
- https://docs.netnet.capital/mechanism
- https://docs.pendle.finance/pendle-academy/yield-trading-deep-dives/chapter-7-providing-liquidity-while-trading-yield
- https://docs.pendle.finance/pendle-v2-dev/Contracts/Oracle/PYLpOracle
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/core/YieldContracts/PendleYieldToken.sol
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/core/Market/PendleMarketV7.sol
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/core/Market/PendleGauge.sol
- https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol

Net vendor snapshot was reported as 2026-08-28. Pendle reviewed upstream YT version 6 and market version 7 use Solidity `^0.8.17`; upstream `main` and V2 `master` links are unpinned. No live deployment equivalence, active market selection, exact fee state or successful integration is certified.

## 17. Review status and implementation handoff

Initial draft prepared for three independent reviews, followed by one combined cross-review per member. Earlier round findings informed preparation; no review consensus is claimed for this file yet.

Before implementation: obtain human decisions, reconcile authoritative policy, establish feasibility gates, pin deployment dependencies and author a separately approved implementation/test plan. Do not execute the plan merely because this document exists.
