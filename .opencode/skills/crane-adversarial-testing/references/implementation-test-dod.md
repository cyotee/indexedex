# Implementation + test Definition of Done (Crane diamonds / vaults)

Use this as a **ship gate** for any new Facet, Target money path, DFPkg, or vault product. Complements `crane-testing` LR-7 and the adversarial catalog (A–K + **A0**, **L**, **M**, **N**, **O**).

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

- [ ] Empty vault / residual inventory (**A0**) — first minter cannot drain pre-seeded assets at zero supply
- [ ] Donation / free mint (A1/A3)
- [ ] Reentrancy cross-entry (C*)
- [ ] Authority / claim (D*)
- [ ] Round-trip + residual (E1/E5/H3)
- [ ] **E6** surplus-refund: if any path refunds residual ETH/tokens to caller, prior inventory / other users cannot be drained
- [ ] Access (F*)
- [ ] **F5** if public resize/migrate/reclaim exists: cannot free-extract idle surplus
- [ ] Atomic fail (H2)

### Accounting sync (K)

- [ ] Donation or dust cannot be consumed as another user’s deposit without policy + tests
- [ ] Transfer/migrate amounts use consistent books vs balance (no silent desync that enables free extract)

### AMM desync / surplus reclaim (L) — if product prices from pair reserves, holds LP, **or** has public reclaim of idle inventory

- [ ] **L1** untracked surplus / skim-class cannot free-mint or free-extract protocol inventory
- [ ] **L3** burn-from-pair / reserve skew cannot free-mint beyond documented deadband (if spot-priced)
- [ ] **L2** FoT shortfall credited correctly (P0 if product claims FoT support; else P1/defer)

### Middleware (M) — if any router/helper/facet forwards calldata or holds open allowances

- [ ] **M1** no user-supplied `target+calldata` against held allowances
- [ ] **M2** swap targets allowlisted; amountOut measured (issuance/exchange helpers)
- [ ] **M3** no third-party allowance sweep without explicit intent

### Quote–settle TOCTOU (N) — if multi-step issue/bond with external hooks/callbacks

- [ ] **N1** hostile mid-flow unit/valuation change cannot inflate credit or drain inventory
- [ ] **N2** preview vs execute consistency (P1)

### Signatures (O) — if permit / EIP-712 / Permit2 paths exist

- [ ] **O1** invalid / address(0) ecrecover never authorizes
- [ ] **O2** replay / missing nonce or deadline reverts
- [ ] **O3** domain/typehash mismatch reverts (P1; also **I5**)

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
# rg "function test_I1_|function test_J2_|function test_A0_|function test_A1_|function test_L1_|function test_M1_|function test_N1_|function test_O1_" test/...
```

## Related

- `crane-adversarial-testing` — catalog A–K + A0/L/M/N/O, harnesses
- `crane-testing` — LR-7, Behaviors, production-first
- `crane-deployment` — factories, DFPkg
- Consumer IndexedEx: `indexedex-testing`, `indexedex-adversarial-testing`, `defi-incident-patterns` (incident → ID map; reference corpus only)
