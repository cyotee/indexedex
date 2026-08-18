# PRD: Uni V4 SE DETF compatibility with staged hook initialization

**Status:** Draft v0.2 — product law for review. Implementor and plan agents make **no** product or layout choices once this file is accepted.  
**Date:** 2026-08-18  
**Scope:** All four Uni V4 Standard Exchange DETF families (CP Single, Orbital, Weighted, Curve Quad).  
**Follow-on:** Implementation / test plan is co-located (file map, phases, DoD only). This PRD is product law.

| Doc | Role |
|-----|------|
| **This file** | Product law for DETF deploy stages, children wiring, hook-door orchestration, TestBases, scripts |
| Co-located family `*_PRD.md` (four families) | Still SoT for mint/bond/threshold/expansion. **This file supersedes** any sentence that says hook `postDeploy` or DETF `postDeploy` initializes V4 pair doors or deploys bond NFT / rebasing in the DETF deploy transaction |
| [`UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md`](./UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md) | Unchanged. `deployVault(PkgArgs, uint256)` + premine stay |
| Hook staged-init family PRDs under `contracts/hooks/uniswap/v4/**` | Unchanged. Door ABI, bootstrap cuts, `finalizeInitialization`, permissionless callers stay |
| Hook family index | [`../../../../../../hooks/uniswap/v4/UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md`](../../../../../../hooks/uniswap/v4/UNISWAP_V4_HOOK_STAGED_INIT_FAMILY_INDEX.md) |

**Authority:** If this PRD and a family DETF PRD / family DETF impl plan / Anvil script README disagree on **when hook doors exist**, **when hook production ABI appears**, or **when bond NFT / rebasing are deployed**, **this PRD wins**. The plan agent must patch those docs to match.

Hook staged-init PRDs that say “do not touch SE Orbital / Weighted / Quad DETF in the hook change set” are **not** a ban on this follow-on. Those greps deferred DETF work **to this PRD**.

---

## 0. One-line goal

A Uni V4 SE DETF deploy transaction creates an inert diamond and a **bootstrap** reserve hook only. Product pair doors and hook finalize stay on `IUniswapV4HookStagedPairInit`. Bond NFT and rebasing are created later by two permissionless instance functions, `completeReserveBondNft()` then `completeReserveClaim()`, after the hook is finalized. First bond still establishes `isReserveLive`.

---

## 1. Why

Hook staged init (Orbital gold S6–S12, copied by every SE buffer family) changed reserve-hook bring-up to three caller stages:

```text
hook deployVault  →  bootstrap diamond (vault pair + package-as-init)
deployPair(a, b)  →  one PoolManager.initialize per product unordered pair
finalizeInitialization  →  remove init facet; add production (ERC20, deposit/join, SE, hooks)
```

`pkg.postDeploy` on those hooks now returns `true` and initializes **zero** pools. Production selectors — including `IERC20.decimals`, `depositSingle`, `addLiquidity`, `isLive` — are **unmatched** until finalize.

Four DETF packages still assume the old hook:

| Family | Today after `DETF.deployVault` | Break |
|--------|--------------------------------|-------|
| CP Single | `_initPool` calls `deployPair` + `finalizeInitialization` **inside** DETF `postDeploy`, then deploys children | Works for 1 door. Recreates a same-tx hook bring-up this PRD forbids |
| Orbital | `_deployReserveHook` only. Family PRD says hook `postDeploy` inits **all three** doors, then children deploy | Hook `postDeploy` is a no-op. Bond NFT `initAccount` calls `lpToken.decimals()` → unmatched |
| Weighted | Same as Orbital. Family PRD says hook `postDeploy` inits all \(\binom{n}{2}\) doors | Same break. \(n=8\) is 28 `PoolManager.initialize`s — the gas cliff staged init exists to avoid |
| Curve Quad | Same as Orbital. Family PRD says hook `postDeploy` inits all six doors | Same break |

Shared bond NFT package (`DETFNFTVaultDFPkg.initAccount`) does:

```solidity
ERC4626Repo._initialize(args.lpToken, IERC20Metadata(address(args.lpToken)).safeDecimals(), ...);
```

That `decimals()` call is why children **cannot** be created until hook finalize. This PRD does **not** change the bond NFT package to skip `decimals()`.

CP Single `_initPool` inside DETF `postDeploy` is **deleted**. All four families use the same staged shape.

---

## 2. Locked decisions

| # | Decision | Status |
|---|----------|--------|
| D1 | **Four families only:** CP Single, Orbital, Weighted, Curve Quad Uni V4 SE DETF packages + `I*DETF` / `I*DETDFPkg` + gold TestBases + every in-repo caller (tests, Anvil scripts). | **Locked** |
| D2 | **Do not** invent Dual / Balancer Quad / standalone-hook DETF packages. Those hooks have no DETF family today. | **Locked** |
| D3 | **Do not** change hook factory, hook DFPkg `deployVault` arity, hook `IUniswapV4HookStagedPairInit`, hook `postDeploy`, salt, flags, or mine-nonce law. | **Locked** |
| D4 | **Do not** change mint/bond/threshold/expansion/claim **economics**. Only **when** the reserve hook and children exist. | **Locked** |
| D5 | DETF `deployVault(PkgArgs, uint256)` arity and `UniswapV4DetfHookPremineLib` stay exactly as the mine-nonce PRD. | **Locked** |
| D6 | DETF `postDeploy` deploys the reserve hook via `HOOK_PKG.deployVault(hArgs, cfg.hookMineNonce)` and writes core Repo (bindings, policy, `reserveHook`). It does **not** call `deployPair`, `finalizeInitialization`, or `PoolManager.initialize`. It does **not** deploy bond NFT or rebasing. | **Locked** |
| D7 | Delete CP Single `_initPool`. No family may reintroduce doors or finalize inside DETF `postDeploy`. | **Locked** |
| D8 | Product doors and finalize are called on the **hook** via `IUniswapV4HookStagedPairInit`. DETF instance does **not** wrap `deployPair` or `finalizeInitialization`. | **Locked** |
| D9 | Shared off-instance helper `UniswapV4DetfHookStagedInitLib` exposes **granular** functions (`productTokens*`, `openProductPair`, `finalizeHook`) plus a TestBase-only bundle `ensureReserveReady*`. Broadcast scripts **must** send **one transaction per `deployPair`**, then a finalize TX, then the two wiring TXs. They **must not** call `ensureReserveReady*` (that is one transaction). | **Locked** |
| D10 | DETF instance adds on each `I*DETF` only (not `I*DETDFPkg`, not shared `IDetf`): `isReserveHookFinalized()`, `isReserveWired()`, `completeReserveBondNft()`, `completeReserveClaim()`. | **Locked** |
| D11 | Wiring is **two** permissionless **one-shot** steps, in this order: `completeReserveBondNft()` (bond vault + protocol NFT tries + fee-recipient try) then `completeReserveClaim()` (rebasing). Claim reverts if the bond-NFT step has not succeeded. Each step reverts if already done. | **Locked** |
| D12 | First bond **reverts `ReserveNotWired()`** when `!isReserveWired()`. `isReserveWired()` is **both** children set. First bond does **not** call either wiring function. It does **not** call hook `deployPair` / `finalizeInitialization`. | **Locked** |
| D13 | `isReserveLive` stays first-successful-bond. Wiring is **not** live. Inert mint/burn stay blocked by existing `ReserveNotLive`. | **Locked** |
| D14 | Persist `bondNftVaultPkg` and `rebasingClaimTokenPkg` addresses on DETF Repo in `postDeploy` (copied from DFPkg immutables). Instance wiring cannot see DFPkg immutables. | **Locked** |
| D15 | Append those two addresses at the **end** of each family’s Repo `Storage`. Do **not** reorder existing fields. Do **not** add a `bool reserveWired` flag. Bond-NFT sentinel is `bondNftVault != address(0)`. Claim sentinel is `rebasingClaimToken != address(0)`. `isReserveWired()` is both. | **Locked** |
| D16 | No `via_ir`. No `new` facets/DFPkgs. DETF role names only. Production-first tests: no mocks of SUT. | **Locked** |
| D17 | Do **not** add these functions, events, or errors to shared `IDetf`. Balancer and other `IDetf` implementors stay unchanged. | **Locked** |

---

## 3. Packages in scope (complete)

| Family | Instance interface | Package | Gold TestBase |
|--------|--------------------|---------|---------------|
| CP Single | `IUniswapV4SingleStandardExchangeDETF` | `UniswapV4SingleStandardExchangeDETDFPkg` | `TestBase_UniswapV4SingleStandardExchangeDETF` |
| Orbital | `IUniswapV4StandardExchangeOrbitalDETF` | `UniswapV4StandardExchangeOrbitalDETDFPkg` | `TestBase_UniswapV4StandardExchangeOrbitalDETF` |
| Weighted | `IUniswapV4StandardExchangeWeightedDETF` | `UniswapV4StandardExchangeWeightedDETDFPkg` | `TestBase_UniswapV4StandardExchangeWeightedDETF` |
| Curve Quad | `IUniswapV4StandardExchangeCurveQuadStableDETF` | `UniswapV4StandardExchangeCurveQuadStableDETDFPkg` | `TestBase_UniswapV4StandardExchangeCurveQuadStableDETF` |

Paths stay under `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/`.

**Out of scope (do not change for this PRD):**

- Hook diamond factory
- Hook DFPkg staged-init machinery (already specified by hook PRDs)
- Shared bond NFT / rebasing **package implementations** except that DETF **call sites** move from DFPkg `postDeploy` to instance `completeReserveBondNft` / `completeReserveClaim`
- Shared `IDetf`
- Dual SE / Balancer Quad / standalone Orbital-Weighted-Quad hooks
- Non–Uni-V4-SE DETF families
- `PkgArgs` field lists
- `deployVault` arity / premine
- Product mint/bond/threshold/expansion formulas

---

## 4. Lifecycle (normative)

```text
tx DETF deploy (unchanged factory control flow):
  vault registry deployVault(pkg, abi.encode(args, mineNonce))
  DETF initAccount: PkgArgs checks, ERC20, vault repos, DeployConfig (incl. hookMineNonce)
  DETF postDeploy:
    validate SEs / pairs (today’s checks, unchanged)
    hook = HOOK_PKG.deployVault(hArgs, cfg.hookMineNonce)   # hook bootstrap only
    init vault token list (addresses only; includes hook)
    Repo._initializeCore(..., reserveHook=hook, bondNft=0, claim=0, nftIds=0,
                          bondNftVaultPkg=address(BOND_NFT_VAULT_PKG),
                          rebasingClaimTokenPkg=address(REBASING_CLAIM_TOKEN_PKG))
    Repo._initializePolicy(...)
    # NO deployPair, NO finalize, NO bond NFT, NO rebasing
  registry: DETF vaultConfig() then _registerVault
  DETF is inert, unwired. reserveHook() is callable.

tx Door (anyone, any order, on the hook — not on the DETF):
  IUniswapV4HookStagedPairInit(detf.reserveHook()).deployPair(tokenA, tokenB)
  Product pairs only (hook reverts otherwise). Idempotent skip-if-live.

tx Finalize (anyone, once, on the hook):
  IUniswapV4HookStagedPairInit(detf.reserveHook()).finalizeInitialization()
  Hook production ABI appears (ERC20, deposit/join, SE, hooks).
  isInitializationFinalized() selector becomes unmatched (hook gold S8 / S17).

tx completeReserveBondNft (anyone, once, on the DETF):
  require reserveHook != 0
  require isReserveHookFinalized()
  require bondNftVault == 0
  deploy bond NFT (lpToken = hook; decimals() now exists)
  try init DETF NFT + fee-recipient NFT (same try/catch as today’s postDeploy)
  Repo._setBondNft(bondVault, detfNftId, feeRecipientNftId)
  emit ReserveBondNftWired(hook, bondVault, detfNftId, feeRecipientNftId)
  still isReserveLive == false; isReserveWired() == false

tx completeReserveClaim (anyone, once, on the DETF):
  require bondNftVault != 0
  require rebasingClaimToken == 0
  deploy rebasing (same rate-token rule as today’s postDeploy; detfNftId from Repo)
  Repo._setClaim(claim)
  emit ReserveClaimWired(hook, claim)
  still isReserveLive == false; isReserveWired() == true

tx first bond (anyone, as today):
  require isReserveWired() else revert ReserveNotWired()
  existing first-bond body (creation-rate join, LP on NFT, isReserveLive = true)
```

| State | hook finalized | `bondNftVault` | claim | `isReserveWired` | `isReserveLive` | First bond |
|-------|----------------|----------------|-------|------------------|-----------------|------------|
| After DETF deploy | no | `0` | `0` | false | false | `ReserveNotWired` |
| Doors open, not finalized | no | `0` | `0` | false | false | `ReserveNotWired` |
| Hook finalized, no children | yes | `0` | `0` | false | false | `ReserveNotWired` |
| Bond NFT only | yes | set | `0` | false | false | `ReserveNotWired` |
| Wired / inert | yes | set | set | true | false | allowed (synthetically ungated) |
| Live | yes | set | set | true | true | later-bond rules |

`completeReserveBondNft` while the hook is not finalized reverts `ReserveHookNotFinalized` (finalize itself reverts `ProductDoorsNotLive` if called early; DETF does not call finalize). `completeReserveClaim` before the bond-NFT step reverts `ReserveBondNftNotWired()`. Claim cannot run first.

---

## 5. Instance surface (normative)

Add to **each** of the four `I*DETF` interfaces. Do **not** add these to `I*DETDFPkg`. Do **not** add them to shared `IDetf`.

```solidity
event ReserveBondNftWired(
    address indexed reserveHook,
    address bondNftVault,
    uint256 detfNftId,
    uint256 feeRecipientNftId
);
event ReserveClaimWired(address indexed reserveHook, address rebasingClaimToken);

error ReserveNotWired();
error ReserveHookNotFinalized();
error ReserveBondNftNotWired();
error ReserveBondNftAlreadyWired();
error ReserveClaimAlreadyWired();

function isReserveHookFinalized() external view returns (bool);
function isReserveWired() external view returns (bool);
function completeReserveBondNft() external returns (address bondNftVault);
function completeReserveClaim() external returns (address rebasingClaimToken);
```

Existing `bondNftVault()` / `rebasingClaimToken()` stay. They are the step sentinels. Do **not** add `isReserveBondNftWired()`.

### 5.1 `isReserveWired`

```text
return address(Repo.bondNftVault) != address(0)
    && address(Repo.rebasingClaimToken) != address(0)
```

No extra storage flag. Bond-NFT-only is **not** wired.

### 5.2 `isReserveHookFinalized`

Hook gold: after finalize, `isInitializationFinalized` is **unmatched**. Probe:

```solidity
function isReserveHookFinalized() public view returns (bool) {
    address hook_ = Repo._layoutStruct().reserveHook;
    if (hook_ == address(0)) return false;
    try IUniswapV4HookStagedPairInit(hook_).isInitializationFinalized() returns (bool done_) {
        return done_;
    } catch {
        return true;
    }
}
```

Do **not** use hook `isLive()` (that is book / sphere liveness, not init).  
Do **not** treat a zero `reserveHook` as finalized.

### 5.3 `completeReserveBondNft`

**Caller:** anyone.  
**Returns:** `bondNftVault` after a successful write.  
**Reverts:**

| Condition | Error |
|-----------|--------|
| `reserveHook == address(0)` | `ReserveHookNotFinalized()` |
| `!isReserveHookFinalized()` | `ReserveHookNotFinalized()` |
| `bondNftVault != address(0)` | `ReserveBondNftAlreadyWired()` |

**Body:**

1. Read `name` / `symbol` from DETF `ERC20Repo` (same string concat as today’s `_deployBondNftVault`).  
2. `bondVault = IDetfSelfNftInventoryDFPkg(s.bondNftVaultPkg).deployVault(name+" Bond", symbol+"-BOND", IDetf(this), IERC20(hook), IERC20(this), 0, this)`.  
3. `detfNftId = try bondVault.initializeDETFNFT() catch 0`.  
4. Fee-recipient NFT: same try/catch + `feeTo` / min-lock as today’s `_tryInitFeeRecipientNft`.  
5. `Repo._setBondNft(bondVault, detfNftId, feeRecipientNftId)`.  
6. Emit `ReserveBondNftWired(hook, address(bondVault), detfNftId, feeRecipientNftId)`.

If this function reverts after the bond-NFT package `deployVault` succeeded, the child exists on-chain and this DETF still has `bondNftVault == 0`. A retry deploys a **new** bond NFT. That is accepted for a revert **inside** this step. The two-step split exists so a **successful** bond-NFT step is not thrown away when claim deploy fails.

### 5.4 `completeReserveClaim`

**Caller:** anyone.  
**Returns:** `rebasingClaimToken` after a successful write.  
**Reverts:**

| Condition | Error |
|-----------|--------|
| `bondNftVault == address(0)` | `ReserveBondNftNotWired()` |
| `rebasingClaimToken != address(0)` | `ReserveClaimAlreadyWired()` |

Does **not** re-check hook finalize (bond-NFT step already required it; hook cannot un-finalize).

**Body:**

1. Rebasing: same family rule as today’s `_deployRebasingClaimToken`  
   - CP: `rateAsset = pairToken`  
   - Orbital: `rateAsset` already on Repo  
   - Weighted / Quad: first product-order pair (`pairTokens[0]`)  
   - `detfNftId` from Repo (may be 0 if the try in the bond-NFT step failed; same as today)  
2. `Repo._setClaim(claim)`.  
3. Emit `ReserveClaimWired(hook, address(claim))`.

If this function reverts after rebasing `deployToken` succeeded, a retry deploys a new claim token. Same in-step waste rule as §5.3.

Do **not** add a recovery setter that attaches an already-deployed child. Do **not** CREATE2-predict and reuse.

### 5.5 Where the selectors live

Do **not** add a new DETF facet.

| Family | Mutators | Views |
|--------|----------|-------|
| CP Single | Both on `UniswapV4SingleStandardExchangeDETFBondingTarget`. Add all four selectors to `UniswapV4SingleStandardExchangeDETFFacet.facetFuncs()`. | Same target (already owns `reserveHook` / `bondNftVault`). |
| Orbital / Weighted / Curve Quad | Both on that family’s `*BondingTarget`. Add those two selectors to the bonding facet `facetFuncs()`. | Both on `*InfoTarget` (already owns `reserveHook()`). Add those two selectors to the info facet `facetFuncs()`. |

Info targets stay view-split: they **must not** implement the mutators.

### 5.6 First-bond / child-dependent gates

At the start of first-bond execution (before any hook `depositSingle` / `addLiquidity`):

```text
if (address(Repo.bondNftVault) == address(0)
    || address(Repo.rebasingClaimToken) == address(0)) {
    revert ReserveNotWired();
}
```

Later-bond, sell, close, claim, compound, primary mint/burn already require `isReserveLive` or hook LP. After live, both wiring steps have already happened. Do **not** sprinkle `ReserveNotWired` on every live path.

Do **not** auto-call either wiring function inside first bond.  
Do **not** auto-finalize inside either wiring function.  
Do **not** call `completeReserveClaim` from `completeReserveBondNft`.

---

## 6. Repo changes (normative)

Each of the four `*DETFRepo.sol` files:

**Append to `Storage` (end only):**

```solidity
address bondNftVaultPkg;
address rebasingClaimTokenPkg;
```

**Append to `CoreInit` (end only):**

```solidity
address bondNftVaultPkg;
address rebasingClaimTokenPkg;
```

`_initializeCore` writes those two fields. `bondNftVault`, `rebasingClaimToken`, `detfNftId`, `feeRecipientNftId` are written as **zero** at `postDeploy`.

**Add** (errors live on the instance interface; Repo reverts those same names, declared once on the Repo library as today does for `ReserveNotLive`):

```solidity
function _setBondNft(
    IDETFNFTVault bondNftVault_,
    uint256 detfNftId_,
    uint256 feeRecipientNftId_
) internal {
    Storage storage s = _layoutStruct();
    if (address(s.bondNftVault) != address(0)) revert ReserveBondNftAlreadyWired();
    if (address(bondNftVault_) == address(0)) revert ZeroAddress();
    s.bondNftVault = bondNftVault_;
    s.detfNftId = detfNftId_;
    s.feeRecipientNftId = feeRecipientNftId_;
}

function _setClaim(IRebasingClaimToken rebasingClaimToken_) internal {
    Storage storage s = _layoutStruct();
    if (address(s.bondNftVault) == address(0)) revert ReserveBondNftNotWired();
    if (address(s.rebasingClaimToken) != address(0)) revert ReserveClaimAlreadyWired();
    if (address(rebasingClaimToken_) == address(0)) revert ZeroAddress();
    s.rebasingClaimToken = rebasingClaimToken_;
}
```

If a family Repo does not already declare `ZeroAddress`, add it there (one spelling). Instance targets revert the wiring errors; do **not** invent a second spelling (`AlreadyWired` vs `ReserveAlreadyWired`). There is **no** `ReserveAlreadyWired` error. The two step-specific already-wired errors replace it.

`_initializeCore` already-initialized sentinel stays as today (`standardExchangeVault` on CP; `pairToken0` on Orbital; family equivalent on Weighted / Quad). It is **not** a wiring sentinel.

---

## 7. Shared staged-init helper (locked)

**Path (create):** `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookStagedInitLib.sol`

**License / pragma:** `SPDX-License-Identifier: BSL-1.1`, `pragma solidity ^0.8.0;`

**Shape:** `library UniswapV4DetfHookStagedInitLib`. `internal` functions. No `console2`. No storage.

Exact signatures (no overloads):

```solidity
function productTokensCp(IUniswapV4SingleStandardExchangeDETF detf)
    internal view returns (address[] memory tokens);
function productTokensOrbital(IUniswapV4StandardExchangeOrbitalDETF detf)
    internal view returns (address[] memory tokens);
function productTokensWeighted(IUniswapV4StandardExchangeWeightedDETF detf)
    internal view returns (address[] memory tokens);
function productTokensQuad(IUniswapV4StandardExchangeCurveQuadStableDETF detf)
    internal view returns (address[] memory tokens);

function openProductPair(address hook, address tokenA, address tokenB) internal;
function finalizeHook(address hook) internal;

function ensureReserveReadyCp(IUniswapV4SingleStandardExchangeDETF detf) internal;
function ensureReserveReadyOrbital(IUniswapV4StandardExchangeOrbitalDETF detf) internal;
function ensureReserveReadyWeighted(IUniswapV4StandardExchangeWeightedDETF detf) internal;
function ensureReserveReadyQuad(IUniswapV4StandardExchangeCurveQuadStableDETF detf) internal;
```

`openProductPair` is `IUniswapV4HookStagedPairInit(hook).deployPair(tokenA, tokenB)`.  
`finalizeHook` is `IUniswapV4HookStagedPairInit(hook).finalizeInitialization()`.

`ensureReserveReady*` is **TestBase / hermetic-spec only**:

1. `hook = detf.reserveHook()`; require `hook != address(0)`.  
2. `tokens = productTokens*(detf)`.  
3. For `i = 0 .. n-1`, for `j = i+1 .. n-1`: `openProductPair(hook, tokens[i], tokens[j])`.  
4. `finalizeHook(hook)`.  
5. `detf.completeReserveBondNft()`.  
6. `detf.completeReserveClaim()`.

Private `_openAllPairs(address hook, address[] memory tokens)` is allowed so the four bundles stay thin.

Broadcast scripts **must not** call `ensureReserveReady*`. They **must**:

```text
tokens = productTokens*(detf)
hook = detf.reserveHook()
for each i < j:
    broadcast openProductPair(hook, tokens[i], tokens[j])   # one TX
broadcast finalizeHook(hook)
broadcast detf.completeReserveBondNft()
broadcast detf.completeReserveClaim()
```

`deployPair` is idempotent skip-if-live. Calling `ensureReserveReady*` twice: `finalizeHook` reverts `InitializationAlreadyFinalized` or unmatched finalize after the first success. TestBase `setUp` calls the bundle **once**. Do not swallow that revert.

### 7.1 Token lists (complete)

| Family | `tokens` construction |
|--------|------------------------|
| CP | `[address(detf), detf.pairToken()]` — length 2, one `deployPair` |
| Orbital | Binding-order length 3. `detfIdx = detf.detfBindingIndex()`. Remaining indices ascending: first → `pairToken0`, second → `pairToken1`. `tokens[detfIdx] = address(detf)`. Same remap as mine-nonce PRD §4.1 Orbital |
| Weighted | `m = detf.m()`, `n = m+1`. `tokens[0] = address(detf)`, `tokens[i+1] = detf.pairToken(i)`. Insertion-sort by address ascending (same loop as mine-nonce PRD §4.1 Weighted). Every unordered pair among the `n` addresses is a product door |
| Quad | `tokens[0] = address(detf)`, `tokens[1..3] = detf.pairToken(0..2)`. Insertion-sort by address. Six unordered pairs |

Do **not** call hook `token0` / `token1` / `tokens(i)` to build this list: those production views are unmatched until finalize.

### 7.2 Forbidden helper paths

- Inlining a second token-list / door-loop algorithm in a TestBase or script (scripts may `i<j` over `productTokens*` only)  
- Calling hook `PairPoolLib.ensure*PairPools`  
- Calling `PoolManager.initialize` from DETF or the helper  
- DETF wrappers `deployReservePair` / `finalizeReserve`  
- Putting the helper on the DETF diamond as a facet  
- Broadcast scripts calling `ensureReserveReady*`  

---

## 8. Tests (locked)

### 8.1 Gold TestBases

All four `TestBase_UniswapV4*DETF.sol`:

1. `_deployDetfInstance` stays premine + `deployVault(args, nonce)` + `require(detf == predicted)`. It does **not** open doors or wire.  
2. Default `setUp` after `_deployDetfInstance` calls the matching `UniswapV4DetfHookStagedInitLib.ensureReserveReady*`. Existing first-bond / mint suites keep a **wired inert** instance.  
3. Add `_deployDetfBootstrapOnly(args)` = today’s `_deployDetfInstance` body (deploy only). Used by the staged-init spec.  
4. `_assertInert` stays `!isReserveLive`.  
5. Add `_assertWired`: `isReserveWired()`, `isReserveHookFinalized()`, `bondNftVault() != 0`, `rebasingClaimToken() != 0`, `!isReserveLive()`.  
6. `_assertLive` still requires live + hook + bond NFT.

### 8.2 Shared staged-init spec

**One file:** `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4SeDetfStagedHookInit.t.sol`

Four contracts, each inheriting the matching gold TestBase. Each contract **overrides `setUp`** so it deploys packages / SEs / terms but does **not** call `ensureReserveReady*` (use `_deployDetfBootstrapOnly(_defaultDetfArgs())` for the instance). Each contract implements:

| Unit | Law |
|------|-----|
| A — deploy only | `reserveHook() != 0`. `!isReserveHookFinalized()`. `!isReserveWired()`. `bondNftVault() == 0`. `rebasingClaimToken() == 0`. `!isReserveLive()`. Hook `isInitializationFinalized()` returns **false** (selector exists). Hook `decimals()` / `depositSingle` / `token0` revert (unmatched). |
| B — bond-NFT step before finalize reverts | `vm.prank(stranger); vm.expectRevert(ReserveHookNotFinalized.selector); detf.completeReserveBondNft();`. Claim before bond NFT: `vm.expectRevert(ReserveBondNftNotWired.selector); detf.completeReserveClaim();`. |
| C — doors + finalize, not wired | Open pairs + `finalizeHook` only (use lib granular fns, not `ensureReserveReady*`). Then `isReserveHookFinalized()`. `!isReserveWired()`. `IERC20Metadata(hook).decimals()` succeeds. First bond reverts `ReserveNotWired`. |
| D — two-step wiring + first bond | Stranger calls `completeReserveBondNft` then `completeReserveClaim`. After bond NFT only: `bondNftVault() != 0`, `!isReserveWired()`, first bond reverts `ReserveNotWired`. After claim: `_assertWired`. Second bond-NFT step reverts `ReserveBondNftAlreadyWired`. Second claim step reverts `ReserveClaimAlreadyWired`. Then existing `_firstBond` succeeds and `_assertLive`. |
| E — pair count | After doors, **before** finalize: CP 1 live product pair; Orbital 3; Quad 6; Weighted \(\binom{n}{2}\) with default TestBase `n`. Use hook `isPairPoolLive`. After finalize those views are unmatched. |

`indexedexManager.deployVault` stays forbidden except the existing mine-nonce Unit C.

Adversarial / core / price-movement suites must compile and pass hermetic via default `setUp` (wired). No SUT mocks.

### 8.3 Existing tests to grep-and-fix

Any test that, **after `deployVault` alone** (not via default `setUp`), asserts `bondNftVault() != 0` or calls first bond without `ensureReserveReady*` must change.

Known shape: four gold TestBases; family `*_Deploy.t.sol` / `*_Core.t.sol` / `*_Adversarial.t.sol`. If a deploy spec currently expects children at the end of `deployVault`, rewrite it to Unit A + Unit D semantics.

---

## 9. Scripts (locked)

Every in-repo Foundry script that deploys these four DETFs **must**, after `I*DETDFPkg.deployVault(args, nonce)` and `require(deployed == predicted)`, follow the **per-transaction** sequence in §7 (one `deployPair` broadcast per unordered pair, then finalize, then `completeReserveBondNft`, then `completeReserveClaim`). Then first-bond / enrich as today.

Scripts **must not** call `ensureReserveReady*`. They **must** use `productTokens*` so they do not inline a second sort / binding remap.

| Tree | Files |
|------|--------|
| `scripts/foundry/anvil_robinhood_testnet/` | `Stage_06_LeafDETFs.sol`, `Stage_07_NestDETFs.sol`, `Stage_08_FeeSink.sol` (every `deployNvdaS` / `deployNvdaSmhO` / `deployIdxQ` / `deployDolQ` / `deployBetaO` / `deployIdxWrap` / `deploy*` that returns a Uni V4 SE DETF) |
| `scripts/foundry/anvil_robinhood_main/` | `Script_13_DeployInertDemos.s.sol`, `Script_18_DeployChirInstance.s.sol` |
| `scripts/foundry/anvil_robinhood_fee_detf/` | `Script_09_DeployChirInstance.s.sol` |

Anvil leaf scripts that today do `deployVault` + first-bond in one broadcast **must** insert the per-door TXs + finalize + two wiring TXs **between** those two. They may keep one **script file** that sends **several** transactions. Do **not** fold doors or wiring back into `deployVault`. Do **not** bundle all doors into one broadcast call.

README for `anvil_robinhood_testnet`: replace “hook postDeploy inits doors” / “DETF deploy leaves a ready reserve” with the sequence in §4.

---

## 10. Docs the plan agent must patch (same change set)

- This PRD stays SoT.  
- Four family `*_PRD.md` § Deploy / postDeploy spirit: hook `postDeploy` does **not** init doors; DETF `postDeploy` deploys bootstrap hook only; scripts use `productTokens*` + one TX per door + two wiring fns; TestBase `setUp` may use `ensureReserveReady*`. Point here.  
- Four family `*_IMPLEMENTATION_AND_TEST_PLAN.md`: same sentences.  
- `docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md` and its impl plan if they claim DETF deploy inits hook doors or children.  
- `scripts/foundry/anvil_robinhood_testnet/README.md`.  
- Hook staged-init family PRDs: **do not rewrite**. A one-line “DETF follow-on: this file” pointer is allowed, not required.

Do not rewrite hook factory PRDs.

---

## 11. Explicit non-goals

- Staging DETF **facets** (DETF diamond still ships its full ABI at deploy)  
- DETF wrappers for `deployPair` / `finalizeInitialization`  
- Changing hook staged-init law or `IUniswapV4HookStagedPairInit`  
- Changing bond NFT `decimals()` at init  
- Hard-coding hook LP decimals as `18` to deploy children before finalize  
- Auto-wire inside first bond  
- Auto-finalize inside either wiring function  
- Auto-claim inside `completeReserveBondNft`  
- A `bool reserveWired` Repo flag  
- Attaching an already-deployed child on retry / CREATE2-predict-and-reuse  
- Putting child-package addresses in `PkgArgs`  
- Adding wiring surface to shared `IDetf`  
- Dual / Balancer Quad / standalone-hook DETFs  
- `via_ir`  
- Changing mint/bond/threshold/expansion product behavior  
- Public broadcast / 46630 live deploy as a required DoD (scripts must **compile** and send the per-door TX sequence)

---

## 12. Definition of done (requirements)

- Four `I*DETF` interfaces expose D10 functions + the two events + the five errors. Four `I*DETDFPkg` interfaces unchanged. Shared `IDetf` unchanged.  
- Four packages: `postDeploy` matches D6; CP `_initPool` gone; no `deployPair` / `finalizeInitialization` from any DETF DFPkg.  
- Four Repos: D15 append + `_setBondNft` + `_setClaim`.  
- `completeReserveBondNft` / `completeReserveClaim` deploy the same children today’s `postDeploy` deployed, after hook finalize, as two steps.  
- `UniswapV4DetfHookStagedInitLib` exists with granular fns + TestBase-only `ensureReserveReady*`.  
- Four gold TestBases: default `setUp` wires via `ensureReserveReady*`; `_deployDetfInstance` does not.  
- Shared spec §8.2 exists and covers units A–E on all four families.  
- Listed scripts compile and send one TX per door + finalize + two wiring TXs. `rg ensureReserveReady` under `scripts/` is clean.  
- Family PRDs + Anvil README patched.  
- Hermetic tests for the four families green (plan names the exact `forge test --match-path` set).  
- `rg _initPool` under the four DETF package directories: clean.  
- `rg deployPair` under those four DETF **package** `.sol` files: clean (helper + tests + scripts may match).  
- `rg completeReserveWiring` in this repo: clean.

---

## 13. Open questions

None. Locked from 2026-08-18 reviews:

1. Stage DETF too (not same-tx doors+finalize in `postDeploy`).  
2. Four existing Uni V4 SE DETFs only.  
3. Callers use hook `IUniswapV4HookStagedPairInit`; DETF adds thin views + wiring mutators.  
4. Scripts send **one TX per door**; `ensureReserveReady*` is TestBase-only.  
5. Two-step wiring: `completeReserveBondNft` then `completeReserveClaim`. First bond requires both.  
6. New surface on the four family `I*DETF` interfaces only. Shared `IDetf` unchanged.

---

## 14. Revision log

| Date | Rev | Change |
|------|-----|--------|
| 2026-08-18 | **v0.1** | First draft from code review + locked Q&A: DETF deploy = hook bootstrap only; doors/finalize on hook ABI; `completeReserveWiring` for children; shared `UniswapV4DetfHookStagedInitLib`; four families only. |
| 2026-08-18 | **v0.2** | Split helper for per-door broadcasts; replace one-shot `completeReserveWiring` with `completeReserveBondNft` + `completeReserveClaim`; keep surface off `IDetf`. |

**Next:** implement from `UNISWAP_V4_SE_DETF_STAGED_HOOK_INIT_IMPLEMENTATION_AND_TEST_PLAN.md` after this PRD is accepted (no new product choices).
