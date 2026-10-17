# Grok — REQ-SEP-04 site list

The owner answer is closed. Exact-output refunds `min(unbooked, declared maximum) - used`. Exact-input processes declared `amountIn` and does not refund undeclared surplus. A declaration that differs from the whole surplus does not revert for that reason alone. Do not refund the entire unbooked remainder. Do not add a ledger.

`contracts/protocols/dexes/uniswap/v4` is out of scope. Slipstream is not restored. `AGENTS.md`, `CLAUDE.md`, and `SKILL.md` are not targets. Historical notes under `docs/reviews/` and `docs/research/` are not targets. Preserved copies under `docs/audits/apex-2026-09-17-evidence/followup-review/` are not targets.

## Code edits

None.

No production path read in this search reverts only because the declaration differs from the whole surplus. No production path read refunds the entire unbooked remainder. Prepaid exact-input credits the declared amount when unbooked value covers it and leaves the undeclared surplus. Prepaid exact-output refunds only the unused part of `min(unbooked, declared maximum)`. A shortfall reverts. It is not filled from booked inventory.

## No code edit

Leave these executable paths unchanged:

- `contracts/vaults/basic/BasicVaultCommon.sol:80-106` and the exact-out refund at `:108-119`
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:450-464` and `:501-506`
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol:189-203` and `:240-245`
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:974-988` and `:1025-1030`
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:864-874` and `:909-917`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:905-914` and `:945-953`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol:905-914` and `:945-953`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:81-87`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:242-271` and `:288-313`
- `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol:310-331`
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeOutTarget.sol:75-99`
- `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:324-341` and `:352-362`
- `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:455-470` and `:493-500`
- `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol:452-467` and `:504-509`
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol:117-138`
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:162-200` and `:235-266`
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:872-913`
- `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:151-187`
- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:467-506`
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2206-2244`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:485-524`
- `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:267-296`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol:769-795`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenTarget.sol:239-259`
- `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:159-166`

Callers of these helpers are the same shape. Do not edit them. Do not edit Slipstream.

## Comment edits

Replace only the cited sentence. Do not change a signature. Use the README replacement meaning: the caller declares the bound; unused declared credit is refunded on exact-output; undeclared surplus is not refunded; a surplus mismatch is not by itself a revert; booked inventory is not spent.

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol:126` and `:137`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol:11`, `:24`, `:30`, `:36`, `:42`, and `:48`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol:12`, `:21`, `:27`, `:33`, `:39`, and `:45`
- `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol:11`, `:24`, `:30`, `:36`, `:42`, and `:48`
- `contracts/interfaces/detf/IDetf.sol:169` and `:238`
- `contracts/interfaces/IRebasingClaimToken.sol:177` and `:188`
- `contracts/interfaces/IStandardExchangeInMulti.sol:27`
- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56`
- `contracts/vaults/basic/BasicVaultCommon.sol:69-70` and `:76`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:24-26`
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol:77`
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:44`
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:55`

Do not edit comments that already say false-flag exact-output pulls quoted used and refunds nothing, or that true-flag exact-output refunds only `min(unbooked, maximum) - used`. Those match. `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:57` and `:63` match. Do not edit them.

## Documentation edits

Replace the withdrawn equality-revert or unqualified never-refund sentence with the same meaning. Do not rewrite README lines 3 and 56.

- `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32` and `:38`. Use the two replacement sentences in the PRD.
- `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.plan.md:261`. It still says `exchangeIn` requires `actualIn == amountIn` and reverts when surplus makes `U != T`.
- `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md:14`, `:63`, `:172`, and `:202`
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21` and `:111`
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md:45`
- `docs/agent/INDEXEDEX_AGENT_LAW.md:422`
- `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:124`
- `docs/audits/apex-2026-09-17-evidence.md:61`
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:78`, `:80`, `:329`, and `:336`
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:100` and `:105`
- `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md:38`
- `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:159`
- `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:419`
- `docs/plans/UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md:48`
- `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:214`
- `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md:376`
- `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md:7` and `:152`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInTarget.sol:220` is the same sentence. Do not edit it.

False-flag sentences that say a pull of quoted used refunds nothing are not this edit.

I did not run Forge.
