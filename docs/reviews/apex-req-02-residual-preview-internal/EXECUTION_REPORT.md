# REQ-02 execution report

Date: 2026-10-14. Implemented and verified against the [plan](REMEDIATION_PRD.plan.md)
and [controlling PRD](REMEDIATION_PRD.md), following the owner's request to execute the plan.

`previewResidualBuffer` is now `internal view`. Its direct `previewExchangeIn` body is
unchanged, and `bufferQuotedResidual` remains external. This visibility change is the
only production edit. All four sweep files are byte-for-byte unchanged from HEAD,
including their zero stops, iteration limits, identity returns, and dust comparisons.
The refreshed library's method identifiers exclude `previewResidualBuffer(uint256)`
and retain `bufferQuotedResidual(uint256,uint256)`.

The new `UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol`
inherits the existing gold TestBase and calls its setup. It uses the existing registry
deployment, hook, Standard Exchange, receipt, and fee oracle without replacement.

| Witness | Production entry / reached sweep | Result |
| --- | --- | --- |
| Zero quote | `depositWithSeShares` / `DepositCommon._refundPairDust` | Passed |
| Zero quote | `withdrawSeShares` / `WithdrawalLib.refundPairDust` | Passed |
| Reverting quote | `depositWithSeShares` / `DepositCommon._refundPairDust` | Passed |
| Reverting quote | `withdrawSeShares` / `WithdrawalLib.refundPairDust` | Passed |
| No preview selector | Deployed hook diamond loupe | Passed |

The zero witnesses call the bound receipt's existing `simulateYield` transition to
double its assets without minting receipt shares. They donate `Repo.MAX_DUST_WEI + 1`
pair units to the hook. The bound SE quotes the actual one-unit sweep excess to zero
when called as the hook. Neither chosen parent entry moves pair tokens before the
sweep, so the pre-call excess is the sweep-time excess. Assertions prove exact parent
preview/minimum fulfillment, exact parent SE-share changes, retained pair excess,
and unchanged caller and actual oracle fee-recipient pair balances (including a zero
fee recipient if returned).

The reverting witnesses use an existing arithmetic boundary in the bound
`SimpleYieldERC4626.convertToShares`: its checked `assets * totalSupply` multiplication.
The donated excess is `type(uint256).max / receipt.totalSupply() + 1`. The direct bound-SE
quote reverts with `Panic(0x11)`. Both share-only parent entries then reach that exact
SE quote and receipt conversion, propagate the same panic, and restore hook/caller
pair, raw, SE-share and LP balances and LP supply. Exact call-count expectations
exclude an unrelated earlier failure as the witness. This tests an extreme amount
boundary supported by the unchanged fixture; it does not claim a pause/disable
preview failure or fault the receipt's `balanceOf`.

The monolithic `Target._refundPairDust` is not installed by this TestBase, and
`SeTarget._refundPairDust` has no caller. They remain runtime-unreached as required.
The monolithic Target was explicitly included as a compilation root; SeTarget was
compiled through SeFacet. No new entry or public quote wrapper was added.

Validation completed: **21 passed, 0 failed, 0 skipped** across the five new tests
and sixteen existing deployment tests. All four required behavior cases were reached;
REQ-02's scoped acceptance criteria are satisfied. No full hermetic suite, fork suite,
or live deployment was run.

Commands run from the repository root:

```sh
python3 scripts/forge-artifacts.py build \
  contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol \
  --consumer test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy.t.sol

python3 scripts/forge-artifacts.py test \
  contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol \
  contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol \
  --test-root test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy.t.sol \
  -- -vvv

forge fmt --check test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol
git diff --check
```

The [initial artifact build](evidence/artifact-build.log) compiled 36 changed files
successfully. The first focused command compiled the monolithic Target and new test
successfully, then [Forge crashed](evidence/focused-tests-sandbox-crash.log) in macOS
`system-configuration` proxy discovery before executing tests (exit 250). The identical
focused command was rerun outside the sandbox with approval. It refreshed/verified
artifacts before testing, reused the compiled cache, and [passed all 21 tests](evidence/focused-tests.log)
(exit 0). Formatting passed after correcting one line wrap. Static comparison verified
the four untouched sweeps and visibility-only ClaimLib diff. The existing `out/` and
`cache_forge/` were retained, with `via_ir = false` throughout.
