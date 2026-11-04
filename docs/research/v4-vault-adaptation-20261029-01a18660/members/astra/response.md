# Astra original: adaptation foundation for hook-composable V4 shares

## Recommendation

**Choose Weir's strategy and direct-PoolManager custody model, but adapt it through the existing PairToken Standard Exchange family rather than fork Weir and merely add ERC20. Rank lpTOKEN second and The Pool third.**

The concrete target I recommend is **one registry-deployed ERC20-share diamond owning one hookless, full-range backing position, with native exact-input conversion and a separately authorized execution entry for an already-unlocked PoolManager**. Preserve the existing stage-one proportional basket accounting, fee attribution, native support, atomic one-token rejection, and deterministic execution limits. Use Weir as the simple strategy/execution reference and lpTOKEN as the strongest outside reference for proportional inventory funding and full-consumption conversion. [L2-L4, P1-P3]

This agrees with the user's preference about the **strategy**, not with the claim that adding ERC20 is the remaining work. Weir has material accounting, execution-context, output, and rate gaps. None of the three published implementations meets the complete hook-composition requirement unchanged.

| Question | My answer |
|---|---|
| Best external strategy foundation | **Weir:** one full-range position, direct manager calls, integrated same-pool conversion, no required external conversion market. |
| Best external accounting/periphery reference | **lpTOKEN:** a two-currency portfolio claim, explicit funding of idle as well as position ownership, separate conversion, full-spend-or-revert exit. |
| Lowest actual adaptation burden in this repository | **Extend the current full-range PairToken SE family**, not replace its ownership model with Weir's liquidity-only issuance or import another standalone token. It already specifies much of the difficult accounting and packaging. Its current manager-lock contract must change for the new use. |
| Runner-up if starting from an outside codebase alone | **lpTOKEN** is a credible stronger accounting starting point; it loses the overall ranking here because its factory/clone, share-fee, dead-share, fixed-range, launch, and external-zap choices must be removed or changed to fit existing product decisions. |
| Third place | **The Pool:** useful fixed-asset and net-contribution ideas, but unnecessary NFT/periphery, adapter, reserve-sale, owner-reference, and ERC4626 assumptions for this use. |

**Rate recommendation:** preserve the proposed normalized one-whole-share executable exit `getRate` as an explicitly identified quote semantics. Do **not** use it unchanged as the sole trusted invariant multiplier. For a Balancer-style rate-scaled pool, my preferred **new product choice** is a separate, guarded, common-reference basket-value adapter, with amount-specific conversion settlement still binding. This is not an accepted replacement for `getRate` or for current SY accounting. No inspected candidate supplies an invariant-safety proof for either rate policy. Section 5 states the distinction and the remaining decision.

This is an independent architecture recommendation, not a code change, PRD amendment, migration instruction, or statement that the existing implementation passes its tests.

## Requirement-fit comparison

“Present” means observed in source, not validated by executing transactions. “Adapt” denotes new work needed under the clarified requirement.

| Requirement | Weir | lpTOKEN | The Pool |
|---|---|---|---|
| One simple full-range backing position | Present; direct manager ownership | One direct position, but configured fixed range is not the same full-range policy | PositionManager NFT, owner-managed range |
| Transferable ERC20 share | **Adapt:** current per-PoolId ledger | Present | Present through ERC4626 |
| Native either-leg one-token entry/exit | Integrated branches; exit residual defect | Verified external zap; integrate economic path inside the SE family | Fixed-asset methods call configured external adapter |
| Same-manager execution during a hook swap | **Adapt:** public methods call `unlock` | **Adapt:** both vault and zap initiate unlocks | **Adapt:** helper calls ordinary `modifyLiquidities`; adapter also needs examination |
| Complete chosen-token exit or revert | **Adapt:** unwanted residual can be paid | Strongest reference: entire unwanted leg must be consumed | Fixed-asset sufficiency check; not the same proportional slice model |
| Idle-aware proportional issuance | **Adapt:** shares primarily follow added liquidity | Strongest outside fit | Scalar NAV-delta model, not per-currency non-dilution |
| No independent market assumption | Same backing-pool conversion fits | Direct zap fits; restricted routed entry is unnecessary | Adapter configuration does not establish this property |
| No permanent dead shares / no vault fee | Remove existing lock and performance cut | Remove dead shares and share fees | Remove fee/admin policies and adapt genesis math |
| Current SE/SY and registry packaging | Port economics into existing family | Port economics; do not retain standalone token/factory stack | Substantial adaptation; do not force ERC4626 exact-output semantics |
| Read-only normalized one-share exit rate | Not present as required | Not present as required | ERC4626/NAV rate is not that quote |
| Safe downstream invariant multiplier | Not established | Not established | Not established by its reference guard |

The basis is source P1-P4 and the owner-approved local requirements L2. These are architecture-fit judgments, not relative security ratings.

**Other researched families:** ALPS adds managed multi-pool exposure and conditional cash realization; USDa assumes a stable relationship and an off-pool market and permits dual-token fallback; Unoxi requires asynchronous rounds and confidential-wrapper settlement; ZapVault lacks pooled shares and can retain residual ETH after deleting the user position. Each moves further from the synchronous, exact-output-currency requirement. Their reusable details do not justify making them the base. [L1]

## 1. Why “add ERC20” is insufficient

### 1.1 One ERC20 must identify one economic basket

Weir's one contract holds many PoolIds, with `sharesOf[id][user]` and `totalShares` per pool. Adding one global ERC20 supply to that singleton would merge claims on distinct baskets. For IndexedEx, use the existing **one diamond, one PoolKey, one ERC20 supply** identity and canonical ERC20/permit/domain facets. Do not create both a Weir ledger and a second authoritative ERC20 ledger. [P1; L2 S1-ARCH-01 through 05]

### 1.2 Liquidity-ratio issuance does not automatically fund idle ownership

Weir `_deposit` computes new shares from added liquidity divided by existing liquidity, while `_withdraw` allocates idle0/idle1 pro rata too. `_compound` can leave unmatched idle balances. The issuance denominator therefore does not itself charge an entrant for the claim on those balances. [P1, lines 238-286, 319-360]

**Analytical example, not an executed exploit:** let incumbent liquidity and supply each be 100 units and let 20 units of currency0 remain idle after maintenance. Adding 10 liquidity units and minting 10 shares without a corresponding idle contribution preserves liquidity per share but reduces incumbent idle currency0 per share from `20/100` to `20/110`. Calling the residue “dust” does not make the ownership dilution disappear.

lpTOKEN instead computes a portfolio snapshot and requires proportional position **and idle** backing. The local stage-one PRD already specifies a different, explicit reserve-wise non-dilution equation: use a post-entry-swap incumbent snapshot and mint only against attributable caller contribution. **Retain the local equation rather than silently substitute either outside formula.** [P2 `_portfolioSnapshot`, `_mintBackingForShares`; L2 S1-ACC-07; L3 `_entrySnapshot`, `_mintCredit`]

### 1.3 Fee collection and input attribution need checkpoints

Pre-entry compounding alone is insufficient: the entrant's backing-pool swap can create new fees for incumbent liquidity before the addition. An addition or partial decrease can realize fees already owed to the whole position. Principal cost, incumbent fees, hook deltas, and caller input must remain distinguishable; the second `feesAccrued` return must not be added again to a caller delta already including it. [P5; L2 S1-X15/X16, S1-ACC-07]

Recommend preserving:

- Input reservations outside shareholder backing before maintenance.
- Incumbent fee checkpoints before attributable minting.
- Proportional withdrawal allocations of booked idle and principal, with correct ownership of newly realized fees.
- Full-precision credit comparisons and explicit floor/ceiling rules, not a displayed NAV-per-share comparison.
- The approved zap-remainder policy: the PRD currently books the uncredited caller remainder without extra shares and requires previews/events to expose it. That is **disclosed basket contribution**, not ownerless residual custody. Do not silently replace it with lpTOKEN's two-token refunds inside a single-output hook route. [L2 S1-ACC-07; L3]

Removing Weir's locked `MIN_SHARES` also changes terminal redemption and bootstrap behavior. Stage one already requires no permanent sink, a real zero-supply reset, and paired genesis; those are settled decisions, not questions to reopen. [L2 S1-X02/X10, S1-OP-01]

### 1.4 Successful withdrawal needs a structural one-token postcondition

Weir attempts to sell the unwanted currency, then settles **both** net deltas. Minimum outputs are lower bounds, not a constraint that the second output equals zero. Add full allocated-input consumption and zero unpaid/unwanted allocation checks, not merely a stricter `min0` or `min1`. lpTOKEN's router is the useful reference. [P1 `_withdraw`, `_swap`; P3 `_zapOut`, `unlockCallback`]

The route may leave legitimate incumbent inventory in the vault. It must not burn the caller's shares and leave part of **that caller's withdrawal allocation** stranded, donated, queued, or paid in another currency. On failure, revert the whole outer transaction. The current local `_exit` already rejects a nonzero undesired payout. [L3 `_exit`; L2 S1-X12]

## 2. Same-PoolManager hook execution is the central integration change

### 2.1 Distinguish the two pools and the three accounting actors

Let:

- **P** be the backing pool, holding target T and counterpart U.
- **V** be the ERC20-share vault diamond and owner of P's liquidity.
- **Q** be a different, share-consuming pool using V shares as one currency.
- **H** be the custom hook on Q.
- **M** be their common PoolManager.

Canonical M has a global unlocked flag; `unlock` rejects a nested unlock. Liquidity modifications are owned by their direct caller, and temporary currency deltas are keyed by **account and currency**, not by pool. The outer router, H, and V do not share one automatically netted wallet. [P5-P6]

Therefore the naive path fails:

> Router unlocks M, calls Q swap, H calls ordinary Weir deposit/withdraw, Weir calls M.unlock again.

It reverts `AlreadyUnlocked`. The same issue exists in lpTOKEN's vault and swap router. A different manager would change that topology, but would not solve accounting, rates, or composition generally. [P1-P3, P5]

This is already a local specification boundary: PairToken `_start` and `_action` explicitly reject an unlocked manager, and Wings `Common.execute` does too. **Those guards cannot simply be deleted.** The new requirement needs a scoped, owner-authorized execution-contract amendment. [L3:323,548; L6:40-50; L2 S1-SEC-01]

### 2.2 Recommended minimal unlocked-entry design

This is a proposed contract boundary, not an implementation plan:

1. **Two authorized entry contexts, one economic engine.** Normal entry initiates its own unlock with the existing committed callback discipline. A separate hook-integration entry requires M already unlocked, the designated H caller, an admitted Q/route, and a one-use active operation context. The locked route and already-unlocked route must perform the same ownership, fee, amount, and limit checks.
2. **Preserve V as manager caller.** H calls V; V invokes `modifyLiquidity` and P swaps directly. Moving those calls into H would change the position owner to H. Merely forwarding PoolKey/range/salt cannot authorize H to alter V's position.
3. **Reserve exact funding and authority.** Bind source tokens/shares, amount, direction, recipient, minima, deadline, and route identity to the active context. The hook validates its manager callback and PoolKey. Vault authorization validates H, not a forged claim in `hookData`. Input must be observed, isolated caller credit, never arbitrary raw-balance excess or someone else's pretransfer.
4. **Settle V's own deltas locally before it returns.** For the first integration, favor explicit funding/settlement over clever cross-contract netting. V pays its actual debts and takes its own credits, returns the selected result to H, and leaves no new V delta or pending allocation. Do not require *global* zero deltas here: the outer router may legitimately still owe M.
5. **H accounts for the outer swap separately.** H delivers or settles the actual resulting shares/underlying and returns the matching hook deltas for Q. The router closes its own obligations before the original M.unlock returns. The same amount must not be both paid as a transfer and independently credited a second time through hook-return accounting.
6. **Authenticate callbacks separately from the integration entry.** An ordinary `unlockCallback` still accepts only bound M plus a live payload commitment, consumed once. H must not impersonate M or call that callback. `isUnlocked()` by itself is never authority.

These are derived design recommendations from the caller/delta model, not claims that existing source already implements them. [P5-P8; L2-L3]

**Concrete funding picture:** H can use manager flash accounting to obtain the incoming currency, fund V, receive V's actual output, and settle that output to M. The returned Q hook delta accounts for what H took/returned, while the outer router supplies/receives the user's currencies. Such use depends on Q's configured hook-return permissions and exact sign/orientation accounting. Native settlement must explicitly reset the synced currency; ERC20 settlement uses the current sync/transfer/settle sequence. Do not rely on another actor's outstanding synced-reserve checkpoint. [P5, P8; L2 S1-NATIVE-01]

### 2.3 PositionManager is possible, but adds burden

Canonical PositionManager exposes `modifyLiquiditiesWithoutUnlock`; its ordinary `modifyLiquidities` uses the unlock-opening path. Thus NFT-based designs are **not inherently impossible** in an already-unlocked manager. But The Pool's inspected `VaultLP` uses the ordinary method, and adopting the alternate method still requires its NFT approval, locker/payer, periphery guard, and settlement model to compose correctly. Its swap adapter must also avoid reopening M. [P4, P7, P9]

Direct V-owned liquidity avoids that extra owner/payer layer and matches current local architecture. This, rather than the mere length of Weir's code, is the primary reason to prefer its strategy model.

### 2.4 Recursion and read consistency are distinct from the global unlock

Keep P hookless and Q distinct for the first adaptation, as the current PRD already specifies for the backing pool. Reject routes in which V becomes its own backing asset or nested conversions return to the active V/Q operation. This avoids introducing an arbitrary backing-hook compatibility problem just because Weir permits any PoolKey. [L2 S1-ARCH-03; P1]

The canonical hook self-call suppression applies to the immediate manager caller. H calling V, which calls M, is **not** H directly calling M. It is not a general recursion defense. [P8]

Hold the vault's cross-facet busy state through funding, manager actions, payout, and reserve publication. Ordinary public economic reads must not expose a half-updated supply/book. Read the chosen rate at a defined coherent boundary, or use the already-authorized projected-state interface for internal transition evaluation. Complete V's operation before a fresh public rate read; M may remain unlocked for the outer transaction. A manager-unlocked flag and a vault-busy flag are not interchangeable. [L2 S1-SEC-01; L4; L7]

If the consuming invariant requires a rate during V's active operation, it needs an explicitly coherent projected snapshot, not removal of the read guard or a stale cached scalar. The existing transition interfaces are relevant context; their presence does not prove this family currently implements the needed combined quote.

## 3. Exact one-token execution under the single-market premise

There is no need to assume Chainlink, a peg, or another deep pool to perform the conversion. P itself can buy the missing entry leg and sell the unwanted exit leg. The tradeoffs are self-impact, trading fees, manipulation exposure, and capacity after withdrawal. [P1-P3]

On exit, quote and execute against **liquidity remaining after V removes the caller's slice**. Do not use the pre-removal depth. If V is nearly the whole pool, smaller redemptions can use remaining incumbent liquidity while a terminal single-token exit may be impossible. The permitted behavior is atomic rejection; a separate deliberate paired exit is not a silent fallback for H. No scalar rate creates missing market depth. [L2 S1-QUOTE-01; P3; inference]

Exact-input conversion must check full specified input consumption as well as final output. A high minimum cannot prove absence of unwanted currency; an extreme sqrt-price limit cannot prove complete fill. Entry minima must also cover issued shares and any disclosed uncredited remainder. [P1-P3; L2]

**Same-pool TWAP:** it can be useful as a temporal reference, but it is not an independent market price. It can make a brief spot displacement easier to detect or more costly to sustain. Sparse observations, sustained manipulation, real price jumps, stale windows, and downstream extraction size remain relevant. Neither “same pool” nor “TWAP” alone settles safety.

The current stage-one PRD explicitly adds no TWAP. Its backing pool is hookless and immutable; do not assume an observation feed exists or silently attach an oracle hook to it. If a same-pool historical reference is chosen for the new downstream rate policy, specify an admitted observation mechanism and bootstrap/staleness behavior compatible with that topology. That is a new dependency/policy, not an independent-market assumption. [L2:622-629, S1-ARCH-03]

I recommend a separate downstream deviation/staleness/exposure policy and amount-specific execution bounds, not changing proportional issuance into oracle-priced issuance. Calibration is unresolved; inventing one universal deviation percentage would not establish profitability resistance.

## 4. Ownership, accounting, and executable value must remain separate

### Ownership/issuance

Shares own the actual portfolio: removable principal, booked idle, and earned fees, excluding pending caller input and unrelated unbooked funds. At the same post-swap state, new shares must be backed by the caller's attributable growth rather than repricing incumbents and counting that as a deposit. [L2 S1-ACC-07]

This is why The Pool's `totalAfter - totalBefore` scalar idea is not a drop-in answer under same-backing-pool conversion: a price-changing operation can change incumbent marked NAV too. “Net NAV gain” is not automatically “new caller capital.” The Pool remains a useful contrast, not proof that scalar issuance is appropriate here. [P4 `depositWithZap`; inference]

### Current local SY accounting

`UniswapV4PairTokenStandardExchangeVaultSYQueryTarget.exchangeRate()` is explicitly spot-marked, fee-inclusive **accounting**, not issuance and not redemption proceeds. It invokes the family idle guard. S1-QUOTE-02 specifies raw target units per `1e18` raw share units, and returns zero at zero supply. Do not replace it as part of this recommendation. [L2:989-1025; L4]

### Actual executable exit quote

Define `E_t(q, sigma)` as the raw units of selected underlying t returned by the complete supported redemption-and-sale operation for q raw shares from coherent state sigma. It includes required maintenance, fee ownership, proportional removal, post-removal swaps, rounding, and configured limits. It is undefined as a successful quote when that route would reject. [L2 S1-QUOTE-01; analytical notation]

For share decimals `d_s` and target decimals `d_t`, the requested one-whole-share rate is:

```text
oneShareRaw = 10^d_s
R_exit_WAD = floor(E_t(oneShareRaw, sigma) * 10^18 / 10^d_t)
```

For the current 18-decimal shares, a quote returning `2_400_000` raw six-decimal target units means `R_exit_WAD = 2.4e18`. Calling an exit preview with `1` raw share is not quoting one whole share.

A one-share quote also needs a defined admission domain: at zero supply, supply below a whole share, or insufficient conversion depth, do not invent 1:1 or linearly rescale a smaller successful exit and call it the same quote. The consuming pool needs an explicit unavailable-rate/activation policy.

### Do not relabel Wings

Current Wings `getRate` computes `Quote.quote(Common.quoteRequest()).value * 1e18 / totalSupply`, returning `1e18` at zero supply. The request includes the whole owned book; the helper removes all owned liquidity before the sale and reports native-unit value, including a market-limited result if something remains unsold. That is **whole-book value divided by supply**, not `E_t(10^d_s, sigma)`. [L5-L6, L8]

In the inspected helper, “normalized” can safely describe division by share supply; it should not be taken as independently demonstrated human target-decimal normalization. The helper says native units and the displayed `getRate` formula has no target-decimal factor. This observation is limited to the read path, not a wider Wings audit or authorization to change it.

## 5. A one-share quote is not a generally safe invariant multiplier

Balancer's rate interface promises an 18-decimal related-token rate, not a redemption-size guarantee. Its vault applies token decimals and rate scaling as separate operations; rounding direction matters. A matching ABI does not establish the economic assumptions of a custom rate-aware invariant. [P10-P12; L9]

In general:

```text
E_t(n * oneShareRaw, sigma) != n * E_t(oneShareRaw, sigma)
```

The larger operation removes more liquidity before selling, can cross different ticks, and can enter a different maintenance/admission branch. A sequential second withdrawal also starts from a different state. This is a mathematical/execution consequence, not a claim about a particular tested failure.

An LP share denominated in T is not a redemption-pegged T wrapper. Target-relative value can fall through relative price changes, impermanent loss, costs, and losses. Fees do not imply monotonic appreciation. A low one-share rate is not automatically conservative for **both** swap directions; rate and amount rounding affect what the downstream pool pays and receives differently. [L1; P10-P12; inference]

Most importantly, the backing state is potentially user-influenced. A trader can change P, invoke a rate-consuming Q, and later trade P again. Whether such a sequence profits depends on costs, depth, constraints, and Q's exposure. Neither a spot exit quote nor a spot accounting rate supplies an independent truth merely by being read-only.

### Concrete recommended rate boundary

1. **Keep `getRate`'s proposed one-share executable semantics identifiable and unchanged by fiat.** It can support diagnostics, quoting, and explicit one-share reference comparisons.
2. **Use amount-specific actual conversion receipts in H.** Do not promise conversion of q shares from `q * getRate / 1e18`. The quote and settlement for q must agree on the admitted state and operation.
3. **For a Balancer-style invariant, I favor a separate `IRateProvider` adapter with common-reference basket accounting**, explicitly a new product choice requiring owner acceptance. With portfolio raw value `V_t` at the specified reference and raw supply S, its dimensional formula is:

```text
R_accounting_WAD = floor(V_t * 10^d_s * 10^18 / (S * 10^d_t))
```

   Use full-precision evaluation rather than multiplying an already-rounded SY display value when exactness matters. Current raw SY and this normalized adapter are not interchangeable.
4. **Do not claim that alternative is already safe.** It still needs a coherent observation/valuation policy, directionally appropriate rounding, stale/deviation handling, exposure limits, and a downstream invariant argument covering a rate-changing conversion. A same-pool historical reference is admissible under the premise but remains endogenous.
5. **If the owner requires the executable one-share value itself to be the invariant multiplier**, treat that as a custom quote-aware pricing design with an explicit size/state domain, not plug-compatible Balancer rate scaling. My foundation recommendation stays the same, but I do not recommend pretending that invariant design is already resolved.

The unresolved choice is the **downstream pricing contract**, not whether to merge accounting and issuance. I recommend the separate adapter alternative; I do not record it as approval to replace the requested quote or the approved SY rate.

## 6. Minimal adaptation boundaries and local constraints

The necessary work is limited conceptually, but it is more than an ERC20 facet:

1. **Retain the existing single-diamond identity and accounting.** Canonical share/permit/domain and vault discovery components; no second reserve token or share-of-shares layer.
2. **Introduce an explicit already-unlocked hook execution context.** Preserve normal callback authentication and share the economic engine. Change both the start gate and action-dispatch assumptions deliberately; changing only one still fails.
3. **Enforce complete one-currency output.** lpTOKEN's full-consumption condition and the current `_exit` undesired-allocation check are the references. Never clear/donate residual just to make unlock succeed.
4. **Preserve caller/fee/idle categorization.** Do not import Weir's liquidity-only issuance or raw-balance accounting into local pretransfer semantics.
5. **Preserve current maintenance policy unless separately changed.** Weir's mandatory balanced reinvestment and lpTOKEN's swapless cooldown policy differ from approved stage-one full maintenance with narrowly selected collection-only withdrawal. Do not quietly substitute either.
6. **Add a precisely denominated read-only quote/rate boundary.** Keep current SY accounting separate; define whether a separate downstream adapter is adopted.
7. **Extend quote parity to the hook route, without a new general simulator.** Actual amount, authorized operation context, maintenance mode, pending input exclusion, post-removal depth, fee growth, native/wrapped faces, and integer rounding must match the existing bounded model. Sequentially dependent steps cannot repeatedly quote unchanged live state. [L7]
8. **Retain current deployment and protocol boundaries.** CREATE3/FactoryServices for facets/packages; manager registry deployment for instances; shared facet selectors and factory-provided selectors remain distinct. Use SE exact-input interfaces and native SY; exact-output remains `ExchangeOutNotAvailable()`. Do not force ERC4626 methods that promise an unsupported exact-asset withdrawal. [L2 S1-ARCH-04, S1-PKG-01]

The PRD currently admits at most **64 swap iterations, 12 initialized crossings, and 16 distinct bitmap words per candidate**, with at most two withdrawal candidates. Its engineering ceilings are **12M transaction gas and 5M preview gas**. These are requirements I read, **not measurements I reproduced**. A new hook/router envelope must fit its whole supported transaction or undergo a separately authorized bound revision; a 12M inner vault call plus unbudgeted outer work is not proof of compliance. [L2:885-987]

Do not replace expensive preview failure with a spot estimate, whole-book ratio, partial quote, `gasleft`-dependent economics, queue, or automatic paired payout. A scalar `getRate` used by downstream pool operations also needs an affordable read path; a permitted 5M local preview is not assurance that a composed pool operation can routinely afford that read.

**Code provenance:** Weir's inspected principal source and The Pool's vault/helper identify MIT; the inspected lpTOKEN vault/zap identify BSD-3-Clause. Those labels support choosing references, not copying the complete dependency trees without checking notices and transitive terms. The recommendation is adaptation of architecture within the existing family, not wholesale copying of verified deployed source. Verification alone is not a license grant. [P1-P4]

## 7. Owner decisions that are genuinely still open

These do not prevent a concrete recommendation and do not authorize edits:

1. **Downstream rate semantics:** accept the recommended separate common-reference accounting adapter, or insist on a one-share executable quote-aware invariant. Neither choice silently changes SY or issuance.
2. **Risk and availability policy:** observation method/window, bootstrap/staleness handling, deviation/exposure limits, and rate-unavailable behavior for thin supply/depth. The current stage-one PRD does not decide these for a share-consuming pool.
3. **The authorized hook boundary:** which concrete hook/pool family may invoke the already-unlocked route, and whether its immutable bindings or registry policy are part of the new package identity. My default recommendation is narrow route binding, no arbitrary unlocked caller, and hookless P.

Full-range strategy, one ERC20 supply, no permanent dead shares, no vault-level fee, native support, exact-output rejection, bounded atomicity, and existing registry packaging are already specified locally. I am not reopening them.

**Final ranking: Weir strategy first, lpTOKEN accounting/periphery reference second, The Pool third; current full-range SE implementation is the recommended adaptation vehicle.** The reason is the simplest compatible custody/call graph, not deference to the initial preference or a claim that ERC20 is the only missing feature.

## Sources, observation scope, and limits

All reads occurred on **2026-10-29**. Local files were read as current working files, not a frozen repository snapshot. No new-run peer response was read. The complete common brief and prior final REPORT were read; retained prior observations were supplemented with narrow primary-source checks.

### Local sources

Paths are relative to `/Users/cyotee/Projects/indexedex/`.

| ID | Exact path / read locator |
|---|---|
| L1 | `docs/research/v4-single-token-vaults-20261029-01a18660/REPORT.md` — complete final report, including revised output semantics, deployment table, council limits, and source registry. |
| L2 | `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` — lines 1-280; 454-533; 610-673; 885-1086. Decisions, architecture, attribution equation, fallback, gas, SY rate, registry, and guard sections. Not a claim to have audited the entire PRD. |
| L3 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol` — lines 285-589, especially `_start` at 317 onward, unlocked rejection at 323, `_entrySnapshot`, `_mintCredit`, `_exit`, `_action` and rejection at 548. |
| L4 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultSYQueryTarget.sol` — complete short file; `assetInfo`, `exchangeRate`, preview guards. |
| L5 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol` — complete short file; `getRate`, `quoteRate`, `_ready`. |
| L6 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol` — complete short file; `quoteRequest`, `execute`. |
| L7 | `contracts/interfaces/IStandardExchangeTransitionQuote.sol` — complete interfaces, including external transition and projected-rate extensions. |
| L8 | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol` — lines 1-190; native-unit whole-book quote, owned-liquidity removal, unsold inventory and market-limited result. |
| L9 | `lib/crane/contracts/external/balancer/v3/interfaces/contracts/solidity-utils/helpers/IRateProvider.sol` — complete interface and rounding/context warning. |

Repository guidance consulted: previously read `CLAUDE.md`; discovery skill `.agents/skills/crane-architecture/SKILL.md` (canonical Crane architecture guidance); `.agents/skills/balancer-v3/SKILL.md`; canonical `lib/crane/.claude/skills/balancer-v3-vault/SKILL.md`. No implementation or deployment commands from those files were run. Current explicit PRD requirements take precedence over generic skill examples.

### Public primary sources

| ID | Exact URL / inspected contract |
|---|---|
| P1 | https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources — `src/WeirVaults.sol`, particularly lines 145-406; matched record. |
| P2 | https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/LpTokenVault.sol — mint/redeem lines 372-514, callback 715-742, portfolio funding 873-1021, unlock 1173-1181. |
| P3 | https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/periphery/ZapRouter.sol — exit 565-624, callback 672-695; unlock and route entry locations also inspected. |
| P4 | https://sourcify.dev/server/v2/contract/42161/0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0?fields=sources — `src/LiquidityVaultV2.sol` lines 397-572, complete `src/libraries/VaultLP.sol`, matched record; prior original additionally covers its reference/admin paths. |
| P5 | https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol — `unlock`, `modifyLiquidity`, `swap`, `sync`, `take`, `settle`, `settleFor` and `_settle`. |
| P6 | https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/CurrencyDelta.sol — complete account/currency keyed transient-delta library. |
| P7 | https://raw.githubusercontent.com/Uniswap/v4-periphery/main/src/PositionManager.sol — approvals, both execution entrypoints, payer/locker and liquidity action dispatch. |
| P8 | https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/Hooks.sol — immediate-caller suppression, hook-return permissions and swap delta composition. |
| P9 | https://raw.githubusercontent.com/Uniswap/v4-periphery/main/src/base/BaseActionsRouter.sol — complete ordinary and without-unlock action dispatch. |
| P10 | https://raw.githubusercontent.com/balancer/balancer-v3-monorepo/master/pkg/interfaces/contracts/solidity-utils/helpers/IRateProvider.sol — complete interface. |
| P11 | https://docs.balancer.fi/concepts/vault/token-scaling.html and https://docs.balancer.fi/concepts/core-concepts/rate-providers.html — separate decimal/rate scaling and use during pool operations. |
| P12 | https://raw.githubusercontent.com/balancer/balancer-v3-monorepo/main/pkg/solidity-utils/contracts/helpers/ScalingHelpers.sol — apply/undo rate scaling with directed rounding, `computeRateRoundUp`. |

### Actual tool and evidence limits

- No broad new candidate search; only the three foundations, canonical V4/Balancer sources, and required local evidence were investigated.
- The brief reports the coordinator's Context7 monthly quota failure. I used official sources directly and do not claim a successful Context7 query in this session.
- Solidity document-symbol requests for the two Wings files timed out. Literal declaration searches and direct file reads supplied the required locators; no LSP configuration was changed.
- A combined read output was truncated by display limits; the resident individual read results were reprinted in bounded form, including the complete prior final report. No omitted report section was treated as read merely from the truncated aggregate.
- Large public verified-source JSON was fetched and parsed in memory, with selected source sections printed. No source files were created. One display-helper lookup failed and was corrected without repeating writes or execution.
- An initial guessed Balancer `pkg/vault/contracts/lib/ScalingHelpers.sol` URL returned 404; the official token-scaling documentation provided the actual `pkg/solidity-utils/contracts/helpers/ScalingHelpers.sol` location.
- Public main branches are mutable. Verification records do not prove current operational state, and no deployment/state transaction was executed.
- No tests, builds, shell, Git, installation, deployment, wallets, delegation, external messages, code/config/PRD edits, or new general projector were performed. Only this assigned response was written with `apply_patch`.

The recommendation identifies necessary mechanisms and unresolved product choices. It does not claim the proposed hook call graph, downstream invariant, manipulation resistance, or gas envelope has been implemented or validated.
