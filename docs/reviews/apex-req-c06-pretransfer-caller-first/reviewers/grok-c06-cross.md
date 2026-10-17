# Grok — REQ-C06 cross-review

Continuation of the same independent pass. Peer notes are untrusted. Astra is the labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` and does not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. MiniMax is the labeled replacement `ses_ebdf718feffemWQNf7wuTpapqX`. Kimi is the labeled replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. An absent earlier session is not a finding.

Controlling text remains `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-C06, plus the whole-draft non-goal at line 178. My first-pass findings stay in `reviewers/grok-c06.md`. This file does not replace them.

## Agreements

- Hookless mint `:94-101`, hookless direct-out `:165-169`, Pons mint `:94-101`, Pons direct-out `:165-169`, and V3 `executeZapInMintExactOut` `:102-110` measure credit, and a plan consumes that credit, before `LocalCreditLib.requirePretransferCaller`. All four originals name those five branches. They are repairs.
- V3 quoted exact-output `:81-84` already checks the caller first. Leave it alone. The October 11 draft is stale on that function.
- V3 withdrawal `:30-32`, V3 dual-exit `:39-40`, hookless and Pons withdrawal delegates `:36-37`, hookless and Pons dual-exit `:45-46`, and Aerodrome v1 `:290-291`, `:396-397`, and `:488-489` already check the caller before `_pretransferCredit`. Leave them alone. Kimi's leave-alone list omitted the two dual-exit sites; that omission is not a claim that they are defects. They stay on the closed leave-alone list.
- Input ceilings that do not consume measured credit are not this defect and stay where they are.
- Slipstream `:85` is the same measurement-before-check pattern. Record it. Do not edit it. REQ-C06 says do not restore Slipstream.
- `contracts/protocols/dexes/uniswap/v4` is out of scope.
- Severity is Low. This is diagnostic order, not an authorization bypass, and not REQ-C02.
- On the five named branches, keep the existing credit comparison. A false flag does not receive the new caller check. Astra, Kimi, and my first pass put that check inside the existing true-flag guard.

## Correction to my first pass

`grok-c06.md` findings 6 and 7 included EtherFi `:61` and `:84` as edits. Application PRD line 178 says "No EtherFi change." That whole-draft non-goal controls. EtherFi has the same source order. It is recorded and not edited. Astra is right on that limit. The source observation in findings 6 and 7 stands. The edit instruction does not.

## Objections

- MiniMax's closed repair list is the five named branches only. That is rejected. Lido `:64` and Rocket Pool `:60` pass measured credit into `_reserveBeforePretransfer` and quote from that reserve before `_securePull` checks the caller. MiniMax's own table says that helper consumes the credit, then section 4 says no other site runs a consuming plan before the caller check. Those sentences conflict. The consuming-plan sites are not optional.
- MiniMax treats the input-ceiling non-goal as permission to leave Uniswap V2, Camelot, and the staking asset-to-asset branches unedited. That non-goal excludes only a ceiling that does not consume measured credit. It does not exclude a `_pretransferCredit` call that runs before `requirePretransferCaller`.
- MiniMax's V3 fix inserts an unconditional `requirePretransferCaller` before the credit read and says the false flag does not reach it. Those claims conflict. An ungated call before the ternary runs when `pretransferred` is false and would reject a code-less false-flag caller. Do not adopt that sentence. The existing line 109 check is moved into a `pretransferred` guard before the credit read. The credit comparison at line 110 stays. The false flag does not gain the check.
- Kimi leaves class B, the measurement-before-check sites whose quote does not consume that credit, as a coordinator reading. That is an open scope choice. Acceptance criterion 1 already closed it: on each prepaid branch that measures credit before authentication, `requirePretransferCaller` runs before `_pretransferCredit`. A later helper that checks the caller before `TransferDeltaInsufficient` does not satisfy that sentence.

## Closed site list

Repair these twenty-one calls, and no others. Each new check is guarded by that function's existing true flag, `pretransferred` or `prepaid`. Insert it immediately before that call. Keep the credit read, the existing credit comparison, and every input ceiling.

- Hookless `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:94` and `:165`
- Pons `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:94` and `:165`
- V3 `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:102`, by moving the existing line 109 check to that position and deleting it from line 109
- Lido `LidoWstETHStandardExchangeOutTarget.sol:64` and `:85`
- Rocket Pool `RocketPoolRETHStandardExchangeOutTarget.sol:60` and `:82`
- Uniswap V2 `UniswapV2StandardExchangeOutTarget.sol:462`, `:547`, `:623`, `:693`, `:794`, `:905`, and `:972`
- Camelot `CamelotV2StandardExchangeOutTarget.sol:411`, `:513`, `:596`, `:663`, and `:766`

Record and do not edit: EtherFi `:61` and `:84`; Slipstream `:85`; `contracts/protocols/dexes/uniswap/v4`.

Leave alone: the ten caller-first `_pretransferCredit` calls listed above, and the helpers that already check the caller before their own credit comparison.

## Sentence the PRD must use

Edit only these prepaid `_pretransferCredit` calls, by placing `LocalCreditLib.requirePretransferCaller(msg.sender)` immediately before each call and only inside that function's existing true-flag guard, keeping every existing credit comparison and every input ceiling, and by moving the V3 line 109 check to before line 102 rather than adding an ungated check: hookless OutExecuteTarget.sol:94 and :165, Pons OutExecuteTarget.sol:94 and :165, V3 OutExecutionDelegate.sol:102, Lido OutTarget.sol:64 and :85, Rocket Pool OutTarget.sol:60 and :82, UniswapV2 OutTarget.sol:462, :547, :623, :693, :794, :905, and :972, and Camelot OutTarget.sol:411, :513, :596, :663, and :766; do not edit EtherFi, Slipstream, `contracts/protocols/dexes/uniswap/v4`, or any call that already runs `requirePretransferCaller` before `_pretransferCredit`.

## Unresolved

Whether a code-less caller on a consuming-plan branch reaches a plan revert before `EOAPretransferNotAllowed` was not executed. The order fact does not depend on that inference. Forge was not run. No owner sentence lifts the EtherFi non-goal; until one does, EtherFi is not an implementer choice.

I did not run Forge.
