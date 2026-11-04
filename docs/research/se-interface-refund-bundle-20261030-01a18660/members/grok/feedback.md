# Member feedback

## Identity

- Run ID: se-interface-refund-bundle-20261030-01a18660
- Member label: grok
- Phase: advisory review
- Owned path: docs/research/se-interface-refund-bundle-20261030-01a18660/members/grok/feedback.md
- Requested role: council-member
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: continued. This advisory is in the same conversation that wrote the initial response. Continuity was not lost.
- Initial response path: docs/research/se-interface-refund-bundle-20261030-01a18660/members/grok/response.md
- Initial response preserved: yes. This pass does not overwrite it.

## Draft under review

- Draft ID: se-interface-refund-bundle-20261030-01a18660-r1
- Path: docs/research/se-interface-refund-bundle-20261030-01a18660/coordinator/draft.md
- Fingerprint supplied by the coordinator: 4e37ac6e38c6fd71dde40fd5f1402408d5131df556a98ad2e0f535958269c2cf
- Fingerprint independently computed: not computed. The assignment said that SHA-256 is coordinator-supplied provenance, not a hash to recompute. It is not repeated here as independent proof.
- Draft bytes opened: yes. The file at the assigned path was opened in full. Its Draft identity lines state this Draft ID and this path. The file itself says its fingerprint was not computed in that file.

## Disposition

- Disposition: support-with-reservations
- Assignment wording: support with corrections
- This file replaces a missing initial response: no

I support the draft's answer and the Solidity signatures in `## Proposed text`. Redefine by addition. Do not replace or extend `exchangeIn` or `exchangeOut`. Keep the owner-named bundle interfaces. Read bundle-out as exact-in: output addresses in, floors in, actual amounts out. Put the refund return only on the new functions. Leave `IStandardExchange`, the multi interfaces, and `IStandardExchangeMultiAssetLiquidity` unmerged and unchanged. Use the smaller error set. Use `address` on the bundle token arguments and `IERC20` on the single-asset sibling.

I do not support the proposed text as complete. The corrections below are sentences to add or rewrite. They are not a request to replace the interface shape. Do not resolve them by deleting `minAmountsOut`, by moving the refund onto the current selectors, or by renaming `exchangeBundleOut` into an exact-out function.

This advisory does not replace the original response. It does not authorize implementation. I do not demand a further round.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G1 | `## Proposed text`, Coordinator choices, first bullet | The bullet says amounts of the expected tokens are returns, not inputs. The code then takes `minAmountsOut` as an input. A later edit that makes the sentence true by deleting `minAmountsOut` would change the signature I support. | Keep `minAmountsOut`. Rewrite the bullet: `tokensOut` is addresses in the caller's order; `minAmountsOut` is the floors, aligned to that array and input only on the mutating function; `amountsOut` is the actual receipts and is a return. Preview does not take the floors. This remains exact-in. Exact output amounts are not inputs. |
| G2 | `## Proposed text`, Coordinator choices preview bullet, and the Refund identity paragraph | The preview half of the brief is only half answered. The draft says the preview returns a quote and does not transfer. It does not say whether that quote binds execution. | Add: the quote assumes the declaration is available. It is not a balance read and not a prediction of surplus above the declaration. Execution may refund a different amount. `minAmountOut` and `minAmountsOut` bind. The execution return is the actual refund. Do not require bit-exact preview equality. |
| G3 | `## Proposed text`, Refund identity paragraph, and "The same-token refund goes to `msg.sender`" | "Goes to `msg.sender`" can mean a transfer or an amount never pulled. Kept plus refunded equals declared does not by itself require a refund transfer, and it does not forbid booking the same wei. | Add: the pull path pulls the declared amount, then transfers the unkept amount of that same token to `msg.sender`. The pretransfer path transfers that unkept amount back to `msg.sender`. A zero refund transfers nothing. Pull-only-the-consumed-amount is not the rule. Refunded wei are not credited as a deposit and are not the full-spread `J_i` booking. A fee, if any, is part of the kept amount. There is no third bucket inside the declaration. |
| G4 | `## Proposed text`, Coordinator choices, `pretransferred` bullet | The flag is named. The current pretransfer law is not carried onto the new functions. | Add that `pretransferred` has the same meaning as on current `exchangeIn`: integrating-contract flag, atomic transfer and consume, callers with no bytecode revert `EOAPretransferNotAllowed()`, unrecorded balance may be consumed by the next contract caller, booked backing is not pretransfer credit, the declaration is processed only when present unbooked input covers it, a short declaration reverts, surplus above the declaration is not refunded, and booked inventory does not fill a shortfall. Do not redeclare `EOAPretransferNotAllowed`. Do not add a shortfall error. |
| G5 | `## Proposed text`, Solidity block, and the sentence "`tokenIn == tokenOut` is not a route" | The errors are declared, but the proposed text does not say which call reverts which error. The same-token sentence does not name `InvalidRoute` and does not cover the bundle cases. | Keep the error signatures. State the triggers. `InvalidRoute` for `tokenIn == tokenOut`, for a nonzero bundle-in slot whose `vaultTokens()` entry equals `tokenOut`, and for `tokenIn` appearing in `tokensOut`. `TokenNotExchangeable` for `address(0)` and for any other token that vault will not exchange. A zero bundle-in slot does not require its token to be exchangeable. `AmountsLengthMismatch` when `amountsIn.length` is not `vaultTokens().length`. `TokenAmountsLengthMismatch` when `minAmountsOut.length` is not `tokensOut.length`. An omitted floors array is not "no floors." A zero floor is allowed. `DuplicateOutput` for a repeated `tokensOut` entry. `EmptyExchange` for `amountIn == 0`, empty `tokensOut`, all-zero `amountsIn`, or an empty amounts array paired with empty `vaultTokens()`. `MinAmountNotMetAt.index` is the caller's `tokensOut` index, not a `vaultTokens()` index. `RouteNotSupported` or the function's `NotAvailable` error when the set cannot be paid. Bundle-out pays only `tokensOut`. It does not pay a surprise token. `tokensOut` is not fixed at two. |
| G6 | `## Proposed text`, opening route paragraph, and the current-function table | The share route is described, but not the case where the share is absent from `vaultTokens()`. The table says current functions are not replaced. It does not say they are not extended, and it does not label the new functions as beside. | Add: the share may be `tokenIn` or `tokenOut` even when it is absent from `vaultTokens()`. Add rows for the new functions: they sit beside the named current functions and do not extend them. A vault that implements both must not partial-fill the old function. `exchangeInManyToOne` stays full-keep-or-revert. A vault that must fully consume does not implement `IStandardExchangeInWithRefund`. `usedAmounts` on the liquidity extension is not a refund. |
| G7 | `## Proposed text`, Coordinator choices, ERC-20 bullet | "A native underlying uses its wrapped face" can be read as accept `address(0)` and wrap it inside the function. | Rewrite: the caller passes the wrapped ERC-20 face. These functions do not accept `address(0)`, do not wrap it, and are not payable. `address(0)` reverts `TokenNotExchangeable`. Raw ETH and `msg.value` stay on product functions outside this redefinition. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

I did not open peer files. The following is taken from this draft's `## Preserved disagreements` table, not from those files. I do not withdraw my original disagreement with the positions that table attributes to other members, and the draft correctly did not adopt them:

- Kimi's in-place replacement of `exchangeIn` and `exchangeOut` returns. I still reject it. Old callers can ignore extra returndata and treat a partial keep as a full consume. Current hooks call the old functions.
- MiniMax's claim that a return change is a selector change. I still reject that claim. The ABI break is real. That is why the current functions stay unchanged.
- Astra's `IStandardExchangeOutWithRefund` and MiniMax's `exchangeOutWithRefund`. I still reject an exact-out named-refund sibling. The used amount is already `exchangeOut`'s return. Slack stays the current side effect.
- MiniMax and Kimi's exact-out reading of the owner-named `exchangeBundleOut`. I still reject giving that name to an exact-out function. A later exact-out bundle needs a different suffix. This feedback does not define one.
- MiniMax's `IStandardExchangeFull` and Kimi's extension of `IStandardExchange`. I still reject a new aggregate. A product implements the leaves it supports.
- Astra's addition of `EOAPretransferNotAllowed` to the new error interface. I still reject that addition. Name it as the current comments do. Do not move it.

The draft also did not copy my file-path recommendation or the `cast sig` hex for the new functions. I do not press either. Do not fill that gap with the stale `@custom:selector` comments on the current files. The draft already says it does not copy those values. I support that.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- This file does not replace `members/grok/response.md` and does not authorize implementation, tests, installs, Git, or edits outside this owned path.
- I do not demand a further round.
- Inherited parent permissions are not evidence of confinement.
- The supplied fingerprint was not recomputed. I did not open `RUN.md`.
- Peer response files and peer feedback files were not read. Attributions in the draft were not independently checked.
- No implementation, hook caller, or gas measurement was run in this pass. I did not claim that a same-token remainder is always feasible inside the gas limit. I support the draft's evidence gap on that point.
- Selector comments were not rechecked in this pass. The original response recorded the mismatch. This feedback does not edit those files.
