---
name: crane-adversarial-testing
description: This skill should be used when the user asks to "write adversarial tests", "abuse tests", "attack catalog", "donation attack test", "reentrancy test vault", "security tests for diamond", "adversarial suite", "threat model tests", "IsLocked reentrancy", or needs guidance implementing production-first adversarial / abuse Foundry tests for Crane diamonds, vaults, ERC-4626-like products, or similar modular architectures.
license: MIT
---

# Crane Adversarial Testing

Write **abuse-oriented Foundry tests** that drive **real production entry points** (CREATE3 + DFPkg + factories), not mocks of the SUT. Happy-path matrix tests prove the product works; adversarial suites prove attacks fail (or document intentional economic risk with hard safety invariants).

**Read first:** `crane-testing` (production-first + LR-7), `crane-deployment` (factories), `crane-access` (reentrancy / operable). Consumer projects (e.g. IndexedEx) add a product-specific skill on top of this one.

## When to use this skill

- Scaffolding an `adversarial/` suite next to feature specs
- Threat-modeling a Diamond vault, ERC-4626 wrapper, or multi-token product
- Porting MultiVaultWeightedDetf-style attack catalogs to other Crane packages
- Reviewing whether a "security test" is real or test theater

## Non-negotiable rules

1. **Production-first SUT** — real facets / DFPkgs / diamond instances via `CraneTest` factories. Never mock the subject under test.
2. **Real entry points** — `exchangeIn`, `deposit`, `bond`, `redeem`, `initializeReserve`, etc. as users call them. Do not re-implement SUT math inside the test.
3. **Allowed harnesses only:**
   - Hostile ERC20 (`transfer` / `transferFrom` reentrancy)
   - Attacker EOA / multicall bot (`vm.prank`, flash-style capital via mintable underlyings)
   - Mintable tokens for funding
4. **Forbidden:** `vm.mockCall` on SUT; `MockVault` as SUT; hard-coded expected exploit profits that skip the call path.
5. **Pass criteria are binary:** exploit **blocked** (revert / no value theft) **or** intentional economic risk **documented** with invariants that still hold (e.g. seigniorage when gates open, but bond principal not free-drainable).
6. **If a profitable exploit is real** — fix production first; never greenwash as "expected" without a product decision and bounds.
7. **Never trust caller-claimed amounts** — any path that accepts `amountIn` / `pretransferred` / permit amount / `msg.value` must credit only an **observed balance delta** (or strict equivalent), never absolute balance and never the caller's claim alone. See **I (Trust-flag abuse)**.
8. **Diamond surface is part of security** — every product-facing Target entry must be in `facetFuncs()` **and** callable on a production-deployed proxy. Missing selectors are silent fund-path / view-path failures. See **J (Surface completeness)** and `crane-testing` LR-7 surface matrix.

## Workflow (do this in order)

```
1. Threat model table (actor × surface × asset × trust flags)
2. Attack catalog IDs (A–H classic + I trust-flag + J surface + K accounting-sync)
3. Priority P0 / P1 / P2
4. Adversarial plan markdown (status, checklist, pass criteria)
5. TestBase_*_Adversarial harness (extends feature TestBase)
6. One suite file per category (or tight grouping)
7. forge test match-path adversarial/** then full feature path
8. Checklist + deferred NatSpec for unimplemented IDs
```

### Plan document skeleton

Place next to the feature (or under `test/.../adversarial/`):

```markdown
# <Feature> — Adversarial Test Plan
## Status: PLANNED | IMPLEMENTED (P0/P1)
## Threat model | Attack catalog | Priority
## Already covered (baseline — do not duplicate)
## File layout | Invariants | Acceptance criteria
## Deferred P2 with reason
```

Acceptance: every P0/P1 ID has a real test **or** is explicitly deferred with reason in suite NatSpec (not only chat).

## Directory layout

```text
test/foundry/spec/<feature>/
  <Feature>_Happy.t.sol              # keep green
  adversarial/
    TestBase_<Feature>_Adversarial.sol
    Adversarial_Guards.t.sol
    Adversarial_Access.t.sol
    Adversarial_Reentrancy.t.sol
    Adversarial_Donation.t.sol
    Adversarial_Economic.t.sol
    Adversarial_PriceManipulation.t.sol   # if pool-implied pricing
    Adversarial_Griefing.t.sol
    Adversarial_TrustFlags.t.sol        # I1–I5 pretransferred / claimed amount
    Adversarial_Surface.t.sol           # J1–J4 Target↔Facet↔proxy (or co-locate with declaration tests)
```

Naming: `test_<ID>_<behavior>()` so greps prove catalog coverage (`test_A1_...`, `test_I1_...`, `test_J2_...`).

## Attack catalog (generic vault / diamond)

| Cat | Theme | Examples | Typical pass |
|-----|--------|----------|--------------|
| **A** | Donation / inflation | Transfer assets/shares/BPT to diamond without mint path; first-depositor share inflation | No free mint; idle inventory cannot steal others' balances; empty-vault mint is safe or gated |
| **B** | Spot / rate manipulation | Skew underlying AMM → mint → reverse → burn | No free lunch **or** bounded intentional seigniorage + safety invariants |
| **C** | Reentrancy / cross-entry | Hostile share reenters mint/bond/redeem/init | Nested `IsLocked` (or equivalent nonReentrant) |
| **D** | Authority / claim / NFT | Redeem without claim; double redeem; onlyOwner vaults | Revert; no over-claim of principal |
| **E** | Accounting / residual | Round-trip conservation; zero amount; deadline; fee-on-transfer `actualIn` | Residual free inventory 0; exact/approx deltas; credit = observed in |
| **F** | Access / immutability | diamondCut, setWeights, mintFromNFTSale by EOA | Fail; no owner upgrade surface if unowned |
| **G** | Composition | Nested vault as leg | Outer activity does not brick inner |
| **H** | Grief / DoS | minOut fail, min-balance exit fail | Clean revert; **atomicity** (no permanent burn without payout) |
| **I** | Trust-flag / claimed amount | `pretransferred=true` with **no** transfer; claim `amountIn` against absolute vault balance that already holds reserves; permit amount ≠ actual; `msg.value` mismatch | Revert **or** credit only measured **delta** since last snapshot / call start; attacker balance of shares/product must not increase without paying |
| **J** | Surface completeness | Target has `foo()` but Facet omits selector; DFPkg `facetCuts` incomplete; proxy loupe missing product API | After production deploy: every product selector is on loupe **and** succeeds as a real call (or intentional access revert) |
| **K** | Accounting sync | `lastTotalAssets` / reserve snapshot stale; donation then next deposit mis-credits; skim vs internal books diverge | Next user cannot mint from prior donation; mismatch reverts with exact selector or donation is explicitly accepted with documented beneficiary |

Map product-specific surfaces onto this catalog; drop irrelevant categories with a one-line deferred reason.

### Category I — Trust-flag abuse (mandatory P0 for any vault with `pretransferred` / pull-or-credit)

This is a **distinct failure class from A (donation)**. Donation is “assets arrive without a mint path.” Trust-flag abuse is “caller **claims** assets arrived (or will) and the SUT mints/credits without proving a delta.”

**Bug pattern (real production class):**

```solidity
// WRONG — absolute balance check trusts prior inventory as "this user's" transfer
if (pretransferred) {
    require(token.balanceOf(address(this)) >= amountIn);
    return amountIn; // credits claimed amount; vault may already hold amountIn from reserves/donations
}
```

**Correct pattern (sketch):**

```solidity
// RIGHT — credit only observed inbound delta (or pull + re-measure)
uint256 before = token.balanceOf(address(this)); // or lastSyncedReserve
// if !pretransferred: pull amountIn
uint256 actualIn = token.balanceOf(address(this)) - before;
require(actualIn == amountIn /* or >= with refund/strict policy */, "...");
// mint/credit using actualIn, not amountIn alone
// update lastSyncedReserve / lastTotalAssets
```

**Required adversarial tests (P0 when flag exists):**

| ID | Attack | Pass |
|----|--------|------|
| **I1** | `pretransferred=true`, **zero** transfer, vault already holds ≥ `amountIn` reserves | Revert **or** zero credit; attacker share/product balance unchanged |
| **I2** | `pretransferred=true`, transfer **less** than claimed `amountIn` | Revert exact selector (e.g. transfer-not-received / insufficient pretransfer) |
| **I3** | `pretransferred=true`, transfer exact, then second call reuses residual without new transfer | Second call cannot free-mint from residual |
| **I4** | `pretransferred=false` path still measures post-pull **delta** (fee-on-transfer shortfall) | Credit ≤ actual received; no phantom shares |
| **I5** | Permit2 / signature path: signed amount ≠ delivered | Revert or credit actual only |

Do **not** treat happy-path `pretransferred=true` with a real transfer as coverage for I1–I3.

### Category J — Diamond surface completeness (mandatory P0 for every new Facet / DFPkg)

Facet declaration tests that only compare `facetFuncs()` to a **hand-written control list** can pass when **both** lists omit the same function. That is test theater.

**Three-way (or four-way) matrix — all required:**

| Layer | Source of truth | Assert |
|-------|-----------------|--------|
| 1. Target product API | External/public money + documented views on Target | Enumerate selectors |
| 2. Facet declaration | `IFacet.facetFuncs()` / `facetInterfaces()` | **Equals** Target product API (or explicit intentional split across facets with no orphan) |
| 3. Package cuts | DFPkg `facetCuts()` / `diamondConfig` | Every facet selector appears in a cut |
| 4. Live proxy | Production deploy via factory/registry; loupe `facetAddress(sel)` | Non-zero; low-level call does not `FunctionNotFound` |

**Required tests:**

| ID | Test | Pass |
|----|------|------|
| **J1** | Control list built from **Target** (or interface of product), not from Facet source alone | Facet matches Target |
| **J2** | After DFPkg deploy, for each product selector: `facetAddress(sel) != 0` | All wired |
| **J3** | Smoke call each product entry on **proxy** (not facet address) | Succeeds or exact access/guard revert — never empty-code / unknown selector |
| **J4** | Package `facetCuts` length/selectors match declared facets | No silent drop |

See also Recon-style diamond structural invariants: selector uniqueness, loupe consistency, no dangling selectors (use when upgrade/`diamondCut` is live; unowned immutable diamonds still need J1–J3 at deploy).

## Harness patterns

### Hostile reentrant ERC20

```solidity
contract RecordingReentrantShare is MockERC20 {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    function arm(address target_, bytes memory reentryCall_) external { /* set + reset counters */ }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (armed && _depth == 0) {
            _depth = 1;
            ++reentryAttempts;
            (bool ok, bytes memory ret) = target.call(reentryCall);
            nestedCallSucceeded = ok;
            if (!ok && ret.length >= 4) {
                bytes4 sel;
                assembly { sel := mload(add(ret, 0x20)) }
                nestedErrorSelector = sel;
            }
            _depth = 0;
        }
        return super.transferFrom(from, to, value);
    }
}
```

**Critical:** complete the outer transfer after nested call so probe state persists (do not `require` nested success). Assert:

```solidity
assertEq(hostile.reentryAttempts(), 1);
assertFalse(hostile.nestedCallSucceeded());
assertEq(hostile.nestedErrorSelector(), IReentrancyLock.IsLocked.selector);
```

Wire hostile share as a **configured product token** (vault share / pool token) via production DFPkg args when the product accepts it — not via mockCall.

### Adversarial TestBase helpers

| Helper | Purpose |
|--------|---------|
| `attacker` / `victim` | Distinct EOAs via `makeAddr` |
| `_openLive*` / go-live | Product reaches operable state the same way as production |
| `_assertNoFreeInventory` | Diamond holds ~0 free shares / free product token after success |
| `_swapUnderlying` | Real AMM trade for rate/spot manipulation (not mock price) |
| Snapshot balances | Pre/post deltas for conservation |

### Assertions style

- Prefer **exact** `assertEq` / `assertLe` on deltas (LR-7).
- Allow documented ≤ few-wei only when Balancer/AMM math forces it (`assertApproxEqAbs(..., 10)`).
- On failed paths: assert **residual free inventory is zero** and user funds not stranded mid-function.
- On claim/exit: assert **failed redeem leaves claim balance unchanged** (full-tx atomicity).

## Intentional economic risk (do not confuse with bugs)

Some products expose **seigniorage / open mint-burn windows** when pricing gates allow both directions. A profitable skew-mint-burn under *open* thresholds may be **by design**.

Document with hard safety invariants, for example:

- Victim token balances unchanged by attacker path
- No free reserve principal without claim/NFT authority
- Residual free inventory clean
- Profit bounded vs bootstrap / not unbounded drain

Under closed thresholds (deadband), assert mint and burn are **not** simultaneously allowed.

## Anti-patterns (test theater)

| Theater | Fix |
|---------|-----|
| `assertTrue(true)` after unused setup | Drive real entry point |
| Hard-code expected out without calling preview/execute | `preview` then `exchange`/`deposit`; compare |
| Mock SUT return values | Deploy real package |
| Only static `grep` for security | Static ok as *supplement*; P0 needs execution |
| Duplicate happy-path under "adversarial" name | Link baseline; add cross-function / abuse only |
| Silent missing catalog IDs | Deferred NatSpec + plan checkbox |
| Happy-path `pretransferred=true` with real transfer only | Add **I1–I3** false-claim / short-transfer cases |
| `controlFacetFuncs` copied from incomplete Facet | Build control from **Target/interface** product API (**J1**) |
| Declaration tests on facet contract only | Also deploy package and call **proxy** (**J2–J3**) |
| Absolute `balanceOf(vault) >= amount` as “proof of transfer” | Measure **delta** vs last reserve / balBefore |
| `expectRevert()` without selector | Exact selector + state unchanged |
| Line coverage without balance invariants | Assert attacker did not gain shares/assets for free |

## Priority guidance

| Priority | Ship gate? | Examples |
|----------|------------|----------|
| **P0** | Yes — "adversarially tested" | Free principal redeem, reentrancy, residual after fail, onlyOwner critical mints, donation free-mint, **I1–I3 trust-flag**, **J1–J3 surface**, **K** reserve-sync free credit |
| **P1** | Should before major release | Nested composition, lock clamps, soft non-dilution, deadband gates, I4–I5, weird-token FoT |
| **P2** | Explicit defer OK | Gas grief N=max, peer product ports, rare sandwich/MEV fork reconstructions |

## Run & evidence

```bash
forge test --match-path 'test/foundry/spec/<feature>/adversarial/**' -vv
forge test --match-path 'test/foundry/spec/<feature>/**'   # happy + adversarial
```

Capture logs for verification goals. Update plan status to **IMPLEMENTED (P0/P1)** only when both paths exit 0 and deferred IDs are documented.

## Definition of “adversarially tested” (ship gate)

A feature is **adversarially tested** only when **all** of the following hold:

1. Catalog A–H applicable P0 IDs have real tests or explicit NatSpec deferral.
2. If the product has pull/credit flags (`pretransferred`, Permit2, `msg.value`): **I1–I3** green.
3. Every new Facet/DFPkg: **J1–J3** green (Target → Facet → live proxy).
4. If reserve/`lastTotalAssets` accounting exists: at least one **K** free-credit / mismatch case.
5. `forge test --match-path '.../adversarial/**'` and full feature path exit 0.
6. No known unbounded profitable exploit left greenwashed.

Happy-path coverage alone is **never** sufficient for (2) or (3).

## See also

- `skill:crane-testing` — production-first, TestBase, Behavior, LR-7, surface matrix, accounting gates
- `skill:crane-deployment` — CREATE3 / DFPkg in tests
- `skill:crane-architecture` — Facet/Target/Repo; `facetFuncs` must enumerate product API
- `skill:crane-access` — nonReentrant / IsLocked
- `skill:forge-testing` — cheatcodes only (subordinate for protocol tests)
- `skill:forge-fuzz-testing` / property-based testing — L1/L3 properties complement fixed adversarial catalogs
- Consumer: `skill:indexedex-adversarial-testing` when working in IndexedEx vaults/DETFs

## References

- `references/attack-catalog-template.md` — copy/paste catalog + suite NatSpec stubs
- `references/implementation-test-dod.md` — ship-gate checklist for implementors
