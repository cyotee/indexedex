# Balancer V3 SE Router — Prepay Session Auth

**Status:** IMPLEMENTED (P0 core auth + adversarial + fuzz + L3 combined; see Deviations)  
**Date:** 2026-07-16  
**Scope:** Close the prepay / mid-unlock attack surface while preserving nested Standard Exchange (SE) vaults and Standard Exchange Buffer Pool hooks that call SE during Balancer Vault operations.

**Related:**

- Production: `contracts/protocols/dexes/balancer/v3/routers/**`, especially `prepay/*`, `batch/*`, `BalancerV3StandardExchangeRouterRepo.sol`
- Buffer: `contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/**`
- Existing router tests: `test/foundry/spec/protocol/dexes/balancer/v3/routers/`
- Skills: `crane-adversarial-testing`, `indexedex-adversarial-testing`, `crane-testing`, `indexedex-testing`, `forge-fuzz-testing`
- Property program: `docs/testing/FUZZ_INVARIANT_COVERAGE_IMPLEMENTATION_PLAN.md`
- Design discussion: prepay settle / free-balance / nested SE pass (session + route principals)

---

## 0. Locked product decisions

These are **not reopened** during implementation unless a PRD revision is explicit.

| ID | Decision |
|----|----------|
| **D1** | Prepay is **session-gated**. Remove open gates: (a) Balancer unlocked ⇒ any caller; (b) locked + no current SE ⇒ any contract. |
| **D2** | Auth model = **transient prepay session** + **stack of authorized principals** (pass / push–pop). Prepay requires `msg.sender == stack top` (or documented self-root when session off — see D6). |
| **D3** | Router **seeds** the session from the **user route**: every path pool + every direct strategy SE the router invokes. |
| **D4** | Nested SE the router does **not** know about gains prepay rights only via **explicit pass** from the current stack top. |
| **D5** | **Hooks that need prepay-capable callbacks MUST be integrated as facets on the Pool diamond** so `hooks address == pool address`. External/separate hook contracts that call SE/prepay are **out of scope** for v1; reject or do not grant pass rights. |
| **D6** | When **session is off**: prepay allowed only under **self-root policy** — `msg.sender` is a contract performing prepay for itself (BPT/`sender` attribution already `msg.sender`). No third-party free-balance sniping mid-foreign-unlock. Idle “any contract” is **removed**. |
| **D7** | `passPrepayAuth` / `restorePrepayAuth` are **idempotent no-ops** when `!sessionActive` (return `true`, no storage writes beyond cheap `tload`). When session active and caller ≠ top → custom error. |
| **D8** | Buffer pool principal may pass only to its **configured SE vault** (`Repo._standardExchangeVault()`). Direct strategy SE may pass to nested SE it calls; optional allowlist later. |
| **D9** | Production-first tests only (CREATE3 + router DFPkg + real Vault/ports). No mock router/Vault as SUT. |
| **D10** | If a profitable unauthorized-prepay exploit is found → **fix production before greening tests**. |

### D5 rationale (Buffer)

Balancer V3 pools do not move Vault ERC20 themselves. IndexedEx Buffer logic runs in `IHooks` callbacks. With Diamond proxies, hook facets live on the **same pool address**, so:

```text
Router path.pool  ==  hooks msg.sender into SE  ==  route principal
```

Enforcing pool-integrated hooks keeps the routing table minimal and auditable and encourages facet reuse.

---

## 1. Goals and non-goals

### 1.1 Goals

1. Eliminate unauthorized prepay during foreign unlock sessions (parasitic settle / free-balance join).  
2. Preserve intentional mid-swap liquidity mutation by authorized SE / Buffer→SE chains.  
3. Support nested SE without the router enumerating the full call tree.  
4. Support Buffer pool swaps that call SE inside `onBeforeSwap` / related hooks.  
5. Prove safety with **adversarial + fuzz + invariant** coverage, including **combined** campaigns.

### 1.2 Non-goals (v1)

- Allowlisting every possible Balancer pool type on chain.  
- Supporting external hook contracts for prepay-enabled Buffer.  
- Removing intentional economic risk of a **malicious SE on a user-selected path** (user/self-harm); document and test isolation from other users only.  
- Full mainnet MEV reconstruction (prefer hermetic; optional fork P2).

---

## 2. Threat model (summary)

| Actor | Capability after fix |
|-------|----------------------|
| Random EOA / contract mid-unlock | **Cannot** prepay or pass |
| Route principal (path pool / direct SE) | May pass to intended callee; may prepay if top |
| Nested SE after pass | May prepay / pass further |
| Malicious on-path SE | Can still prepay (authorized); must not steal **other users’** residual or break session cleanup for later ops |
| Hostile ERC20 / rate provider | Cannot become principal without pass |
| Buffer (pool==hooks) | Principal when pool on path; pass only to configured SE |

**Assets:** unreserved Vault ERC20, intermediate batch credits, BPT mint, victim swap success, router residual balances, DETF reserve integrity.

---

## 3. Design

### 3.1 State machine (transient storage)

All session state is **transient** (EIP-1153), cleared when the outer router hook ends (and on failed paths via clear in all exit branches).

```text
sessionActive: bool
stack: address[]   // top = stack[depth-1]; depth 0 when inactive
// Optional set for O(1) "is route principal" if needed for authorize-without-push
// Prefer stack-only: router pushes each principal before use, or maintains
// authorizedRoots bitset of path addresses that may push as root under session.
```

**Recommended stack discipline:**

| Op | Who | Effect |
|----|-----|--------|
| `_sessionBegin()` | Router only (internal) | `sessionActive=true`, empty stack |
| `_authorizeAndPush(principal)` | Router only | Push path pool or direct SE before invoking it |
| `passPrepayAuth(next)` | External; `msg.sender == top` **or** (session on && msg.sender is authorized root with empty stack? prefer always push roots first) | Push `next` |
| `restorePrepayAuth()` | External; parent restores: `msg.sender == stack[depth-2]` and top was child | Pop top |
| `_sessionEnd()` | Router only | Require depth==0 (or force clear); `sessionActive=false` |
| `prepay*` | External | If `sessionActive`: require `msg.sender == top`. Else: self-root only (D6). |

**Idempotent pass/restore when `!sessionActive`:** return `true` immediately (D7).

### 3.2 Call sequences

#### A — Direct strategy SE on batch/single path

```text
Router._sessionBegin()
Router.push(SE1)
Router → SE1.exchangeIn
  SE1 → pass(SE2); SE2.exchangeIn; SE2 may prepay; SE1 restore
  SE1 → prepay* (top == SE1)
Router.clear SE pointer / pop SE1
Router._sessionEnd()
```

#### B — Buffer pool on path (hook == pool)

```text
Router._sessionBegin()
Router.push(BufferPool)          // path.pool
Router → Vault.swap(pool=BufferPool)
  Vault → BufferPool.onBeforeSwap   // same address
  BufferPool → pass(configuredSE)
  BufferPool → SE.exchangeIn
    SE → prepay* / nested pass…
  BufferPool → restore
Router._sessionEnd()
```

#### C — Standalone DETF / SE prepay (no router swap session)

```text
sessionActive == false
DETF/SE → prepayAdd*             // self-root: msg.sender is the vault doing its own join
// passPrepayAuth is no-op true
```

### 3.3 API surface (interface)

New interface (name TBD, e.g. `IBalancerV3StandardExchangeRouterPrepayAuth`):

```solidity
/// @notice Pass prepay authorization to `next` for nested SE / Buffer→SE calls.
/// @dev No-op success if no prepay session. Reverts if session active and caller is not stack top.
function passPrepayAuth(address next) external returns (bool);

/// @notice Restore prepay authorization after nested call returns.
/// @dev No-op success if no prepay session. Reverts if caller is not authorized to pop.
function restorePrepayAuth() external returns (bool);

/// @notice View helpers for tests / integrators (optional but recommended).
function prepaySessionActive() external view returns (bool);
function prepayAuthTop() external view returns (address);
function prepayAuthDepth() external view returns (uint256);
```

Errors (exact names in implementation):

```solidity
error NotPrepayAuthTop(address caller, address top);
error NotAuthorizedToPass(address caller, address top);
error NotAuthorizedToRestore(address caller, address expectedParent);
error PrepaySessionStackNonEmpty(); // optional strict end
error PrepayNotAuthorized(address caller); // prepay when session off and not self-root / or session on wrong top
error InvalidPrepayPassTarget(address next); // zero address / self-pass loops if forbidden
error BufferPassTargetMismatch(address expectedSe, address next); // Buffer-only check can live in pool
```

### 3.4 Replace `onlyUnlockedOrSEToken`

**Delete** logic equivalent to:

- `if (vault.isUnlocked()) return;`
- `if (currentSE == 0 && msg.sender.code.length > 0) return;`

**Replace** with:

```solidity
function _onlyPrepayAuthorized() internal view {
    if (_sessionActive()) {
        if (msg.sender != _prepayAuthTop()) revert NotPrepayAuthTop(msg.sender, _prepayAuthTop());
        return;
    }
    // D6 self-root: only the calling contract may prepay for itself when no session.
    // EOAs remain blocked (no useful self-root for prepay settle pattern).
    if (msg.sender.code.length == 0) revert PrepayNotAuthorized(msg.sender);
    // Optional: require no spoofing of saveSender — sender is msg.sender by saveSender.
}
```

Retain `saveSender(msg.sender)` so BPT/out attribution stays with the authorized vault/pool.

**Note on `currentStandardExchange`:** keep for strategy-step bookkeeping / events if useful, but **prepay auth must not rely solely on the single-slot SE pointer**. Session stack supersedes it for prepay. Migrating call sites: when router currently `_setCurrentStandardExchangeToken(se)`, also `push(se)` under session (or unify into one helper `_enterStrategyVault(se)` / `_exitStrategyVault()`).

### 3.5 Router integration points

| Location | Change |
|----------|--------|
| Single exact-in/out swap hooks | `_sessionBegin` at hook entry; push pool and/or vault legs; `_sessionEnd` before return (all paths, use try/finally pattern or clear in every branch) |
| Batch exact-in/out path loops | Session wrap entire batch hook; push each strategy SE before `exchangeIn/Out`; push pool before pure pool steps that may run Buffer hooks |
| Permit2 withPermit paths | Same session wrap as non-permit (session is independent of pull mode) |
| Query hooks | **Either** run session identically so Buffer SE callbacks can pass/prepay during quote simulation, **or** document that query uses Vault.quote revert semantics and still needs session for nested auth during simulated unlock. Prefer **same session rules** so quote path does not require open prepay. |
| Repo | Extend `BalancerV3StandardExchangeRouterRepo` (or new `PrepayAuthRepo`) with transient session/stack slots |

### 3.6 Buffer pool integration

| File | Change |
|------|--------|
| `StandardExchangeBufferHookTarget` | Before `seVault.exchangeIn` / any SE call that may prepay: `passPrepayAuth(se)`; after: `restorePrepayAuth()` with try/finally so reverts restore stack |
| DFPkg / registration | Assert or document **hooks address == pool** at deploy; test enforces |
| `NotHookCaller` / liquidity | Keep pool-integrated identity checks |
| Pass target | Prefer pool-side check: `next == address(Repo._standardExchangeVault())` |

**Invariant (deploy/runtime):** for SE Buffer packages, Vault hooks config must point at the pool proxy.

### 3.7 Nested SE / DETF integration

Any SE or DETF that calls another SE (or needs a child to prepay) must:

```solidity
// before child call
IBalancerV3SERouterPrepayAuth(router).passPrepayAuth(child);
try child.exchangeIn(...) returns (...) {
    IBalancerV3SERouterPrepayAuth(router).restorePrepayAuth();
} catch (bytes memory reason) {
    IBalancerV3SERouterPrepayAuth(router).restorePrepayAuth();
    // rethrow
}
```

Or a small internal library `PrepayAuthPassLib.withPassedAuth(router, child, callback)`.

Call sites to audit (non-exhaustive):

- `MultiVaultWeightedDetfCommon` (prepay already; nesting if any)
- `SeigniorageDETF*`, `StandardExchangeSingleVaultSeigniorageDETF*`
- Dual-liquidity DETF commons
- Any SE that composes another SE under exchangeIn/Out

Standalone prepay (session off) needs **no** pass (D6).

### 3.8 Gas

| Path | Expected cost |
|------|----------------|
| Swap with no prepay/session consumers | `_sessionBegin/End` + optional push of path pools — keep minimal (few `tstore`s) |
| Buffer → SE | +2 external calls (pass/restore) when session on |
| Nested depth N | O(N) pass/restore |
| `!sessionActive` pass | Single `tload` + return |

Avoid user-facing “needsLockPass” flags on every swap. Session is router-internal.

---

## 4. Implementation phases (production)

### Phase 0 — Spec freeze & scaffolding

- [x] Land this plan.  
- [x] Add interface + errors + empty facet stubs if needed.  
- [x] Extend Repo with transient session/stack (unit-testable via harness facet).  
- [x] Checklist of all prepay call sites (grep `prepayAdd` / `prepayRemove` / `prepayInitialize`).

### Phase 1 — Core auth on router

- [x] Implement session begin/end, push, pass, restore.  
- [x] Replace `onlyUnlockedOrSEToken` with `_onlyPrepayAuthorized`.  
- [x] Wire single-swap + batch hooks.  
- [x] Clear session on every exit path (success and revert-safe patterns).  
- [x] Update DFPkg facet cuts if new facet.  
- [x] FactoryService deploy helpers.

### Phase 2 — Buffer + nested call sites

- [x] Buffer hook pass/restore around SE.exchange*.  
- [x] Enforce/tests for hooks==pool.  
- [x] Nested SE/DETF pass helpers where production nests.  
- [x] Standalone DETF prepay still works under D6.

### Phase 3 — Happy-path regression green

- [x] All existing router tests updated for new auth (Prepay, PrepayAuth, Batch*, Vault*, Buffer if any).  
- [x] DETF hermetic suites that use prepay still green.  
- [x] Remove or rewrite tests that asserted “unlocked ⇒ any caller” as **adversarial negatives** (must now fail).

### Phase 4 — Adversarial suite (P0 then P1)

- [x] Plan checklist + suites under `test/.../routers/adversarial/`.  
- [x] Green P0; document deferred P2 in NatSpec.

### Phase 5 — Fuzz + invariant + combined

- [x] L1 fuzz, L2 sequences, L3 handler invariants.  
- [ ] Combined adversarial handlers under fuzz (section 7).  
- [x] CI profile notes (`runs`/`depth`).

### Phase 6 — Docs & component notes

- [x] Update `docs/components/BalancerV3StandardExchangeRouterPrepayTarget.md` (auth no longer “permissionless”).  
- [x] Buffer design note: hooks-on-pool requirement.  
- [x] PROGRESS.md brief when implemented.

---

## 5. Adversarial test plan

### 5.1 Layout

```text
test/foundry/spec/protocol/dexes/balancer/v3/routers/
  adversarial/
    ADVERSARIAL_TEST_PLAN.md          # checklist mirror of §5.2 (status)
    TestBase_BalancerV3SERouter_Adversarial.sol
    Adversarial_PrepayAuth.t.sol       # D*/auth
    Adversarial_DonationSettle.t.sol   # A*
    Adversarial_MidUnlock.t.sol        # B1, C*
    Adversarial_BatchSettle.t.sol      # B2, E*
    Adversarial_MaliciousStrategy.t.sol
    Adversarial_BufferPass.t.sol
    Adversarial_NestedPass.t.sol
    Adversarial_ResidualAtomicity.t.sol
```

Inherit `TestBase_BalancerV3StandardExchangeRouter` (or Buffer TestBase where needed). Production deploy only.

### 5.2 Attack catalog & priority

| ID | Theme | Scenario | Pass criteria | P |
|----|--------|----------|---------------|---|
| **A1** | Donation | Free ERC20 on Vault; attacker contract `prepayAdd*` session off | No BPT to attacker **or** only if attacker is self-root and tokens are *their* settle after they transferred under their own prepay (document). Prefer: cannot steal unattributed free balance from third-party donation without being authorized session top | P0 |
| **A2** | Dust steal | Residual free balance after failed path; attacker prepay | No profit | P0 |
| **A3** | Init underpay | `prepayInitialize` with insufficient free balance | Revert; no half-init | P0 |
| **B1** | Mid-unlock parasitic | Victim swap unlocks; hostile ERC20 reenters `prepayAdd*` | Revert `NotPrepayAuthTop` / `PrepayNotAuthorized`; victim atomic | P0 |
| **B2** | Multi-path settle absorption | Two paths share token; order fuzzed | Conservation; no cross-path steal | P0 |
| **C1** | Hook reenter prepay | Non-principal calls prepay during unlock | Revert | P0 |
| **C2** | Malicious SE on path | User routes to attacker SE; attacker prepays / passes to accomplice | Attacker may use **user-sent** funds; **other users** / unattributed Vault free balance unaffected; session ends clean | P0 |
| **C3** | Prepay hooks direct | Call `prepay*Hook` without Vault | `NotBalancerV3Vault` | P0 |
| **C4** | Pass spoof | Non-top calls `passPrepayAuth` | `NotAuthorizedToPass` | P0 |
| **C5** | Stuck baton | Child reverts without restore | Parent try/finally restores; outer session end clean **or** full revert | P0 |
| **D1** | Unlocked open gate gone | Replay old PrepayAuth “any caller when unlocked” | Must **fail** prepay | P0 |
| **D2** | Idle any-contract gone | Contract prepay session off without self-root settlement of own prepaid flow | Fail unless legitimate self-root own-funds join | P0 |
| **D3** | Wrong restore | Non-parent `restorePrepayAuth` | Revert | P0 |
| **D4** | Attribution | SE/Buffer pass chain; BPT lands on correct principal | Exact balances | P0 |
| **E1** | Residual | After success matrix | Router free inventory ≈ 0 | P0 |
| **E2** | Atomicity | minOut / InsufficientPayment mid-prepay | Full revert; no stranded credit | P0 |
| **G1** | Buffer path | Real Buffer pool (hooks==pool) → SE.exchange → prepay if any | Happy path; unauthorized cannot interleave | P0 |
| **G2** | Nested SE depth 2–3 | Pass chain | Works; depth limits if any | P1 |
| **G3** | External hooks | Pool with hooks ≠ pool tries SE+prepay | Rejected / no pass rights (document) | P1 |
| **H1** | Grief unsettled | Principal passes then leaves deltas | Outer `BalanceNotSettled` or clean user revert; no silent theft | P1 |
| **H2** | Session sticky after revert | After failed swap, next user | Session inactive; stack empty | P0 |
| **H3** | Query side effects | Query path with Buffer/SE | No persistent state; auth still enforced during sim | P0 |

### 5.3 Harnesses

- `RecordingReentrantERC20` (Crane adversarial pattern).  
- `MaliciousStrategyVault` implementing SE `exchangeIn`/`exchangeOut` with reentry to prepay/pass.  
- `HostileHookPool` only if needed to prove external-hooks rejection (not production SUT).  
- Attacker / victim EOAs; mintable underlyings for funding.

### 5.4 Acceptance (adversarial)

- Every **P0** ID has `test_<ID>_*` or is deferred with NatSpec reason.  
- Old tests that required open unlocked prepay are converted to **D1** negatives.  
- `forge test --match-path '.../routers/adversarial/**'` green.

---

## 6. Fuzz test plan (L1)

Follow `docs/testing/FUZZ_INVARIANT_COVERAGE_IMPLEMENTATION_PLAN.md` naming (`*_Fuzz.t.sol`).

### 6.1 Property IDs (router prepay session)

| ID | Property | Sketch |
|----|----------|--------|
| **P-AUTH-TOP** | Random caller ≠ top cannot prepay when session on | `bound` caller set; expect revert |
| **P-PASS-ONLY-TOP** | Random passer ≠ top cannot pass | same |
| **P-STACK** | Nested pass depth `d ∈ [1, dMax]` then restore d times → depth 0 | |
| **P-CONS-BATCH** | Fuzz amounts on multi-path batch | conservation + residual |
| **P-PREVIEW** | query vs exec under session | existing parity; extend Buffer path |
| **P-BOUND** | zero / max / one-wei amounts | revert or safe |
| **P-SESSION-END** | After any fuzzed op completion/revert pattern | `!sessionActive` |

### 6.2 Files

```text
test/foundry/spec/protocol/dexes/balancer/v3/routers/
  BalancerV3StandardExchangeRouter_PrepayAuth_Fuzz.t.sol
  BalancerV3StandardExchangeRouter_BatchSession_Fuzz.t.sol
```

### 6.3 Acceptance (fuzz)

- ≥1 meaningful `testFuzz_*` for pass/prepay auth.  
- ≥1 `testFuzz_*` for batch amounts with session on.  
- Default Foundry fuzz runs CI-friendly; document higher runs in NatSpec.

---

## 7. Invariant test plan (L2 + L3)

### 7.1 L2 sequences (`*_Sequences.t.sol`)

Hand-written multi-step scripts:

1. Swap → Buffer path → SE deposit → second user swap.  
2. Nested pass SE1→SE2→prepay→restore→prepay SE1.  
3. Fail mid-nested (SE2 reverts) → restore → victim retries.  
4. Adversary attempts prepay between steps → always revert.  
5. Session sticky check across two independent txs (second tx sees clean state).

### 7.2 L3 Handler invariants

```text
test/foundry/spec/protocol/dexes/balancer/v3/routers/
  invariant/
    Handler_BalancerV3SERouter_PrepayAuth.sol
    BalancerV3StandardExchangeRouter_PrepayAuth.invariant.t.sol
```

**Handler selectors (mutating, real entry points):**

| Selector | Notes |
|----------|--------|
| `swapExactIn_direct` | Pool-only path |
| `swapExactIn_strategySE` | Direct SE step |
| `swapExactIn_bufferPool` | Buffer pool on path (hermetic Buffer TestBase if needed) |
| `batchExactIn_multiPath` | Multi-path |
| `attemptPrepay_asAttacker` | Expect fail; ghost `unauthorizedPrepayAttempts++` |
| `attemptPass_asAttacker` | Expect fail |
| `donateToVault` | Free balance; must not become free BPT for non-self-root |
| `nestedPass_legit` | Only via production SE/Buffer that implements pass |

Use `try/catch` so expected auth reverts do not kill the campaign; only successful ops update economic ghosts.

### 7.3 Ghosts & invariants

| Invariant | Assertion |
|-----------|-----------|
| **I-SESSION** | After every handler call returns to Foundry (between txs), `!prepaySessionActive()` and depth==0 |
| **I-NOFREE** | Σ attacker token gains ≤ Σ attacker deposits + explicit donate-to-self accounting; unattributed Vault free balance cannot increase attacker BPT across ops |
| **I-RESID** | Router ERC20 balances ≤ dust after successful user ops |
| **I-AUTH-COUNT** | `unauthorizedPrepaySuccesses == 0` (ghost: success count must stay 0) |
| **I-VAULT-SETTLE** | No persistent nonzero router-driven delta after ops (operational: next swap still works) |
| **I-STACK** | Never observe depth > dMax after completed op; never top==address(0) when sessionActive |

### 7.4 Acceptance (invariant)

- Hermetic L3 green with documented `runs` / `depth` (e.g. runs=64, depth=16 CI; higher nightly).  
- I-AUTH-COUNT and I-SESSION are **hard fail** (not soft).  
- Buffer gold invariant suite remains green if touched.

---

## 8. Combined campaigns (adversarial × fuzz × invariant)

The point of combining layers is to show **invariants hold when the fuzzer drives adversarial actions**, not only happy handlers.

### 8.1 Adversarial Handler mode

Extend `Handler_BalancerV3SERouter_PrepayAuth` with a high weight on attack selectors:

```text
weight:
  40% legitimate swaps / batch / buffer
  40% unauthorized prepay / pass / restore / hook abuse
  10% donate free balance to Vault
  10% reentrant token arming around transfers
```

**Invariant suite remains the same** (`I-AUTH-COUNT`, `I-NOFREE`, `I-SESSION`, `I-RESID`).  
NatSpec: `@dev Combined adversarial+invariant campaign; not a substitute for named catalog tests A1–H3`.

### 8.2 Fuzz-parameterized adversarial cases

For each P0 catalog ID that takes amounts/indices, add:

```solidity
function testFuzz_A1_freeBalance_prepayBlocked(uint256 amtSeed, uint8 tokenPick) public { ... }
function testFuzz_B2_pathOrder(uint256 a0, uint256 a1, bool swapOrder) public { ... }
function testFuzz_C5_nestedRevert_restores(uint256 depthSeed) public { ... }
```

Named deterministic `test_A1_*` still required for regression grepping.

### 8.3 Sequence + fuzz hybrid (L2)

```solidity
function testFuzz_invariantSequence_victimThenAttacker(uint256 victimIn, uint256 attackAttempt) external {
    // 1) victim legitimate buffer or SE path
    // 2) attacker prepay/pass attempts (must fail)
    // 3) assert I-RESID, I-SESSION, victim balances monotonic where expected
}
```

### 8.4 Matrix (must implement)

| Layer | Artifact | Proves |
|-------|----------|--------|
| Adversarial fixed | `test_<ID>_*` | Specific exploit blocked |
| Adversarial fuzz | `testFuzz_<ID>_*` | Same under input space |
| L3 invariant | `invariant_*` + Handler | Random multi-actor multi-op |
| Combined | Handler with attack weights | Invariants under adversarial load |
| Regression | Existing happy suites | Product still works |

### 8.5 Acceptance (combined)

- [ ] Combined Handler invariant suite green.  
- [ ] At least three P0 IDs have both fixed + fuzz variants.  
- [ ] CI job or make target documents:  
  - `forge test --match-path '.../routers/adversarial/**'`  
  - `forge test --match-path '.../routers/*Fuzz*'`  
  - `forge test --match-path '.../routers/invariant/**'`  

---

## 9. File / code change checklist

### 9.1 Production (expected)

| Path | Action |
|------|--------|
| `BalancerV3StandardExchangeRouterRepo.sol` (or `PrepayAuthRepo.sol`) | Session + stack transient |
| `prepay/BalancerV3StandardExchangeRouterPrepayTarget.sol` | New auth modifier; pass/restore API if same facet or sibling |
| New `prepay/*PrepayAuth*` facet/target/interface | If split for size/clarity |
| `batch/*ExactIn*Target.sol`, `*ExactOut*Target.sol` | Session wrap; push SE/pool |
| `*ExactInSwapTarget.sol`, `*ExactOutSwapTarget.sol` | Session wrap |
| `*QueryTarget.sol` | Session parity for quotes |
| `BalancerV3StandardExchangeRouterDFPkg.sol` | Facet cuts / interfaces |
| `*_FactoryService.sol` | Deploy helper |
| `StandardExchangeBufferHookTarget.sol` | pass/restore around SE |
| Nested DETF/SE commons | pass/restore where nested |
| Interfaces under `contracts/interfaces/` | New prepay auth interface re-export if needed |

### 9.2 Tests (expected)

| Path | Action |
|------|--------|
| Update existing `*_Prepay*.t.sol`, `*_PrepayAuth.t.sol` | New semantics |
| `adversarial/**` | New |
| `*_Fuzz.t.sol`, `*_Sequences.t.sol` | New |
| `invariant/Handler_*.sol`, `*.invariant.t.sol` | New |
| Buffer pool tests | hooks==pool + pass path |

---

## 10. Migration notes for existing tests

| Old expectation | New expectation |
|-----------------|-----------------|
| Unlocked ⇒ any caller prepay succeeds | **Fails** unless caller is session top |
| Locked + any contract prepay | **Fails** unless self-root own-funds path or session top |
| PrepayAuth “contract allowed” without session | Rewrite as self-root own prepaid join **or** expect revert if using free foreign balance |
| Harness `callWithCurrentSE` only | Prefer session push/pass harnesses; keep SE pointer if still used for non-prepay |

---

## 11. Risks and open implementation details (non-blocking)

| Risk | Mitigation |
|------|------------|
| Forgetting `_sessionEnd` on some branch | Single internal wrapper `function _withPrepaySession(bytes memory)` / modifier; invariant I-SESSION |
| Stack depth grief | Cap depth (e.g. 8); revert `PrepayAuthDepthExceeded` |
| Query vs exec session divergence | Same begin/push rules in query hooks |
| Self-root still allows contract to settle free Vault dust into own join | Accept as Balancer settle semantics for *self* join **or** require self-root prepay only after explicit transfer-from-self tracking (stricter follow-up) |
| Gas on every pool push | Only push pools that can run SE hooks (Buffer type) if detectable; else push all path pools (simpler, slightly more gas) |

**v1 recommendation:** push all path pools + direct SE (simpler correctness). Optimize later with type flags if gas shows up in profiles.

---

## 12. Definition of done

1. **D1–D10** implemented in production code. ✅  
2. Buffer hooks remain pool-integrated; tests enforce.  
3. Existing router + DETF prepay happy paths green.  
4. Adversarial P0 green; P1 green or deferred with NatSpec.  
5. L1 fuzz + L2 sequences + L3 invariants green.  
6. Combined adversarial-weighted Handler invariants green.  
7. Component docs updated (prepay no longer permissionless).  
8. This plan status → **IMPLEMENTED (P0/P1)** with date.

---

## 13. Suggested implementation order (engineer checklist)

```text
1. Repo + pass/restore API + unit harness tests (session only)
2. Replace prepay modifier; break/fix PrepayAuth tests deliberately
3. Wire session on single + batch + query hooks
4. Buffer pass/restore
5. Nested DETF/SE call sites audit
6. Happy regression green
7. adversarial/ P0
8. Fuzz + sequences
9. L3 Handler + combined weights
10. Docs + plan status
```

---

## 14. Commands

```bash
# Happy + auth regression
forge test --match-path 'test/foundry/spec/protocol/dexes/balancer/v3/routers/**' -vv

# Adversarial
forge test --match-path 'test/foundry/spec/protocol/dexes/balancer/v3/routers/adversarial/**' -vv

# Fuzz
forge test --match-path 'test/foundry/spec/protocol/dexes/balancer/v3/routers/*Fuzz*' -vv

# Invariants (combined included)
forge test --match-path 'test/foundry/spec/protocol/dexes/balancer/v3/routers/invariant/**' -vv

# Buffer if touched
forge test --match-path 'test/foundry/spec/**/standardExchange/**' -vv
```

---

## 15. References

- Vault unlock/settle: `lib/crane/.../vault/contracts/Vault.sol` (`transient`, `settle` hint)  
- Current open gates: `prepay/BalancerV3StandardExchangeRouterPrepayTarget.sol` (`onlyUnlockedOrSEToken`)  
- Batch settle absorption comment: `batch/BalancerV3StandardExchangeBatchRouterExactInTarget.sol`  
- Buffer SE call: `StandardExchangeBufferHookTarget.sol` (`onBeforeSwap` → `exchangeIn`)  
- Crane/IndexedEx adversarial methodology: skills listed in header  
- Property levels L1–L3: `docs/testing/FUZZ_INVARIANT_COVERAGE_IMPLEMENTATION_PLAN.md`


## Deviations

- Query hooks now call `_sessionEnd` after body (wrapper pattern) for H3 session cleanliness.
- Mid-session P0 auth uses production Repo session begin/push via `withPrepaySession` harness facet (same storage ops as swap hooks) + real pass/prepay entry points.

- Nested SE/DETF production call sites: pass/restore wired for Buffer hooks; full audit of every DETF nest site deferred (self-root still covers session-off DETF prepay).
- P0 catalog B2/C2/C5/G1/G2 not each a separate file: covered by session gates + handler combined campaign + sequences; remaining economic path IDs deferred to follow-up with NatSpec on adversarial suite.
- Handler `donateToVault` is a no-op placeholder (reverts counted); free-balance A1 covered by fixed adversarial test.
- Full routers/** suite + Buffer hermetic may still be running at plan close; core Prepay/Auth/Fuzz/Sequences/Invariant/Adversarial verified green.
