# Composed preview and transaction gas receipt

Date: 2026-11-07. Source: `17-gas-preview.log`, exit 0; nine tests passed,
zero failed, zero skipped. Each concrete matrix runs
`test_composedRouteGasFitsCeiling` with isolated transactions.

| Configuration | Preview frame gas | Whole router transaction gas |
|---|---:|---:|
| Single wrap/unwrap | 125999 | 647206 |
| Constant-product single | 290594 | 821131 |
| Dual constant product | 474313 | 1080835 |
| Orbital | 470804 | 1202138 |
| Weighted n=2 | 327561 | 856230 |
| Weighted n=3 | 452838 | 978049 |
| Curve quad | 444973 | 939092 |
| Balancer n=2 | 321657 | 873097 |
| Balancer n=5 | 468685 | 1070128 |

The preview is a positive real proxy quote, measured immediately with
`vm.lastFrameGas().gasTotalUsed`, before the router transaction. Each preview
must fit 5,000,000 gas. The isolated router transaction includes calldata
intrinsic gas and must fit 12,000,000 gas. The existing helper requires an
actual increase in the FullSpread share supply. Setup and bootstrap gas are
excluded; the enclosing test gas is not used as transaction gas.

These receipts cover the configured primary provider and mint direction.
They do not close task 17: second-provider gas and redemption-direction
receipts remain outstanding. Same-backing-pool composition remains
unverified. This is not evidence that all facades or requested-share exits
are supported.
