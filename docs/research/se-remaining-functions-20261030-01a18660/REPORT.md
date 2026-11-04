# Remaining full-spread functions

Revision **se-remaining-functions-20261030-01a18660-final**. Coordinator revision after one advisory pass on draft `se-remaining-functions-20261030-01a18660-r1`. This is not member-approved text and not an implementation. The owner has since locked the drop of `previewWithdrawalMode` and `wrappedNative()` as FS-OWN-10. The three splits below were not locked.

## Question

For each remaining open function, should this family keep it, drop it, or map it onto an accepted standard function?

## Participation

| Member | Advisory |
| --- | --- |
| Astra | SUPPORT WITH CORRECTIONS |
| Grok | REQUESTED CHANGES, on attribution, not on the five decisions |
| MiniMax | REQUESTED CHANGES, on the record, not on the five decisions |
| Kimi | SUPPORT WITH FIDELITY CORRECTIONS |

The two splits below were not voted closed.

## Answer

| Function | Recommendation |
| --- | --- |
| `previewWithdrawalMode` | Do not keep the selector. Not settled as map or drop. |
| `wrappedNative()` | Do not keep the family getter. Do not move it to the Position Repo. Not settled as map or drop. |
| `previewZapCredit` | Not settled. Three keep it. One maps it away. |
| `maxZapBps()` | Not settled. Two keep the getter. Two drop the getter and keep the cap. |
| `maxZapTickMove()` | Same split as `maxZapBps()`. |

`previewExchangeIn`'s `amountRefunded` does not replace a per-currency credit split. That return is unkept input of the token the caller provided. It is not `credit0`, `credit1`, `uncredited0`, or `uncredited1`. All four originals said this.

### `previewWithdrawalMode`

Do not install it. A caller does not use it to choose a route. For a paired exit, the quote is `previewExchangeBundleOut`. For a single-token exit, the accepted quote is `previewExchangeIn`. Neither preview returns the compound-or-collect mode or its reason.

Astra and MiniMax describe that as mapping the payout quotes. Kimi and Grok say it is a drop, not a map, because no accepted preview answers the question this selector asks. That label split stays open.

Dropping the selector does not, by itself, lock an internal compound-or-collect branch. Astra, MiniMax, and Kimi would keep that internal choice. Grok did not. Naming the branch would publish a fallback this family has not locked.

If the selector is later dropped, the inherited statements that still name it have to be re-pointed. MiniMax named S1-EXIT-01, S1-A61, and S1-A63. This report does not edit those rows.

### `wrappedNative()`

Do not keep it as a family getter. All four said the public selector does not move to the Position Repo. The accepted routes already use the ERC-20 face on `vaultTokens()`, with the wrapped face at a native leg's index.

Astra and Kimi call that a map onto `vaultTokens()`. MiniMax and Grok call it a drop, because that face is already exposed and this is not a new function. MiniMax's reason for refusing the Position Repo is that a wrapper address is neither position state nor pool state. If a later read needs the protocol's wrapper, that home is the Protocol Aware pair, not the Position Repo. Where the vault stores the binding internally is not decided.

### `previewZapCredit`

Not settled.

Astra, Kimi, and MiniMax would keep it as a read-only explanation of the same entry plan. Quoted shares must agree with `previewExchangeIn(tokenIn, amountIn, share)`. It is not a second money route. MiniMax's keep flips if the owner later rules that a booked no-share residual is unconsumed input and must be refunded. Even then, `credit0` and `credit1` still have no home on an accepted surface.

Grok would map it onto `previewExchangeIn` and drop the selector. The missing split is stage-one residual accounting this family has not locked, and a second quote can disagree with the standard preview.

### `maxZapBps` and `maxZapTickMove`

Not settled as getters. Settled only in this narrower sense: no original removes the caps themselves. Dropping a getter is not dropping the cap.

Astra and Kimi would keep both getters, so an integrator can read the configured caps without inferring them from a rejected quote.

MiniMax and Grok would drop both getters. The caps stay as internal configuration and enforcement. There is no accepted standard getter to map them onto. Grok does not adopt the stage-one formulas, and does not decide whether `compound()` uses the same size cap.

## Limits

No implementation was run. This report does not edit the full-spread PRD or the function-review file. It does not authorize code changes.
