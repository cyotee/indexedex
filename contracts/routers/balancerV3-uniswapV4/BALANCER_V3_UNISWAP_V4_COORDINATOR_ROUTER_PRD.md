# PRD: Balancer V3 × Uniswap V4 Coordinator Router

**Name:** `BalancerV3UniswapV4CoordinatorRouter` (working title; short: **Coordinator**)  
**Date:** 2026-08-03  
**Status:** **v1.0 plan-ready** — product law locked for exact-in multi-venue route execution.  
**Package path:** `contracts/routers/balancerV3-uniswapV4/`  
**Package kind:** IndexedEx **periphery coordinator** — sequences calls into **allowlisted** child routers (stock Balancer V3, IndexedEx Balancer V3 Standard Exchange Diamond, Uniswap V4 Periphery). **Not** a vault; **not** a DFPkg vault product; may be a diamond or single-contract package at implementor discretion so long as CREATE3 + FactoryService patterns are followed.

**Authority (normative):**

| Layer | Role |
|-------|------|
| **This PRD (v1.0)** | Product law for implementation plan and code |
| **Implementation plan** (follow-on) | Source of truth for implementors once written against this PRD |
| Child routers | Execution venues only — Coordinator does **not** reimplement pool math |

**Related surfaces (integration targets):**

| Surface | Path / note |
|---------|-------------|
| IndexedEx SE Router (Diamond) | `contracts/protocols/dexes/balancer/v3/routers/` — exact-in single + batch with SE vault intermediation |
| Stock Balancer V3 Router | Crane port: `lib/crane/contracts/external/balancer/v3/vault/contracts/Router.sol` (`IRouter.swapSingleTokenExactIn`) |
| Stock Balancer V3 BatchRouter | Crane port: `…/BatchRouter.sol` (`IBatchRouter.swapExactIn`) |
| Uniswap V4 core / abstract router | Crane: `lib/crane/contracts/protocols/dexes/uniswap/v4/` (`V4Router`, `PoolManager`, actions) |
| Uniswap V4 Periphery (call target) | **Deployed chain periphery** that exposes a public exact-in swap entry over V4 (typically **Universal Router** with `V4_SWAP` / settle-take actions). Crane `V4Router` is abstract — Coordinator does **not** call it as a standalone public API. |
| Crane AddressSet | `lib/crane/contracts/utils/collections/sets/AddressSetRepo.sol` |

**Standards (mandatory):**

- AGENTS.md / Crane: CREATE3 deploy, production-first tests, no mock of SUT
- Crane `AddressSet` / `AddressSetRepo` for allowed routers
- Permit2 for all ERC-20 pulls from the end user into the Coordinator
- Exact-in only in v1 (exact-out deferred)

---

## 0. Terminology (normative)

| Term | Meaning |
|------|---------|
| **Coordinator** | This package — the single user-facing contract that owns custody between hops and calls child routers |
| **Child router** | An allowlisted address the Coordinator is permitted to call for a step |
| **Router family / AdapterKind** | Classification of a child router’s ABI surface used by the Coordinator to decode `step.data` and dispatch the correct call |
| **Step** | One Coordinator hop: allowlisted child router + expected `tokenOut` + venue-encoded `data` |
| **Route** | Ordered list of steps built **off-chain**; executed atomically on-chain |
| **Principal** | Economic user who signed Permit2 / sent ETH; intermediate hops treat the **Coordinator** as child-router `msg.sender` / payer |
| **Stock Balancer** | Official Balancer V3 `Router` and/or `BatchRouter` (no SE vault features) |
| **SE Router** | IndexedEx `BalancerV3StandardExchangeRouter` diamond (single + batch with SE vaults) |
| **V4 Periphery** | Public Uniswap V4 entry the Coordinator calls (Universal Router or equivalent), **not** abstract `V4Router` alone |
| **First hop / last hop** | First and last steps of the route; only places native ETH may enter or leave |
| **DoD** | Definition of Done — package complete when §11 is satisfied |

---

## 1. Goal

Ship a **production-first multi-venue exact-in Coordinator** that:

1. Accepts an **off-chain-built** ordered route of steps.
2. Pulls user input once via **Permit2** (ERC-20) or **`msg.value`** (native ETH on the first hop only when flagged).
3. Executes each step by calling an **owner-allowlisted** child router, using that router’s native exact-in API.
4. Keeps **intermediate token balances on the Coordinator** between hops so any allowlisted venue can be chained.
5. Enforces a **global `minAmountOut`** on the final `tokenOut` before paying the user.
6. Works on chains that deploy **any non-empty subset** of the three families (stock Balancer only, SE only, V4 only, or combinations) by configuring the allowlist per deployment — **one Coordinator design, many chain configs**.

### 1.1 Canonical user story

```text
User wants: USDC → (Uniswap V4) WETH → (Balancer SE / stock) someBptOrShare

Off-chain:
  1. Quote each leg; build Step[] with child router addresses + encoded data
  2. User approves Permit2 for USDC (one-time)
  3. User signs Permit2 SignatureTransfer for amountIn → Coordinator

On-chain (one tx):
  Coordinator.swapExactInWithPermit(...):
    - permitWitnessTransferFrom USDC → Coordinator
    - step0: approve/fund V4 Periphery; execute V4 exact-in; WETH lands on Coordinator
    - step1: fund SE or stock Balancer; execute exact-in (single or batch path); tokenOut lands on Coordinator
    - require balance(tokenOut) >= minAmountOut
    - transfer tokenOut to user (or unwrap WETH→ETH if last hop ETH)
```

---

## 2. Non-goals (v1)

1. **Exact-out** swaps (binary search / multi-venue exact-out solvers). Deferred to a later router.
2. **On-chain route discovery / aggregation** (no quoter fusion, no best-path search on-chain).
3. **Split routes** (parallel partial fills / multi-path fan-out across venues in one Coordinator call).  
   - Same-venue multi-path batch (Balancer batch multi-path) may be used **inside one step** if the child router supports it; Coordinator v1 still sequences **steps** serially.
4. **Reimplementing** Balancer Vault or Uniswap PoolManager swap math inside the Coordinator.
5. **Arbitrary external calls** to non-allowlisted addresses.
6. **Nested unlock** of Balancer Vault and Uni PoolManager in the same callback context — legs are always **sequential full calls**.
7. **Mid-route native ETH** as an intermediate asset (WETH only between hops). ETH only on **first hop in** and/or **last hop out**.
8. **ERC-20 `transferFrom` without Permit2** from the end user (Permit2-only user funding).
9. **Exact-out child APIs**, even if child routers expose them.
10. **Frontend / off-chain router service** — out of scope except encoding contracts implied by this PRD.

---

## 3. Locked decisions

| ID | Decision | Status |
|----|----------|--------|
| **D1** | Architecture = **coordinator of child routers** (not direct Vault/PoolManager swap reimplementation) | LOCKED |
| **D2** | Exact-in only; exact-out out of scope | LOCKED |
| **D3** | Routes built **off-chain**; on-chain validates allowlist + balances + slippage | LOCKED |
| **D4** | Child routers identified by **address**; owner-managed **allowlist** via Crane **`AddressSet`** | LOCKED |
| **D5** | Owner registers each allowed router with an **`AdapterKind`** so the Coordinator knows how to decode `step.data` and which function to call | LOCKED |
| **D6** | Supported adapter families in v1: **StockBalancerV3**, **IndexedExSE**, **UniswapV4Periphery** | LOCKED |
| **D7** | Stock Balancer: support **single** `swapSingleTokenExactIn` **and** **batch** `swapExactIn` as step encodings | LOCKED |
| **D8** | SE Router: support **single** `swapSingleTokenExactIn` **and** **batch** `swapExactIn` as step encodings | LOCKED |
| **D9** | Uniswap: call **V4 Periphery** (public entry, e.g. Universal Router `execute` with V4 swap commands), not abstract `V4Router` alone | LOCKED |
| **D10** | User ERC-20 funding: **Permit2 only** (SignatureTransfer into Coordinator) | LOCKED |
| **D11** | Native **ETH** allowed on **first hop in** and/or **last hop out** only; intermediates are ERC-20/WETH | LOCKED |
| **D12** | Custody chain: user → **Coordinator** → child → **Coordinator** → … → user | LOCKED |
| **D13** | Global `minAmountOut` required; optional per-step `minAmountOut` (0 = skip) | LOCKED |
| **D14** | One Coordinator product; per-chain allowlist may include any subset of the three families | LOCKED |
| **D15** | No leftover intermediate tokens intended; whole tx reverts on any step failure | LOCKED |
| **D16** | Deadline checked once at Coordinator entry (and may be forwarded into child calls) | LOCKED |
| **D17** | Deploy via Crane CREATE3 / FactoryService patterns; production-first tests | LOCKED |

---

## 4. Product model

### 4.1 Why a Coordinator (not a new AMM)

Balancer V3 and Uniswap V4 already expose production swap surfaces with their own unlock/accounting:

- Balancer: `Vault.unlock` + router hooks; Permit2 pull from `sender`; `sendTo` payout to `sender`.
- Uniswap V4: `PoolManager.unlock` + action encoding (`SWAP_EXACT_IN*`, `SETTLE*`, `TAKE*`); public composition via **Periphery** (Universal Router `V4_SWAP`, etc.).

The Coordinator’s job is **custody + sequencing + allowlisting**, not pricing.

### 4.2 Multi-chain configuration

| Chain situation | Allowlist example |
|-----------------|-------------------|
| Balancer stock only | Stock `Router` + `BatchRouter` addresses |
| IndexedEx SE only | SE Diamond (single+batch facets on one proxy) |
| Uniswap V4 only | V4 Periphery / Universal Router |
| Full stack | All of the above |

Missing venues are simply **not registered**. Steps that target unregistered routers **revert**.

### 4.3 AdapterKind (normative)

When the owner allows a router, they set:

```text
registerRouter(address router, AdapterKind kind)
unregisterRouter(address router)
```

| `AdapterKind` | Expected child surface | Notes |
|---------------|------------------------|-------|
| `StockBalancerV3Router` | `IRouter.swapSingleTokenExactIn` | Single-hop / single-pool stock path |
| `StockBalancerV3BatchRouter` | `IBatchRouter.swapExactIn` | Multi-hop stock path (one Coordinator step) |
| `IndexedExSERouter` | SE Diamond single + batch exact-in | Same address may support both encodings; `step.data` selects which |
| `UniswapV4Periphery` | Periphery `execute` (or documented exact-in entry) | Must be able to pay out ERC-20 to Coordinator |

**Rationale for separate stock single vs batch kinds:** stock Balancer ships **two contracts** (`Router` vs `BatchRouter`). SE ships both APIs on **one diamond** → one kind with data-selected call mode.

Implementors may fold stock single+batch into one kind if a chain deploys a combined entry; PRD does not require that.

### 4.4 Step and route types (normative sketch)

```solidity
enum AdapterKind {
    StockBalancerV3Router,
    StockBalancerV3BatchRouter,
    IndexedExSERouter,
    UniswapV4Periphery
}

/// @dev Leading selector inside `data` for kinds that support multiple encodings (SE; optionally others).
enum StepCallMode {
    SingleExactIn,   // swapSingleTokenExactIn-shaped
    BatchExactIn     // swapExactIn path-shaped (single path recommended for chaining)
}

struct RouteStep {
    address router;       // must be allowlisted; kind looked up from storage
    address tokenOut;     // expected token balance increase after this step
    uint256 minAmountOut; // 0 = no per-step check; else require delta(tokenOut) >= min
    bytes data;           // adapter-specific encoding (see §5)
}

struct SwapExactInParams {
    address tokenIn;      // ERC-20 address; use WETH address when ethIn = true
    uint256 amountIn;
    address tokenOut;     // final token; must equal last step.tokenOut (or WETH if ethOut)
    uint256 minAmountOut; // global final slippage
    uint256 deadline;
    bool ethIn;           // true: first hop funded by msg.value (wrap to WETH on Coordinator)
    bool ethOut;          // true: unwrap final WETH and send ETH to user
    RouteStep[] steps;
}
```

**Entry points (normative):**

```text
swapExactInWithPermit(SwapExactInParams params, PermitTransferFrom permit, bytes signature)
  → uint256 amountOut

// Optional convenience if token already held by Coordinator (composable callers / tests):
// Not required for v1 DoD if Permit2 path covers product needs.
```

Native ETH: when `ethIn == true`, `msg.value >= amountIn`, Coordinator wraps to WETH before step 0; Permit2 not used for that input. When `ethIn == false`, ERC-20 input uses Permit2 only.

### 4.5 Execution algorithm (normative)

```text
1. require(block.timestamp <= deadline)
2. require(steps.length >= 1)
3. require(last.tokenOut == tokenOut)  // if ethOut, tokenOut is WETH address and last.tokenOut is WETH
4. For each step: require(isAllowedRouter(step.router))
5. Fund Coordinator:
     if ethIn: wrap msg.value (amountIn) → WETH; refund excess ETH to user
     else: Permit2 SignatureTransfer amountIn of tokenIn → Coordinator
6. currentToken = ethIn ? WETH : tokenIn
7. For i, step in steps:
     a. require currentToken balance on Coordinator > 0 (or amountIn for i==0 already held)
     b. amountForStep = balance(currentToken) for i>0; for i==0 use amountIn (or full WETH if ethIn)
     c. Dispatch by AdapterKind(step.router):
          prepare approvals / Permit2 allowance as required by child
          call child exact-in with amountForStep, sender/payer = Coordinator,
          recipient semantics such that step.tokenOut ends on Coordinator
          (for Balancer family: child pays `msg.sender` = Coordinator — achieved by Coordinator being caller)
     d. deltaOut = balance(step.tokenOut) - balBefore
     e. if step.minAmountOut != 0: require deltaOut >= step.minAmountOut
     f. currentToken = step.tokenOut
8. amountOut = balance(tokenOut)
9. require amountOut >= minAmountOut
10. if ethOut: unwrap WETH amountOut → ETH; send to user
    else: safeTransfer tokenOut → user
11. Do not leave dust of intermediate tokens as a success path requirement;
    optional dust sweep of known intermediates is implementor choice (prefer zero intermediates)
```

### 4.6 Custody and Permit2 toward child routers

| Direction | Mechanism |
|-----------|-----------|
| User → Coordinator | Permit2 SignatureTransfer (ERC-20) or `msg.value` (ETH in) |
| Coordinator → Balancer child | Child pulls via its own Permit2 from **Coordinator** as `sender`, **or** Coordinator pre-transfers if child API allows — prefer matching child production path (SE/stock use Permit2 `transferFrom(sender, …)`). Coordinator must grant Permit2 allowance to the child router for the step token/amount (or max with clear policy documented in plan). |
| Coordinator → V4 Periphery | Periphery-specific: typically approve Permit2 / periphery patterns so settle pulls from Coordinator; `TAKE` recipient = Coordinator (`ADDRESS_THIS` / explicit address) |
| Coordinator → User | ERC-20 transfer or ETH send |

**Security:** unlimited allowances to child routers are discouraged; prefer amount-scoped Permit2 AllowanceTransfer updates per step or documented reset pattern in the implementation plan.

### 4.7 ETH rules (normative)

| Case | Behavior |
|------|----------|
| `ethIn` | `tokenIn` must be WETH address; `msg.value >= amountIn`; wrap on Coordinator; excess ETH refunded to user |
| Mid-route | **Forbidden** to use native ETH as `tokenOut` of a non-final step |
| `ethOut` | Final `tokenOut` must be WETH; unwrap and send ETH to user after global min check |
| Both | Allowed (ETH → … → ETH) |

Child hops between first and last always see **WETH ERC-20**, never native ETH, unless a single-step route is pure wrap/unwrap (out of scope as a product feature — users can call WETH directly).

---

## 5. Step data encodings (normative)

All encodings are built off-chain. Amounts that the Coordinator fills on-chain (`exactAmountIn`) are **overwritten** by the Coordinator from balances; off-chain may pass 0 as placeholder.

### 5.1 Stock Balancer — single (`AdapterKind.StockBalancerV3Router`)

Maps to:

```solidity
IRouter.swapSingleTokenExactIn(
  pool, tokenIn, tokenOut, exactAmountIn, minAmountOut, deadline, wethIsEth, userData
)
```

**`step.data` ABI:**

```text
abi.encode(
  address pool,
  address tokenIn,       // must match Coordinator currentToken
  address tokenOut,      // must match step.tokenOut
  uint256 minAmountOut,  // child-level; often 0 when Coordinator enforces step.minAmountOut
  bool wethIsEth,        // mid-route: false (no native ETH)
  bytes userData
)
```

Coordinator supplies `exactAmountIn` and `deadline` from route context.

### 5.2 Stock Balancer — batch (`AdapterKind.StockBalancerV3BatchRouter`)

Maps to `IBatchRouter.swapExactIn(paths, deadline, wethIsEth, userData)`.

**v1 chaining recommendation:** encode **exactly one** `SwapPathExactAmountIn` whose final `tokenOut` equals `step.tokenOut`. Multi-path stock batch inside one step is allowed only if all path outputs are the **same** `tokenOut` and the Coordinator measures total balance delta of that token.

**`step.data` ABI:**

```text
abi.encode(
  SwapPathExactAmountIn[] paths,  // exactAmountIn fields overwritten on-chain for the funded path(s)
  bool wethIsEth,                 // mid-route: false
  bytes userData
)
```

Types: Crane / Balancer `SwapPathStep` / `SwapPathExactAmountIn` (`BatchRouterTypes.sol`).

### 5.3 IndexedEx SE Router — single (`AdapterKind.IndexedExSERouter` + `StepCallMode.SingleExactIn`)

Maps to SE:

```solidity
swapSingleTokenExactIn(
  pool, tokenIn, tokenInVault, tokenOut, tokenOutVault,
  exactAmountIn, minAmountOut, deadline, wethIsEth, userData
)
```

**`step.data` ABI:**

```text
abi.encode(
  uint8 callMode,              // StepCallMode.SingleExactIn = 0
  address pool,
  address tokenIn,
  address tokenInVault,        // address(0) if none
  address tokenOut,
  address tokenOutVault,       // address(0) if none
  uint256 minAmountOut,
  bool wethIsEth,
  bytes userData
)
```

### 5.4 IndexedEx SE Router — batch (`AdapterKind.IndexedExSERouter` + `StepCallMode.BatchExactIn`)

Maps to SE `swapExactIn(SESwapPathExactAmountIn[] paths, deadline, wethIsEth, userData)`.

**`step.data` ABI:**

```text
abi.encode(
  uint8 callMode,              // StepCallMode.BatchExactIn = 1
  SESwapPathExactAmountIn[] paths,  // includes isStrategyVault steps; exactAmountIn filled on-chain
  bool wethIsEth,
  bytes userData
)
```

Types: `IBalancerV3StandardExchangeBatchRouterExactIn` / `IBalancerV3StandardExchangeBatchRouterTypes`.

### 5.5 Uniswap V4 Periphery (`AdapterKind.UniswapV4Periphery`)

**Call target:** allowlisted periphery address (chain Universal Router or documented V4 executor).

**Normative capability:** execute an **exact-in** V4 swap (single-hop and multi-hop path) such that:

1. Input token is taken from the **Coordinator** (not the end user).
2. Output token is received by the **Coordinator**.
3. Optional child-level min out may be 0; Coordinator enforces `step.minAmountOut` / global min.

**`step.data` ABI (v1 preferred):**

```text
// Opaque periphery payload built off-chain for this step only:
abi.encode(
  bytes commands,      // e.g. Universal Router commands including V4_SWAP (+ settle/take as required)
  bytes[] inputs,      // corresponding inputs; amountIn fields must be fillable or use OPEN_DELTA / balance patterns
  // Implementation plan MUST document the exact command templates for:
  //   - single hop exact-in
  //   - multi-hop exact-in
  // and how the Coordinator patches amountIn when balance-driven.
)
```

**Fallback (if implementors prefer a thinner surface):** a dedicated `UniswapV4ExactInExecutor` periphery owned by IndexedEx, wrapping Crane `V4Router` actions, registered under the same `AdapterKind`. Product law still forbids calling abstract `V4Router` without a public entry.

Implementation plan must pin **one** primary V4 call convention per deployment and test it hermetically (stub periphery or Crane-deployed executor).

### 5.6 Amount fill rules

| Step index | Input amount |
|------------|--------------|
| 0 | `amountIn` (after wrap if `ethIn`) |
| i > 0 | **Entire** Coordinator ERC-20 balance of `currentToken` immediately before the step |

Per-step child `minAmountOut` inside `data` should usually be `0` when the Coordinator’s `step.minAmountOut` is used, to avoid double semantics — either is allowed; both enforced if non-zero.

---

## 6. Ownership and allowlist admin

### 6.1 Owner powers

| Function | Behavior |
|----------|----------|
| `registerRouter(router, kind)` | Add to `AddressSet`; store `AdapterKind`; emit event; revert if zero address or unknown kind |
| `unregisterRouter(router)` | Remove from set; clear kind; emit event |
| `isRouterAllowed(router)` | View |
| `routerKind(router)` | View |
| `allowedRouterCount()` / `allowedRouterAt(i)` | View enumeration via set |

Uses Crane **`AddressSet` + `AddressSetRepo`**. Unbounded set size is acceptable for admin-curated lists.

### 6.2 Ownership model

- Deploy-time owner (Crane Ownable / MultiStepOwnable pattern as used by peer periphery).
- **No** user-facing fee switch required in v1 (fees live in child venues).
- Renounce ownership allowed; after renounce, allowlist is frozen (document operational expectation: configure allowlist before renounce on immutable deployments).

### 6.3 Security properties of allowlist

- Steps targeting non-allowed routers **revert** (`RouterNotAllowed`).
- Owner compromise can add malicious routers → treat owner as trusted admin (standard). Optional future: timelock — out of v1 scope.
- Coordinator must not `call` arbitrary addresses beyond allowlisted routers (and Permit2, WETH, tokens).

---

## 7. Architecture / package shape

### 7.1 Suggested layout

```text
contracts/routers/balancerV3-uniswapV4/
  BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_PRD.md          # this file
  (plan) *_IMPLEMENTATION_AND_TEST_PLAN.md                  # follow-on
  interfaces/
    IBalancerV3UniswapV4CoordinatorRouter.sol
  BalancerV3UniswapV4CoordinatorRouter*.sol                 # Target / Common / Repo as needed
  BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol
  adapters/                                                 # optional pure libs per AdapterKind
  TestBase_BalancerV3UniswapV4CoordinatorRouter.sol
```

### 7.2 Diamond vs single contract

Implementor choice:

- **Single contract** is acceptable for v1 size if it stays maintainable.
- **Diamond** if facet split helps (ExactIn facet, Admin facet, Adapter libs).

Either path must use CREATE3 + FactoryService; no `new` in production deploy paths.

### 7.3 Dependencies (immutables / aware repos)

- Permit2
- WETH
- (Optional) references for tests only: Balancer Vault, Uni PoolManager — Coordinator production code should not hardcode child router addresses except via allowlist storage.

---

## 8. Errors and events (normative minimum)

### 8.1 Errors

| Error | When |
|-------|------|
| `ExpiredDeadline` | `block.timestamp > deadline` |
| `EmptyRoute` | `steps.length == 0` |
| `RouterNotAllowed(address)` | step router not in set |
| `InvalidRouterKind` | register with bad kind / missing kind on dispatch |
| `TokenOutMismatch` | last step / final tokenOut inconsistency |
| `InvalidEthIn` / `InvalidEthOut` | eth flags disagree with tokens / msg.value |
| `InsufficientEth` | `msg.value < amountIn` when ethIn |
| `MinAmountOutNotMet(uint256 min, uint256 actual)` | global or per-step |
| `StepFailed(uint256 index)` or bubble child revert data | child call failed |
| `ZeroAddress` | admin / token |
| `InvalidStepData` | decode failure / callMode unsupported |
| `Permit2Failed` / standard Permit2 errors | funding |

### 8.2 Events

| Event | Fields (minimum) |
|-------|------------------|
| `RouterRegistered` | router, kind |
| `RouterUnregistered` | router |
| `RouteExecuted` | user, tokenIn, tokenOut, amountIn, amountOut, steps length |
| `StepExecuted` (optional) | index, router, tokenOut, amountOut |

---

## 9. Security considerations

1. **Reentrancy:** nonReentrant on entry; do not make untrusted external calls outside allowlisted children / token / WETH / Permit2.
2. **Approval griefing:** prefer amount-scoped allowances; document residual approval policy after each step.
3. **Malicious tokenOut reporting:** Coordinator must measure **balance deltas**, not trust child return values alone for slippage (return values may still be logged).
4. **Fee-on-transfer tokens:** v1 assumes standard ERC-20; FoT may break amount chaining — document unsupported unless tests prove otherwise.
5. **ETH return:** excess `msg.value` returned to user; never to owner.
6. **Owner allowlist:** trusted; compromise is critical.
7. **No nested unlock** across venues.
8. **Deadline** prevents stale routes; still subject to ordinary AMM MEV — not a MEV-protection product.

---

## 10. Testing expectations (production-first)

Follow `crane-testing` + `indexedex-testing`.

### 10.1 Required suites

| ID | Coverage |
|----|----------|
| T1 | Deploy Coordinator via CREATE3/FactoryService; owner registers routers |
| T2 | Reject step with non-allowlisted router |
| T3 | Stock Balancer single hop only (if stock deployed in test env) |
| T4 | Stock Balancer batch multi-hop as one step |
| T5 | SE Router single hop (pool and/or SE vault path) |
| T6 | SE Router batch path as one step |
| T7 | V4 Periphery single hop exact-in |
| T8 | V4 Periphery multi-hop exact-in as one step |
| T9 | Cross-venue: V4 → stock Balancer |
| T10 | Cross-venue: V4 → SE Router |
| T11 | Cross-venue: stock/SE → V4 |
| T12 | Global minAmountOut revert |
| T13 | Per-step minAmountOut revert |
| T14 | Permit2 funding happy path |
| T15 | ethIn wrap + first hop |
| T16 | ethOut unwrap + last hop |
| T17 | ethIn + ethOut end-to-end |
| T18 | Mid-route ethOut / ethIn invalid configs revert |
| T19 | Deadline expiry revert |
| T20 | Unregister router then step reverts |
| T21 | Chain-config matrix: allowlist subset still works for remaining venues |

### 10.2 Environments

- **Hermetic:** Crane Balancer stubs + Uni V4 port + SE TestBase chain where available.
- **Fork:** Base mainnet (and/or Robinhood 4663 if SE/V4 present) for live periphery addresses when hermetic periphery is insufficient.

### 10.3 Forbidden

- Mocking the Coordinator SUT
- Bypassing allowlist in production code paths
- Exact-out tests as product requirements

---

## 11. Definition of Done

1. PRD (this document) accepted.
2. Implementation + test plan written under the same directory.
3. Coordinator implements §4–§6 with Permit2 entry, allowlist admin, three adapter families.
4. Exact-in routes execute atomically across mixed venues with custody on Coordinator.
5. ETH first/last hop works per §4.7.
6. Test suites T1–T21 pass at the level the target chains support (subset documented if a venue is absent).
7. No `new` production deploys; CREATE3/FactoryService path covered by TestBase.
8. NatSpec + interface package under `contracts/routers/balancerV3-uniswapV4/` (and `contracts/interfaces/` if project convention requires).

---

## 12. Implementation plan notes (non-normative hints)

1. Start with adapters as internal libraries: `StockBalancerAdapter`, `SERouterAdapter`, `V4PeripheryAdapter`.
2. Pin Universal Router command templates for V4 exact-in in the plan (commands + input ABI + amount patching).
3. SE diamond: reuse existing interfaces from `contracts/interfaces/IBalancerV3StandardExchangeRouter*`.
4. Stock: use Crane `IRouter` / `IBatchRouter`.
5. Prefer measuring `balanceOf` before/after each step for slippage.
6. Gas: collapsing same-venue multi-hops into one batch/V4 multi-hop step is an off-chain responsibility.

---

## 13. Future work (explicitly deferred)

| Item | Notes |
|------|-------|
| Exact-out Coordinator | Separate product; multi-venue exact-out is non-trivial |
| On-chain quoter | View multicall / simulation helpers |
| Split / multi-path parallel routes | Aggregator-style |
| Fee-on-transfer / weird ERC-20 | Opt-in support |
| Timelocked allowlist | Governance hardening |
| Witness Permit2 binding full route | Optional SE-style witness for stronger intent binding |

---

## 14. Decision log (summary)

| Decision | Choice |
|----------|--------|
| Architecture | Coordinator calling child routers |
| Router identity | Address + owner `AddressSet` allowlist + `AdapterKind` |
| Venues | Stock Balancer (single + batch), SE Diamond (single + batch), Uni V4 Periphery |
| Amount type | Exact-in only |
| Route source | Off-chain |
| User funding | Permit2 only (+ ETH msg.value for ethIn) |
| ETH | First/last hop only |
| Multi-chain | One design; configure allowlist per chain |
| Slippage | Global required; per-step optional |
| Custody | Always Coordinator between hops |

---

**End of PRD v1.0**
