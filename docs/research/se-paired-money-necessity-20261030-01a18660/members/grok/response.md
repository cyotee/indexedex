# Member response

## Identity

- Run ID: se-paired-money-necessity-20261030-01a18660
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-paired-money-necessity-20261030-01a18660/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does the accepted Standard Exchange redefinition fill the same need as the paired-money functions, and which of those functions should this family keep, drop, or map onto a named standard function?
- Required targets: the paired-money section of `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`; the owner lock and accepted interfaces in `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`; the declarations of `depositPair`, `previewDepositPair`, `redeemPair`, `previewRedeemPair`, `donate`, and `compound` in `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`
- Optional context: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, used for what those functions do. Not interface law for the new standard.
- Admitted read scope: those files only. No peer response was read. The full-spread PRD was not read.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Question and decision vocabulary | `docs/research/se-paired-money-necessity-20261030-01a18660/brief.md` | coordinator-supplied | The family must get keep, drop, or map for each of the six functions. A map must name the standard function and the argument that makes the route a deposit or a withdrawal, and must state behavior that function does not cover. `donate` and `compound` are not covered by a bundle route unless the route that does that work is named. |
| Paired-money group is still open | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, "Paired money" | source observation | The file says unmarked functions are still open. The Standard Exchange return lock "does not decide the paired functions below." The section intro calls them "the two-token operations the standard one-token interface cannot express." |
| Six proposed behaviors | Same file, paired-money bullets | source observation | `depositPair` takes both pool currencies up to two maxima and mints shares; on a native pool the native side is `msg.value`. `previewDepositPair` returns the shares and how much of each token would be taken. `redeemPair` burns the caller's shares and pays both pool currencies, including raw ETH on a native pool. `previewRedeemPair` returns those two payouts. `donate` adds tokens to the book and mints no shares. `compound` collects fees into the position and does not change share supply. |
| ERC-5115 is locked out | Same file, "ERC-5115" | source observation | "Locked: do not install ERC-5115." That drops `syMoneyFacet`, `syQueryFacet`, and `rateAsset()`. |
| Owner lock | `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, "Owner lock" | source observation | The owner accepted the recommended definition with one change: no `WithRefund` names, and the refund return sits on existing `previewExchangeIn` and `exchangeIn`. Parameter lists and selectors stay. The bundle interfaces are accepted as written. `exchangeOut` does not gain a refund return. The preserved council text is overridden where it conflicts. The report says it does not change the full-spread PRD and is not an implementation. |
| Route identity | Same report, "Answer" | source observation | Swaps, deposits, and withdrawals use one family. Underlying, or a bundle of underlyings, for the share is a deposit. Share for an underlying, or for a named set of underlyings, is a withdrawal. The share may be `tokenIn` or `tokenOut` even when absent from `vaultTokens()`. A vault may reject a route. |
| Refund rule and native exclusion | Same report, "Refund rule" | source observation | For each declared input, declared amount equals consumed plus refunded. The pull path pulls the declared amount, then returns the unkept amount. "Pulling only the consumed amount is not the rule." These functions are not payable. The caller passes the wrapped ERC-20 face. `address(0)` reverts `TokenNotExchangeable`. "Raw ETH stays on product functions outside this redefinition." A preview does not read a balance, assumes the declaration is available, and execution may differ. Bit-exact preview equality is not required. |
| Bundle-in shape | Same report, `IStandardExchangeBundleInForSingleOut` | source observation | `previewExchangeBundleInForSingleOut(amountsIn, tokenOut)` and `exchangeBundleInForSingleOut(amountsIn, tokenOut, minAmountOut, recipient, pretransferred, deadline)` use `vaultTokens()` order. Length must equal `vaultTokens().length`. A zero slot is not provided. A nonzero slot whose token equals `tokenOut` reverts `InvalidRoute`. Returns output plus per-token refunds. |
| Bundle-out shape | Same report, `IStandardExchangeBundleOut` | source observation | `previewExchangeBundleOut(tokenIn, amountIn, tokensOut)` and `exchangeBundleOut(tokenIn, amountIn, tokensOut, minAmountsOut, recipient, pretransferred, deadline)` take one pay token and caller-named outputs. `minAmountsOut` are floors. This is exact-in. `tokensOut` is not fixed at two. A subset is allowed only when the route can settle it without an unrequested output. Returns receipts plus the unkept pay-token refund. |
| Surfaces explicitly not the map targets | Same report, "What stays unchanged" and "Dissent not adopted" | source observation | `exchangeInManyToOne` stays full-keep or revert and is not replaced. `exchangeOut` and `exchangeOutOneToMany` stay unchanged. `exchangeOutOneToMany` is the current exact-out many route. An exact-out bundle was not adopted and is not defined. `IStandardExchangeMultiAssetLiquidity` stays unmerged; its `usedAmounts` is not a refund. |
| All six are declared | `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol` | source observation | The interface declares all six, so the stage-one PRD was not required as a substitute. `depositPair` is payable and "Deposit[s] accepted portions of two maxima after incumbent maintenance." Native pools require `amount0Max` as `msg.value` and refund only unused ETH. `previewDepositPair` returns `(shares, used0, used1)`. `redeemPair` burns caller shares and pays both actual pool currencies. `previewRedeemPair` projects paired payouts "using the same conditional maintenance choice." `donate` is payable and "Pull[s] and book[s] only this call's positive contribution without minting." `compound` "Maintain[s] incumbent backing without changing supply or charging vault fees" and returns `(fees0, fees1)`. |
| Stage-one paired deposit | `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, S1-OP-01 | source observation | `depositPair` has an execution-equivalent preview. It pulls only accepted ERC-20 amounts; unused ERC-20 maxima remain with the caller. Native pools require `msg.value == amount0Max` and refund `amount0Max - used0`. It has no pretransfer flag. "The first deposit must use this operation; do not invent a one-token bootstrap." Incumbent compound and fee checkpoint happen before accepted-input selection. |
| Stage-one necessity claim | Same PRD, S1-OP-03 | source observation | Stage one calls the paired methods necessary because "the scalar SE and SY interfaces cannot express two-input genesis or two-output redemption." It says the then-existing many-to-one interface is exact input, not an accepted portion of two maxima, and the then-existing one-to-many interface is exact output, not proportional share-input redemption. It says not to keep a second implementation of the same accounting behind additional aliases. |
| Stage-one native decision | Same PRD, S1-P02 and S1-NATIVE-01 | source observation | S1-P02 says retain native ETH support, including actual ETH entry and payout, and that wrapped-native adaptation at the nonpayable Standard Exchange boundary must not replace or remove native operation support. S1-NATIVE-01 says canonical SE methods are nonpayable, reject raw `address(0)`, and use wrapped faces. Direct native single-token entry and exit use payable SY methods. Paired methods use actual pool currencies. |
| Donation and compound | Same PRD, S1-ACC-04, S1-OP-05, S1-P01, S1-SEC-02 | source observation | `donate` credits an observed same-call receipt to booked reserves, mints no shares, requires positive supply and amount, and may leave the donation idle. Native donation uses `token == address(0)` and `msg.value == amount`. It does not adopt unrelated unbooked balances. `compound` collects fees, may ratio-swap and reinvest, and does not mint or burn. Explicit `compound()` and the mandatory pre-operation compound share one engine. Deposits and standalone compound do not get the withdrawal-only fallback. An empty book is a successful no-op. Disable rejects issuance and explicit donation. Standalone compound remains permissionless while disabled. |
| Public query | none | source observation | not used |

No supplied runtime and no static analysis beyond reading these texts. Selectors in the interface comments and the refund report were not recomputed.

## Assumptions

- "This family" is the full-spread family whose open list is the function-review file. Stage-one decisions, including S1-P02, describe the current paired functions. They are not interface law for the accepted standard.
- A map means the family does not keep that selector. Callers use the named standard function. It does not mean both functions remain.
- `vaultTokens()` for this family is the two underlying faces, the share is absent from that list, and the order is stable. That is what stage one specifies, and the accepted report allows the share to be absent from `vaultTokens()`. The full-spread PRD was not admitted and was not read. If `vaultTokens()` is not that pair, the named functions are still the map targets, but a nonzero slot is a pool currency only when that entry is one.
- No bundle-route implementation was read. Nothing below claims the current code already performs these routes.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Paired-money section of `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` | required | examined | The section, the open-status note, the return lock, and the ERC-5115 lock were read. |
| Owner lock and accepted interfaces in `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` | required | examined | The full report was read, including the owner lock, preserved council text, both bundle interfaces, and the unchanged surfaces. |
| Six declarations in `IUniswapV4PairTokenStandardExchangeVault.sol` | required | examined | All six are declared. The interface file was read through the end of those declarations and the surrounding family comments. |
| `PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` | optional | partially examined | Read the owner decisions, donation accounting, paired deposit, paired redemption, compound, native boundary, family ABI, and disable rule. Later mentions of the six names were located. Not every acceptance-row sentence was used as a requirement. Not used as interface law. |
| Full-spread PRD, peer responses, facet bodies, `PairToken.sol` | not a required target | not examined | Outside the admitted read scope. |

## Conclusions

The accepted redefinition does not fill the whole paired-money group. It does fill the two-sided deposit need and the two-sided withdrawal need on wrapped faces. It does not book a no-share donation, it does not reinvest fees without an exchange, and it does not accept or pay raw ETH.

Agreement is not available. Peers were not read. These are recommendations. They do not lock the PRD and do not authorize implementation.

| Function | Recommendation | Named standard function | Argument that selects the route |
| --- | --- | --- | --- |
| `depositPair` | map | `exchangeBundleInForSingleOut` | `tokenOut` is the share, so the route is a deposit. `amountsIn` is in `vaultTokens()` order. |
| `previewDepositPair` | map | `previewExchangeBundleInForSingleOut` | `tokenOut` is the share, so the quote is a deposit quote. |
| `redeemPair` | map | `exchangeBundleOut` | `tokenIn` is the share, so the route is a withdrawal. `amountIn` is the share amount. |
| `previewRedeemPair` | map | `previewExchangeBundleOut` | `tokenIn` is the share, so the quote is a withdrawal quote. |
| `donate` | keep | none | No accepted function does this work. |
| `compound` | keep | none | No accepted function does this work. |

`minShares` corresponds to `minAmountOut` when the output is the share. `min0` and `min1` correspond to `minAmountsOut` aligned to the caller's `tokensOut`. `recipient` and `deadline` already exist on both bundle mutators. Those correspondences are not separate functions.

### `depositPair`: map

The review file's intro says the one-token interface cannot express two-token operations. That sentence is about the one-token interface. The owner lock accepts a bundle-in function whose deposit route is a bundle of underlyings for the share. Stage one's necessity claim in S1-OP-03 is about the scalar SE and SY surfaces and about the older many-to-one exact-input surface. It is not a claim about `exchangeBundleInForSingleOut`, and it is not interface law here.

Do not map this function to `exchangeIn`. That function takes one input token. Do not map it to `exchangeInManyToOne`. The accepted report leaves that surface full-keep or revert. Full-keep does not fill a deposit that may take less than the caller offered. Do not map it to `IStandardExchangeMultiAssetLiquidity`. The report says `usedAmounts` is not a refund, and that interface was not read.

Behavior `exchangeBundleInForSingleOut` does not cover:

- Raw ETH input. `depositPair` is payable. On a native pool, `amount0Max` is `msg.value`, and only unused ETH is refunded. The accepted function is not payable, rejects `address(0)`, and does not wrap it.
- Pull-only-accepted ERC-20. Stage one pulls the accepted amount and leaves the unused maximum with the caller. The accepted rule pulls the declared amount and refunds the unkept part. Pulling only the consumed amount is explicitly not the rule.
- A return of used amounts. The family function returns shares. Its preview returns used amounts. The standard mutator returns shares as `amountOut` plus per-token refunds. Used amount is declared minus refunded only if the caller still holds the declaration.
- The PairToken acceptance predicate, incumbent compound-before-snapshot, and empty-supply geometric-mean genesis. The standard identifies the route. It does not specify that accounting.
- A no-pretransfer paired deposit. The standard function has `pretransferred`. Stage-one `depositPair` has no such flag.

### `previewDepositPair`: map

The quote need remains. The separate function does not. `previewExchangeBundleInForSingleOut` with `tokenOut` equal to the share is the deposit quote.

Behavior it does not cover: it returns refunds, not used amounts; it does not read a balance; execution may differ; bit-exact equality is not required. Stage one requires an execution-equivalent preview. That stronger quote is not in the accepted standard.

### `redeemPair`: map

`exchangeBundleOut` with `tokenIn` equal to the share is a withdrawal of a declared share amount into caller-named outputs, with floors. That is the shape of `redeemPair`: share amount in, two payout floors, not exact output amounts as inputs.

Do not map it to `exchangeOut`. That function is one output, unchanged, and does not gain a refund return. Do not map it to `exchangeOutOneToMany`. The report calls that the current exact-out many route. `redeemPair` does not take output amounts as inputs. An exact-out bundle was not adopted, and this response does not define one.

Behavior `exchangeBundleOut` does not cover:

- Raw ETH payout. `redeemPair` pays both actual pool currencies, including raw ETH on a native pool. The accepted function pays the wrapped ERC-20 face and rejects `address(0)`.
- A fixed pool-order return of `(amount0, amount1)`. Receipts follow the caller's `tokensOut` order. There is also an unkept pay-token refund. `redeemPair` has no share refund. It burns the submitted shares or reverts.
- The word "burn." The standard calls share-for-underlyings a withdrawal. It does not say the share is burned rather than transferred.
- The no-pretransfer, caller-only burn. `redeemPair` has no third-party allowance-burn path. The bundle function has `pretransferred`.
- Conditional full-compound versus collect-only maintenance as a named result. The family preview comment says `previewRedeemPair` uses that choice. `exchangeBundleOut` has no mode argument. `previewWithdrawalMode` is outside these six and is not decided here.

### `previewRedeemPair`: map

Same route argument as the mutator: `tokenIn` is the share on `previewExchangeBundleOut`. The separate preview does not remain necessary if `redeemPair` is mapped. The quote gaps are the same raw-ETH, caller-order, and non-binding-preview gaps as the mutator, plus the accepted rule that a preview need not match execution.

### `donate`: keep

No accepted route books tokens and mints no shares. A deposit's output is shares. The refund rule says idle unconsumed input is not consumption, refunded value is not credited as a deposit, and surplus above a declaration is not consumed and not refunded. That is the opposite of a donation. Stage one also rejects a zero final share credit on entry, so a zero-share "deposit" is not the donation operation.

`donate` is one token, not a pair. It is payable. Native donation is `address(0)` plus `msg.value`. The standard rejects `address(0)`. Disable blocks explicit donation and issuance together, which treats donation as a capital contribution rather than as an exchange. Naming a bundle function here would be a false map.

### `compound`: keep

No accepted function collects position fees and puts them back into the position without changing share supply. Every accepted exchange has a pay token and an output. A zero declaration reverts `EmptyExchange`. Mandatory compound inside a later deposit or withdrawal is a side effect of that route, not a permissionless maintenance call. Stage one keeps explicit `compound()` even though entries and exits also compound, and it keeps that call available when issuance and donation are disabled. Withdrawal fallback can skip reinvestment. Without `compound()`, fees can sit unreinvested until some other exchange. That is a different need. This response does not name a bundle route for it, because none does this work.

### Resolutions that must not be silent

Recommendation: the maxima-versus-declared difference is not enough to keep `depositPair`. The caller outcome the owner asked about is "offer two amounts, receive shares, keep what the vault does not take." The accepted refund rule was written for that outcome. `used = declared - refunded` when the route consumes only the paired acceptance amount. The remaining difference is mechanical: the caller must hold and approve the full declaration, and the vault pulls it before refunding. The owner lock already rejected pull-only-consumed as the standard rule. Keeping `depositPair` to preserve pull-only-used would leave a second deposit entry beside `exchangeBundleInForSingleOut`.

Recommendation: raw ETH on `redeemPair` is a reason to extend the standard, not a reason to keep a paired redeem. The same recommendation applies to raw ETH input on `depositPair`. The owner lock left raw ETH on product functions outside the redefinition, but it did not name these two functions and did not require this family to keep them. Keeping either function as specified would also keep a wrapped-token path that can disagree with the bundle route. Full-spread has already dropped ERC-5115, so stage one's SY native entry and exit are not the replacement. This response does not invent the extension. No payable shape, no `address(0)` exception, and no wrap-or-unwrap rule is proposed. Until an extension exists, the mapped routes use the wrapped face. That is a real product gap. It is not a reason to retain the parallel functions.

Recommendation: dropping `depositPair` removes a second entry path that could disagree with `exchangeBundleInForSingleOut`. The two paths can disagree on accepted amounts, share mint, incumbent maintenance, pull-versus-refund, pretransfer, and native versus wrapped delivery. Stage one already says not to keep a second implementation of the same accounting behind another alias. Removal of that second deposit entry is a reason to map, not a reason to keep. For the map to fill the paired-deposit need, this family's bundle-in implementation has to be that one deposit formula, including two-token genesis when supply is empty. A one-nonzero-slot call is the single-token deposit, not `depositPair`. Empty-supply one-token bootstrap is not invented here. Those are route-conformance recommendations for the named function, not a new interface.

Recommendation: `previewDepositPair` and `previewRedeemPair` do not remain necessary as family functions if the paired mutators are mapped. Map them to the bundle previews named above. Their different return shapes are recoverable or caller-ordered, and the accepted preview contract is the weaker one. Do not keep them to preserve stage one's exact preview match. If this family wants that match, it is a property of the standard preview implementation, not a second function.

Recommendation: on the mapped withdrawal, consumption of the share means a burn of declared shares minus the unkept refund. A successful paired redeem should fully consume the declared shares or revert, so the pay-token refund is zero. The standard permits a nonzero share refund. Using that permission would change `redeemPair`, which burns the submitted amount or reverts on unmet minima. This is route conformance, not a new function.

Recommendation: a paired withdrawal names both underlying faces in `tokensOut`. A one-face `tokensOut` is a single-token exit, which is outside these six. The standard allows a subset only when no unrequested output is required. That does not require a separate `redeemPair`. Pass the two faces in `vaultTokens()` order if the caller wants pool-order alignment. The standard does not enforce that order.

What this response does not adopt: keeping `depositPair` for pull-only-used maxima; keeping `redeemPair` as the raw-ETH product function; mapping `donate` or `compound` onto any bundle function; mapping the deposit onto `exchangeInManyToOne`; mapping the redeem onto `exchangeOut` or `exchangeOutOneToMany`.

## Limits

- Runtime or extraction proof: none. These files were read as text. No test, build, script, or selector recomputation was run. Interface-comment selectors and report selectors were not checked.
- Not examined: peer responses; the full-spread PRD; facet and `PairToken.sol` bodies; `IStandardExchangeMultiAssetLiquidity` and the current many-to-one and one-to-many sources beyond what the admitted report says about them. The optional stage-one PRD was not read as a complete requirements list. Live files can change. This was not an atomic snapshot.
- The stage-one PRD retains native entry and payout under S1-P02. The brief says that PRD is not interface law for the new standard. This recommendation follows that boundary. It therefore does not preserve S1-P02 on this family.
- The `vaultTokens()` assumption above was not confirmed from the full-spread PRD.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path. It does not lock the PRD.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
- Actual Native role, model, reasoning, task ID, and session ID were not exposed. The requested model is not proof of the runtime model.
