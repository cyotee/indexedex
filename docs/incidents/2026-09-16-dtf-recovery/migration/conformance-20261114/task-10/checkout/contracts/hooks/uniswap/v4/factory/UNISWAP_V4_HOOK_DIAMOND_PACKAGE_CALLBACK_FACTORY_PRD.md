# PRD: Uniswap V4 Hook Diamond Package Callback Factory

**Name:** `UniswapV4HookDiamondPackageCallBackFactory`  
**Date:** 2026-08-04  
**Status:** **Draft v1.1 — product law locked; ready for implementation plan**  
**Package path:** `contracts/hooks/uniswap/v4/factory/`  
**Package kind:** IndexedEx **ecosystem singleton factory** — deploys **immutable Diamond proxies** at **CREATE2-mined addresses** suitable for Uniswap V4 hook permission flags. **Parallel** to Crane `DiamondPackageCallBackFactory` (does **not** replace it). **Not** a vault share product; **not** the vault-registry DFPkg path for the factory itself.

**Primary consumers (v1):**

| Consumer | Role |
|----------|------|
| **Single SE Buffer CP Hook** | First production package; **hard-blocks** on this factory DoD (hook product waits) |
| Future IndexedEx V4 hooks | Only packages conforming to `IUniswapV4HookDiamondPackage` |
| Existing monomorph hooks | **Out of scope** — separate refactor effort later |

**Related:**

- Peer factory (unchanged): `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol`
- Proxy: `lib/crane/contracts/proxies/MinimalDiamondCallBackProxy.sol`
- Package base interface: `lib/crane/contracts/factories/diamondPkg/IDiamondFactoryPackage.sol`
- Hook flag mining peer: `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol` (CREATE3 monomorph; this factory is **CREATE2**)
- V4 Hooks library: `Hooks.ALL_HOOK_MASK` / permission flags
- First product PRD: co-located with Single SE Buffer CP Hook package when authored (hook product **blocks** on this factory DoD)
- Vault registry: **in this DoD** — extend Vault Registry **deployment interface** so it can call this factory and register liquidity-holding V4 hooks as vaults

**Authority:**

| Layer | Role |
|-------|------|
| **This PRD** | Product law for the factory + package extension interface + registry deploy-path extension |
| Implementation plan (follow-on, separate agent) | Phases, exact file map, registry function names, tests |
| Single SE CP hook plan | Consumer; blocks on factory green |

---

## 0. Terminology

| Term | Meaning |
|------|---------|
| **Vault diamond factory** | Existing `DiamondPackageCallBackFactory` — CREATE2 proxy; salt **includes package address** |
| **This factory / Hook diamond factory** | `UniswapV4HookDiamondPackageCallBackFactory` — CREATE2 proxy; salt **excludes package address**; mines **V4 permission flags** |
| **Package** | `IUniswapV4HookDiamondPackage` (extends `IDiamondFactoryPackage`) |
| **Package salt** | `pkg.calcSalt(pkgArgs)` — package-defined contribution (binding / PkgArgs policy) |
| **Final salt** | Factory-composed CREATE2 salt used with `PROXY_INIT_HASH` (includes mineNonce; **not** package address) |
| **Hook proxy / instance** | `MinimalDiamondCallBackProxy` at a mined address — **this** address is what Uniswap V4 `PoolManager` calls |
| **Facets** | Logic contracts; addresses **never** need V4 flags; still deployed via existing `create3Factory` facet path |
| **Required flags** | `uint160` bottom permission bits the proxy address must match (from package `requiredHookFlags()` — **pure / package-constant**) |
| **Binding** | Package-defined identity of one immortal instance (via `calcSalt`); one binding → one proxy forever |
| **First-deployer-wins** | If predicted address already has code and package `isExpectedInstance` accepts it → return existing; no facet-set equality required |
| **Idempotent deploy** | Same final salt / predicted address already holds an accepted live instance → return existing address |
| **Premine-first** | Production path is off-chain mine + `deployWithMineNonce`; auto-mine `deploy` is allowed but gas-risky |
| **DoD** | Definition of Done — §11 |

---

## 1. Goal

Ship a **permissionless, CREATE3-deployed ecosystem singleton factory** that:

1. Deploys **Diamond proxies** (`MinimalDiamondCallBackProxy`) via **CREATE2** with the **same factory-callback init pattern** as the vault diamond factory.  
2. **Does not** mix the **package contract address** into the CREATE2 salt (unlike vault factory).  
3. Mines (or accepts a premined) salt so the **proxy address** has Uniswap V4 **hook permission flags**.  
4. Lets packages declare **pure `requiredHookFlags()`** and stores/exposes those flags on each instance for public discovery.  
5. Exposes a **constant `PROXY_INIT_HASH`** (and getters) so off-chain miners can compute CREATE2 addresses without guessing initcode.  
6. Keeps instances **immutable after postDeploy** via **install-then-remove** of temporary cut/postDeploy surfaces (no live `diamondCut` for v1 hooks).  
7. Is general enough for **any** diamond that wants package-out-of-salt + optional flag mining — not only V4 hooks (hooks are the first product; naming remains V4-hook-oriented; `requiredHookFlags() == 0` allowed).  
8. **Extends Vault Registry deployment interface** so liquidity-holding V4 hook diamonds can be **deployed via this factory and registered as vaults** (in factory DoD).

### 1.1 Why not use `DiamondPackageCallBackFactory` alone

| Property | Vault factory | This factory |
|----------|---------------|--------------|
| Proxy deploy | CREATE2 `MinimalDiamondCallBackProxy` | **Same** |
| Salt outer mix | `keccak256(abi.encode(pkg, packageSalt))` | **No package address** |
| Address bits | Unconstrained | **Mine for V4 flags** |
| Package interface | `IDiamondFactoryPackage` | **`IUniswapV4HookDiamondPackage`** (+ pure flags + thin `isExpectedInstance`) |
| Instance mutability | Product-dependent | **Immutable after postDeploy** (install-then-remove cut) |
| Flag discovery | N/A | **Required flags on package + instance** |
| Production mine path | N/A | **Premine-first** (`deployWithMineNonce`) |

### 1.2 Why CREATE2 (not CREATE3) for instances

- `MinimalDiamondCallBackProxy` constructor calls `IFactoryCallBack(msg.sender)._initAccount()`.  
- CREATE2 `new Proxy{salt}()` from the factory → `msg.sender` is the factory → **callback works**.  
- Solmate CREATE3 deploys via an intermediate contract → constructor `msg.sender` is **not** the factory → callback breaks without a custom proxy.  
- CREATE2 still supports **off-chain premining** given public `PROXY_INIT_HASH` + deployer (factory) address + final salt.  
- Facets remain CREATE3 via existing process (unchanged).

---

## 2. Product summary

### 2.1 What this package is

| Attribute | Value |
|-----------|--------|
| Artifact | `UniswapV4HookDiamondPackageCallBackFactory` contract + interfaces + FactoryService helpers + Vault Registry deploy-path extension + tests |
| Deploy of factory | **Once** via existing `create3Factory` as ecosystem singleton (protocol deploy scripts / owner-operator path) |
| Deploy of instances | **CREATE2** `MinimalDiamondCallBackProxy` from this factory |
| Package shape | DFPkg-like; implements `IUniswapV4HookDiamondPackage` |
| Salt policy | Package contributes `calcSalt(pkgArgs)`; factory adds mineNonce; **no package address** |
| Flags | Package **pure** `requiredHookFlags()`; instance address must match; instance exposes flags |
| Production deploy | **Premine-first:** off-chain mine → `deployWithMineNonce` |
| Auto-mine deploy | `deploy` loops from nonce 0 — **allowed**, documented as **gas-risky** (tests / low flag density) |
| Idempotency | **First-deployer-wins:** return existing if code + package `isExpectedInstance` accepts |
| Immortality | One binding → one proxy; abandon and new binding if config wrong |
| Immutability | **Install-then-remove** temporary diamondCut / postDeploy surfaces; live proxy has **no** cut |
| ACL | **Permissionless** instance deploy (mitigations §8) |
| Registry | Vault Registry **deployment interface extension** calls this factory + registers vault metadata |

### 2.2 What this package is not

- Not a replacement for `DiamondPackageCallBackFactory` (vaults keep current salt law).  
- Not a monomorph CREATE3 hook miner (that path remains for legacy hooks until refactored).  
- Not the Single SE CP hook product itself (separate PRD/plan; **depends** on this factory).  
- Not automatic migration of dual/weighted/orbital monomorph hooks (separate effort).  
- Not post-deploy upgradeable hook instances (v1).  
- Not a full Vault Registry UI/product redesign — only the **deployment interface extension** needed to call this factory and register.  
- Not public marketing docs under `docs/` — this PRD lives **next to code**.

### 2.3 Non-goals (v1)

1. Changing vault factory salt law.  
2. Promoting factory to Crane (may later; v1 lives under IndexedEx path).  
3. CREATE3 instance deploy.  
4. On-chain vanity mining beyond flag bits (full vanity is out of scope).  
5. Refactoring all existing V4 hooks in this workstream.  
6. Full Vault Registry UI/product redesign.  
7. Deep facet-set / loupe equality as a factory collision gate (see §4.5 first-deployer-wins).  

---

## 3. Locked product decisions

### 3.1 Identity & placement

| # | Decision | Value |
|---|----------|--------|
| F1 | Product name | **`UniswapV4HookDiamondPackageCallBackFactory`** |
| F2 | Package path | `contracts/hooks/uniswap/v4/factory/` |
| F3 | Parallel factory | **New** factory; do **not** modify vault factory salt semantics |
| F4 | Crane promotion | Deferred; IndexedEx path for v1 |
| F5 | PRD location | Next to code (this file); not under public `docs/` |
| F6 | First consumer | Single SE Buffer CP Hook package — **factory is hard prerequisite** |
| F7 | Later consumers | Other IndexedEx V4 hooks that implement `IUniswapV4HookDiamondPackage` |
| F8 | Generality | Usable for any diamond that wants **package-out-of-salt** CREATE2 deploy; V4 flag mining is first-class but packages may declare `requiredHookFlags() == 0` if no flags needed; naming stays V4-hook-oriented |

### 3.2 CREATE2 & proxy

| # | Decision | Value |
|---|----------|--------|
| F9 | Instance opcode | **CREATE2 only** for hook/instance proxies |
| F10 | Proxy type | **`MinimalDiamondCallBackProxy`** (reuse) |
| F11 | Init pattern | Same as vault factory: proxy ctor → `IFactoryCallBack(factory).initAccount` → base cuts + package cuts + `pkg.initAccount` → postDeploy |
| F12 | `PROXY_INIT_HASH` | **Constant** = `keccak256(type(MinimalDiamondCallBackProxy).creationCode)` on the factory; **public getter** for off-chain premining |
| F13 | Deployer for CREATE2 | **This factory address** (so preminers use factory as CREATE2 deployer) |
| F14 | Facets | Existing CREATE3 facet deploy path — **unchanged** |
| F15 | Factory singleton | Deploy factory **once** via CREATE3 (`create3Factory`); protocol/owner-operator deploy scripts — not end-user instance deploy ACL |

### 3.3 Flags & mining

| # | Decision | Value |
|---|----------|--------|
| F16 | What is mined | **Proxy address only**; facets never need flags |
| F17 | Flag source | Package **`requiredHookFlags() external pure returns (uint160)`** — **package-constant** (not PkgArgs-dependent); factory masks to `Hooks.ALL_HOOK_MASK` / bottom 14 bits |
| F18 | Flag storage | Persist required flags on instance (diamond storage / aware repo) and **expose public view** on instance (package-defined getter or factory-standard `requiredHookFlags()` on proxy) |
| F19 | Auto-mine | `deploy(...)` loops `mineNonce` from 0 until address flags match; revert `HookMineExhausted` after **`MAX_LOOP`** (peer HookMiner: **160_444**). **Allowed but gas-risky** — not the preferred production path |
| F20 | Premine-first production | **`deployWithMineNonce`** is the **expected production path**; accepts premined nonce; **validates** flags on predicted address; reuses shared internal deploy core |
| F21 | Determinism | Auto-mine always searches from `mineNonce = 0` upward so first hit is unique per package salt → stable address when auto-mine is used |

### 3.4 Salt law (normative)

| # | Decision | Value |
|---|----------|--------|
| F22 | No package in salt | CREATE2 salt **must not** include `address(pkg)` |
| F23 | Package contribution | `packageSalt = pkg.calcSalt(pkgArgs)` after `processArgs` (package decides what of PkgArgs enters salt; often full-args hash) |
| F24 | Final salt composition | **Normative:** `finalSalt = keccak256(abi.encode(packageSalt, mineNonce))` — efficient, mineNonce-only free variable, off-chain friendly |
| F25 | Off-chain mining recipe | (1) `processed = processArgs(pkgArgs)` using same rules as on-chain (prefer pure/view processArgs); (2) `packageSalt = calcSalt(processed)`; (3) loop `mineNonce`; (4) `addr = create2(factory, PROXY_INIT_HASH, finalSalt)`; (5) check `uint160(addr) & FLAG_MASK == requiredFlags` (from pure `requiredHookFlags()`) |
| F26 | One binding → one immortal proxy | **First-deployer-wins:** same packageSalt first successful deploy owns the address forever; later deploys with same salt return existing if `isExpectedInstance` accepts; if code present and package rejects → `HookDeployCollision` |
| F27 | Package identity in salt | Packages **should** include a **stable product id** (e.g. name hash / bytes32 PRODUCT_ID) inside `calcSalt` so different products do not collide while still excluding package **address** (allows facet/package code redeploy at new addresses without changing binding salt if PRODUCT_ID + args match) |

### 3.5 Package interface extension

| # | Decision | Value |
|---|----------|--------|
| F28 | Base | Keep full `IDiamondFactoryPackage` behavior |
| F29 | Extension | **`IUniswapV4HookDiamondPackage is IDiamondFactoryPackage`** |
| F30 | Required: flags | `function requiredHookFlags() external pure returns (uint160 flags);` |
| F30b | Required: expected instance | `function isExpectedInstance(address proxy, bytes calldata processedArgs) external view returns (bool);` — **package-owned**; factory only calls it |
| F31 | Optional helpers | Package may document recommended `calcSalt` shape; factory does not hardcode product bindings |
| F32 | Base facets on every proxy | Same as vault factory today: ERC165, DiamondLoupe, ERC8109, temporary PostDeploy hook (removed postDeploy) |
| F33 | Immutability | **Install-then-remove:** temporary diamondCut / postDeploy scaffolding as needed for init; **postDeploy removes cut** so live proxies have **no** callable `diamondCut`. Failed config → abandon instance |

### 3.6 Storage & init

| # | Decision | Value |
|---|----------|--------|
| F34 | Binding storage | Package `initAccount` writes binding via **Diamond storage / Aware Repos** (poolManager, feeOracle, SE, tokens, etc.) — not proxy constructor immutables |
| F35 | Reuse AwareRepos | Prefer existing Crane/IndexedEx AwareRepos patterns |
| F36 | Return value | `deploy*` returns **`address` only** |
| F36b | Events | Emit **`HookDiamondDeployed`** on first successful CREATE2 deploy (not on pure idempotent return) — see §7.1 |

### 3.7 ACL & trust

| # | Decision | Value |
|---|----------|--------|
| F37 | Instance deploy ACL | **Permissionless** |
| F38 | Package trust | Same as vault DFPkgs — users must understand the package they deploy; **PRODUCT_ID + calcSalt inputs** are the security boundary (not package address at redeploy) |
| F39 | Selfdestruct / redeploy | No special handling beyond CREATE2 collision rules |
| F39b | Factory singleton deploy | Protocol/owner-operator CREATE3 path; not part of end-user permissionless surface |

### 3.8 Registry

| # | Decision | Value |
|---|----------|--------|
| F40 | Vault Registry | **In factory DoD:** extend Vault Registry **deployment interface** with functions that call **this** factory, then register the resulting hook diamond as a vault |
| F41 | Registry detail | Exact function names/signatures are plan-owned; product requires: deploy via hook factory → register vault metadata; **must not** reintroduce package-in-salt; smoke test in factory DoD |

### 3.9 Testing forks

| # | Decision | Value |
|---|----------|--------|
| F42 | Forks | **Ethereum mainnet**, **Base**, and **Robinhood 4663** fork smokes as DoD |
| F43 | Stub package | Hermetic **test stub** `IUniswapV4HookDiamondPackage` for factory isolation tests |
| F44 | Collision law in tests | Stub `isExpectedInstance` is **thin** (code present + flags match); prove first-deployer-wins / idempotent return |

---

## 4. Normative salt & address math

### 4.1 Constants

```text
PROXY_INIT_HASH = keccak256(type(MinimalDiamondCallBackProxy).creationCode)
FLAG_MASK       = Hooks.ALL_HOOK_MASK   // bottom 14 bits
MAX_LOOP        = 160_444               // mine exhaustion
```

Factory **must** expose at least:

```solidity
function PROXY_INIT_HASH() external view returns (bytes32);
// or public constant — either is fine if off-chain can read it
```

### 4.2 Address prediction (CREATE2)

```text
// Standard CREATE2:
// address = keccak256(0xff ++ factoryAddress ++ finalSalt ++ PROXY_INIT_HASH)[12:]

predicted = create2Address(factory, finalSalt, PROXY_INIT_HASH)
flagsOk   = (uint160(predicted) & FLAG_MASK) == (requiredFlags & FLAG_MASK)
```

### 4.3 Auto-mine algorithm (on-chain)

**Product weight:** allowed convenience / hermetic path. Prefer off-chain premine + `deployWithMineNonce` in production (gas).

```text
packageSalt = pkg.calcSalt(processedPkgArgs)
requiredFlags = pkg.requiredHookFlags() & FLAG_MASK   // pure

for mineNonce = 0 .. MAX_LOOP-1:
  finalSalt = keccak256(abi.encode(packageSalt, mineNonce))
  predicted = create2Address(address(this), finalSalt, PROXY_INIT_HASH)
  if (uint160(predicted) & FLAG_MASK) != requiredFlags: continue
  // first match
  if predicted.code.length > 0:
    require pkg.isExpectedInstance(predicted, processedPkgArgs)
    return predicted   // idempotent first-deployer-wins
  // deploy CREATE2 proxy at finalSalt; init callback; postDeploy; freeze
  emit HookDiamondDeployed(...)
  return predicted

revert HookMineExhausted()
```

### 4.4 Premine entrypoints (production path)

```text
// Preferred production: caller supplies mineNonce found off-chain
deployWithMineNonce(pkg, pkgArgs, mineNonce) → address
  // compute finalSalt; require flags; then shared deploy/idempotent path

// View helpers (normative):
  previewFinalSalt(packageSalt, mineNonce)
  calcAddress(pkg, pkgArgs, mineNonce)
// Optional:
  findMineNonce(pkg, pkgArgs) view  // eth_call helper; may OOG — document off-chain preferred
```

**Normative public API (F20/F36):**

```solidity
/// @notice Auto-mine from mineNonce 0. Gas-risky for dense flag requirements; prefer deployWithMineNonce in production.
function deploy(IUniswapV4HookDiamondPackage pkg, bytes calldata pkgArgs)
    external returns (address proxy);

/// @notice Production path: deploy with off-chain premined mineNonce.
function deployWithMineNonce(
    IUniswapV4HookDiamondPackage pkg,
    bytes calldata pkgArgs,
    uint256 mineNonce
) external returns (address proxy);

function calcAddress(
    IUniswapV4HookDiamondPackage pkg,
    bytes calldata pkgArgs,
    uint256 mineNonce
) external view returns (address predicted);

function PROXY_INIT_HASH() external view returns (bytes32);
```

Shared internal logic between `deploy` (auto-mine) and `deployWithMineNonce` (premine). Optional wrappers OK.

### 4.5 Idempotency & expected instance (first-deployer-wins)

**Product law:** when predicted address has code:

1. Verify **required flags** on the address match package pure `requiredHookFlags()` (bytecode at wrong flags should be impossible if salt law held; still check on premine).  
2. Call **`pkg.isExpectedInstance(predicted, processedPkgArgs)`** (package-owned).  
3. If `true` → **return address** (idempotent; **first successful deployer wins forever** for that salt).  
4. If `false` → **revert** `HookDeployCollision(address)`.

**Thin `isExpectedInstance` contract (v1 normative recommendation for packages + required for stub):**

```text
// Package callback owns the function; factory only calls it.
// v1 product law for collision depth: first-deployer-wins with thin checks.
// isExpectedInstance MUST NOT require facet-set / loupe equality that would
// block intentional package-address swap at same PRODUCT_ID + calcSalt.

// Default / stub behavior:
return proxy.code.length > 0
    && (uint160(proxy) & FLAG_MASK) == (requiredHookFlags() & FLAG_MASK);

// Optional package soft checks allowed (e.g. stored PRODUCT_ID view if already
// initialized) but MUST NOT reject a legitimate first live proxy solely because
// a different package *implementation address* is used on a later deploy call.
```

**Security implication (explicit):** a later package implementation that reproduces the same `calcSalt` material (same PRODUCT_ID + binding fields) will **return the existing proxy** if thin `isExpectedInstance` accepts. Users and integrators treat **PRODUCT_ID + calcSalt inputs** as the binding security boundary — not the package contract address or facet set at redeploy time. Deep facet verification is **social / off-chain** (source, loupe inspection before first use), not a factory gate.

---

## 5. Lifecycle (deploy)

```text
1. processArgs(pkgArgs) → processed
2. packageSalt = calcSalt(processed)
3. requiredFlags = requiredHookFlags()   // pure
4. Resolve mineNonce (auto-loop or caller-supplied premined)
5. finalSalt = keccak256(abi.encode(packageSalt, mineNonce))
6. predicted = CREATE2 address
7. If code at predicted → isExpectedInstance → return or HookDeployCollision
8. Record transient factory context (pkg, processed args) for callback (peer vault factory pattern)
9. CREATE2 MinimalDiamondCallBackProxy{salt: finalSalt}()
10. Proxy ctor → factory.initAccount:
      - base facet cuts (ERC165, Loupe, ERC8109, PostDeploy)
      - temporary diamondCut surface as required for package cuts (install-then-remove law)
      - package diamondConfig cuts
      - pkg.initAccount(processed)  // bindings in diamond storage; store requiredFlags
11. pkg.postDeploy(proxy); proxy postDeploy hook cleanup
12. Remove diamondCut / temporary postDeploy surfaces so live instance has no cut
13. emit HookDiamondDeployed(proxy, pkg, packageSalt, mineNonce, requiredFlags)
14. return proxy
```

---

## 6. `IUniswapV4HookDiamondPackage` (normative)

```solidity
interface IUniswapV4HookDiamondPackage is IDiamondFactoryPackage {
    /// @notice Uniswap V4 hook permission flags the CREATE2 proxy address must encode.
    /// @dev Package-constant (pure). Factory masks to FLAG_MASK. 0 allowed for non-hook diamonds.
    function requiredHookFlags() external pure returns (uint160 flags);

    /// @notice Thin acceptance check for idempotent redeploy / first-deployer-wins.
    /// @dev Factory calls when predicted address has code. v1: accept if code + flags match
    ///      product requirements; MUST NOT require facet-set equality that blocks same-salt
    ///      package-address swap. See PRD §4.5.
    function isExpectedInstance(address proxy, bytes calldata processedArgs)
        external
        view
        returns (bool);
}
```

**PkgInit / PkgArgs:** remain on the package **interface** (Crane DFPkg rule), not the implementation contract.

**Package `calcSalt` guidance (normative recommendation, not factory-enforced layout):**

```text
// Include stable product identity + binding fields that define the immortal instance
// DO NOT include: package address, facet addresses that change on logic redeploy (unless intentional)
// DO include: PRODUCT_ID, poolManager, feeOracle, SE, tokens, threshold mode, etc. as product requires
```

**Instance public surface (minimum for flags):**

```text
requiredHookFlags() → uint160   // stored at init from package pure flags; public so integrators can read without package
```

May live on a small shared facet installed by factory or by every hook package.

---

## 7. Factory surface (normative)

### 7.1 Required

| Item | Notes |
|------|--------|
| `PROXY_INIT_HASH()` | Constant initcode hash for MinimalDiamondCallBackProxy |
| `deploy(pkg, pkgArgs)` | Auto-mine from nonce 0; **gas-risky**; hermetic/convenience |
| `deployWithMineNonce(pkg, pkgArgs, mineNonce)` | **Production premine path** |
| `calcAddress(pkg, pkgArgs, mineNonce)` | View prediction |
| `MAX_LOOP` or documented constant | 160_444 |
| Errors | `HookMineExhausted`, `HookDeployCollision`, `InvalidHookFlags` (premine flags mismatch), zero-address guards |
| Event | `HookDiamondDeployed(address indexed proxy, address indexed pkg, bytes32 packageSalt, uint256 mineNonce, uint160 flags)` on **first** deploy only |
| Base facet immutables | ERC165, Loupe, ERC8109, PostDeploy — peer vault factory InitArgs pattern |
| Immutability | Install-then-remove cut; live proxies have no diamondCut |

### 7.2 FactoryService (IndexedEx)

Library helpers for tests/scripts:

- Deploy factory singleton via `create3Factory`  
- Typed `deployHook(factory, pkg, pkgArgs)` / premine helpers  
- Off-chain mine recipe in NatSpec (emphasize **premine-first**)  

### 7.3 Vault Registry extension (**in factory DoD**)

- Extend Vault Registry **deployment interface** with functions that can invoke **this** factory (not only the vault diamond factory).  
- Liquidity-holding V4 hook diamonds are a **vault type** discoverable like other vaults after register.  
- Exact registry API names are plan-owned but must not reintroduce package-in-salt.  
- **Factory DoD includes** implement + hermetic/smoke test of the extension path (deploy via hook factory → register).  
- Single SE CP hook registration against a real hook package remains **consumer** DoD after factory green; factory proves the path with stub or minimal package as plan specifies.

---

## 8. Security notes

### 8.1 Permissionless deploy — risks & mitigations

| Risk | Mitigation |
|------|------------|
| Spam instances | Deployer pays gas + mine cost; no factory subsidy |
| Front-run deploy of a binding | **First-deployer-wins**; users verify loupe/facets/source **before first use**; packages use unique PRODUCT_ID in `calcSalt` |
| Same packageSalt, different package implementation | **Returns existing proxy** if thin `isExpectedInstance` accepts — intentional package-out-of-salt; binding security = PRODUCT_ID + calcSalt inputs |
| Malicious package reusing another product's salt material | Distinct PRODUCT_ID / binding fields in `calcSalt`; social verification of package before first deploy |
| Package address not in salt → code swap confusion | Immortal proxy; new package **address** with same PRODUCT_ID + args resolves to **same** proxy (return existing) — intentional; logic upgrades require new product id / new binding |
| Wrong flags | Factory enforces address flags == pure `requiredHookFlags` |
| Upgrade / rug via diamondCut | **Install-then-remove** — no cut facet on live hooks after postDeploy |
| Malicious facet cuts in package | Same trust model as vault DFPkgs — user chooses package **before first deploy** |
| Init callback spoof | Only CREATE2 from factory makes factory `msg.sender` in proxy ctor |
| On-chain auto-mine grief / gas | Premine-first production path; auto-mine documented as gas-risky |

### 8.2 Trust model (explicit)

Users must understand the **package** they deploy (facets, init, salt policy) **before the first successful deploy** of a binding. After that, the proxy is immortal and immutable; redeploys with the same salt return the same address under first-deployer-wins.

The factory provides mechanical guarantees:

- V4 flag bits on address  
- No package address in salt  
- Install-then-remove immutability scaffolding  
- Thin package `isExpectedInstance` gate on idempotent path  

It does **not** provide economic security of arbitrary packages, nor deep facet-set identity across package-address swaps.

---

## 9. File map (target)

```text
contracts/hooks/uniswap/v4/factory/
  UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_PRD.md   # this file
  UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_IMPLEMENTATION_AND_TEST_PLAN.md  # follow-on

  interfaces/
    IUniswapV4HookDiamondPackage.sol
    IUniswapV4HookDiamondPackageCallBackFactory.sol

  UniswapV4HookDiamondPackageCallBackFactory.sol
  UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol   # CREATE3 deploy of factory + helpers

  # Test stub package (hermetic)
  stubs/
    UniswapV4HookDiamondFactoryStubPackage.sol
    IUniswapV4HookDiamondFactoryStubPackage.sol

  # Optional shared facet for requiredHookFlags() view on instances
  facets/ or shared/
    UniswapV4HookFlagsFacet.sol   # if not inlined per package
```

**Registry touchpoints** (under `contracts/registries/vault/` or manager deploy facets): **in DoD** — plan lists exact files for Vault Registry deployment interface extension that calls this factory.

**Tests:**

```text
# Package-adjacent TestBase preferred
contracts/hooks/uniswap/v4/factory/
  TestBase_UniswapV4HookDiamondPackageCallBackFactory.sol

test/foundry/spec/hooks/uniswap/v4/factory/
  UniswapV4HookDiamondFactory_Deploy.t.sol
  UniswapV4HookDiamondFactory_Salt.t.sol
  UniswapV4HookDiamondFactory_Flags.t.sol
  UniswapV4HookDiamondFactory_Idempotent.t.sol
  UniswapV4HookDiamondFactory_Premine.t.sol
  UniswapV4HookDiamondFactory_Immutable.t.sol
  UniswapV4HookDiamondFactory_Registry.t.sol   # deploy-via-hook-factory + register smoke

test/foundry/fork/ethereum_main/hooks/uniswap/v4/factory/
  UniswapV4HookDiamondFactory_Ethereum.t.sol
test/foundry/fork/base_main/hooks/uniswap/v4/factory/
  UniswapV4HookDiamondFactory_Base.t.sol
test/foundry/fork/robinhood_4663/hooks/uniswap/v4/factory/
  UniswapV4HookDiamondFactory_Robinhood.t.sol
```

---

## 10. Test expectations

### 10.1 Hermetic (stub package)

| ID | Case |
|----|------|
| H1 | Factory deploys via CREATE3 singleton path |
| H2 | `PROXY_INIT_HASH` matches `keccak256(MinimalDiamondCallBackProxy.creationCode)` |
| H3 | `deploy` / `deployWithMineNonce` yields address with `requiredHookFlags` bits set |
| H4 | Auto-mine deterministic: two deploys same args → same address (idempotent return) |
| H5 | `deployWithMineNonce` with correct premined nonce succeeds (primary production path) |
| H6 | Wrong mineNonce (flags mismatch) reverts `InvalidHookFlags` |
| H7 | Mine exhaustion reverts after MAX_LOOP (stub with impossible flags and/or test-only MAX_LOOP if needed) |
| H8 | Package address **not** in salt: two different package **addresses** with same PRODUCT_ID + same calcSalt material → same predicted address; second deploy **returns existing** (first-deployer-wins / thin `isExpectedInstance`) |
| H9 | Base facets present: ERC165, Loupe, ERC8109 |
| H10 | No diamondCut after postDeploy (install-then-remove immutability) |
| H11 | Stub `initAccount` writes diamond storage readable via views |
| H12 | `requiredHookFlags()` on instance matches package pure flags |
| H13 | Off-chain recipe: pure calc from factory address + PROXY_INIT_HASH + finalSalt equals on-chain address |
| H14 | `HookDiamondDeployed` emitted on first deploy; not required on pure idempotent return |
| H15 | Registry deploy-path extension: deploy via this factory + register vault smoke |

### 10.2 Forks

| ID | Case |
|----|------|
| FK1 | Ethereum mainnet fork: deploy factory (or use live if present) + stub package smoke |
| FK2 | Base mainnet fork: same |
| FK3 | Robinhood 4663 fork: same |

### 10.3 Production-first rules

- No mock factory SUT; real CREATE2/CREATE3 paths.  
- Stub package is a real DFPkg-shaped contract for factory isolation (not a mock of the factory).  
- Stub `isExpectedInstance` implements **thin** acceptance (code + flags).  
- Single SE CP hook tests are **out of this PRD’s hermetic stub matrix** but **block** on factory DoD in the consumer plan.

---

## 11. Definition of Done

1. Factory + interfaces + FactoryService under `contracts/hooks/uniswap/v4/factory/`.  
2. CREATE2 `MinimalDiamondCallBackProxy` deploy with factory callback init.  
3. Salt **without** package address; `finalSalt = keccak256(abi.encode(packageSalt, mineNonce))`.  
4. Premine-first: `deployWithMineNonce` + auto-mine `deploy` with MAX_LOOP exhaustion; NatSpec gas guidance on auto-mine.  
5. Public **`PROXY_INIT_HASH`** for off-chain premining.  
6. `IUniswapV4HookDiamondPackage.requiredHookFlags()` **pure** enforced on address bits.  
7. `isExpectedInstance` package callback on idempotent path; thin first-deployer-wins law.  
8. Flags stored and exposed on instance.  
9. Idempotent return of accepted instance; `HookDeployCollision` when package rejects.  
10. Install-then-remove immutability (no live diamondCut).  
11. `HookDiamondDeployed` on first deploy.  
12. Stub package + hermetic §10.1 green (including H15 registry smoke).  
13. Fork smokes: Ethereum + Base + Robinhood 4663.  
14. **Vault Registry deployment interface extension** implemented and tested (deploy via this factory + register).  
15. Implementation plan written; single SE CP hook plan may unblock coding against this factory.  
16. NatSpec: off-chain mine recipe (premine-first); permissionless risks; first-deployer-wins; difference from vault factory.

---

## 12. Implementation plan handoff (for next agent)

**Suggested plan file:**  
`contracts/hooks/uniswap/v4/factory/UNISWAP_V4_HOOK_DIAMOND_PACKAGE_CALLBACK_FACTORY_IMPLEMENTATION_AND_TEST_PLAN.md`

**Suggested phases:**

```text
0. Spike: CREATE2 address helpers + PROXY_INIT_HASH + flag check pure lib
1. IUniswapV4HookDiamondPackage (pure flags + isExpectedInstance) + factory interface + events/errors
2. Factory core (deploy / deployWithMineNonce / calcAddress / first-deployer-wins idempotent)
3. Install-then-remove immutability postDeploy (no live cut)
4. Stub package (thin isExpectedInstance) + hermetic suite
5. FactoryService CREATE3 deploy of factory singleton
6. Vault Registry deployment interface extension + register smoke (H15)
7. Forks Ethereum / Base / 4663
8. Handoff note for Single SE CP hook agent
```

**Consumer note (Single SE CP hook):**  
Hook Diamond deploy via this factory is the **required** path once this factory is green; monomorph CREATE3 remains emergency fallback only if plan explicitly waives.

---

## 13. Open items for implementation plan only

| Item | Guidance |
|------|----------|
| Exact Vault Registry function names / facet surface | Product requires deploy-via-this-factory + register; plan names the API |
| Whether `processArgs` is view-safe for off-chain | Prefer pure/view calcSalt path; document if processArgs is stateful |
| Shared `requiredHookFlags` instance facet vs per-package | Plan discretion |
| `findMineNonce` on-chain view | Optional; off-chain preferred |
| Temporary diamondCut install details | Mirror vault factory InitArgs/postDeploy as closely as possible; live must have no cut |

**Product Q&A closed in v1.1:** registry in DoD; package-owned thin `isExpectedInstance`; first-deployer-wins; install-then-remove immutability; premine-first production; pure package-constant flags.

---

## 14. Revision history

| Version | Date | Notes |
|---------|------|-------|
| v1.0 | 2026-08-04 | Initial PRD: parallel Hook Diamond factory; CREATE2 + MinimalDiamondCallBackProxy; package-out-of-salt; package-owned calcSalt + mineNonce; PROXY_INIT_HASH for off-chain premine; requiredHookFlags; immutable instances; permissionless; registry vault typing; stub + ETH/Base/4663 forks; Single SE CP first consumer / hard block |
| v1.1 | 2026-08-04 | Review locks: Vault Registry **deployment interface extension in DoD**; package-owned **thin** `isExpectedInstance` + **first-deployer-wins**; **install-then-remove** diamondCut; **premine-first** production (`deployWithMineNonce`); **pure** `requiredHookFlags`; `HookDiamondDeployed` event; security honesty for package-out-of-salt; H14–H15; closed product Q&A |

---

## 15. Approval

| Role | Sign-off |
|------|----------|
| Product | Pending |
| Protocol | Pending |

**Status: Draft v1.1 — product law locked; ready for implementation plan and implementor lock.**

---

## 16. Summary for coding agents

```text
Name: UniswapV4HookDiamondPackageCallBackFactory
Path: contracts/hooks/uniswap/v4/factory/
Peer: DiamondPackageCallBackFactory (unchanged; package-IN-salt)
This: package-OUT-of-salt + CREATE2 mine for V4 flags
Proxy: MinimalDiamondCallBackProxy (callback init works with CREATE2)
Expose: PROXY_INIT_HASH for off-chain CREATE2 premining
Salt: finalSalt = keccak256(abi.encode(pkg.calcSalt(args), mineNonce))
Package:
  - requiredHookFlags() pure (package-constant)
  - isExpectedInstance(proxy, processedArgs) thin (code + flags; first-deployer-wins)
Production deploy: deployWithMineNonce (premine-first); deploy() auto-mine is gas-risky
Deploy ACL: permissionless instances; factory singleton via CREATE3 protocol scripts
Idempotent: first successful deploy owns address forever for that salt
Immutable: install-then-remove cut; no live diamondCut
Event: HookDiamondDeployed on first deploy
Facets: existing CREATE3 facet path
Factory: CREATE3 singleton once
Registry: IN DoD — extend Vault Registry deployment interface to call this factory + register
First consumer: Single SE Buffer CP Hook (blocks on this DoD)
Test: stub package + hermetic (incl. registry smoke) + Ethereum/Base/4663 forks
Security boundary: PRODUCT_ID + calcSalt inputs (not package address at redeploy)
```
