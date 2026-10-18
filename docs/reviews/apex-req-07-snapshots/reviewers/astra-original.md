# Astra — REQ-07 snapshot ownership and lifetime

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass over this repository's `contracts/`. No other reviewers' notes were read. No code or controlling PRD was edited.

## Answer to the owner

**IndexedEx vaults do build snapshots for quoting, and hooks request and pass those snapshots during a call. I found no production vault or hook storing the REQ-07 opaque quote-state bytes in contract storage.** These are different propositions: retaining a persistent historical snapshot is not what the inspected quoting code does.

**The current `StandardExchangeRateProviderFacet` does not call `quoteState` or read `gasleft()` in its empty-state path. No implementation gap** was established in the specific REQ-07 empty-state behavior inspected here. Its ordinary rate call reads live supply and invokes the ordinary preview. A caller-supplied projected state remains a separate supported path.

The reason for the ephemeral snapshots is to quote a sequence of operations against one evolving simulated state: an unwrap changes a holder's shares, a deposit can change supply/fees, and a later swap or join must be quoted against those changes rather than repeatedly reading the unchanged live chain. Some hooks also project a PoolManager-unavailable context so previews reflect what settlement can do while that manager is already unlocked. Those uses are not a persisted cache and are not the removed rate-provider self-snapshot behavior.

## Access/attribution limitation

The attempted fresh read of `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` at OD-02 returned **`[RC_ATTRIBUTION] active call attribution failed; report the failure, do not bypass it`**. I did not retry via another tool/path or otherwise bypass that denial. That document, including OD-02 and REQ-07, had already been read in full earlier in this session: it distinguishes ordinary live-rate calls from caller-supplied snapshots and does not require deleting vault transition quotes. A fresh document-state verification was unavailable for this pass. The current code findings below come from successful direct source reads and scoped searches, not peer conclusions.

## 1. Persistent storage: no quote-state byte cache found

The relevant declarations are memory objects or calldata inputs, not persistent snapshot fields:

- `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:41–47` declares `ExternalQuote.state`, but its builders return **`ExternalQuote memory`** at **50–75**. The actual reusable storage `Layout` at **29–35** contains token/address membership and mapping configuration, not snapshot bytes.
- Dual `DepositQuoteLib.sol:19–30,96–103` carries `Leg.state` in **memory**. Orbital `ExitQuoteLib.sol:16–38,50–70` likewise carries `Leg[3] memory` and returns a memory leg.
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol:15–31,37,60,66` contains nested `vaultState` bytes inside a **memory** `QuoteState`; it ABI-encodes and returns them, and later decodes input bytes into memory.
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolLiquidationLib.sol:28–40,57–78` includes nested `poolState`/`weightedState` bytes in a **memory** `PoolQuoteState` returned by its view snapshot function.
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderRepo.sol:19–25` stores only reserve vault, rate subject, rate target and target decimals. There is no snapshot field.

Scoped searches covered `quoteState` calls, encoded-selector calls, bytes-bearing structs/state declarations, storage-reference uses and Repo snapshot fields. No production assignment of these quote-state bytes to persistent vault/hook storage was found. Merely declaring `bytes state` inside a struct does not make instances storage-backed.

Do not confuse other stored values with REQ-07 snapshots: the single-CP/dual Repo comments call configured decimal counts “snapshots”; booked reserves are normal accounting state. FullSpread hookless/Pons execution-context Repos use transient storage for managers, flags, budgets, plan identifiers and liabilities (e.g. their **23–27,73–75,103**), not retained encoded quoteState bytes. Test/harness callback payload storage also exists under `contracts/`; it is not a deployed vault snapshot cache.

This is a source-search conclusion about the specified opaque snapshots, not a proof that no arbitrary encoded state can ever be persisted through every assembly or dependency path. Scope excludes code under `lib/` except previously read canonical guidance, and no chain storage was inspected.

## 2. Ephemeral snapshot production and consumption

### Concrete vault examples: where the bytes are built

- **V3 FullSpread:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol:43–60`. `quoteState` creates `InventoryQuote memory`, reads supply, holder shares, free balances, collectable fees, position liquidity, ticks and live pool price/liquidity, then returns `abi.encode(q)`. The state is an input to projected transitions, not written back as a book snapshot.
- **V4 hookless FullSpread:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultOutQueryTarget.sol:20–24`. `_inventorySnapshot(asset, holder)` returns a memory quote; `quoteState` encodes it and computes the holder claim. The Pons sibling has its own same public builder at `fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookOutQueryTarget.sol:20` (located by source search).
- **Wings:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultTransitionTarget.sol:14–16`. `Projection.snapshot` produces a memory state and returns its encoded form. At **23–34**, supplied calldata is decoded, projected and re-encoded; unavailable-manager context changes `q.blocked` in memory, not the vault's stored context.
- **Generic ERC-4626 SE, including nesting:** `contracts/vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol:33–60`. It builds its own memory quote; **47–49** first models an IERC4626 virtual/ratio snapshot. If that representation is unavailable, **52** calls the underlying vault's `quoteState`, stores the returned bytes in `q.vaultState` **in memory**, and returns the enclosing encoding. Its sequential `quoteTransition` at **63–125** models deposits/redemptions and fee/supply changes without performing those operations.
- **Balancer pool SE:** `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTransitionQuoteTarget.sol:161–167` builds and encodes `Liquidation.PoolQuoteState memory`. The helper `BalancerV3PoolLiquidationLib.sol:57–78` reads pool data, rates, fees and supply; it obtains nested pool quote bytes at **75** or a weighted snapshot at **78**. These are temporary liquidation simulations.

### Additional quoteState producer entrypoints found

These are implementations/declarations of the snapshot API, **not evidence of storage retention**. Paths are relative to `contracts/`; declaration sites were identified by scoped source search:

| Family | Producer entrypoint |
|---|---|
| Rebasing custody SE | `protocols/staking/rebasingVault/RebasingAwareStandardExchangeQuoteTarget.sol:29` |
| Rocket Pool | `protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeInTarget.sol:144` |
| Lido | `protocols/staking/lido/LidoWstETHStandardExchangeInTarget.sol:194` |
| EtherFi | `protocols/staking/etherfi/EtherFiWeETHStandardExchangeInTarget.sol:133` |
| Camelot V2 | `protocols/dexes/camelot/v2/CamelotV2StandardExchangeQuoteTarget.sol:32` |
| Uniswap V2 | `protocols/dexes/uniswap/v2/UniswapV2StandardExchangeQuoteTarget.sol:31` |
| Aerodrome | `protocols/dexes/aerodrome/v1/AerodromeStandardExchangeQuoteTarget.sol:42` |
| Aave Stata | `protocols/lending/aave/v3.6/AaveV3StataStandardExchangeInTarget.sol:115` |
| Aave cross-version loop | `protocols/lending/aave/cross-version/AaveCrossVersionLoopStandardExchangeTransitionQuoteTarget.sol:58` |
| Morpho Blue | `vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeQuoteTarget.sol:32` |

These additional producer bodies were not all individually audited in full. Facet entries listing `quoteState.selector` expose the API; they do not themselves execute snapshot calls.

### Direct production calls to quoteState found

All paths below are relative to `contracts/`. The identified non-test direct call sites, including the encoded staticcall probe, are:

| Caller | Lines | Why / lifetime |
|---|---|---|
| `vaults/standard/erc4626/ERC4626StandardExchangeQuoteTarget.sol` | **52** | Nested receipt-vault state inside the wrapper's memory quote, described above. |
| `hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol` | **47,57** | Build an opaque memory snapshot, optionally project unavailable-manager context; exact-output quotes use a projection only when context changes. |
| `hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol` | **55,75** | External exchange/deposit projection, preserving holder inventory while simulating prior issuance, fees and subsequent intake. Returns memory `ExternalQuote`. |
| `hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol` | **257** | Project a deposit's before/after rated holder claim; next-state rate can change with SE fees. |
| `hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol` | **100** | Load each memory leg; subsequent ReceiveShares/redeem/swap/deposit projections use updated states rather than rereading the unchanged live book. |
| `hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookInQuoteBase.sol` | **125** | Project proportional redemption before quoting residual exchange; leg state is returned in memory. |
| `hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol` | **62** | Snapshot each buffered leg, project pro-rata withdrawals and residual swaps in a memory array. |
| `hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase.sol` | **115** | Share-input zap begins with SE state, forwarded to the memory share-zap projection. |
| `hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol` | **37,191,580** | Respectively: zap-state projection; redemption-before-residual-swap plan; before/after rated claim for a buffer deposit. |
| Same single-CP ClaimLib | **490,497** | Support/quotability probes. The direct result or staticcall reply is checked/discarded, not retained in storage. |

All directly inspected materializing calls above use memory states or memory structs. The two probes are called out separately because they request a snapshot without passing it onward as a retained quote.

### Indirect callers of the shared snapshot helpers

The shared ContextQuote library centralizes acquisition. Its `rate` at **25**, `deposit` at **95**, `redeem` at **105**, `redeemReceived` at **116**, `withdraw` at **127**, and `inputForShares` at **139** invoke `snapshot`; all are view calculations with memory bytes. `project` at **40** passes those bytes to `quoteStateWithUnavailableUnlock`. `rateFromState` at **18–21** forwards a memory quote to LegLib.

The following wrapper call sites were found by scoped search. They are additional **indirect** ephemeral acquisition/forwarding sites, not additional storage caches. Prefix for the family rows is `contracts/hooks/uniswap/v4/standardExchange/`:

- **Single non-CP:** `single/UniswapV4SingleStandardExchangeBufferHookTarget.sol:265,270,275,280` calls context-aware deposit/exact-share/redeem/withdraw quoting.
- **Single CP:** ClaimLib **268,282,290,344** requests snapshot/exact-output state; DepositProjectionTarget **66,75,100** invokes LegLib external exchange/deposit projection.
- **Dual:** ClaimLib **41,94,101,108** requests exact-output state or snapshots.
- **Orbital:** ClaimLib **145,161,420,427,430,438–439** obtains context-aware state/rates or deposit/redemption projections; Common **774** requests an external-exchange projection; ExitQuoteLib **195,209** requests external-deposit projection.
- **Weighted:** ClaimLib **152,157,174,183,186,260,279** obtains context-aware rates, deposit/redemption or exact-output snapshots; JoinQueryTarget **16** and HooksTarget **378,389** request external-deposit/exchange projection.
- **Balancer quad:** ClaimLib **98,101,118,127,130,153,166** obtains the analogous context-aware rates/quantities.
- **Curve quad:** ClaimLib **218,221,237,246,249,272,285** obtains context-aware rates/quantities; JoinQueryTarget **30** and HooksTarget **405,416** request external-deposit/exchange projection.

Each short family filename above has the existing family-specific `UniswapV4...BufferHook` prefix; the searches identified these within the named family directory, not in deleted legacy code. Wrapper sites were mapped by source search; central helper bodies and direct materializing calls were read to establish memory lifetime and forwarding semantics.

The crucial rate-forwarding site is `contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol:133–149`: a supporting provider receives `quoteRate(exchange, pair, q.state)` at **144**. Otherwise it gets ordinary `getRate()` at **145**. This is why the provider still accepts a nonempty supplied state: the hook may already have advanced that state through a simulated operation.

## 3. Rate-provider self-snapshot: absent from current ordinary path

`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` was read in full:

- **45–46:** `getRate()` calls `_getRate("")`.
- **61–68:** empty state selects the subject's live `totalSupply()`. Nonempty supplied state selects `quoteTotalSupply(state)` instead.
- **79–82,112–125:** ordinary full-book valuation uses `previewExchangeIn`; supplied-state valuation uses `quoteAssets(state, amount)`. The existing exact-return-length handling is retained. It does not retry a failed supplied-state quote using the live path.
- **98–109:** zero-supply initialization uses an ordinary unit-deposit preview, not quoteState.
- **49–58:** `quoteRate` accepts state only for the matching configured exchange/asset/subject. An unrelated subject deliberately uses the live rate; that is subject discrimination, not a fallback after a failed matching snapshot.

A scoped search of the current rate-provider tree found **no `quoteState`, `gasleft` or snapshot references**. The facet directly contains no such call and its Repo stores configuration only. An ordinary preview implementation may internally build a temporary pricing model; that does not mean this rate provider is taking the former gas-gated self-snapshot.

Thus the previously specified empty-state behavior is present. The source does not support a claim that ordinary `getRate()` is still taking and keeping the disputed snapshot. Conversely, removing every caller-supplied snapshot would remove different current functionality, not complete the stated REQ-07 repair.

## Test code under contracts/ and evidence limits

The search also found calls under `contracts/test/bases/`, `contracts/test/stubs/`, protocol TestBases and DETF TestBases. These include FullSpread work-limit, transition lifecycle, rate-context, unlock-context and funding regression helpers, plus quote fixtures. They are test infrastructure, not production vault storage. The raw `quoteState(` search returned 77 matches in 41 files, including declarations and these tests; that number must not be presented as 77 production snapshot acquisitions.

Some unrelated bytes fields hold callback/router payloads. No inference of a vault snapshot cache is made from those names. The storage searches and call-site mapping are defensive static analysis, not an executed storage trace or an exhaustive semantic proof across arbitrary dynamically encoded calls. No external source or library documentation lookup was needed to explain these repository-specific paths.

## Findings and disposition

**No implementation gap** found in the current rate-provider empty-state snapshot/gas behavior. No production snapshot-byte persistence defect was established. There is no proposed code change, blanket snapshot deletion or new product rule. Existing ephemeral transition quotes explain why vaults “take snapshots” without “keeping snapshots.”

Files directly examined without a scoped defect: the rate-provider facet and Repo; ContextQuoteLib and LegLib; generic ERC-4626 quote target; V3 query target; hookless query target; wings transition target; Balancer transition/liquidation snapshot builders; and the single-CP, dual and orbital direct consumer ranges listed above. Other producer/wrapper entries are identified search sites, not individually certified implementations. The controlling-text attribution denial is explicitly recorded above; it was not bypassed. The assigned report was absent before this write.

Only this assigned Markdown report was created. No code, tests, PRD, configuration or instruction file was edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
