# Astra research contribution

## Identity

- Assigned member: Astra.
- Requested model/account/reasoning: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, account, reasoning, role, task ID, session ID, parent and root identity: not exposed by this assignment.
- Profile: research; independent original contribution.
- Run: `se-interface-refund-bundle-20261030-01a18660`.
- Owned artifact: `members/astra/response.md`.
- Date: 2026-10-31.

## Question and targets

Should Standard Exchange present one `previewExchange` / `exchange` family for swaps, deposits and withdrawals, with same-input-token refunds, and what exact interfaces should it expose?

**Recommendation:** yes, introduce an explicitly distinct, refund-aware interface family. Make the requested bundle interfaces part of that family. Keep the existing interfaces intact as legacy surfaces rather than silently changing their return decoding or settlement semantics. Use token identities to distinguish swaps, deposits and withdrawals; do not require callers to understand the underlying protocol's join/exit vocabulary.

This contribution recommends interfaces and their settlement contract, not implementation. Every choice below that goes beyond the quoted owner constraints is a recommendation, not an owner's decision.

## Evidence

### Repository source observations

All eight required interface files were read completely in this run. References below identify declarations and comments, not inferred implementations.

| ID | Source | Observation |
| --- | --- | --- |
| E1 | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, `previewExchangeIn`, `exchangeIn`, `InArgs` | Both functions return only `amountOut`. Execution has a pretransfer flag and deadline. Its pretransfer comment requires the declared input to be covered by unbooked input, excludes booked backing, and says tokens above the declaration are not refunded. |
| E2 | `lib/crane/contracts/interfaces/IStandardExchangeOut.sol`, `previewExchangeOut`, `exchangeOut`, `OutArgs` | Preview returns required input. Pretransferred execution refunds `min(unrecorded balance, maxAmountIn) - used` to `msg.sender`; amounts above the maximum are not refunded. Non-pretransferred execution pulls only quoted used input and refunds nothing. |
| E3 | `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol` | Existing errors cover deadline, maximum input, minimum output, invalid/unsupported routes, exact output and unknown reserves. This file does not declare the `EOAPretransferNotAllowed()` error named by other interface comments. |
| E4 | `contracts/interfaces/IStandardExchange.sol` | The current aggregate inherits the existing In and Out interfaces and adds no functions. |
| E5 | `contracts/interfaces/IStandardExchangeInMulti.sol`, both many-to-one functions | Inputs contain explicit token addresses and amounts in the vault's declared order. Output is scalar. V4 comments specify PoolKey order and a WETH ERC-20 face. The pretransfer comment excludes refunds of tokens above the declaration. |
| E6 | `contracts/interfaces/IStandardExchangeOutMulti.sol`, both one-to-many functions | This is specifically an exact-output dual exit from vault shares. It takes both output addresses and exact amounts, returns shares burned, requires two pool currencies in declared order, and uses E2's funding/refund distinction. Its preview does not simulate tail-rebalance. |
| E7 | `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol` | This separates proportional, unbalanced, single-asset and alias liquidity functions. Its header explicitly says canonical In/Out remain swap-only and must not absorb these selectors. Proportional join returns used input amounts; proportional exit accepts shares and returns an output vector. |
| E8 | `contracts/vaults/basic/IBasicVault.sol` | It declares `vaultTokens()`, `reserveOfToken(address)` and `reserves()`. The token-list comment says accepted/produced tokens; it does not itself specify order immutability, share exclusion or bundle alignment semantics. |

**Inference from E1/E5:** an unconsumed portion of a caller's declared input and surplus exceeding that declaration are different accounting quantities. The new same-token refund rule can apply to the former without awarding all unbooked balances to that caller. These comments do not establish that partially consuming declared input is already supported.

**Inference from E2/E6:** a spending cap is not necessarily an amount actually funded. Returning `maxAmountIn - amountInUsed` as a refund on today's ordinary exact-output path would falsely describe tokens that never left the caller.

### Narrow public ABI verification

**Source observation E9:** Solidity's official Contract ABI Specification, section “Function Selector,” excludes return types from the function signature used for selector calculation. Therefore, adding a refund return alone does **not** change a selector. It changes the ABI return contract. The brief's phrase “breaking selector change” should be corrected to “breaking ABI/semantic change unless a new name or input signature is introduced.” **Inference:** a new caller expecting two return words cannot rely on an old implementation returning one, and a selector-based interface identifier cannot distinguish a return-only revision. This is why I recommend new function suffixes rather than a return-only replacement. Source: E9's direct retrieval below.

Exact public queries used:

- `site.docs.soliditylang.org ABI function selector return types not part signature`
- `site:docs.soliditylang.org "return types" "signature" "selector"`

Primary source retrieved with `webfetch`: `https://docs.soliditylang.org/en/latest/abi-spec.html`, sections “Function Selector” and “Function Selector and Argument Encoding.” The server search/open calls returned no visible source records; the subsequent `webfetch` supplied the readable primary text for E9.
No private source excerpts or repository paths were sent to search.

## Assumptions

1. **Recommendation A1:** use an ERC-20-only external settlement face. Reject `address(0)`; do not make these functions payable. A native underlying uses its declared wrapped-token face, consistent with E5/E6. Native wrapping inside a route is not caller-facing native-ETH support.
2. **Recommendation A2:** the vault's share token is `address(this)` for the deposit/withdrawal classification below. E6 explicitly uses that convention. Other share arrangements require a separately specified discovery contract; they are not silently inferred.
3. **Recommendation A3:** retain the repository router's prohibition on fee-on-transfer and rebasing underlyings. Amounts are raw token units, not normalized common-decimal values.
4. **Recommendation A4:** expose only routes the vault can settle under the refund contract. An interface declaration does not prove a particular protocol can produce a same-token remainder with bounded gas.
5. **Recommendation A5:** refunds go to `msg.sender`, independently of the output `recipient`, matching E2. The caller is responsible for forwarding refunds to its own user. A distinct refund-recipient parameter is not necessary for this revision.
6. **Recommendation A6:** the proposed exact-output family uses a fully funded input budget in both funding modes. This is deliberately different from legacy E2/E6 and is explained below. It trades extra transfer/approval work for a precise, funding-mode-independent preview/refund contract.

## Coverage

| Target or question | Coverage |
| --- | --- |
| All eight required interface files | Examined completely; E1-E8. |
| Immediate shared error interface | Examined; E3. |
| Current scalar and multi pretransfer comments | Examined; declaration surplus and exact-output funding distinctions retained explicitly. |
| Exact recommended Solidity definitions | Provided below, including the two owner-named interfaces, pretransfer options and refund returns. |
| Replacement versus extension versus coexistence | Function-by-function mapping below. |
| Bundle output addresses versus amounts | Resolved as recommendations R4/R5, not attributed to the owner. |
| Canonical token ordering and native ETH | Resolved as recommendations R3/R7. |
| Preview refund meaning | Resolved as recommendation R6. |
| Optional `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` and `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | Not examined; optional and not treated as interface law. |
| Protocol implementations, callers, deployed contracts, gas feasibility and runtime behavior | Not examined or executed; outside this assignment. |
| Peer responses | Not read. |

## Conclusions

### R1. Unify the operation vocabulary, not incompatible deployed ABIs

**Recommendation:** add `IStandardExchangeInWithRefund` and `IStandardExchangeOutWithRefund` beside the existing scalar interfaces. Keep old names, returns and behavior unchanged for legacy users. Use the new family as the preferred integration surface for new compliant products.

For a supported route:

- Underlying token to another underlying token is a swap.
- Underlying token or underlying bundle to `IERC20(address(this))` is a deposit.
- `IERC20(address(this))` to an underlying token or output bundle is a withdrawal.

The same signatures and refund law cover all three. A vault need not support every combination. Unsupported scalar routes revert `RouteNotSupported`; unsupported bundles revert the bundle error defined below. Preview and execution must agree on structural route validity. Same-token identity routes are rejected rather than implicitly treated as withdrawals or refunds.

**Recommendation:** do not edit E7's historical swap-only contract to pretend it always meant this. The new family's documentation must explicitly supersede that restriction for new opt-in interfaces, while the legacy liquidity extension remains separate. Existing aliases can coexist, but a function is not a semantic alias unless its amounts, rounding, fees, refund recipient and output protections actually match.

### R2. Define refunds against the admitted input budget

**Recommendation:** each call admits a declared budget for every input token. For exact-input calls it is `amountIn` or `amountsIn[i]`. For new exact-output calls it is `maxAmountIn`.

For each admitted input:

```text
fundedBudget = amountInUsed + amountInRefunded
```

`amountInUsed` includes input-denominated fees actually charged by the route. A protocol cannot classify idle leftover inventory as a fee merely to avoid refunding it. `amountInRefunded` is the same token, actually transferred back to the caller before successful execution returns. It is not an internal credit, an output surplus, an unused allowance, or a value-denominated estimate.

- `pretransferred == false`: pull the full declared budget from `msg.sender`, execute, and return the unused portion.
- `pretransferred == true`: require unbooked input covering the full declared budget; attribute at most that budget to this call. Do not fund a shortfall from booked backing. Refund only the unused admitted portion.
- Reject pretransfer calls from callers with no bytecode, retaining the stated legacy restriction. Transfer-and-consume must be atomic; this restriction does not establish ownership of previously resting surplus.
- Tokens above the declaration remain outside the call and are not refunded. A difference between total unbooked surplus and the declaration is not itself an error.
- In a share-input withdrawal, used shares are burned and unused admitted shares are returned; do not burn the entire budget and manufacture a refund in underlying tokens.
- Any intermediate unconsumed token must be resolved internally so the caller receives only its requested outputs and its original input-token refund(s). If this is infeasible, the route must revert or be unsupported, not leak an unrequested dust token.

**Recommendation:** exact-input now means a fixed offered budget with potentially partial consumption, not a guarantee that every input unit is spent. Minimum outputs protect the result. A positive offered budget that consumes nothing should revert rather than succeed as a misleading all-refund exchange. A positive exact-output request must be completely satisfied or revert; it must not quietly become partial-output.

The full-budget exact-output rule is an explicit new choice. It makes a budget of 100, used input of 73 and refund of 27 mean the same thing in both modes. Under legacy E2, the ordinary path instead pulls 73 and refunds zero. Keeping that optimization would require a different preview contract, or separate “unused cap” and “actual refund” results; do not ambiguously call both values a refund.

### R3. Give bundle input exactly one positional order

**Recommendation:** `amountsIn.length == vaultTokens().length`, with index-for-index correspondence. Include zero entries for unused tokens. Do not also accept arbitrary input-address permutations, compact subsets or a second ordering convention in this interface.

**Recommendation:** for an instance advertising this interface, `vaultTokens()` is a stable, duplicate-free list of nonzero ERC-20 faces. Changing its order or membership invalidates positional calldata, so the list must remain stable for that instance. The bundle interface references the list actually exposed; it does not silently redefine which assets an existing vault lists or force shares into or out of that list. A product whose existing list cannot serve as its stable input manifest must not advertise this interface without an explicitly approved discovery change.

The output refund vector always has that full length and order, including zeros. Unsupported combinations of nonzero entries revert; zero entries are not funded and cannot claim resting balances.

### R4. Interpret the requested BundleOut as fixed-input, variable-output

**Recommendation resolving ambiguity:** the owner's “array of tokens they expect to receive” means an address array. Add a scalar offered `amountIn`, return actual amounts for those addresses, and accept a matching `minAmountsOut` vector on execution. This makes the named interface useful for proportional withdrawals without needing an expensive inverse solve.

**Recommendation:** output addresses must be nonempty, unique, members of `vaultTokens()`, and in their relative canonical order. A supported subset may be requested; it is not silently expanded. Returning every reserve is legal by passing the complete list. The implementation must deliver exactly the requested token identities, meet each minimum and return no unrequested token. It can reject a subset route that cannot meet these rules. Reject any output address equal to `tokenIn`; this keeps output delivery distinct from input refund.

This differs from E6: the current one-to-many interface specifies exact output quantities and is restricted to a two-token share exit. Therefore the new `BundleOut` is not merely a rename of it.

### R5. Preserve exact-output bundles as a separately suffixed capability

**Recommendation resolving ambiguity:** also define optional `IStandardExchangeBundleOutExactOut`. Here the caller supplies **both** output addresses and exact output amounts, plus a funded maximum input. This is the refund-aware generalization of E6, without forcing the unsuffixed `BundleOut` to mean both exact-in and exact-out.

The same output identity/order rules apply. Requested output quantities are delivered exactly or the call reverts. Internally generated excess cannot be sent as undeclared output or counted as a same-token input refund. A product unable to satisfy this exact-output contract need not expose the capability. No iterative inverse-solver requirement is implied.

### R6. Preview refunds are estimates of a concrete settlement operation

**Recommendation:** a preview returns the output and refund that the corresponding execution algorithm would produce against the current state using the declared funded budget. It does not transfer, reserve tokens, check the caller's allowance, or require a pretransfer balance to exist.

Because the proposed execution funds the same full budget in either mode, preview does not need a pretransfer flag. Exact-output previews take `maxAmountIn` so their refund has a defined budget, and revert if required input exceeds it. Execution still recomputes against its execution state and enforces its deadline and output limits.

Preview is not a promise about a later block. Within an unchanged relevant state, it must model the same bounded algorithm, rounding, fees and partial-consumption rule as execution, not an idealized full-consumption calculation. If a compliant view quote is unavailable, do not advertise that preview capability and return an invented zero refund. Declaring an interface is not evidence that this quoting requirement is achievable for every candidate protocol.

### R7. Exact recommended definitions

**Recommendation:** use the following declarations as one coherent proposed interface set. This is specification text, not a patch to production interfaces. Existing shared errors are inherited; added errors make the new validation and availability contract explicit. Keep all amounts in token-native units. New interfaces do not inherit the legacy In/Out declarations.

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeErrors} from
    "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

interface IStandardExchangeRefundErrors is IStandardExchangeErrors {
    error EOAPretransferNotAllowed();
    error InvalidRecipient(address recipient);
    error InvalidBundleLength(uint256 expected, uint256 actual);
    error InvalidBundleToken(uint256 index, address token);
    error EmptyExchange();
    error InsufficientPretransferredInput(
        address token,
        uint256 required,
        uint256 available
    );
    error BundleRouteNotSupported(bytes4 functionSelector);
    error PreviewNotAvailable(bytes4 functionSelector);
}

interface IStandardExchangeInWithRefund is IStandardExchangeRefundErrors {
    /// @notice Quote a funded input budget and its same-token remainder.
    function previewExchangeInWithRefund(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut
    ) external view returns (
        uint256 amountOut,
        uint256 amountInRefunded
    );

    /// @notice Output goes to recipient; tokenIn refund goes to msg.sender.
    function exchangeInWithRefund(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (
        uint256 amountOut,
        uint256 amountInRefunded
    );
}

interface IStandardExchangeOutWithRefund is IStandardExchangeRefundErrors {
    /// @notice Quote exact output against a fully funded maximum input.
    function previewExchangeOutWithRefund(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut
    ) external view returns (
        uint256 amountInUsed,
        uint256 amountInRefunded
    );

    /// @notice Fund maxAmountIn, deliver exact amountOut, refund unused tokenIn.
    function exchangeOutWithRefund(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (
        uint256 amountInUsed,
        uint256 amountInRefunded
    );
}

interface IStandardExchangeBundleInForSingleOut
    is IStandardExchangeRefundErrors
{
    /// @notice Both input and refund vectors follow the complete vaultTokens().
    function previewExchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        IERC20 tokenOut
    ) external view returns (
        uint256 amountOut,
        uint256[] memory amountsInRefunded
    );

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (
        uint256 amountOut,
        uint256[] memory amountsInRefunded
    );
}

interface IStandardExchangeBundleOut is IStandardExchangeRefundErrors {
    /// @notice Output amounts follow tokensOut; refund is solely tokenIn.
    function previewExchangeBundleOut(
        IERC20 tokenIn,
        uint256 amountIn,
        address[] calldata tokensOut
    ) external view returns (
        uint256[] memory amountsOut,
        uint256 amountInRefunded
    );

    function exchangeBundleOut(
        IERC20 tokenIn,
        uint256 amountIn,
        address[] calldata tokensOut,
        uint256[] calldata minAmountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (
        uint256[] memory amountsOut,
        uint256 amountInRefunded
    );
}

interface IStandardExchangeBundleOutExactOut
    is IStandardExchangeRefundErrors
{
    /// @notice Exact output vectors follow tokensOut; fund maxAmountIn.
    function previewExchangeBundleOutExactOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut
    ) external view returns (
        uint256 amountInUsed,
        uint256 amountInRefunded
    );

    function exchangeBundleOutExactOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (
        uint256 amountInUsed,
        uint256 amountInRefunded
    );
}

/// @notice Convenience type for products supporting both scalar capabilities.
interface IStandardExchangeWithRefund is
    IStandardExchangeInWithRefund,
    IStandardExchangeOutWithRefund
{}
```

**Recommendation:** the scalar aggregate does not force bundle or exact-output support onto every product. A product advertises each capability separately and only advertises the aggregate if both scalar capabilities exist. Use the repository's existing capability-advertisement mechanism; no new discovery function is proposed here.

**Recommendation:** keep `IBasicVault`'s exact declarations unchanged:

```solidity
interface IBasicVault {
    function vaultTokens() external view returns (address[] memory tokens_);
    function reserveOfToken(address token) external view returns (uint256 reserve_);
    function reserves() external view returns (uint256[] memory reserves_);
}
```

The stable ordering constraint in R3 is a new conformance requirement for bundle-capable instances, not a claim that today's `IBasicVault` already guarantees it. No recommendation here changes the meaning of `reserveOfToken`, `reserves`, vault configuration, pricing or rate-provider functions.

Additional normative recommendations for these definitions:

- Reject zero input budgets, all-zero input bundles, empty output bundles, zero exact-output requests and successful no-consumption exchanges with `EmptyExchange()`. Zero entries in an otherwise nonzero bundle are allowed.
- Reject zero output recipients and the vault itself as recipient with `InvalidRecipient`; these interfaces promise delivery outside the vault's booked inventory.
- Require each output amount/minimum vector to have the same length as `tokensOut`. Require returned vectors to have the corresponding declared lengths. Use `InvalidBundleLength`.
- Reject zero token faces, duplicate/out-of-order output addresses and addresses outside the canonical output list with `InvalidBundleToken`. Reject unsupported scalar routes with the existing route errors. Reject a bundle with a positively funded input equal to its single output as an unsupported bundle route.
- Use existing `DeadlineExceeded`, `MaxAmountExceeded`, `MinAmountNotMet` and `AmountOutNotMet` for their named constraints; enforce output minima per token, never by adding quantities of unrelated tokens.
- A failed required output or refund transfer reverts the whole operation. An execution return describes completed settlement, not a promise to transfer later.
- `PreviewNotAvailable` identifies a route's inability to quote; it is not permission to claim that an unquotable route satisfies the new preview/execution contract. Consumers must not treat a reverting preview as a successful quote.

### R8. Function disposition and legacy migration

All replacements in this table are **semantic successors for new integrations**, not authorization to change a deployed selector or edit a current interface in place.

| Proposed function | Disposition relative to current functions |
| --- | --- |
| `previewExchangeInWithRefund` | Sits beside `previewExchangeIn`; extends its quote with a same-token refund estimate and a broader supported-route domain. |
| `exchangeInWithRefund` | Sits beside `exchangeIn`; preferred successor with partial-consumption/refund settlement. It can also serve supported single-asset deposit and withdrawal routes. |
| `previewExchangeOutWithRefund` | Sits beside `previewExchangeOut`; adds an explicit funding budget and returns used input plus refund. |
| `exchangeOutWithRefund` | Sits beside `exchangeOut`; preferred successor with full-budget funding in both modes and an actual refund return. This is not legacy pull-only-used behavior. |
| `previewExchangeBundleInForSingleOut` | Sits beside `previewExchangeInManyToOne`; semantic successor eliminating the redundant input-address array and adding a refund vector. |
| `exchangeBundleInForSingleOut` | Sits beside `exchangeInManyToOne`; semantic successor for canonical bundle deposits or other supported bundle-to-single routes. |
| `previewExchangeBundleOut` | New capability beside `previewExchangeOutOneToMany`; quotes outputs for an offered input budget rather than input for fixed outputs. Can represent `previewExitProportional` where semantics match. |
| `exchangeBundleOut` | New capability beside `exchangeOutOneToMany`; can succeed `exitProportional` for a matching route, with output minima, pretransfer and same-input refund reporting. |
| `previewExchangeBundleOutExactOut` | Sits beside `previewExchangeOutOneToMany`; refund-aware semantic successor with an explicit funded maximum and generalized output vector. |
| `exchangeBundleOutExactOut` | Sits beside `exchangeOutOneToMany`; refund-aware semantic successor, with the explicit full-budget funding difference. |
| `vaultTokens` | Retained unchanged in ABI; extended by R3's conformance requirement only for new bundle-capable instances. |
| `reserveOfToken`, `reserves` | Retained unchanged; sit beside the new settlement surface. |

**Recommendation for E7's complete liquidity surface:**

- `previewJoinSingleAssetExactIn`, `joinSingleAssetExactIn`, `previewDepositSingle` and `depositSingle` map semantically to the new scalar In pair with the share token as output.
- `previewJoinSingleAssetExactOut` and `joinSingleAssetExactOut` map to the new scalar Out pair with shares as exact output.
- `previewExitSingleAssetExactBptIn`, `exitSingleAssetExactBptIn`, `previewWithdrawSingle` and `withdrawSingle` map to the new scalar In pair with shares as input.
- `previewExitSingleAssetExactTokenOut`, `exitSingleAssetExactTokenOut`, `previewWithdrawSingleExactOut` and `withdrawSingleExactOut` map to the new scalar Out pair with shares as input.
- `previewJoinProportional` and `joinProportional` can map to BundleInForSingleOut with shares as output and input refunds equal to funded amounts minus used amounts.
- `previewExitProportional` and `exitProportional` can map to BundleOut with shares as input and the complete underlying output list.
- `previewJoinUnbalanced` and `joinUnbalanced` cannot automatically be aliases of the same bundle-input call as proportional join: identical tokens and budgets do not encode a choice between two liquidity policies. **Recommendation:** the new generic route has one documented deterministic policy per product. Retain specialized policy-selecting functions beside it; do not add a guessed mode parameter or pretend both policies became the same operation.

This preserves the owner's unified default integration goal without erasing meaningful specialized behavior. If exposing multiple policies through the generic standard is desired, that is a separate explicit interface decision.

### R9. Acceptance implications, not executed tests

**Recommendation:** any later implementation assignment should demonstrate these observable cases:

1. A declared budget of 100 with 80 consumed delivers the quoted output and returns 20 of exactly the input token.
2. A pretransfer of 130 with a declaration of 100 and consumption of 80 refunds 20, not 50; the extra 30 is not attributed to this call.
3. An insufficient unbooked balance cannot borrow booked holder backing to satisfy a declaration.
4. New exact-output calls with a budget of 100 and 73 used refund 27 in both modes; legacy ordinary exact-output behavior remains pull-73/refund-zero.
5. Canonical bundle input returns a full-length, correctly ordered refund vector, including zero entries.
6. Bundle output delivers only the requested addresses, matches their order and enforces each minimum separately.
7. A partial withdrawal returns unburned shares as the refund, never another underlying token in their place.
8. An unsupported same-token-remainder route reverts rather than returning a different dust token.
9. Preview and execution use the same arithmetic and bounded policy under the same relevant state; output changes before execution are caught by its limits.
10. New return decoding is exercised against the new capabilities, not inferred from an old selector or a return-only interface revision.

These are recommended acceptance observations, not claims of test coverage or an implementation/test plan.

## Limits

This is one independent research contribution. It neither replaces an owner decision nor authorizes implementation, deployment, interface migration or PRD changes.

The exact Solidity declarations have not been compiled, their selectors/interface IDs have not been calculated, and no tests or Git commands were run. No production code, peer file, brief, run record or aggregate report was edited. Only this owned response was created.

All required source interfaces were examined as live files, not as an atomic repository snapshot. No implementation or call-site survey establishes whether existing products can satisfy the proposed same-token remainder, immutable token ordering, full-budget exact-output funding or bounded preview requirements. Those are explicit recommendations and adoption gates, not proven properties.

The principal unresolved owner choice is whether the efficiency cost of fully funding exact-output budgets is acceptable. This contribution recommends it for a coherent refund contract; it does not claim the owner selected it. The other ambiguity resolutions are likewise recommendations: address-only unsuffixed BundleOut with a separate exact-output capability, stable canonical ordering, ERC-20 faces, caller-directed refunds and one deterministic generic liquidity policy per product.
