# PRD: Uniswap V3 Standard Exchange Vault

**Status:** LOCKED for v1 design (implementation not started)  
**Date:** 2026-07-28  
**Last clarified:** 2026-07-28 (fee compound / import auth / factory validation / previewImport / empty NFT / post-import organic subsequent deposits)  
**Package path:** `contracts/protocols/dexes/uniswap/v3/`  
**Primary behavioral template:** Slipstream Standard Exchange  
**Secondary layout reference:** Uniswap V4 Standard Exchange (package wiring, position import surface)

---

## 1. Goal

Implement an IndexedEx **Standard Exchange (SE)** vault package for **Uniswap V3** that provides the same user-facing shape as Slipstream / Uniswap V4 SE:

1. direct pool-side exact-in and exact-out swaps between the two pool tokens,
2. single-sided zap-in from a pool token to vault shares,
3. single-sided zap-out from vault shares to a pool token,
4. ERC-20 vault shares representing proportional ownership of managed concentrated-liquidity positions,
5. deterministic CREATE3 + vault-registry deployment through IndexedEx manager,
6. optional **first-deposit bootstrap** by importing a Uniswap V3 **NonfungiblePositionManager (NPM)** NFT and converting it into vault-owned pool liquidity.

The vault is **not** ERC-4626. It is a multi-asset SE diamond, same family as Slipstream and Uni V4 SE.

---

## 2. Non-Goals (v1)

Explicitly out of scope for this PRD’s shippable v1:

1. DETF / MultiVault / protocol-package consumers of the new DFPkg (wiring may be noted; not required to ship).
2. DualLiquidity Linked Cross-Version or other protocol products using this SE leg.
3. On-chain automated rebalancing / tick migration after first create or import.
4. Multi-hop swaps or routes involving tokens outside the bound pool pair.
5. Native ETH wrap/unwrap on vault routes (WETH is ERC-20 only).
6. Keeping an NPM NFT as the long-lived ownership vehicle after import (empty NFT may remain on the vault after conversion, but runtime liquidity is always direct pool).
7. Multiple simultaneous vault strategies beyond the fixed center + wings geometry.
8. Fee-tier creation / pool creation inside the vault (pool must already exist and be initialized).
9. ERC-4626 semantics or single-asset “asset()” modeling.

---

## 3. Why V3 Is Not a Copy of V4 (and Not a Copy of V2)

| Concern | Uniswap V2 SE | Slipstream SE | Uniswap V4 SE | **Uniswap V3 SE (this PRD)** |
|--------|---------------|---------------|---------------|------------------------------|
| Pool identity | Pair address | CL pool address | `PoolKey` + `PoolManager` | **V3 pool address** |
| Liquidity ownership | Pair LP ERC-20 | Direct pool positions | Direct PM positions (+ optional import NFT) | **Direct pool positions** |
| Position key | N/A (fungible LP) | `(owner, tickLower, tickUpper)` | `(owner, ticks, salt)` | **`(owner=vault, tickLower, tickUpper)`** |
| Execution | Router / pair | `pool.mint/burn/collect/swap` | `PoolManager.unlock` flash accounting | **`pool.mint/burn/collect/swap` + callbacks** |
| Callback surface | Pair swap callback patterns | CL-specific | `unlockCallback` | **`IUniswapV3MintCallback` + `IUniswapV3SwapCallback`** |
| Quotes | ConstProd math | `SlipstreamQuoter` | V4 quote helpers | **Crane `UniswapV3Quoter` / `UniswapV3ZapQuoter`** |

**Normative rule:** Prefer **Slipstream SE** for economics, wing strategy, route matrix, and share accounting. Prefer **V4 SE** only for diamond package layout, factory service pattern, manager deploy wiring, and the *existence* of a position-import facet (import *mechanics* differ—see §8).

---

## 4. Locked Product Decisions

| # | Decision | Value |
|---|----------|--------|
| D1 | Architecture template | **Slipstream SE** |
| D2 | Position ownership | **Direct pool** (`owner = address(this)` / vault diamond) |
| D3 | Liquidity strategy | **Center + lower wing + upper wing** |
| D4 | Deploy binding | `PkgArgs = (IUniswapV3Pool pool, uint24 widthMultiplier)` |
| D5 | ETH | **ERC-20 only**; WETH treated as ordinary ERC-20 |
| D6 | Fees | Collect into vault value; **compound into liquidity before crediting new depositors**; take vault usage fee on fee redeposit when fee oracle wiring applies (see §6.4) |
| D7 | Position import | **In scope**; convert NPM NFT → vault-owned pool positions |
| D8 | Import geometry | Imported range becomes **Center only**; wings uncreated until a future rebalance product |
| D9 | Import NPM address | Caller-supplied `INonfungiblePositionManager` (not a single hardcoded chain address) |
| D10 | Rebalance | **Non-goal** for v1; ticks fixed after first create or import |
| D11 | Ship scope | **Core SE package only** |
| D12 | Testing | **Hermetic Crane V3 port + Base mainnet fork** required for v1 DoD |
| D13 | Preview quality | **Slipstream-grade** view quotes; target preview ≈ execution on supported routes (including **import preview**) |
| D14 | `PkgInit` factory | Store `IUniswapV3Factory` in package init; **`require(pool.factory() == uniswapV3Factory)` at init is mandatory**; **NPM not required in PkgInit** |
| D15 | Empty NPM after import | **Leave** the empty NFT on the vault after full `decreaseLiquidity` + `collect`; **do not burn**. Steady-state liquidity is still **direct pool** only; the empty NFT is inert and not used as the position vehicle |
| D16 | Import authorization | **No vault-side operator/owner policy beyond Uni V3/NPM.** If the vault can pull the NFT and withdraw liquidity (transfer/approval semantics enforced by NPM + ERC-721), import proceeds. Rely on Uniswap V3 / NPM security for authorization |
| D17 | Import preview | **`previewImportPosition` is required** on the import surface (view; same valuation path as mutate) |
| D18 | Post-import deposits | Use the **same organic subsequent-deposit path** as non-import vaults: add liquidity only to **already created** positions (no re-centering, no wing create in v1). After import that is center-only, so post-import zaps add to **center** only |

These rows are **LOCKED**. Changing them requires an explicit PRD revision, not silent implementation drift.

---

## 5. User-Facing Surface

### 5.1 Interfaces

Expose at minimum:

1. `IERC20` / `IERC20Metadata` / `IERC20Permit` / `IERC5267`
2. `IStandardVault` (multi-asset standard vault surface used by peers)
3. `IStandardExchangeIn`
4. `IStandardExchangeOut`
5. `IUniswapV3StandardExchangePositionImport` (new; name may match V4 import naming style) — includes **mutate + preview**
6. Uni V3 callback interfaces as required for pool interactions (see §7)

### 5.2 Route Matrix

Same intentional matrix as Slipstream / V4 SE.

**Exact-in (`exchangeIn` / `previewExchangeIn`)**

| tokenIn | tokenOut | Behavior |
|---------|----------|----------|
| token0 | token1 | Direct pool swap exact-in |
| token1 | token0 | Direct pool swap exact-in |
| token0 | vault shares | Single-sided zap-in |
| token1 | vault shares | Single-sided zap-in |

**Exact-out (`exchangeOut` / `previewExchangeOut`)**

| tokenIn | tokenOut | Behavior |
|---------|----------|----------|
| token0 | token1 | Direct pool swap exact-out |
| token1 | token0 | Direct pool swap exact-out |
| vault shares | token0 | Single-sided zap-out |
| vault shares | token1 | Single-sided zap-out |

**Unsupported (must revert)**

1. vault shares → vault shares  
2. same-asset no-ops  
3. any token not equal to token0, token1, or the vault share token  
4. multi-hop / external intermediate tokens  

Prefer family-consistent errors (`ExchangeInNotAvailable` / `ExchangeOutNotAvailable` or package-local `UnsupportedRoute`—match Slipstream’s existing SE error style unless a repo-wide SE error enum is already standardized for new packages).

### 5.3 Route Rules

1. **Single-sided zap-in never pulls a second token from the user.** Internal cleanup swap may rebalance inventory inside the vault before mint.
2. **Zap-out final transfer is measured after any cleanup swap**, not before.
3. Support `pretransferred` boolean semantics consistent with peer SE packages.
4. Enforce `deadline` and slippage (`minAmountOut` / `maxAmountIn`) on all mutating routes.
5. Respect vault-disable checks via fee oracle / registry disable query if peers do (mirror V4/Slipstream `_requireNotDisabled` pattern if present on SE peers at implementation time).

---

## 6. Core Design

### 6.1 Multi-Asset Vault Facets (Not ERC-4626)

Facet mix for the DFPkg (order flexible; set must be complete):

1. `ERC20Facet`
2. `ERC5267Facet`
3. `ERC2612Facet`
4. `MultiAssetBasicVaultFacet`
5. `MultiAssetStandardVaultFacet`
6. `UniswapV3StandardExchangeInFacet`
7. `UniswapV3StandardExchangeOutFacet`
8. `UniswapV3StandardExchangePositionImportFacet`

Optional later (not required for v1 DoD unless needed for bytecode/stack): split query facet for views only (V4 has `InQueryFacet`—**optional**, not mandated).

### 6.2 Stored Identity

Per vault instance:

| State | Source |
|-------|--------|
| Bound `IUniswapV3Pool` | `PkgArgs.pool` |
| `widthMultiplier` | `PkgArgs.widthMultiplier` (≥ 1) |
| Strategy defaults | Mirror Slipstream: `centerWidthMultiplier = 2`, `activeLiquidityBps = 1000` unless peer constants differ—**copy SlipstreamVaultRepo defaults** |
| Center / lower wing / upper wing ticks + liquidity + `created` | Position/vault repo |
| Optional last sqrtPrice / tick / timestamp cache | For invalidation / accounting helpers if useful |
| Fee oracle, permit2, registry, manager wiring | Standard vault repos (peer pattern) |

**Do not** store only token0/token1/fee without pool address. The pool address is canonical. Fee and tickSpacing are read from the pool.

**Required:** `IUniswapV3Factory` in package init / factory aware repo; **`require(pool.factory() == factory)` at init (D14).**

### 6.3 Liquidity Strategy (Center + Wings)

On **first organic deposit** (zap-in with no positions created yet):

1. Read `slot0` current tick and `tickSpacing` from the bound pool.
2. Derive managed ticks exactly as Slipstream does:

   - outer half-width ≈ `widthMultiplier * tickSpacing / 2`
   - center half-width ≈ `centerWidthMultiplier * tickSpacing / 2` (min one spacing)
   - snap to tickSpacing multiples; clamp to `TickMath` bounds
   - lower wing: `[outerLower, centerLower]`, upper wing: `[centerUpper, outerUpper]`

3. Persist three position records (center / lower / upper).
4. Allocate budgets with `activeLiquidityBps` (center gets bps of available amounts; wings get remainder single-sided as Slipstream).
5. Mint liquidity via `pool.mint` with `recipient = address(this)`.

On **subsequent deposits**: add liquidity into the **existing** ticks only (no re-centering).

**Import path exception:** see §8—import creates **Center only** at the NFT’s ticks; wings remain uncreated/`liquidity = 0`.

### 6.4 Share Accounting

Mirror Slipstream economic model, with an explicit **non-dilution / fee-first** ordering for new deposits:

**Mint**

1. If `totalSupply == 0`, mint shares from actual principal value contributed using the same initial share convention as Slipstream (normalized multi-asset initial mint). First-deposit (including import bootstrap) has no prior incumbents.
2. Otherwise mint proportional to **new depositor contribution only** vs **total vault value after fee compounding (and any vault fee on that redeposit), before applying the new deposit**.
3. Total vault value includes:
   - amounts for all managed liquidities at current sqrt price,
   - collectable tokens owed (fees) on those positions (until compounded),
   - free token0/token1 balances held by the vault that are part of working inventory (define consistently with Slipstream; do not double-count).

**Burn**

1. Shares entitle proportional liquidity / value.
2. Burn liquidity, collect, optional cleanup swap to one-sided out.
3. Burn shares only after actual entitlement is known.
4. Refund dust remainder tokens to `msg.sender` when peers do.

**Fee rule (LOCKED) — compound fees; new depositors only get credit for their contribution:**

On any liquidity-increasing path that admits prior positions / accrued fees (subsequent zap-in, and import remint when tokens owed / free fee inventory exist):

1. **Collect** position fees (and treat any free fee inventory consistently).
2. **Redeposit / compound** those fees into managed liquidity (prefer full compound when both sides allow; residual dust may remain free inventory if a side cannot be minted).
3. **Take vault usage fee** on that fee redeposit when peer SE / fee-oracle usage-fee wiring applies (feeTo / protocol cut from the compounded value, not from the new user’s principal).
4. **Then** process the new deposit (or finalize import share mint) so the new depositor’s shares reflect **only their contribution** against post-compound vault value.

A **two-phase** implementation (phase A: fee collect + compound + vault fee; phase B: new principal deposit / import share mint) is **explicitly acceptable** and preferred when it keeps accounting clearer—even if a single external call wraps both phases.

Do **not** leave fee inventory stranded as unaccounted free balances across successful routes in a way that dilutes or enriches the next depositor incorrectly.

### 6.5 Preview Strategy (LOCKED quality bar)

Use Crane production math, not mocks:

1. Direct swaps: `UniswapV3Quoter.quoteExactInput` / `quoteExactOutput` against the live pool state.
2. Zaps: `UniswapV3ZapQuoter` (and/or port of Slipstream zap preview structure using Uni V3 utils).
3. Tests must assert **preview ≈ execution** on hermetic routes (exact preferred; document ≤ few-wei only if unavoidable and justified).

Conservative “always under-quote” previews are **not** acceptable as the long-term v1 bar (unlike early V4 bring-up).

---

## 7. Uniswap V3 Execution Model

### 7.1 Direct Pool Calls

Runtime execution **must** call the bound `IUniswapV3Pool` directly for:

1. `swap(...)` — direct exchange routes and zap cleanup swaps  
2. `mint(...)` — add liquidity  
3. `burn(...)` — remove liquidity  
4. `collect(...)` — fees + burn proceeds  

Do **not** route core vault ops through NPM at steady state.

NPM is used **only** during position import conversion (§8).

### 7.2 Callbacks (mandatory design item)

Uniswap V3 pools invoke callbacks on `msg.sender`:

1. `uniswapV3MintCallback(int256 amount0Owed, int256 amount1Owed, bytes data)`
2. `uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes data)`

**Requirements:**

1. The diamond proxy must expose these selectors (facet or shared common target wired into the diamond).
2. Callbacks **must authenticate** the caller is the bound pool (and, if data encodes expected pool, verify).
3. Callbacks transfer owed tokens from vault balances to the pool (mint) / settle swap deltas.
4. Reentrancy: SE routes already use `nonReentrant` / Crane reentrancy lock; callbacks must not open unguarded external reentry into share mint/burn beyond the active op. Follow Crane `IsLocked` / peer SE patterns.
5. Do not implement flash-loan receiver features beyond what swaps/mints need.

**Implementation note:** Because the pool calls the vault diamond, facet cut must include callback selectors. Prefer placing callbacks on `UniswapV3StandardExchangeCommon` (inherited by in/out targets) or a dedicated small callback facet if selector packaging requires it.

### 7.3 Position Keys

Vault-owned positions use Uni V3 key:

```text
keccak256(abi.encodePacked(address(this), tickLower, tickUpper))
```

Repo helpers should compute own position keys per `PositionKind` the same way `SlipstreamVaultRepo._getOwnPositionKey` does for CL.

There is **no salt** (unlike V4). Two vaults can share a pool; each owns distinct positions because `owner` differs.

---

## 8. Position Import (v1 In Scope)

### 8.1 Intent

Allow a user (or integrator) to bootstrap a **new empty vault** by contributing an existing Uni V3 NPM position NFT that sits on the **same pool** the vault is bound to, receiving vault shares, after which the vault owns **direct pool liquidity** only.

### 8.2 Preconditions

Import **must revert** unless all hold:

1. `totalSupply() == 0`
2. No managed position `created` yet (center/wings all empty)
3. `deadline` valid (mutate only)
4. Vault can obtain the NFT and withdraw its liquidity under **Uniswap V3 / NPM / ERC-721 rules** (typically `transferFrom` into the vault, then NPM ops as owner). **No additional IndexedEx-only owner/operator gate** beyond what is required for the vault to successfully pull and decrease the position
5. NFT’s pool matches bound vault pool (`token0`, `token1`, `fee` / pool address resolution via NPM `positions` + factory)
6. NFT liquidity `> 0`
7. `sharesOut >= minSharesOut` (mutate only)

If pull/decrease fails because the caller/vault is not authorized under Uni V3 security, the tx reverts—that is the authorization model (D16).

### 8.3 Conversion Flow (LOCKED — convert to direct pool ownership)

Atomic external call; internal two-phase accounting is fine:

1. Validate preconditions; compute expected `sharesOut` with the same path as `previewImportPosition` (principal liquidity value at current sqrt price **plus** collectable tokens owed / fees, compounded per §6.4 where applicable).
2. Pull the NFT into the vault (`transferFrom` / equivalent) so the vault can withdraw under NPM.
3. NPM `decreaseLiquidity` for **full** liquidity + `collect` **all** token0/token1 to the vault.
4. **Leave the empty NFT** on the vault — **do not burn** (D15). The NFT is inert for runtime routes; do not use it as the long-lived position vehicle.
5. **Compound on remint (LOCKED):** `pool.mint` at the **same** `tickLower`/`tickUpper` with `recipient = address(this)`, reminting liquidity from **principal + fees** where safely compoundable (prefer maximize reminted liquidity from collected balances; residual one-sided dust may remain free inventory). Apply vault usage fee on the fee portion of that redeposit when fee-oracle wiring applies (two-phase A then B is acceptable).
6. Initialize position repo: **Center** = imported ticks; lower/upper wings **not created**.
7. Sync multi-asset vault reserves; mint shares to `recipient` for the **imported contribution** only (first depositor / empty supply case).
8. Steady-state zap/swap/burn paths use **direct pool positions only** — never require NPM after import.

**Reject:** leaving the NFT as the runtime position manager (V4-style long-lived import) for V3 v1. Empty NFT retention is **not** runtime position management.

### 8.4 Import Interface Sketch

```solidity
interface IUniswapV3StandardExchangePositionImport {
    /// @notice View quote for importPosition; same valuation path as the mutate.
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

Exact NatSpec / error names should mirror V4 import surface where practical for frontend reuse. **`previewImportPosition` is required for v1** (D17); tests must assert preview ≈ execution on hermetic import (same quality bar as other routes).

### 8.5 Post-Import Behavior

1. **Organic subsequent-deposit path (D18):** Post-import zap-ins use the **same** subsequent-deposit code path as organic vaults — add liquidity only to **already created** positions; no re-centering; **no wing creation** in v1. Because import initializes **center only**, post-import adds go to **center** only. Wings stay uncreated until a future rebalance product.
2. Organic (non-import) first deposit on an empty vault still creates full **center + wings**.
3. Direct swaps work regardless of wing presence.
4. Second import always reverts (supply or positions already non-empty).
5. Empty NPM NFT may remain on the vault forever; ignore it for valuation except dust-free zero liquidity / zero tokensOwed.

---

## 9. Package / Deployment

### 9.1 Interface Rules (Crane)

1. `PkgInit` and `PkgArgs` live on **`IUniswapV3StandardExchangeDFPkg`**, not on the contract body only.
2. Never `new` facets or DFPkg in production/tests for SUT—use CREATE3 + FactoryService + manager registry.

### 9.2 Structs

```solidity
struct PkgInit {
    IFacet erc20Facet;
    IFacet erc5267Facet;
    IFacet erc2612Facet;
    IFacet multiAssetBasicVaultFacet;
    IFacet multiAssetStandardVaultFacet;
    IFacet uniswapV3StandardExchangeInFacet;
    IFacet uniswapV3StandardExchangeOutFacet;
    IFacet uniswapV3StandardExchangePositionImportFacet;
    IVaultFeeOracleQuery vaultFeeOracleQuery;
    IVaultRegistryDeployment vaultRegistryDeployment;
    IPermit2 permit2;
    IUniswapV3Factory uniswapV3Factory; // mandatory pool.factory() validation + discovery
}

struct PkgArgs {
    IUniswapV3Pool pool;
    uint24 widthMultiplier;
}
```

```solidity
function deployVault(IUniswapV3Pool pool, uint24 widthMultiplier) external returns (address vault);
```

### 9.3 `initAccount` Requirements

Must fully initialize (no empty Slipstream-era placeholder):

1. Readable ERC-20 name/symbol derived from pool tokens + fee (peer style).
2. `ERC20Repo`, `EIP712Repo`
3. `StandardVaultRepo` / multi-asset basic vault repos as peers
4. `VaultFeeOracleQueryAwareRepo`
5. `Permit2AwareRepo`
6. Pool aware repo (`IUniswapV3Pool`)
7. **Mandatory factory validation (D14):** `require(pool.factory() == uniswapV3Factory)` so the caller-supplied pool is proven to have been deployed by the package’s Uniswap V3 factory
8. Position/strategy repo with `widthMultiplier`
9. Register tokens token0/token1 as vault underlying assets
10. Approve pool (and NPM only if import needs transient allowance patterns) carefully—prefer exact callback pulls from vault balance without infinite pool allowances if avoidable; follow Slipstream allowance practice where it already works.

### 9.4 Factory Service + Manager Wiring

Add:

1. `UniswapV3_Component_FactoryService.sol` — deploy facets via `create3Factory`, deploy DFPkg via `indexedexManager.deployPkg` / typed helper.
2. Manager / registry typed deploy methods consistent with `deploySlipstream…` / `deployUniswapV4…` peers.
3. Vault type registration / fee type ids: USAGE fee on `IStandardVault` interface id (peer pattern).

### 9.5 Proposed Files

```text
contracts/protocols/dexes/uniswap/v3/
├── UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PRD.md          # this file
├── UniswapV3PoolAwareRepo.sol
├── UniswapV3FactoryAwareRepo.sol                      # required (mandatory factory check)
├── UniswapV3VaultRepo.sol                             # center/wings/strategy (or *PositionRepo)
├── UniswapV3StandardExchangeCommon.sol
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

1. IndexedEx manager deployment surface (typed `deployUniswapV3StandardExchangeDFPkg`)
2. Vault component factory registrations if centralized
3. Spec tests under `test/foundry/spec/protocol/dexes/uniswap/v3/`
4. Fork tests under `test/foundry/fork/.../uniswap/v3/`

Reuse Crane:

1. `lib/crane/.../uniswap/v3/*` pool/factory/periphery
2. `UniswapV3Quoter`, `UniswapV3ZapQuoter`, `UniswapV3Utils`
3. `TestBase_UniswapV3`, `TestBase_UniswapV3Periphery` for hermetic bring-up

---

## 10. Route Workflows (Normative)

### A. Exact-in direct swap token0 → token1

1. Preview via `UniswapV3Quoter`.
2. Pull or validate pretransfer of token0.
3. `pool.swap` exact-in; pay in `uniswapV3SwapCallback`.
4. Transfer token1 to recipient; enforce `minAmountOut`.

### B. Exact-out direct swap

1. Preview input via quoter.
2. Enforce `maxAmountIn`; pull funds.
3. `pool.swap` exact-out; settle callback.
4. Refund excess input if any; transfer exact out.

### C. Zap-in token → shares

1. Preview shares via zap quoter / reserve math (preview must model fee-first compounding when positions already exist).
2. Pull single token.
3. If no positions: derive center+wings ticks and create records (organic first deposit).
4. If positions exist: **phase A** — collect fees, compound into existing positions, take vault fee on fee redeposit when applicable; **phase B** — process new principal (§6.4).
5. Internal swap to target inventory mix for plan as needed.
6. Mint liquidity to **existing created** positions per plan (post-import: center only; organic first deposit: center+wings).
7. Mint shares from **new principal only** vs post-compound total value.
8. Refund dust.

### D. Zap-out shares → token

1. Preview.
2. Burn proportional liquidity across existing positions; collect.
3. Cleanup swap to requested single token.
4. Burn shares; transfer out; enforce min out.

### E. Import NPM position

1. `previewImportPosition` for view quote.
2. Mutate per §8.3 (compound fees into remint; leave empty NFT; mint shares).

---

## 11. Testing Plan

### 11.1 Philosophy

Follow `indexedex-testing` + `crane-testing` production-first rules:

1. Real DFPkg, facets, manager, registry, fee oracle.
2. Real Uni V3 pool from Crane port (hermetic) or live Base pool (fork).
3. No mocks of SUT vault/manager/registry/facets.
4. Mintable ERC-20 harness tokens OK for hermetic funding.
5. Protocol ports under Crane are **not** mocks.

### 11.2 Gold TestBase

`TestBase_UniswapV3StandardExchange` should:

1. Inherit `IndexedexTest` → vault components → Uni V3 TestBase (and periphery when NPM import tests need it).
2. Deploy In/Out/Import facets via CREATE3 factory service.
3. Deploy DFPkg via `indexedexManager` (owner prank).
4. Helpers: create/initialize pool, seed external LP, deploy vault(`pool`, `widthMultiplier`), fund users, run routes.
5. For import tests: deploy NPM (periphery TestBase), mint external NFT, import into empty vault.

### 11.3 Hermetic Spec Categories (required)

1. Facet metadata (`IFacet` name/interfaces/selectors) for In, Out, Import.
2. DFPkg deploy + `initAccount` wiring (pool, widthMultiplier, tokens, strategy defaults).
3. Direct exact-in both directions.
4. Direct exact-out both directions.
5. Zap-in both tokens (first deposit creates center+wings; second deposit adds to same ticks).
6. Zap-out both tokens.
7. Preview == execution (or documented wei tolerance) for supported routes, including **`previewImportPosition` vs `importPosition`**.
8. Deadline / slippage failures.
9. Unsupported route reverts.
10. Fee accrual + **fee-first compound**: subsequent depositor shares reflect **only new contribution** (incumbents not diluted by unpaid fees; vault fee on fee redeposit when wired).
11. Callback auth: non-pool caller reverts.
12. Disable path if peer SE implements registry disable.
13. **Factory validation:** deploy with wrong `pool.factory()` reverts at init.
14. **Import:** happy path convert with fee compound remint; empty NFT left on vault (not burned); unauthorized pull reverts via NPM/ERC-721; wrong pool reverts; non-empty vault reverts; zero liquidity reverts; shares slippage; `previewImportPosition` parity; post-import zap follows organic subsequent path (center only); post-import direct swaps still work; second import reverts.

### 11.4 Fork Spec Categories (required for v1 DoD)

Primary chain: **Base mainnet**.

1. Deploy vault against a liquid real Uni V3 pool (document pool address in test).
2. Exact-in / zap-in smoke with forked balances (`deal` / whale prank as peers do).
3. At least one import path against a real NPM deployment address on Base if hermetic already covers conversion deeply—fork proves ABI/address assumptions.
4. No dependency on unreproducible UI flows.

Optional later: Ethereum mainnet fork (not required for v1 DoD).

### 11.5 Suggested Test Files

```text
test/foundry/spec/protocol/dexes/uniswap/v3/
  UniswapV3StandardExchangeInFacet_IFacet_Test.t.sol
  UniswapV3StandardExchangeOutFacet_IFacet_Test.t.sol
  UniswapV3StandardExchangePositionImportFacet_IFacet_Test.t.sol
  UniswapV3StandardExchangeDFPkg_Deploy.t.sol
  UniswapV3StandardExchange_Routes.t.sol
  UniswapV3StandardExchange_Previews.t.sol
  UniswapV3StandardExchange_Import.t.sol

test/foundry/fork/base_main/protocol/dexes/uniswap/v3/
  UniswapV3StandardExchange_Fork.t.sol
```

### 11.6 Adversarial (recommended follow-on; not blocking core PRD if time-boxed)

After happy paths: reentrancy via hostile ERC-20 as vault inventory token where applicable; donation of tokens to vault; callback spoofing. Use `indexedex-adversarial-testing` patterns.

---

## 12. Implementation Phases

### Phase 0: PRD lock

1. This document reviewed/accepted.
2. No code required.

**Exit:** design decisions frozen (status → Accepted).

### Phase 1: Scaffolding and state

1. Create directory + repos (`PoolAware`, **required** `FactoryAware`, `VaultRepo`/`PositionRepo`).
2. Facet/target shells, DFPkg, `Component_FactoryService`.
3. Full `initAccount` wiring including **mandatory** `pool.factory() == uniswapV3Factory`.
4. Manager typed deploy helper.
5. `TestBase_UniswapV3StandardExchange` deploys package through manager.

**Exit:** vault deploys; storage reads back pool + widthMultiplier; factory mismatch reverts; facet metadata tests pass.

### Phase 2: Callbacks + direct swaps

1. Implement mint/swap callbacks with pool auth.
2. Exact-in and exact-out both directions.
3. Quoter-backed previews for direct routes.
4. Hermetic direct route tests + negative tests.

**Exit:** direct routes green; callback spoof test green.

### Phase 3: Zap routes + share accounting + wings

1. First-deposit tick derivation (center+wings).
2. Zap-in / zap-out both assets.
3. Fee collect + **two-phase** compound-before-new-deposit + vault fee on fee redeposit when applicable.
4. Preview parity for zaps (including fee-first subsequent deposit cases).
5. Dust refund behavior matching Slipstream.

**Exit:** full route matrix green hermetically; preview parity holds; non-dilution tests green.

### Phase 4: Position import

1. Import facet/target with **`previewImportPosition` + `importPosition`**.
2. NPM full exit; **leave empty NFT**; remint center with **principal + compoundable fees**.
3. Hermetic import suite (auth via NPM, preview parity, post-import organic subsequent deposits).
4. Ensure steady-state paths never require NPM after import (empty NFT inert).

**Exit:** import suite green; post-import routes green.

### Phase 5: Fork hardening + docs

1. Base mainnet fork smoke tests.
2. Document pool addresses, fee tiers exercised, limitations.
3. Size check (`forge build --sizes`) if near limits; split facets if needed.

**Exit:** v1 Definition of Done (§13) satisfied.

---

## 13. Definition of Done (v1)

1. All files in §9.5 implemented (**FactoryAware** included; mandatory factory check at init).
2. Deploy path is CREATE3 + manager vault registry only.
3. All routes in §5.2 work with deadline/slippage/pretransfer semantics.
4. Center+wings strategy works for organic first deposit; ticks immutable thereafter; post-import uses organic subsequent path (center only).
5. Import converts NPM → direct center position; **empty NFT left on vault**; wings uncreated; no runtime NPM dependency.
6. Fee-first compound + non-dilution of incumbents; vault fee on fee redeposit when wired.
7. Callbacks authenticated; production-first hermetic tests pass.
8. Preview ≈ execution for supported hermetic routes **including `previewImportPosition`**.
9. Base mainnet fork smoke tests pass for at least direct swap + one zap path.
10. No DETF/DualLiquidity consumer required.
11. This PRD’s locked decisions (D1–D18) are not silently violated.

---

## 14. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Stack-too-deep in zap/common | Follow V4/Slipstream struct-parameter and externalized helper patterns; avoid `viaIR` unless project already requires it |
| Callback reentrancy | Crane reentrancy lock on external routes; minimal callback surface |
| Import / deposit fee accounting mismatch | Two-phase fee compound then new principal; remint principal+compoundable fees; tests for non-dilution + preview parity; document residual one-sided dust |
| Quoter vs execution drift | Use same pool state; assert parity in tests; avoid single-tick-only utils for production previews |
| Fee tier / tickSpacing edge geometry | Snap/clamp helpers copied from Slipstream; fuzz widthMultiplier later |
| Bytecode size | Split import facet; keep common logic in internal library if needed |
| Fork flakiness | Pin pool + block number; avoid depending on ephemeral mempool state |

---

## 15. Open Items Explicitly Deferred (not blockers)

1. Ethereum mainnet fork matrix.
2. DETF Single-SE matrix row for Uni V3 SE.
3. Active rebalance / wing rebuild after import (including creating wings post-import).
4. Permit2-signed import / gasless NFT transfer helpers.
5. In-query-only facet split for gas/size.
6. Protocol fee tier whitelist beyond whatever the bound pool already is.
7. Burning empty imported NPM NFTs (explicitly **not** v1 — leave empty NFT per D15).

---

## 16. References

### IndexedEx peers

- `contracts/protocols/dexes/aerodrome/slipstream/*` — primary behavioral template  
- `contracts/vaults/slipstream/SlipstreamVaultRepo.sol` — position/strategy storage model  
- `contracts/protocols/dexes/uniswap/v4/*` — package layout, factory service, import *surface*  
- `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_VAULT_PLAN.md` — plan structure peer  
- `contracts/protocols/dexes/uniswap/v2/*` — simpler SE deploy patterns (not CL economics)

### Crane

- `lib/crane/contracts/protocols/dexes/uniswap/v3/` — core + periphery port  
- `lib/crane/contracts/utils/math/UniswapV3Quoter.sol`  
- `lib/crane/contracts/utils/math/UniswapV3ZapQuoter.sol`  
- `lib/crane/contracts/utils/math/UniswapV3Utils.sol`  
- `lib/crane/contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3.sol`  
- `lib/crane/contracts/protocols/dexes/uniswap/v3/periphery/test/bases/TestBase_UniswapV3Periphery.sol`

### Skills (implementation)

- `crane-deployment`, `crane-architecture`, `crane-testing`, `crane-uniswap`  
- `indexedex-testing`, `indexedex-adversarial-testing`  
- Uniswap V3 skill family (`uniswap-v3-architecture`, `…-pool`, `…-swaps`, `…-positions`, `…-position-manager`, `…-ticks`)  
- Slipstream skill family for CL vault economics  

### Project rules

- `Agents.md` — CREATE3, registry DFPkg path, production-first tests, no `new` SUT deploys  

---

## 17. Acceptance Sign-Off

| Role | Outcome |
|------|---------|
| Product / protocol owner | Locked decisions D1–D18 accepted (incl. 2026-07-28 clarifications) |
| Implementation | Phases 1–5 complete per DoD |
| Review | No silent drift from Slipstream economics, fee-first non-dilution, or direct-pool ownership |

**Implementation plan:** [`UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PLAN.md`](./UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PLAN.md)  

**Next action after acceptance:** begin Phase 1 scaffolding under `contracts/protocols/dexes/uniswap/v3/` per the plan (incl. preview=execution + adversarial ship gates).

---

## 18. Clarification log (2026-07-28)

| Topic | Decision |
|-------|----------|
| Fee compound on remint / deposit | **Compound fees into liquidity** before crediting new depositors; two-phase (fee redeposit + vault fee, then new deposit) is acceptable and preferred when clearer |
| Empty NPM after import | **Leave** empty NFT on vault; do **not** burn |
| Factory check | **Mandatory** `pool.factory() == uniswapV3Factory` at vault init |
| Import auth | Rely on **Uniswap V3 / NPM / ERC-721**; if vault can withdraw the NFT position, import it |
| Import preview | Add **`previewImportPosition`** |
| Post-import deposits | **Organic subsequent-deposit process** (add only to existing created positions; center-only after import) |
