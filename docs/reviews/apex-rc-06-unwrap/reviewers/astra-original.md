# Astra — RC-06 orbital unwrap return review

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes were read. The controlling RC-06 text in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:146–157` was freshly read successfully; no guard denial occurred.

## Verdict

**Close RC-06.** The current orbital `_unwrapExactTokenOut` does **not return a share count**. There is no return variable that reports the approval cap, and every identified orbital caller invokes it as a statement without consuming a returned value. This satisfies the requirement's explicitly permitted removal outcome.

The September description is refuted against current source. It is not necessary to choose between reporting actual spend and deleting a return: the latter outcome is already present. No production repair is proposed.

## Current unwrap function

File: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711–727`.

- **711:** signature is `function _unwrapExactTokenOut(address token, uint256 amountOut) internal`, with no `returns` clause.
- **712,714:** zero-output and identity-leg cases use bare `return;`, not returned share amounts.
- **715–719:** reads spendable SE shares, obtains the required input quote and rejects zero or above-cap requirements. `maxIn` is the approved quote bound, not a reported output.
- **720:** grants approval limited to `maxIn`.
- **722–724:** performs the existing exact-output SE call. It does not bind the SE's returned spend to a new count, nor assign `seIn = maxIn`.
- **725:** resets approval to zero on successful return.
- **726:** compares the received token delta with the requested output and reverts `InsufficientTokenOut()` for short delivery. The revert is not caught in this helper, so transaction rollback applies to this operation's changes.

Discarding the SE return is not itself RC-06 now: this helper makes no claim to return shares consumed. `maxIn` remaining as an approval/input bound is distinct from falsely reporting it as spend. The operation remains exact-output, and no unused approval cap is transferred to a caller.

## Every identified orbital caller

A search across `contracts/**/*.sol` located similarly named functions in several hook families; a second scoped search isolated the orbital definition and exactly these three call sites. All orbital caller bodies were read:

| Caller | File and line | Use of unwrap result |
|---|---|---|
| `_swapExactOutExecute` | Orbital Common **750–764**, call at **758** | Calls unwrap as a statement. Its own `amountIn` return is the separately calculated swap input at 756, not an SE-share count returned by unwrap. |
| `_swapExchangeOut` | `UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:120–157`, call at **144** | Calls unwrap as a statement; input is quoted/bounded and pulled separately. It transfers the specified output and syncs reserves afterward. |
| `_payOwnerSwap` | Same SeTarget **209–218**, call at **213** | Calls unwrap as a statement, then finishes owner settlement. The enclosing owner exact-output entry at **184–200** returns its own quoted input; it does not receive a share count from unwrap. |

The scoped search for `_unwrapExactTokenOut` and `seIn = maxIn` returned only the definition and those three calls, with no old cap-assignment match. No caller expects a removed return value. Other families' similarly named helpers are not evidence of a second orbital return and are outside this narrow finding.

## Acceptance and limits

The controlling text permits either a truthful share-spend return or removal of the unused return with callers updated. Current source satisfies the latter and retains the approved-cap/reset sequence and short-delivery rejection. Closure does not rely on callers merely ignoring a still-misleading return; the return is absent.

**Confirmed facts:** void signature, no cap-as-spend assignment, all three orbital call sites use the void form, exact-output dependency call retained, approval reset and short-delivery check present.

**Inference:** the specific historical misreporting mechanism no longer exists in this implementation.

**Unverified:** historical source at filing, when removal occurred, compilation/runtime results and deployed-instance behavior. No Forge run or executed rollback test is claimed. A void function is sufficient for the assignment's stated closure condition; no new accounting return or test is invented to keep this item open.

## Files examined without a scoped defect

- Orbital Common **691–768**: distinguishes the adjacent exact-input helpers, which legitimately return token output, from the void exact-output helper under review; includes the Common caller.
- Orbital SeTarget **110–225**: both remaining unwrap callers and their entry/settlement context.
- Controlling RC-06 section and contracts-wide/family-scoped reference searches.

All supplied input paths were present. The assigned output was absent before writing. Only this assigned Markdown report was created. No code, tests, PRD, original review, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

Close RC-06
I did not run Forge.
