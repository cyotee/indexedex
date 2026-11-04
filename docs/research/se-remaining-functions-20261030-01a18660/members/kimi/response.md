# Kimi member response

## Identity

- Member: Kimi
- Requested Native selection: `kimi-coding/k3.1-pro:high`, global route
- Actual Native identity: not exposed
- Run: `se-remaining-functions-20261030-01a18660`

## Question and targets

For each remaining open full-spread function, recommend whether the family should keep it, drop it, or map it onto an accepted standard function:

1. `previewZapCredit(tokenIn, amountIn)`
2. `previewWithdrawalMode(shares, paired, tokenOut)`
3. `maxZapBps()`
4. `maxZapTickMove()`
5. `wrappedNative()`

The already locked route, refund, paired-money, ERC-5115, rate-asset, and native-face decisions are not reopened.

## Evidence

- `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` leaves exactly these five functions open. It locks `previewExchangeIn` and `exchangeIn` to `(amountOut, amountRefunded)`, accepts the bundle routes, requires stable `vaultTokens()` order with the wrapped face at a native leg, and moves pool-key information to the reusable Uniswap V4 Position Repo rather than keeping a family-only `poolKey()` query.
- The owner lock in `se-interface-refund-bundle-20261030-01a18660/REPORT.md` defines `amountRefunded` as unkept declared `tokenIn`. It does not return per-currency contribution or credit amounts. The accepted bundle previews likewise return route outputs and refunds, not withdrawal-maintenance diagnostics. These routes are nonpayable, use ERC-20 faces, and reject `address(0)`.
- `se-paired-money-necessity-20261030-01a18660/REPORT.md` maps paired exit to `exchangeBundleOut` and its preview to `previewExchangeBundleOut`. It confirms that the wrapper occupies the native leg's stable `vaultTokens()` index and that mapping routes does not change their economics.
- The stage-one PRD is used only for functional context, as the brief permits. S1-API-05 declares all five functions. S1-ACC-07 distinguishes per-currency share credit from uncredited zap residuals. S1-EXIT-01 makes withdrawal maintenance a deterministic preflight choice, not a caller choice. S1-ARCH-03 makes both zap limits immutable instance configuration. S1-NATIVE-01 defines the wrapped native face used at the Standard Exchange boundary.

## Assumptions

- The owner locks and accepted Standard Exchange interfaces control where the older stage-one PRD differs; the stage-one text is not treated as new-family law.
- These recommendations concern the external query surface. Dropping a getter would not remove the underlying cap or maintenance behavior.
- Uncredited residual and same-token refund are not assumed to be interchangeable accounting categories.
- No raw-ETH extension, new Position Repo API, implementation, or PRD lock is proposed.

## Coverage

| Function | Evidence considered | Surface question decided |
| --- | --- | --- |
| `previewZapCredit` | Refund owner lock; zap credit and residual definitions | Whether a same-input refund replaces the per-currency credit split |
| `previewWithdrawalMode` | Accepted withdrawal previews; deterministic maintenance selection | Whether callers need a separate internal-mode query |
| `maxZapBps` | Immutable configuration and entry/compound cap context | Whether to expose the size cap separately from route previews |
| `maxZapTickMove` | Immutable configuration and entry-swap tick cap context | Whether to expose the tick-movement cap separately from route previews |
| `wrappedNative` | Stable `vaultTokens()` faces; Position Repo ownership of pool identity | Whether a separate family or Position Repo wrapper getter is necessary |

## Conclusions

### 1. `previewZapCredit(tokenIn, amountIn)` — **Recommendation: keep**

Keep it as a family accounting preview, not as another deposit route. The accepted `previewExchangeIn` returns the quoted shares and `amountRefunded`, but that refund is only unkept input denominated in the caller's original `tokenIn`. It does not return how much of each currency funds those shares or a per-currency uncredited residual.

Therefore, the refund return does **not** replace the credit split. It overlaps only the single-input unkept-amount concern; it cannot represent the two-currency attribution that `previewZapCredit` exposes. The standard preview remains the ordinary route quote, while this family query explains the zap's share-credit accounting.

### 2. `previewWithdrawalMode(shares, paired, tokenOut)` — **Recommendation: drop**

Drop the public query. Full compounding versus collection-only maintenance is a deterministic internal plan, not a choice the caller supplies or can use to select a different route. For a caller's economic decision, `previewExchangeBundleOut` is sufficient for paired withdrawal and `previewExchangeIn` is the accepted single-token exact-input preview.

This is a drop rather than a map: neither accepted preview returns the maintenance mode or reason, and no single accepted function covers both the paired and single-token forms. Dropping the query deliberately gives up that standalone diagnostic detail; it does not remove the maintenance selection or require removing any execution event.

### 3. `maxZapBps()` — **Recommendation: keep**

Keep the getter as immutable family configuration discovery. It lets integrators determine the configured single-token entry and compound-swap size constraint without inferring it from rejected quotes. No accepted Standard Exchange function returns this cap.

The cap remains enforced regardless of this recommendation. Keeping the getter is only about discoverability; dropping the getter would not be a decision to drop the cap.

### 4. `maxZapTickMove()` — **Recommendation: keep**

Keep the getter as separate immutable family configuration discovery. It exposes the entry-swap tick-movement bound, which is distinct from the amount-based `maxZapBps` cap and is not returned by any accepted route preview.

As with `maxZapBps`, this recommendation does not create or remove the underlying guard. It retains visibility into a cap that otherwise could be learned only through deployment data or failed quotes.

### 5. `wrappedNative()` — **Recommendation: map to `vaultTokens()`**

Do not keep a separate family selector and do not move this getter to the Position Repo. The accepted nonpayable routes already consume the ERC-20 faces exposed by `vaultTokens()` in stable PoolKey order, with the wrapped face at the native leg's index. Pool and native-leg identity belongs with the position information, not with a second wrapper query on the full-spread family.

The mapped `vaultTokens()` function does **not** return a standalone wrapper address or explicitly identify which entry is the native alias. A caller that needs that distinction uses the position's pool identity together with the stable token order. For an ERC-20-only pool, no native wrapper face is needed.

## Limits

This is a research recommendation only. It does not edit or lock the PRD, authorize implementation, define new interfaces, or change any accepted route economics. No peers were read, and no code, tests, builds, deployments, or external searches were used.
