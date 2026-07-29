# PRD: Remove Protocol DETF product naming from shared DETF surfaces

| Field | Value |
|-------|--------|
| **Status** | **LOCKED** (product decisions) — ready for implementation plan / execution |
| **Date** | 2026-07-28 |
| **Inventory basis** | [`PROTOCOL_NAMING_INVENTORY_REPORT.md`](./PROTOCOL_NAMING_INVENTORY_REPORT.md) |
| **Product** | Cross-family DETF naming hygiene (not a new vault family) |
| **Decisions locked with owner** | 2026-07-28 (see §2) |

---

## 1. Problem

The **Protocol DETF** product is deprecated and its concrete packages are gone. What remains is naming that still treats “Protocol” as the canonical DETF product brand:

1. Shared typed surface: `IProtocolDETF`, `IProtocolDETFErrors`, `IProtocolDETFProxy`
2. Inventory / bond / claim APIs coined in that era: `sellPositionToProtocol`, `protocolDETF()`, `protocolNftId`, mint-split `protocolDetf`, …
3. Layout: shared bond NFT + claim packages still live under `contracts/vaults/protocol/` next to unrelated DualLiquidity code
4. Residual deploy scripts and tests named `*ProtocolDETF*`

This pollutes structure and mental model for **every live DETF family** that reuses the common machinery. Agents and humans keep re-importing a dead product name into new work (e.g. Threshold Modes F6 still documents `IProtocolDETF`).

**This PRD does not change product economics, threshold law, mint/burn routes, or bond math.** It is a **rename + path move** program with layout-preserving storage renames and greenfield ABI breaks.

---

## 2. Locked decisions (owner)

| # | Question | Decision |
|---|----------|----------|
| D1 | Canonical DETF product interface name | **`IDetf`** (replaces `IProtocolDETF`) |
| D2 | Scope depth | **Full clean**: product types + inventory APIs + mint-split fields + move shared bond/claim packages out of `vaults/protocol/` |
| D3 | Domain vocabulary | **detf-owned / detfNft** (not “protocol-owned” in identifiers) |
| D4 | Delivery scope | **Contracts + tests + residual Protocol DETF scripts**. Frontend / tokenlists = **optional follow-on** (not required for Done) |
| D5 | ABI / diamonds | **Greenfield**: breaking selector renames OK; **no** dual-surface shims; redeploy packages as needed |

---

## 3. Goals

1. **Zero product-brand pollution** in production Solidity type names for the shared DETF surface (`IProtocolDETF*` gone).
2. **Role-consistent inventory language**: identifiers speak detf-owned NFT / inventory, not Protocol DETF.
3. **Path hygiene**: bond NFT vault + rebasing claim packages live under `contracts/vaults/detf/**`, not under a deprecated product directory name.
4. **Cross-family consistency**: Single SE, Single Vault, Multi-vault weighted, Mixed-buffer multi-vault stable, Composed stable common, and shared `DETFNFTVault` / `RebasingClaimToken` all use the new names.
5. **Preserve behavior and storage layout** (slot order and packing unchanged); only names and import paths change.
6. **Remove or archive dead Protocol DETF deploy scripts** so new agents do not run them as live paths.
7. **Update AGENTS.md / Threshold Modes docs** so F6 and deploy maps no longer mandate `IProtocolDETF`.

---

## 4. Non-goals

| Non-goal | Reason |
|----------|--------|
| Change threshold Policy/Open law | Already shipped; rename only |
| Change mint/burn/bond math or fee split ratios | Behavior freeze |
| Merge `IDETF` (pricing helper) into `IDetf` | Different surfaces; keep both |
| Rename `contracts/protocols/**` (DEX/lending) | Unrelated “protocol” |
| Rename DualLiquidity under `vaults/protocol/uniswap/crossVersion/` | Different product; co-located path only |
| Frontend `protocolDetfs()`, tokenlist `vaults/protocolDetf`, portfolio kind | Follow-on wave F (optional) |
| Temporary deprecated aliases / dual ABI | Explicitly rejected (D5) |
| Storage-slot migration for already-deployed diamonds | Greenfield; new deploys only |
| Delete seigniorage family or DualLiquidity | Out of scope |

---

## 5. Glossary (normative)

| Term | Meaning after this PRD |
|------|-------------------------|
| **Protocol DETF** | Deprecated product. Do not use in type names, paths for shared DETF packages, or new NatSpec titles. Historical docs may say “formerly Protocol DETF.” |
| **`IDetf`** | Canonical shared DETF diamond surface (mint/bond/threshold/claimLiquidity/…). Formerly `IProtocolDETF`. |
| **`IDETF`** | Narrow rebasing/pricing helper interface — **unchanged** by this PRD. Do not confuse with `IDetf`. |
| **detf-owned NFT / `detfNftId`** | Bond-NFT vault token id that holds DETF reserve inventory (sold user bonds + seigniorage inventory). Formerly “protocol NFT” / `protocolNftId`. Aligns with existing getter `detfNFTId()` where present. |
| **inventory DETF (`inventoryDetf`)** | Seigniorage mint-split leg that accrues to detf-owned inventory (not user). Formerly `protocolDetf` / `protocolDetfOut`. |
| **DEX / lending protocol** | External integrations under `contracts/protocols/**` — **not** renamed. |
| **DualLiquidity / protocol package path** | Unrelated product still under `vaults/protocol/uniswap/…` — **not** moved by this PRD. |

**English NatSpec:** Prefer “detf-owned NFT,” “DETF inventory,” “this DETF diamond.” Avoid “Protocol DETF.” Occasional plain-English “the protocol” meaning IndexedEx as a system is fine when it cannot be read as the product name.

---

## 6. Locked rename tables

### 6.1 Product types and errors (Cluster A)

| Current | New | File path change |
|---------|-----|------------------|
| `IProtocolDETF` | `IDetf` | `contracts/interfaces/IProtocolDETF.sol` → `contracts/interfaces/IDetf.sol` |
| `IProtocolDETFErrors` | `IDetfErrors` | `…/IProtocolDETFErrors.sol` → `…/IDetfErrors.sol` |
| `IProtocolDETFProxy` | `IDetfProxy` | `…/proxies/IProtocolDETFProxy.sol` → `…/proxies/IDetfProxy.sol` |
| `error NotProtocolDETF(address)` | `error NotDetf(address)` | inside `IDetfErrors` |
| `ISingleVaultDetf is IProtocolDETF` | `ISingleVaultDetf is IDetf` | `ISingleVaultDetf.sol` only |
| NatSpec “Protocol DETF” on those files | “DETF” / “shared DETF surface” | same |

**Threshold Modes F6:** docs that say `IProtocolDETF` become `IDetf`. No product-law change.

### 6.2 Inventory / bond / claim APIs (Cluster B)

| Current | New | Notes |
|---------|-----|-------|
| `sellPositionToProtocol` | `sellPositionToDetfNft` | External — **selector break** |
| `reallocateProtocolRewards` | `reallocateDetfNftRewards` | External — selector break |
| `event ProtocolRewardsReallocated` | `event DetfNftRewardsReallocated` | Indexer break (no frontend Done gate) |
| `IDetfProtocolNftInventoryPolicy` | `IDetfNftInventoryPolicy` | File rename under `detf/inventory/` |
| `protocolDETF()` (view) | `detf()` | On `IDETFNFTVault`, claim tokens, composed-stable bond vault |
| `setProtocolDETF(address)` | `setDetf(address)` | Claim tokens |
| Storage / params `protocolDETF` typed as old interface | `detf` typed as `IDetf` | Layout-preserving field rename |
| `_protocolDETF()` repo getters | `_detf()` | |
| `protocolNftId` (storage / locals) | `detfNftId` | Prefer alignment with `detfNFTId()` API casing rules: **storage field `detfNftId`**, public getters may keep existing `detfNFTId()` |
| `_tryInitProtocolNft` | `_tryInitDetfNft` | DFPkg private helpers |
| `_sellPositionToProtocol` | `_sellPositionToDetfNft` | `DETFBondLifecycleLib` |
| `_collectProtocolRewards` | `_collectDetfNftRewards` | lifecycle lib |
| `_addReservePoolBptToProtocolNft` | `_addReservePoolBptToDetfNft` | lifecycle lib + single vault bonding |

**Existing already-good names (do not regress):**

- `initializeDETFNFT`, `addToDETFNFT`, `detfNFTId()`, `DETFNFTRestricted`
- Role names: `rateAsset`, `pairToken`, `underlyingVault`, `reservePool`, `rebasingClaimToken`

### 6.3 Mint-split / inventory accrual (Cluster C)

| Current | New |
|---------|-----|
| mint-split field `protocolDetf` | `inventoryDetf` |
| mint-split field `protocolDetfOut` | `inventoryDetfOut` |
| `DETFMintSplitLib` return `protocolAmount_` | `inventoryAmount_` |
| `_accrueMintProtocolInventory` | `_accrueMintInventory` |
| Test helper names like `mockProtocolReserveBpt` | `mockDetfOwnedReserveBpt` (or `mockDetfNftReserveBpt`) |

### 6.4 Package path move (Cluster D)

**Move** shared packages **out of** `contracts/vaults/protocol/` into detf:

| Current | New |
|---------|-----|
| `contracts/vaults/protocol/DETFNFTVault*.sol` | `contracts/vaults/detf/bondNft/DETFNFTVault*.sol` |
| `contracts/vaults/protocol/RebasingClaimToken*.sol` | `contracts/vaults/detf/claimToken/RebasingClaimToken*.sol` |

**Leave in place (out of scope):**

| Path | Reason |
|------|--------|
| `contracts/vaults/protocol/uniswap/crossVersion/*DualLiquidity*` | DualLiquidity product, not Protocol DETF rename |

After the move, `contracts/vaults/protocol/` may remain solely for DualLiquidity (and any non-DETF leftovers). **Do not** force-delete the directory while DualLiquidity lives there. Optional later PRD may relocate DualLiquidity.

Update all imports, including:

- `detf/reusable/Detf{Component,Facet,Pkg}FactoryService.sol`
- `detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol`
- family DFPkgs that deploy bond/claim packages
- tests under `test/foundry/spec/protocol/vaults/protocol/` and `test/foundry/spec/vaults/protocol/`

**Test path preference (same program):**

| Current test layout | Target |
|---------------------|--------|
| `test/foundry/spec/protocol/vaults/protocol/DETFNFTVault*` | `test/foundry/spec/vaults/detf/bondNft/` |
| `test/foundry/spec/protocol/vaults/protocol/RebasingClaimToken*` | `test/foundry/spec/vaults/detf/claimToken/` |
| `test/foundry/spec/vaults/protocol/DETFNFTVault.t.sol` etc. | same target tree |
| DualLiquidity fork bases under `…/vaults/protocol/uniswap/…` | **unchanged** |

### 6.5 Scripts (Cluster E)

| Action | Artifacts |
|--------|-----------|
| **Archive or delete** (prefer `scripts/archive/` if historical value; else delete) | `Script_16_DeployProtocolDETF.s.sol` (all envs), supersim `*ProtocolDetf*` deploy/bridge scripts that only exist for the dead product |
| **Rewrite imports** if still used for modern families | `Script_12_DeployScenario3Overlay.s.sol` and any script that only needed `IProtocolDETF` type |
| **Do not rename** | `Script_03_DeployBaseProtocols`, `Demo_02_External_Protocols` (DEX “protocols”) |

### 6.6 Docs (Cluster G — required for Done)

| Doc | Change |
|-----|--------|
| `AGENTS.md` / `Agents.md` | F6 surface = `IDetf`; path map: bondNft/claimToken under detf; drop “Protocol DETF” as live family |
| `DETF_Threshold_Modes_PRD.md` + PROGRESS / program-complete notes | F6 → `IDetf` naming; historical note that F6 shipped under old name |
| Family PRDs that cite “Protocol DETF” as **behavioral reference** | One-line update: “former Protocol DETF / now shared `IDetf` surface” — do not re-open product design |
| This PRD + inventory report | Remain as historical + normative rename law |

### 6.7 Explicitly out of scope identifiers

| Keep as-is | Why |
|------------|-----|
| `contracts/protocols/**` | External protocol integrations |
| DualLiquidity package names and path under `vaults/protocol/uniswap/` | Different product |
| `IDETF` interface name | Separate narrow surface |
| English “protocol-owned reserve” in old archived tasks | Historical |
| Frontend / e2e `protocolDetfs` | Wave F optional |

---

## 7. Storage layout rules (normative)

1. **Rename-in-place only** for repo `Storage` structs: change **field names**, never **order**, **type width**, or **insert/delete** fields mid-struct in this program.
2. Changing `IProtocolDETF` → `IDetf` on a stored address-sized reference is a **type alias rename** (same underlying address). Safe if field order unchanged.
3. No “cleanup” packing, no moving `detfNftId` relative to neighbors.
4. CREATE3 salt strings that embed old type **names** (e.g. facet deploy salts from `type(X).name`) will change **addresses of new deploys** — expected under greenfield. Document in implementation plan; do not invent salt-stability hacks unless a later ops requirement appears.

---

## 8. ABI / interface rules (normative)

1. **No dual exports.** Old external names must not remain as wrappers.
2. Facet `facetFuncs` / `facetMetadata` / IFacet tests update to new selectors in the same change set as implementations.
3. `interfaceId` for `IDetf` will differ from `IProtocolDETF` if the function set is identical but names change (ERC-165 id is over function selectors). Update any hard-coded interfaceId assertions.
4. Off-chain ABIs in-repo used by Foundry tests update with Solidity. Frontend is Wave F.

---

## 9. Behavior freeze

Implementations must preserve:

- Mint/burn threshold Policy vs Open (synthetic gates)
- Seigniorage split math (only names of split fields change)
- Bond lock min/max clamp
- Sell bond → detf-owned NFT principal move → claim mint path
- `claimLiquidity` / `previewClaimLiquidity` semantics
- Reentrancy / auth checks (caller must be DETF diamond, feeTo, etc.) — only error **names** like `NotDetf` change
- Preview == execution guarantees already required by family PRDs

**Forbidden in this program:** drive-by refactors, fee changes, new routes, threshold default changes.

---

## 10. Delivery waves

### Wave 0 — Baseline (no rename yet)

- [ ] Confirm `forge build` green on branch tip
- [ ] Snapshot inventory report is still accurate (spot-check `rg IProtocolDETF`)
- [ ] List DualLiquidity paths under `vaults/protocol/uniswap` so movers do not touch them

### Wave 1 — Canonical types (Cluster A)

- [ ] Add `IDetf.sol`, `IDetfErrors.sol`, `IDetfProxy.sol` (or rename files via git mv)
- [ ] Point `ISingleVaultDetf`, `IDETFNFTVault`, claim interfaces at `IDetf`
- [ ] Update `DETFCommon` → `IDetfErrors`
- [ ] Remove old interface files once no references remain
- [ ] `forge build`

**Suggested first compile target:** interfaces + `DETFCommon` + one family (Single Vault facets) before whole monorepo.

### Wave 2 — Shared packages path move (Cluster D) + inventory APIs on packages (Cluster B partial)

- [ ] `git mv` DETFNFTVault* → `detf/bondNft/`
- [ ] `git mv` RebasingClaimToken* → `detf/claimToken/`
- [ ] Rename package APIs: `detf()`, `setDetf`, `sellPositionToDetfNft`, `reallocateDetfNftRewards`, event rename
- [ ] Update reusable factory imports
- [ ] Move/update package unit/deploy tests
- [ ] `forge build` + package deploy tests

### Wave 3 — Core libs + inventory policies (Clusters B/C core)

- [ ] `DETFBondLifecycleLib`, `DETFBondNFTMathLib`, `DETFMintSplitLib`
- [ ] `detf/inventory/*` renames (`IDetfNftInventoryPolicy`, bond policy method names)
- [ ] `forge build`

### Wave 4 — Family production code (all live families)

Apply Clusters A–C consistently:

| Family | Path |
|--------|------|
| Single SE | `detf/standardExchange/single/` |
| Single Vault | `detf/composed/single/` |
| Multi-vault weighted | `detf/composed/multi-vault-weighted/` |
| Mixed-buffer multi-vault stable | `detf/composed/stable/mixedBuffer/` |
| Composed stable common (+ local bond NFT vault + rebasing token) | `detf/composed/stable/common/` |

Also:

- [ ] `contracts/vaults/seigniorage/nft/SeigniorageBondNFTTarget.sol` (`IDetfErrors` import / any `NotProtocolDETF` usage)
- [ ] Any remaining `IProtocolDETFErrors` under seigniorage packages

### Wave 5 — Tests

- [ ] All `test/foundry/spec/vaults/detf/**` imports and expectRevert selectors
- [ ] Adversarial suites referencing `sellPositionToProtocol`
- [ ] IFacet tests for Single Vault (heavy `IProtocolDETF` selector tables)
- [ ] Bond NFT / claim package tests after path move
- [ ] Delete or fix `test/foundry/debug/ProtocolDETF_*` and dead fork stubs (rename file if kept)

**Verification command set (minimum):**

```bash
forge build
forge test --match-path test/foundry/spec/vaults/detf/ -vv
forge test --match-path test/foundry/spec/vaults/detf/bondNft/ -vv   # after move
forge test --match-path test/foundry/spec/vaults/detf/claimToken/ -vv
# Plus family gold paths as capacity allows:
forge test --match-contract SingleVaultDetf --no-match-path 'fork/**'
# etc.
```

Exact suite list belongs in the implementation plan; PRD requires **no remaining `IProtocolDETF` references under `contracts/`** and **green detf spec tests**.

### Wave 6 — Scripts (Cluster E)

- [ ] Archive/delete Protocol DETF-named deploy scripts
- [ ] Fix remaining live scripts that import old types
- [ ] Grep `scripts/` for `IProtocolDETF` / `ProtocolDETF` / `setProtocolDETF` → empty (except archive)

### Wave 7 — Docs + agent law (Cluster G)

- [ ] AGENTS.md path table + F6 naming
- [ ] Threshold Modes PRD/PROGRESS F6 rename notes
- [ ] Family PRD “Protocol DETF reference” one-liners
- [ ] Mark inventory report status: **superseded by this PRD for decisions**; keep as evidence

### Wave F — Frontend / lists (optional follow-on; not Done)

- `protocolDetfs()`, tokenlist type dir `vaults/protocolDetf`, portfolio `kind === 'protocol'`
- Separate small PRD or task; must not block Wave 7 Done

---

## 11. Acceptance criteria (Definition of Done)

### 11.1 Must pass

1. **`rg 'IProtocolDETF' contracts/`** → no matches (except this PRD / inventory / historical quotes if those stay under `contracts/vaults/detf/*.md` — prefer confining old names to docs that explicitly say “formerly”).
2. **`rg 'IProtocolDETF' test/foundry`** → no matches in live tests (archived debug optional).
3. **`rg 'sellPositionToProtocol|setProtocolDETF|reallocateProtocolRewards|NotProtocolDETF' contracts/`** → no matches.
4. **`rg 'protocolDetf|protocolNftId|protocolDETF' contracts/vaults/detf contracts/interfaces contracts/vaults/detf/bondNft contracts/vaults/detf/claimToken`** → no matches (allow English in comments only if PRD glossary compliant; prefer zero).
5. Shared packages exist only under:
   - `contracts/vaults/detf/bondNft/`
   - `contracts/vaults/detf/claimToken/`
6. **`forge build`** succeeds.
7. **DETF family + bondNft + claimToken Foundry specs** required by implementation plan pass.
8. AGENTS.md no longer lists live `IProtocolDETF` or `contracts/vaults/protocol/` as home of DETFNFTVault/RebasingClaimToken.
9. No new mocks introduced for SUT (production-first testing unchanged).

### 11.2 Explicit non-blockers

- Frontend still saying `protocolDetfs` (Wave F)
- DualLiquidity still under `vaults/protocol/uniswap/`
- Historical root PLANs / archived tasks mentioning Protocol DETF
- Archive scripts under `scripts/archive/` still containing old names

---

## 12. Risks and mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Massive mechanical rename misses a selector in facet metadata | High | Wave order: types → packages → libs → families → tests; full `rg` gates |
| Storage layout accidental reorder | Critical | PR review checklist: struct field **order** diff empty of reorders; only renames |
| DualLiquidity files moved by accident | Medium | Wave 0 path allowlist; never `git mv contracts/vaults/protocol` wholesale |
| CREATE3 address changes break local anvil scripts still pointing at old salts | Medium | Wave 6 script cleanup; re-broadcast local stacks |
| Confusion `IDetf` vs `IDETF` | Medium | NatSpec on both files; AGENTS.md glossary; PRD §5 |
| Agent reintroduces Protocol names | Medium | AGENTS.md anti-pattern table; inventory+PRD linked from DETF section |
| Seigniorage / non-detf still on old errors | Medium | Wave 4 includes seigniorage NFT target error import |

---

## 13. Anti-patterns (do not reintroduce)

```solidity
// WRONG — product brand
interface IProtocolDETF { ... }
error NotProtocolDETF(address caller);
function setProtocolDETF(address) external;
function sellPositionToProtocol(...) external;

// WRONG — new code under deprecated shared package path
import {DETFNFTVaultDFPkg} from "contracts/vaults/protocol/DETFNFTVaultDFPkg.sol";

// RIGHT
interface IDetf { ... }
error NotDetf(address caller);
function setDetf(address) external;
function sellPositionToDetfNft(...) external;
import {DETFNFTVaultDFPkg} from "contracts/vaults/detf/bondNft/DETFNFTVaultDFPkg.sol";
```

---

## 14. Relationship to other programs

| Program | Relationship |
|---------|----------------|
| DETF Threshold Modes (F6) | **Naming only**: F6 surface becomes `IDetf`; Policy/Open law unchanged |
| DETF role naming (rateAsset / pairToken) | Orthogonal; this PRD continues that cleanup for inventory roles |
| Seigniorage DETF | Imports `IDetfErrors` only as needed; no seigniorage product redesign |
| DualLiquidity | Path co-location under `vaults/protocol/uniswap` left alone |
| Frontend redesign | Wave F optional; may track under `frontend/ROADMAP.md` later |

---

## 15. Implementation plan handoff

A separate **implementation and test plan** (same directory) should expand:

1. File-by-file `git mv` list for Wave 2
2. Exact `forge test --match-path` matrix per wave
3. Suggested PR split (e.g. Wave 1–2 one PR, Wave 3–5 one PR, Wave 6–7 docs/scripts PR) **or** single stacked PR if preferred
4. Grep allowlist for docs that may still say “formerly Protocol DETF”

This PRD is sufficient to start that plan without reopening D1–D5.

---

## 16. Open items (non-blocking)

| Item | Default if never decided |
|------|---------------------------|
| Exact claim mint-split field: `inventoryDetf` vs `seigniorageDetf` | **`inventoryDetf`** (locked by D3 table §6.3) |
| Whether to delete vs archive Protocol DETF scripts | **Archive** under `scripts/archive/` if any historical ops value; else delete |
| `IDetfNftInventoryPolicy` empty marker: keep vs fold into bond policy | **Keep renamed marker** if `IComposedStableCommonDetfBondNFTVault` still uses it; fold only if zero cost and same PR |
| Casing: `detfNFTId` vs `detfNftId` for new storage | Storage **`detfNftId`**; keep existing external `detfNFTId()` getters as-is to limit extra selector churn beyond Cluster B |

---

## 17. Success narrative

After this program:

- New DETF work imports **`IDetf` / `IDetfErrors`**, not a dead product brand.
- Bond NFT sell and seigniorage inventory read as **detf-owned NFT / inventory**, matching AGENTS role language.
- Shared bond/claim packages sit under **`contracts/vaults/detf/bondNft`** and **`…/claimToken`**.
- Agents reading AGENTS.md and Threshold Modes docs no longer treat Protocol DETF as a live family.
- Behavior and storage layout match pre-rename; only names, selectors, and paths differ.

---

## 18. Document control

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-07-28 | Locked from inventory report + owner decisions D1–D5 |

**Normative for rename execution.** Inventory report remains the evidence base for blast radius; this PRD wins on naming choices.

---

*End of PRD.*
