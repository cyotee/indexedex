# Which V4 fee vault should IndexedEx adapt?

Date: 2026-10-29. Explicit user request for a council recommendation; assessment only, not implementation, PRD amendment or migration authorization.

## User's complete clarification

> The WeirVaults seems like the closest fit for what we want. We would just need to ass the ERC20 and related interfaces. Our goal is to use our vault as liquidity in other pools where we can apply a Balancer V3 type Rate Provider so we can price the vault token as one of the underlying tokens. So we need the vault to be able to accept deposits of a single token, and produce a single token for withdrawals as part of a swap using our custom Uniswap V4 hook. Of the vaults you found, which does the council think would be best for us to adapt to our needs?

Read "ass" as "add", based on the complete sentence, without an unrelated search.

## Deliverable and common inputs

Independently recommend the best foundation, not the product with most marketing features. Rank Weir, lpTOKEN and The Pool against the clarified use, briefly dispose of ALPS/USDa/Unoxi/ZapVault. Distinguish best strategy model, best accounting/periphery reference, and lowest actual adaptation burden.

Read the complete prior final comparison (shared admitted evidence, not a new peer answer):

`docs/research/v4-single-token-vaults-20261029-01a18660/REPORT.md`

Prior source-notes, original responses and feedback in that run are admitted if a specific claim requires detail. New originals for this follow-up remain independent: do not read another member's response under this new run until advisory. Preserve all earlier artifacts.

## Requirements and critical questions

1. Fee-exposed V4 liquidity backs a transferable ERC20 share usable as another pool's asset. User prefers Weir's simple full-range model; assess without treating that preference as a predetermined answer.
2. Accept a single underlying token and return a single underlying token synchronously within a hook-driven swap. A successful exact-input route must not silently leave a second payout/residual custody or become queued/in-kind. Failure can revert; no promise of unlimited exit depth.
3. Separate backing pool from share-consuming pool. Analyze the important same-PoolManager topology: the hook callback already runs inside an unlocked manager. Vanilla Weir deposit/withdraw call unlock again. Does that work? What minimal authorized unlocked-entry settlement design is required? A different PoolManager is a topology condition, not a universal fix.
4. Compare global manager unlock state, caller-specific deltas, direct vault-owner liquidity, PositionManager routes, restricted callback authorization, nested hook recursion, and transient accounting/read consistency. Do not recommend an unguarded isUnlocked bypass.
5. Rate provider: one related-underlying-denominated rate, 18-decimal fixed point, read-only and callable by the downstream pool. Decimal normalization must distinguish one whole share from raw units. ABI alone does not make an LP share a safe exchange-rate asset. Rates can fall from price movement/IL/costs; "fee earning" does not imply monotonic appreciation or a peg.
6. Keep three concepts distinct: proportional ownership/share issuance; accounting/SY value; actual executable target-token withdrawal-and-sale quote. Prior remembered discussion favored normalized one-share target exit getRate rather than silently replacing getRate with NAV. That memory is not implementation authority, and current stage-one SY uses a different explicit accounting rate. Explain whether a normalized one-share executable quote is fit as a downstream invariant multiplier; it cannot linearly promise outputs for arbitrary size. If proposing NAV or another rate as the downstream multiplier, label it an alternative/new product choice, not an accepted replacement.
7. Assume a volatile target might have liquidity only in the backing pool. Do not solve the problem by assuming Chainlink, a second deep pool, a peg, or an independent market exists. An underlying-pool TWAP can be the available reference; distinguish its independence from its possible utility. State tradeoffs and evidence, not a blanket prohibition or unsupported safety proof.
8. Weir's existing share issuance is liquidity-ratio based; portfolio includes idle dust. Examine idle/fees/refunds and entrant conversion-cost attribution before claiming ERC20 alone suffices. Pending fees, pre-entry reinvestment, partial withdrawal fee settlement, floor rounding, locked shares, hook fees and compounding liveness are relevant.
9. Scope excludes a new general swap simulator/projector. Identify amount-specific preview parity/gas requirements without reproducing a large implementation plan. Prior stage-one gas complexity is context, not permission to drop atomicity or owner-approved limits.
10. Crane Diamond/registry and standard SE/SY interfaces are existing project packaging constraints. Do not force ERC4626 semantics if the basket is naturally two-currency or exact-output unsupported. Assess source licensing only if choosing to copy exact code: public verification is not a license grant.

## Read-only local evidence

- `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, sections 1-3 and pricing/lock-state sections if needed. Current PRD expressly has one full-range ERC20-share diamond, no permanent dead shares, no vault-level protocol fee, conditional bounded maintenance and atomic one-token rejection; SY rate is spot accounting and not issuance.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol`, `_start` and `_action`: coordinator read manager-already-unlocked rejection at lines 323 and 548. Existing implementation is not automatically hook-composable.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultSYQueryTarget.sol`, `exchangeRate`: explicitly spot accounting, not exit quote or issuance.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol`, `getRate`: actual current code uses normalized whole-portfolio liquidation value divided by supply; do not mislabel that as already implementing a one-whole-share exit.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol`, `execute`: rejects already-unlocked manager.
- `contracts/interfaces/IStandardExchangeTransitionQuote.sol`: projected sequential quote interfaces; research context, not implementation authorization.
- `lib/crane/contracts/external/balancer/v3/interfaces/contracts/solidity-utils/helpers/IRateProvider.sol`: 18-decimal rate interface, context-dependent semantics and rounding warning.

Local files can change; cite the lines/functions actually read and do not claim a frozen repository snapshot. This is a comparative recommendation, not an audit of every existing vault.

## Public primary sources to verify narrowly

- Weir matched source: https://sourcify.dev/server/v2/contract/4663/0x9bb6A517A8dB43a55e4A873C0313D7bFADd70110?fields=sources . Principal `src/WeirVaults.sol` was readable before later dependency truncation.
- lpTOKEN vault and zap: https://github.com/Steemhunt/lptoken-contracts .
- The Pool matched source: https://sourcify.dev/server/v2/contract/42161/0xf79c2dc829cd3a2d8ceec353bdb1b2414ba1eee0?fields=sources .
- Canonical V4: https://github.com/Uniswap/v4-core/blob/main/src/PoolManager.sol ; https://github.com/Uniswap/v4-periphery/blob/main/src/PositionManager.sol .
- Balancer V3: https://github.com/balancer/balancer-v3-monorepo/blob/main/pkg/interfaces/contracts/solidity-utils/helpers/IRateProvider.sol ; current official Vault token-rate scaling sources/docs.

Context7 was attempted by coordinator and returned monthly-quota exceeded. Use official sources directly rather than invent a Context7 result. Generalized public queries only; do not send private code or local paths to public services.

## Original response shape

Return: preferred foundation and runner-up; requirement-fit table; why "add ERC20" is sufficient or not; same-manager hook call/settlement sketch in prose; ownership/issuance versus rate/exit semantics; minimal required adaptations; clear owner decisions if any; sources/limits. Concrete recommendation first, no deferral to another council. An amount-dependent quote is not a universal invariant-safe rate merely because its ABI matches.

Write only assigned `members/<name>/response.md` with apply_patch if active; otherwise return the COMPLETE original inline, with no alternate write tool. No implementation, shared-file edits, shell, Git, tests/builds, installs, deployment, wallets, further delegation, or external messages. Stop after the original.

## Council procedure

Full four-member recommendation on the same exact Native routes as the completed research: Astra `chatgpt-subscription/gpt-6-astra:high`, Grok `xai/grok-4.7:xhigh`, MiniMax `minimax/MiniMax-M3`, Kimi `kimi-coding/k3.1-pro:high`. Reuse eligible originals through task_send; if Native continuity fails, disclose and do not silently replace routes/sessions. Invoking-agent coordinator. All originals settle before synthesis, then one same-draft advisory each, then coordinator resolution/final report. No second advisory round.
