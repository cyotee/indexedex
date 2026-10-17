# Grok — REQ-C06 plan cross-review

Continuation of the same pass. Peer notes are untrusted. Astra is the labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` and does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. MiniMax is `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi is `ses_ec3d04e91ffeJa0is24e2jZv06`.

My plan draft stays in `reviewers/grok-c06-plan.md`. This file does not replace it.

## Agreements

- The 21 measurement lines, the true-flag insert, `prepaid` only at hookless and Pons line 165, the V3 mint move, imports only in Uniswap V2, Camelot, Rocket Pool, and Lido, and the EtherFi, Slipstream, and legacy V4 exclusions are the same in all four drafts.
- No bare `vm.expectRevert()`. A code-less caller is not a test contract. One family's pass does not close another.
- Hookless and Pons direct-out already live in each family's `ApexRecurrenceErrorOrder.t.sol`. Those cases stay. They do not cover mint.

## Correction to my plan

`grok-c06-plan.md` said the V3 mint assertion had no home and named a new `ReqC06MintCallerOrder.t.sol`. That is withdrawn. `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol` already calls `exchangeOut` with the vault share as `tokenOut` for the code-less and contract short-credit cases. The new V3 file is not created.

The other new `ReqC06*` files in my draft are also withdrawn. Each missing case is added to the one existing file named below. Creating a sibling and also editing another suite would leave a file choice.

## Objections

- MiniMax's hookless home, `PretransferCallerLifecycle.t.sol`, calls `exchangeIn`. It does not reach lines 94 or 165. Its code-less short-credit case expects `TransferDeltaInsufficient`. That is not the repaired out-path assertion, and "no new code" leaves both repaired lines untested.
- MiniMax's V2 and Camelot commands use `test/foundry/spec/protocols/dexes/`. Those paths are not the tree. The tree is `test/foundry/spec/protocol/dexes/`. One swap case in `SecRemediation` does not close the other listed lines.
- MiniMax's Rocket and Lido new files use `test/foundry/spec/protocols/staking/`. That directory is not the tree. The samples also omit the contract-caller short-credit case, and the Lido asset route uses stETH. The closed asset route is WETH to wstETH.
- MiniMax says the Pons and V3 files need no new code. Pons direct-out does not cover mint. The V3 false-flag case at line 134 is quoted exact-out, which is left alone. It does not cover mint false-flag.
- Kimi's file list is closer, but section 3 says one representative branch per helper shape is acceptable. That is the choice this plan must not leave. Every listed line gets its own three assertions.
- Astra's V3 home, `UniswapV3FullSpreadExactOutputFill.t.sol`, is a real file and is rejected as a second home. The mint cases already live in the release `ApexRecurrenceErrorOrder.t.sol`. Astra's Camelot home, `CamelotV2ZapOutMaxAmountIn.t.sol`, only has zap-out cases. It is rejected so the five lines are not split across two files.
- My draft required every false-flag call to return. That is wrong for hookless and Pons idle mint. `_amountInForZapMint` reverts `InvalidRoute` when the pool manager can unlock. The code-less idle true-flag mint must revert `EOAPretransferNotAllowed`. The code-less idle false-flag mint must revert that existing `InvalidRoute` and must not revert `EOAPretransferNotAllowed`. The funded false-flag mint uses the existing real `_nested` helper and must succeed. Direct-out false-flag stays a success. No other expectation is allowed.

## Sentence the plan must use

Add the missing caller-order cases only in these seven files, with a code-less short-credit `EOAPretransferNotAllowed` assertion, a contract short-credit `TransferDeltaInsufficient` assertion, and a false-flag assertion on every listed line, not on one representative route: hookless `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol`, Pons `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol`, V3 `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol`, Uniswap V2 `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_InOutInvariant.t.sol` for all seven existing `route*` exchangeOut cases, Camelot `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_SecRemediation.t.sol` for lines 411, 513, 596, 663, and 766, Rocket Pool `test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol` for lines 60 and 82, and Lido `test/foundry/spec/protocol/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol` for lines 64 and 85.

I did not run Forge.
