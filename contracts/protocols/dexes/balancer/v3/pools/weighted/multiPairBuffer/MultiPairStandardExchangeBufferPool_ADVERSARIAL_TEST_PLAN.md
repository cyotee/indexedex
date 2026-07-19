# MultiPairStandardExchangeBufferPool — Adversarial Test Plan

## Purpose

Prove the multi-pair weighted SE **buffer pool** resists the abuse classes that have drained or griefed Balancer-style pools, vault buffers, and hook-driven products — especially:

- **Ungated CUSTOM remove liquidity** (public drain via `bptAmountIn = 0`)
- **Donation / inflation** of virtual reserves or BPT
- **Hook / Vault caller spoofing**
- **Reentrancy** through hostile ERC20s or SE callbacks during pre-seat / reconcile
- **Cross-pair accounting corruption** (one leg’s math balance stolen for another)
- **Failed-path residual inventory** (tokens stuck mid-hook; free inventory for next user)

Methodology follows:

1. `lib/crane/.claude/skills/crane-adversarial-testing/` (catalog A–H, production-first, P0/P1)
2. `.claude/skills/indexedex-adversarial-testing/` (registry deploy, no mock SUT)
3. Single-pair buffer baselines under `test/.../constProd/standardExchange/` (NotHookCaller, donation grief)

**Normative product:** [PRD](./MultiPairStandardExchangeBufferPool_PRD.md) L1–L27 (esp. L5 hook-in-pool, L12–L16 equivalence, L18 full graph, L19 unbalanced LP, L21 uniqueness, L24 SE I/O).  
**Happy path / comparative:** [Implementation plan](./MultiPairStandardExchangeBufferPool_IMPLEMENTATION_AND_TEST_PLAN.md) — adversarial is **additional**, not a substitute for Phase 6 comparative.

## Status

**PLANNED** — implement after happy-path Phases 1–5 are green (minimum: registration, within-pair swaps, CUSTOM liquidity). Prefer full-graph + LP green before claiming P0 complete.

| Field | Value |
|-------|--------|
| SUT | Multi-pair buffer Diamond (pool == hooks) |
| Deploy | CREATE3 facets + Vault Registry DFPkg only |
| Forbidden | `vm.mockCall` on pool/manager/registry; mock SE as SUT/leg |

---

## 1. Threat model

| Actor | Surface | Assets at risk |
|-------|---------|----------------|
| External EOA / bot | `Vault.swap`, `addLiquidity`, `removeLiquidity` (all kinds), donate | Buffer tokens, vault shares, BPT, SE vault inventory tied to pool |
| Attacker as LP | Unbalanced join/exit, proportional exit | Other LPs’ virtual reserves / share depth |
| Hostile ERC20 | Configured as `vaultShare` or `bufferToken` if product allows weird tokens | Reentrancy into pool/hooks during transfer |
| Hostile / buggy SE vault | `exchangeIn` / `exchangeOut` during hook | Mid-swap grief; should not leave free inventory or corrupt virtuals on full revert |
| Fake “router” | `removeLiquidity(CUSTOM)` / `addLiquidity(CUSTOM)` with `maxBptAmountIn=0` | **Full pool drain** if `NotHookCaller` missing (historical class) |
| Spoof factory / register | Balancer `onRegister` | Wrong pool binding |

**Pass criteria (binary):**

- Exploit **blocked** (revert / zero value theft), **or**
- Intentional economic behavior **documented** with hard safety invariants still holding (e.g. L14 rate drift after underlying trades is not “theft of virtuals”).

If an unbounded profitable exploit is real → **fix production first**; do not greenwash.

---

## 2. Attack catalog (product-mapped)

IDs use Crane categories. Multi-pair-specific rows marked **MP**.

### A — Donation / inflation

| ID | Attack | Pass |
|----|--------|------|
| **A1** | Transfer `bufferToken[i]` directly to pool / Vault pool balance without join | No free BPT; `virtualBuffer[i]` unchanged until legitimate LP/swap paths; no theft of other legs |
| **A2** | Transfer `vaultShare[i]` to pool outside swap/LP | Derived depth must not mint free BPT; attacker cannot improve their BPT share free |
| **A3** | Balancer `DONATION` of buffer or shares as external user | Same as single buffer: **must not** bump virtuals the way hook-internal donation bookkeeping does (L19 / double-count rule); BPT supply unchanged for pure donation |
| **A4** | Dust donate then force victim swap | Victim not charged attacker’s dust as debt; no permanent DoS of invariant |
| **A5 (MP)** | Donate on pair *i* then swap on pair *j* | No cross-leg free lunch from idle inventory |

### B — Price / rate manipulation

| ID | Attack | Pass |
|----|--------|------|
| **B1** | Skew SE underlying AMM → move rate → swap buffer | May change quotes (L14); **no** unbounded drain of *other* pairs’ virtuals; victim balances not stolen |
| **B2** | Sandwich victim swap around attacker LP add/remove | Prefer document MEV risk; assert no residual free inventory / virtual underflow |
| **B3** | Extreme rate (or forced store only for guard tests) | Clean revert or bounded behavior; pool not permanently bricked without admin (immutable) |
| **B4** | Comparative freeze broken deliberately | Document: parity tests must not claim pass if underlyings traded |

### C — Reentrancy

| ID | Attack | Pass |
|----|--------|------|
| **C1** | Hostile `vaultShare` reenters `Vault.swap` / add / remove mid-transfer during hook | Nested call fails with `IsLocked` (or BV3 lock); outer path completes or full reverts cleanly; `reentryAttempts ≥ 1`, nested success false |
| **C2** | Hostile `bufferToken` reentrancy on settle/sendTo path | Same |
| **C3** | Reenter CUSTOM liquidity from hostile token during hook dance | `NotHookCaller` or lock; no drain |
| **C4 (MP)** | Cross-pair: reenter swap tokenOut different pair mid pre-seat | No double pre-seat / virtual double-spend |

Wire hostile tokens via **production** pool tokens only when the product allows that ERC20 as a configured leg (mintable hostile ERC20 as buffer or share stand-in in hermetic tests). Prefer real SE share when possible; hostile ERC20 as bufferToken for C2 is OK if mintable.

### D — Authority / CUSTOM drain (P0 classic)

| ID | Attack | Pass |
|----|--------|------|
| **D1** | `removeLiquidity(CUSTOM)` with `maxBptAmountIn=0`, arbitrary `minAmountsOut`, attacker as router | **`NotHookCaller`** — **P0** (single-buffer LiquidityTarget NatSpec drain) |
| **D2** | `addLiquidity(CUSTOM)` from attacker router | `NotHookCaller` (hygiene; softer than D1) |
| **D3** | Call hook functions (`onBeforeSwap`, etc.) as non-Vault | Return false / no state change / revert |
| **D4** | `onRegister` with wrong factory / wrong pool / wrong tokenConfig | Reject registration |
| **D5** | Attempt diamondCut / upgrade if surface exists | Fail (immutable unowned instance policy if applicable) |

### E — Accounting / residual / cross-pair

| ID | Attack | Pass |
|----|--------|------|
| **E1** | Force failed pre-seat mid-path | Full tx reverts; physical balances and virtuals consistent (no half-applied virtual) |
| **E2** | Force `PostSwapDepositFailed` after user swap would have succeeded on reference | Full revert; user not left with free out + unpaid in |
| **E3 (MP)** | Swap buffer_i → share_j; assert pair *k* virtual/delta unchanged | Exact isolation of non-involved legs |
| **E4 (MP)** | Sequence of cross-pair swaps; attacker profit vs no free mint of BPT | Conservation of virtual vector vs BPT (within fee/rounding); no free BPT |
| **E5** | Zero / dust swap amounts | Revert `SwapTooSmall` / ZeroAmount peer; no state corruption |
| **E6** | Unbalanced LP add buffer only, then attacker CUSTOM remove | CUSTOM still gated; virtuals match policy |
| **E7** | After successful swap, physical buffer balances eventual-zero | Assert ≈0 residual buffer tokens on pool (documented dust bound) |

### F — Access / registration

| ID | Attack | Pass |
|----|--------|------|
| **F1** | Deploy with duplicate pairs (L21) | Revert at processArgs/init |
| **F2** | Non-registry `processArgs` | `NotCalledByRegistry` |
| **F3** | External hooks address (must be impossible via pkg) | Package always sets `hooksContract = pool`; test asserts pool implements IHooks at same address |

### G — Composition / SE grief

| ID | Attack | Pass |
|----|--------|------|
| **G1** | SE `exchangeOut` reverts (empty vault) during pre-seat | Clean `PreSeatRedemptionFailed`; no virtual debit |
| **G2** | SE `exchangeIn` reverts during reconcile | Clean `PostSwapDepositFailed`; full swap reverts |
| **G3** | Nested DETF / SE as vault leg (if fixture available) | Opacity; pool still only uses IStandardExchange |

### H — Grief / DoS

| ID | Attack | Pass |
|----|--------|------|
| **H1** | Drain pair share inventory so pre-seat cannot seat buffer out | Revert for that route; other pairs still swap if independent inventory allows |
| **H2** | Unbalanced grief leave physical buffer sitting | Eventual-zero policy: next buffer-in path or documented residual; not stealable via CUSTOM |
| **H3** | minOut fail on router swap | Atomic revert; no residual free inventory on pool |

---

## 3. Priority

### P0 — ship gate (“adversarially tested”)

| ID | Why |
|----|-----|
| **D1, D2** | Historic CUSTOM passthrough drain |
| **D3, D4** | Hook/Vault binding |
| **A3** | Donation double-count / BPT inflation class |
| **E1, E2, E7** | Failed hook / residual free inventory |
| **E3, E4** | Multi-pair isolation + no free BPT |
| **C1** (or C2) | At least one hostile ERC20 reentrancy probe on live swap path |
| **F1, F3** | Distinct pairs + hooks-in-proxy |

### P1 — before calling security-ready

| ID | Why |
|----|-----|
| **A1, A2, A5** | Idle transfer inflation |
| **B1** | Rate move safety bounds (not comparative parity) |
| **C3, C4** | Hook dance reentrancy |
| **E5, E6** | Dust / unbalanced + CUSTOM |
| **G1, G2** | SE failure modes |
| **H1–H3** | DoS / atomicity |

### P2 — explicit defer OK

| ID | Reason to defer |
|----|-----------------|
| **B2** | Full sandwich/MEV reconstruction; document |
| **B3** | Extreme rate via `vm.store` only for guard if product has no bound |
| **G3** | Nested DETF fixture cost |
| **C*** full matrix | One strong reentrancy test may suffice initially |

Every deferred P2 ID gets a suite NatSpec one-liner (Crane skill rule).

---

## 4. Already covered (baseline — do not only duplicate)

From **single-pair** buffer (port patterns, re-implement against multi-pair SUT):

| Baseline | Source |
|----------|--------|
| `NotHookCaller` on CUSTOM add/remove | `StandardExchangeBufferPoolLiquidityTarget.t.sol`, Errors behavior |
| Donation does not shift virtualTTA / hookSharesDelta / BPT | `Behavior_StandardExchangeBufferPool_Adversarial` |
| Rate provider zero path | Adversarial behavior |

Multi-pair must re-run equivalents for **vector** virtuals and **full graph**.

---

## 5. File layout

```text
test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/
  adversarial/
    TestBase_MultiPairBuffer_Adversarial.sol
    Adversarial_CustomDrain.t.sol          # D1–D2
    Adversarial_HooksAccess.t.sol          # D3–D4, F3
    Adversarial_Donation.t.sol             # A*
    Adversarial_Reentrancy.t.sol           # C*
    Adversarial_Accounting.t.sol           # E*
    Adversarial_SeIoGrief.t.sol            # G*, H*
    Adversarial_RateManipulation.t.sol     # B1 (P1)
    Adversarial_DeployGuards.t.sol         # F1–F2
```

Naming: `test_D1_customRemove_revertsNotHookCaller()`, `test_E3_crossPair_leavesOtherVirtualsUnchanged()`, etc.

### TestBase harness helpers

```text
attacker, victim
_assertEventualZeroBufferTokens(pool)
_assertVirtualVector(...)
_assertNoFreeInventory(pool)          // free buffer ≈ 0; no unexpected share dust policy
_snapshotMathBalances / _assertMathDelta
_swapExactIn(tokenIn, tokenOut, amount)
_tryCustomRemoveAs(router, amounts)   // expect NotHookCaller
_armHostileShare / _deployWithHostileBufferToken  // when in scope
```

Extend `TestBase_MultiPairStandardExchangeBufferPool` (or UniV2 hermetic base). **P=2 minimum** for MP IDs; P=1 enough for D1/A3 port.

---

## 6. Implementation phases (adversarial track)

Run **after** happy-path Phase 3 (within-pair swaps) at earliest for D1/A3; complete P0 after Phase 4–5.

| Phase | Work | Depends on |
|-------|------|------------|
| **Adv-0** | This plan + TestBase_Adversarial scaffold | Impl Phase 1 |
| **Adv-1 P0** | D1–D4, F1, F3, A3, E7 | Liquidity + init |
| **Adv-2 P0** | E1–E4, C1 | Within-pair + cross-pair swaps |
| **Adv-3 P1** | A1–A2, A5, B1, G1–G2, H*, E5–E6 | LP + SE fixtures |
| **Adv-4** | Checklist green; deferred NatSpec; link from main plan status | — |

---

## 7. Invariants (assert often)

1. **CUSTOM liquidity only from pool-as-router** (`router == address(this)`).
2. **Hook entry only from Balancer Vault** (`msg.sender == vault`).
3. **hooksContract == pool**; Hook Facet on same Diamond (L5).
4. **Non-involved pair virtuals/deltas unchanged** across a swap of two other tokens (E3).
5. **No free BPT** from donate/transfer without proportional mint path.
6. **Eventual-zero physical buffer tokens** after successful buffer-involving ops (dust bound).
7. **Failed txs leave no stealable free inventory** on the pool.
8. **Virtual buffer ≥ 0**; derived share depth well-defined (no underflow panic → clean revert).

---

## 8. Acceptance criteria

| Gate | Criterion |
|------|-----------|
| P0 complete | Every P0 ID has a real `test_<ID>_…` **or** explicit NatSpec deferral (none expected for D1) |
| `forge test --match-path '.../multiPairBuffer/adversarial/**'` | Exit 0 |
| Production exploit found | Fix PR first; test becomes regression |
| Comparative Phase 6 | Still required separately; adversarial does not replace freeze equivalence |

---

## 9. Commands

```bash
forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/adversarial/**' -vv
forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/**'
```

---

## 10. Lessons from common pool / buffer failures (mapped)

| Historical class | Our control | Test ID |
|------------------|-------------|---------|
| Public `removeLiquidityCustom` / mock passthrough drain | `NotHookCaller` | **D1** |
| First depositor / donation inflation | Virtuals not tied to raw `balanceOf` alone; donation policy | **A1–A3** |
| Read-only reentrancy / ERC777 hooks | BV3 + IsLocked + hostile ERC20 probe | **C*** |
| Oracle/rate manipulation free mint | No seigniorage mint; swap only; document L14 | **B1** |
| Failed external call leaves inconsistent state | Full revert on pre-seat/reconcile fail | **E1–E2, G1–G2** |
| Cross-pool accounting bleed | Per-pair virtual vector isolation | **E3–E4** |
| Separate hooks contract trust | Hooks facet in pool proxy only | **F3, L5** |

---

## Document control

| Item | Value |
|------|--------|
| Path | `…/multiPairBuffer/MultiPairStandardExchangeBufferPool_ADVERSARIAL_TEST_PLAN.md` |
| Created | 2026-07-18 |
| Status | **PLANNED** |
| Skills | `crane-adversarial-testing`, `indexedex-adversarial-testing` |
