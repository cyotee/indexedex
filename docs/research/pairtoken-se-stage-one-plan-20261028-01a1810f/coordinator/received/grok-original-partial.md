# Grok planning contribution: partial archival receipt

Source: already-completed initial task `st_01a18422`, supported task_output transcript. The reader elided 29,081 characters; the marker below is retained. A same-task no-tool verbatim recovery failed with provider HTTP 403. No provider retry or model substitution was attempted. This is NOT a complete original and missing material is not inferred.

---

# Identity

Grok, independent Native council planning member. Requested route: `xai/grok-4.7:xhigh`. This is an implementation and testing contribution only. It does not replace the PRD, authorize implementation, or open an advisory round.

# Inputs and coverage

Read completely: the run brief and `inputs/PRD.md` through section 12, including S1-D01–D05, S1-P01–P06, S1-X01–X19, S1-ACC-01–07, S1-OP-01–05, S1-EXIT-01, S1-NATIVE-01, S1-API-01–05, S1-QUOTE-01–02, S1-PKG-01, S1-SEC-01–02, S1-OBS-01, S1-A01–A70, and S1-TEST-01. The supplied SHA-256 was not recomputed.

Read for concrete reuse, not as economic authority: `CLAUDE.md`; `.github/ASSISTANT_RULES.md`, `ASSISTANT_CODING.md`, `ASSISTANT_DEPLOYMENT.md`, `ASSISTANT_TESTS.md`; `.claude/skills/indexedex-testing/SKILL.md`; Crane facet/package/testing law as stated in `lib/crane/AGENTS.md`; `PairToken.sol`, `PairTokenMath.sol`, `IPairTokenDependencies.sol`; `PairTokenTestBase.sol` and the public `ScriptedDependencies.sol` API; `LocalCreditLib.sol`; `IStandardExchangeIn`, `IStandardExchangeOut`, `IStandardExchangeErrors`, `IStandardExchange`; `IBasicVault`, `IStandardVault`, `IStandardVaultPkg`, `IVaultRegistryDeployment`; the five reused facet/repo entrypoints used below; native SY money, discovery, and preview targets; Wings package and `TestBase_UniswapV4UpperLowerWingsStandardExchangeVault` as packaging only; Crane `Pool.swap` / `Pool.State`, `StateLibrary`, `TransientStateLibrary.isUnlocked`, `TickMath.minUsableTick` / `maxUsableTick`, `TickBitmap.nextInitializedTickWithinOneWord`, `Position.update`, `SqrtPriceMath`, `AddressSetRepo._add`, `StandardVaultRepo._initialize`, `ERC20Repo._initialize`, `EIP712Repo._initialize`, `calcContentsId`, `docs/testing/ARTIFACT_BUILDS.md`, Crane `IWETH` alias, and `DiamondPackageCallBackFactory` base-facet init.

Not read, and not evidence: peer originals, prior council reports, private memory, Sourcify, or an external PairToken reconstruction. No file was written. No test, build, forge, or git command was run. `docs/agent/INDEXEDEX_AGENT_LAW.md` was not read line by line; the plan uses the PRD plus the router and testing-skill statements of registry path, token policy, and production-first law. `PoolManager.modifyLiquidity`'s return packing and the diamond proxy `receive` body were not line-read; both are explicit gates below, not silent assumptions.

Settled choices used as fixed: one full-range position, one 18-decimal share supply, no dead shares, no retention, no vault protocol fee, caller-attributed issuance, paired residual credit, zap uncredited residual, full compound plus a final fee checkpoint, withdrawal-only conditional collection fallback, native and wrapped faces, exact-output unsupported, spot SY rate with one-floor conversion, five reused facets, factory facets excluded from package cuts, 512 steps per candidate, at most two withdrawal candidates.

# File/component map

All new paths are proposed. None exist for this family.

Proposed root: `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/`.

| Proposed file | Role |
| --- | --- |
| `interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol` | `PkgInit` and `PkgArgs` live here, not on the contract. |
| `interfaces/IUniswapV4PairTokenStandardExchangeVault.sol` | Family ABI, enums, events, enumerated errors, plus the one rate-overflow error in Blockers. |
| `UniswapV4PairTokenStandardExchangeVaultRepo.sol` | ERC-1967 family slot only. |
| `UniswapV4PairTokenLedgerLib.sol` | Disjoint custody categories. |
| `UniswapV4PairTokenIssuanceLib.sol` | Genesis quote, paired `qQuote`, S1-ACC-07 credit. |
| `UniswapV4PairTokenMaintenanceLib.sol` | Baseline compound sizing and fallback classification. |
| `UniswapV4PairTokenValueLib.sol` | S1-QUOTE-02 single-floor conversion. External, CREATE3-linked. |
| `UniswapV4PairTokenProjectorLib.sol` | Memory pool overlay and candidate planner. External, CREATE3-linked. |
| `UniswapV4PairTokenSettlementLib.sol` | Canonical `BalanceDelta` settlement and native sync reset. |
| `UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol` / `QueryFacet.sol` | Family views, paired previews, mode, zap-credit preview. |
| `UniswapV4PairTokenStandardExchangeVaultExecutionTarget.sol` / `ExecutionFacet.sol` | Paired money, `compound`, `donate`, all four SE selectors. |
| `UniswapV4PairTokenStandardExchangeVaultCallbackTarget.sol` / `CallbackFacet.sol` | `unlockCallback` only. |
| `UniswapV4PairTokenStandardExchangeVaultSYTarget.sol` / `SYFacet.sol` | Sixteen SY methods. Inherits shared SY abstracts and overrides native rejection. |
| `UniswapV4PairTokenStandardExchangeVaultDFPkg.sol` | Registry package. |
| `UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService.sol` | CREATE3 deploy of the four family facets through `ArtifactCreationCode`. |
| `test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol` | Real PoolManager, registry, facets, package. Next to the package, Wings layout. |
| `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken/` | Acceptance specs. |

`PkgInit`, named fields, no open-ended facet array: `erc20Facet`, `erc2612Facet`, `erc5267Facet`, `basicVaultFacet`, `standardVaultFacet`, `queryFacet`, `executionFacet`, `callbackFacet`, `syFacet`, `poolManager`, `registry`, `oracle`, `wrappedNative`. Cuts are exactly those nine addresses, in that order. A factory facet cannot be inserted without an interface change.

`PkgArgs`: `poolKey`, `rateAsset`, `name`, `symbol`, `maxZapBps`, `maxZapTickMove`. No defaults. `maxZapBps` must satisfy `0 < maxZapBps <= 10000`. `maxZapTickMove >= 0`. The `int24` type is the representable bound.

Family slot: `bytes32(uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.pairToken"))) - 1)`. Do not use Wings storage or PairToken's linear layout.

Repo state: `initialized`, manager, key, bound wrapper, `rateAsset`, cached decimals, `tickLower`, `tickUpper`, zap parameters, `booked0`, `booked1` in raw pool units, guard, callback commitment, and the four reservation pairs. Shared basic-vault reserves are a published snapshot of `booked`, written under the wrapped face for a native leg, never a fifth category.

Reuse unchanged:

- `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol` and `ERC20Repo._initialize(name, symbol, 18)`.
- `lib/crane/contracts/tokens/ERC2612/ERC2612Facet.sol` and `ERC2612Repo`. Nonces stay at zero.
- `lib/crane/contracts/utils/cryptography/ERC5267/ERC5267Facet.sol`.
- `EIP712Repo._initialize(name, "1")`. Verifying contract is the diamond.
- `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` and `MultiAssetBasicVaultRepo`. `_add` appends, so initialize `[C0, C1]` and never call `_sortAsc` on that set.
- `contracts/vaults/standard/MultiAssetStandardVaultFacet.sol` and `StandardVaultRepo._initialize(oracle, bytes32(0), dedupedInterfaceIds, contentsId)`.
- `contracts/utils/LocalCreditLib.sol`.
- `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` and its discovery, preview, money, and rewards parents. Override in the family SY target. Do not edit the shared files.
- Crane V4: `IPoolManager`, `PoolKey`, `Currency`, `BalanceDelta`, `StateLibrary`, `TransientStateLibrary`, `TickMath`, `SqrtPriceMath`, `SwapMath`, `LiquidityMath`, `ProtocolFeeLibrary`, `LPFeeLibrary`, `PoolIdLibrary`, `Position` fee formula. Not the baseline's simplified `IPoolManager`.
- `lib/crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol`, the alias of Balancer `deposit()` / `withdraw(uint256)`.
- `PairTokenMath.sqrt`, `MD`, and `MU` only where the sections below name them.
- `IndexedexTest`, `ArtifactCreationCode`, `indexedexManager.deployPkg`, package `deployVault` to `registry.deployVault`.

Do not install `ERC20PermitFacet`, empty `StandardVaultTarget`, Permit2, Wings economic or rebalance facets, a second ERC-20, or any factory facet. Factory-owned persistent surface, from `DiamondPackageCallBackFactory` `InitArgs`, is ERC-165, DiamondLoupe, and ERC-8109. The temporary post-deploy hook is factory-owned and must be gone after `postDeploy`. Do not recut those.

Initialization ownership is package `initAccount`, delegatecall on the proxy only. It validates, sets the family initialized flag, then calls the four shared repo initializers and the family repo. It does not write factory introspection, permit nonces, or reserves. `processArgs` is registry-only and repeats validation. `postDeploy` and `updatePkg` return true and write nothing. `vaultFeeTypeIds()` is `bytes32(0)`. Contents id is `keccak256(abi.encode(sortedCopy([C0, C1])))`, matching `calcContentsId`. Stored token order stays PoolKey face order.

Package salt is `keccak256(abi.encode(pkgInit))`, not a constant Wings-style salt. CREATE3 ignores init code, so a constant salt would not move the package when bindings change. Instance salt is `keccak256(abi.encode(pkgArgs))`. The factory's package-in-salt behavior must be asserted, not assumed: same init and args predict the same vault; each `PkgArgs` field and each binding field moves the address.

`C0` is `wrappedNative` when `currency0` is `address(0)`, otherwise `currency0`. `C1` is `currency1`. Reject `C0 == C1`, which excludes a native/that-wrapper pool. Reject a pool currency equal to the proxy inside `initAccount`.

Code-size strategy, in this order, with no `via_ir` and no `foundry.toml` edit: external-link `ProjectorLib` and `ValueLib` through the `ArtifactCreationCode` CREATE3 overload that honors link references; keep Execution methods as wrappers so all four SE selectors stay on one facet and that facet can honestly declare `IStandardExchangeIn` and `IStandardExchangeOut`; if a facet still exceeds 24576 bytes, split Query into discovery and preview before any compiler-setting change. Selector splitting of one declared interface across two facets is not allowed. `unlockCallback` lives only on the callback facet, under a one-function callback interface, so the family interface does not have to claim it.

# Implementation stages

Stages are ordered. A later stage does not start until the prior stage's exit evidence exists. No stage may change a settled equation to make a test pass.

## Stage 0 — three reads before coding

1. Read the diamond proxy `receive`. Empty calldata must hit the proxy `receive` and not delegatecall. If it delegatecalls, stop. Do not add a facet `receive` to paper over it. That is Blocker B1.
2. Read Crane `PoolManager.modifyLiquidity` and record the real `(callerDelta, feesAccrued)` `BalanceDelta` identity. The PRD requires `callerDelta = principalDelta + feesAccrued`. Implement that subtraction with Crane delta arithmetic. If the port's signs cannot express it, stop and cite the function. Do not reuse the baseline's packed `int256`.
3. Read the disable-query facet beside `VaultRegistryDisableManagerTarget.setVaultAddressDisabled` and call that existing view. Do not add a family disable flag. Bind `IVaultFeeOracleQuery` to the live oracle object `IndexedexTest` already uses for standard-vault init. In the Wings fixture that object is `indexedexManager`. Store it, and store fee-type ids as zero. Do not copy Wings' `VaultTypeUtils._insertFeeTypeId` usage.

Exit: a short note in the implementation report, or a stop on B1 or a delta-identity contradiction.

## Stage 1 — interfaces and manifest skeleton

Define enums `WithdrawalMode { FullCompound, CollectOnly }` and `MaintenanceReason { None, MaintenanceWorkLimit, MaintenancePriceLimit, MaintenanceLiquidityLimit, MaintenanceDeltaLimit }`.

Family methods are exactly the S1-API-05 signatures: `depositPair`, `previewDepositPair`, `redeemPair`, `previewRedeemPair`, `donate`, `compound`, `poolManager`, `poolKey`, `wrappedNative`, `rateAsset`, `tickLower`, `tickUpper`, `positionLiquidity`, `localReserves`, `basket`, `maxZapBps`, `maxZapTickMove`, `previewWithdrawalMode`, `previewZapCredit`.

Events: `WithdrawalMaintenanceSelected(uint8 mode, uint8 reason)` once per successful withdrawal; `ZapCredit` with actual input, credit pair, residual pair, and minted shares; family paired deposit, paired redeem, dona
...[elided 29081 chars]...
incipal. |
| A25 | `PairTokenSE_Routes.t.sol` | Four exact-input routes execute. Currency-to-currency, share-to-share, identical currency, and foreign tokens revert `InvalidRoute`. |
| A26 | `PairTokenSE_Routes.t.sol` | Both exact-output selectors exist, revert `ExchangeOutNotAvailable`, and leave balances, supply, and pool state unchanged. |
| A27 | `PairTokenSE_PreviewParity.t.sol` | Each SE and paired preview equals execution from the same state, including fees, a tick crossing, compound, and a terminal exit. Preview itself does not move the pool. |
| A28 | `PairTokenSE_PreviewParity.t.sol` | Library control reports 512 and 513. Vault preview and execution agree on success and on `QuoteWorkExceeded`. Withdrawal full-candidate failure does not change the original price seen by collection-only. No partial quote. At most two candidates. |
| A29 | `PairTokenSE_SY.t.sol` | All sixteen SY selectors are installed. SY execution equals SE for the same route. `yieldToken` is the diamond. No second receipt token. |
| A30 | `PairTokenSE_SY.t.sol` | Internal-balance redeem rejects a code-less caller and a short vault-held balance. False-flag burns the caller. Invalid token preview is zero. Invalid native value reverts. |
| A31 | `PairTokenSE_SY.t.sol` | Reward views are empty. `claimRewards` emits an empty canonical event. A later exit still pays the compounded fees once. |
| A32 | `PairTokenSE_Value.t.sol` | `floor(Vraw * 1e18 / S)` for 6, 8, and 18 decimal assets. `syToAsset` returns raw units. The single-floor oracle matches. No required gap versus rounded exit proceeds. |
| A33 | `PairTokenSE_Value.t.sol` | Zero supply returns rate zero. Genesis shares are the geometric mean, not a 1:1 rate mint. |
| A34 | `PairTokenSE_Credit.t.sol` | False-flag short delivery reverts. Pre-existing reserves do not fill it. An unrelated transfer is not this input. |
| A35 | `PairTokenSE_Credit.t.sol` | True-flag from a code-less caller and from a constructor reverts `EOAPretransferNotAllowed`. |
| A36 | `PairTokenSE_Credit.t.sol` | True-flag with no unbooked credit reverts `TransferDeltaInsufficient` and does not spend booked backing. |
| A37 | `PairTokenSE_Credit.t.sol` | Excess pretransfer processes the declared amount, refunds nothing, and leaves the excess unbooked. |
| A38 | `PairTokenSE_Credit.t.sol` | `donate` increases booked reserves and not supply. Unsolicited balances survive compound, entry, exit, and restart. |
| A39 | `PairTokenSE_CallbackGuard.t.sol` | Real manager callback succeeds. Wrong manager, unsolicited payload, replay, and a cross-facet reenter revert. |
| A40 | `PairTokenSE_CallbackGuard.t.sol` | A call started while the manager is unlocked reverts `ManagerAlreadyUnlocked` before a nested `unlock`. No local-sleeve execution. |
| A41 | `PairTokenSE_Reconcile.t.sol` | After every operation, manager position, token custody, booked reserves, supply, and event amounts match. |
| A42 | `PairTokenSE_Disable.t.sol` | Disabled vault reverts issuance and donation with `IssuanceDisabled`, allows `compound`, and still exits with the same fallback rules. |
| A43 | `PairTokenSE_Rollback.t.sol` | Payout failure and unmet minima restore shares, pool liquidity, and token balances from the pre-call snapshot. |
| A44 | `PairTokenSE_DecimalsFoT.t.sol` | A 6/8/18 pool completes paired entry and exit. A real FoT pull does not mint shares for the gross amount. |
| A45 | `PairTokenSE_Bounds.t.sol` | Interior, both boundaries, and outside-range amounts equal manager receipts. Capacity and signed-delta failures select fallback only on withdrawal maintenance. No silent clamp. |
| A46 | `PairTokenSE_SequenceInvariant.t.sol` | Handler sequence: supply conservation, no unbooked adoption, donation without mint, per-leg non-dilution, and exact pre-sale exit allocation. Price and fee effects are reported separately. |
| A47 | `PairTokenSE_Package.t.sol` | Two vaults share facets. Operations, approvals, position keys, and init on one leave the other unchanged. |
| A48 | `PairTokenSE_Size.t.sol` | `extcodesize` of every new facet, library, and package is at most 24576. Build uses the edited artifacts. Fuzz and invariant depth are untouched. No `via_ir`. |
| A49 | `PairTokenSE_Native.t.sol` | Native genesis and deposit require `msg.value == amount0Max`, exclude it from pre-entry compound, and refund only the unused part. Wrong value and refund failure roll back. |
| A50 | `PairTokenSE_Native.t.sol` | Equal states produce equal share and payout amounts for native SY and wrapped SE. Only the delivered token differs. |
| A51 | `PairTokenSE_Native.t.sol` | Real registered diamond settles native debt, accepts wrapper ETH, and never calls ERC-20 on `address(0)`. |
| A52 | `PairTokenSE_Native.t.sol` | Forced ETH, pending value, refunds, and temporary wrapped balances are not a second reserve and not free deposit credit. |
| A53 | `PairTokenSE_Native.t.sol` | A rejecting receiver and a reentrant receiver roll back. A receiver using more than 2300 gas succeeds. |
| A54 | `PairTokenSE_Native.t.sol` | Last native paired exit zeros booked ETH, booked token, and owned liquidity. Rebootstrap leaves old unbooked ETH unbooked. |
| A55 | `PairTokenSE_Native.t.sol` | Native and wrapped donations credit the same reserve once. Wrong `msg.value`, native donate on an ERC-20 pool, and `address(0)` on standard SE revert. |
| A56 | `PairTokenSE_Facets.t.sol` | The five reused facets contribute exactly 20 selectors: 9, 3, 1, 3, 4. No `ERC20PermitFacet`, no duplicate token or SY selector, and no factory facet in inputs, addresses, or cuts. |
| A57 | `PairTokenSE_Facets.t.sol` | Factory ERC-165, loupe, and ERC-8109 work without package cuts. The temporary hook is absent after deploy. Permit nonce, replay, and domain isolation work. Shared repo init is per proxy. |
| A58 | `PairTokenSE_Package.t.sol` | Wrapper address sorts after the other face. Registry hash uses the sorted copy. `vaultTokens` and reserves stay PoolKey order. |
| A59 | `PairTokenSE_CallbackGuard.t.sol` | During a callback, family economic reads revert, basic reserves return the last snapshot, and token and domain reads keep canonical behavior. |
| A60 | `PairTokenSE_Native.t.sol` | After an ERC-20 sync, native debt syncs `address(0)` before value settlement and closes the native delta. Empty-calldata ETH does not enter a family facet. |
| A61 | `PairTokenSE_Fallback.t.sol` | Each of the four reasons has a real-manager case or a written unreachable-domain proof. Preview, event, and execution agree. A valid full candidate wins over collection-only. |
| A62 | `PairTokenSE_Fallback.t.sol` | Manager, token, wrapper, custody, fee-collection, state-change, and payout failures are not converted to collection-only. A failed second candidate does not leave a partial compound. |
| A63 | `PairTokenSE_Fallback.t.sol` | A tight user minimum or an unsellable final leg does not change maintenance mode. `previewWithdrawalMode` uses `tokenOut == address(0)` for paired output and the boolean to separate that from single-token ETH. |
| A64 | `PairTokenSE_CreditComponents.t.sol` | Tests read `G_i`, paired `J_i`, zap uncredited `J_i`, and incumbent fees as separate values. `qQuote` above the minimum and `q` below it reverts. Addition rounding reduces entrant credit, not incumbent `R_i`. |
| A65 | `PairTokenSE_Reconcile.t.sol` | At each settled boundary the five custody categories sum to raw custody and reservations are zero. Terminal receipts reach the last holder. Restart does not adopt unsolicited funds. |
| A66 | `PairTokenSE_EmptyAndTiny.t.sol` | Empty `compound` is a no-op. Zero total payout reverts `ZeroPayout`. One-sided positive paired output succeeds. Tiny genesis and donation keep the predicates without dead shares. |
| A67 | `PairTokenSE_StateChange.t.sol` | Nonzero protocol fee, an initialized crossing, empty-word progress, and a checkpoint change are projected through compound plus entry and exit. A token-induced pool change reverts `EconomicStateChanged`. |
| A68 | `PairTokenSE_Facets.t.sol` | Proxy has no owner, `diamondCut`, rescue, ERC-4626, or rate-provider selector. Manifest covers family ABI, shared selectors, interface ids, and repo init. Binding hash participates in identity. |
| A69 | `PairTokenSE_Package.t.sol` | Zero fee-type ids register and read back. No invented fee is charged. Dust constant is 1000. Omitted zap args do not compile into a default. `assetInfo` uses cached decimals. |
| A70 | `PairTokenSE_Size.t.sol` | Measure gas for a 512-step candidate, a two-candidate withdrawal, a native wrap path, and a collection-only paired exit. Code size uses the Stage 8 gate. A miss stops for design revision. It does not lower 512, fuzz, or the size limit. |

A61 construction: the work-limit case initializes enough real ticks, from the test contract as a non-SUT LP, that the linked projector reports step 513 on the full candidate and the collection-only paired plan has zero swaps. The price-limit case moves the real pool to the protocol boundary and forces a nonzero maintenance swap in the illegal direction. Liquidity-limit and delta-limit cases are attempted with mintable balances. If a case needs a token amount or delta the manager cannot represent, the spec contains a pure domain proof of that overflow and does not etch the manager. The proof is labeled and is not counted as a passing real-manager execution.

A28 uses the same linked library as a control. The acceptance subject is still the registered vault: preview and execution must agree. The public ABI does not grow a step-count field.

# Validation and release gates

After every production edit, from a warm tree, with `cache_forge` and `out` seeded before the first compile in a new worktree:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecutionTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultQueryTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultCallbackTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultSYTarget.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/pairToken \
  -- -vv
```

Pass every edited production file as a positional argument. Repeat `--test-root` for the value-oracle spec if it lives outside that directory. Do not run `forge test` alone after a production edit. Do not add a Foundry profile, pass `FOUNDRY_TEST`, delete `out/` or `cache_forge/`, or set `via_ir`. Cold compile waits for process exit; a multi-hour budget is normal. Hermetic default profile only. Fork suites are out of stage one.

Before that test command, `python3 scripts/forge-artifacts.py plan` with the same arguments shows the graph. `python3 scripts/forge-artifacts.py audit <edited> --json` is an inspection, not a pass signal.

Release gates, all required, none yet run:

1. The artifact-first command exits 0.
2. Every S1-A01–A70 row has a passing assertion or, for an unreachable fallback reason only, a labeled domain proof.
3. `extcodesize` of each new facet, linked library, and package is at most 24576 after the real CREATE3 deploy.
4. Differential projector tests match the real manager on the vectors in Stage 4.
5. Value-oracle vectors match, including the sequential-floor counterexample.
6. Gas used is recorded for the four A70 paths. The numeric block-gas ceiling is not in the PRD or the files read here. The report cites the deployment ceiling from current repo deployment docs. If none is named, A70's pass/fail is Blocker B3, while the measurement still ships. Do not invent a ceiling in production code.
7. Comparison ledger is present and the baseline suite is unmodified.
8. Implementation report lists files, runtime sizes, commands, measured gas, unrun checks, and later-stage reuse paths. Unrun items stay labeled unrun.

Implementer handoff format: files added; comparison-ledger rows; runtime sizes; commands and exit codes; A01–A70 evidence pointers; gas figures marked measured; any domain proof; blockers. No deployment, no git commit, and no PRD edit are part of this plan.

# Blockers and limits

B1. Diamond proxy empty-calldata `receive` was not line-read. If that path delegatecalls, S1-A60 cannot be met by a facet `receive` without contradicting the PRD. Stop in Stage 0. Resolution is a factory-proxy fact, not a family workaround.

B2. S1-QUOTE-02 requires an explicit revert for an unrepresentable value. S1-OBS-01 does not name that error. Proposed identifier: `UnrepresentableExchangeRate()`. This is an ABI name, not a valuation change. Freeze it in the manifest only if the coordinator accepts that one-error clarification. Do not omit the revert, and do not substitute `PairTokenMath.MD`'s empty revert.

B3. S1-A70's gas ceiling is unnamed in the admitted sources. Measure gas. Do not treat a Foundry unlimited transaction as a pass, and do not hardcode a guessed chain limit. Code size is not blocked: the normal deployed limit used here is EIP-170, 24576 bytes.

B4. `MaintenanceLiquidityLimit` or `MaintenanceDeltaLimit` may be unreachable with representable token amounts. A61 permits a domain proof. That proof is not a mocked pass. Work-limit and price-limit are expected to be real-manager reachable.

B5. Crane `modifyLiquidity` return signs were not line-read. Stage 0 either confirms `callerDelta = principalDelta + feesAccrued` on the real port or stops. No alternate split is authorized.

No other product choice is open. In particular, do not replace the issuance equation, the zap residual policy, the fallback predicate, the 512-step bound, the spot SY rate, the five-facet list, or the factory-facet exclusion.

Limits of this contribution: no implementation exists; no test was run; no size or gas number below is a measurement; no economic invariant was executed. `INDEXEDEX_AGENT_LAW.md` was used through the router and testing skill, not by a full read. The projector loop is specified from the `Pool.swap` body that was read and is valid only if Stage 4's differential holds. Baseline harness files stay stable. This contribution does not authorize coding, deployment, or a second council round.
