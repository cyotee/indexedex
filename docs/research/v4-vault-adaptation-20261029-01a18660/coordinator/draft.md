# Which vault should IndexedEx adapt?

Frozen advisory revision **v4-adaptation-r1**, 2026-10-29. Final revisions belong in REPORT.md and resolution.md; this draft will remain unchanged.

## Recommendation

**Use Weir's simple full-range strategy, implemented through the existing local PairToken Standard Exchange vault. Use lpTOKEN as the stronger external accounting/conversion reference. Do not fork Weir and assume ERC20 is the only missing component.**

That distinction resolves the apparent disagreement. All four originals recommend the existing full-range share-vault family as the lowest-burden implementation vehicle. Astra and MiniMax rank Weir first as a strategy foundation; Grok and Kimi rank lpTOKEN first as the external implementation reference. This is not unanimity that one upstream contract should be copied.

If choosing the reserve strategy: **Weir/local full-range first**. If choosing code to study for transferable proportional ownership and strict conversion: **lpTOKEN first**. The Pool is third for this use because its scalar ERC4626 NAV, PositionManager/NFT route, external swap adapter, reserve-sale machinery and owner reference add assumptions not needed here. None is a drop-in solution for a same-PoolManager hook. [E1-E6, L1-L3]

## Fit against the user's clarified needs

| Need | Weir | lpTOKEN | The Pool | Recommended adaptation |
|---|---|---|---|---|
| Simple fee-earning V4 reserve | Full-range direct position | Direct position, fixed range not necessarily full-range | Managed NFT range | Retain local full-range direct custody |
| ERC20 share usable in other pools | Per-PoolId ledger, not ERC20 | Already ERC20 | Already ERC4626 | One existing diamond/share supply per backing basket |
| Single-token success | Attempts either-leg conversion; can pay second leg | Strict whole-leg conversion or revert through official zap | Fixed-asset payout or revert through adapter | Preserve local strict one-token allocation check; borrow full-spend invariant |
| Entry/exit inside same-manager hook swap | Vanilla public calls open another unlock | Vault and zap open unlocks | Current helper uses ordinary PositionManager entry | New explicitly authorized already-unlocked entry, not ABI wrapping |
| Complete backing/fee ownership | Liquidity-only issuance misses idle contribution | Strong two-currency portfolio reference | Net NAV delta is not necessarily attributable capital under self-impact | Keep local per-currency attributable contribution and fee checkpoints |
| Related-underlying rate | Required new quote/provider boundary absent | Required new quote/provider boundary absent | NAV is not the requested one-share sale quote | Define quote semantics, units and downstream pricing policy explicitly |

All cells are source/architecture assessment, not executed verification or a safety ranking. [E1-E10, L1-L5]

## Why adding ERC20 is not enough

1. **One share token must identify one basket.** Weir's singleton holds different PoolIds with separate share ledgers. One global ERC20 would incorrectly merge them. The local one-PoolKey/one-diamond/one-supply architecture already fits; use canonical share/permit/domain interfaces rather than add a second ledger. [E1; L1]
2. **Issuance must fund idle and accrued ownership.** Weir mints from added liquidity relative to existing liquidity but redeems idle balances proportionally too. Compounding can leave unmatched idle. Adding an ERC20 does not charge an entrant for that idle claim. Keep the local attributable reserve-growth rule, including post-entry-swap incumbent snapshot and final fee checkpoint. lpTOKEN's explicit portfolio funding is a useful comparison, not permission to replace the local equation. [E1-E2; L1-L2]
3. **One-token success must be structural.** Weir settles both resulting deltas. A minimum is a lower bound, not a zero-unwanted-token assertion. For the hook path, consume the complete caller-owned unwanted allocation and pay only the selected token, or revert the whole transaction. Never burn shares and donate/strand/queue the residual to make the call succeed. Legitimate remaining shareholder inventory is different from an unpaid exiting allocation. [E1, E3; L2]
4. **Execution context must change deliberately.** A hook on the share-consuming pool is already inside the common manager's unlock. Weir and lpTOKEN's vanilla paths call unlock again and fail. The local family explicitly rejects this state too. Deleting guards is not a settlement design. [E1-E5; L2-L3]
5. **An ERC20 does not supply its rate semantics.** Accounting value, actual liquidation proceeds and a downstream pool's scalar pricing input have different contracts. None of the shortlisted vaults provides the complete requested rate boundary ready-made. [E7-E10; L4-L5]

Do not import upstream economic policies as interface work. Current local requirements already exclude permanent dead shares and vault-level fees and preserve native support, paired genesis, no-sink terminal reset, strict atomic one-token rejection and explicit unsupported exact-output methods. Weir's performance cut/locked shares and lpTOKEN's share fees/launch-specific range and NAV are not adopted. [L1]

## Hook integration: two pools, one outer unlock

Let P be the backing T/U pool, V the vault/share token, Q a distinct consuming pool containing V shares, H its hook, and M their common PoolManager.

The naive path fails:

> Outer router unlocks M -> swaps Q -> H calls ordinary vault deposit/redeem -> vault tries M.unlock again.

Canonical M rejects nested unlock. Recommended boundary: H invokes a narrow V entry authorized for this H/Q/operation while M is already unlocked. V uses the same economic engine without opening another unlock. Ordinary user entry retains its authenticated unlock callback. Neither H nor an arbitrary unlocked caller impersonates that callback. [E4; L2-L3]

Preserve V as the caller of backing `modifyLiquidity`, so V remains position owner. Bind source shares/tokens, observed input credit, amount, output token, recipient, limits, deadline and route identity. The unlocked flag is corroborating state, not authorization. Keep the cross-facet busy guard through funding, execution, payout and final book publication.

M's deltas are per **address and currency**. V must close its own operation deltas or return to an explicitly accounted baseline before returning; H and the router handle their separate obligations. Only the final outer unlock requires the global nonzero-delta count to be zero. Transfers, manager credits and hook-return deltas must not double-pay the same amount. Use supported sync/transfer/settle sequencing; do not assume another actor's saved checkpoint remains valid or prescribe arbitrary transient-slot restoration. [E4, E6]

Direct position custody is the simplest fit, **not the only protocol-legal approach**. PositionManager exposes `modifyLiquiditiesWithoutUnlock`; adapting The Pool through it is possible in principle but still needs NFT approvals, payer/locker, action and swap-adapter composition. lpTOKEN also uses direct manager custody; its separate vanilla router is a refactoring burden, not a reason it can never be integrated. [E2-E5]

Keep P hookless and distinct from Q as current local law requires. Do not assume immediate-caller hook suppression prevents H -> V -> M -> H recursion. A different manager changes lock topology but does not solve fee attribution, conversion depth or rate manipulation. [L1; E4-E6]

No new general swap simulator is recommended. Extend the existing bounded amount-specific quote/execution contract to the authorized hook context. The whole outer swap, not merely the inner vault call, must satisfy its gas budget; current local 12M transaction and 5M preview ceilings are requirements read, not newly measured results. [L1-L2]

## Rate Provider: preserve the quote, decide how the consuming pool uses it

The goal is feasible as a design objective, but no candidate settles its downstream pricing policy. Keep these distinct:

- **Ownership/issuance:** proportional claims, attributable caller funding and correct fee/idle ownership.
- **Current SY accounting rate:** spot-marked basket accounting in raw target units per scaled raw shares; not issuance or executable proceeds.
- **Executable quote E(q):** actual supported withdrawal plus sale for q shares, including maintenance, fee allocation, post-removal liquidity, limits and rounding.
- **Downstream pricing rate:** scalar used by the consuming pool's invariant or hook. Balancer-style rate scaling uses a defined 18-decimal related-token value and applies it to balances/amounts. ABI compatibility is not an economic safety proof. [E7-E10; L1, L4-L5]

Preserve the previously discussed executable one-whole-share `getRate` semantics as a proposal rather than silently replace it with NAV:

```text
oneShareRaw = 10^shareDecimals
exitRateWAD = floor(E(oneShareRaw) * 10^18 / 10^targetDecimals)
```

A six-decimal target quote of 2,400,000 raw units for one whole share gives 2.4e18, not 2,400,000 as a human-normalized rate. Current raw SY accounting cannot be wired unchanged into that normalized interface. Current Wings `getRate` divides whole-book quoted value by supply, which is not the same operation as E(oneShareRaw); its existence does not prove the requested quote is already implemented. [L4-L5]

**A scalar rate is a reference, not an arbitrary-size redemption guarantee.** Generally E(n shares) differs from n times E(one share). That nonlinearity alone does not mathematically prohibit a rate-aware pool: ordinary pools already have slippage and rates can be valuation/oracle references. It does mean H must size/settle each actual conversion from the supported amount-specific operation and its observed result, not promise payout by linear multiplication. [E7-E10; inference]

The more serious concern is influence over the underlying state: a user can trade P, read/use the resulting rate in Q, and trade P again. Whether that profits depends on P/Q depth, fees, observation policy and exposure; no supplied source proves it cannot. A rate being read-only is not protection, and neither a one-share sale quote nor spot NAV is automatically safe.

Astra and Kimi prefer a **separate common-reference accounting adapter** as the downstream multiplier, explicitly a new product choice; Grok recommends withholding the provider/invariant integration; MiniMax proposes standardized/cadenced redemption-rate restrictions, including queues/rate limits. Coordinator recommendation: **keep the requested executable quote identifiable, build the hook on actual amount-specific settlement, and treat a separate downstream accounting/reference adapter as the preferred alternative to evaluate—not an accepted replacement or an instruction to drop the user's rate-provider goal.** No queue or new redemption restriction is adopted.

Do not assume an independent market. A same-P historical/TWAP reference may be useful if an observation mechanism actually exists, but remains endogenous, lagged and subject to sustained manipulation/availability limits. V4 core has no automatic pool TWAP. Current local backing pool is hookless; adding an oracle hook is neither already authorized nor the only conceivable observation arrangement. No Chainlink, peg or second deep pool is presumed. [L1; E4, E7-E10]

Require coherent read boundaries: manager-unlocked is not vault-busy. After V commits its operation, M can remain unlocked while a valid public rate read occurs. During V's mutation, use guards or an explicitly coherent authorized projected state. Transient state can be observed through the owning contract's accessor in the same transaction; another contract is not automatically blind to it. [E11; L2-L5]

Bootstrap, supply below one whole share, failed conversion depth, unavailable rate and stale observations need explicit behavior; do not invent a 1:1 rate or silently scale a smaller exit to claim an exact one-share quote. Fee income does not imply monotonic target-relative value or a peg.

## Required adaptations and decisions

Minimum conceptual work, not an implementation plan:

1. Keep one existing ERC20-share diamond per full-range backing basket and approved ownership/fee rules.
2. Add the narrowly authorized same-manager unlocked execution context, sharing economics with normal entry.
3. Enforce full caller-allocation conversion and one-token payout or atomic revert.
4. Preserve categorized input/idle/exit inventory, incumbent fee checkpoints and attributable share credit; retain the local disclosed zap-remainder policy rather than silently import two-token refunds.
5. Define correctly normalized read-only quote/provider semantics and coherent read timing; do not rename SY NAV as executable `getRate`.
6. Validate amount-specific preview parity and the complete composed swap's bounds/gas before implementation acceptance.

Genuine owner choices before implementation: the consuming pool's rate/pricing contract; observation/bootstrap/staleness/exposure policy; concrete H/Q authorization bindings. Existing full-range/ERC20/native/no-dead-share/no-fee/strict-atomic/registry decisions are not reopened.

**Answer to the user:** Weir is the closest *strategy*, but extending the existing local vault is the best *implementation base*. lpTOKEN contributes the strongest external accounting and exact-conversion mechanics. Adding ERC20 alone leaves the two biggest requirements—same-unlock hook settlement and defensible rate consumption—unsolved.

## Evidence, council and limits

All four exact Native routes supplied substantive originals and are retained under members/. No new-run peers were read during independent originals. One advisory pass remains pending on this frozen draft.

No implementation, PRD changes, tests/builds, deployment, wallet operation or runtime economic proof was performed. Local files were read as mutable working files. Public main branches are mutable; prior matched-source records are not proof of current funded deployments or safety. Context7 quota was exceeded, so official documentation/source was used directly.

### Public primary references

- E1 https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources — WeirVaults main source.
- E2 https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/LpTokenVault.sol — proportional portfolio funding, direct custody, unlock.
- E3 https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/periphery/ZapRouter.sol — full-consumption conversion and vanilla unlock path.
- E4 https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol — unlock/caller-owned positions/deltas/settlement.
- E5 https://raw.githubusercontent.com/Uniswap/v4-periphery/main/src/PositionManager.sol — ordinary and without-unlock entrypoints.
- E6 https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/CurrencyDelta.sol and https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/Hooks.sol — address/currency accounting and callback semantics.
- E7 https://docs.balancer.fi/concepts/core-concepts/rate-providers.html .
- E8 https://docs.balancer.fi/concepts/vault/token-scaling.html .
- E9 https://raw.githubusercontent.com/balancer/balancer-v3-monorepo/main/pkg/interfaces/contracts/solidity-utils/helpers/IRateProvider.sol .
- E10 https://raw.githubusercontent.com/balancer/balancer-v3-monorepo/main/pkg/solidity-utils/contracts/helpers/ScalingHelpers.sol .
- E11 https://eips.ethereum.org/EIPS/eip-1153 .
- E12 https://sourcify.dev/server/v2/contract/42161/0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0?fields=sources — The Pool vault/helper and adapter boundary.

### Local references

- L1 `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` — S1-D/P/X, S1-ACC-07, S1-QUOTE, S1-SEC; read locators recorded in originals.
- L2 `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol` — `_start`, `_action`, `_entrySnapshot`, `_mintCredit`, `_exit`.
- L3 `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol` — execute guard.
- L4 `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultSYQueryTarget.sol` — exchangeRate and quote guards.
- L5 `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol` and `contracts/interfaces/IStandardExchangeTransitionQuote.sol` — rate and projected-state interfaces.
- Prior full survey: `../v4-single-token-vaults-20261029-01a18660/REPORT.md`.
