# PRD: Balancer V3 × Uniswap V4 Coordinator Router

**Name:** `BalancerV3UniswapV4CoordinatorRouter` (**frozen** production type/package name; short: **Coordinator**)  
**Date:** 2026-08-03  
**Status:** **v1.3 accepted product law** — implementation plan written ([`BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_IMPLEMENTATION_AND_TEST_PLAN.md`](./BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_IMPLEMENTATION_AND_TEST_PLAN.md)).  
**Package path:** `contracts/routers/balancerV3-uniswapV4/`  
**Package kind:** IndexedEx **Diamond periphery package** — DFPkg deploys a Coordinator diamond that sequences calls into **allowlisted** child routers (stock Balancer V3 Router, stock Balancer V3 BatchRouter, IndexedEx Balancer V3 Standard Exchange Diamond, Uniswap **Universal Router**). **Not** a vault package. **Deploy path = pure Crane** (CREATE3 + DFPkg / FactoryService / diamond package factory) — **not** the IndexedEx vault-registry manager path.

**Authority (normative):**

| Layer | Role |
|-------|------|
| **This PRD (v1.3)** | Product law for code and plan |
| **[Implementation plan](./BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_IMPLEMENTATION_AND_TEST_PLAN.md)** | Source of truth for implementors (layout, witness string, UR templates, phases, T1–T32 mapping) |
| Child routers | Execution venues only — Coordinator does **not** reimplement pool math |

**Related surfaces (integration targets):**

| Surface | Path / note |
|---------|-------------|
| IndexedEx SE Router (Diamond) | `contracts/protocols/dexes/balancer/v3/routers/` — exact-in single + batch with SE vault intermediation |
| Stock Balancer V3 Router | Crane: `lib/crane/contracts/external/balancer/v3/vault/contracts/Router.sol` (`IRouter.swapSingleTokenExactIn`) |
| Stock Balancer V3 BatchRouter | Crane: `…/BatchRouter.sol` (`IBatchRouter.swapExactIn`) |
| Uniswap V4 core / abstract router | Crane: `lib/crane/contracts/protocols/dexes/uniswap/v4/` (`V4Router`, `PoolManager`, actions) |
| **Uniswap Universal Router** | **Normative V4 call target** — `execute(commands, inputs, deadline)` with `V4_SWAP` (and related settle/take/sweep commands as required). **Not currently vendored under Crane** (as of this PRD). See **§7.4** — hermetic testing **requires a Crane Universal Router port** (or equivalent production-faithful deployable) as a **dependency** of this package’s DoD. |
| Crane AddressSet | `lib/crane/contracts/utils/collections/sets/AddressSetRepo.sol` |
| Crane MultiStepOwnable | Crane access patterns for two-step ownership |

**Standards (mandatory):**

- AGENTS.md / Crane: CREATE3 + DFPkg/FactoryService deploy, production-first tests, no mock of SUT
- **Pure Crane deploy** for this package (not vault registry / `indexedexManager.deploy*DFPkg`)
- Crane `AddressSet` / `AddressSetRepo` for allowed routers
- **Permit2-only** ERC-20 funding from the end user (no plain `transferFrom` user entry)
- Permit2 **witness** binds the **full route** intent (see §5.7)
- Exact-in only in v1 (exact-out deferred)
- Diamond + package deploy path

---

## 0. Terminology (normative)

| Term | Meaning |
|------|---------|
| **Coordinator** | This Diamond package — user-facing surface that owns custody between hops and calls child routers |
| **Child router** | An allowlisted address the Coordinator is permitted to call for a step |
| **AdapterKind** | Classification of a child router’s ABI surface used to decode `step.data` and dispatch the correct call |
| **Step** | One Coordinator hop: allowlisted child router + expected `tokenOut` + venue-encoded `data` |
| **Route** | Ordered list of steps built **off-chain**; executed atomically on-chain; may **interleave** any allowlisted adapters (e.g. V4 → SE batch → stock single → V4) |
| **Principal / payer** | Economic user who signed Permit2 and/or sent ETH (`msg.sender` on entry). Intermediate hops treat the **Coordinator diamond** as child-router `msg.sender` / payer |
| **Recipient** | Address that receives final `tokenOut` (or ETH if `ethOut`); may differ from principal |
| **Stock Balancer** | Official Balancer V3 `Router` and/or `BatchRouter` (no SE vault features) |
| **SE Router** | IndexedEx `BalancerV3StandardExchangeRouter` diamond (single + batch with SE vaults) |
| **Universal Router (UR)** | Uniswap periphery entry for V4 (and other Uni commands); **only** supported Uniswap call surface for this package |
| **First hop / last hop** | First and last steps of the route; only places native ETH may enter or leave |
| **Query** | Simulation path that returns expected `amountOut` **without** lasting state changes (see §4.8); must support **all** allowlisted adapter kinds including UR |
| **Amount ledger** | Coordinator-carried `amountForStep` for the hop input: step 0 uses `params.amountIn`; later steps use **prior step’s measured `deltaOut`**, not raw `balanceOf` (donation-safe) |
| **Single-root step** | One step encodes a **single funded input chain** into one expected `tokenOut` — no multi-root parallel split of Coordinator inventory inside a step |
| **DoD** | Definition of Done — package complete when §11 is satisfied |

---

## 1. Goal

Ship a **production-first multi-venue exact-in Coordinator Diamond** that:

1. Accepts an **off-chain-built** ordered route of steps (arbitrary interleaving of allowlisted venues).
2. Pulls user ERC-20 input **only** via **Permit2 SignatureTransfer with a full-route witness** (or **`msg.value`** when `ethIn`).
3. Executes each step by calling an **owner-allowlisted** child router using that router’s native exact-in API.
4. Keeps **intermediate token balances on the Coordinator** between hops.
5. Enforces a **global `minAmountOut`** on the final `tokenOut` before paying **`recipient`**.
6. Exposes **`queryExactIn`** for off-chain / on-chain simulation of the same step encodings.
7. Works on chains that deploy **any non-empty subset** of the supported child families by configuring the allowlist — **one Coordinator design, many chain configs**.

### 1.1 Canonical user story

```text
User wants: USDC → (Universal Router / V4) WETH → (SE batch) vaultShare → (stock Balancer) BPT
Recipient may be a vault or EOA different from signer.

Off-chain:
  1. Quote each leg; build RouteStep[] with child router addresses + encoded data
  2. User approves Permit2 for USDC (one-time)
  3. User signs Permit2 SignatureTransfer + witness over full SwapExactInParams (incl. recipient, steps)

On-chain (one tx):
  Coordinator.swapExactInWithPermit(params, permit, signature):
    - verify deadline; allowlist; ethIn == false
    - permitWitnessTransferFrom USDC → Coordinator (witness = full route incl. stepsHash)
    - amountForStep = amountIn (tracked ledger)
    - for each step: amount-scoped child funding; call child; amountForStep = delta(tokenOut)
    - require amountForStep >= minAmountOut
    - transfer amountOut to params.recipient (or unwrap WETH→ETH to recipient if ethOut)
```

---

## 2. Non-goals (v1)

1. **Exact-out** swaps (binary search / multi-venue exact-out solvers).
2. **On-chain route discovery / aggregation** (no best-path search on-chain). Query simulates a **provided** route only.
3. **Parallel split routes** (same input amount forked across venues or multi-root batch paths in one Coordinator step). Serial steps only; each step is a **single-root** chain (see §4.5 / §5.2).
4. **Reimplementing** Balancer Vault or Uniswap PoolManager swap math inside the Coordinator.
5. **Arbitrary external calls** to non-allowlisted addresses.
6. **Nested unlock** of Balancer Vault and Uni PoolManager in the same callback — legs are **sequential full child calls**.
7. **Mid-route native ETH** (WETH only between hops). ETH only on **first hop in** and/or **last hop out**.
8. **Any user ERC-20 funding path other than Permit2** (no pre-funded entry, no `transferFrom` from user, no allowance-based pull from user).
9. **Exact-out child APIs**, even if children expose them.
10. **Thin IndexedEx V4 executor as product target** — Universal Router is the call target; abstract `V4Router` is not a public entry.
11. **Frontend / off-chain router service** — out of scope except encoding contracts implied by this PRD.
12. **Fee-on-transfer / weird ERC-20 as a supported product** — pulls that yield less than expected **revert** `InvalidAmount(token, expected, actual)` (see §4.6 / §8.1). No FoT-aware “accept less and continue” math.

---

## 3. Locked decisions

| ID | Decision | Status |
|----|----------|--------|
| **D1** | Architecture = **coordinator of child routers** | LOCKED |
| **D2** | Exact-in only; exact-out out of scope | LOCKED |
| **D3** | Routes built **off-chain**; on-chain validates allowlist + balances + slippage | LOCKED |
| **D4** | Child routers identified by **address**; owner-managed **allowlist** via Crane **`AddressSet`** | LOCKED |
| **D5** | Owner registers each allowed router with an **`AdapterKind`** | LOCKED |
| **D6** | Adapter families: **StockBalancerV3Router**, **StockBalancerV3BatchRouter**, **IndexedExSERouter**, **UniswapV4UniversalRouter** | LOCKED |
| **D7** | Stock Balancer: **two kinds** kept separate (Router vs BatchRouter addresses) | LOCKED |
| **D8** | SE Router: **single** and **batch** via `StepCallMode` on one diamond kind | LOCKED |
| **D9** | Uniswap: call **chain Universal Router** only (`execute`); not abstract `V4Router` alone | LOCKED |
| **D10** | User ERC-20 funding: **Permit2 only** — no alternate funding entry | LOCKED |
| **D11** | Permit2 uses **witness style binding the full route** (`SwapExactInParams` commitment) | LOCKED |
| **D12** | Native **ETH** on **first hop in** and/or **last hop out** only | LOCKED |
| **D13** | Custody: principal → **Coordinator** → child → **Coordinator** → … → **`recipient`** | LOCKED |
| **D14** | Explicit **`recipient`** on every exact-in / query params struct | LOCKED |
| **D15** | Global `minAmountOut` required; optional per-step `minAmountOut` (0 = skip) | LOCKED |
| **D16** | Steps may **interleave** any allowlisted adapters freely (including multiple batch steps and mixed venues) | LOCKED |
| **D17** | One Coordinator product; per-chain allowlist may include any subset of families | LOCKED |
| **D18** | **Per-step amount-scoped** child funding: **Balancer/SE → Permit2 AllowanceTransfer**; **UR → ERC-20 approve**; clear residual after each step; no max-approve-once | LOCKED |
| **D19** | **`queryExactIn`** required for the full provided route; UR via **pinned V4 templates + V4 quoter** (D30) | LOCKED |
| **D20** | Access: **MultiStepOwnable** for allowlist admin | LOCKED |
| **D21** | Deploy as **Diamond + DFPkg** via **pure Crane** CREATE3 / FactoryService / diamond package factory — **not** vault registry | LOCKED |
| **D22** | Whole tx reverts on any step failure; no partial fill | LOCKED |
| **D23** | Deadline checked at Coordinator entry (and forwarded into child calls where APIs require it) | LOCKED |
| **D24** | Hermetic tests require a **production-faithful Universal Router** deploy path (Crane port or vendored deployable) — see §7.4 | LOCKED |
| **D25** | ETH-in and ERC-20-in are **separate execute entries**: `swapExactInWithPermit` requires `ethIn == false`; `swapExactInEth` is the only `ethIn == true` path | LOCKED |
| **D26** | **Tracked amount ledger** for hop inputs (not raw `balanceOf` chaining) — donation-safe | LOCKED |
| **D27** | Permit2 witness: **gas-efficient static EIP-712 struct** + **`stepsHash = keccak256(abi.encode(steps))`** (see §5.7) | LOCKED |
| **D28** | Each step is **single-root** (no multi-root parallel batch funding); product expectation: step *i* `tokenOut` funds step *i+1* input; **no Coordinator decode check** that child `tokenIn == currentToken` — trust builder; deep path validity delegated to child routers | LOCKED |
| **D29** | **No hard on-chain max** `steps.length` — gas is the natural bound | LOCKED |
| **D30** | UR **`queryExactIn`**: compose **Uniswap V4 quoter** for **pinned V4-only UR command templates**; other UR command sets **unsupported for query** (and may be unsupported for execute if not in the pin set — plan pins the allowed templates) | LOCKED |
| **D31** | `registerRouter`: Crane **`AddressSetRepo._add` (idempotent)** + store/overwrite `AdapterKind`; no “must unregister first” | LOCKED |
| **D32** | Allowlist seed: **optional** `(router, kind)[]` in **`PkgArgs` → postDeploy**; later mutations owner-only | LOCKED |
| **D33** | Final payout = **ledger `amountOut` only**; residual inventory may remain; **owner-only `rescueTokens` / `rescueETH`** (or equivalent), **nonreentrant** and sharing the **same reentrancy lock** as execute so rescue **cannot** run inside a swap | LOCKED |
| **D34** | User ERC-20 pull shortfall (e.g. fee-on-transfer) → **`InvalidAmount(token, expected, actual)`** | LOCKED |
| **D35** | Production name frozen: **`BalancerV3UniswapV4CoordinatorRouter`** (DFPkg, FactoryService, interface, TestBase prefixes) | LOCKED |

---

## 4. Product model

### 4.1 Why a Coordinator (not a new AMM)

Balancer V3 and Uniswap V4 already expose production swap surfaces with their own unlock/accounting:

- Balancer: `Vault.unlock` + router hooks; Permit2 pull from `sender`; `sendTo` payout to `sender`.
- Uniswap V4: `PoolManager.unlock` + action encoding; public composition via **Universal Router** (`V4_SWAP`, settle/take/sweep, etc.).

The Coordinator’s job is **custody + sequencing + allowlisting + query**, not pricing.

### 4.2 Multi-chain configuration

| Chain situation | Allowlist example |
|-----------------|-------------------|
| Balancer stock only | Stock `Router` + `BatchRouter` |
| IndexedEx SE only | SE Diamond |
| Uniswap V4 only | Universal Router |
| Full stack | All of the above |

Missing venues are **not registered**. Steps that target unregistered routers **revert**.

### 4.3 AdapterKind (normative)

```text
registerRouter(address router, AdapterKind kind)   // onlyOwner (MultiStepOwnable)
unregisterRouter(address router)
```

| `AdapterKind` | Expected child surface | Notes |
|---------------|------------------------|-------|
| `StockBalancerV3Router` | `IRouter.swapSingleTokenExactIn` | Single contract kind |
| `StockBalancerV3BatchRouter` | `IBatchRouter.swapExactIn` | Separate address from stock Router |
| `IndexedExSERouter` | SE Diamond single + batch exact-in | `step.data` leading `StepCallMode` selects API |
| `UniswapV4UniversalRouter` | `IUniversalRouter.execute(commands, inputs, deadline)` | Output must land on Coordinator |

**Rationale for two stock kinds:** stock Balancer ships **two contracts**. SE ships both APIs on **one diamond**.

### 4.4 Step and route types (normative)

```solidity
enum AdapterKind {
    StockBalancerV3Router,
    StockBalancerV3BatchRouter,
    IndexedExSERouter,
    UniswapV4UniversalRouter
}

enum StepCallMode {
    SingleExactIn,   // 0 — swapSingleTokenExactIn-shaped (SE)
    BatchExactIn     // 1 — swapExactIn path-shaped (SE)
}

struct RouteStep {
    address router;       // must be allowlisted; kind from storage
    address tokenOut;     // expected token balance increase after this step
    uint256 minAmountOut; // 0 = no per-step check; else require delta(tokenOut) >= min
    bytes data;           // adapter-specific encoding (see §5)
}

struct SwapExactInParams {
    address recipient;    // final payout address (required; non-zero)
    address tokenIn;      // ERC-20; WETH address when ethIn = true
    uint256 amountIn;
    address tokenOut;     // final token; must equal last step.tokenOut (WETH if ethOut)
    uint256 minAmountOut; // global final slippage
    uint256 deadline;
    bool ethIn;           // msg.value funds first hop (wrap to WETH on Coordinator)
    bool ethOut;          // unwrap final WETH → ETH to recipient
    RouteStep[] steps;
}
```

**Entry points (normative — two execute surfaces + query):**

```text
/// Execute — ERC-20 in via Permit2 full-route witness. Requires ethIn == false.
function swapExactInWithPermit(
    SwapExactInParams calldata params,
    ISignatureTransfer.PermitTransferFrom calldata permit,
    bytes calldata signature
) external payable returns (uint256 amountOut);

/// Execute — native ETH in only. Requires ethIn == true. No ERC-20 Permit2.
function swapExactInEth(
    SwapExactInParams calldata params
) external payable returns (uint256 amountOut);

/// Query / simulate the same route encoding without lasting external effects (see §4.8)
function queryExactIn(
    SwapExactInParams calldata params
) external returns (uint256 amountOut);
```

**Strict funding law:**

- There is **no** `swapExactIn` that pulls ERC-20 from the user via `transferFrom` or open allowance.
- **`swapExactInWithPermit`:** require `ethIn == false`; permit covers `tokenIn` / `amountIn`; **witness must match** full `params` (see §5.7). Revert if `ethIn == true` (`InvalidEthIn`).
- **`swapExactInEth`:** require `ethIn == true` and `msg.value >= amountIn`; wrap to WETH on Coordinator. No user ERC-20 Permit2. Revert if `ethIn == false`.

### 4.5 Execution algorithm (normative)

```text
1. require(block.timestamp <= deadline)
2. require(params.recipient != address(0))
3. require(steps.length >= 1)   // no hard upper bound (D29)
4. require(last.tokenOut == tokenOut)  // if ethOut, tokenOut is WETH and last.tokenOut is WETH
5. For each step: require(isAllowedRouter(step.router))
6. Fund Coordinator:
     if ethIn (swapExactInEth only):
       require(msg.value >= amountIn); wrap amountIn → WETH; refund excess ETH to msg.sender
     else (swapExactInWithPermit only):
       Permit2 permitWitnessTransferFrom(tokenIn, amountIn → Coordinator, witness=route)
7. currentToken = ethIn ? WETH : tokenIn
8. amountForStep = amountIn   // tracked ledger seed (not balanceOf)
9. For i, step in steps:
     a. require amountForStep > 0
     b. balBefore = balance(step.tokenOut)
     c. _approveChildForStep(step, currentToken, amountForStep)  // amount-scoped only (see §4.6)
     d. Dispatch AdapterKind(step.router); child sees Coordinator as msg.sender/payer;
        patch child exactAmountIn / settle amount from amountForStep (not full balanceOf);
        child must deliver step.tokenOut to Coordinator
     e. _clearChildAllowance(step, currentToken)  // residual → 0
     f. deltaOut = balance(step.tokenOut) - balBefore
     g. if step.minAmountOut != 0: require deltaOut >= step.minAmountOut
     h. currentToken = step.tokenOut
     i. amountForStep = deltaOut   // next hop input = this hop’s measured out (D26)
10. amountOut = amountForStep after last step  // equals final delta chain; still verify payout balance
11. require amountOut >= minAmountOut
    // Prefer also require IERC20(tokenOut).balanceOf(Coordinator) >= amountOut before transfer
12. if ethOut: unwrap amountOut WETH → ETH; send to params.recipient
    else: safeTransfer tokenOut amountOut → params.recipient
13. Success does **not** sweep residuals; dust / donated tokens may remain on the diamond (owner rescue only — §6.4)
```

**Interleaving:** any sequence of allowlisted kinds is valid, e.g.

```text
[UR V4] → [SE Batch] → [Stock Single] → [UR V4] → [Stock Batch]
```

Each element is one Coordinator step with its own `router` + `data`.

**Step chaining product law (D28):**

- Off-chain builders **must** construct routes where the economic input of step *i+1* is the `tokenOut` of step *i* (first step input is `tokenIn` / WETH after wrap).
- The Coordinator **does not** enforce on-chain that decoded child `tokenIn` equals `currentToken` (trust builder). Invalid or mismatched child encodings revert at the child (or produce wrong deltas / minOut failures).
- The Coordinator **does not** re-validate deep venue path graphs (pool hops inside `step.data`).
- **Single-root only:** a step must not ask the Coordinator to fund multiple independent batch path roots from one inventory split. Multi-hop **within** one child call (one funded root → one measured `tokenOut`) is allowed when the child API supports it.

**Donation / residual:** pre-existing or donated balances of `currentToken` are **not** spent (ledger uses `amountForStep`). Donated `step.tokenOut` before a step still inflates `deltaOut` if present at `balBefore` measurement — measure delta correctly; do not use absolute balance as the hop input for the next step beyond `deltaOut`.

### 4.6 Custody and per-step allowances (normative)

| Direction | Mechanism |
|-----------|-----------|
| User → Coordinator (ERC-20) | Permit2 **SignatureTransfer** + **full-route witness** only (`swapExactInWithPermit`). After pull: require received ≥ `amountIn` else **`InvalidAmount(tokenIn, amountIn, actual)`** (D34). |
| User → Coordinator (ETH) | `msg.value` + wrap to WETH (`swapExactInEth` only) |
| Coordinator → Stock Balancer / SE child | Child pulls via **Permit2** from **Coordinator** as `sender`. Coordinator sets **amount-scoped Permit2 AllowanceTransfer** (`amountForStep`) for `(token, child router)` **immediately before** the call and **clears residual to 0** after. |
| Coordinator → Universal Router | **ERC-20 `approve`** amount-scoped to `amountForStep` for the UR address (UR settle from Coordinator balance / allowance as the step encoding requires); residual approve **0** after step |
| Coordinator → recipient | ERC-20 transfer or ETH send to **`params.recipient`** for **ledger final `amountOut` only** (not full `balanceOf`) |
| Owner rescue | See §6.4 — residual inventory only; never nested in swap |

**Forbidden:** infinite / max `type(uint160).max` standing Permit2 allowances or ERC-20 approvals left on child routers after a successful step.

### 4.7 ETH rules (normative)

| Case | Behavior |
|------|----------|
| `ethIn` | `tokenIn` is WETH address; `msg.value >= amountIn`; wrap on Coordinator; excess ETH → **`msg.sender`** (principal), not recipient |
| Mid-route | Native ETH **forbidden** as intermediate `tokenOut` |
| `ethOut` | Final `tokenOut` is WETH; unwrap; ETH → **`params.recipient`** |
| Both | Allowed (ETH → … → ETH) |

Child hops always see **WETH ERC-20** for ether-value legs after Coordinator wrap; set child `wethIsEth = false` for mid-route encodings.

### 4.8 `queryExactIn` (normative)

**Purpose:** return the expected final `amountOut` for a provided route **without** lasting state changes to user balances, Coordinator inventory, or child AMM state.

**Requirements:**

1. Accepts the same `SwapExactInParams` shape as execution (including `recipient`, steps, eth flags).
2. Does **not** require a user Permit2 signature or `msg.value` funding (eth flags describe the *simulated* route only).
3. Must not leave net ERC-20/ETH changes on the Coordinator or mutate pool/vault state permanently.
4. **Must support every allowlisted `AdapterKind`, including `UniswapV4UniversalRouter`** for the **pinned V4 template set** (D19, D30). Interleaved stock / SE / UR routes are queryable end-to-end when each step uses a supported encoding.
5. **Per-adapter query strategy (normative):**
   - **Stock Balancer / SE:** use native child **query** APIs (`querySwap*` / batch query equivalents).
   - **Universal Router:** **no** full opaque `execute` simulation. Product law pins **V4 exact-in command templates** (single-hop and multi-hop as plan documents). `queryExactIn` **composes Uniswap V4 quoter** (or Crane-equivalent production quoter) against those templates and the amount ledger. UR `step.data` that is **not** a pinned template → revert `InvalidStepData` or `UnsupportedQuery` (plan picks one error; must be documented).
6. Off-chain-only `eth_call` of `swapExactIn*` is **not** a substitute for on-chain `queryExactIn`.
7. Slippage fields may be ignored for the numeric result, but invalid routes / allowlist / encoding still revert.
8. Return value: final `amountOut` in `tokenOut` raw units (WETH units even if `ethOut` would unwrap on execute), following the same **amount ledger** chaining as execute.

**Non-requirement:** bit-exact match to every child query edge case under hooks is best-effort; tests must assert **execute ≈ query** on golden paths within documented tolerance (prefer exact wei equality where children allow).

---

## 5. Step data encodings (normative)

Amounts filled on-chain (`exactAmountIn`) are **overwritten** by the Coordinator from the **amount ledger**; off-chain may pass `0` as placeholder. Encoded `tokenIn` / path roots are **off-chain responsibilities** — Coordinator does **not** require-match them to `currentToken` (D28).

### 5.1 Stock Balancer — single (`StockBalancerV3Router`)

```solidity
IRouter.swapSingleTokenExactIn(
  pool, tokenIn, tokenOut, exactAmountIn, minAmountOut, deadline, wethIsEth, userData
)
```

**`step.data`:**

```text
abi.encode(
  address pool,
  address tokenIn,       // builder should set = currentToken; not Coordinator-enforced
  address tokenOut,      // should equal step.tokenOut for coherent routes
  uint256 minAmountOut,  // child-level; often 0 if step.minAmountOut used
  bool wethIsEth,        // mid-route: false
  bytes userData
)
```

### 5.2 Stock Balancer — batch (`StockBalancerV3BatchRouter`)

```solidity
IBatchRouter.swapExactIn(paths, deadline, wethIsEth, userData)
```

**Single-root only (D28):** v1 does **not** support multi-root parallel batch paths that would split Coordinator inventory across independent path roots in one step. A batch step encodes **one funded chain** (one economic input of `currentToken` / `amountForStep`) producing **`step.tokenOut`**. Multi-hop steps *inside* that single path are fine. Coordinator overwrites the funded path’s `exactAmountIn` from the amount ledger and measures **balance delta** of `step.tokenOut` only.

**`step.data`:**

```text
abi.encode(
  SwapPathExactAmountIn[] paths,  // single-root funding; exactAmountIn patched from amountForStep
  bool wethIsEth,
  bytes userData
)
```

Types: Balancer `SwapPathStep` / `SwapPathExactAmountIn`.

### 5.3 IndexedEx SE — single (`IndexedExSERouter` + `StepCallMode.SingleExactIn`)

```solidity
swapSingleTokenExactIn(
  pool, tokenIn, tokenInVault, tokenOut, tokenOutVault,
  exactAmountIn, minAmountOut, deadline, wethIsEth, userData
)
```

**`step.data`:**

```text
abi.encode(
  uint8 callMode,           // 0 = SingleExactIn
  address pool,
  address tokenIn,
  address tokenInVault,
  address tokenOut,
  address tokenOutVault,
  uint256 minAmountOut,
  bool wethIsEth,
  bytes userData
)
```

### 5.4 IndexedEx SE — batch (`IndexedExSERouter` + `StepCallMode.BatchExactIn`)

```solidity
swapExactIn(SESwapPathExactAmountIn[] paths, deadline, wethIsEth, userData)
```

**`step.data`:**

```text
abi.encode(
  uint8 callMode,           // 1 = BatchExactIn
  SESwapPathExactAmountIn[] paths,
  bool wethIsEth,
  bytes userData
)
```

### 5.5 Uniswap Universal Router (`UniswapV4UniversalRouter`)

**Call:**

```solidity
IUniversalRouter.execute(bytes commands, bytes[] inputs, uint256 deadline)
```

**Normative capability for each UR step:**

1. Input taken from **Coordinator** (not end user).
2. Output **`step.tokenOut`** received by **Coordinator** (UR `ADDRESS_THIS` / sweep-to-Coordinator patterns as documented in the implementation plan).
3. **v1 execute + query** are defined for **pinned V4 exact-in templates** only (commands + input layout fixed in the implementation plan: `V4_SWAP` + required settle/take/sweep). Arbitrary other UR commands are **out of v1 product support** even if bytes would execute — non-template encodings revert at dispatch/query (`InvalidStepData` / plan error).

**`step.data`:**

```text
abi.encode(
  bytes commands,
  bytes[] inputs
  // Coordinator supplies deadline = params.deadline
  // Implementation plan: amountIn patching / OPEN_DELTA for ledger-driven hops; template catalog for queryExactIn (V4 quoter)
)
```

### 5.6 Amount fill rules (tracked ledger — D26)

| Step index | Input amount (`amountForStep`) |
|------------|--------------------------------|
| 0 | `params.amountIn` (after wrap if `ethIn`) |
| i > 0 | **Prior step’s measured `deltaOut`** of that step’s `tokenOut` |

Do **not** use raw `balanceOf(currentToken)` as the hop input (donation-safe). Child call encodings are patched with this ledger amount.

### 5.7 Permit2 full-route witness (normative — gas-efficient)

User ERC-20 funding **must** use Permit2 `permitWitnessTransferFrom` with a witness that commits to the **entire** route intent (not merely token/amount).

**Gas design (D27):** EIP-712 witness data is **static-sized only**. Dynamic `RouteStep[]` is **not** inlined into the EIP-712 encode; it is bound once via `stepsHash`. That minimizes witness hashing cost vs hashing nested dynamic arrays inside EIP-712.

**Normative witness fields (struct order for typehash):**

```text
// Logical struct (Solidity names illustrative)
// stepsHash = keccak256(abi.encode(params.steps))  // once; binds full RouteStep[] including data bytes
Witness(
  address recipient,
  address tokenIn,
  uint256 amountIn,
  address tokenOut,
  uint256 minAmountOut,
  uint256 deadline,
  bool ethIn,
  bool ethOut,
  bytes32 stepsHash
)
```

**Requirements:**

1. Fixed Coordinator constants exposed via getters: `WITNESS_TYPE_STRING()` / `WITNESS_TYPEHASH()` (SE-router style). Exact type-string characters finalized in implementation plan **must** match this field list and order.
2. On execute: compute `stepsHash = keccak256(abi.encode(params.steps))`; build witness from `params` + `stepsHash`; `permitWitnessTransferFrom` must verify against signed witness.
3. Permit owner is **`msg.sender`** (principal); `recipient` is separate and included in the witness.
4. Permit `requestedAmount` / permitted token must match `tokenIn` / `amountIn`. After transfer, if `balance` increase (or measured received) `< amountIn` → **`InvalidAmount(tokenIn, amountIn, actual)`**.
5. Mismatch between signed witness and executed `params` **reverts**.

**ETH-in:** no user ERC-20 permit; witness rules do not apply to `swapExactInEth`.

---

## 6. Ownership and allowlist admin

### 6.1 Owner powers (MultiStepOwnable)

| Function | Behavior |
|----------|----------|
| `registerRouter(router, kind)` | `AddressSetRepo._add` (**idempotent** — already-present is success, D31); store/overwrite `AdapterKind`; emit `RouterRegistered` (including re-register with new kind); revert on zero address / invalid kind |
| `unregisterRouter(router)` | Remove via AddressSet; clear kind; emit `RouterUnregistered` (idempotent remove preferred if repo supports it) |
| `isRouterAllowed(router)` | View |
| `routerKind(router)` | View |
| `allowedRouterCount()` / `allowedRouterAt(i)` | View enumeration |
| `rescueTokens(token, to, amount)` / `rescueETH(to, amount)` | Owner-only residual recovery — **§6.4** |

Uses Crane **`AddressSet` + `AddressSetRepo`** (do not invent a custom set).

### 6.2 Ownership model

- **MultiStepOwnable** (Crane): two-step transfer; only owner mutates allowlist and rescues.
- No Coordinator swap fee in v1.
- Renounce allowed; allowlist freezes after renounce — configure before renounce on immutable deploys. Rescue also freezes if renounced (no owner).

### 6.3 Allowlist security

- Non-allowed step routers → `RouterNotAllowed`.
- Owner is trusted for allowlist integrity and rescue.
- Coordinator external calls limited to: allowlisted routers, Permit2, WETH, ERC-20 tokens touched by the route (plus owner rescue transfers).

### 6.4 Owner token / ETH rescue (normative — D33)

**Purpose:** recover residual inventory (dust, donations, failed partial external transfers that still left balances) without making success-path sweeps part of swap.

| Rule | Requirement |
|------|-------------|
| Access | **onlyOwner** (MultiStepOwnable) |
| Scope | Arbitrary ERC-20 held by Coordinator and/or ETH balance; plan may also allow rescue of residual Permit2 allowances if needed |
| Reentrancy | **Same global lock** as `swapExactInWithPermit` / `swapExactInEth` / `queryExactIn` (if query locks). Rescue **must not** be callable while a swap/query holds the lock — and swap/query must take the lock so a child callback **cannot** re-enter rescue mid-route |
| Not in swap path | Rescue is a **separate** admin entry; never invoked by execute algorithm |
| Events | e.g. `TokensRescued(token, to, amount)` / `ETHRescued(to, amount)` |

### 6.5 Optional deploy-time allowlist seed (normative — D32)

`PkgArgs` **may** include `InitialRouter[]` (`address router`, `AdapterKind kind`). DFPkg **postDeploy** registers each via the same logic as `registerRouter` (idempotent add + kind store). Empty array = empty allowlist after deploy; owner can register later.

---

## 7. Architecture / package shape

### 7.1 Layout

```text
contracts/routers/balancerV3-uniswapV4/
  BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_PRD.md
  BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_IMPLEMENTATION_AND_TEST_PLAN.md
  interfaces/
    IBalancerV3UniswapV4CoordinatorRouter.sol   # PkgInit/PkgArgs if DFPkg needs them on interface
  facets / targets / repos / common as Crane diamond pattern requires
  BalancerV3UniswapV4CoordinatorRouterDFPkg.sol
  BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol
  adapters/   # Stock / SE / UR libs
  TestBase_BalancerV3UniswapV4CoordinatorRouter.sol
```

### 7.2 Diamond + DFPkg (normative)

- **Must** deploy as a **Diamond** via **DFPkg** + CREATE3 / FactoryService using the **pure Crane** package path (`create3Factory` / `diamondPackageFactory` / package helpers).
- **Must not** use IndexedEx vault registry (`indexedexManager.deploy*DFPkg` / `IVaultRegistryDeployment`) — this is **not** a vault package (D21).
- Suggested facet split (non-normative): ExactIn execution, Query, Admin/Allowlist/Rescue, Permit2 witness constants.
- `PkgInit` / `PkgArgs` on the **interface**, not the contract (Crane rule): e.g. initial owner, Permit2, WETH, optional `InitialRouter[]`, and any V4 quoter address required for `queryExactIn`.

### 7.3 Dependencies (immutables / aware)

- Permit2
- WETH
- V4 quoter (or equivalent) for UR query composition — configure via PkgArgs / aware repo as plan defines
- Child routers: **not** hard-coded as immutables — allowlist only; optional seed via `PkgArgs` → postDeploy (D32); owner may register later

### 7.4 Universal Router port gap (normative dependency)

**Current monorepo state (2026-08-03):** Crane includes Uniswap V4 core/periphery building blocks (`V4Router` abstract, `PoolManager`, etc.) but **does not** include a vendored **Universal Router** implementation under `lib/crane`.

**DoD implication:**

1. Hermetic Coordinator tests that exercise `UniswapV4UniversalRouter` steps **require** a production-faithful Universal Router deployable in the test graph.
2. That is a **blocking dependency**: either  
   - **(Preferred)** Port Universal Router into Crane (`crane-porting` skill; hermetic + fork verification), **or**  
   - Vendor a pinned UR under an approved Crane external path with the same verification bar.
3. Fork tests against live chain UR addresses are **necessary but not sufficient** for DoD without a hermetic path for CI.
4. Coordinator production code calls **whatever address** is allowlisted as `UniswapV4UniversalRouter` — the port is for **deploy/test parity**, not a second adapter kind.

---

## 8. Errors and events (normative minimum)

### 8.1 Errors

| Error | When |
|-------|------|
| `ExpiredDeadline` | `block.timestamp > deadline` |
| `EmptyRoute` | `steps.length == 0` |
| `RouterNotAllowed(address)` | step router not in set |
| `InvalidRouterKind` | bad/missing kind on register or dispatch |
| `TokenOutMismatch` | final token / last step inconsistency |
| `InvalidRecipient` | `recipient == address(0)` |
| `InvalidEthIn` / `InvalidEthOut` | eth flags disagree with tokens / entry |
| `InsufficientEth` | `msg.value < amountIn` when ethIn |
| `MinAmountOutNotMet(uint256 min, uint256 actual)` | global or per-step |
| `StepFailed(uint256 index)` or bubbled child revert | child call failed |
| `ZeroAddress` | admin / token |
| `InvalidStepData` | decode / unsupported callMode |
| `InvalidPermitWitness` / Permit2 errors | funding / witness mismatch |
| `PermitRequired` | ERC-20 execute attempted without valid permit path |
| `InvalidAmount(address token, uint256 expected, uint256 actual)` | pull/shortfall (e.g. FoT); other amount mismatches plan may reuse |
| `UnsupportedQuery` (optional alias of `InvalidStepData`) | UR step not in pinned V4 template set for query |

### 8.2 Events

| Event | Fields (minimum) |
|-------|------------------|
| `RouterRegistered` | router, kind |
| `RouterUnregistered` | router |
| `RouteExecuted` | principal, recipient, tokenIn, tokenOut, amountIn, amountOut, stepCount |
| `StepExecuted` (optional) | index, router, tokenOut, amountOut |
| `TokensRescued` | token, to, amount |
| `ETHRescued` | to, amount |

---

## 9. Security considerations

1. **Reentrancy:** one shared lock on **execute**, **query** (if external calls), and **owner rescue** — rescue must not be nestable inside swap/query.
2. **Per-step allowances only** (Permit2 for Balancer/SE; ERC-20 approve for UR); clear residuals after each step.
3. **Balance-delta slippage** — do not trust child return values alone for final/step mins; use measured `deltaOut`.
4. **Amount ledger** — next hop spends prior `deltaOut`, not full `balanceOf`, so donated input tokens are not auto-spent. Donations of `tokenOut` still affect that step’s measured delta if timed before `balBefore` (standard balance-delta caveat).
5. **Witness binds full route** (static EIP-712 + `stepsHash`) — prevents permit reuse across alternate step lists.
6. **Recipient ≠ principal** — principal still funds; recipient receives; no claim that recipient authorized the spend.
7. **Excess ETH** on `ethIn` returns to **principal** (`msg.sender`), not recipient.
8. **Owner allowlist + rescue** compromise is critical (can drain residuals; cannot steal in-flight user funds mid-tx if lock is correct).
9. **No nested multi-venue unlock**.
10. **UR templates only** — reduce opaque command surface for both execute and query.
11. **No on-chain tokenIn / deep path validation** — builders and child routers bear encoding correctness.
12. **FoT / short pull** reverts via `InvalidAmount` — no silent underfunding.
13. Not a MEV-protection product.

---

## 10. Testing expectations (production-first)

Follow `crane-testing` + `indexedex-testing`.

### 10.1 Required suites

| ID | Coverage |
|----|----------|
| T1 | Deploy Coordinator **Diamond DFPkg** via CREATE3/FactoryService; MultiStepOwnable owner registers routers |
| T2 | Reject non-allowlisted step router |
| T3 | Stock single hop |
| T4 | Stock batch hop (single-root multi-hop path if used; multi-root unsupported) |
| T5 | SE single hop (pool and/or SE vault) |
| T6 | SE batch hop |
| T7 | Universal Router V4 single hop |
| T8 | Universal Router V4 multi-hop commands as one step |
| T9 | Interleaved multi-venue route (≥3 steps, ≥2 families) |
| T10 | Multiple single-root batch steps interleaved with other adapters |
| T11 | Global minAmountOut revert |
| T12 | Per-step minAmountOut revert |
| T13 | Permit2 + **full-route witness** happy path |
| T14 | Witness mismatch reverts |
| T15 | No non-Permit2 ERC-20 execute path |
| T16 | ethIn wrap; excess ETH to principal |
| T17 | ethOut unwrap to **recipient** |
| T18 | ethIn + ethOut; recipient ≠ principal |
| T19 | `recipient == 0` reverts |
| T20 | Deadline expiry |
| T21 | Unregister then step reverts |
| T22 | Allowlist subset matrix (stock-only / SE-only / UR-only) |
| T23 | **Per-step allowance:** Balancer/SE Permit2 amount-scoped; UR ERC-20 approve amount-scoped; residual cleared |
| T24 | **`queryExactIn`** for stock, SE, and **pinned UR V4 templates** (incl. interleaved); no lasting inventory change; golden path query≈execute; non-template UR reverts |
| T25 | MultiStepOwnable transfer ownership flow for admin |
| T26 | **Amount ledger / donation:** donated `currentToken` is not spent on next hop; hop input = prior `deltaOut` |
| T27 | **Entry split:** `swapExactInWithPermit` reverts when `ethIn==true`; `swapExactInEth` reverts when `ethIn==false` |
| T28 | Pure Crane DFPkg deploy (no vault-registry path) |
| T29 | **Idempotent** `registerRouter` (AddressSetRepo._add); re-register updates kind |
| T30 | Optional **PkgArgs initial routers** seed in postDeploy |
| T31 | Payout is **ledger amountOut only**; residual remains; owner **rescue** works; rescue **reverts when reentered from swap** (shared lock) |
| T32 | FoT / short pull → **`InvalidAmount(token, expected, actual)`** |

### 10.2 Environments

- **Hermetic:** Crane Balancer + Uni V4 + **Universal Router port** + SE TestBase.
- **Fork:** live Universal Router + Balancer + SE where deployed (e.g. Base).

### 10.3 Forbidden

- Mock Coordinator SUT / DFPkg / allowlist admin diamond
- Bypassing allowlist
- Exact-out as product requirements
- Max-approve-once as the production allowance policy
- Spending full `balanceOf` as hop input (use amount ledger)
- Multi-root parallel batch funding as a supported step shape

---

## 11. Definition of Done

1. PRD (this document) accepted.
2. Implementation + test plan written under the same directory — **done** ([plan](./BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_IMPLEMENTATION_AND_TEST_PLAN.md)).
3. Coordinator **Diamond DFPkg** implements §4–§6 (execute, query, allowlist, rescue, MultiStepOwnable, gas-efficient witness Permit2, recipient, per-step allowances).
4. Universal Router + V4 quoter dependencies for hermetic tests satisfied per §7.4 / §4.8.
5. Exact-in interleaved multi-venue routes execute atomically with custody on Coordinator and **ledger** payout to `recipient`.
6. ETH first/last hop works per §4.7.
7. `queryExactIn` works per §4.8 (incl. pinned UR → V4 quoter).
8. Suites T1–T32 pass for supported venues (document gaps only if a chain lacks a venue).
9. No `new` production deploys; pure Crane CREATE3/FactoryService/TestBase covered (not vault registry).
10. NatSpec + interfaces landed under package / `contracts/interfaces/` per project convention; type name **`BalancerV3UniswapV4CoordinatorRouter`**.

---

## 12. Implementation plan notes (non-normative)

1. Adapter libs: `StockBalancerAdapter`, `SERouterAdapter`, `UniversalRouterAdapter`.
2. **Pin UR V4 exact-in templates** (single + multi-hop) shared by execute + query; amount patching from the **amount ledger**.
3. Port or vendor Universal Router into Crane **before** or **in parallel with** Coordinator hermetic UR tests; wire **V4 quoter** for query.
4. SE interfaces: `contracts/interfaces/IBalancerV3StandardExchangeRouter*`.
5. Stock: Crane `IRouter` / `IBatchRouter`.
6. Witness: static `Witness(...)` field list in §5.7; `stepsHash = keccak256(abi.encode(steps))`; getters on diamond; finalize exact type-string chars in plan (gas-efficient static EIP-712).
7. Query: stock/SE native query; UR → V4 quoter over pinned templates only.
8. Child funding: Permit2 AllowanceTransfer for Balancer/SE; `SafeERC20.forceApprove` amount then 0 for UR.
9. Shared reentrancy guard across execute / query / rescue.
10. TestBase inherits CraneTest (+ IndexedexTest only if SE stack is needed for child venues, not for Coordinator deploy itself).

---

## 13. Future work (deferred)

| Item | Notes |
|------|-------|
| Exact-out Coordinator | Separate product |
| On-chain route discovery | Aggregator |
| Parallel split routes | Multi-path fan-out of one input |
| Fee-on-transfer “accept less” paths | v1 reverts `InvalidAmount` only |
| Timelocked allowlist | Governance hardening |
| Thin V4 executor alternative | Not needed if UR port exists |
| Arbitrary UR commands beyond pinned V4 templates | Out of v1 |

---

## 14. Decision log (summary)

| Topic | Choice |
|-------|--------|
| Architecture | Coordinator diamond calling child routers |
| Deploy | Diamond + DFPkg + CREATE3 — **pure Crane**, not vault registry |
| Ownership | MultiStepOwnable |
| Router identity | Address + AddressSet allowlist + AdapterKind |
| Stock kinds | **Two** (Router vs BatchRouter) |
| SE | One kind; Single vs Batch via `StepCallMode` |
| Uniswap | **Universal Router** only |
| Route shape | Free interleaving; **single-root** steps; step *i* out funds step *i+1* |
| Amount type | Exact-in only |
| Hop input | **Tracked amount ledger** (prior `deltaOut`), not full `balanceOf` |
| User ERC-20 funding | **Permit2 only** + **gas-efficient static witness** + `stepsHash` |
| Execute entries | `swapExactInWithPermit` (ERC-20) **xor** `swapExactInEth` (ETH) |
| ETH | First/last hop; excess ETH → principal; payout → recipient |
| Recipient | Explicit on params |
| Payout / dust | Ledger `amountOut` only; owner rescue (shared lock) |
| Child funding | Balancer/SE: Permit2 amount-scoped; UR: ERC-20 approve amount-scoped; clear residual |
| Query | Stock/SE native query; UR via **V4 quoter** on **pinned templates** |
| Register | AddressSetRepo `_add` idempotent + kind overwrite |
| Allowlist seed | Optional `PkgArgs` initial routers |
| Token continuity | Trust builder (no Coordinator tokenIn check) |
| FoT | `InvalidAmount(token, expected, actual)` |
| Name | `BalancerV3UniswapV4CoordinatorRouter` frozen |
| Step count | No hard max (gas-bound) |
| UR hermetic | Crane port / vendor required (§7.4) |

### Clarification changelog (v1.0 → v1.1)

| # | Clarification | PRD impact |
|---|---------------|------------|
| 1 | Explicit `recipient` | D14; params; payout; events |
| 2 | Chain Universal Router | D9; rename adapter; §7.4 port gap |
| 3 | Permit2 strict | D10; remove pre-funded entry |
| 4 | Per-step allowance | D18; §4.6 |
| 5 | Diamond + package | D21; §7.2 |
| 6 | Keep two stock kinds | D7 |
| 7 | Free interleaving / multi batch steps | D16; non-goals refined |
| 8 | `queryExactIn` | D19; §4.8; T24 |
| 9 | MultiStepOwnable | D20 |
| 10 | Full-route witness | D11; §5.7 |

### Clarification changelog (v1.1 → v1.2)

| # | Clarification | PRD impact |
|---|---------------|------------|
| 11 | Pure Crane deploy (not vault registry) | D21; package kind; §7.2; T28 |
| 12 | Two execute entries locked (permit vs eth) | D25; §4.4; T27 |
| 13 | Tracked amount ledger (donation-safe hop input) | D26; §4.5; §5.6; T26 |
| 14 | `queryExactIn` must cover UR on-chain | D19 refined; §4.8; T24 |
| 15 | Witness `stepsHash = keccak256(abi.encode(steps))` | D27; §5.7 |
| 16 | Single-root steps; no multi-root batch split; chain validity delegated to children | D28; §5.2; non-goal 3 |
| 17 | No hard max `steps.length` | D29 |
| 18 | Child funding: Balancer/SE Permit2; UR ERC-20 approve | D18 refined; §4.6; T23 |

### Clarification changelog (v1.2 → v1.3)

| # | Clarification | PRD impact |
|---|---------------|------------|
| 19 | UR query = V4 quoter over pinned V4-only templates | D30; §4.8; §5.5; T24 |
| 20 | `registerRouter` via AddressSetRepo._add (idempotent) + kind store/overwrite | D31; §6.1; T29 |
| 21 | Optional initial routers in PkgArgs → postDeploy | D32; §6.5; T30 |
| 22 | No Coordinator tokenIn==currentToken check (trust builder) | D28 refined; §4.5; §5 |
| 23 | Payout ledger amountOut only; owner rescue; shared nonreentrancy with swaps | D33; §6.4; T31 |
| 24 | Gas-efficient static EIP-712 witness field list + stepsHash | D27 refined; §5.7 |
| 25 | FoT / short pull → `InvalidAmount(token, expected, actual)` | D34; §4.6; §8.1; T32 |
| 26 | Name frozen: `BalancerV3UniswapV4CoordinatorRouter` | D35; header |

---

**End of PRD v1.3**
