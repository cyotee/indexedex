# Struct + Audit Readiness Review — A-detf-core

- **Date:** 2026-08-08
- **Agent/role:** area subagent (pilot) — A-detf-core
- **Scope paths:** `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex/contracts/vaults/detf/common/**`
- **Out of scope notes:** Family-local DETF targets under `contracts/vaults/detf/protocols/**` not fully reviewed; cited only as **out-of-area references** for C3 clone detection (`ComposedStableCommonDetfBondNFTVault*`). Interfaces under `contracts/interfaces/**` cited for `Position` / product ABI only. No `forge` gas measurement run in this pass.
- **Status:** COMPLETE
- **Commands / tools used:**
  - `rg -n --glob '*.sol' 'struct\s+\w+' contracts/vaults/detf/common`
  - `rg` consumers: `HarvestParams|HarvestResult|RedeemParams|LockInfo|AccrualInput|RebasingDetfTokenFacets`
  - `rg` brand/flags: `RICHIR|CHIR|detfNFTSold|pretransferred|buildRICHIR`
  - Read: PRD §§2–3, 6–7, 14; all `*.sol` under allowlist (bondNft, claimToken, core, factory, inventory)

---

## 1. Executive summary

### Top 5 opportunities
1. **Shrink / delete dead stack-relief members** on `HarvestParams` (`tokenId`, `recipient`) and `RedeemParams` (`tokenId`) — never read on pure helpers; hot-path memory waste.
2. **C3 share** `DETFNFTVaultService` types with family clones (`ComposedStableCommonDetfBondNFTVaultService` is an exact copy) — delete duplicate stack-relief structs out-of-area after this canonicalization.
3. **C5 collapse** harvest path: call `DETFBondNFTMathLib._calcHarvestRewards` + `_executeHarvestTransfer` with scalars; drop `HarvestParams`/`HarvestResult` if stack stays green (likely — Target already uses block scopes).
4. **C6 pack** `DETFNFTVaultRepo.Storage.decimalOffset` + `detfNFTSold` into one slot (pre-launch; migration-risk labeled).
5. **Rename** `buildRICHIRPkgInit` → role-safe factory helper; align SVG/comments away from product brands.

### Top 5 audit concerns
1. **`detfNFTSold` flag never enforced** — `error DETFNFTSold` exists; `markDETFNFTSold` sets storage; `addToDETFNFT` / sell / mint paths never check it (docs claim freeze after sell).
2. **Rebasing claim `redeem` / exchange path does not unwind via DETF** — NatSpec/product text promises BPT unwind; implementation only `rateAsset.safeTransfer` from pre-funded balance (solvency / rate drift).
3. **`pretransferred=true` skips balance proof** on claim token (`_secureTokenTransfer`) — anyone can burn claim shares already held by the diamond and drain `rateAsset`.
4. **`reallocateDetfNftRewards` lacks `nonReentrant`** while other money paths lock; harvest does ERC20 transfer after debt update.
5. **Facet surface gaps** — Target exposes `lockInfoOf` / `rewardPerShares` / `detfNFTSold` / claim `updateRedemptionRate` but facets omit selectors → diamond-unreachable API.

### Struct counts
| Metric | Count |
|--------|------:|
| Structs defined in allowlist | **14** |
| Recommended remove (entire type) | **2–3** (`HarvestParams` and/or `HarvestResult`; possibly merge `LockInfo` later) |
| Recommended merge / shrink | **4–5** (member shrink, C3 share, C6 pack, AccrualInput keep-separate) |
| Recommended do-not-collapse | **7** (see §5) |

---

## 2. Struct inventory

| Name (file + struct) | Kind | Visibility surface | Approx members | Write sites | Read sites | Lifetime | Notes |
|----------------------|------|--------------------|----------------|-------------|------------|----------|-------|
| `DETFNFTVaultService.HarvestParams` — `bondNft/DETFNFTVaultService.sol:26-32` | stack-relief | library / internal-only | 5: `uint256 tokenId`, `address recipient`, `uint256 effectiveShares`, `uint256 rewardPerShares`, `uint256 paidPerShare` | `DETFNFTVaultTarget._harvestRewardsInternal` ~225-231 | `_calcHarvestRewards` only uses 3 fields | single call | **tokenId/recipient never read** |
| `DETFNFTVaultService.HarvestResult` — `Service.sol:35-38` | result | library | 2: `uint256 rewards`, `bool hasRewards` | `_calcHarvestRewards` | Target harvest | single call | `hasRewards ≡ rewards > 0` |
| `DETFNFTVaultService.RedeemParams` — `Service.sol:41-46` | stack-relief | library | 4: `tokenId`, `recipient`, `caller`, `detf` | `redeemPosition` ~151-153 | `_validateRedeemCaller` (not `tokenId`) | single call | **tokenId unused** |
| `DETFNFTVaultCommon.LockInfo` — `Common.sol:43-48` | api / result | abstract contract public view return | 4: `sharesAwarded`, `rewardPerShare`, `bonusPercentage`, `unlockTime` | `lockInfoOf` fills | external `lockInfoOf` | view | Overlaps `IDETFNFTVault.Position` (OOS interface); naming of `bonusPercentage` vs multiplier |
| `DETFNFTVaultRepo.Storage` — `Repo.sol:70-101` | storage | library diamond storage | 8 scalars + 5 mappings: detf, lpToken, rewardToken, lastRewardTokenBalance, totalShares, rewardPerShares, decimalOffset, maps…, nextTokenId, detfNFTId, detfNFTSold | init / position / rewards | all bond NFT ops | permanent | Slot waste: lone `uint8` + lone `bool` |
| `IDETFNFTVaultDFPkg.PkgInit` — `DFPkg.sol:43-50` | api | interface | 6 facets/oracle/registry | constructor / factory | DFPkg ctor | deploy | Correctly on **interface** |
| `IDETFNFTVaultDFPkg.PkgArgs` — `DFPkg.sol:52-65` | api | interface | 7: name, symbol, detf, lpToken, rewardToken, decimalOffset, owner | `deployVault` encode | `initAccount` | deploy | Correctly on **interface** |
| `IRebasingClaimTokenDFPkg.PkgInit` — `claimToken/…DFPkg.sol:37-43` | api | interface | 5 facets + diamondFactory | factory | ctor | deploy | On interface ✓ |
| `IRebasingClaimTokenDFPkg.PkgArgs` — `DFPkg.sol:45-58` | api | interface | 6: detf, nftVault, rateAsset, detfNFTId, owner, optionalSalt | `deployToken` | `initAccount` + salt hash | deploy | Comments say “WETH” / “CHIR” |
| `RebasingClaimTokenRepo.Storage` — `Repo.sol:49-73` | storage | library | 7: detf, nftVault, rateAsset, detfNFTId, totalShares, sharesOf, cachedRedemptionRate, lastRateUpdateBlock | init / mint-burn / rate | Target | permanent | Slot name still `…richir` |
| `DetfComponentFactoryService.RebasingDetfTokenFacets` — `factory/DetfComponentFactoryService.sol:24-30` | other / deploy-helper | library | 5 IFacet | test/deploy builders (also OOS clones) | `buildRebasingDetfTokenPkgInit` | deploy | Mirrors family factory structs |
| `DETFNaturalExpansionLib.AccrualInput` — `core/DETFNaturalExpansionLib.sol:89-100` | execution-context | library pure API | 10: flags + continuous premium-closure params | family Commons (OOS) | `computeExpansionMint` | pure call | Continuous / catch-up model |
| `DETFEpochNaturalExpansionLib.AccrualInput` — `core/DETFEpochNaturalExpansionLib.sol:17-27` | execution-context | library pure API | 9: flags + epoch params | Uni V4 family / tests | `previewPending…` / `computeRealization` | pure call | **Different formula** — do not merge with continuous |

**No structs** in: `DETFMintSplitLib`, `DETFThresholdPolicy` (enum only), `DETFBondLifecycleLib`, `DETFProtocolCompoundLib`, `DETFUsageFeeLib`, `DETFPreviewLib`, `DETFBondNFTMathLib`, `DETFSafeTransferLib`, `DETFBalancerScaleLib`, inventory interfaces (empty marker interfaces), facets (no local structs).

---

## 3. Redundant members

| ID | Severity | Category | Title | Evidence (path:lines) | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------------------|--------|-----------------|---------|------------|--------------------|------------|----------|
| S-A-detf-core-001 | Medium | struct-redundant | `HarvestParams.tokenId` never read | `DETFNFTVaultService.sol:26-32,56-59`; fill `Target.sol:225-231` | Extra MSTORE on every harvest/claim/redeem/sell | Remove field; pass only math inputs | positive | low | No (internal) | medium | Yes |
| S-A-detf-core-002 | Medium | struct-redundant | `HarvestParams.recipient` never read | same; execute uses separate `recipient_` arg `Service.sol:65-76` | Same as above | Remove; keep recipient only on transfer call | positive | low | No | medium | Yes |
| S-A-detf-core-003 | Low | struct-redundant | `HarvestResult.hasRewards` duplicates `rewards > 0` | `Service.sol:35-38,56-59`; `MathLib._calcHarvestRewards:85-96` | Extra bool store/check | Return `uint256` only; `if (rewards==0)` | neutral/positive | low | No | medium | No |
| S-A-detf-core-004 | Medium | struct-redundant | `RedeemParams.tokenId` never read | `Service.sol:41-46,97-99`; build `Target.sol:151-153` | Dead field on redeem hot path | Drop `tokenId` from struct | positive | low | No | high | Yes |
| S-A-detf-core-005 | Low | struct-redundant | Nested copy of harvest fields already available on `layoutStruct_` | `Target.sol:220-243` | Struct filled from storage then mostly discarded | Prefer C5: call math lib with 3 locals | positive | med | No | medium | Yes (with compile gate) |
| S-A-detf-core-006 | Low | gas / clarity | `LockInfo.bonusPercentage` sometimes stores full `bonusMultiplier` (1e18-scale), not % | `Target.lockInfoOf:350-354` | Auditor/integrator confusion; not unused | Rename to `bonusMultiplier` or always store bps; align with `Position` | n/a | n/a | Yes if public ABI | high | No (ABI note) |
| S-A-detf-core-007 | Nit | struct-redundant | `PkgArgs.optionalSalt` only participates via full-args hash | `RebasingClaimTokenDFPkg.sol:57,108` | Not dead; salt component | Keep; document role in `calcSalt` | n/a | n/a | No | high | No |

---

## 4. Collapse / consolidation proposals

### C1 — Merge sibling param structs

| ID | Severity | Category | Title | Evidence | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------|--------|----------------|---------|------------|--------------------|------------|----------|
| S-A-detf-core-010 | Low | struct-collapse | Do **not** merge `HarvestParams`+`RedeemParams` | Different fields/lifetimes | Merging would load unused fields on each path | Prefer shrink (001–004) over merge | negative if merged fat | med | No | medium | No |

**Sketch (shrink, not merge):**

```text
// Before HarvestParams: tokenId, recipient, effectiveShares, rewardPerShares, paidPerShare
// After:
struct HarvestCalc { uint256 effectiveShares; uint256 rewardPerShares; uint256 paidPerShare; }
// or no struct (C5)
// RedeemParams: recipient, caller, detf  (drop tokenId)
```

### C2 — Flat execution context

| ID | Severity | Category | Title | Evidence | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------|--------|----------------|---------|------------|--------------------|------------|----------|
| S-A-detf-core-011 | Nit | struct-collapse | No deep nested graph on harvest/redeem | `Target.sol:138-192,220-243` | Already flat + block scopes | Keep pattern; avoid new Params/State/Cache towers | n/a | n/a | No | high | No |

### C3 — Share library structs across families

| ID | Severity | Category | Title | Evidence | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------|--------|----------------|---------|------------|--------------------|------------|----------|
| S-A-detf-core-012 | Medium | struct-collapse | Identical `HarvestParams`/`HarvestResult`/`RedeemParams` cloned in ComposedStable service | **In-area:** `DETFNFTVaultService.sol:26-46`; **OOS clone:** `…/ComposedStableCommonDetfBondNFTVaultService.sol:12-30` | Bytecode + maintenance ×N; auditor graph noise | Make common service **canonical**; delete family copies in implement phase | positive (bytecode) | low | No if internal-only | high | Yes (shared types first) |
| S-A-detf-core-013 | Low | struct-collapse | `LockInfo` cloned in ComposedStable Common | **In-area:** `Common.sol:43-48`; OOS clone exists | Same | Share or use interface-level view type | neutral | low | Maybe ABI | medium | Later |
| S-A-detf-core-014 | Low | struct-collapse | `RebasingDetfTokenFacets` duplicated in family factory services | `DetfComponentFactoryService.sol:24-30` + OOS `ComposedStable…_Component_FactoryService` | Deploy-only | Prefer common factory types | neutral | low | No | medium | Later |

### C4 — Split mega-struct

| ID | Severity | Category | Title | Evidence | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------|--------|----------------|---------|------------|--------------------|------------|----------|
| S-A-detf-core-015 | Nit | struct-split | Storage not loaded as mega-context | Repos use field accessors | OK | No C4 needed | n/a | n/a | No | high | No |

### C5 — Remove struct; helper + scopes

| ID | Severity | Category | Title | Evidence | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------|--------|----------------|---------|------------|--------------------|------------|----------|
| S-A-detf-core-016 | Medium | struct-collapse | Remove harvest stack-relief structs if stack-safe | `Target._harvestRewardsInternal:220-243`; math already pure 3-arg `BondNFTMathLib:85-96` | Fewer memory copies on claim/redeem/sell/compound harvest | Inline: `(rewards, ok) = MathLib._calc…(eff, rps, paid)`; then transfer | positive (hot path) | med — must `forge build` | No | medium | Yes with compile gate |
| S-A-detf-core-017 | Low | struct-collapse | Remove `RedeemParams` → 3-arg validate | `MathLib._validateRedeemCaller:118-132` already scalar | Same | Call math lib from Target block scope | positive | low | No | high | Yes |

### C6 — Storage packing only

| ID | Severity | Category | Title | Evidence | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------|--------|----------------|---------|------------|--------------------|------------|----------|
| S-A-detf-core-018 | Low | gas | Pack `decimalOffset` (uint8) with `detfNFTSold` (bool) [and optionally reserved bytes] | `Repo.Storage:70-101` — `decimalOffset` alone then maps then `detfNFTSold` at end | Save ≥1 cold slot on init/reads of both | Reorder: place both small fields adjacent **before** mappings; pre-launch tests for layout | positive (cold SLOAD) | low | **Yes storage** — migration risk labeled | medium | Later (test gate) |
| S-A-detf-core-019 | Nit | gas | Claim token `lastRateUpdateBlock` stays uint256 | `RebasingClaimTokenRepo.Storage:68-72` | No free pack partner without changing semantics | Leave | n/a | n/a | No | high | No |

### Dual AccrualInput (do not C1-merge)

| ID | Severity | Category | Title | Evidence | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------|--------|----------------|---------|------------|--------------------|------------|----------|
| S-A-detf-core-020 | Nit | clarity | Same name `AccrualInput` in two libs | `DETFNaturalExpansionLib.sol:89-100` vs `DETFEpochNaturalExpansionLib.sol:17-27` | Name collision for auditors | Keep separate; optional rename `ContinuousAccrualInput` / `EpochAccrualInput` | neutral | low | No | high | No |

**Affected functions (collapse shortlist):** `_harvestRewardsInternal`, `claimRewards`, `redeemPosition`, `sellPositionToDetfNft`, `reallocateDetfNftRewards`, `redeemPosition` validate block, family clones of same (implement phase).

---

## 5. Do-not-collapse list

| Struct | Reason to keep separate |
|--------|-------------------------|
| `IDETFNFTVaultDFPkg.PkgInit` / `PkgArgs` | Public deploy ABI; already on interface; registry encode |
| `IRebasingClaimTokenDFPkg.PkgInit` / `PkgArgs` | Public deploy ABI; salt includes full args |
| `DETFNFTVaultRepo.Storage` | Diamond storage layout; pack only via explicit C6 + tests |
| `RebasingClaimTokenRepo.Storage` | Same |
| `DETFNaturalExpansionLib.AccrualInput` vs `DETFEpochNaturalExpansionLib.AccrualInput` | Different product formulas (continuous vs whole-epoch); merging fields would load unused cold semantics |
| `IDETFNFTVault.Position` (interface OOS) vs in-area `LockInfo` | Different public views; Position is canonical inventory; LockInfo is convenience view — merge only with deliberate ABI plan |
| `DetfComponentFactoryService.RebasingDetfTokenFacets` | Deploy-only; collapsing into PkgInit is optional but PkgInit is interface-owned for another package |

---

## 6. Gas notes

### Hot paths in this area
| Path | Entry | Struct touch |
|------|-------|--------------|
| Bond create | `createPosition` / `WithEffectiveBase` | none (locals) |
| Claim rewards / harvest | `claimRewards` → `_harvestRewardsInternal` | HarvestParams/Result |
| Redeem bond | `redeemPosition` | RedeemParams + harvest |
| Sell → protocol NFT | `sellPositionToDetfNft` | harvest |
| Protocol reward realloc | `reallocateDetfNftRewards` | harvest |
| Claim token redeem / exchangeIn/Out | `redeem`, `exchangeIn`, `exchangeOut` | no memory structs; storage + math |
| Expansion pure | family calls AccrualInput | pure, warm when hooked to user txs |

### Hermetic measurement ideas (implement phase; no invented %)
```bash
# Baseline compile (default profile — never via_ir)
forge build

# Prefer existing hermetic DETF bond / claim tests under test/foundry/spec/vaults/detf/
forge snapshot --match-path 'test/foundry/spec/vaults/detf/common/**'
forge test --gas-report --match-path 'test/foundry/spec/vaults/detf/common/**'

# Targeted once tests named:
# forge snapshot --match-test test_.*claimRewards|redeemPosition|sellPosition|Harvest
# forge snapshot --match-test test_.*RebasingClaim|redeem|exchangeIn
# forge snapshot --match-test test_.*NaturalExpansion|EpochNaturalExpansion
```

Fork only if hermetic cannot fund rateAsset/BPT inventory for claim redeem solvency paths.

### Directional gas (static only)
- Removing unused Harvest/Redeem members / C5 inline: **positive**, hot path, confidence **medium** until snapshot.
- C3 delete family clones: **positive** deploy bytecode / size, confidence **high** (duplicate code).
- C6 packing: **positive** on cold multi-field loads, confidence **medium**, storage break.

---

## 7. Audit readiness findings

| ID | Severity | Category | Title | Evidence (path:lines) | Impact | Recommendation | Gas dir | Stack risk | ABI/Storage break? | Confidence | Fix now? |
|----|----------|----------|-------|----------------------|--------|-----------------|---------|------------|--------------------|------------|----------|
| A-A-detf-core-001 | High | economic / invariants | `detfNFTSold` never gated; `DETFNFTSold` error dead | Flag set `Target.sol:312-319`; storage `Repo.sol:99-100`; error `Common.sol:37`; **no** `revert DETFNFTSold` / checks in `addToDETFNFT:253-261` or sell; interface claims freeze `IDETFNFTVault.sol:236-238` | Product invariant “no more LP after protocol NFT sold” unenforced | Check `detfNFTSold` in `addToDETFNFT` (and any post-sale add); tests for negative path | n/a | n/a | No | high | Yes |
| A-A-detf-core-002 | High | economic | Claim redeem transfers pre-funded `rateAsset` only — no DETF BPT unwind | NatSpec `IRebasingClaimToken.sol:138-143` vs impl `Target._executeRedeem:494-516` | Solvency if rate rises / rateAsset underfunded; doc↔code mismatch for auditors | Align code to product (unwind via DETF) **or** rewrite NatSpec + fund model; add solvency tests | n/a | n/a | Maybe ABI | high | Yes (design) |
| A-A-detf-core-003 | High | access / tokens | `pretransferred=true` trusts amount without balance delta | `_secureTokenTransfer:518-531`; `redeem:317-327`; `exchangeIn:351-352`; `exchangeOut:387-391` | Steal claim shares / rateAsset already on contract | Match BasicVault / RocketPool pattern: require `balanceOf(this)` delta ≥ amount when pretransferred; or restrict to owner/router | n/a | n/a | No | high | Yes |
| A-A-detf-core-004 | Medium | reentrancy | `reallocateDetfNftRewards` missing `nonReentrant` | `Target.sol:482-499` vs `claimRewards:201` | Reentrancy via malicious reward token mid-harvest | Add same lock as claim/redeem | n/a | n/a | No | medium | Yes |
| A-A-detf-core-005 | Medium | access / deploy | Facet omits selectors for live Target views | `DETFNFTVaultFacet.facetFuncs:42-69` missing `lockInfoOf`, `rewardPerShares`, `detfNFTSold`; Target has them `343-393` | Diamond users cannot call documented views; dead code / partial API | Add selectors or remove dead Target entrypoints | n/a | n/a | ABI facet surface | high | Yes |
| A-A-detf-core-006 | Medium | access / deploy | Claim facet omits `updateRedemptionRate` | Target `463-472`; Facet `48-79` | Public rate refresh not diamond-exposed | Add selector or drop function | n/a | n/a | ABI | high | Yes |
| A-A-detf-core-007 | Medium | economic | Rate uses `position.originalShares` as BPT amount into `previewExchangeIn` | `_calcCurrentRedemptionRate:545-557` | Wrong if originalShares ≠ reserve LP units after conversion/decimalOffset | Document invariant or convert via bond vault `convertToAssets` | n/a | n/a | No | medium | Yes (verify) |
| A-A-detf-core-008 | Medium | naming | Brand names in production common code | `buildRICHIRPkgInit` `DetfComponentFactoryService.sol:64`; SVG `Pending CHIR` `Repo.sol:48`; comments CHIR `ClaimToken Repo/DFPkg`; slot `…richir` `Repo.sol:36` | Violates DETF role-name law; audit noise | Rename helpers/comments/SVG to role names; storage **slot string** change is layout-breaking if already deployed — pre-launch only | n/a | n/a | Slot change = storage | high | Rename yes; slot later |
| A-A-detf-core-009 | Medium | test-gap | No allowlist-local hermetic suite exercise for sold-flag + pretransfer + facet wiring called out | Area has unit tests for expansion libs under `test/.../common/core/` but sold-flag enforcement / claim pretransfer not evidenced in this pass | Gaps hide 001–003 | Production-first tests on DFPkg path: mark sold then add fails; pretransfer without deposit reverts | n/a | n/a | No | medium | Yes |
| A-A-detf-core-010 | Low | tokens / errors | String `require` on transfer and share burn | `DETFSafeTransferLib.sol:10`; `ClaimTokenRepo._burnShares:247` | Harder decoding / gas vs custom errors | Custom errors consistent with `IDetfErrors` | n/a | n/a | No | high | No |
| A-A-detf-core-011 | Low | errors | Wrong error reuse on zero address | `transferHeldToken` NFT `Target:470` uses `NotAuthorized(address(0))`; claim `412` uses `ZeroAmount` | Confusing failure modes | Dedicated `ZeroAddress` / invalid arg errors | n/a | n/a | No | high | No |
| A-A-detf-core-012 | Low | access | `burnShares` with `pretransferred` burns from `address(this)` without pull | `Target:421-453` owner-only | Owner (DETF) can burn any claim held by package — intentional if orchestrated; document | Keep owner-only; balance-check pattern | n/a | n/a | No | medium | No |
| A-A-detf-core-013 | Low | storage | STORAGE_SLOT string encodes brand `richir` | `RebasingClaimTokenRepo.sol:36` | Pre-launch renames break layout | Rename only if no external deploy; test layout | n/a | n/a | **Yes storage** | high | Pre-launch decision |
| A-A-detf-core-014 | Low | reentrancy / CEI | Harvest: update paid + balance then transfer | `Service._executeHarvestTransfer:71-76` | Standard ERC20 reentry risk if non-standard token | Prefer nonReentrant on all harvest entrypoints (partially done) | n/a | n/a | No | medium | With 004 |
| A-A-detf-core-015 | Low | NatSpec / events | `createPosition` emits `NewLock` not interface `PositionCreated` | `Target:115` vs `IDETFNFTVault:255-262` | Indexer/event mismatch | Emit interface event or update interface | n/a | n/a | Event ABI | medium | Later |
| A-A-detf-core-016 | Nit | dead code | Commented SVG `abi.encodePacked` block | `Repo.sol:563-576` | Noise | Delete | n/a | n/a | No | high | No |
| A-A-detf-core-017 | Nit | deploy | Claim DFPkg stores `ERC20_FACET` immutables but facetCuts omit ERC20 facet | `DFPkg:77-88,123-128` | Confusing; ERC20 may be in claim facet | Drop unused immutable or document intentional | n/a | n/a | No | medium | No |
| A-A-detf-core-018 | Nit | inventory | Empty marker interfaces | `IDetfSelfNftInventoryPolicy`, `IDetfNftInventoryPolicy` | Fine for typing | Keep | n/a | n/a | No | high | No |

**PkgInit/PkgArgs placement:** correctly on **interfaces** (`IDETFNFTVaultDFPkg`, `IRebasingClaimTokenDFPkg`) — **no finding**.

**Deploy path:** DFPkgs use registry/create3 factories; no `new` facet deploy in common path — OK.

---

## 8. Suggested implementation order (for later plan)

1. **Audit fixes first (no via_ir):** A-001 sold-flag gate + tests; A-003 pretransfer balance proof; A-002 product decision on redeem funding/unwind; A-004 nonReentrant on realloc.
2. **Facet ABI completeness:** A-005 / A-006 selectors.
3. **Struct hygiene (hermetic gas):** S-001/002/004 shrink; S-016/017 C5 try-compile; snapshot harvest/redeem.
4. **C3 share service types** with family clone deletion (orchestrator coordinates A-detf-balancer).
5. **Naming cleanup** A-008 (code/comments/SVG); defer storage slot string unless greenfield.
6. **C6 packing** S-018 only after layout tests; label migration risk (PRD L4).
7. **Nits:** events, custom errors, dead comments.

---

## 9. Open questions

1. **Product law for `detfNFTSold`:** After mark, is `addToDETFNFT` permanently forbidden, or only user sells? Interface says freeze; code allows ongoing compound BPT credits — clarify before gating compound path.
2. **Claim redeem funding model:** Is rebasing claim a pure “claim on pre-funded rateAsset inventory” or must each redeem unwind `reservePool` via DETF? A-002 blocks audit READY until answered.
3. **Is `LockInfo` still required** given `positionOf` / `getPosition`? If unused by frontend, delete from Target+facet plan.
4. **Hermetic tests covering pretransfer and sold-flag** — confirm existence under broader DETF suites (this area pass did not exhaust `test/**`).
5. **Out-of-area ownership of ComposedStable bond NFT clone** — implement C3 in balancer area after common types land.

---

**Done criteria:** COMPLETE — inventory of all 14 allowlist structs, redundant-member analysis, C1–C6 proposals with gas/stack/ABI/confidence, do-not-collapse list, gas notes with hermetic measurement ideas, and audit findings with path:line evidence. No contracts edited. No `via_ir` recommended.
