# Implementation + test Definition of Done (Crane diamonds / vaults)

Use this as a **ship gate** for any new Facet, Target money path, DFPkg, or vault product. Complements `crane-testing` LR-7 and the adversarial catalog (A–K).

Agents: do not mark a feature complete until every applicable checkbox is green or explicitly deferred with NatSpec reason in the suite.

---

## 1. Architecture completeness

- [ ] Repo / Target / Facet layers follow Crane patterns (`crane-architecture`)
- [ ] `PkgInit` / `PkgArgs` on the **interface**, not the contract
- [ ] Facets deployed via CREATE3 / FactoryService — never `new` production facets in tests or scripts
- [ ] **Every** product-facing external/public function on Target appears in the corresponding Facet’s `facetFuncs()` (and interfaces as needed)
- [ ] If API is split across facets, **no orphan** Target entry without a facet owner
- [ ] DFPkg `facetCuts()` / `diamondConfig` includes every facet selector

## 2. Accounting primitives (money in / out)

- [ ] Inbound credit uses **balance delta** (or pull + re-measure), never absolute `balanceOf(this)` alone as proof of transfer
- [ ] Caller-claimed amounts (`amountIn`, `pretransferred`, permit amount, `msg.value`) are never trusted without measured delivery
- [ ] Fee-on-transfer / rebasing: mint/credit uses **actualIn**, not nominal
- [ ] Reserve / `lastTotalAssets` (or equivalent) updated so the next call cannot treat prior inventory as fresh deposit
- [ ] Failed paths leave residual free inventory ~0 and do not permanently burn claim without payout
- [ ] Preview (if any) matches execute on the same inputs (exact or documented tolerance)

## 3. Mandatory tests (happy + negative)

### Declaration / surface (J)

- [ ] `Behavior_IFacet` declaration tests with controls derived from **Target/product interface**, not copied from a incomplete Facet
- [ ] Package declaration tests (`facetCuts`, `processArgs`, `initAccount` via real factory path)
- [ ] After production deploy: loupe `facetAddress(sel) != 0` for every product selector
- [ ] Smoke: each product function invoked on the **proxy** (not the facet implementation address)

### Trust flags (I) — if `pretransferred` / Permit2 / native value exists

- [ ] **I1** `pretransferred=true`, no transfer, vault already holds ≥ amount → no free mint
- [ ] **I2** short transfer vs claimed amount → exact revert
- [ ] **I3** residual cannot fund a second free mint
- [ ] Happy-path pretransfer with real funds (not a substitute for I1–I3)

### Classic adversarial P0 (when product surface applies)

- [ ] Donation / free mint (A1/A3)
- [ ] Reentrancy cross-entry (C*)
- [ ] Authority / claim (D*)
- [ ] Round-trip + residual (E1/E5/H3)
- [ ] Access (F*)
- [ ] Atomic fail (H2)

### Accounting sync (K)

- [ ] Donation or dust cannot be consumed as another user’s deposit without policy + tests

## 4. Property layer (strongly recommended)

Fixed adversarial catalogs do **not** replace:

- [ ] At least one `testFuzz_*` on mint/burn or exchange conservation where math is non-trivial
- [ ] Handler / sequence invariants for multi-call residual and multi-user interleaving (see `docs/testing/FUZZ_INVARIANT_*` in consumer repos)

## 5. Anti-rubber-stamp

| Do not accept as done | Why |
|----------------------|-----|
| Facet declaration tests only | Can match incomplete Facet to incomplete control |
| Happy-path pretransfer only | Misses free mint from existing reserves |
| Tests against facet address | Misses missing diamondCut selectors |
| `expectRevert()` bare | Wrong failure can still “pass” |
| Mock SUT | Does not prove production deploy path |

## 6. Commands (evidence)

```bash
forge test --match-path 'test/foundry/spec/<feature>/**' -vv
forge test --match-path 'test/foundry/spec/<feature>/adversarial/**' -vv
# Prefer grepping for catalog IDs:
# rg "function test_I1_|function test_J2_|function test_A1_" test/...
```

## Related

- `crane-adversarial-testing` — catalog A–K, harnesses
- `crane-testing` — LR-7, Behaviors, production-first
- `crane-deployment` — factories, DFPkg
- Consumer IndexedEx: `indexedex-testing`, `indexedex-adversarial-testing`
