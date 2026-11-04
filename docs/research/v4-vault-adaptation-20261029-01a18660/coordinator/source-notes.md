# Decisive source observations for the adaptation recommendation

Access date 2026-10-29. Research only; no code changes or executed transactions.

## Rate interface and consumer

- Official Balancer interface: https://raw.githubusercontent.com/balancer/balancer-v3-monorepo/main/pkg/interfaces/contracts/solidity-utils/helpers/IRateProvider.sol . Eighteen-decimal related-token exchange rate; explicitly context-dependent and rounding-sensitive. No amount, direction or slippage arguments.
- Official docs: https://docs.balancer.fi/concepts/core-concepts/rate-providers.html and https://docs.balancer.fi/concepts/vault/token-scaling.html . Rates read during pool operations; decimal scaling and rate scaling are separate. This is a balance/amount scaling input, not execution of backing-vault liquidation.
- Inference: a size-dependent executable redemption quote can be exposed as a normalized reference, but ABI compatibility alone does not establish safe use as a downstream invariant multiplier or a guarantee of price at arbitrary redemption size. No alternative NAV semantics is approved by this research.
- If q is target raw output from redeeming one whole share (10^shareDecimals raw), normalized rate is q * 10^18 / 10^targetDecimals, with defined rounding. Actual amount-specific previews remain separate. A pool-wide liquidation quotient is a different quantity.
- Context7 was attempted; monthly quota exceeded. No Context7 documentation answer was claimed.

## Same-manager hook composition

Canonical PoolManager: https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol .

- `unlock` rejects AlreadyUnlocked when already open; only the original outer callback owns that unlock. `_accountPoolBalanceDelta` attributes deltas to the operation caller; hook deltas have their own address. The final outer boundary checks the global nonzero-delta count.
- `modifyLiquidity` uses caller address as position owner and salt/range as identity. Moving liquidity operations to an adapter under a different caller does not automatically preserve position identity.
- `take`, `settle` and `settleFor` are accounting operations, not authority to pretend another address's credit is the vault's. Take can create caller debt, which must be covered.
- Inference: a legitimate already-unlocked execution service can operate inside the outer session, but must bind authorized hook/router, operation inputs/recipient/limits, payer/share ownership, position owner and delta settlement. Global isUnlocked alone is not authorization. Returning vault-owned deltas to their expected baseline is different from requiring the whole outer transaction's deltas to be zero immediately.
- Distinguish backing PoolKey from consuming PoolKey; forbid/guard recursive entry into the consuming hook. Different PoolManager topology is a separate case, not a reason to ignore the common same-manager case.

Canonical PositionManager: https://raw.githubusercontent.com/Uniswap/v4-periphery/main/src/PositionManager.sol , `modifyLiquidities` at line 172 and the following `modifyLiquiditiesWithoutUnlock` in accessed main.

- Has both `modifyLiquidities` and `modifyLiquiditiesWithoutUnlock`; the latter is an existence proof of supported already-unlocked action routing, not a drop-in guarantee for any vault.
- ERC721 ownership/approval, its own reentrancy lock and caller-specific settlement still apply. Its use does not make The Pool's existing zap adapter automatically nested-safe.

## Weir

Verified record: https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources . Coordinator parsed public JSON in memory and read principal source.

- Main source uses MIT SPDX. Full-range direct manager position, internal per-PoolId share ledger; not a one-ERC20 global fungible basket.
- Native `deposit` lines 159-183 and `withdraw` lines 186-203 both unconditionally call manager.unlock. Thus unmodified same-manager invocation from a swap hook reverts.
- Share issuance lines 253-267 uses added liquidity * existing share supply / existing liquidity. Pro-rata withdrawal lines 278-286 also allocates idle0/idle1.
- Inference: stored idle assets are part of the outgoing claim but absent as a separate input to issuance denominator; pre-entry compounding does not guarantee all imbalanced dust is invested. Explicit attribution work is needed before calling the result complete proportional ownership.
- Withdrawal lines 303-314 attempts conversion then settles both deltas, with no zero-unwanted-currency postcondition. Per-leg minima are lower bounds, not exclusivity assertions.
- Compounding and manager callback references use shared pool state and hookData; rate read must account for pending fees, idle balances, net costs and operation phase rather than blindly using previewRedeem (which excludes pending fees).
- A one-pool/one-share-token Crane instance is a simpler target than preserving Weir's multi-pool ledger and wrapping every ID. This is an architectural recommendation, not implementation.

## lpTOKEN

https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/LpTokenVault.sol and https://raw.githubusercontent.com/Steemhunt/lptoken-contracts/main/src/periphery/ZapRouter.sol .

- Current main has BSD-3-Clause SPDX headers and Solidity 0.8.36; source/dependency/version porting cannot be assumed compatible with the local family.
- Proportional two-currency ERC20 core, explicit idle/fee portfolio snapshots and separate swap periphery are useful accounting/execution references, not a proof every line is correct.
- `_modifyLiquidity` at lines 1173-1179 unconditionally unlocks. Zap `_swapExactInput` at line 833 onward also unlocks. Neither unmodified flow is nested-hook-safe on the same manager. Line offsets are from the fresh public fetch, not assumed identical to the earlier survey.
- Router enforces complete exact-input spend, output amount and actual received balance; exact one-token successful settlement is a stronger reference than Weir's residual payout.
- Family also brings factory/clone/launch-fee links, share fees, dead shares, fixed range and cooldown; these are not silently adopted into existing fee-free/no-dead-share Stage One law.

## Existing local project context

- Stage-one PRD `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, sections 1-3: already one full-range ERC20-share diamond with proportional two-currency basket ownership. Deliberately no dead shares/vault-level fees, bounded maintenance, strict atomic one-token exit domain, raw-unit SY accounting rate. Exact-output unsupported.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol:323` and `:548`: explicit ManagerAlreadyUnlocked rejection in `_start` and `_action`. A simple removal of the guards is not sufficient; planning/settlement were designed for separate manager unlocks.
- `.../UniswapV4PairTokenStandardExchangeVaultSYQueryTarget.sol:73` onward: SY exchangeRate is spot accounting, not executable exit or issuance.
- Wings `.../UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol:27`: current getRate is total portfolio liquidation quote / supply. That is not the same as simulating withdrawal of one whole share. It must not be mislabeled as already satisfying remembered one-share quote semantics.
- Wings `.../UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol:43`: also rejects unlocked manager.
- Remembered quote-design discussions are context, not current implementation authorization. Current user's question does not authorize modifying these contracts, PRDs or migrations.

## Issues to resolve when synthesizing the first originals

These notes are source checks, not a draft recommendation before all originals settle.

- MiniMax's categorical "only direct owner liquidity can act inside an unlocked manager" and "PositionManager unavailable" are contradicted by canonical `modifyLiquiditiesWithoutUnlock`. Direct custody remains a simplicity preference, not a protocol exclusivity law. lpTOKEN itself also uses direct manager custody.
- MiniMax's claim that another contract cannot observe transient manager state in the same transaction is incorrect. EIP-1153 permits TLOAD in STATICCALL and owning contract frames share their transaction-local store; a caller can observe manager transient state through the manager's view/accessor. A separate transaction is different. Source: https://eips.ethereum.org/EIPS/eip-1153 .
- NonzeroDeltaCount counts nonzero address/currency delta slots, not only distinct currencies. Different addresses' same-currency debts are not automatically interchangeable.
- A scalar reference price need not guarantee size-linear redemption to be a pool pricing input. Official Balancer docs accept oracle prices as well as balance ratios. An amount-dependent one-share exit quote is therefore not categorically forbidden, but it is neither a guaranteed arbitrary-size payout nor automatically manipulation-safe. Do not turn a real risk into a universal impossibility claim.
- MiniMax's proposal to queue or rate-limit redemptions as the default changes the requested atomic hook route and does not prove absence of arbitrage. It is not adopted without an explicit new product choice. Grok's preference to omit the requested Rate Provider also does not satisfy the user's stated goal; preserve it as dissent, not a unilateral scope change.
- A same-pool TWAP can be available without assuming an independent market; "not independent" does not prove useless. Hook-based observation is not the only imaginable observation-maintenance arrangement. Do not silently change the current hookless backing-pool requirement or assert an oracle hook is mandatory.
- Grok proposes saving/restoring the manager's global sync slot. There is no adopted arbitrary restore API. Settlement sequencing must respect shared sync/checkpoint state using supported operations; do not prescribe raw transient mutation or assume a prior checkpoint can be restored after balances change.
- The current local PRD already specifies pro-rata booked idle ownership and excludes vault-level fees/dead shares. Those are not new open owner decisions solely because an original failed to read all sections. Distinguish new unresolved rate/topology decisions from settled local product law.
