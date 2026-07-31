# DETF RICH Naming Generalization — Implementation Plan

> **For review:** Agents hard-coded product token names (`RICH`, `RICHIR`, `WETH/RICH`) into DETF APIs, storage, types, and docs despite prior instructions to use role names only. This plan defines a full rename to general descriptive terms, phased for safe delivery.

**Goal:** Remove product-specific token branding (`RICH`, `RICHIR`, `WETH` when not WETH-specific, and compounds such as `wethRich*`, `richChir*`, `bridgeRichir`, `receiveBridgedRich`, `mintWithWeth`, `wethAsEth`) from DETF protocol code, interfaces, tests, scripts, and active docs. Replace with **role-based names** that describe economic function, not a specific deployment asset.

**Non-goal / hard constraint:** **Rename and ABI surface cleanup only.** No workflow, pricing, threshold, reserve-math, or routing logic changes. Existing tests must pass after call-site updates for renamed functions. Do not add multi-token loops or new vault capabilities in this refactor.

**Canonical naming precedent (already enforced elsewhere):**

- DualLiquidityLinkedDETF PRD / plan: *role names only* — no product strings in contract identifiers or normative NatSpec.
- Composed stable common path already partially generalizes (`rebasingDetfToken`, `rewardToken`, `baseToken`) but still types against `IRICHIR` and keeps `richir*` parameter names.
- **WETH rule:** Use `weth` / `WETH` only in code that is *actually* WETH-specific (e.g. `WETHAwareRepo`, wrap/unwrap). DETF vaults that accept a configurable settlement/rate asset must **not** say WETH even if a deployment happens to use WETH.

**Tech stack:** Solidity ^0.8.0, Foundry, Crane Diamond (Repo/Target/Facet/DFPkg/FactoryService), Next.js frontend ABIs, deploy scripts + JSON artifacts.

---

## 1. Problem statement

| Layer | Symptom |
|-------|---------|
| **Interfaces** | `IProtocolDETF.richToken()`, `richirToken()`, `bridgeRichir()`, `receiveBridgedRich()`, `ISingleVaultDetf.wethRichVault()`, `IRICHIR`, `convertToRichir` |
| **Types / packages** | `RICHIRDFPkg`, `RICHIRFacet`, `RICHIRTarget`, `RICHIRRepo`, `IRICHIRProxy` |
| **Storage fields** | `richToken`, `richirToken`, `wethRichVault`, `wethRichPoolKeyHash` |
| **Helpers** | `_isRichToken`, `_convertRichToWeth`, `_mintRichirFromWeth`, `previewBridgeRichir` |
| **Docs / NatSpec** | “RICH: static supply ERC20”, “WETH/RICH Standard Exchange”, error comments “Token is not RICH” |
| **Deploy / UI** | `Script_DeployRichToken`, tokenlists with `RICH`/`RICHIR` symbols, frontend staking copy and ABI selectors |

Approx. **85+ Solidity-touching files** (plus tests, scripts, frontend, deploy JSON) reference this vocabulary. Archive/task history may retain old names; live code and active docs must not.

---

## 2. Canonical glossary (target vocabulary)

Adopt one glossary and apply it **everywhere** (identifiers, NatSpec, errors, events, test locals, script vars).

### 2.0 Intent (SingleVaultDetf / composed DETF legs)

```
                    IStandardExchange underlyingVault
                    (any SE; tokens() may be 1..N assets)
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
    rateAsset            pairToken(s)         (other legs…)
  "new money"         every tokens()[i] that
  Rate Provider       is not rateAsset
  quote target
  mint/bond/redeem
  settlement
         │
         └──────────► gives the DETF reserve its real market value
```

| Role | **Target name** | Meaning |
|------|-----------------|---------|
| Rate Provider quote / “new money” | **`rateAsset`** | The token the Rate Provider targets. Must appear in the underlying vault’s declared token set (`IStandardVault.tokens()` / equivalent). This is **also** the settlement asset for mint, bond, and redeem. It is what gives the DETF reserve real market value. |
| Any other vault-declared token | **`pairToken`** | Every asset in the underlying vault’s token list that is **not** `rateAsset`. Count and identity of pair tokens are irrelevant to DETF architecture; the DETF processes them the way current code processes the single RICH slot. **This rename keeps a singular storage field** (today’s one non-rate bond/route asset) — multi-token iteration is future work, not this PR. |
| Underlying Standard Exchange | **`underlyingVault`** | Any `IStandardExchange`. We only require that `rateAsset` is a token that vault processes as declared by its standard vault token list. |
| Rate provider | **`vaultRateProvider`** (keep if already general) | Quotes the vault (or vault share) vs `rateAsset`. |
| Rebasing claim token | **`rebasingClaimToken`** / **`IRebasingClaimToken`** | Claim on protocol reserve BPT via NFT sale / mint path (today: RICHIR). |
| Uniswap V4 pool key for the SE (if still in PkgArgs) | **`underlyingPoolKey`** / **`underlyingPoolKeyHash`** / **`underlyingWidthMultiplier`** | Deploy args for the SE vault — not “WETH/RICH pool”. |
| DETF share token | **`detfToken`** / `address(this)` | Deploy-time name/symbol strings stay configurable. |
| Bond NFT vault | keep **`detfNFTVault`** if consistent | Already mostly general. |

**Mapping from current code (rename only):**

| Current | Target |
|---------|--------|
| `wethToken` | `rateAsset` |
| `richToken` | `pairToken` |
| `wethRichVault` / `richChirVault` / `chirWethVault` | `underlyingVault` (collapse redundant getters to one) |
| `wethRichPoolKey*` | `underlyingPoolKey*` |
| `richirToken` / `IRICHIR` / `RICHIR*` | `rebasingClaimToken` / `IRebasingClaimToken` / `RebasingClaimToken*` |
| `mintWithWeth` | `mintWithRateAsset` (or `mint` if no overload clash — prefer explicit `mintWithRateAsset`) |
| `_convertRichToWeth` | `_convertPairToRateAsset` |
| `_isWethToken` / `_isRichToken` | `_isRateAsset` / `_isPairToken` |
| `bond(..., wethAsEth, ...)` payable | **`bond(...)` ERC20-only** — drop `wethAsEth` and bare-ETH path from the DETF surface (see §2.4) |

### 2.0.1 WETH rule (when the word is allowed)

| Allowed | Forbidden in DETF family code |
|---------|-------------------------------|
| `WETHAwareRepo`, wrap/unwrap helpers, deploy scripts that *mint/wrap real WETH* for a specific chain fixture | `wethToken`, `mintWithWeth`, `wethRichVault`, `wethAsEth`, NatSpec “WETH/RICH vault” on SingleVaultDetf |
| Test fixtures may still *deploy* a token labeled WETH as instance data | Using WETH as the **type/role** name for `rateAsset` |

### 2.1 Type / file renames

| Current | Target |
|---------|--------|
| `IRICHIR` | `IRebasingClaimToken` |
| `IRICHIRProxy` | `IRebasingClaimTokenProxy` |
| `RICHIRDFPkg` / `IRICHIRDFPkg` | `RebasingClaimTokenDFPkg` / `IRebasingClaimTokenDFPkg` |
| `RICHIRFacet` | `RebasingClaimTokenFacet` |
| `RICHIRTarget` | `RebasingClaimTokenTarget` |
| `RICHIRRepo` | `RebasingClaimTokenRepo` |
| Directory paths under `contracts/vaults/protocol/RICHIR*` | Rename files in place (same folder is fine) |

### 2.2 Function / event / error renames (ABI-breaking)

| Current | Target |
|---------|--------|
| `richToken()` | `pairToken()` |
| `wethToken()` (on DETF info surface, if exposed) | `rateAsset()` |
| `richirToken()` | `rebasingClaimToken()` |
| `wethRichVault()` / `richChirVault()` / `chirWethVault()` | **`underlyingVault()`** (single getter) |
| `setRichirToken(...)` | `setRebasingClaimToken(...)` |
| `bridgeRichir(...)` | `bridgeRebasingClaim(...)` |
| `previewBridgeRichir(...)` | `previewBridgeRebasingClaim(...)` |
| `receiveBridgedRich(...)` | `receiveBridgedPair(...)` |
| `mintWithWeth(...)` | `mintWithRateAsset(...)` |
| `convertToRichir(shares)` | `convertToClaim(shares)` |
| `convertToShares(richirAmount)` | `convertToShares(claimAmount)` (param name only) |
| `bond(..., wethAsEth, ...)` payable | `bond(...)` **ERC20-only** — remove `wethAsEth` and `payable` / `msg.value` handling on the DETF |
| Events: `BridgeReceived(... richAmount ...)` | `... pairAmount ...` (or `rateAssetAmount` where the bridged asset is the pair leg today — keep semantics of *which* token moves; only rename) |
| Errors / NatSpec mentioning RICH / RICHIR / WETH (as roles) | Role language only |

### 2.3 Storage field renames (diamond storage)

Rename **struct member names** in source for clarity. **Do not change `STORAGE_SLOT` string values** in the same PR unless a full storage layout migration is explicitly planned (see §5). Solidity storage layout is by **declaration order and type**, not member name — renaming members alone is layout-safe **if order and types are unchanged**.

| Current member | Target member | Slot constant |
|----------------|---------------|---------------|
| `wethToken` | `rateAsset` | keep existing slot strings |
| `richToken` | `pairToken` | keep `keccak256("indexedex.vaults.detf.composed.single")` etc. |
| `richirToken` | `rebasingClaimToken` | same |
| `wethRichVault` | `underlyingVault` | same |
| `wethRichPoolKeyHash` | `underlyingPoolKeyHash` | same |
| `RICHIRRepo` slot `indexedex.vaults.protocol.richir` | **Keep slot string** for upgrade continuity; comment `// historical slot id; do not change` | |

### 2.4 Intentional API narrowing (not a logic change)

| Change | Why it is still in scope |
|--------|---------------------------|
| Drop `wethAsEth` / bare ETH on DETF `bond` | DETF surface is ERC20-only; wrap ETH off-vault if needed. Callers that passed `wethAsEth=true` must send ERC20 `rateAsset` instead. |
| Rename all exposed product-named functions | Required by this refactor; update tests/scripts/frontend selectors. |
| **No** new multi-`pairToken` iteration | Conceptual model allows N pair tokens; **current storage remains one `pairToken`** processed exactly as today’s RICH path. |

**Forbidden after this work (in live DETF / protocol vault code):**

- Product roots: `richToken`, `richir`, `RICHIR`, `wethRich`, `richChir`, `BridgedRich`, `mintWithWeth`, …
- Role misuse of `weth` / `WETH` on SingleVaultDetf and generic DETF packages
- NatSpec that names RICH / RICHIR / WETH as *the* protocol assets for this family
- Reintroducing `wethAsEth` on DETF entrypoints

**Allowed residual uses:**

- True WETH infrastructure (`WETHAwareRepo`, chain WETH address constants used only to *construct* a `rateAsset` in a deploy script)
- Deploy artifact **symbols** for a real token named RICH (instance data)
- Archives under `tasks/archive/`, `docs/archive/`

---

## 3. Scope inventory (blast radius)

### 3.1 Must change (P0 — production surface)

**Interfaces**

- `contracts/interfaces/IProtocolDETF.sol`
- `contracts/interfaces/IProtocolDETFErrors.sol`
- `contracts/interfaces/ISingleVaultDetf.sol`
- `contracts/interfaces/IRICHIR.sol` → rename file + content
- `contracts/interfaces/proxies/IRICHIRProxy.sol` → rename
- `contracts/interfaces/IDETFNFTVault.sol` (NatSpec / sale route wording)
- Any `IComposedStableCommonDetf*` still exposing RICH vocabulary

**Implementations — Single vault DETF**

- `contracts/vaults/detf/composed/single/**` (all Repo/Common/Target/Facet/DFPkg/FactoryService files)

**Implementations — protocol RICHIR package**

- `contracts/vaults/protocol/RICHIR*.sol` → RebasingClaimToken*
- Call sites in `DETFNFTVault*`, `DetfPkgFactoryService`, `DetfFacetFactoryService`, `DetfComponentFactoryService`, `DETFBondLifecycleLib`

**Implementations — stable common (partial debt)**

- `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/**` — replace remaining `IRICHIR` / `richir*` / `convertToRichir` / event types with glossary names while keeping existing good names (`rebasingDetfToken`, `rewardToken`)

### 3.2 Must change (P1 — tests & factories)

- `test/foundry/spec/vaults/detf/composed/single/**`
- `test/foundry/spec/vaults/protocol/RICHIR*` → rename paths
- `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/**`
- `test/foundry/fork/**` Protocol DETF suites that call `richToken` / `richir` selectors
- `test/foundry/debug/**` as needed

### 3.3 Must change (P2 — scripts & frontend)

- `scripts/foundry/**` deploy/export scripts referencing RICHIR pkg types and `richToken` args
- `frontend/app/lib/protocolDetfAbi.ts` and staking hooks/sections
- Tokenlist generators that hardcode protocol type names as `RICHIR` (symbol for a *deployed* product can stay a symbol; **ABI function names** must update)

### 3.4 Docs (P3 — active only)

Update active normative docs; do not mass-edit archives unless cited as current:

- `docs/components/RICHIR*.md` → rename + retarget
- `docs/DETF.md`, `docs/PROTOCOL_DETF_ANALYSIS.md`, route inventories that are still used
- `Agents.md` / any skill copy that tells agents “RICH” is the pair token — **add an explicit anti-pattern**

### 3.5 Explicit non-scope (this plan)

- Deployed mainnet/sepolia **addresses** and historical broadcast folders (immutable)
- Renaming a real ERC20’s on-chain `name()`/`symbol()` for a token that is already RICH
- DualLiquidityLinked family (already role-named; only verify no regression of the rule)
- Archive tasks under `tasks/archive/*` (optional follow-up)

---

## 4. Principles & constraints

1. **Role names only** in contracts, interfaces, storage field names, facet selectors, and normative NatSpec.
2. **Behavior parity:** same call graphs, same thresholds, same fees — only names change.
3. **Crane / IndexedEx rules still apply:** no `new` for facets/pkgs; vault DFPkgs via registry; production-first tests.
4. **One glossary** — do not invent parallel terms mid-stack (`pairToken` vs `rewardToken` for the same slot). Exception: bond NFT vault may keep `rewardToken` if that field means DETF rewards, not the pair asset — document the distinction in NatSpec.
5. **Prefer mechanical rename PR(s)** over redesign. If an API is redundant (`richChirVault` vs `wethRichVault`), collapse in the same phase as renames.
6. **CI gate:** after completion, `rg` lint fails if product vocabulary reappears in `contracts/` and `test/` (see §8).
7. **Agent instruction:** add a short “Naming” subsection under DETF / Agents.md so future agents do not reintroduce RICH branding.

---

## 5. Storage & upgrade notes

| Concern | Decision |
|---------|----------|
| Diamond storage member renames | Safe if **order + types** unchanged |
| `STORAGE_SLOT` string containing `richir` | **Leave unchanged** (historical salt); comment only |
| Already-deployed proxies (supersim/sepolia artifacts) | ABI rename **breaks** callers; redeploy or ship a temporary dual-selector facet only if a live integration requires it |
| Interface IDs / `docs/interfaceids.json` | Regenerate after facet selector changes |
| ERC-165 `facetInterfaces` | Update to new interface types |

**Recommendation:** Treat this as a **source + testnet redeploy** refactor. Do not promise mainnet in-place upgrade compatibility for selector renames unless a dual-ABI adapter facet is explicitly scheduled (out of default path).

---

## 6. Phased implementation

### Phase 0 — Align & freeze glossary (review gate)

**Deliverables**

- [ ] This plan reviewed; glossary in §2 accepted or amended **before** code moves
- [ ] Confirm target names for edge cases:
  - [ ] `pairToken` vs `rewardToken` for the static pair asset
  - [ ] `rebasingClaimToken` vs shorter `claimToken` / existing `rebasingDetfToken`
  - [ ] Whether `commonToken` replaces remaining WETH-specific DETF APIs or only pair/claim vocabulary
- [ ] Open tracking issue / branch: `refactor/detf-role-naming` (or similar)
- [ ] Snapshot current green suites to re-run after each phase

**Exit:** Written approval of §2 glossary (comment on plan or PR description).

---

### Phase 1 — Core type rename (`IRICHIR` → `IRebasingClaimToken`)

**Why first:** Many files import the type; renames cascade cleanly with `git mv`.

**Steps**

1. [ ] `git mv` interface + implementation files to new names
2. [ ] Rewrite interface NatSpec to role language; rename methods (`convertToRichir` → `convertToClaim`)
3. [ ] Update `RICHIRRepo` storage field names and internal helpers; **keep storage slot constant string**
4. [ ] Update DFPkg / Facet / FactoryService names and CREATE3 salt **source** (`type(X).name` changes salt — document that new deploys get new addresses)
5. [ ] Fix all Solidity imports/types until `forge build` succeeds
6. [ ] Rename primary unit tests under `test/foundry/spec/vaults/protocol/`

**Verification**

```bash
forge build
forge test --match-path 'test/foundry/spec/vaults/protocol/*' -vv
```

**Exit:** No `IRICHIR` / `RICHIR*` type names remain under `contracts/` except historical slot comments.

---

### Phase 2 — Protocol DETF interface surface

**Steps**

1. [ ] Edit `IProtocolDETF` / errors / events / structs (`BridgeArgs` fields like `richirAmount`, `minRichOut`, `minLocalRichirOut`)
2. [ ] Edit `ISingleVaultDetf` (`wethRichVault` → `underlyingVault`; `wethToken` → `rateAsset` where exposed)
3. [ ] Update facet `facetFuncs` selector lists (must match new function names)
4. [ ] Collapse redundant getters (`richChirVault` / `chirWethVault` / `wethRichVault` → single `underlyingVault`)
5. [ ] Regenerate or hand-update frontend ABI fragments that encode selectors

**Verification**

```bash
forge build
# Facet interface id tests if present:
forge test --match-contract 'SingleVaultDetf*Facet_IFacet*' -vv
```

**Exit:** Interfaces contain zero product-token vocabulary; facet metadata tests green.

---

### Phase 3 — SingleVaultDetf implementation

**Steps**

1. [ ] `SingleVaultDetfRepo` field + accessor renames
2. [ ] `SingleVaultDetfCommon` helper renames (`_isRichToken` → `_isPairToken`, `_isWethToken` → `_isRateAsset`, etc.)
3. [ ] ExchangeIn / Out / Query / Bonding / Info Targets; drop `wethAsEth` / payable ETH on bond
4. [ ] DFPkg `PkgInit` / `PkgArgs` (`richToken` → `pairToken`, `wethToken` → `rateAsset`, `wethRichPoolKey` → `underlyingPoolKey`, …)
5. [ ] FactoryServices (`*_Component_FactoryService` builders)
6. [ ] Spec tests under `test/foundry/spec/vaults/detf/composed/single/**`

**Verification**

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/*' -vv
```

**Exit:** Single-vault family fully role-named; suite green.

---

### Phase 4 — Stable common + shared DETF libs

**Steps**

1. [ ] Replace residual `IRICHIR` / `richir*` in `composed/stable/common/**` and `RebasingDETFToken*`
2. [ ] Align naming: prefer one of `rebasingClaimToken` **or** keep local `rebasingDetfToken` if it is the same type — document mapping in a one-line NatSpec on the field
3. [ ] `DETFBondLifecycleLib`, NFT vault sale NatSpec, factory services
4. [ ] Stable common tests

**Verification**

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/*' -vv
```

**Exit:** No RICH product vocabulary under `contracts/vaults/detf/**` or `contracts/vaults/protocol/**`.

---

### Phase 5 — Scripts, frontend, active docs, agent rules

**Steps**

1. [ ] Deploy scripts: variable names, log labels, JSON keys written by *new* exports (do not rewrite historical `deployments/**` unless tooling requires it)
2. [ ] Frontend: ABI, hooks, staking UI strings that describe protocol roles
3. [ ] Active docs: `docs/components/*`, `docs/DETF.md`, rename `RICHIR*.md` component docs
4. [ ] **Agents.md** (and DETF skill/PRD snippets if any): add anti-pattern — *never name protocol roles after product tokens; use `rateAsset` / `pairToken` / `underlyingVault` / `rebasingClaimToken`; never use WETH unless the code is WETH-specific*
5. [ ] Optional: cspell / CI `rg` check (see §8)

**Verification**

```bash
# vocabulary gate (adjust paths if needed)
rg -n --pcre2 '\bRICH\b|\bRICHIR\b|\brichToken\b|\brichirToken\b|\bwethRich|\bbridgeRichir\b|\breceiveBridgedRich\b|\bIRICHIR\b|\bconvertToRichir\b' \
  contracts/ test/foundry/ scripts/foundry/ frontend/app --glob '!**/archive/**' --glob '!**/playwright-report/**'
# expect: zero hits (or allowlisted deploy instance symbols only)
```

**Exit:** Gate clean on live trees; docs instruct role naming.

---

### Phase 6 — Integration / fork confidence

**Steps**

1. [ ] Fork / supersim Protocol DETF tests updated and green
2. [ ] One full local deploy path smoke (foundation + DETF script stage) on Anvil/supersim if scripts still used
3. [ ] Note CREATE3 address changes due to `type(Name).name` salts — update any hardcoded expected addresses in tests

**Verification**

```bash
forge test --match-path 'test/foundry/fork/**/*ProtocolDETF*' -vv   # as applicable
# or project’s standard DETF integration command
```

**Exit:** Declared suite list green; plan status section updated.

---

## 7. Suggested PR slicing

| PR | Contents | Risk |
|----|----------|------|
| **PR1** | Phase 1 type/package rename only | Medium (many files, salts change) |
| **PR2** | Phase 2–3 interfaces + SingleVaultDetf + unit tests | High (ABI) |
| **PR3** | Phase 4 stable common + shared libs | Medium |
| **PR4** | Phase 5–6 scripts, frontend, docs, CI gate | Low–medium |

Do **not** mix this rename with economic changes or new vault features.

---

## 8. Definition of done

- [ ] Glossary (§2) applied consistently across interfaces and implementations
- [ ] `forge build` clean
- [ ] All DETF/protocol suites listed in Phases 1–4 and 6 green
- [ ] Vocabulary `rg` gate has **zero** product hits under `contracts/` and `test/foundry/` (except documented allowlist if any)
- [ ] Agents.md contains the role-naming rule and anti-pattern example
- [ ] Frontend compiles against new ABI selectors
- [ ] CREATE3 salt / address impact noted in PR description for deployers
- [ ] This plan’s status block updated to **DONE** with PR links

---

## 9. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Massive PR / review fatigue | Phase PRs as in §7; mechanical renames first |
| Missed selector in facetFuncs | Facet_IFacet tests + full build |
| CREATE3 address drift | Expect new addresses; update tests; never hardcode salts from old type names |
| Frontend / scripts half-updated | PR4 must land before treating release as complete; temporary dual ABI only if forced |
| Agents reintroduce RICH | Agents.md + CI rg gate |
| Confusing `pairToken` vs `rewardToken` | Single glossary; NatSpec one-liners on each storage field |
| Historical JSON / tokenlists still say RICH | Instance data OK; do not use as type names in Solidity |

---

## 10. Open questions — resolved / remaining

### Resolved (2026-07-14)

| # | Decision |
|---|----------|
| Rate / settlement asset | **`rateAsset`** — Rate Provider target; mint/bond/redeem settlement; “new money” that gives reserve real market value. Must be in underlying vault `tokens()`. |
| Other vault tokens | **`pairToken`** — any declared vault token that is not `rateAsset`. Architecture-agnostic to how many; **rename keeps singular field** (current RICH slot). |
| Underlying vault | **`underlyingVault`** — any `IStandardExchange`. |
| Claim token | **`rebasingClaimToken` / `IRebasingClaimToken`**. |
| WETH naming | Only in truly WETH-specific code. Not on SingleVaultDetf roles. |
| Scope | **Rename only** — no workflow/behavior changes; tests pass after renames. |
| `wethAsEth` | **Remove** from DETF bond surface; ERC20-only. |
| Collapse getters | Yes — one `underlyingVault()` (drop product dual names). |

### Still open (optional before Phase 1)

1. **Deployed environments:** Redeploy-only vs temporary dual-selector facets for supersim continuity?
2. **CI allowlist:** Any legitimate remaining product string in live `contracts/` (expect: none except historical storage-slot comments)?
3. **`mintWithRateAsset` vs shorter `mint`:** prefer explicit name to avoid ERC20 `mint` confusion — default **`mintWithRateAsset`** unless review prefers otherwise.

---

## 11. Status

| Field | Value |
|-------|--------|
| **Status** | IN PROGRESS — core rename implemented; forge build green; SingleVaultDetf + protocol + stable-common suites green |
| **Author intent** | Correct accidental product branding introduced despite prior agent guidance |
| **Branch (proposed)** | `refactor/detf-role-naming` |
| **Related** | DualLiquidityLinked naming rule; stable-common partial generalization; SingleVaultDetf review |

---

## 12. Appendix — high-signal current references

Use for search-and-replace baselines (not exhaustive):

```
richToken / _richToken / _isRichToken / _convertRichToWeth
wethToken / _isWethToken / mintWithWeth / wethAsEth
richirToken / _richirToken / _isRichirToken / setRichirToken
wethRichVault / wethRichPoolKey / wethRichPoolKeyHash / wethRichVaultPkg
richChirVault / chirWethVault
bridgeRichir / previewBridgeRichir / receiveBridgedRich
convertToRichir / minRichOut / minLocalRichirOut / richirAmount
IRICHIR / IRICHIRProxy / RICHIRDFPkg / RICHIRFacet / RICHIRTarget / RICHIRRepo
```

After Phase 5, re-run:

```bash
rg -n --pcre2 '(?i)\brich(ir|token|chir)?\b|wethRich|wethAsEth|mintWithWeth|bridgeRichir|receiveBridgedRich|convertToRichir|IRICHIR|RICHIR' \
  contracts/vaults/detf contracts/vaults/protocol contracts/interfaces test/foundry/
# Also flag DETF-role misuse of wethToken (allow true WETH infra paths separately)
```

---

*End of plan.*
