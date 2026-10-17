# Grok — REQ-C06 plan draft

Controlling text: `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md`. This file is not `REMEDIATION_PRD.plan.md`. No code was edited.

Spot-check: all 21 named lines still assign `_pretransferCredit`. Hookless and Pons already import `LocalCreditLib` at line 18. The V3 delegate already imports it at line 7. Uniswap V2, Camelot, Rocket Pool, and Lido out targets do not.

## Stop

Before each edit, read the named line. If that line does not assign `_pretransferCredit`, stop and report the file and line. Do not choose another site. Do not edit EtherFi, Slipstream, or `contracts/protocols/dexes/uniswap/v4`. Do not edit the ten caller-first sites named in the PRD. Do not edit `_requirePrepaidCredit`, `_secureTokenTransfer`, `_securePull`, or `_secureSelfBurn`. Do not move an input ceiling, a quote, a refund, or settlement.

## 1. Imports

Add this import only in the four files that do not already have it. Place it immediately after that file's existing exchange-common or interface import block, and before the contract declaration. Do not add it to hookless, Pons, or the V3 delegate.

```solidity
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
```

Files: `UniswapV2StandardExchangeOutTarget.sol`, `CamelotV2StandardExchangeOutTarget.sol`, `RocketPoolRETHStandardExchangeOutTarget.sol`, `LidoWstETHStandardExchangeOutTarget.sol`.

## 2. Inserts

At every listed site except the V3 mint, insert the check as a new statement immediately before the credit assignment. Do not put it inside the later `if (pretransferred)` or `if (prepaid)` block. That later block stays after the measurement and keeps its existing credit comparison.

Use `prepaid` only at hookless line 165 and Pons line 165:

```solidity
if (prepaid) {
    LocalCreditLib.requirePretransferCaller(msg.sender);
}
```

Use `pretransferred` at every other listed site, including hookless line 94 and Pons line 94:

```solidity
if (pretransferred) {
    LocalCreditLib.requirePretransferCaller(msg.sender);
}
```

Sites:

- Hookless `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94` and `:165`
- Pons `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:94` and `:165`
- Uniswap V2 `UniswapV2StandardExchangeOutTarget.sol:462`, `:547`, `:623`, `:693`, `:794`, `:905`, `:972`
- Camelot `CamelotV2StandardExchangeOutTarget.sol:411`, `:513`, `:596`, `:663`, `:766`
- Rocket Pool `RocketPoolRETHStandardExchangeOutTarget.sol:60` and `:82`
- Lido `LidoWstETHStandardExchangeOutTarget.sol:64` and `:85`

A false flag does not enter these statements.

## 3. V3 mint move

In `executeZapInMintExactOut` only, after `IERC20 token = IERC20(tokenIn);` and before the credit assignment at line 102, insert:

```solidity
if (pretransferred) {
    LocalCreditLib.requirePretransferCaller(msg.sender);
}
```

Delete the existing `LocalCreditLib.requirePretransferCaller(msg.sender);` from the later pretransfer block. Leave `if (amountIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, credit);` and `pullAmount = credit;` in that later block. Do not add an unguarded check. Do not edit `executeZapOutWithdrawal`.

## 4. Named tests

One family's test does not close another. A test-contract caller is not the code-less assertion. The code-less caller is `makeAddr`, and the test asserts `code.length == 0`. The contract caller is the existing `AtomicPretransferCaller` stub. Do not use a bare `vm.expectRevert()`.

True-flag short credit means no token is transferred to the vault before the call. The code-less call uses `vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector)`. The contract call uses `vm.expectRevert(ISecurePullErrors.TransferDeltaInsufficient.selector)`. After each revert, vault `totalSupply` and the vault balance of the input token equal the pre-call values. The credit error must not be the selector reached by the code-less call.

The false-flag call uses the same code-less address, the same route, and flag `false`. It is not wrapped in `expectRevert`. It must return. If it reverts `EOAPretransferNotAllowed`, the test fails.

Quote with `previewExchangeOut` on the production proxy. Use that quote as `maxAmountIn` and as `amountOut`'s pair. Do not hard-code an amount. If the preview reverts or returns zero, stop and report that route. Do not pick another route.

Existing production-proxy tests, and the one new file where an assertion has no home:

| Family | Existing production-proxy test | Assertion home |
| --- | --- | --- |
| Hookless | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol` | Direct-out already lives in `test_review_underfundedEoaExactOutObservesCreditError`, `test_review_underfundedContractExactOutObservesCreditError`, and `test_review_falseFlagEoaExactOutDoesNotUseCallerGuard`. Do not edit that file. Mint has no home. Add only `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ReqC06MintCallerOrder.t.sol`. |
| Pons | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol` | Same split. Do not edit that file. Add only `.../ponsFamilyV2Hook/ReqC06MintCallerOrder.t.sol`. |
| V3 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol` | That file covers quoted exact-out, which is left alone. Mint has no home. Add only `.../release/v3/ReqC06MintCallerOrder.t.sol`. |
| Uniswap V2 | `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol` | That file's EOA swap check pushes credit first and does not cover the seven lines. Add only `.../uniswap/v2/ReqC06CallerOrder.t.sol`. |
| Camelot | `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol` | Same gap. Add only `.../camelot/v2/ReqC06CallerOrder.t.sol`. |
| Rocket Pool | `test/foundry/spec/protocol/staking/rocket-pool/RocketPoolRETHStandardExchange_Core.t.sol` | Out-line assertions have no home. Add only `.../rocket-pool/ReqC06CallerOrder.t.sol`. |
| Lido | `test/foundry/spec/protocol/staking/lido/LidoWstETHStandardExchange_Core.t.sol` | Out-line assertions have no home. Add only `.../lido/ReqC06CallerOrder.t.sol`. |

New-file rules:

- Hookless and Pons mint files extend the same acceptance base as the sibling `ApexRecurrenceErrorOrder` test and call `_bootstrap()`. The only route is pool token in, vault share out. Three tests: code-less true flag, contract true flag, code-less false flag.
- The V3 mint file extends `UniswapV3FullSpreadApexRecurrenceErrorOrderTest`. The only route is pool token in, vault share out, through `vault.exchangeOut`. Do not call the delegate. Three tests, same three shapes.
- The V2 file extends `UniswapV2StandardExchange_SecRemediation_Test` and uses `_vault()`. Seven routes, three tests each, no other route. Pass-through swap: the two pool tokens already used by that base. Pass-through zap-out: pair token in, one pool token out. Vault deposit: pair token in, vault share out. Vault withdrawal: vault share in, pair token out. Zap-out vault withdrawal: vault share in, one pool token out. Zap-in vault deposit: one pool token in, vault share out. Pass-through zap-in: one pool token in, pair token out. These are the seven lines in order: 462, 547, 623, 693, 794, 905, 972.
- The Camelot file extends `CamelotV2StandardExchange_SecRemediation_Test` and uses its `vault`. Five routes, three tests each. Pass-through swap, pass-through zap-out, vault deposit, vault withdrawal, zap-out vault withdrawal. Those are lines 411, 513, 596, 663, 766. Use that file's existing pool-token fixtures. Do not add the two V2-only routes.
- Rocket Pool extends `RocketPoolRETHStandardExchange_Core_Test`. Line 60: WETH in, vault share out. Line 82: WETH in, rETH out. Three tests on each route. No stETH route.
- Lido extends `LidoWstETHStandardExchange_Core_Test`. Line 64: WETH in, vault share out. Line 85: WETH in, wstETH out. Three tests on each route. No stETH route.

## 5. Commands

Run this from the repository root after the edits. Do not add a Forge profile. Do not add EtherFi, Slipstream, or legacy V4 paths.

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol \
  contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol \
  contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ReqC06MintCallerOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ReqC06MintCallerOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ReqC06MintCallerOrder.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/ReqC06CallerOrder.t.sol \
  --test-root test/foundry/spec/protocol/dexes/camelot/v2/ReqC06CallerOrder.t.sol \
  --test-root test/foundry/spec/protocol/staking/rocket-pool/ReqC06CallerOrder.t.sol \
  --test-root test/foundry/spec/protocol/staking/lido/ReqC06CallerOrder.t.sol \
  --consumer test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ReqC06MintCallerOrder.t.sol \
  --consumer test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ReqC06MintCallerOrder.t.sol \
  --consumer test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ReqC06MintCallerOrder.t.sol \
  --consumer test/foundry/spec/protocol/dexes/uniswap/v2/ReqC06CallerOrder.t.sol \
  --consumer test/foundry/spec/protocol/dexes/camelot/v2/ReqC06CallerOrder.t.sol \
  --consumer test/foundry/spec/protocol/staking/rocket-pool/ReqC06CallerOrder.t.sol \
  --consumer test/foundry/spec/protocol/staking/lido/ReqC06CallerOrder.t.sol
```

Report that command and its exit code. A present test file is not a pass.

I did not run Forge.
