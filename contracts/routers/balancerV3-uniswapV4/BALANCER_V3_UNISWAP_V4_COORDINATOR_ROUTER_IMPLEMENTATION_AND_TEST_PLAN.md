# Balancer V3 × Uniswap V4 Coordinator Router — Implementation & Test Plan

**Package name (frozen):** `BalancerV3UniswapV4CoordinatorRouter` (short: **Coordinator**)  
**Date:** 2026-08-03  
**Status:** **Ready to implement** against PRD **v1.3**  
**Package path:** `contracts/routers/balancerV3-uniswapV4/`  
**Authority:**

| Layer | Role |
|-------|------|
| **[PRD v1.3](./BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_PRD.md)** | Product law (do not re-litigate) |
| **This plan** | Source of truth for implementors: file layout, APIs, witness string, UR templates, phases, tests |
| Child routers | Execution venues only |

**Skills (mandatory before coding):**

- Crane: `crane-deployment`, `crane-architecture`, `crane-testing`, `crane-porting` (for Universal Router dependency)
- IndexedEx: `indexedex-testing` (Coordinator itself is **pure Crane**, not vault registry; SE child venues still use IndexedEx SE TestBases)

---

## 0. Plan-owned locks (finalize PRD soft spots)

These choices were left to the plan in PRD v1.3 and are **LOCKED** here.

| ID | Lock |
|----|------|
| **P1** | Error for non-pinned UR encodings: **`InvalidStepData`** only (do not introduce a second `UnsupportedQuery` unless a later PRD adds it). Same error for execute and query. |
| **P2** | Witness type string / typehash: **§5.1** of this plan (exact characters). |
| **P3** | Shared reentrancy: Crane **`ReentrancyLockModifiers`** (same pattern as SE router) on execute, query, and rescue. |
| **P4** | UR v1 templates: **Template A** (single-hop V4 exact-in) and **Template B** (multi-hop V4 exact-in path) — **§6**. |
| **P5** | V4 quote surface: Crane **`V4Quoter`** / `UniswapV4Quoter` helpers already under `lib/crane` (prefer production quoter address in PkgArgs; hermetic deploy via Crane Uni V4 test stack). |
| **P6** | Batch single-root fill: overwrite **`paths[0].exactAmountIn`** only; require `paths.length == 1` for v1 stock/SE batch steps (strict single-root). Multi-hop *within* that one path is allowed. |
| **P7** | Child revert policy: bubble child reverts as-is when possible; optional wrap only if selector collision forces it — prefer **no wrap** for easier debugging. |
| **P8** | `StepExecuted` event: **emit** (index, router, tokenOut, amountOut) for each successful step. |
| **P9** | Universal Router hermetic dependency: **blocking milestone M0** before T7/T8/T9/T24 UR cases green in CI. |
| **P10** | FoT check: measure token balance of Coordinator **before and after** Permit2 pull; if `after - before < amountIn` → `InvalidAmount(tokenIn, amountIn, actual)`. |
| **P11** | Final transfer: `require(IERC20(tokenOut).balanceOf(this) >= amountOut)` then transfer **exactly** ledger `amountOut`. |
| **P12** | Interface home: types + primary interface under package `interfaces/`; re-export or thin facade under `contracts/interfaces/` only if project convention requires global discoverability (prefer package-local first; add global interface when other packages import Coordinator). |

---

## 1. Goals / non-goals

### 1.1 Goals

1. Ship production **Diamond + DFPkg** Coordinator per PRD D1–D35.
2. Pure Crane deploy path (CREATE3 facets + package; diamond via `diamondPackageFactory`).
3. Exact-in multi-venue routes with amount ledger, Permit2 full-route witness, per-step allowances, recipient payout, ETH first/last, query, allowlist, owner rescue.
4. Production-first tests T1–T32 (PRD §10) with real child venues (no mock SUT).
5. Unblock UR hermetic coverage via Crane Universal Router port (or approved vendor).

### 1.2 Non-goals (v1)

- Exact-out, on-chain aggregation, parallel splits, multi-root batch, FoT “accept less”.
- Vault-registry registration of Coordinator.
- Frontend / off-chain aggregator service (except encoding contracts implied by §5–§6).
- Arbitrary UR commands beyond Templates A/B.
- Thin IndexedEx V4 executor product.

---

## 2. Target package layout

```text
contracts/routers/balancerV3-uniswapV4/
  BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_PRD.md
  BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_IMPLEMENTATION_AND_TEST_PLAN.md  # this file

  interfaces/
    IBalancerV3UniswapV4CoordinatorRouter.sol          # types, main surface, errors/events, PkgInit/PkgArgs
    IBalancerV3UniswapV4CoordinatorRouterAdmin.sol      # allowlist + rescue (optional split)
    IBalancerV3UniswapV4CoordinatorRouterPermit2Witness.sol
    IBalancerV3UniswapV4CoordinatorRouterDFPkg.sol      # PkgInit / PkgArgs (Crane rule: on interface)

  common/
    BalancerV3UniswapV4CoordinatorRouterCommon.sol     # shared modifiers, errors, constants
    BalancerV3UniswapV4CoordinatorRouterRepo.sol        # allowlist AddressSet + kind map + lock if needed
    BalancerV3UniswapV4CoordinatorRouterAwareRepo.sol   # optional: if more than Permit2/WETH/quoter

  adapters/
    StockBalancerV3RouterAdapter.sol                   # library
    StockBalancerV3BatchRouterAdapter.sol              # library
    IndexedExSERouterAdapter.sol                       # library
    UniswapV4UniversalRouterAdapter.sol                # library + template parse/patch/quote

  facets/
    BalancerV3UniswapV4CoordinatorRouterExactInFacet.sol
    BalancerV3UniswapV4CoordinatorRouterQueryFacet.sol
    BalancerV3UniswapV4CoordinatorRouterAdminFacet.sol
    BalancerV3UniswapV4CoordinatorRouterPermit2WitnessFacet.sol
    # MultiStepOwnable: use Crane MultiStepOwnable facet in diamond cuts (not reimplemented)

  targets/
    BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol
    BalancerV3UniswapV4CoordinatorRouterQueryTarget.sol
    BalancerV3UniswapV4CoordinatorRouterAdminTarget.sol
    BalancerV3UniswapV4CoordinatorRouterPermit2WitnessTarget.sol

  BalancerV3UniswapV4CoordinatorRouterDFPkg.sol
  BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol

  TestBase_BalancerV3UniswapV4CoordinatorRouter.sol

test/foundry/routers/spec/balancerV3-uniswapV4/
  BalancerV3UniswapV4CoordinatorRouter_Deploy.t.sol
  BalancerV3UniswapV4CoordinatorRouter_Admin.t.sol
  BalancerV3UniswapV4CoordinatorRouter_ExactIn_Stock.t.sol
  BalancerV3UniswapV4CoordinatorRouter_ExactIn_SE.t.sol
  BalancerV3UniswapV4CoordinatorRouter_ExactIn_UR.t.sol
  BalancerV3UniswapV4CoordinatorRouter_ExactIn_Interleaved.t.sol
  BalancerV3UniswapV4CoordinatorRouter_Permit2Witness.t.sol
  BalancerV3UniswapV4CoordinatorRouter_Eth.t.sol
  BalancerV3UniswapV4CoordinatorRouter_Query.t.sol
  BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol
  BalancerV3UniswapV4CoordinatorRouter_Negative.t.sol

test/foundry/fork/base_main/routers/balancerV3-uniswapV4/
  TestBase_BalancerV3UniswapV4CoordinatorRouter_BaseMain.sol
  BalancerV3UniswapV4CoordinatorRouter_BaseMain_Fork.t.sol
```

**Naming:** all production types use frozen prefix `BalancerV3UniswapV4CoordinatorRouter*`.

---

## 3. Architecture

### 3.1 Diamond facet split (normative for this plan)

| Facet | Responsibility | Selectors (conceptual) |
|-------|----------------|------------------------|
| **ExactIn** | `swapExactInWithPermit`, `swapExactInEth` | Execute path |
| **Query** | `queryExactIn` | Simulation path |
| **Admin** | `registerRouter`, `unregisterRouter`, views, `rescueTokens`, `rescueETH` | Owner + views |
| **Permit2Witness** | `WITNESS_TYPE_STRING`, `WITNESS_TYPEHASH` | Constants / getters |
| **MultiStepOwnable** | Crane ownership transfer surface | From Crane facet |

Targets hold implementation; facets only declare cuts (Crane pattern).

### 3.2 Storage (Repo)

**`BalancerV3UniswapV4CoordinatorRouterRepo`** (ERC-1967-style Crane slot):

```text
struct Layout {
  AddressSet allowedRouters;                 // AddressSetRepo
  mapping(address => AdapterKind) kindOf;    // 0 unused / invalid if not in set
  // Permit2, WETH, V4Quoter: prefer AwareRepos from initAccount (Permit2AwareRepo, WETHAwareRepo)
  // or store in Layout if package-specific:
  address v4Quoter;                          // required for UR query
}
```

**Rules:**

- `registerRouter`: `allowedRouters._add(router)` (idempotent); `kindOf[router] = kind`; emit `RouterRegistered`.
- `unregisterRouter`: remove from set; `delete kindOf[router]`; emit `RouterUnregistered`.
- Dispatch: `require(allowedRouters._contains(router))`; read `kindOf[router]`; invalid enum → `InvalidRouterKind`.

**Aware deps (initAccount / postDeploy):**

- `Permit2AwareRepo` → Permit2
- `WETHAwareRepo` → WETH
- Quoter address → repo field `v4Quoter` (or `UniswapV4QuoterAwareRepo` if one exists; else package repo)

### 3.3 Shared lock

Use Crane `ReentrancyLockModifiers`:

| Function | Lock |
|----------|------|
| `swapExactInWithPermit` | nonReentrant |
| `swapExactInEth` | nonReentrant |
| `queryExactIn` | nonReentrant (external calls to child query / quoter) |
| `rescueTokens` / `rescueETH` | nonReentrant |
| Admin register/unregister | **no** lock required (views free; writes cheap) |

A child callback **must not** successfully call rescue or a second swap on the Coordinator mid-route.

### 3.4 Custody flow (implementation)

```text
Principal --Permit2 witness / ETH wrap--> Coordinator
  loop steps:
    amount-scoped child funding
    child.exactIn(...)  // msg.sender = Coordinator
    measure delta(step.tokenOut)
    amountForStep = delta
  transfer ledger amountOut --> recipient
```

---

## 4. Interfaces and types

### 4.1 Primary interface sketch

Define on `IBalancerV3UniswapV4CoordinatorRouter` (or split interfaces composed by the diamond):

```solidity
enum AdapterKind {
    StockBalancerV3Router,        // 0
    StockBalancerV3BatchRouter,   // 1
    IndexedExSERouter,            // 2
    UniswapV4UniversalRouter      // 3
}

enum StepCallMode {
    SingleExactIn,  // 0
    BatchExactIn    // 1
}

struct RouteStep {
    address router;
    address tokenOut;
    uint256 minAmountOut;
    bytes data;
}

struct SwapExactInParams {
    address recipient;
    address tokenIn;
    uint256 amountIn;
    address tokenOut;
    uint256 minAmountOut;
    uint256 deadline;
    bool ethIn;
    bool ethOut;
    RouteStep[] steps;
}

struct InitialRouter {
    address router;
    AdapterKind kind;
}

// Execute
function swapExactInWithPermit(
    SwapExactInParams calldata params,
    ISignatureTransfer.PermitTransferFrom calldata permit,
    bytes calldata signature
) external payable returns (uint256 amountOut);

function swapExactInEth(SwapExactInParams calldata params)
    external
    payable
    returns (uint256 amountOut);

function queryExactIn(SwapExactInParams calldata params)
    external
    returns (uint256 amountOut);

// Admin
function registerRouter(address router, AdapterKind kind) external;
function unregisterRouter(address router) external;
function isRouterAllowed(address router) external view returns (bool);
function routerKind(address router) external view returns (AdapterKind);
function allowedRouterCount() external view returns (uint256);
function allowedRouterAt(uint256 index) external view returns (address);
function rescueTokens(address token, address to, uint256 amount) external;
function rescueETH(address to, uint256 amount) external;

// Witness getters
function WITNESS_TYPE_STRING() external pure returns (string memory);
function WITNESS_TYPEHASH() external pure returns (bytes32);
```

### 4.2 DFPkg interface (`IBalancerV3UniswapV4CoordinatorRouterDFPkg`)

```solidity
struct PkgInit {
    IFacet multiStepOwnableFacet;   // Crane
    IFacet exactInFacet;
    IFacet queryFacet;
    IFacet adminFacet;
    IFacet permit2WitnessFacet;
    // any other base facets required by project diamond policy
    IPermit2 permit2;
    IWETH weth;
    address v4Quoter;               // may be address(0) only if UR never used; prefer non-zero always in tests
}

struct PkgArgs {
    address owner;                  // MultiStepOwnable initial owner
    InitialRouter[] initialRouters; // optional seed (may be empty)
}
```

**`PkgInit` / `PkgArgs` MUST live on the interface**, not the contract body.

### 4.3 Errors & events (implement PRD minimum)

Errors: as PRD §8.1 (use `InvalidStepData` for bad UR templates / decode; omit separate `UnsupportedQuery`).

Events: `RouterRegistered`, `RouterUnregistered`, `RouteExecuted`, `StepExecuted`, `TokensRescued`, `ETHRescued`.

---

## 5. Permit2 full-route witness (exact)

### 5.1 Type string and typehash (LOCKED)

Align with SE router style (`Witness witness)TokenPermissions...`).

```text
WITNESS_TYPE_STRING =
  "Witness witness)"
  "TokenPermissions(address token,uint256 amount)"
  "Witness(address recipient,address tokenIn,uint256 amountIn,address tokenOut,uint256 minAmountOut,uint256 deadline,bool ethIn,bool ethOut,bytes32 stepsHash)"

WITNESS_TYPEHASH = keccak256(
  "Witness(address recipient,address tokenIn,uint256 amountIn,address tokenOut,uint256 minAmountOut,uint256 deadline,bool ethIn,bool ethOut,bytes32 stepsHash)"
)
```

### 5.2 On-chain witness encoding

```solidity
bytes32 stepsHash = keccak256(abi.encode(params.steps));

bytes32 witness = keccak256(
    abi.encode(
        WITNESS_TYPEHASH,
        params.recipient,
        params.tokenIn,
        params.amountIn,
        params.tokenOut,
        params.minAmountOut,
        params.deadline,
        params.ethIn,
        params.ethOut,
        stepsHash
    )
);
```

Then `Permit2.permitWitnessTransferFrom(...)` with `WITNESS_TYPE_STRING` (SE-router pattern: check exact `permitWitnessTransferFrom` arity used by IndexedEx SE router).

### 5.3 Permit validation

- `permit.permitted.token == params.tokenIn`
- `permit.permitted.amount` covers `params.amountIn` (Permit2 rules)
- Owner = `msg.sender`
- After transfer: **P10** balance delta check → `InvalidAmount` on shortfall

### 5.4 Test helper

TestBase should expose `_signCoordinatorWitness(principalPk, params, permitNonce, deadline)` using `vm.sign` / EIP-712 domain of Permit2 (mirror SE router TestBase witness signing).

---

## 6. Universal Router templates (LOCKED catalog)

### 6.1 Product rule

Only Templates **A** and **B** are valid for `AdapterKind.UniswapV4UniversalRouter`.  
Parse `step.data = abi.encode(bytes commands, bytes[] inputs)`.  
If commands/inputs do not match a template → **`InvalidStepData`**.

Exact command byte values must match the **vendored Universal Router Commands** constants after M0 lands. Below is the **intent**; implementors fill hex constants from the port.

### 6.2 Template A — single-hop V4 exact-in

**Intent:**

1. Pull/settle `amountIn` of `tokenIn` from Coordinator into PoolManager (via UR).
2. `V4_SWAP` exact-in single pool (or V4Router actions equivalent encoded in UR input).
3. Take / sweep `tokenOut` to **Coordinator** (`ADDRESS_THIS` / recipient = coordinator).

**Ledger patch:** replace amount-in fields in the actions/inputs with `amountForStep` before `execute`.

**Query:** decode pool key + zeroForOne + amountIn from template; call `V4Quoter.quoteExactInputSingle` (or Crane `UniswapV4Quoter.quoteExactInput`) → `amountOut` for ledger.

### 6.3 Template B — multi-hop V4 exact-in

**Intent:** same as A but multi-hop path encoding inside `V4_SWAP` actions.

**Query:** `quoteExactInput` along path with ledger `amountIn`.

### 6.4 Amount patching

Adapter function:

```text
patchAndExecute(router, commands, inputs, amountForStep, deadline, tokenOut) -> delta measured by caller
patchAndQuote(commands, inputs, amountForStep) -> quotedOut
```

Never use full `balanceOf` as input.

### 6.5 Recipient / sweep

Execute encodings **must** leave `step.tokenOut` on the Coordinator. Document in NatSpec that off-chain builders must not set final sweep recipient to the end user on intermediate UR steps.

---

## 7. Adapter implementations

### 7.1 Shared adapter interface (libraries)

```solidity
library ... {
  function executeStep(
    address router,
    address currentToken,
    uint256 amountIn,
    address tokenOut,
    bytes memory data,
    uint256 deadline
  ) internal; // funding already set by caller

  function queryStep(
    address router,
    address currentToken,
    uint256 amountIn,
    address tokenOut,
    bytes memory data
  ) internal returns (uint256 amountOut);
}
```

Caller (ExactIn/Query target) handles: allowlist, balance before/after for execute, minOut, ledger.

### 7.2 Stock single (`StockBalancerV3Router`)

**Decode `data`:**

```text
(pool, tokenIn, tokenOut, minAmountOut, wethIsEth, userData)
```

**Execute:**

```solidity
IRouter(router).swapSingleTokenExactIn(
  pool, tokenIn, tokenOut, amountIn, minAmountOut, deadline, wethIsEth, userData
);
```

**Funding:** Permit2 AllowanceTransfer: approve child for `amountIn` of `currentToken`, then clear to 0.

**Query:** `IRouter.querySwapSingleTokenExactIn(...)` (or stock query API on Crane Router) with same args; return amountOut. Use `sender = address(this)` semantics as required by Balancer query hooks.

### 7.3 Stock batch (`StockBalancerV3BatchRouter`)

**Decode:**

```text
(SwapPathExactAmountIn[] paths, wethIsEth, userData)
```

**P6:** require `paths.length == 1`; set `paths[0].exactAmountIn = amountIn`.

**Execute:** `IBatchRouter.swapExactIn(paths, deadline, wethIsEth, userData)`.

**Query:** batch `querySwapExactIn` equivalent.

### 7.4 IndexedEx SE (`IndexedExSERouter`)

**Decode leading `uint8 callMode`:**

| Mode | Call |
|------|------|
| 0 SingleExactIn | `swapSingleTokenExactIn(pool, tokenIn, tokenInVault, tokenOut, tokenOutVault, amountIn, minAmountOut, deadline, wethIsEth, userData)` |
| 1 BatchExactIn | `swapExactIn(paths, deadline, wethIsEth, userData)` with P6 single path root |

**Funding:** same Permit2 AllowanceTransfer pattern as stock (SE pulls via Permit2 from Coordinator as sender).

**Query:** `querySwapSingleTokenExactIn` / `querySwapExactIn` on SE diamond.

### 7.5 Universal Router

See §6. Funding: `SafeERC20.forceApprove(token, ur, amountIn)` then `0` after call.

### 7.6 Child funding helpers (common)

```text
_approveBalancerStyle(child, token, amount):
  permit2.approve(token, child, amount, expiration=now+1 or max needed for one tx)
  // clear after: approve(..., 0, 0) or package-standard clear

_approveUrStyle(child, token, amount):
  forceApprove(child, amount); after: forceApprove(child, 0)
```

Never leave `type(uint160).max` standing after success.

---

## 8. Execution / query algorithms (implement PRD §4.5 / §4.8)

### 8.1 Shared validation `_validateParams(params, requireEthInFlag)`

1. `block.timestamp <= deadline` else `ExpiredDeadline`
2. `recipient != 0` else `InvalidRecipient`
3. `steps.length >= 1` else `EmptyRoute`
4. `steps[last].tokenOut == tokenOut` else `TokenOutMismatch`
5. If `ethOut`: `tokenOut == WETH` else `InvalidEthOut`
6. If `ethIn`: `tokenIn == WETH` else `InvalidEthIn`
7. For each step: `isRouterAllowed` else `RouterNotAllowed`
8. Entry-specific: permit path requires `!ethIn`; eth path requires `ethIn`

### 8.2 Execute body

As PRD algorithm with plan locks P10–P11 and `StepExecuted` emits.

**Entry split:**

| Function | Rules |
|----------|--------|
| `swapExactInWithPermit` | `ethIn == false`; pull via witness; `msg.value` should be 0 (refund or ignore; prefer require 0 or refund excess to principal) |
| `swapExactInEth` | `ethIn == true`; `msg.value >= amountIn`; wrap; refund excess ETH to `msg.sender` |

### 8.3 Query body

1. Same structural validation (no permit, no value required).
2. `amountForStep = amountIn` (simulate funding exists).
3. For each step: `queryStep` adapter → set `amountForStep = quotedOut`; optional ignore per-step min for numeric result but still decode-valid.
4. Return final `amountForStep` (no transfers, no lasting state).
5. UR non-template → `InvalidStepData`.

**State safety:** child query APIs must not leave balances changed. Assert in tests Coordinator inventory unchanged (except transient gas). Prefer pure view/static patterns already used by Balancer/SE query facets.

---

## 9. Deploy path (pure Crane)

### 9.1 FactoryService

`BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol`:

```solidity
function deploy*Facet(ICreate3Factory factory) internal returns (IFacet);
function deployBalancerV3UniswapV4CoordinatorRouterDFPkg(ICreate3Factory factory, PkgInit memory init)
  returns (IBalancerV3UniswapV4CoordinatorRouterDFPkg);
function deployCoordinator(
  IDiamondPackageCallBackFactory diamondFactory,
  IBalancerV3UniswapV4CoordinatorRouterDFPkg pkg,
  PkgArgs memory args
) internal returns (IBalancerV3UniswapV4CoordinatorRouter);
```

Salts: `abi.encode(type(X).name)._hash()` via Crane hash lib.

### 9.2 DFPkg lifecycle

1. `facetCuts` / `diamondConfig` — ExactIn, Query, Admin, Witness, MultiStepOwnable (+ loupe/base via factory).
2. `initAccount(args)` — set owner (MultiStepOwnable), bind Permit2/WETH/quoter aware slots.
3. `postDeploy(account)` — register `args.initialRouters` via internal register logic (idempotent).

**Forbidden:** `indexedexManager.deploy*DFPkg`, vault registry, `new Facet()`.

### 9.3 TestBase deploy snippet (intent)

```solidity
// CraneTest.setUp() already provides create3Factory + diamondPackageFactory
facets = FactoryService.deployAllFacets(create3Factory);
pkg = FactoryService.deployPkg(create3Factory, PkgInit({... real facets, permit2, weth, quoter ...}));
coordinator = FactoryService.deployCoordinator(
  diamondPackageFactory,
  pkg,
  PkgArgs({ owner: owner, initialRouters: seed })
);
```

---

## 10. Implementation phases

| Phase | Name | Deliverable | Exit criteria |
|-------|------|-------------|---------------|
| **M0** | UR + quoter dependency | Crane Universal Router port **or** approved vendor + hermetic deploy helper; V4Quoter wired in Uni V4 TestBase | Can deploy UR + PoolManager + quoter hermetically; smoke `execute` V4 swap works outside Coordinator |
| **M1** | Skeleton diamond | Interfaces, Repo, DFPkg, FactoryService, MultiStepOwnable, Admin register/unregister/views, empty ExactIn/Query stubs | T1, T28, T29, T30, T25 (ownership) green |
| **M2** | ExactIn core + stock | Witness, Permit2 pull, ledger, stock single+batch adapters, ETH wrap/unwrap, rescue | T2–T4, T11–T23 (stock), T16–T20, T26–T27, T31–T32 green without SE/UR |
| **M3** | SE adapters | SE single+batch execute + query | T5, T6 + SE query paths |
| **M4** | UR adapters | Templates A/B execute + V4 quoter query | T7, T8, T24 UR cases |
| **M5** | Interleave + matrix | Multi-venue routes, subset allowlists, fork suite | T9, T10, T22, fork smoke; full T1–T32 |
| **M6** | Polish | NatSpec, Behavior_IFacet if used, forge fmt, docs cross-links | DoD checklist complete |

**Parallelism:** M0 can run in parallel with M1–M2. M4 blocked on M0.

---

## 11. Test plan

### 11.1 Standards

- Production-first: real Coordinator diamond, real child routers, real Permit2/WETH.
- **Never** mock Coordinator / DFPkg / facets under test.
- Allowed non-SUT: mintable ERC20, FoT ERC20 harness, reentrancy ERC20 for lock tests.
- Prefer exact `assertEq` (wei) for preview/execute; document ≤ few-wei only if child query forces it.
- Inherit: `CraneTest` for Coordinator deploy; compose `IndexedexTest` + SE/Balancer TestBases when SE legs needed; Uni V4 TestBase / port for UR.

### 11.2 TestBase responsibilities

`TestBase_BalancerV3UniswapV4CoordinatorRouter`:

1. Deploy Coordinator via FactoryService (pure Crane).
2. Provide `owner`, `alice`, `bob` (recipient), `permit2`, `weth`.
3. Helpers: fund + approve Permit2; sign witness; build RouteStep encodings per adapter.
4. Optional mode flags: `withStock`, `withSE`, `withUR` to register subsets.
5. Pool fixtures: minimal liquid pools for each venue used in suite.

### 11.3 Suite map (PRD T1–T32)

| ID | Spec file (suggested) | Assertion focus |
|----|----------------------|-----------------|
| T1 | `*_Deploy.t.sol` | CREATE3 facets + DFPkg + diamond; owner is MultiStepOwnable owner; register works |
| T2 | `*_Negative.t.sol` | Unregistered router → `RouterNotAllowed` |
| T3 | `*_ExactIn_Stock.t.sol` | Single stock hop; recipient balance += amountOut |
| T4 | `*_ExactIn_Stock.t.sol` | Single-root batch path; multi-root `paths.length!=1` → `InvalidStepData` |
| T5 | `*_ExactIn_SE.t.sol` | SE single |
| T6 | `*_ExactIn_SE.t.sol` | SE batch single-root |
| T7 | `*_ExactIn_UR.t.sol` | Template A |
| T8 | `*_ExactIn_UR.t.sol` | Template B |
| T9 | `*_ExactIn_Interleaved.t.sol` | ≥3 steps, ≥2 families; atomic success |
| T10 | `*_ExactIn_Interleaved.t.sol` | Two batch steps + other adapter |
| T11 | `*_Negative.t.sol` | Global minOut revert |
| T12 | `*_Negative.t.sol` | Per-step minOut revert |
| T13 | `*_Permit2Witness.t.sol` | Happy path witness |
| T14 | `*_Permit2Witness.t.sol` | Tampered steps / recipient / amount → revert |
| T15 | `*_Negative.t.sol` | No `transferFrom` user path exists (interface + attempt fails) |
| T16 | `*_Eth.t.sol` | ethIn; excess ETH to principal |
| T17 | `*_Eth.t.sol` | ethOut to recipient |
| T18 | `*_Eth.t.sol` | ethIn+ethOut; recipient ≠ principal |
| T19 | `*_Negative.t.sol` | recipient 0 |
| T20 | `*_Negative.t.sol` | deadline |
| T21 | `*_Admin.t.sol` | unregister then step fails |
| T22 | `*_Deploy.t.sol` / matrix | stock-only / SE-only / UR-only allowlists |
| T23 | `*_LedgerAndRescue.t.sol` | after step, child Permit2/ERC20 allowance == 0; cannot pull more than step |
| T24 | `*_Query.t.sol` | query≈execute; no inventory change; bad UR template reverts |
| T25 | `*_Admin.t.sol` | two-step ownership transfer |
| T26 | `*_LedgerAndRescue.t.sol` | donate intermediate token; next hop uses prior delta only |
| T27 | `*_Eth.t.sol` / Negative | entry split eth flags |
| T28 | `*_Deploy.t.sol` | assert deploy path does not call vault registry |
| T29 | `*_Admin.t.sol` | double register idempotent; kind overwrite |
| T30 | `*_Deploy.t.sol` | non-empty `initialRouters` seed in PkgArgs |
| T31 | `*_LedgerAndRescue.t.sol` | residual after swap; rescue; reentrancy: hostile token tries rescue mid-swap → locked |
| T32 | `*_Negative.t.sol` | FoT token → `InvalidAmount` |

### 11.4 Adversarial extras (recommended P1, not blocking DoD)

| ID | Case |
|----|------|
| A1 | Reentrancy ERC20 as `tokenOut` attempts nested `swapExactIn*` / `rescueTokens` → `IsLocked` / reentrancy error |
| A2 | Malicious allowlisted child (if test double router registered) tries max pull beyond allowance → fails |
| A3 | Witness replay with different `msg.sender` fails |
| A4 | Donation of `tokenOut` before step inflates delta (document); ledger still correct for *next* hop input |

### 11.5 Fork suite (Base main)

- Live Universal Router + WETH + Permit2 + one Balancer pool + optional SE if deployed.
- Smoke: single UR hop, single stock hop, one interleaved if both available.
- Not a substitute for hermetic T7–T9.

### 11.6 Commands

```bash
# Skeleton / admin
forge test --match-path 'test/foundry/routers/spec/balancerV3-uniswapV4/*' -vv

# Narrow
forge test --match-contract BalancerV3UniswapV4CoordinatorRouter_ExactIn_Stock -vvv

# Fork (requires RPC)
forge test --match-path 'test/foundry/fork/base_main/routers/balancerV3-uniswapV4/*' -vv
```

---

## 12. Dependency: Universal Router port (M0 detail)

### 12.1 Preferred path

1. Use `crane-porting` + `crane-porting-verification`.
2. Vendor Uniswap Universal Router (and required interfaces) under Crane external/protocol tree.
3. Remap shared OZ/Permit2/V4 deps into Crane shared externals (no nested private OZ trees).
4. Hermetic deploy helper + fork parity smoke.
5. Document addresses / constructor args for Base main in fork TestBase.

### 12.2 Interim (only if M0 slips)

- Stock + SE suites can land first (M1–M3).
- UR tests remain `skip` or separate profile **only until** M0 done — **DoD still requires M0**.
- Do **not** ship production Coordinator claiming UR support without hermetic UR tests.

### 12.3 Quoter

- Hermetic: deploy Crane `V4Quoter` against hermetic `PoolManager`.
- Fork: use live quoter if available, else deploy quoter pointing at live PoolManager (if construction allows).

---

## 13. Security implementation checklist

- [x] Shared nonreentrancy on swap / query / rescue  
- [x] Amount-scoped child funding + zero residual  
- [x] Balance-delta mins (not only child return values)  
- [x] Witness binds full params + stepsHash  
- [x] Ledger hop inputs (no full balance spend)  
- [x] FoT shortfall → `InvalidAmount` (T32 green)  
- [x] Excess ETH → principal; payout → recipient  
- [x] Owner rescue cannot run mid-swap  
- [x] Allowlist-only external router calls  
- [x] UR limited to Templates A/B  

---

## 14. Definition of Done (implements PRD §11)

1. PRD v1.3 accepted (product law).  
2. **This plan** accepted as implementor SoT.  
3. Coordinator Diamond DFPkg implements PRD §4–§6 + plan locks P1–P12.  
4. M0 Universal Router (+ quoter) hermetic path green.  
5. Exact-in interleaved multi-venue routes work with ledger payout to `recipient`.  
6. ETH first/last hop per PRD §4.7.  
7. `queryExactIn` per PRD §4.8 + Templates A/B.  
8. Suites **T1–T32** pass for venues in hermetic stack; fork smoke for live UR/Balancer.  
9. No `new` production deploys; pure Crane CREATE3/FactoryService/TestBase.  
10. NatSpec + interfaces; frozen name `BalancerV3UniswapV4CoordinatorRouter*`.  

---

## 15. Deviations process

If implementation discovers a conflict with PRD product law:

1. **Stop** and document in a short “Deviation” note under this directory.  
2. Prefer PRD revision (v1.4) over silent plan-only changes for product law.  
3. Plan-only bugs (wrong template hex, facet split, file names) may be fixed in this document with a changelog entry.

### Plan changelog

| Ver | Date | Notes |
|-----|------|--------|
| 1.0 | 2026-08-03 | Initial plan against PRD v1.3 |
| 1.1 | 2026-08-04 | M0: vendor Uniswap UR **2.1.1** under Crane `external/uniswap/universal-router`; profiles `universal_router` / `coordinator` / `coordinator_fork`. Stock query uses Balancer `tx.origin==0` semantics (not EVM staticcall). Hermetic + Base fork smoke green. |
| 1.2 | 2026-08-04 | M3 SE T5/T6 + T23 SE allowance + T32 FoT: SE suite uses real SE diamond on lean 8020 fixture (full SE TestBase stack-too-deep under via_ir). |
| 1.3 | 2026-08-04 | Skeptic closure: T7/T8 UR liquid execute+query; T9/T10 interleave; T11–T13/T16–T18/T22/T26/T31; Base fork live stock hop; hermetic **44** tests; UR settle funds router (`payerIsUser=false`). |

---

## 16. Quick implementor checklist (copy into PR)

```text
[x] M0 UR port / vendor + quoter (pin 2.1.1)
[x] Interfaces + Repo + errors/events
[x] Witness constants match §5.1
[x] ExactIn target (permit + eth) + ledger
[x] Adapters: stock single/batch, SE, UR A/B (liquid T7/T8 execute+query)
[x] Query target + child queries / V4 quoter
[x] Admin + rescue + shared lock
[x] DFPkg + FactoryService + TestBase
[x] Hermetic suite green (44 tests covering T1–T32 map for hermetic venues)
[x] Fork smoke with live stock hop (base_mainnet_alchemy)
[x] forge fmt on touched files
```

---

**End of implementation & test plan v1.0**
