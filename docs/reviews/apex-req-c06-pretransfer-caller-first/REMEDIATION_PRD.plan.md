# Implementation plan — caller check before pretransfer credit

- **Date:** 2026-10-16
- **Status:** DRAFT. This plan does not authorize code, test, config, or script edits. A later session must be explicitly asked to implement it. The 2026-10-11 plan in this path is withdrawn. Do not execute it.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-C06. EtherFi, Slipstream, and `contracts/protocols/dexes/uniswap/v4` are not this plan.
- **Council:** Astra replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax replacement `ses_ebdf718feffemWQNf7wuTpapqX` does not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. Kimi replacement `ses_ec3d04e91ffeJa0is24e2jZv06` does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No Forge run. Consensus is not proof.
- **Drafts:** `reviewers/astra-c06-plan.md`, `reviewers/grok-c06-plan.md`, `reviewers/minimax-c06-plan.md`, `reviewers/kimi-c06-plan.md`, and the four `*-c06-plan-cross.md` files. Those drafts are inputs. This file is the consolidation.

## Closed sentence

Add the C06 assertions to exactly these seven existing files, and to no new file: hookless `ApexRecurrenceErrorOrder.t.sol`, Pons `ApexRecurrenceErrorOrder.t.sol`, V3 release `ApexRecurrenceErrorOrder.t.sol`, `UniswapV2StandardExchange_SecRemediation.t.sol`, `CamelotV2StandardExchange_SecRemediation.t.sol`, `Adversarial_RocketPoolRETH_P0.t.sol`, and `Adversarial_LidoWstETH_P0.t.sol`. Cover all 2, 2, 1, 7, 5, 2, and 2 repaired branches. Do not substitute one branch for another.

## What not to do

- Do not execute the withdrawn 2026-10-11 steps. Do not put the V3 quoted-swap check back in front of a comparison that already follows it. Do not limit the repair to three FullSpread branches.
- Do not edit EtherFi, Slipstream, `contracts/protocols/dexes/uniswap/v4`, or the ten caller-first sites named in the PRD.
- Do not edit `_requirePrepaidCredit`, `_secureTokenTransfer`, `_securePull`, or `_secureSelfBurn`.
- Do not move a quote, an input ceiling, a refund, or a settlement statement.
- Do not add the caller check to a false flag. Do not add an unguarded check before the V3 mint ternary.
- Do not create a test file. Do not use a bare `vm.expectRevert()`.
- Do not reset unrelated working-tree changes. Record them and preserve them.
- Do not enable `via_ir` or delete `out/` or `cache_forge/`.

## Step 1 — stop if a named line drifted

Before any edit, read the 21 measurement lines in the PRD table. Each must still assign `_pretransferCredit`. If one does not, stop and report that file and line. Do not choose another site.

## Step 2 — production edits

Add `import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";` only to the Uniswap V2, Camelot, Rocket Pool, and Lido out targets. The hookless target, the Pons target, and the V3 delegate already import it. Do not add a duplicate.

At every listed site except the V3 mint, insert this statement immediately before the credit assignment. Use `prepaid` at hookless line 165 and Pons line 165. Use `pretransferred` everywhere else.

```solidity
if (pretransferred) {
    LocalCreditLib.requirePretransferCaller(msg.sender);
}
```

Sites: hookless 94 and 165; Pons 94 and 165; Uniswap V2 462, 547, 623, 693, 794, 905, and 972; Camelot 411, 513, 596, 663, and 766; Rocket Pool 60 and 82; Lido 64 and 85.

For `executeZapInMintExactOut` only, move the existing `LocalCreditLib.requirePretransferCaller(msg.sender);` out of the later pretransfer block. Place it in a new `if (pretransferred)` block after `IERC20 token = IERC20(tokenIn);` and before the credit measurement. Leave `if (amountIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, credit);` and `pullAmount = credit;` in the later block. Do not leave a second caller check in that later block. Do not change `executeZapOutWithdrawal`.

## Step 3 — tests

Add cases to these files only:

| Family | File | Branches |
| --- | --- | --- |
| Hookless | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol` | Mint 94 and direct-out 165 |
| Pons | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol` | Mint 94 and direct-out 165 |
| V3 | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol` | Mint 102 only |
| Uniswap V2 | `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol` | 462, 547, 623, 693, 794, 905, 972 |
| Camelot | `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol` | 411, 513, 596, 663, 766 |
| Rocket Pool | `test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol` | WETH-to-share mint 60 and WETH-to-rETH 82 |
| Lido | `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol` | WETH-to-share mint 64 and WETH-to-wstETH 85 |

Uniswap V2 branch order is token swap, LP-to-token, LP-to-share, share-to-LP, share-to-token, token-to-share, and token-to-LP. Camelot branch order is token swap, LP-to-token, LP-to-share, share-to-LP, and share-to-token. Do not add Camelot token zap-in cases. Those routes are unsupported.

Each branch gets these four controls. Use a supported fixture with a nonempty share book where the route needs one, a valid deadline, and a maximum large enough for the quote. Assert those preconditions before the call. An earlier ceiling, empty-book, or route rejection is not the credit witness.

1. A code-less true-flag caller with short credit reverts `ISecurePullErrors.EOAPretransferNotAllowed.selector`. Caller, recipient, and vault token and share balances, total supply, and the relevant booked reserves are unchanged from the instant before the call.
2. An allowed contract caller with short credit reverts the full `ISecurePullErrors.TransferDeltaInsufficient(required, available)` data. The same balances and books are unchanged. Use the existing `AtomicPretransferCaller` for a direct call. For the V4 nested mint, the Acceptance contract is the caller. Do not use this contract caller as the code-less case.
3. A code-less false-flag caller on a supported pull route succeeds. Returned input equals the fixture quote where the route promises quote parity. The debit equals that input. The input does not exceed the maximum. Output follows the route's existing payout. Exact-output mint issues the requested shares. Do not change production rounding to force a different payout.
4. A funded allowed-contract true-flag call succeeds, spends no more than the maximum, and reconciles input, refund, output, and shares under the unchanged route.

Hookless and Pons exact-output mint is admitted only inside the PoolManager session. Use the existing Acceptance `_nested` helper and `_bootstrap` share book for the contract-caller short-credit and funded mint controls. Do not mock the unlock. Do not accept `InvalidRoute` in place of the contract-caller credit error.

The code-less true-flag mint control calls the idle proxy and expects `EOAPretransferNotAllowed`. The code-less false-flag mint control in that same idle fixture expects `IStandardExchangeErrors.InvalidRoute(tokenIn, address(vault))` and unchanged balances. Do not invent idle mint success. The funded false-flag mint still succeeds through the existing `_nested` fixture. The direct-out false-flag control remains a successful code-less call.

The V3 file must fund its two-token share book through the existing production multi-in path before the mint cases. Do not change a shared TestBase to do that.

If a fixed fixture cannot reach the named comparison, stop and report the precondition. Do not weaken the error, catch the failure, or move the test to another file.

## Step 4 — inspect the diff, then run

Inspect the diff at all 21 sites before treating a revert as order evidence. Each guarded caller check must precede the measurement and every consumer of that measurement. Each existing credit comparison must remain. Record that inspection in `EXECUTION_REPORT.md` in this directory.

Record `git status`. Preserve unrelated changes. Default Foundry profile. Do not set `FOUNDRY_PROFILE=fork`.

From the repository root:

```bash
python3 scripts/forge-artifacts.py plan \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol \
  contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol \
  contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol \
  --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol \
  contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol \
  contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol \
  --test-root test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol \
  -- -vv
bash scripts/apex_bare_expectrevert_scan.sh --check
```

Run each named test file whole. A failed build stops the test command. A scanner site added by this item is a failure. Do not edit a selected test to make `--check` exit 0 except by replacing a bare expectation this plan forbids. Report the commands, the toolchain, and every result in `EXECUTION_REPORT.md`. A present assertion is not a pass until that run is reported.

## Done when

- The diff has 20 new guarded insertions and one V3 guarded move. Four imports were added. No excluded file changed.
- Each of the 21 branches has the four controls in its named file.
- The artifact commands and the scanner check are recorded.

## Dissent

Grok and the MiniMax replacement would put the Uniswap V2 cases in `UniswapV2StandardExchange_InOutInvariant.t.sol`. The MiniMax replacement would put the Camelot cases in `CamelotV2ZapOutMaxAmountIn.t.sol`. Those files exist. This plan uses the security-remediation suites because they already pin the caller error, and it still requires every repaired branch in those suites. Kimi's first-draft permission to cover one representative branch is withdrawn.
