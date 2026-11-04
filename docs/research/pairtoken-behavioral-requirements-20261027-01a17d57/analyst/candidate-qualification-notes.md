# Candidate qualification notes

These are coordinator checks for synthesis, not edits to independent originals or a draft requirements document.

## MiniMax initial

The full returned original is preserved, including its tool-gap/provenance preamble. Its useful topic/branch inventory is not blanket validation of every statement.

Require these corrections/qualifications before adopting its prose:

- Usable full-range ticks lie inside the nominal bounds: signed division toward zero yields lower >= -887272 and upper <= 887272 for positive spacing, not the reversed inequalities in FR-DEF-05.
- Pool-key currency ordering and native-as-currency0 are protocol-domain expectations; the initializer itself does not enforce sorted keys. Do not state it rejects invalid combinations.
- Ordinary transfer recipient credits and mint/burn internal fields include unchecked arithmetic. Do not adopt FR-SYS-06's blanket assertion that all arithmetic is checked.
- Paired actions may swap during the preceding compound. Do not retain FR-SYS-05's initial categorical no-swap wording.
- No reentrancy modifier on a function does not guarantee arbitrary nested calls succeed. Caller balance/allowance/recipient and other checks still apply.
- Absence of a zap refund does not prove all funds were consumed. Pulled or unswapped funds can remain idle, especially with partial fills.
- Redemption payouts use Currency.transfer, including wrapped errors from its dependency. Do not adopt FR-RDM-07's assertion that all outbound failures become TransferFailed.
- Notification catch is not a guarantee that routing never blocks a user action. Factory getter failures, checked fee multiplication and malformed approval decoding can propagate.
- Redemption routes collect first and may therefore pay value from previously pending fees. Do not adopt FR-FEE-08's unconditional assertion that a redeemer receives none of them.
- A structurally invalid enum or malformed callback data can fail ABI decoding. Only a decoded None tag falls through to NotPoolManager; it is not the error for every invalid numeric tag.
- Collect/add/remove/deploy unlocks are conditional; do not require a fixed minimum count for every deposit or redemption.
- A callback deploy with zero swap and zero fitting liquidity can return no additional pool work. No swap alone does not imply no add attempt.
- No-holder positive redemption is a checked burn-subtraction failure after prior steps, not automatically MinShares. Zero input/supply has MinShares, subject to earlier recipient/token/compound failure precedence.
- Compound event eligibility is collected fee0>0 or fee1>0 or liquidityAdded>0. Small idle does not prevent an event when fees were collected.
- Same-width int128-to-uint128 conversion reinterprets signed bits. It is not a proved reachable negative-delta exploit or a magnitude beyond an int128 maximum.
- Death-address shares are retained in ordinary supply; there is no privileged recovery. Do not state an unimplemented special rejection of that address or prove that it can never act.
- Document origin is source-informed, but this task makes no legal ruling that a functional requirements reader is or is not an unexposed implementer.
- Helper formulas and failures need exact fixed-point/FullMath semantics, not generic claims of division-by-zero panics across all helpers.

## Grok initial

Complete repaired final artifact preserved after its original commentary was truncated by the supported transcript view. Correct these before adoption:

- Internal burn updates balance with checked subtraction but total supply with unchecked subtraction. Do not adopt PT-064's statement that both supply updates are checked.
- The refund reservation is cleared before the refund call, not after it; preserve exact reentrant visibility.
- Chosen-leg redemption calls Currency.transfer even when output is zero, unlike paired redemption's nonzero-leg checks. PT-110's conditional transfer wording is incorrect.
- Invalid enum/encoding can fail decoding before dispatch; distinguish decoded None from out-of-range tags rather than adopting PT-122's universal NotPoolManager rule.
- Missing PT-076/PT-142 cross-reference identifiers are not evidence gaps in source. Define the deploy result and helper math explicitly in the final, with self-contained valid references.
- Approval false/failure paths and malformed boolean return decoding are different. Do not adopt unconditional nonreverting approval/reset claims.
- Geometric pricing has no independent oracle but basket denominators do contain live-price principal and idle/fee property; avoid categorical statements that no fee or price component affects quotes.
- Stated fixed-point helper meanings need actual formulas and dependency boundaries, not only references to an admitted map a planner cannot inspect.

## Kimi initial

Retain its complete API/getter inventory, exact plain-token mint/burn arithmetic, callback operation/result encoding, compound trigger/event distinction and separate helper-error paths. Correct:

- PT-MATH-001's general no-silent-truncation language and PT-RED-002's checked liqOut conversion are not faithful: ordinary explicit uint256-to-uint128 narrowing keeps low bits. The amount-to-liquidity helper separately checks its cast and reverts SafeCastOverflow. These are different contracts.
- Swap amount signed conversion must preserve explicit uint256-to-int256 conversion and checked negation, not assume a local upper-bound guard.
- Make chosen-leg zero output transfer unconditional and preserve the distinction from paired nonzero-only transfer calls.
- Clarify invalid enum/malformed ABI behavior and negative signed-delta conversion rather than label all narrowing as overflow rejection.

## Payout error wrapper check

Coordinator read CustomRevert.bubbleUpAndRevertWith in full. Failed Currency.transfer wraps target address, called selector, raw return/revert data and a four-byte context in WrappedError(address,bytes4,bytes,bytes). Native uses zero called selector and NativeTransferFailed context; ERC20 uses transfer selector and ERC20TransferFailed context. These differ from local TransferFailed and malformed local ABI decode failures.
