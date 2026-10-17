# Remediation PRD — caller check before pretransfer credit

- **Status:** DRAFT
- **Date:** 2026-10-15
- **ID:** REQ-C06
- **Severity:** Low
- **Review target:** Every in-scope production call of `_pretransferCredit` that still runs before `LocalCreditLib.requirePretransferCaller`.
- **Controlling application text:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md`, REQ-C06. This file names the sites that text left unnamed. Where the 2026-10-11 body of this file conflicts, this body controls.
- **Astra participation:** Substantive first pass and substantive cross-review. Labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`. It does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. Not censored.
- **Grok:** `ses_ec4128917ffeeVds3Y2p7xrVjp`. The first call timed out. The original was collected by resuming that same session. That is continuation, not a replacement. Cross-review completed.
- **MiniMax M3:** Labeled replacement `ses_ebdf718feffemWQNf7wuTpapqX`. It does not recall `ses_ec41255ceffeVhrySLQe8hwwMC`.
- **Kimi K3:** Labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. It does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`.
- **Execution evidence:** No Forge run. A present check is not a pass. Consensus is not proof.

Writing this PRD does not authorize code, test, configuration, or deployment changes.

## Required outcome

On a pretransfer, the caller is authenticated before the credit is measured and before any quote or plan that consumes that measurement. A code-less caller is rejected with `EOAPretransferNotAllowed` even when the pushed credit is also short. The existing credit comparison stays and runs after that caller check. A false flag does not gain this check.

This is diagnostic order. It is not an authorization bypass, and it is not REQ-C02.

The closed sentence is: repair exactly the 21 measurement-first call sites in the seven-file table below, including measurement used only for a later refund, by placing a true-flag-only caller check before each credit measurement and any computation that consumes it, retain the existing credit comparisons and false-flag behavior, leave the ten caller-first sites unchanged, record but do not edit the two EtherFi sites or deprecated Slipstream, exclude the deleted legacy V4 tree, and assign no further site search to the implementer.

## Repair table

Line numbers are the current credit-measurement lines. If a named line no longer assigns `_pretransferCredit`, stop and report. Do not choose another site.

| File | Measurement lines |
| --- | --- |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol` | 94, 165 |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol` | 94, 165 |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` | 102, mint function only |
| `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol` | 462, 547, 623, 693, 794, 905, 972 |
| `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol` | 411, 513, 596, 663, 766 |
| `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeOutTarget.sol` | 60, 82 |
| `contracts/protocols/staking/lido/LidoWstETHStandardExchangeOutTarget.sol` | 64, 85 |

## Exact edit

At every listed site except the V3 mint, insert this check as a new statement immediately before the credit assignment. Use `prepaid` at hookless line 165 and Pons line 165. Use `pretransferred` at every other listed site.

```solidity
if (pretransferred) {
    LocalCreditLib.requirePretransferCaller(msg.sender);
}
```

The two direct-out sites use `if (prepaid)` with the same call. Add the `LocalCreditLib` import only where the file does not already import it. Do not insert the check inside the later `if (pretransferred)` block. That block is after the measurement. Do not move the input-ceiling comparison, the quote, the refund, or the settlement. Keep `_requirePrepaidCredit`, `_secureTokenTransfer`, `_securePull`, and `_secureSelfBurn` unchanged, including the second caller check already inside them.

For the V3 mint function `executeZapInMintExactOut`, do not add an unguarded check. Move the existing `LocalCreditLib.requirePretransferCaller(msg.sender)` from the later pretransfer block to a new `if (pretransferred)` block after the `IERC20` conversion and before the credit measurement. Leave `if (amountIn > credit) revert ISecurePullErrors.TransferDeltaInsufficient(amountIn, credit);` and `pullAmount = credit;` in that later block.

## Leave alone

These already check the caller before measurement. Do not edit them:

- `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol` `_executeQuotedSwapOut`, check at 82, measurement at 83.
- V3 `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` withdrawal, check at 31, measurement at 32.
- `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol`, check at 39, measurement at 40.
- Hookless and Pons `*OutExecutionDelegate.sol` withdrawal, check at 36, measurement at 37, in each file.
- Hookless and Pons `*OutMultiTarget.sol`, check at 45, measurement at 46, in each file.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutExecuteTarget.sol`, checks at 290, 396, and 488.

Do not edit `contracts/protocols/dexes/uniswap/v4`. That tree is being deleted.

## Recorded, not edited

- `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeOutTarget.sol:61` and `:84` have the same measurement-first order. The application draft says no EtherFi change. Do not edit them in this item.
- Slipstream `SlipstreamStandardExchangeOutTarget.sol:85` has the same order. Do not restore or edit Slipstream.

## Acceptance criteria

- Each of the 21 sites authenticates a true-flag caller before `_pretransferCredit` and before a quote or plan that consumes that measurement.
- A code-less true-flag caller with short credit reverts `EOAPretransferNotAllowed`. The credit error is not the one reached. No tokens move.
- A contract caller allowed to pretransfer, with short credit, still reverts the existing credit error. No tokens move.
- A false-flag call does not revert `EOAPretransferNotAllowed` merely because the caller has no bytecode.
- The ten caller-first sites, both EtherFi sites, Slipstream, and the deleted legacy V4 tree are unchanged.
- One family's test does not close another. The later plan names the existing production-proxy test for each of the seven files. It does not invent a file during implementation.

## Non-goals

- Do not remove a credit comparison.
- Do not treat an input-ceiling comparison that does not consume measured credit as this defect.
- Do not add this caller check to a false flag.
- Do not edit EtherFi, Slipstream, or `contracts/protocols/dexes/uniswap/v4`.
- Do not change quote math, refund math, or settlement.
- Do not add a `catch`.
- Do not deploy or upgrade live instances.

## Dissent

- MiniMax's first pass limited the repair to the five FullSpread branches and called the other measurements informational. Its cross-review withdrew that limit. This draft uses the 21-site table.
- Kimi's first pass left the refund-only sites as an open reading. Its cross-review closed them into the table. The lack of a shown divergent revert does not remove the order requirement. Severity stays Low.
- Grok's first pass included EtherFi. The application non-goal excludes those two edits. The source order is recorded, not repaired.

## Verification

Implement only after a separate request. Tests use the production proxy. A test-contract caller is not the code-less assertion. Report the commands actually run. A present assertion is not a pass until that run is reported.
