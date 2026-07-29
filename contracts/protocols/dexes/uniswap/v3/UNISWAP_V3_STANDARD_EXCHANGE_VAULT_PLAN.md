# Plan: Uniswap V3 Standard Exchange Vault

**Status:** IMPLEMENTED (hermetic + adversarial green; fork blocked by env/compile of unrelated fork suite)  
**Date:** 2026-07-28  
**Normative PRD:** [`UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PRD.md`](./UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PRD.md) (**LOCKED**, D1–D18)  
**Primary behavioral template:** Slipstream Standard Exchange  
**Secondary layout reference:** Uniswap V4 Standard Exchange (package wiring, factory service, import *surface*)

This plan is the execution checklist for the PRD. If plan and PRD conflict, **update the PRD first** — do not silently drift.

---

## Progress Snapshot

| Area | State |
|------|--------|
| PRD | LOCKED (incl. 2026-07-28 clarifications) |
| Implementation | Shipped under `contracts/protocols/dexes/uniswap/v3/` (repos, Common, In/InQuery/Out/Import, DFPkg, FactoryService, TestBase) |
| Hermetic tests | Green — `test/foundry/spec/protocol/dexes/uniswap/v3/**` (50 tests) |
| Preview = execution suite | Green — `UniswapV3StandardExchange_Previews.t.sol` (§9.2; few-wei tol on zap multi-step) |
| Adversarial suite | Green — `adversarial/**` P0+P1 catalog |
| Base mainnet fork smoke | Blocked — `FOUNDRY_PROFILE=fork` fails compile of unrelated eth_main unicode string; pin documented in fork test + env log |
| EIP-170 | InFacet split: In + InQuery; InFacet runtime 23,721 &lt; 24,576 |

---

## 1. Goal

Ship an IndexedEx **Standard Exchange (SE)** vault package for **Uniswap V3** that matches Slipstream / Uni V4 SE user shape:

1. Direct pool-side exact-in and exact-out between the two pool tokens.
2. Single-sided zap-in (pool token → vault shares).
3. Single-sided zap-out (vault shares → pool token).
4. ERC-20 vault shares = proportional ownership of managed CL positions (center + wings).
5. CREATE3 + vault-registry deploy via IndexedEx manager.
6. Optional first-deposit bootstrap: import NPM NFT → **direct pool** center position (empty NFT left on vault; not runtime vehicle).

**Not** ERC-4626. Multi-asset SE diamond.

### Non-goals (v1) — do not expand scope

See PRD §2. Summary: no DETF consumers, no DualLiquidity, no rebalance, no multi-hop, no native ETH, no long-lived NPM ownership, no pool creation, no ERC-4626.

---

## 2. Architecture Summary

| Concern | Choice |
|---------|--------|
| Economics / wings / share math | **Slipstream SE** |
| Package / factory / manager wiring | **Uni V4 SE** patterns |
| Pool identity | `IUniswapV3Pool` address (canonical) |
| Position ownership | Direct `pool.mint/burn/collect/swap`; owner = vault |
| Position key | `keccak256(abi.encodePacked(address(this), tickLower, tickUpper))` — no salt |
| Callbacks | `IUniswapV3MintCallback` + `IUniswapV3SwapCallback` on diamond |
| Quotes | Crane `UniswapV3Quoter` / `UniswapV3ZapQuoter` |
| Factory validation | **Mandatory** `pool.factory() == uniswapV3Factory` at init |
| Fees | Collect + **compound before new depositor credit**; vault fee on fee redeposit when wired |
| Import | Convert NFT → direct center; leave empty NFT; `previewImportPosition` required |

### Normative rule

Prefer Slipstream for economics and route matrix. Prefer V4 only for diamond package layout, FactoryService, manager deploy, and the *existence* of an import facet (import **mechanics** differ — convert, do not keep NFT as position manager).

---

## 3. Proposed Files

```text
contracts/protocols/dexes/uniswap/v3/
├── UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PRD.md          # locked product
├── UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PLAN.md         # this file
├── UniswapV3PoolAwareRepo.sol
├── UniswapV3FactoryAwareRepo.sol                      # required
├── UniswapV3VaultRepo.sol                             # center/wings/strategy (or *PositionRepo)
├── UniswapV3StandardExchangeCommon.sol                # callbacks + shared execution
├── UniswapV3StandardExchangeInTarget.sol
├── UniswapV3StandardExchangeInFacet.sol
├── UniswapV3StandardExchangeOutTarget.sol
├── UniswapV3StandardExchangeOutFacet.sol
├── UniswapV3StandardExchangePositionImportTarget.sol
├── UniswapV3StandardExchangePositionImportFacet.sol
├── UniswapV3StandardExchangeDFPkg.sol
├── UniswapV3_Component_FactoryService.sol
└── test/bases/
    └── TestBase_UniswapV3StandardExchange.sol
```

Likely support edits outside the directory:

1. Manager typed `deployUniswapV3StandardExchangeDFPkg` (peer of Slipstream / V4).
2. Vault type / USAGE fee registration on `IStandardVault` interface id (peer pattern).
3. Specs under `test/foundry/spec/protocol/dexes/uniswap/v3/`.
4. Fork under `test/foundry/fork/base_main/protocol/dexes/uniswap/v3/`.
5. Adversarial plan + suites (see §10).

### Crane reuse (do not reimplement)

1. `lib/crane/.../uniswap/v3/*` pool / factory / periphery port  
2. `UniswapV3Quoter`, `UniswapV3ZapQuoter`, `UniswapV3Utils`  
3. `TestBase_UniswapV3`, `TestBase_UniswapV3Periphery`  

### Skills

`crane-deployment`, `crane-architecture`, `crane-testing`, `crane-adversarial-testing`, `crane-uniswap`, `indexedex-testing`, `indexedex-adversarial-testing`, Uniswap V3 + Slipstream skill families.

---

## 4. Storage And Package Wiring

### 4.1 Repos

| Repo | Responsibility |
|------|----------------|
| `UniswapV3PoolAwareRepo` | Bound `IUniswapV3Pool`; accessors for pool / token0 / token1 / fee / tickSpacing (read from pool) |
| `UniswapV3FactoryAwareRepo` | Expected `IUniswapV3Factory`; used for init validation |
| `UniswapV3VaultRepo` (or PositionRepo) | `widthMultiplier`, `centerWidthMultiplier=2`, `activeLiquidityBps=1000` (copy Slipstream defaults); center / lower / upper ticks + liquidity + `created`; optional last sqrtPrice/tick/timestamp cache; `_getOwnPositionKey(kind)` |

**Do not** store only token0/token1/fee without pool address.

### 4.2 `PkgInit` / `PkgArgs` (on interface only)

Per PRD §9.2 — Crane rule: structs on `IUniswapV3StandardExchangeDFPkg`, not only on the contract body.

```solidity
// PkgInit: ERC20/5267/2612 multi-asset vault facets + In/Out/Import facets
//         + feeOracle + vaultRegistry + permit2 + IUniswapV3Factory
// PkgArgs: (IUniswapV3Pool pool, uint24 widthMultiplier)
// deployVault(pool, widthMultiplier)
```

### 4.3 `initAccount` checklist

1. ERC-20 name/symbol from pool tokens + fee (peer style).  
2. `ERC20Repo`, `EIP712Repo`.  
3. Standard / multi-asset vault repos.  
4. Fee oracle + Permit2 aware repos.  
5. Pool aware + **require `pool.factory() == uniswapV3Factory`**.  
6. Strategy repo with `widthMultiplier >= 1`.  
7. Register token0/token1 as underlyings.  
8. Allowances: prefer callback settlement from vault balance; follow Slipstream practice.

### 4.4 Facet mix

1. `ERC20Facet`, `ERC5267Facet`, `ERC2612Facet`  
2. `MultiAssetBasicVaultFacet`, `MultiAssetStandardVaultFacet`  
3. `UniswapV3StandardExchangeInFacet`  
4. `UniswapV3StandardExchangeOutFacet`  
5. `UniswapV3StandardExchangePositionImportFacet`  

Callbacks must be on the diamond cut (prefer `Common` inherited by In/Out targets, or a dedicated small callback facet if selector packaging requires it).

Optional later (not v1 DoD): In-query-only facet split for size.

---

## 5. Execution Model

### 5.1 Direct pool ops

Steady state **must** call bound `IUniswapV3Pool`:

- `swap`, `mint`, `burn`, `collect`

NPM only during import conversion. Empty post-import NFT is inert.

### 5.2 Callbacks

| Selector | Auth | Behavior |
|----------|------|----------|
| `uniswapV3MintCallback` | `msg.sender == bound pool` | Pay `amount0Owed` / `amount1Owed` from vault balances |
| `uniswapV3SwapCallback` | `msg.sender == bound pool` | Settle swap deltas |

Requirements:

1. Authenticate pool (and data-encoded pool if present).  
2. Routes use Crane `nonReentrant` / `IsLocked`; callbacks must not open unguarded reentry into share mint/burn.  
3. No flash-loan receiver surface beyond mint/swap needs.

### 5.3 Liquidity strategy

**Organic first deposit** (`totalSupply == 0`, no positions created):

1. Read `slot0` + `tickSpacing`.  
2. Derive center + lower + upper wings exactly as Slipstream (`widthMultiplier`, `centerWidthMultiplier`, snap/clamp).  
3. Persist three position records; allocate with `activeLiquidityBps`.  
4. `pool.mint` with `recipient = address(this)`.

**Subsequent deposits (organic and post-import):** add only to **already created** positions (no re-centering, no wing create). After import → center only.

**Import:** center = NFT ticks; wings uncreated.

---

## 6. Share Accounting And Fee-First Compound

Mirror Slipstream economics with PRD §6.4 ordering:

### 6.1 Two-phase deposit (LOCKED pattern)

When prior positions / accrued fees exist:

| Phase | Work |
|-------|------|
| **A** | Collect fees → compound into managed liquidity (maximize remint; residual one-sided dust OK) → take **vault usage fee on fee redeposit** when fee-oracle wiring applies |
| **B** | Process **new principal** only; mint shares vs **post-compound** total vault value |

Acceptable as internal two-phase even if a single external call wraps both. New depositors must **only** be credited for their contribution.

### 6.2 Total vault value

Include:

1. Managed liquidity amounts at current sqrt price.  
2. Collectable tokens owed (until compounded).  
3. Free token0/token1 working inventory (no double-count; match Slipstream).

### 6.3 Burn

Proportional remove → collect → optional cleanup swap → burn shares after entitlement known → dust refund to `msg.sender` when peers do.

---

## 7. Route Matrix And Workflows

### 7.1 Supported routes

**Exact-in / previewExchangeIn**

| tokenIn | tokenOut |
|---------|----------|
| token0 | token1 |
| token1 | token0 |
| token0 | vault shares (zap-in) |
| token1 | vault shares (zap-in) |

**Exact-out / previewExchangeOut**

| tokenIn | tokenOut |
|---------|----------|
| token0 | token1 |
| token1 | token0 |
| vault shares | token0 (zap-out) |
| vault shares | token1 (zap-out) |

**Must revert:** share→share, same-asset no-ops, foreign tokens, multi-hop.

Errors: match Slipstream (`ExchangeInNotAvailable` / `ExchangeOutNotAvailable`) unless repo-wide SE enum already standardizes new packages.

### 7.2 Route rules

1. Zap-in never pulls a second token from the user.  
2. Zap-out final transfer measured **after** cleanup swap.  
3. `pretransferred` semantics consistent with peers.  
4. `deadline` + slippage (`minAmountOut` / `maxAmountIn`) on all mutates.  
5. `_requireNotDisabled` via fee oracle / registry if peers do.

### 7.3 Workflows (summary)

| Route | Preview | Execute |
|-------|---------|---------|
| Direct exact-in | `UniswapV3Quoter.quoteExactInput` | `pool.swap` + swap callback |
| Direct exact-out | `quoteExactOutput` | `pool.swap` + settle + refund excess |
| Zap-in | Zap quoter + fee-first model when positions exist | Phase A/B + mint + shares for new principal |
| Zap-out | Zap quoter | Burn proportional liq → cleanup → burn shares → transfer |
| Import | `previewImportPosition` | §8 conversion |

---

## 8. Position Import

### 8.1 Interface (required)

```solidity
interface IUniswapV3StandardExchangePositionImport {
    function previewImportPosition(
        INonfungiblePositionManager positionManager,
        uint256 positionTokenId
    ) external view returns (uint256 sharesOut);

    function importPosition(
        INonfungiblePositionManager positionManager,
        uint256 positionTokenId,
        uint256 minSharesOut,
        address owner,
        address recipient,
        uint256 deadline
    ) external returns (uint256 sharesOut);
}
```

### 8.2 Preconditions

1. `totalSupply() == 0`  
2. No managed position created  
3. Valid `deadline` (mutate)  
4. Vault can pull NFT and decrease under **NPM / ERC-721** (no extra IndexedEx operator policy)  
5. NFT pool matches bound pool  
6. NFT liquidity `> 0`  
7. `sharesOut >= minSharesOut` (mutate)

### 8.3 Conversion sequence

1. Validate; quote with same path as preview (principal + collectable fees).  
2. Pull NFT into vault.  
3. Full `decreaseLiquidity` + `collect` all token0/token1.  
4. **Leave empty NFT** on vault — **do not burn**.  
5. `pool.mint` same ticks, compound principal **+** compoundable fees (vault fee on fee portion when wired).  
6. Repo: center = imported ticks; wings uncreated.  
7. Sync reserves; mint shares to `recipient`.  
8. Steady state never needs NPM.

---

## 9. Preview = Execution (ship gate)

This is a **first-class Definition of Done requirement**, not a nice-to-have. Match project convention (Slipstream-grade; AGENTS.md DETF/SE preview discipline):

### 9.1 Quality bar

| Rule | Requirement |
|------|-------------|
| Source of truth | Crane production quoters / same math as execution — **no mock previews** |
| Direct swaps | `UniswapV3Quoter` against live pool state |
| Zaps | `UniswapV3ZapQuoter` and/or Slipstream-style zap preview structure on Uni V3 utils |
| Import | `previewImportPosition` uses **identical valuation path** as `importPosition` |
| Subsequent zap-in | Preview must model **fee-first compound** so quoted shares match post-compound mint |
| Exactness | Prefer **`assertEq(preview, executed)`** |
| Tolerance | Document ≤ few-wei **only** if Uni V3 multi-step rounding forces it; never “always under-quote” as the long-term bar |
| Forbidden | Conservative intentional under-quotes as permanent v1 strategy (early V4 bring-up anti-pattern) |

### 9.2 Required preview parity matrix

Every row must have a hermetic test that:

1. Calls `preview*`,  
2. Executes the matching mutate,  
3. Asserts output (and key side effects) match.

| ID | Preview | Execute | Notes |
|----|---------|---------|-------|
| P-IN-01 | `previewExchangeIn` token0→token1 | `exchangeIn` | Exact-in swap |
| P-IN-02 | `previewExchangeIn` token1→token0 | `exchangeIn` | Exact-in swap |
| P-IN-03 | `previewExchangeIn` token0→shares | `exchangeIn` | First-deposit zap |
| P-IN-04 | `previewExchangeIn` token1→shares | `exchangeIn` | First-deposit zap |
| P-IN-05 | `previewExchangeIn` token→shares | `exchangeIn` | **Subsequent** zap after fee accrual (fee-first) |
| P-OUT-01 | `previewExchangeOut` token0→token1 | `exchangeOut` | Exact-out |
| P-OUT-02 | `previewExchangeOut` token1→token0 | `exchangeOut` | Exact-out |
| P-OUT-03 | `previewExchangeOut` shares→token0 | `exchangeOut` | Zap-out |
| P-OUT-04 | `previewExchangeOut` shares→token1 | `exchangeOut` | Zap-out |
| P-IMP-01 | `previewImportPosition` | `importPosition` | Principal-only NFT |
| P-IMP-02 | `previewImportPosition` | `importPosition` | NFT with **tokensOwed / fees** (compound remint) |
| P-PRE-01 | previews | mutates | `pretransferred=true` paths where peers support them |

### 9.3 Implementation notes for parity

1. Views must not mutate pool state; use quoter simulation / pure math over current slot0.  
2. Share mint formula in preview must use the same total-value definition as execution (post phase-A for subsequent deposits).  
3. Import preview must read NPM `positions` + pool slot0; no optimistic free-mint.  
4. If parity fails: fix production quote path first; do not loosen asserts without PRD note.

---

## 10. Adversarial Testing (ship gate)

Adversarial coverage is **required for v1 security DoD**, not deferred “if time.” Follow `crane-adversarial-testing` + `indexedex-adversarial-testing`:

1. Real DFPkg / facets / manager / registry / fee oracle.  
2. Real Uni V3 pool (Crane hermetic port).  
3. No mocks of SUT.  
4. Allowed harnesses: mintable ERC20, **hostile reentrant ERC20** as pool token / inventory token, attacker EOAs.  
5. Pass = exploit blocked **or** intentional risk documented with hard invariants.

### 10.1 Threat model (actors × surfaces)

| Actor | Surfaces | Assets at risk |
|-------|----------|----------------|
| External attacker | `exchangeIn/Out`, import, transfers into vault | token0/token1, shares, unpaid fees |
| Malicious token | `transfer` / `transferFrom` reentry during pull/pay/refund | Nested route / double mint |
| Spoofed callback | Direct call to mint/swap callbacks | Drain vault balances |
| NFT thief / unapproved importer | `importPosition` without ERC-721 authority | Wrong NFT / unauthorized migrate |
| Incumbent vs new depositor | Fee timing / donation before zap | Share inflation / dilution |
| Disabled vault | Routes after registry disable | Ops when product should halt |

### 10.2 Attack catalog (SE × Uni V3)

Map to Crane catalog letters. Test names: `test_<ID>_<behavior>()`.

| ID | Theme | Attack | Pass criteria |
|----|-------|--------|---------------|
| **A1** | Donation | Transfer token0/token1 to vault without mint | Next depositor does **not** receive free shares for donation as if it were their principal; incumbents retain claim on idle inventory per accounting rules (document exact Slipstream-aligned rule) |
| **A2** | Donation | Transfer vault shares to stranger | No privileged power; only share ownership transfer |
| **A3** | Fee donation timing | Accrue Uni fees, then attacker tiny zap | Fee-first compound credits incumbents; attacker only paid for own contribution |
| **B1** | Spot manip | Large pool skew via external LP swap → zap → reverse | No unbounded free lunch; document bounds if any temporary MEV; conservation holds |
| **C1** | Reentrancy | Hostile ERC20 reenters `exchangeIn` mid-pull | Nested call fails `IsLocked`; outer completes or clean reverts |
| **C2** | Reentrancy | Hostile reenters `exchangeOut` mid-payout | `IsLocked` |
| **C3** | Reentrancy | Hostile reenters `importPosition` | `IsLocked` |
| **C4** | Callback reentry | During authenticated callback, attempt reenter share mint/burn via token hooks if any | No nested success on share-mutating routes |
| **D1** | Callback spoof | EOA / non-pool calls `uniswapV3MintCallback` / `SwapCallback` | Revert; vault balances unchanged |
| **D2** | Import auth | Import without NFT approval / wrong owner | Revert via NPM/ERC-721; vault empty of that NFT |
| **D3** | Import wrong pool | NFT on different fee/pair | Revert `InvalidImportedPool` (or family name) |
| **D4** | Second import | Import after live | Revert |
| **E1** | Accounting | Round-trip zap-in then zap-out | Conservation within documented wei; residual free inventory policy holds |
| **E2** | Zero / deadline | Zero amount, expired deadline | Exact selectors; no state change |
| **E3** | Slippage | `minOut` / `maxIn` fail | Full atomic revert; no partial share mint |
| **E4** | Residual | Failed mutate after partial pull patterns | User funds not stranded mid-function; free inventory clean |
| **F1** | Disable | Registry/oracle disable vault | Mutating routes revert; views may still work per peers |
| **F2** | Factory spoof | Deploy vault with pool not from package factory | `initAccount` reverts |
| **H1** | Grief | Extreme `widthMultiplier` / tick edge geometry | Snap/clamp; no overflow panic; or documented revert |
| **H2** | Grief | Import zero liquidity NFT | Revert |
| **H3** | Grief | Leave empty NFT; ensure cannot be re-used as second import principal | Second import blocked; empty NFT ignored for valuation |

### 10.3 Priority

| Priority | IDs | Ship? |
|----------|-----|-------|
| **P0** | A3, C1–C3, D1–D4, E2–E4, F1–F2, H2 | **Yes** — required before “adversarially tested” claim |
| **P1** | A1, B1, C4, E1, H1, H3 | **Yes** — required for v1 DoD in this plan |
| **P2** | Full fork MEV reconstruction, multi-fee-tier fuzz matrix | May defer with NatSpec reason |

### 10.4 Adversarial file layout

```text
test/foundry/spec/protocol/dexes/uniswap/v3/
  ...happy path specs...
  adversarial/
    UNISWAP_V3_STANDARD_EXCHANGE_ADVERSARIAL_TEST_PLAN.md   # living checklist
    TestBase_UniswapV3StandardExchange_Adversarial.sol
    Adversarial_Donation.t.sol          # A*
    Adversarial_Reentrancy.t.sol        # C*
    Adversarial_CallbackAuth.t.sol      # D1
    Adversarial_Import.t.sol            # D2–D4, H2–H3
    Adversarial_Accounting.t.sol        # E*
    Adversarial_AccessDisable.t.sol     # F*
    Adversarial_PriceManipulation.t.sol # B1
    Adversarial_Griefing.t.sol          # H1
```

Optional: keep a short adversarial plan markdown next to suites (status P0/P1 checkboxes).

### 10.5 Harness notes

```solidity
// TestBase_UniswapV3StandardExchange_Adversarial extends TestBase_UniswapV3StandardExchange
// attacker, victim = makeAddr
// Hostile reentrant ERC20 as pool token0 or token1 when probing C*
// Real pool swaps for B1 (not mock price)
// _assertNoUnexpectedFreeInventory after success paths
// Assert nestedErrorSelector == IsLocked on reentry probes
```

**Production bugs:** if a P0/P1 exploit is profitable unbounded → **fix production first**; never greenwash.

---

## 11. Happy-Path And Integration Testing

### 11.1 Gold TestBase

`TestBase_UniswapV3StandardExchange`:

1. Inherit `IndexedexTest` → vault components → Uni V3 TestBase (+ periphery for NPM import).  
2. Deploy In/Out/Import facets via CREATE3 FactoryService.  
3. Deploy DFPkg via `indexedexManager` (`vm.prank(owner)`).  
4. Helpers: create/init pool, seed external LP, `deployVault(pool, widthMultiplier)`, fund users, route helpers.  
5. Import helpers: mint NPM NFT, approve vault, import, assert center-only.

### 11.2 Hermetic categories (required)

1. Facet `IFacet` metadata (In, Out, Import) — selectors include `previewImportPosition`.  
2. DFPkg deploy + init wiring (pool, factory check, widthMultiplier, strategy defaults).  
3. Direct exact-in / exact-out both directions.  
4. Zap-in / zap-out both tokens; first deposit creates center+wings; second adds same ticks.  
5. **Full preview = execution matrix (§9.2).**  
6. Deadline / slippage / unsupported route negatives.  
7. Fee accrual + fee-first non-dilution (A3-class also under adversarial).  
8. Callback auth (also adversarial D1).  
9. Disable path if peers implement it.  
10. Import suite: happy convert, fee compound remint, empty NFT retained, wrong pool, non-empty vault, zero liq, slippage, post-import center-only zap, post-import swaps, second import revert, preview parity.

### 11.3 Fork (Base mainnet) — v1 DoD

1. Liquid real Uni V3 pool (document address + fee tier + pin block).  
2. Exact-in + at least one zap smoke (`deal` / whale prank as peers).  
3. At least one import against real Base NPM if hermetic covers conversion deeply.  
4. No unreproducible UI dependency.

### 11.4 Suggested test files

```text
test/foundry/spec/protocol/dexes/uniswap/v3/
  UniswapV3StandardExchangeInFacet_IFacet_Test.t.sol
  UniswapV3StandardExchangeOutFacet_IFacet_Test.t.sol
  UniswapV3StandardExchangePositionImportFacet_IFacet_Test.t.sol
  UniswapV3StandardExchangeDFPkg_Deploy.t.sol
  UniswapV3StandardExchange_Routes.t.sol
  UniswapV3StandardExchange_Previews.t.sol      # §9 matrix
  UniswapV3StandardExchange_Import.t.sol
  UniswapV3StandardExchange_FeeCompound.t.sol   # two-phase non-dilution
  adversarial/                                  # §10

test/foundry/fork/base_main/protocol/dexes/uniswap/v3/
  UniswapV3StandardExchange_Fork.t.sol
```

### 11.5 Commands

```bash
# Scaffold / unit slice
forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v3/**' -vv

# Preview parity focus
forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Previews.t.sol' -vvv

# Adversarial
forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/**' -vv

# Fork (env RPC as project standard)
forge test --match-path 'test/foundry/fork/base_main/protocol/dexes/uniswap/v3/**' -vv

# Size check near limits
forge build --sizes
```

---

## 12. Implementation Phases

### Phase 0: PRD + plan lock

1. PRD accepted (done).  
2. This plan reviewed.  

**Exit:** no open product questions for v1.

### Phase 1: Scaffolding and state

1. Repos: PoolAware, FactoryAware, Vault/PositionRepo.  
2. Facet/target shells + Common (callback stubs).  
3. DFPkg + `Component_FactoryService`.  
4. Full `initAccount` + **mandatory factory check**.  
5. Manager typed deploy helper.  
6. `TestBase_UniswapV3StandardExchange` deploys via manager.  
7. Facet metadata tests + deploy/init tests + factory mismatch test.

**Exit:** vault deploys; storage reads pool + widthMultiplier; wrong factory reverts.

### Phase 2: Callbacks + direct swaps

1. Authenticated mint/swap callbacks.  
2. Exact-in / exact-out both directions.  
3. Quoter-backed previews for direct routes.  
4. Hermetic direct route tests + negatives (deadline, slippage, unsupported).  
5. Preview parity P-IN-01/02, P-OUT-01/02.  
6. Adversarial D1 (callback spoof) early.

**Exit:** direct routes green; callback spoof blocked; direct preview = execution.

### Phase 3: Zap routes + share accounting + wings

1. First-deposit tick derivation (center+wings).  
2. Zap-in / zap-out both assets.  
3. Fee collect + **two-phase compound-before-new-deposit** + vault fee on fee redeposit.  
4. Preview parity P-IN-03/04/05, P-OUT-03/04.  
5. Fee compound unit tests + dust refunds.  
6. Adversarial A3, E1–E4 as available.

**Exit:** full route matrix hermetic green; fee non-dilution green; zap preview = execution.

### Phase 4: Position import

1. Import facet/target: `previewImportPosition` + `importPosition`.  
2. NPM full exit; **leave empty NFT**; remint center with principal + compoundable fees.  
3. Hermetic import suite + P-IMP-01/02.  
4. Post-import organic subsequent path (center only).  
5. Adversarial D2–D4, H2–H3, C3.

**Exit:** import green; preview = execution; no runtime NPM dependency.

### Phase 5: Adversarial hardening (required)

1. Complete P0 + P1 catalog (§10.2–10.3).  
2. Living `UNISWAP_V3_STANDARD_EXCHANGE_ADVERSARIAL_TEST_PLAN.md` checkboxes.  
3. Deferred P2 IDs documented in suite NatSpec only if any remain.  
4. Fix any production issues found before greening tests.

**Exit:** `forge test --match-path '.../uniswap/v3/adversarial/**'` green; no open P0/P1 exploits.

### Phase 6: Fork + size + docs

1. Base mainnet fork smokes (direct + zap; import if practical).  
2. Pin pool address, fee tier, block in test comments.  
3. `forge build --sizes`; split facets if near limits.  
4. Update this plan Progress Snapshot.  
5. Note limitations (no rebalance, center-only after import, empty NFT retained).

**Exit:** v1 Definition of Done (§13) satisfied.

---

## 13. Definition of Done (v1)

1. All files in §3 implemented (FactoryAware required).  
2. Deploy path is CREATE3 + manager vault registry only — never `new` SUT facets/DFPkg.  
3. All routes in §7 work with deadline / slippage / pretransfer / disable semantics.  
4. Organic first deposit creates center+wings; ticks immutable thereafter.  
5. Import converts NPM → direct center; empty NFT left; wings uncreated; steady state direct pool only.  
6. Fee-first compound + non-dilution; vault fee on fee redeposit when wired.  
7. Callbacks authenticated.  
8. **Preview = execution** for full §9.2 matrix (exact preferred; documented wei only if justified).  
9. **Adversarial P0+P1** catalog green (§10).  
10. Production-first hermetic suite green.  
11. Base mainnet fork smoke: ≥ direct swap + one zap.  
12. No DETF/DualLiquidity consumer required.  
13. PRD D1–D18 not silently violated.

---

## 14. Risks And Mitigations

| Risk | Mitigation |
|------|------------|
| Stack-too-deep in zap/common | Struct params, externalized helpers, V4/Slipstream patterns; avoid `viaIR` unless project already requires |
| Callback reentrancy | Crane lock on external routes; minimal callback surface; adversarial C* + D1 |
| Fee / share dilution bugs | Two-phase A/B; P-IN-05 + A3 tests; no raw `balanceOf` donation as free mint credit |
| Import fee remint mismatch | Compound principal+fees; residual dust documented; P-IMP-02 |
| Quoter vs execution drift | Same pool state; §9 parity suite; no single-tick-only shortcuts for production previews |
| Tick geometry edges | Slipstream snap/clamp; H1 grief tests |
| Bytecode size | Split import facet; library extraction; size check in Phase 6 |
| Fork flakiness | Pin pool + block; no mempool dependence |
| Empty NFT confusion | Explicit tests that empty NFT is not runtime vehicle and cannot re-import |

---

## 15. Deferred (not v1 blockers)

1. Ethereum mainnet fork matrix.  
2. DETF Single-SE matrix row for Uni V3 SE.  
3. Active rebalance / wing rebuild after import.  
4. Permit2-signed import / gasless NFT transfer.  
5. In-query-only facet split.  
6. Protocol fee-tier whitelist beyond bound pool.  
7. Burning empty imported NPM NFTs (explicitly out — D15).  
8. Adversarial P2 items listed in §10.3.

---

## 16. Acceptance Checklist

Use during review / PR:

- [ ] PRD D1–D18 still matched by code  
- [ ] Manager registry deploy path only  
- [ ] Factory validation mandatory  
- [ ] Route matrix complete  
- [ ] Fee-first two-phase deposits  
- [ ] Import convert + leave empty NFT + previewImport  
- [ ] §9 preview = execution matrix all green  
- [ ] §10 adversarial P0+P1 all green (or production fixed)  
- [ ] Hermetic suite green  
- [ ] Base fork smoke green  
- [ ] Sizes acceptable  
- [ ] Plan Progress Snapshot updated  

---

## 17. Next Action

Begin **Phase 1** scaffolding under `contracts/protocols/dexes/uniswap/v3/`:

1. Repos + DFPkg + FactoryService + manager typed deploy.  
2. `TestBase_UniswapV3StandardExchange` production path.  
3. Facet metadata + init/factory validation tests.

Then Phase 2 (callbacks + direct swaps + early callback adversarial) before zap complexity.
