# Astra research response

## Identity

- Run: `se-paired-money-necessity-20261030-01a18660`.
- Assigned member: Astra.
- Profile: research; independent initial contribution.
- Requested role: `council-member`.
- Requested model and reasoning: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, account route, reasoning, and role: not exposed.
- Native task, conversation, parent, and root identities: not exposed.
- Date: 2026-10-31.

## Question and targets

Does the accepted Standard Exchange redefinition fill the same need as the six paired-money functions, and which should the new full-spread family keep, drop, or map onto a named standard function?

**Recommendation:** Map the four paired deposit/redemption functions, including their previews, onto the accepted bundle functions. Keep `donate` and `compound`. This replaces the paired exchange selectors, not the underlying two-token ownership operations. It deliberately selects wrapped ERC-20 entry and payout over the old paired methods' raw-ETH convenience; it is not a claim of complete behavioral equivalence.

The admitted evidence is identified below. The accepted report's owner lock controls the new standard. The stage-one PRD explains the older functions but does not impose its interface choices on this family.

## Evidence

### E1. Current function-review record

**Source observation:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, sections "Standard Exchange return" and "Paired money", records the accepted refund/bundle definition and leaves these six functions open. It describes two maxima for paired entry, two proportional payouts for paired redemption, a no-share donation, and a supply-preserving compound.

**Inference:** The sentence saying the standard one-token interface cannot express the paired operations describes the limitation of a scalar interface. It does not establish a continuing need for paired selectors after the accepted bundle interfaces are considered.

### E2. Accepted standard, including the owner override

**Source observation:** `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, revision `se-interface-refund-bundle-20261030-01a18660-final`, sections "Owner lock", "Refund rule", and "Recommended interfaces":

- `exchangeIn` and `previewExchangeIn` retain their names and parameters and return output plus refund. The earlier report prose advocating separate siblings is overridden.
- `exchangeBundleInForSingleOut` accepts declared inputs in `vaultTokens()` order, one output token, an output minimum, recipient, pretransfer flag, and deadline. Its preview returns output and per-input refunds.
- `exchangeBundleOut` is exact-input: one pay token and amount, caller-named output tokens, per-output floors, recipient, pretransfer flag, and deadline. Its preview returns the outputs and unkept pay-token refund.
- Share identity makes the route an entry or exit: share as output is a deposit; share as input is a withdrawal. The share need not occur in `vaultTokens()`.
- Declared input equals consumed input plus refunded input. A pull route pulls the declaration and returns the unkept amount to `msg.sender`; output goes to `recipient`.
- Bundle-in membership and ordering must remain stable. Bundle-out receipts follow the caller's output ordering and cannot include an unrequested token.
- These functions are nonpayable, reject `address(0)`, and use wrapped ERC-20 faces. The standard does not add raw-ETH support.
- Previews quote rather than transfer, and the accepted standard does not require bit-exact preview/execution equality. Caller minima bind execution.
- `exchangeOut` has no new refund return and is not the accepted exact-input bundle redemption route.

### E3. Current paired-function declarations

**Source observation:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol`, declarations and NatSpec for all six functions, lines 188-246:

- `depositPair` is payable, accepts portions of two maxima, and returns shares. On a native pool it receives the native maximum and refunds unused ETH.
- `previewDepositPair` returns shares and two accepted amounts.
- `redeemPair` burns caller shares and pays both actual pool currencies proportionally.
- `previewRedeemPair` projects the two payouts through the conditional maintenance choice.
- `donate` pulls and books this call's positive contribution without minting.
- `compound` maintains incumbent backing without changing supply or charging vault fees and returns realized fees.

These declarations establish available signatures and documented intent, not runtime correctness.

### E4. Historical operation semantics

**Source observation:** `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, revision "Owner-approved bounded-execution amendment, 2026-10-29":

- S1-ACC-02 and S1-OP-01: paired entry sizes accepted input against the basket; only accepted ERC-20 amounts are pulled. The first deposit uses both currencies. Unused native maximum is refunded.
- S1-ACC-03, S1-ACC-05, and S1-OP-03: paired exit allocates proportional principal and booked idle, supports terminal withdrawal without requiring an opposing-token sale, and pays raw ETH for a native leg. It burns caller-held shares without a paired pretransfer flag or third-party allowance-burn path.
- S1-ACC-04: donation explicitly books same-call receipt without shares. An unsolicited transfer is not automatically adopted, and historical unbooked balances are not a safe donation substitute.
- S1-OP-05: standalone compounding collects fees, may rebalance and reinvest, preserves supply, and shares an engine with automatic maintenance.
- S1-EXIT-01 and S1-QUOTE-01: paired withdrawal and its quote include the selected full or collection-only maintenance path.
- S1-NATIVE-01: actual native currency and its wrapped standard-interface face are distinct representations.

**Inference:** The earlier justification for separate paired methods relied on scalar routes, full-keep many-to-one input, and exact-output one-to-many withdrawal. The newly accepted refund-capable many-input route and exact-input many-output route remove those particular expressiveness gaps. They do not themselves specify issuance mathematics, proportional ownership, maintenance policy, or native-currency delivery.

## Assumptions

1. The question concerns the new full-spread family's surface, not authorization to remove methods from the existing PairToken deployment or implementation.
2. The accepted report is the controlling standard definition; its owner lock overrides contradictory preserved council prose.
3. The family share is denoted `V`; its two underlying ERC-20 faces are `C0` and `C1`. A native underlying uses its configured wrapper as the standard-facing address. These symbols describe argument selection, not newly prescribed configuration.
4. No current implementation of the bundle routes has been established by this investigation. Capability at the interface level is distinct from supported routes in a deployed vault.
5. The new family's detailed accounting and sleeve policy are not inferred from the older stage-one PRD. Any suggested preservation of paired economics below is a recommendation, not a claim that the accepted standard already requires it.

## Coverage

| Target | Coverage |
| --- | --- |
| Assignment brief | Read completely. Question, six-function list, ambiguities, and boundaries covered. |
| Function-review file | Read completely; paired-money section and standard lock examined. Other function groups are not decided here. |
| Accepted interface report | Read completely, including owner override, refund rules, and both bundle interfaces. |
| Current PairToken interface | Read through line 260; all six required declarations, their NatSpec, and relevant events examined. Unrelated remaining queries not examined. |
| Optional stage-one PRD | Partially examined: lines 1-240, 274-417, 511-724, and 831-953. These cover authority context, paired accounting, donation, terminal withdrawal, operations, native adaptation, ABI, and previews. Remaining sections are not claimed as examined. |
| Peer responses | Not read. |
| Runtime behavior and deployment | Not examined; no tests, build, wallet, deployment, or Git operations performed. |

All six decisions and all four ambiguity prompts are answered below. Required evidence was available. Sources were live local files read during this turn, not an atomic repository snapshot. No public searches or private-source queries were needed.

## Conclusions

### Six-function disposition

All rows are **recommendations**, not locked decisions. "Map" means remove the paired selector from the proposed new family and expose its exchange purpose through the named accepted standard function, subject to the explicit differences below.

| Existing function | Decision | Named route and argument mapping | Behavior not automatically preserved |
| --- | --- | --- | --- |
| `depositPair(amount0Max, amount1Max, minShares, recipient, deadline)` | **MAP** | `exchangeBundleInForSingleOut(amountsIn, V, minShares, recipient, false, deadline)`. Place each maximum at its matching currency-face index in `vaultTokens()`. **`tokenOut = V` makes this a deposit.** | The standard pulls both declarations before refunding unkept input; it does not pull only accepted ERC-20 amounts. It accepts no raw ETH. Paired issuance, maintenance, and genesis behavior require family semantics. |
| `previewDepositPair(amount0Max, amount1Max)` | **MAP** | `previewExchangeBundleInForSingleOut(amountsIn, V)`. **`tokenOut = V` quotes a deposit.** Shares are `amountOut`; each quoted consumed amount is `amountsIn[i] - amountsRefunded[i]`. | Returns refunds rather than a literal `(used0, used1)` tuple. Consumption includes any input-denominated fee actually charged, not necessarily position principal. The standard does not inherit the old exact economic-preview guarantee. |
| `redeemPair(shares, min0, min1, recipient, deadline)` | **MAP** | `exchangeBundleOut(V, shares, [C0, C1], [min0, min1], recipient, false, deadline)`. **`tokenIn = V` makes this a withdrawal.** Output addresses and floors must be kept aligned. | Native payout is wrapped, not raw ETH. The standard permits an unkept share refund and uses its own input-funding contract; it does not inherently promise full burn or the old direct caller-burn authority. Proportional/no-sale exit behavior requires family semantics. |
| `previewRedeemPair(shares)` | **MAP** | `previewExchangeBundleOut(V, shares, [C0, C1])`. **`tokenIn = V` quotes a withdrawal.** The two receipts replace `(amount0, amount1)`; the extra refund is in shares. | Native output is quoted in wrapped-face units. Conditional maintenance and full-share consumption are not guaranteed by the generic signature. |
| `donate(token, amount)` | **KEEP** | No accepted standard function performs explicit same-call reserve donation with no share issuance. | Bundle-in with share output is a deposit, not a donation. Setting `minAmountOut = 0` does not instruct it to mint zero shares. An unsolicited transfer or surplus outside a declaration is not an explicit booked donation. |
| `compound()` | **KEEP** | No accepted standard function is a no-input, supply-preserving fee-collection/reinvestment operation. | Exchange operations and their previews do not supply a standalone maintenance trigger. Zero scalar input and all-zero bundle input are rejected by the accepted standard. Automatic maintenance on another operation is not independent permissionless maintenance. |

### Recommendation: maxima do not justify a second deposit selector

For each leg, declaring the old maximum as bundle input permits the same net accepted amount: `maximum = consumed + refunded`. This is enough to express bounded two-token contribution and share issuance.

It is not the same custody contract. Under the old paired pull path, a caller can need balance and allowance only for the accepted amounts; under the accepted bundle pull path, the caller must fund and authorize the full declared amounts. Refund transfer failure is also a failure mode for unused ERC-20 input that the old pull-only-accepted path avoided. E2 and E4 establish this difference.

**Recommendation:** Accept that funding/approval difference for one standard entry surface. Do not keep `depositPair` merely to avoid temporary custody of unused input, and do not change the standard by pulling only the computed accepted amounts. Return every unkept declared amount to the caller; do not silently retain it as uncredited backing.

**Recommendation:** Preserve a genuine paired deposit mode behind the bundle-to-share route, including a two-currency bootstrap where required by the chosen family accounting. Do not replace it with two sequential single-token zaps or infer that a permitted zero input slot automatically authorizes one-token genesis. The ABI permits the paired operation but does not choose its economics.

### Recommendation: choose wrapped paired I/O rather than extend the standard

Raw-ETH entry and payout are real capabilities of the older paired methods. Neither accepted bundle function supplies them. Wrapped payout also adds a dependency on successful wrapping that raw payout did not have.

**Recommendation:** For this new family's paired exchange surface, accept wrapped-native entry and payout and remove the raw-ETH paired conveniences with the four mapped selectors. Do not extend the accepted standard and do not pretend that `address(0)` or attached value is valid. A caller needing raw ETH must perform conversion outside these standard calls; no router, wrapper helper, or new extension is specified here.

This is an explicit proposed product trade-off, not an already authorized removal. The historical S1-P02 native-support lock belongs to the stage-one context and cannot be silently transported into, or silently erased from, the new family's requirements. If the owner requires direct raw-ETH paired operations in this family, the wrapped mapping alone is insufficient and this recommendation must change. The present recommendation chooses wrapped I/O rather than leaving the choice unresolved.

Keeping payable donation does not restore native share issuance or paired redemption; it has a different purpose.

### Recommendation: one canonical route, preserving the paired exit

**Recommendation:** Remove the paired aliases rather than maintain a second entry path that could compute different accepted amounts, shares, fees, or refunds from `exchangeBundleInForSingleOut`. Use the corresponding standard preview for that same economic route. Removing selectors reduces opportunities for disagreement; it does not prove consistent accounting.

**Recommendation:** For `exchangeBundleOut(V, shares, [C0, C1], ...)`, preserve full-share proportional redemption: consume/burn all submitted shares or revert, with zero share refund on success. The standard can express this stricter family policy without requiring partial redemption. Preserve the ability to receive both underlyings without an unwanted-token sale, including terminal withdrawal where supported by the family. Do not route this through `exchangeOut`, sell one leg merely to reconstruct the other, or silently discard an output.

This recommendation preserves the useful paired exit, not necessarily every old authorization detail. Standard pull/pretransfer rules differ from a method that directly burns caller-held shares. In particular, the old absence of a share-transfer allowance requirement is not established by the new standard. Funding and holder authorization must be made explicit when the owner later authorizes specification or implementation work; the method-name mapping is not evidence that those contracts are identical.

### Recommendation: remove duplicate previews, not quoting capability

**Recommendation:** Map both previews along with their mutators. There is no remaining paired-only quote object once the family chooses wrapped bundle entry and exit. Deposit consumers can derive the quoted accepted inputs by subtracting refunds; redemption consumers read the two output receipts and check the share-refund quote.

**Recommendation:** Have those standard previews model the family's actual paired economic path, including whatever maintenance and rounding policy is selected, instead of preserving separate paired preview selectors to carry that information. The old PRD's execution-equivalent projection is not a guarantee granted by the new standard, whose accepted contract allows preview/execution differences. Minima and deadlines remain necessary. A separate preview name does not itself recover stronger quote accuracy.

### Recommendation: retain donation and maintenance as distinct operations

**Recommendation:** Keep explicit donation and standalone compound because they perform work outside the exchange contract. Donation changes booked shareholder backing without minting; compound realizes and reinvests incumbent value without a caller exchange or a supply change. Neither needs a fabricated output token, a zero-input exchange, or a minimum set to zero.

**Recommendation:** Reclassify these two conceptually as donation and maintenance rather than interpreting their placement under "Paired money" as proof of redundancy. This recommendation does not prescribe new fee, sleeve-refill, compounding, or access-control policies and does not import the stage-one algorithm wholesale.

## Limits

This contribution is source-based research, not a code review or runtime proof. It makes no claim that the accepted interfaces have been implemented or that the new family already conforms to them. Generic route expressiveness does not prove availability, numerical equivalence, gas feasibility, or exit success.

The contribution reads no peers, changes no PRD or function-review file, and authorizes no implementation. All proposed ambiguity resolutions are labeled recommendations. The owner must separately accept the deliberate differences, particularly wrapped-only paired I/O and pull-declaration/refund custody. This response does not lock the PRD.
