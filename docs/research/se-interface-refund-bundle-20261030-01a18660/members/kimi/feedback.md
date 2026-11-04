# Kimi advisory feedback

## Identity

- Council member: Kimi
- Advisory pass: one
- Profile: research

## Draft under review

- Draft ID: `se-interface-refund-bundle-20261030-01a18660-r1`
- Path: `docs/research/se-interface-refund-bundle-20261030-01a18660/coordinator/draft.md`
- Coordinator-supplied SHA-256 provenance noted; not recomputed.

## Disposition

**REQUEST CHANGES.**

The draft honestly records the major disagreements and is otherwise coherent. The blocking gap is that its named refund return applies only to new exact-in functions. Current exact-out execution retains an unnamed side-effect refund, and exact-out preview still cannot quote a refund because it has no `maxAmountIn`. The proposed family therefore does not provide a consistent refund-return contract across the route shapes it covers.

## Required corrections

### 1. Proposed text: add an exact-out refund surface beside the current functions

If the draft retains its additive compatibility strategy, add `IStandardExchangeOutWithRefund` beside `IStandardExchangeOut`, rather than leaving exact-out refund accounting implicit. The recommended functions are:

```solidity
function previewExchangeOutWithRefund(
    IERC20 tokenIn,
    uint256 maxAmountIn,
    IERC20 tokenOut,
    uint256 amountOut
) external view returns (uint256 amountIn, uint256 amountRefunded);

function exchangeOutWithRefund(
    IERC20 tokenIn,
    uint256 maxAmountIn,
    IERC20 tokenOut,
    uint256 amountOut,
    address recipient,
    bool pretransferred,
    uint256 deadline
) external returns (uint256 amountIn, uint256 amountRefunded);
```

Use the same accounting invariant as the other new routes: `maxAmountIn == amountIn + amountRefunded`. The preview does not transfer. Execution sends output to `recipient` and accounts for unconsumed input in the same token supplied by the caller. Update the current-function table and preserved-disagreement text to include this surface.

This is the additive fallback correction to the draft. My original preference for replacing canonical Out in a coordinated revision remains recorded below.

### 2. Proposed text, opening compatibility rationale: narrow the categorical ABI claim

Replace the statement that a return-type change “would still break callers that decode the old returndata” with a compatibility-qualified statement. Adding return values changes the declared ABI and is not compatibility-guaranteed, but whether an already-compiled caller rejects additional returndata depends on its decoder. The selector remains unchanged.

The draft can still justify additive functions by implementation and integration migration risk; it should not claim that every old caller necessarily fails. The fact that current hooks call the old functions supports avoiding an uncoordinated replacement, not a universal returndata-decoding result.

## Original disagreements preserved

These are not silently withdrawn by the additive fallback correction above:

1. **Current In/Out replacement.** In “Proposed text” and “Current functions stay as they are,” the draft leaves canonical `previewExchangeIn` / `exchangeIn` and `previewExchangeOut` / `exchangeOut` unchanged. My original recommendation was a coordinated target revision replacing them with refund-returning versions. I still consider that the cleaner final standard because it avoids permanently split canonical and refundable route semantics. The draft explicitly chose the additive alternative.
2. **Bundle-out meaning.** In “Coordinator choices on the ambiguities,” the draft defines `IStandardExchangeBundleOut` as exact-in, with output amounts returned. My original recommendation was exact-output: `tokensOut` and exact `amountsOut` are inputs, `maxAmountIn` bounds the payment, and execution returns actual `amountIn` plus unused-input refund. I preserve that disagreement. The draft has labeled its choice rather than attributing it to the owner.
3. **Bundle-out ordering.** The draft permits caller-selected `tokensOut` order. My original recommendation was a nonempty unique subset in relative `vaultTokens()` order. I still recommend canonical relative order to reduce route representations and simplify validation. This is secondary to the exact-in/exact-out disagreement.
4. **Existing Multi routes.** The draft leaves `IStandardExchangeInMulti` and `IStandardExchangeOutMulti` unchanged. My original recommendation was for the new bundle routes to replace the overlapping ManyToOne and OneToMany routes in the target revision, with legacy surfaces retained only for migration.
5. **Aggregate.** The draft leaves `IStandardExchange` unchanged. My original recommendation was to extend that aggregate with both bundle interfaces. I still prefer one discoverable aggregate for products implementing the complete family, while allowing unsupported routes to revert with their availability errors.

## Supported choices

I support keeping `IStandardExchangeMultiAssetLiquidity` separate, retaining `vaultTokens()` as bundle-input order, using wrapped ERC-20 faces rather than `address(0)`, including pretransfer options, sending output to `recipient` and refunds to `msg.sender`, restricting refund accounting to declared input, and making previews non-transferring refund quotes.

## Limits

This is advisory feedback only. It does not replace the draft, authorize implementation, or represent a new owner decision. No peer feedback, project code, tests, builds, or Git operations were used or changed.
