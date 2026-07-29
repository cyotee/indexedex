# Protocol Naming Rename — Implementation and Test Plan

| Field | Value |
|-------|--------|
| **Status** | Ready for execution |
| **Date** | 2026-07-28 |
| **PRD** | [`PROTOCOL_NAMING_RENAME_PRD.md`](./PROTOCOL_NAMING_RENAME_PRD.md) (**LOCKED** D1–D5) |
| **Inventory** | [`PROTOCOL_NAMING_INVENTORY_REPORT.md`](./PROTOCOL_NAMING_INVENTORY_REPORT.md) (blast-radius evidence; PRD wins on names) |
| **Product** | Cross-family DETF naming hygiene (rename + path move; **no** economics / threshold / route changes) |
| **Delivery** | Work and commit on the **current branch** (no multi-PR stack required). Logical waves below are **commit checkpoints**, not separate PR gates. |

---

## 0. Plan locks (from owner Q&A + PRD §16 defaults)

| ID | Topic | Decision |
|----|-------|----------|
| **P1** | Delivery packaging | **Single branch, sequential commits.** Do not require multi-PR stack. Group commits by wave for reviewability. |
| **P2** | Dead Protocol DETF scripts | **Archive** under `scripts/archive/` (preserve history). |
| **P3** | Wave 5 Done matrix | **Full family gold + all DETF adversarial suites required.** Fork tests not required for Done. |
| **P4** | Historical Threshold Modes `*EXEC_AGENT_PROMPT*.md` | **Allowlist** — do not rewrite bodies. Live law only: AGENTS.md, Threshold Modes PRD/PROGRESS, program-complete note. |
| **P5** | Mint-split field name | **`inventoryDetf` / `inventoryDetfOut` / `inventoryAmount_`** (PRD §6.3) |
| **P6** | `IDetfNftInventoryPolicy` | **Keep** renamed empty marker (used by composed-stable bond NFT vault) |
| **P7** | Casing | Storage **`detfNftId`**; keep existing external **`detfNFTId()`** getters |
| **P8** | Wave F frontend | **Out of Done** — optional follow-on only |

**Do not re-open PRD D1–D5.** Rename tables in PRD §6 are normative.

---

## 1. Goals and non-goals

### Goals

1. Shared typed surface: `IProtocolDETF*` → `IDetf` / `IDetfErrors` / `IDetfProxy`.
2. Inventory / bond / claim APIs: detf-owned NFT language (`sellPositionToDetfNft`, `detf()`, `detfNftId`, …).
3. Mint-split: `protocolDetf` → `inventoryDetf` (behavior unchanged).
4. Move shared packages to `contracts/vaults/detf/bondNft/` and `…/claimToken/`.
5. Archive dead Protocol DETF scripts; fix live scripts that only need type renames.
6. Update AGENTS.md + Threshold Modes live docs so agents stop treating Protocol DETF as a live family.
7. **Behavior freeze + storage layout freeze** (field rename-in-place only).

### Non-goals

- Threshold Policy/Open law, mint/burn math, fee ratios, new routes
- Merge `IDETF` into `IDetf`
- `contracts/protocols/**`, DualLiquidity under `vaults/protocol/uniswap/`
- Frontend `protocolDetfs()` / tokenlists (Wave F)
- Dual ABI shims or storage migration for already-deployed diamonds
- Drive-by refactors

---

## 2. Normative rename quick-ref

| Cluster | Current → New |
|---------|----------------|
| A | `IProtocolDETF` → `IDetf`; `IProtocolDETFErrors` → `IDetfErrors`; `IProtocolDETFProxy` → `IDetfProxy`; `NotProtocolDETF` → `NotDetf` |
| B | `sellPositionToProtocol` → `sellPositionToDetfNft`; `reallocateProtocolRewards` → `reallocateDetfNftRewards`; `ProtocolRewardsReallocated` → `DetfNftRewardsReallocated`; `protocolDETF()` → `detf()`; `setProtocolDETF` → `setDetf`; `protocolNftId` → `detfNftId`; `_protocolDETF` → `_detf`; `_tryInitProtocolNft` → `_tryInitDetfNft`; lifecycle helpers per PRD §6.2 |
| C | `protocolDetf` → `inventoryDetf`; `protocolDetfOut` → `inventoryDetfOut`; `protocolAmount_` → `inventoryAmount_`; `_accrueMintProtocolInventory` → `_accrueMintInventory` |
| D | Path moves §3 |
| E | Archive Protocol DETF scripts |
| G | Docs / AGENTS |

**Do not regress:** `initializeDETFNFT`, `addToDETFNFT`, `detfNFTId()`, `DETFNFTRestricted`, role names (`rateAsset`, `pairToken`, …).

**Do not confuse:** `IDetf` (shared diamond surface) vs `IDETF` (narrow pricing helper — **unchanged**).

---

## 3. Wave 2 file-by-file `git mv` list

### 3.1 Production packages (Cluster D)

```bash
mkdir -p contracts/vaults/detf/bondNft contracts/vaults/detf/claimToken

# Bond NFT vault package
git mv contracts/vaults/protocol/DETFNFTVaultCommon.sol   contracts/vaults/detf/bondNft/
git mv contracts/vaults/protocol/DETFNFTVaultDFPkg.sol    contracts/vaults/detf/bondNft/
git mv contracts/vaults/protocol/DETFNFTVaultFacet.sol    contracts/vaults/detf/bondNft/
git mv contracts/vaults/protocol/DETFNFTVaultRepo.sol     contracts/vaults/detf/bondNft/
git mv contracts/vaults/protocol/DETFNFTVaultService.sol  contracts/vaults/detf/bondNft/
git mv contracts/vaults/protocol/DETFNFTVaultTarget.sol   contracts/vaults/detf/bondNft/

# Rebasing claim token package
git mv contracts/vaults/protocol/RebasingClaimTokenDFPkg.sol  contracts/vaults/detf/claimToken/
git mv contracts/vaults/protocol/RebasingClaimTokenFacet.sol   contracts/vaults/detf/claimToken/
git mv contracts/vaults/protocol/RebasingClaimTokenRepo.sol    contracts/vaults/detf/claimToken/
git mv contracts/vaults/protocol/RebasingClaimTokenTarget.sol  contracts/vaults/detf/claimToken/
```

**Leave in place (DualLiquidity — do not touch):**

```text
contracts/vaults/protocol/uniswap/crossVersion/**
```

After move, `contracts/vaults/protocol/` may contain only `uniswap/` (DualLiquidity). **Never** `git mv contracts/vaults/protocol` wholesale.

### 3.2 Interfaces / inventory file renames (Waves 1–2)

```bash
git mv contracts/interfaces/IProtocolDETF.sol            contracts/interfaces/IDetf.sol
git mv contracts/interfaces/IProtocolDETFErrors.sol      contracts/interfaces/IDetfErrors.sol
git mv contracts/interfaces/proxies/IProtocolDETFProxy.sol \
       contracts/interfaces/proxies/IDetfProxy.sol
git mv contracts/vaults/detf/inventory/IDetfProtocolNftInventoryPolicy.sol \
       contracts/vaults/detf/inventory/IDetfNftInventoryPolicy.sol
```

Inside renamed files: rename types/errors/functions per §2; update NatSpec titles (“shared DETF surface”, not “Protocol DETF”).

### 3.3 Tests path move (Wave 2 / Wave 5)

```bash
mkdir -p test/foundry/spec/vaults/detf/bondNft test/foundry/spec/vaults/detf/claimToken

git mv test/foundry/spec/protocol/vaults/protocol/DETFNFTVaultDFPkg_Deploy.t.sol \
       test/foundry/spec/vaults/detf/bondNft/
git mv test/foundry/spec/vaults/protocol/DETFNFTVault.t.sol \
       test/foundry/spec/vaults/detf/bondNft/

git mv test/foundry/spec/protocol/vaults/protocol/RebasingClaimTokenDFPkg_Deploy.t.sol \
       test/foundry/spec/vaults/detf/claimToken/
git mv test/foundry/spec/vaults/protocol/RebasingClaimTokenRedemption.t.sol \
       test/foundry/spec/vaults/detf/claimToken/
```

Remove empty dirs if left behind. DualLiquidity fork bases under `test/foundry/fork/**/vaults/protocol/uniswap/**` stay put.

### 3.4 Dead / rename-only tests

| Artifact | Action |
|----------|--------|
| `test/foundry/debug/ProtocolDETF_SyntheticPrice_Debug.t.sol` | Delete **or** archive under `test/foundry/debug/archive/` if still useful; if kept, rename file + types so live `rg` gates pass |
| `test/foundry/fork/sepolia/protocol/EthereumProtocolDETFSyntheticPrice_SuperSimFork.t.sol` | Same — dead product fork stub; **not** a Done gate. Prefer delete/archive with note |

### 3.5 Import update roots after path move

Any import of `contracts/vaults/protocol/DETFNFTVault*` or `…/RebasingClaimToken*` must become:

```text
contracts/vaults/detf/bondNft/...
contracts/vaults/detf/claimToken/...
```

**Known import sites (production):**

| Area | Files |
|------|-------|
| Reusable factories | `DetfComponentFactoryService`, `DetfFacetFactoryService`, `DetfPkgFactoryService`, `IDetfSelfNftInventoryDFPkg` |
| Family DFPkgs / TestBases | Single SE, Single Vault, MultiVault weighted, MixedBuffer, Composed stable common |
| Family factory services | `SingleVaultDetf_Component_FactoryService`, composed stable component / bond NFT pkg factory services |
| Seigniorage | `SeigniorageBondNFTTarget` / `SeigniorageBondNFTCommon` (errors + `protocolDETF` param rename only) |

Use after moves:

```bash
rg -n 'contracts/vaults/protocol/(DETFNFT|RebasingClaim)' -g '*.sol'
# expect empty
```

---

## 4. Wave execution order

Commit on the **current branch** after each wave (or sub-wave) once its verification block is green. Prefer small commits: “types”, “path move”, “libs”, “family X”, “tests”, “scripts”, “docs”.

### Wave 0 — Baseline (no rename)

1. `forge build` green on branch tip.
2. Spot-check inventory still accurate:

```bash
rg -l 'IProtocolDETF' -g '*.sol' | wc -l   # expect ~58 as of 2026-07-28
rg -n 'sellPositionToProtocol' -g '*.sol' contracts/ | head
```

3. DualLiquidity allowlist (do not move):

```bash
find contracts/vaults/protocol/uniswap -type f | sort
```

4. Optional: note CREATE3 salt address churn under greenfield (PRD §7.4) — no salt-stability hacks.

**Exit:** documented baseline; no code renames yet.

---

### Wave 1 — Canonical types (Cluster A)

**Order:** rename files via `git mv` (§3.2) → rewrite contents → fan out references.

| Step | Work |
|------|------|
| 1.1 | `IDetf.sol`, `IDetfErrors.sol`, `IDetfProxy.sol` — types, NatSpec, `NotDetf` |
| 1.2 | `ISingleVaultDetf is IDetf` |
| 1.3 | `IDETFNFTVault` / `IRebasingClaimToken` — **type** references to `IDetf` (API renames can wait Wave 2 if needed for compile; preferred: types in W1, external APIs in W2 same commit series) |
| 1.4 | `DETFCommon` → `IDetfErrors` |
| 1.5 | `SeigniorageBondNFTTarget` import `IDetfErrors` |
| 1.6 | Remove any leftover `IProtocolDETF*` paths once zero refs |

**Suggested first compile slice:** interfaces + `DETFCommon` + `SingleVaultDetfInfo*` before whole monorepo.

**Verify:**

```bash
forge build
rg -n 'IProtocolDETF' -g '*.sol' contracts/interfaces contracts/vaults/detf/DETFCommon.sol
# expect empty after W1 complete for those paths
```

**Commit message sketch:** `refactor(detf): rename IProtocolDETF → IDetf (Cluster A)`

---

### Wave 2 — Package path move + package inventory APIs (Clusters D + B partial)

| Step | Work |
|------|------|
| 2.1 | `git mv` bondNft + claimToken packages (§3.1) |
| 2.2 | Inside packages: `detf()` / `setDetf` / `_detf()` / `sellPositionToDetfNft` / `reallocateDetfNftRewards` / `DetfNftRewardsReallocated` / storage field renames **order-preserving** |
| 2.3 | Update `IDETFNFTVault`, `IRebasingClaimToken`, inventory policies if not done in W1 |
| 2.4 | Update reusable `Detf*FactoryService` import paths |
| 2.5 | Update all family DFPkg / TestBase imports of old `vaults/protocol/` paths |
| 2.6 | Move package tests (§3.3); update imports |
| 2.7 | `IDetfNftInventoryPolicy` rename; `IComposedStableCommonDetfBondNFTVault` inheritance |

**Storage checklist (every repo `Storage` struct touched):**

- [ ] Field **order** unchanged
- [ ] Field **types** same width (address → `IDetf` is fine)
- [ ] No packing cleanup / field inserts

**Verify:**

```bash
forge build
forge test --match-path test/foundry/spec/vaults/detf/bondNft/ -vv
forge test --match-path test/foundry/spec/vaults/detf/claimToken/ -vv
rg -n 'contracts/vaults/protocol/(DETFNFT|RebasingClaim)' -g '*.sol'
# empty
```

**Commit:** `refactor(detf): move DETFNFTVault/RebasingClaimToken under detf/{bondNft,claimToken}`

---

### Wave 3 — Core libs + inventory policies (Clusters B/C core)

| File | Renames |
|------|---------|
| `detf/core/DETFBondLifecycleLib.sol` | `_sellPositionToDetfNft`, `_collectDetfNftRewards`, `_addReservePoolBptToDetfNft`, `detfNftId_` params |
| `detf/core/DETFBondNFTMathLib.sol` | `protocolDETF_` → `detf_` (or `detfDiamond_`) in `_validateRedeemCaller` |
| `detf/core/DETFMintSplitLib.sol` | `protocolAmount_` → `inventoryAmount_` |
| `detf/inventory/IDetfBondInventoryPolicy.sol` | method names Cluster B |
| `detf/inventory/IDetfNftInventoryPolicy.sol` | already renamed file |
| siblings | no Protocol product names left |

**Verify:** `forge build`

**Commit:** `refactor(detf): rename inventory/mint-split helpers in core libs`

---

### Wave 4 — Family production code + seigniorage

Apply Clusters A–C consistently to every live family. No behavior changes.

| Family | Path | Typical touch points |
|--------|------|----------------------|
| Single SE | `detf/standardExchange/single/` | Repo (`protocolNftId`→`detfNftId`), Common mint-split, BondingTarget, ExchangeInTarget/Facet, DFPkg `_tryInitDetfNft` |
| Single Vault | `detf/composed/single/` | Facets/targets/repo/DFPkg/factory service; IFacet selector tables in **tests** (Wave 5) |
| Multi-vault weighted | `detf/composed/multi-vault-weighted/` | Repo, Common, Bonding, ExchangeIn, DFPkg |
| Mixed-buffer multi-vault stable | `detf/composed/stable/mixedBuffer/` | same pattern |
| Composed stable common | `detf/composed/stable/common/` | Bond NFT vault package (local), RebasingDETFToken*, ExchangeIn, FactoryService, TestBases, `_accrueMintInventory` |
| Seigniorage | `vaults/seigniorage/nft/` | `IDetfErrors`, `protocolDETF` storage/param → `detf` (layout-preserving) |

**Family loop (per package):**

1. Rename identifiers + imports  
2. `forge build`  
3. Quick smoke: one deploy or IFacet compile of that family if build alone is too coarse  

**Commit:** one commit per family **or** one `refactor(detf): family production rename (Clusters B/C)` if diff is pure mechanical.

---

### Wave 5 — Tests (full gold + adversarial)

#### 5.1 Mechanical updates

- All `test/foundry/spec/vaults/detf/**`: imports, `expectRevert` selectors, facet metadata tables (`IProtocolDETF` → `IDetf` selectors)
- Adversarial suites calling `sellPositionToProtocol` → `sellPositionToDetfNft`
- Bond NFT / claim tests after path move
- Delete/archive dead `ProtocolDETF_*` debug/fork stubs (§3.4)

#### 5.2 Required verification matrix (Done gate — P3)

Run in order; all must pass:

```bash
# 0. Build
forge build

# 1. Core policy
forge test --match-path test/foundry/spec/vaults/detf/core/ -vv

# 2. Shared packages after move
forge test --match-path test/foundry/spec/vaults/detf/bondNft/ -vv
forge test --match-path test/foundry/spec/vaults/detf/claimToken/ -vv

# 3. Full DETF hermetic tree (includes gold + fuzz/invariant under tree)
forge test --match-path test/foundry/spec/vaults/detf/ -vv

# 4. Adversarial suites (explicit; also covered by #3 if under tree — still list for clarity)
forge test --match-path test/foundry/spec/vaults/detf/standardExchange/single/adversarial/ -vv
forge test --match-path test/foundry/spec/vaults/detf/composed/single/adversarial/ -vv
forge test --match-path test/foundry/spec/vaults/detf/composed/stable/common/adversarial/ -vv
forge test --match-path test/foundry/spec/vaults/detf/composed/multi-vault-weighted/adversarial/ -vv
```

**Family gold paths (must be green as part of #3):**

| Family | Path |
|--------|------|
| Single SE | `test/foundry/spec/vaults/detf/standardExchange/single/` |
| Single Vault | `test/foundry/spec/vaults/detf/composed/single/` |
| Multi-vault weighted | `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/` |
| Mixed-buffer | `test/foundry/spec/vaults/detf/composed/stable/mixedBuffer/` |
| Composed stable common | `test/foundry/spec/vaults/detf/composed/stable/common/` |

**Not required for Done:**

- `test/foundry/fork/**` (including DualLiquidity matrix / SuperSim Protocol DETF stubs)
- Frontend e2e

**If a family has no adversarial directory** (e.g. mixedBuffer): gold suite under its path is enough; do not invent new adversarial suites in this program.

**Commit:** `test(detf): update specs/adversarial for IDetf naming`

---

### Wave 6 — Scripts (Cluster E)

#### 6.1 Archive (P2)

```bash
mkdir -p scripts/archive/foundry/protocol-detf

# Per-env Script_16
git mv scripts/foundry/anvil_base_main/Script_16_DeployProtocolDETF.s.sol \
       scripts/archive/foundry/protocol-detf/anvil_base_main/
# … same for anvil_sepolia, public_sepolia/base, public_sepolia/ethereum

# Supersim ProtocolDetf stack
git mv scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol \
       scripts/archive/foundry/protocol-detf/supersim/
git mv scripts/foundry/supersim/Script_26_TestProtocolDetfReserveBridge.s.sol \
       scripts/archive/foundry/protocol-detf/supersim/
git mv scripts/foundry/supersim/base/Script_DeployProtocolDetfMinimal.s.sol \
       scripts/archive/foundry/protocol-detf/supersim/base/
git mv scripts/foundry/supersim/ethereum/Script_DeployProtocolDetfMinimal.s.sol \
       scripts/archive/foundry/protocol-detf/supersim/ethereum/
git mv scripts/foundry/supersim/shared/Script_ConfigureProtocolDetfBridge.s.sol \
       scripts/archive/foundry/protocol-detf/supersim/shared/
```

Add `scripts/archive/foundry/protocol-detf/README.md`: one paragraph — archived dead Protocol DETF product deploy paths; not for live ops; names intentionally old.

#### 6.2 Rewrite live scripts

| Script | Action |
|--------|--------|
| `scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3Overlay.s.sol` | Update imports/types to `IDetf` if still needed for modern families; if only Protocol DETF, archive instead |
| Any other live script still importing `IProtocolDETF` | Same |

**Do not rename:** `Script_03_DeployBaseProtocols`, `Demo_02_External_Protocols` (DEX “protocols”).

**Verify:**

```bash
rg -n 'IProtocolDETF|ProtocolDETF|setProtocolDETF' scripts/foundry
# empty (archive is under scripts/archive/ — allow old names there)
```

**Commit:** `chore(scripts): archive Protocol DETF deploys; fix live type imports`

---

### Wave 7 — Docs + agent law (Cluster G)

| Doc | Change |
|-----|--------|
| `AGENTS.md` / `Agents.md` | F6 surface = `IDetf`; path map bondNft/claimToken under detf; anti-pattern table; drop live `IProtocolDETF` / `vaults/protocol` as home of bond/claim |
| `DETF_Threshold_Modes_PRD.md` | F6 naming → `IDetf`; historical note “shipped under IProtocolDETF” |
| `DETF_Threshold_Modes_PROGRESS.md` | Same naming alignment for status tables |
| `DETF_Threshold_Modes_PROGRAM_COMPLETE_AND_OPTIONAL_FOLLOWONS.md` | F6 row → `IDetf` |
| Family PRDs citing Protocol DETF as behavioral reference | One-liner: “former Protocol DETF / now shared `IDetf` surface” — **do not** re-open product design |
| Inventory report header | Status: superseded for **decisions** by rename PRD; keep as evidence |
| This plan + rename PRD | Remain normative for execution |

**Do not bulk-edit** historical `DETF_Threshold_Modes_P*_EXEC_AGENT_PROMPT.md` (P4 allowlist).

**Commit:** `docs(detf): IDetf naming in AGENTS and Threshold Modes live docs`

---

### Wave F — Frontend (optional; not Done)

Track later under `frontend/ROADMAP.md` if desired:

- `protocolDetfs()`, tokenlist `vaults/protocolDetf`, portfolio `kind === 'protocol'`

No work required for this plan’s Definition of Done.

---

## 5. Grep gates and allowlists

### 5.1 Must be empty (live code)

```bash
# Product types
rg -n 'IProtocolDETF' -g '*.sol' contracts/ test/foundry
# expect empty (except allowlisted archived test paths if any remain)

# API / error cluster
rg -n 'sellPositionToProtocol|setProtocolDETF|reallocateProtocolRewards|NotProtocolDETF' \
  -g '*.sol' contracts/

# Inventory naming under detf surface
rg -n 'protocolDetf|protocolNftId|protocolDETF' -g '*.sol' \
  contracts/vaults/detf contracts/interfaces \
  contracts/vaults/detf/bondNft contracts/vaults/detf/claimToken
# prefer empty; English comments only if glossary-compliant

# Old package paths
rg -n 'contracts/vaults/protocol/(DETFNFT|RebasingClaim)' -g '*.sol'
# empty

# Live scripts
rg -n 'IProtocolDETF|ProtocolDETF|setProtocolDETF' scripts/foundry
# empty
```

Also scan seigniorage:

```bash
rg -n 'IProtocolDETF|protocolDETF|NotProtocolDETF' -g '*.sol' contracts/vaults/seigniorage
# empty after Wave 4
```

### 5.2 Grep allowlist (may still say “Protocol DETF” / `IProtocolDETF`)

| Path pattern | Reason |
|--------------|--------|
| `contracts/vaults/detf/PROTOCOL_NAMING_RENAME_PRD.md` | Normative rename law; documents old names |
| `contracts/vaults/detf/PROTOCOL_NAMING_INVENTORY_REPORT.md` | Historical blast radius |
| `contracts/vaults/detf/PROTOCOL_NAMING_RENAME_IMPLEMENTATION_AND_TEST_PLAN.md` | This plan |
| `contracts/vaults/detf/DETF_Threshold_Modes_P*_EXEC_AGENT_PROMPT.md` | Historical agent prompts (P4) |
| Other `DETF_Threshold_Modes_*PLAN*AGENT*` historical prompts | Same |
| `scripts/archive/**` | Archived dead product scripts |
| Root historical `PROGRESS.md` / archived tasks (if any) | Non-blocker (PRD §11.2) |
| Family PRDs **only** in “formerly Protocol DETF” one-liners | Explicit historical reference |
| Threshold Modes PRD/PROGRESS **only** in “formerly / shipped as IProtocolDETF” notes | Historical |

**Not allowlisted:** production `.sol`, live `scripts/foundry/**`, AGENTS.md as a live mandate of `IProtocolDETF`.

Optional stricter check after Wave 7:

```bash
rg -n 'IProtocolDETF' contracts/ --glob '!**/PROTOCOL_NAMING*.md' \
  --glob '!**/*EXEC_AGENT_PROMPT.md' --glob '!**/*_PLAN_AGENT_PROMPT.md' \
  --glob '!**/*P0_EXEC*' --glob '!**/*P1_*' --glob '!**/*P2_*' \
  --glob '!**/*P3_*' --glob '!**/*P4_*' --glob '!**/*P5*' --glob '!**/*P6_*' \
  --glob '!**/*P7_*'
# Remaining hits should be intentional “formerly” notes only
```

---

## 6. Storage layout and ABI checklist (PR review)

Use on every commit that touches repos / facets:

| Check | Rule |
|-------|------|
| Struct field order | Diff shows renames only — **no** reorder / insert / delete mid-struct |
| Types | `IProtocolDETF` → `IDetf` is address-sized type rename only |
| External selectors | Old names **gone** (no wrappers) — greenfield |
| `facetFuncs` / IFacet tests | Match new selectors in same change set |
| `interfaceId` assertions | Update if hard-coded for `IProtocolDETF` |
| CREATE3 salts | May change facet/package addresses for **new** deploys — expected; re-broadcast local stacks if needed |
| Behavior | No fee/threshold/route/math changes |

---

## 7. Behavior freeze (regression intent)

After rename, these must still hold (covered by existing family gold + adversarial):

- Policy vs Open synthetic mint/burn gates
- Seigniorage split ratios (field names only change)
- Bond lock min revert / max clamp
- Sell bond → detf-owned NFT → claim mint
- `claimLiquidity` / `previewClaimLiquidity` semantics
- Auth / reentrancy (`NotDetf` name only; same call sites)
- Preview == execution on closed-form routes

**Forbidden:** drive-by refactors, fee changes, new routes, threshold default changes, new mocks of SUT.

---

## 8. Suggested commit sequence (current branch)

| # | Wave | Commit theme |
|---|------|----------------|
| 1 | 0 | (optional) chore: baseline note only if needed |
| 2 | 1 | `refactor(detf): IProtocolDETF → IDetf types` |
| 3 | 2 | `refactor(detf): bondNft/claimToken path move + package APIs` |
| 4 | 3 | `refactor(detf): core lib inventory/mint-split renames` |
| 5 | 4 | `refactor(detf): family + seigniorage production renames` (split by family if large) |
| 6 | 5 | `test(detf): gold + adversarial for renamed surface` |
| 7 | 6 | `chore(scripts): archive Protocol DETF deploys` |
| 8 | 7 | `docs(detf): AGENTS + Threshold Modes IDetf law` |

No multi-PR requirement (P1). Squash only if the operator prefers a single landing commit after local green.

---

## 9. Definition of Done

All of the following:

1. Grep gates §5.1 pass (live code empty of old product identifiers).
2. Shared packages live only under:
   - `contracts/vaults/detf/bondNft/`
   - `contracts/vaults/detf/claimToken/`
3. DualLiquidity still under `contracts/vaults/protocol/uniswap/**` (untouched).
4. `forge build` succeeds.
5. Wave 5 matrix (§5.2) fully green — **full detf spec tree + all adversarial suites**.
6. Protocol DETF scripts archived under `scripts/archive/`; live `scripts/foundry` free of old product types.
7. AGENTS.md: F6 = `IDetf`; bond/claim paths under detf; no live mandate of `IProtocolDETF`.
8. Threshold Modes live docs updated; historical exec prompts allowlisted only.
9. No new SUT mocks; production-first testing unchanged.
10. Storage layout rules followed (rename-in-place only).

**Non-blockers:** Wave F frontend; DualLiquidity path; archive scripts with old names; historical root plans/tasks.

---

## 10. Risks (execution-focused)

| Risk | Mitigation |
|------|------------|
| Missed selector in IFacet / `facetFuncs` | Wave order; full detf + adversarial matrix; `rg` gates |
| Accidental Storage reorder | PR checklist §6; review struct diffs only for renames |
| DualLiquidity moved | Wave 0 allowlist; never wholesale `git mv` of `vaults/protocol` |
| CREATE3 address churn | Expected greenfield; Wave 6 cleanup; re-broadcast local |
| `IDetf` vs `IDETF` confusion | NatSpec on both; AGENTS glossary |
| Seigniorage left on old errors | Explicit Wave 4 seigniorage step |
| Huge single commit | Prefer §8 commit sequence even on one branch |

---

## 11. Agent execution notes

1. Read PRD §6 rename tables before editing; do not invent alternate names.
2. Prefer `git mv` to preserve history.
3. After each wave: build + that wave’s tests before starting the next.
4. Production-first: no mocks of DETF diamonds, DFPkgs, manager, registry, fee oracle.
5. When grepping, ignore DualLiquidity and `contracts/protocols/**` false positives.
6. If capacity forces intermediate WIP: still land with `forge build` green; **Done** requires full §5.2 matrix.

---

## 12. Living progress log

| Date | Note |
|------|------|
| 2026-07-28 | Plan written from LOCKED PRD + inventory. Plan locks P1–P8 from owner Q&A (single branch commits; archive scripts; full gold+adversarial; historical prompt allowlist). |

---

## 13. Document control

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-07-28 | Initial implementation + test plan for Protocol naming rename |

**Normative for execution order and Done gates.** PRD remains normative for naming choices; inventory remains evidence base.

---

*End of implementation plan.*
