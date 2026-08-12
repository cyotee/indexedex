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
2. Attack catalog IDs (A–H classic + A0 empty-vault + I trust-flag + J surface + K accounting-sync + L AMM desync + M middleware + N TOCTOU + O signatures)
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
    Adversarial_AmmDesync.t.sol         # L1–L3 AMM reserve / FoT / skim-class (if product prices or holds LP)
    Adversarial_Middleware.t.sol        # M1–M3 arbitrary call / swap target / allowance
    Adversarial_Toctou.t.sol            # N1–N2 quote–settle / preview vs execute
    Adversarial_Signatures.t.sol        # O1–O3 permit / ecrecover / replay (if product has sig paths)
```

Naming: `test_<ID>_<behavior>()` so greps prove catalog coverage (`test_A1_...`, `test_A0_...`, `test_I1_...`, `test_L1_...`, `test_J2_...`).

## Attack catalog (generic vault / diamond)

| Cat | Theme | Examples | Typical pass |
|-----|--------|----------|--------------|
| **A** | Donation / inflation | Transfer assets/shares/BPT to diamond without mint path; first-depositor share inflation | No free mint; idle inventory cannot steal others' balances; empty-vault mint is safe or gated |
| **A0** | Empty vault / residual inventory | `totalSupply()==0` (or no dead shares) while contract holds assets; first minter drains pre-seeded inventory | First mint cannot claim unaccounted inventory; dead shares / virtual offset / init gate |
| **B** | Spot / rate manipulation | Skew underlying AMM → mint → reverse → burn | No free lunch **or** bounded intentional seigniorage + safety invariants |
| **C** | Reentrancy / cross-entry | Hostile share reenters mint/bond/redeem/init | Nested `IsLocked` (or equivalent nonReentrant) |
| **D** | Authority / claim / NFT | Redeem without claim; double redeem; onlyOwner vaults | Revert; no over-claim of principal |
| **E** | Accounting / residual | Round-trip conservation; zero amount; deadline; fee-on-transfer `actualIn`; **surplus-refund** paths that pay `balance − X` to caller | Residual free inventory 0; exact/approx deltas; credit = observed in; refunds use **accounted liability**, not raw balance |
| **F** | Access / immutability | diamondCut, setWeights, mintFromNFTSale by EOA; **permissionless structural ops** that resize/settle inventory (realloc-class, treasury resize, migrate) | Fail; no owner upgrade surface if unowned; value-settling structural ops are auth-gated or cannot refund untracked surplus |
| **G** | Composition | Nested vault as leg | Outer activity does not brick inner |
| **H** | Grief / DoS | minOut fail, min-balance exit fail | Clean revert; **atomicity** (no permanent burn without payout) |
| **I** | Trust-flag / claimed amount | `pretransferred=true` with **no** transfer; claim `amountIn` against absolute vault balance that already holds reserves; permit amount ≠ actual; `msg.value` mismatch | Revert **or** credit only measured **delta** since last snapshot / call start; attacker balance of shares/product must not increase without paying |
| **J** | Surface completeness | Target has `foo()` but Facet omits selector; DFPkg `facetCuts` incomplete; proxy loupe missing product API | After production deploy: every product selector is on loupe **and** succeeds as a real call (or intentional access revert) |
| **K** | Accounting sync | `lastTotalAssets` / reserve snapshot stale; donation then next deposit mis-credits; skim vs internal books diverge | Next user cannot mint from prior donation; mismatch reverts with exact selector or donation is explicitly accepted with documented beneficiary |
| **L** | AMM reserve / balance desync | Untracked pair surplus + public skim; FoT leaves books ≠ balances; burn-from-pair used as mint/burn oracle | Protocol books match balances; no free extract of untracked surplus; FoT does not desync NAV |
| **M** | Middleware / arbitrary call / allowance | Public `target+calldata` with held ERC20 allowance; user-supplied swap target; third-party `transferFrom` without intent | No user-supplied call with protocol/user allowances; allowlisted routers; amountOut measured |
| **N** | Quote–settle TOCTOU | Mid-tx hook/valuation changes units between quote and settle; preview ≠ execute | Hostile callback between quote and settle cannot inflate credit or drain inventory |
| **O** | Signature / permit failure | ecrecover address(0); invalid/dummy sig accepted; missing nonce/deadline; domain/typehash mismatch | Invalid/zero/reused sig reverts; never authorizes address(0) |

**Do not renumber A–K.** A0 and L/M/N/O are extensions only.

Map product-specific surfaces onto this catalog; drop irrelevant categories with a one-line deferred reason.

### Boundary map (avoid double-count)

| Existing | When to use vs new |
|----------|--------------------|
| **A** | Assets arrive *without* mint path; classic donation/inflation |
| **A0** | Residual assets with empty/zero share supply (first minter drain) |
| **I** | Caller *claims* transfer via `pretransferred` / permit amount |
| **K** | Stale internal snapshot; next user free credit from prior donation |
| **L** | *External AMM* pair balance≠reserve; FoT pair surplus; skim-class |
| **E** vs **L1** | E = product refund/residual math on own books; L1 = untracked surplus extract (incl. public skim / surplus-refund) |
| **B** vs **L3** | B = economic skew of *priced* path; L3 = books/oracle trust of desynced reserves |
| **C** vs **N** | C = reentrancy into locked path; N = logic TOCTOU without same-lock reentry |
| **M** vs **F** | F = product access control; M = helper/router forwarding with allowances |

### Category E / L1 cross-cut — surplus-refund & structural value settlement

Any path that returns value as **`address(this).balance − floor`**, **`token.balanceOf(this) − someMin`**, or “rent/resize delta to `msg.sender`” is a **public skim of untracked surplus** unless the refund is capped to **caller-accounted liability** only.

| ID | Attack | Pass | P |
|----|--------|------|---|
| **E6** | Overpay / donate ETH or tokens, then hit a refund path that pays raw balance above a floor to the caller | Refund ≤ caller’s tracked credit / overpay for **this** call; prior inventory and other users’ balances stay put | P0 if any refund / residual-return path exists |
| **F5** | Untracked surplus + **permissionless** resize / migrate / reclaim that settles value to the caller | No free extract of protocol surplus; structural ops auth-gated **or** refund math cannot touch surplus inventory | P0 if public structural settle exists |
| **L1** | Untracked surplus extract (pair skim, idle native/ERC20 reclaim chains) | Books match balances; no free extract of untracked surplus | P0 if holds AMM LP, prices from pair reserves, **or** holds idle inventory with public reclaim |

**EVM anti-pattern (sketch):**

```solidity
// WRONG — refunds all surplus inventory, not just this caller's overpay
uint256 refund = address(this).balance - requiredReserve;
payable(msg.sender).transfer(refund);

// RIGHT — refund only measured overpay for this call
uint256 refund = msg.value - amountDue; // or tracked credit for msg.sender
payable(msg.sender).transfer(refund);
```

Cross-VM lesson (Solana realloc / rent refund CTFs): shrinking or resettling an account that holds **trading proceeds above rent floor** can pay the entire surplus to `realloc_payer` when the framework refunds `lamports − new_rent_exempt`. Same class as **E6 / L1 / F5** — map to hermetic EVM tests; do not renumber A–K.

### Category L — AMM reserve / balance desync (P0 when product prices from pair reserves or holds LP)

| ID | Attack | Pass | P |
|----|--------|------|---|
| **L1** | Untracked balance / public skim-class surplus on protocol-owned or protocol-priced inventory (incl. surplus-refund / permissionless migrate+reclaim chains) | Books match balances; no free extract of untracked surplus | P0 if holds AMM LP, prices from pair reserves, **or** holds idle native/ERC20 with public reclaim |
| **L2** | FoT / deflationary transfer leaves books ≠ balances | Credit ≤ actual; NAV not inflated by phantom FoT surplus | P1 default; P0 if product claims FoT support |
| **L3** | Burn-from-pair or direct pair reserve skew used as mint/burn oracle | Spot path cannot free-mint beyond documented deadband/seigniorage policy | P0 when mint/burn uses spot/reserves without TWAP/deadband |

### Category M — Middleware / arbitrary call / allowance (P0 for routers/helpers)

| ID | Attack | Pass | P |
|----|--------|------|---|
| **M1** | Public arbitrary `call`/`delegatecall` with held ERC20 allowance | No user-supplied `target+calldata` against held allowances | P0 |
| **M2** | User-supplied swap target without path/out validation | Allowlisted routers only; amountOut measured | P0 for issuance/exchange helpers |
| **M3** | Allowance sweep / `transferFrom` third party without explicit intent | Revert or explicit permit path only | P0 |

### Category N — Quote–settle TOCTOU (P0 for multi-step issue/bond with callbacks)

| ID | Attack | Pass | P |
|----|--------|------|---|
| **N1** | Mid-tx external valuation/hook changes units between quote and settle | Hostile hook cannot inflate credit or drain inventory | P0 |
| **N2** | Preview/view path inconsistent with execute (stale snapshot) | Documented tolerance or exact match | P1 |

### Category O — Signature / permit (P0 if product has permit/sig paths)

| ID | Attack | Pass | P |
|----|--------|------|---|
| **O1** | Permit/ecrecover accepts invalid or address(0) signer | Invalid/zero signer reverts | P0 if permit exists |
| **O2** | Signature replay / missing nonce or deadline | Replay reverts | P0 if permit exists |
| **O3** | Permit2 / EIP-712 typed data mismatch (domain, typehash) | Wrong domain/type reverts; credit actual only (see **I5**) | P1 |

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
| Only reading historical fork PoCs without hermetic tests | Map incident → catalog ID → production-path abuse test |
| Fork profit assert (`assertGt(attackerBal, 0)`) as security coverage | Pass = exploit **blocked** (or bounded intentional risk) |

## Priority guidance

| Priority | Ship gate? | Examples |
|----------|------------|----------|
| **P0** | Yes — "adversarially tested" | Free principal redeem, reentrancy, residual after fail, onlyOwner critical mints, donation free-mint, **A0** empty vault, **I1–I3** trust-flag, **J1–J3** surface, **K** reserve-sync, **L1/L3** if AMM-priced or idle-inventory reclaim, **E6** if refund path, **F5** if public structural settle, **M*** if router/helper, **N1** if multi-step issue, **O1–O2** if permit |
| **P1** | Should before major release | Nested composition, lock clamps, soft non-dilution, deadband gates, I4–I5, L2 FoT, N2 preview, O3 typed-data |
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
2. If the product can hold inventory before live shares (or zero `totalSupply` with residual assets): **A0** green.
3. If the product has pull/credit flags (`pretransferred`, Permit2, `msg.value`): **I1–I3** green.
4. Every new Facet/DFPkg: **J1–J3** green (Target → Facet → live proxy).
5. If reserve/`lastTotalAssets` accounting exists: at least one **K** free-credit / mismatch case.
6. If the product prices from AMM pair reserves or holds LP **or** has public reclaim/refund of idle inventory: applicable **L1** / **E6** / **F5** P0 green (or deferred with reason).
7. If any router/helper forwards user calldata or holds open allowances: applicable **M** P0 green.
8. If multi-step issue/bond has external hooks between quote and settle: **N1** green.
9. If permit/signature paths exist: **O1–O2** green.
10. `forge test --match-path '.../adversarial/**'` and full feature path exit 0.
11. No known unbounded profitable exploit left greenwashed.

Happy-path coverage alone is **never** sufficient for trust-flag, surface, or empty-vault classes.

## See also

- `skill:crane-testing` — production-first, TestBase, Behavior, LR-7, surface matrix, accounting gates
- `skill:crane-deployment` — CREATE3 / DFPkg in tests
- `skill:crane-architecture` — Facet/Target/Repo; `facetFuncs` must enumerate product API
- `skill:crane-access` — nonReentrant / IsLocked
- `skill:forge-testing` — cheatcodes only (subordinate for protocol tests)
- `skill:forge-fuzz-testing` / property-based testing — L1/L3 properties complement fixed adversarial catalogs
- Consumer: `skill:indexedex-adversarial-testing` when working in IndexedEx vaults/DETFs
- Consumer (IndexedEx monorepo): `skill:defi-incident-patterns` — historical incident → catalog ID map (reference corpus only)

## References

- `references/attack-catalog-template.md` — copy/paste catalog + suite NatSpec stubs
- `references/implementation-test-dod.md` — ship-gate checklist for implementors
- `references/incident-pattern-bridge.md` — thin map from real-world incident themes to A0/L/M/N/O
