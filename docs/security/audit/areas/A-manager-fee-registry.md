# Security Audit — A-manager-fee-registry

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · MODE=full · `A-manager-fee-registry` |
| Status | **COMPLETE** |
| Production paths | `contracts/manager/**`; `contracts/fee/collector/**`; `contracts/oracles/fee/**`; `contracts/registries/vault/**` |
| Test paths | `test/foundry/spec/manager/**`; `test/foundry/spec/fee/**`; `test/foundry/spec/oracles/fee/**`; `test/foundry/spec/registries/vault/**` |
| Skills cited | `docs/security/SECURITY_AUDIT_PRD.md` §2, §2.4, §3.8, §5–8, §19; `00_SCOPE_PARTITION.md`; `crane-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `ethskills-crops`; `crane-access`; `defi-incident-patterns` |
| Seeds | `docs/testing/coverage-audit/areas/T-manager-fee-registry.md`; `docs/security/audit/specialists/S-crops-trust.md` |
| Residual-risk scores | IndexedexManager **3**; VaultFeeOracle **4**; VaultRegistry (deploy/index) **4**; VaultRegistry (disable) **3**; FeeCollector **4**; VaultFeeOracleQueryAware **4** |

## 1. Executive summary

- **Residual-risk scores:** Manager **3** (owned admin diamond + disable capability that freeze-gated families honor). Fee oracle **4** (WAD bounds + cascade proven; 100% tax is trust, not extract). Registry deploy/index **4**. Registry disable **3** (path correct; freeze is consumer High). FeeCollector **4** (money-out ACL proven on proxy). QueryAware **4** (view-only support facet).
- **Critical / High counts:** **Critical 0**. **Open High 1** — `SEC-MGR-001` registry disable-on-exit, **OWNED_ELSEWHERE** → `SEC-CROPS-001` / `WP-SEC-CROPS-001` (do **not** rewrite `S-crops-trust`). **Closed-at-SHA High 3** (OWNED_ELSEWHERE): seigniorage PAT-J-OMIT (`WP-J-MGR-001`), manager J matrix (`WP-J-MGR-002`), FeeCollector pull/push (`WP-N-FEE-001`).
- **Top recommended WPs (this program):** none for new High CODE. Stage 2 should **not** open `sec_fix_*` on `WP-J-MGR-001/002` or `WP-N-FEE-001`. Remaining Mediums: `WP-SEC-REG-001` (stale packed `feeTypeIdsOfVault`) and `WP-SEC-MGR-ACL-001` (exact-selector ACL residuals) — only if coverage Wave-2 `WP-CODE-REG-001` / `WP-N-MGR-001` stay unscheduled. Freeze CODE stays `WP-SEC-CROPS-001` on DETF/SE commons, not on manager.
- **OWNED_ELSEWHERE count:** **8** linked touch-sets (`SEC-MGR-001…003`, `SEC-FEE-001`, `SEC-MGR-005`, `SEC-MGR-006`, plus TCA-MGR-004/012 residuals clustered below).

Headline: this area is an **owned platform diamond**, not an unowned DETF. Leftover `diamondCut` on IndexedexManager / FeeCollector is **expected** (L-SEC-11 distinction — do not treat as leftover-admin on a DETF instance). Gap-closure at this SHA **wired** `vaultSeigniorageTermsTypeId`, landed manager/registry/oracle `*_IFacet` + proxy J smoke, and proved FeeCollector `pullFee` `NotOwner` + real ERC20 + `pushSingleTokenFee`. The remaining High is the **disable flag consumers honor on claim/exit** (`S-crops-trust` SEC-CROPS-001). Re-verify of the manager/registry path: `setVaultAddressDisabled` / `setPackageDisabled` are **`onlyOwner`** (operator cannot flip the switch); `isDisabled` is vault-address **OR** package-of-vault; `deployVault` / hook deploy revert `DisabledPackage`. The registry does **not** itself revert user money functions — freeze requires a family `_requireNotDisabled` (Single SE, Uni V4 DETFs, DualLiquidity; **not** MultiVault).

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|---------------|
| **IndexedexManager** | `IndexedexManagerDFPkg` + `IndexedexManagerFactoryService`. Cuts: DiamondCut, MultiStepOwnable, Operable, VaultFeeOracle{Query,Manager}, VaultRegistry{Deployment,VaultManager,PackageManager,PackageQuery,VaultQuery,DisableQuery,DisableManager} | `IndexedexTest` → real manager proxy | **Excellent** — CREATE3 facets + DFPkg + `diamondPackageFactory.deployIndexedexManager`. Never `new` production facets | **3** |
| **VaultFeeOracle** (storage on manager) | `VaultFeeOracle{Query,Manager}Facet` + `VaultFeeOracleRepo` (`keccak256("indexedex.vault.registry.fee.oracle")`) | Same manager proxy | Facets on manager DFPkg; queries hit proxy | **4** |
| **VaultRegistry** (storage on manager) | Deployment / VaultManager / PackageManager / VaultQuery / PackageQuery / Disable{Query,Manager} Facets+Targets+Repos | Manager proxy; deploy ACL via `TestBase_AerodromeStandardExchange` | `deployPkg` / `deployVault` / hook deploy via registry; DFPkg-as-caller is the user path | **3** (disable) / **4** (index/deploy) |
| **FeeCollector** | `FeeCollectorDFPkg` + FactoryService. Cuts: DiamondCut, MultiStepOwnable, SingleTokenPush, Manager | `IndexedexTest.feeCollector` | CREATE3 facets + DFPkg + factory deploy | **4** |
| **VaultFeeOracleQueryAware** | `VaultFeeOralceQueryAwareFacet` (typo in type name) + `VaultFeeOracleQueryAwareRepo` | None dedicated | Support facet for SE DFPkg `initAccount` (`_initialize` fee-oracle pointer). **Not** on manager DFPkg cuts | **4** (view-only) |

### 2.1 Trust-flag / money credit entrypoints (this area)

| Surface | Flag / credit | Notes |
|---------|---------------|-------|
| Manager / fee oracle | None | Config-only; vaults consume `feeTo` / WAD reads |
| Registry deploy | N/A | `deployPkg` `onlyOwnerOrOperator`; `deployVault` / hook deploy owner **or** operator **or** `_isPkg(msg.sender)` |
| FeeCollector `syncReserve` / `pushSingleTokenFee` | Permissionless snapshot `reserve := balanceOf` | No `pretransferred`; PAT-I N/A |
| FeeCollector `pullFee` | Owner ERC20 `safeTransfer` out | **No** reserve subtract; ACL proven |

### 2.2 Facet inventory (manager diamond — `IndexedexManagerDFPkg`)

| Facet | Access model | `facetFuncs` | Declaration / J test? |
|-------|--------------|-------------:|-----------------------|
| DiamondCut | `onlyOwner` (Crane) | Crane | Crane |
| MultiStepOwnable | owner; 3-day transfer buffer | Crane | Crane + `InitAccount` |
| Operable | owner `setOperator` | Crane | `test_J3_proxySmoke_operable_setOperator` |
| VaultFeeOracleQuery | view | 25 | **Yes** — `VaultFeeOracleQueryFacet_IFacet` + Surface |
| VaultFeeOracleManager | `setFeeTo` onlyOwner; rest `onlyOwnerOrOperator` | 16 | **Yes** — IFacet + Auth + Seigniorage + Surface |
| VaultRegistryDeployment | `deployPkg` onlyOwnerOrOperator; vault/hook: `_onlyOwnerOrOperatorOrPkg` | 5 | **Yes** — IFacet + Auth + Surface |
| VaultRegistryVaultManager | onlyOwner | 2 | **Yes** IFacet |
| VaultRegistryVaultPackageManager | onlyOwner | 2 | **Yes** IFacet |
| VaultRegistryVaultPackageQuery | view | 10 | **Yes** IFacet |
| VaultRegistryVaultQuery | view | 22 (incl. `vaultSeigniorageTermsTypeId`) | **Yes** IFacet + Surface + Seigniorage_Surface |
| VaultRegistryDisableQuery | view | 7 | **Yes** IFacet |
| VaultRegistryDisableManager | onlyOwner | 2 | **Yes** IFacet + Disable suite |

FeeCollector: MultiStepOwnable + SingleTokenPush (1) + Manager (3). Both have `*_IFacet`. Money-out: `FeeCollector_N_MoneyOut.t.sol`.

### 2.3 Deploy-path / leftover-admin distinction (L-SEC-11)

| Diamond | `diamondCut` | Human owner | Product law |
|---------|--------------|-------------|-------------|
| **IndexedexManager** | **Yes** — first DFPkg cut; `initAccount` `MultiStepOwnableRepo._initialize(owner, 3 days)` | Yes (platform) | **Expected upgradeable platform.** Instant cut; 3-day buffer applies only to **ownership transfer**. Cite `SEC-CROPS-004`. |
| **FeeCollector** | **Yes** | Yes | Protocol-fee sink, not user vault inventory. Instant cut + `pullFee` onlyOwner. |
| **DETF instances** | Must be **absent** | Must be **absent** | Unowned after deploy (`INDEXEDEX_AGENT_LAW.md` Governance). **Not this area’s SUT.** Pilot MultiVault is stripped (`S-crops-trust` non-finding). |

`facetCuts()[2]` installs OPERABLE before fee facets; `facetAddresses()` lists fee query at `[2]` and OPERABLE at `[4]`. `facetInterfaces()` matches **addresses**, not cuts. Factory ERC165 zip uses interfaces↔addresses. Hygiene only (`SEC-MGR-009`).

### 2.4 Storage slots (PAT-SLOT)

| Repo | Slot | Collision? |
|------|------|------------|
| `VaultFeeOracleRepo` | `keccak256("indexedex.vault.registry.fee.oracle")` | Distinct |
| `VaultRegistryVaultRepo` | `keccak256("indexedex.registry.vault.vault")` | Distinct |
| `VaultRegistryVaultPackageRepo` | `keccak256("indexedex.registry.vault.vaultpkg")` | Distinct |
| `VaultRegistryDisableRepo` | `keccak256("indexedex.registry.vault.disable")` | Distinct |
| `VaultRegistryAwareRepo` | `keccak256("contracts.registries.vault.aware")` | Distinct; not on manager DFPkg |
| `VaultFeeOracleQueryAwareRepo` | `keccak256("indexedex.oracles.fee.vault.fee.oracle.query.aware")` | Distinct; SE instance storage |
| Hook factory aware | `keccak256(abi.encode("indexedex.hooks.uniswap.v4.hookDiamondPackageFactory.aware"))-1` | Distinct |
| FeeCollector MultiAsset | `keccak256(abi.encode("indexedex.vaults.basic"))` | Same **name** as vaults; **different contract** |

No overlapping struct layouts found across manager-diamond repos.

## 3. Threat models

### 3.1 IndexedexManager (platform diamond)

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| ADM | `diamondCut` | Config, disable, fee storage | none | owner, instant | Recut disable query to always-true; rewrite `feeTo`; add drain facet. **ACCEPTED_RISK** (platform). Does **not** cut DETF instances. |
| ADM | `initiateOwnershipTransfer` → accept | owner key | 3-day buffer | MultiStepOwnable | Hostile pending owner after buffer. Transfer is slower than cut. |
| ADM / operator | `setOperator` / function-operator | deploy + fee setters | Operable | owner grants | Operator ≈ owner for fees + `deployPkg` / hook factory. **Cannot** disable or `setFeeTo` or `pullFee`. |
| EXT | all mutators | none | none | — | Revert `NotOwner` / `NotOperator` on fee/deploy (proven). Register/disable owner-only (negatives incomplete — Medium TEST). |
| CFG | `PkgArgs.owner` / `feeTo` | future protocol mint | none | confused deployer | Wrong owner / `feeTo` at init. |

### 3.2 VaultFeeOracle

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| ADM / operator | `setUsageFee*` / `setDex*` / `setSeigniorage*` / liquid-reserve | **new** mint split / swap fee / incentive | 0 = unset sentinel | `onlyOwnerOrOperator`; cap `<= 1e18` | 100% tax on **new** `detfToken` mint (`_splitMintedDetf`). Cannot seize existing inventory or rewrite stored bond `unlockTime`. `SEC-CROPS-003`. |
| ADM | `setFeeTo` | future protocol `detfToken` mint recipient | none | **onlyOwner** (operator forbidden — tested) | Redirect `feeTo` to attacker. `setFeeTo(0)` unbounded (Low). |
| EXT | query cascade | none | none | vault → type → global | No write. 0 sentinel cannot express explicit 0% (`SEC-MGR-008`). |
| CFG | default constants | 0.1% usage / 5% dex / 50% seigniorage | none | `initAccount` | Documented defaults; operator can overwrite live. |

### 3.3 VaultRegistry — deploy / index

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| ADM / operator | `deployPkg(initCode, initArgs, salt)` | new package bytecode + auto-register | CREATE3 | onlyOwnerOrOperator | Hostile package; then `_isPkg` can call `deployVault`. **Intended god-path.** |
| EXT via registered DFPkg | `DFPkg.deployVault` → registry `deployVault` | new instance | pkg is `msg.sender` | `_onlyOwnerOrOperatorOrPkg` | Permissionless **instantiation** of registered packages (`test_deployVault_viaDFPkg_anyUser_succeeds`). Index growth / grief, not steal. ACCEPTED_RISK. |
| EXT | `deployVault` / `deployPkg` direct | none | none | — | `NotOperator` (exact selector). |
| ADM | `registerVault` / `unregisterVault` / package register | index integrity | caller-supplied `VaultConfig` | onlyOwner | Wrong config on unregister leaves ghost indexes; packed `feeTypeIdsOfVault` stale (`SEC-REG-001`). |
| ADM / operator | `setHookDiamondPackageFactory` | hook deploy target | re-init allowed | onlyOwnerOrOperator; rejects `address(0)` | Redirect hook factory; `deployHookVault` registers returned address. ADM. |
| ADM | `setPackageDisabled` then `deployVault` | none | — | onlyOwner disable | `DisabledPackage` — **inbound issuance gate works**. |

### 3.4 VaultRegistry — disable (CROPS)

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| ADM | `setVaultAddressDisabled(detf, true)` | **none on manager**; freezes consumers | none | **onlyOwner** (not operator) | Disable-gated DETF: `closeBondMature` / `redeemClaim` / `exchangeOut` / new `bond` revert `VaultDisabled`. Inventory stuck until re-enable. **`SEC-CROPS-001`.** MultiVault: flag set, **never read**. |
| ADM | `setPackageDisabled(pkg, true)` | none on manager | OR with address | onlyOwner | **All** registered instances of that pkg report `isDisabled` if they still have `pkgOfVault`. Deploy of that pkg blocked. |
| EXT | disable mutators | none | none | — | Revert (bare `expectRevert` today — Medium TEST). |
| EXT | `isDisabled` / `isDisabledDetailed` | none | none | — | View-only. Unregistered + not address-disabled → `false`. Unregister clears `pkgOfVault` so **package** disable no longer applies to that address. |

Re-verify vs `S-crops-trust` (do not rewrite): manager path is a **flag + deploy gate**, not a vault pause opcode. Freeze = consumer `_requireNotDisabled` via `IVaultRegistryDisableQuery(StandardVaultRepo._feeOracle())`. Interface NatSpec: “Vaults should call only `isDisabled(address(this))`.” That is the product-law conflict with “no admin pause on an unowned instance.”

### 3.5 FeeCollector

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| ADM | `pullFee(token, amount, recipient)` | protocol-fee ERC20 | none | onlyOwner | Extract protocol fees. **Not** DETF reserve. ACL proven exact `NotOwner`. |
| ADM | `diamondCut` | collector inventory | none | owner | Recut to public drain. ACCEPTED_RISK. |
| EXT | `pullFee` | none | none | — | `NotOwner`. |
| EXT | `syncReserve` / `pushSingleTokenFee` | none (book only) | none | permissionless | Overwrite MultiAsset reserve to `balanceOf`. No transfer out. `pullFee` ignores reserve. F5/E6 **no extract**. |
| HOS | FoT / ERC777 on `pullFee` | short delivery / reenter | none | owner path | `safeTransfer` exact amount; no reserve update; no lock. ADM+token only. |

## 4. Catalog matrix (A–O, E6, F5)

Manager / fee / registry are **not** DETF/SE money vaults. Classic A–H mostly N/A. Score access, CROPS, J, collector accounting.

Legend: **F** found/covered · **P** partial · **G** gap · **N/A** + reason · **VULN** production exploitable.

| ID | IndexedexManager | VaultFeeOracle | VaultRegistry | FeeCollector | Evidence |
|----|------------------|----------------|---------------|--------------|----------|
| **A1–A3** | N/A — no share mint | N/A | N/A | N/A — donation only books via sync | No user shares |
| **A0** | N/A | N/A | N/A | N/A — not a share vault | First sync books inventory; no mint |
| **B\*** | N/A | N/A — stores WAD, does not price | N/A | N/A | Seigniorage **%** is incentive, not spot |
| **C\*** | N/A | N/A | N/A | P — `pullFee` no `nonReentrant` | Only owner + token callback |
| **D\*** | N/A — not NFT/claim | N/A | N/A | N/A | |
| **E1/E5** | N/A | N/A | N/A | P — insufficient-balance revert (bare) | `test_N2_pullFee_revertsOnInsufficientBalance` |
| **E6** | N/A — no refund | N/A | N/A | N/A — no `balance−floor` payout | sync/push do not transfer |
| **F** | **ACCEPTED_RISK** leftover cut (platform) | F setters gated | F disable onlyOwner; deploy gated | ACCEPTED_RISK cut + pullFee owner | Contrast DETF unowned |
| **F5** | N/A | N/A | N/A | F — permissionless sync does **not** settle value to caller | `pushSingleTokenFee` / `syncReserve` snapshot only |
| **G** | N/A | N/A | P — package disable fans out to all `pkgOfVault` | N/A | Consumer freeze blast |
| **H2–H3** | N/A | N/A | N/A | N/A | |
| **I1–I5** | N/A — no `pretransferred` | N/A | N/A | N/A | |
| **J1** | **F** (gap-closure) | **F** | **F** vault query incl. seigniorage; package query has no seigniorage **set** (Target also omits) | **F** manager + push IFacet | `vaultSeigniorageTermsTypeId` on interface + facetFuncs + proxy |
| **J2** | **F** | **F** | **F** | P — IFacet on facets; no dedicated collector loupe suite | `IndexedexManager_Surface` J2 loupe |
| **J3** | **F** | **F** | **F** (deploy smoke via `PkgNotRegistered`) | **F** N-suite + selector smoke | Proxy, not facet impl |
| **K1** | N/A | N/A | N/A | P — reserve stale after `pullFee` | Documented `test_N2_*`; no consumer of reserve for enforcement |
| **L1–L3** | N/A | N/A | N/A | N/A — no AMM | |
| **M1–M3** | P — `deployPkg` arbitrary `initCode` is **ADM-only** | N/A | P — hook factory pointer ADM | N/A | Not EXT `target+calldata` |
| **N1–N2** | N/A | N/A | N/A | N/A | No quote–settle |
| **O1–O3** | N/A | N/A | N/A | N/A | No permit/sig |

**Class-specific (PRD §2.3 manager/fee/registry):**

| Property | Score | Evidence |
|----------|-------|----------|
| Fee setter ACL owner/operator | **F** | `VaultFeeOracleManagerFacet_Auth` + Seigniorage auth |
| `setFeeTo` onlyOwner (not operator) | **F** | `test_setFeeTo_revertsForOperator` |
| Liquid reserve setter ACL | **G** | FO-1..6 owner-only; Auth suite still omits LR attackers (`TCA-MGR-006`) |
| Register/unregister vault/pkg ACL | **G** | Owner paths only; no stranger + exact `NotOwner` (`TCA-MGR-005`) |
| Deploy vault ACL | **F** | `VaultRegistryDeployment_Auth` exact `NotOperator` |
| Disable ACL | **P** | Functional OR solid; stranger uses **bare** `expectRevert()` |
| Hook factory / `deployHookVault` ACL | **P** | J3 owner setHook smoke; no attacker matrix (`TCA-MGR-008`) |
| Fee WAD bounds `<= 1e18` | **F** | Bounds + Dilution |
| Cascade vault→type→global | **F** | BondTermsFallback, Units, LiquidReserve FO, usage 0-sentinel |
| Fee math non-dilution / proportionality | **F** | Dilution + `testFuzz_feeExtraction_isProportional` (oracle math) |
| FeeCollector `pullFee` ACL + balances | **F** | `FeeCollector_N_MoneyOut` (was G in coverage-audit) |
| Seigniorage query on proxy | **F** | Was VULN/J-omit; **fixed** `WP-J-MGR-001` |
| Disable-on-exit (consumers) | **VULN** on gated DETF families | **OWNED** `SEC-CROPS-001` — not manager CODE |

## 5. Domain notes

Walked (hunt lists, not a second ID space):

| Domain / skill | What was walked | Hits |
|----------------|-----------------|------|
| **access-control** / `crane-access` | MultiStepOwnable 3-day buffer; Operable on fee + deploy; disable **onlyOwner**; `_onlyOwnerOrOperatorOrPkg`; `setFeeTo` vs operator | Disable least-privilege is good. Operator ≈ owner for fees + `deployPkg`. Instant `diamondCut` vs buffered transfer (`SEC-CROPS-004`). |
| **proxies** / catalog J | DFPkg cuts vs interfaces vs addresses; Target ⊆ facetFuncs; loupe + proxy smoke; QueryAware not on manager | J-omit seigniorage **closed**. Cuts/addresses order hygiene. |
| **general** / precision-math | `_validateWadPercentage`; bond term inequalities; cascade 0-sentinel; `_percentageOfWAD` | Cannot exceed 100% per fee axis. Stacking usage+seigniorage 100%+100% is vault-side (`NEEDS_OWNER` / CROPS-003). |
| **erc20** | FeeCollector `BetterSafeERC20.safeTransfer`; real ERC20 N-suite | No mock-SUT. FoT pull not covered (Low). |
| **dos** | Unbounded `vaults()` / `disabledVaults()` / `syncReserves` arrays | Documented off-chain; EXT cannot grow disable set. Permissionless DFPkg deploy can grow `vaults()`. |
| **CROPS** / `ethskills-crops` | C: disable + frontend; O/F: BUSL (cite `SEC-CROPS-006`); P: public logs; S: walkaway, leftover cut, fee keys | Full CROPS record in `S-crops-trust`. This area **re-verified** disable path only. |
| **sharp-edges** | 0-sentinel; `pretransferred` N/A; `setFeeTo(0)`; hook factory re-init; DFPkg any-user deploy | `SEC-MGR-007/008`. |
| **spec-compliance** | Agent law: DETF unowned / no admin pause; fees via oracle; manager is **not** a DETF | Disable consumers contradict law — `SEC-CROPS-001`. |
| **defi-incident-patterns** | Admin-key / pause-without-exit → F / PAT-CROPS-ADMIN. Missing selector → J. Access leftover init → F2–F3 (QueryAware `_initialize` only in DFPkg `initAccount`; no public setter). | No HackLabs compile. |
| **oracles** (evm-audit) | Fee oracle is a **policy store**, not a price feed. No freshness/deviation. Live overwrite is the threat. | Bounds F. |
| **erc4626 / defi-amm / flashloans / signatures / assembly** | N/A this area | — |

## 6. Findings

### 6.1 [SEC-MGR-001] Registry disable freezes disable-gated DETF claim/exit (re-verify)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-MGR-001` |
| **Title** | Manager disable path re-verified: flag + deploy gate; freeze is consumer `_requireNotDisabled` |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high (call graph + registry tests) |
| **Catalog IDs** | F, G (package fan-out) |
| **Pattern IDs** | **PAT-CROPS-ADMIN** |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | C + S |
| **Incident theme** | admin-key / pause-without-exit |
| **Products** | VaultRegistryDisable{Manager,Query,Repo} on IndexedexManager; freeze blast = Single SE / Uni V4 DETFs / DualLiquidity (not MultiVault) |
| **Blast radius** | DETF family that delegates `_requireActive` → `_requireNotDisabled`; one `setPackageDisabled` hits every instance of that pkg |
| **Attacker** | **ADM** |
| **Attack scenario** | 1. Hostile/compromised IndexedexManager **owner** (not operator) calls `IVaultRegistryDisableManager.setVaultAddressDisabled(detf, true)` or `setPackageDisabled(pkg, true)`. 2. `isDisabled(detf)` is true (address set **or** `pkgOfVault` ∈ disabled packages). 3. Holder of a **mature** bond on a disable-gated family calls `closeBondMature` → `_requireActive` → `VaultDisabled`. 4. Claim holder `redeemClaim` same. 5. `detfToken` holder `exchangeOut` same. 6. New `bond` / `buyClaim` also revert. 7. `deployVault` / hook deploy of that pkg revert `DisabledPackage` (issuance gate — intended). Inventory stays in reserve / `vaultShare` / claim; ADM cannot pull it via this path. |
| **Preconditions** | Target family calls `_requireNotDisabled`. Manager owner key exists (production-intended). One tx. MultiVault **unaffected**. |
| **Impact** | Freeze of mint, bond, **closeBondMature**, **redeemClaim**, **exchangeOut** on gated families. Contradicts agent law “no admin pause surface on the diamond.” Not unbounded extract. |
| **Evidence** | Manager: `VaultRegistryDisableManagerTarget.sol` L18–31 `onlyOwner`; `VaultRegistryDisableRepo.sol` L114–122 OR resolution; `VaultRegistryDeploymentTarget.sol` L71–73 and L131–133 `DisabledPackage`; `IVaultRegistryDisableQuery.sol` L5–9 NatSpec. Tests: `VaultRegistry_Disable.t.sol` (OR, package fan-out, `packageOfVault` cleared on unregister); `VaultRegistryDeployment_Auth.t.sol` L105–116 deploy gate. Consumers: cite `S-crops-trust` §2.1 (Single SE Common L131–144; DualLiquidity L528–536; Uni V4 family Commons). MultiVault Common L92–97 **no** disable check. |
| **Runtime** | not required (not Critical CODE). Static call graph complete. No new runtime this run. |
| **Recommended CODE** | **None on manager** for the freeze. Fix is strip `_requireNotDisabled` from claim/exit on gated families (`S-crops-trust`). Keep package disable as **deploy** gate. Do **not** add disable to MultiVault. |
| **Recommended TEST** | Owned by `WP-SEC-CROPS-001`: `test_CROPS_001_disable_doesNotBlock_closeBondMature_or_redeemClaim` on each gated family **proxy**. This area: optional `test_setVaultAddressDisabled_revertsForNonOwner` exact `NotOwner` (cluster `WP-SEC-MGR-ACL-001`). |
| **Anti-theater** | Must use real manager proxy + `setVaultAddressDisabled`; must **not** mock registry; exit must **not** `expectRevert` after the DETF-side fix. |
| **Suggested WP-ID** | `WP-SEC-CROPS-001` — **do not** open a second `sec_fix_*` on manager disable storage |
| **Link TCA / prior** | **`SEC-CROPS-001`**, `WP-SEC-CROPS-001`. Coverage `T-manager-fee-registry` tests registry **logic**, not DETF exit. Not `WP-J-MGR-*`. |
| **Depends / parallel** | Serial with DETF-family commons that share the helper; parallel per family copy. After Wave 0 commons. |

### 6.2 [SEC-MGR-002] Seigniorage registry query PAT-J-OMIT — closed at this SHA

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-MGR-002` |
| **Title** | `vaultSeigniorageTermsTypeId` is on interface, facetFuncs, loupe, and proxy |
| **Severity** | **High** (historical) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed (static + tests present) |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-J-OMIT (closed) |
| **EVM-audit domain** | proxies |
| **CROPS pillar** | n/a |
| **Incident theme** | missing facet / proxy selectors |
| **Products** | `IVaultRegistryVaultQuery` / Target / Facet |
| **Blast radius** | admin/index surface (never a user money entrypoint) |
| **Impact** | **None remaining.** Typo `seeigniorageTermsTypeId` removed; selector `vaultSeigniorageTermsTypeId` cut. |
| **Evidence** | Interface L200; Target L224–226; Facet L44 / length 22; tests `VaultFeeOracle_Seigniorage_Surface` J1–J3, `VaultRegistry_Surface`, `VaultRegistryVaultQueryFacet_IFacet` control[20]. Coverage `STAGE3_PROGRESS.md` `WP-J-MGR-001` 10/10. |
| **Recommended CODE** | none |
| **Recommended TEST** | none new |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | `WP-J-MGR-001` — **do not** `sec_fix_*` |
| **Link TCA / prior** | `TCA-MGR-001`, `WP-J-MGR-001` |
| **Depends / parallel** | n/a |

### 6.3 [SEC-MGR-003] Manager / registry / oracle J matrix — closed at this SHA

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-MGR-003` |
| **Title** | IFacet + proxy J1–J3 now exist for manager DFPkg facets |
| **Severity** | **High** (historical TEST) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed (test tree) |
| **Catalog IDs** | J1–J3, D (declaration) |
| **Pattern IDs** | PAT-THEATER-FACET (closed for this substrate) |
| **EVM-audit domain** | proxies |
| **Products** | All manager DFPkg facets; FeeCollector SingleTokenPush |
| **Impact** | Declaration bar met. Residual: package-query seigniorage **set** still omitted (Low, Target-aligned). |
| **Evidence** | `test/foundry/spec/{manager,oracles/fee,registries/vault,fee/collector}/*_IFacet*.t.sol`; `IndexedexManager_Surface.t.sol`; `VaultRegistry_Surface.t.sol`. Controls from **interfaces**. `STAGE3_PROGRESS.md` `WP-J-MGR-002`. |
| **Suggested WP-ID** | `WP-J-MGR-002` — **do not** `sec_fix_*` |
| **Link TCA / prior** | `TCA-MGR-002`, `WP-J-MGR-002` |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Depends / parallel** | n/a |

### 6.4 [SEC-FEE-001] FeeCollector pull/push money-out — tests landed

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-FEE-001` |
| **Title** | `pullFee` ACL + real ERC20 + `pushSingleTokenFee` proxy proven |
| **Severity** | **High** (historical TEST) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | F, J3, K (documented stale reserve) |
| **Pattern IDs** | PAT-THEATER (closed for ACL/balances) |
| **EVM-audit domain** | access-control / erc20 |
| **CROPS pillar** | S (protocol-fee custody; not user vault) |
| **Products** | FeeCollector diamond |
| **Impact** | EXT cannot `pullFee`. Owner extract of **protocol** fees is intended. Reserve not auto-updated (`SEC-FEE-002`). |
| **Evidence** | `FeeCollectorManagerTarget.sol` L51–54 `onlyOwner`; `FeeCollector_N_MoneyOut.t.sol` N1–N4 (exact `NotOwner`, real mint/transfer, push via proxy, no `mockCall` on token). `STAGE3_PROGRESS.md` `WP-N-FEE-001` 8/8. |
| **Suggested WP-ID** | `WP-N-FEE-001` — **do not** `sec_fix_*` |
| **Link TCA / prior** | `TCA-MGR-003`, `TCA-MGR-007`, `WP-N-FEE-001` |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Depends / parallel** | n/a |

### 6.5 [SEC-REG-001] `_removeVault` leaves packed `feeTypeIdsOfVault` stale

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-REG-001` |
| **Title** | Unregister assigns packed fee-type IDs instead of deleting them |
| **Severity** | **Medium** |
| **Class** | **CODE** |
| **Confidence** | confirmed (source + theater test) |
| **Catalog IDs** | none (storage hygiene) |
| **Pattern IDs** | none |
| **EVM-audit domain** | general |
| **CROPS pillar** | n/a |
| **Products** | `VaultRegistryVaultRepo` |
| **Blast radius** | single mapping; fee oracle reads **individual** fields (those **are** deleted) |
| **Impact** | Ghost packed IDs after unregister. No public getter. Fee cascade uses `_usageFeeIdOfVault` etc. (cleared → 0 → global default). Low exploit; re-register overwrites. |
| **Evidence** | `VaultRegistryVaultRepo.sol` L177 assignment vs L179–183 `delete`; `test_unregisterVault_feeTypeIdsOfVault_bugStaleAssignment` L323–336 documents without assert on packed slot. |
| **Recommended CODE** | `delete layoutStruct.feeTypeIdsOfVault[vault];` |
| **Recommended TEST** | Harness or `vm.load` packed slot; re-register isolation. |
| **Anti-theater** | Must assert storage-visible clear, not comment-only. |
| **Suggested WP-ID** | `WP-SEC-REG-001` |
| **Link TCA / prior** | `TCA-MGR-004` / area-local `WP-CODE-REG-001` — **not** in global coverage `WORK_PACKAGE_BACKLOG.md`. Stage 2: one owner; skip if `gap_cover_reg-unregister-pack` exists. |
| **Depends / parallel** | Independent of CROPS-001. Parallel with ACL TEST WP. |

### 6.6 [SEC-MGR-004] Exact-selector ACL residuals (disable / register / liquid reserve / hook factory)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-MGR-004` |
| **Title** | Stranger negatives missing or bare `expectRevert` on several owner mutators |
| **Severity** | **Medium** |
| **Class** | **TEST** |
| **Confidence** | confirmed (test source) |
| **Catalog IDs** | F (proof gap, not missing modifier) |
| **Pattern IDs** | PAT-THEATER (bare revert) |
| **EVM-audit domain** | access-control |
| **Products** | Disable manager; Vault/Package manager; fee liquid-reserve setters; `setHookDiamondPackageFactory` / hook deploy |
| **Impact** | Production modifiers look correct (`onlyOwner` / `onlyOwnerOrOperator`). Proof bar fails. |
| **Evidence** | `VaultRegistry_Disable.t.sol` L112–122 bare `expectRevert()`; Registration suites owner-prank only; `VaultFeeOracleManagerFacet_Auth.t.sol` ends without liquid-reserve cases (FO suite is owner functional); Deployment Auth covers SE `deployVault`/`deployPkg` not hook factory attacker. |
| **Recommended CODE** | none |
| **Recommended TEST** | Exact `NotOwner` / `NotOperator` matrix. |
| **Anti-theater** | Typed selectors; state unchanged. |
| **Suggested WP-ID** | `WP-SEC-MGR-ACL-001` |
| **Link TCA / prior** | `TCA-MGR-005`, `TCA-MGR-006`, `TCA-MGR-008` / area-local `WP-N-MGR-001` (not in global coverage backlog). |
| **Depends / parallel** | Parallel with `WP-SEC-REG-001`. |

### 6.7 Clustered Medium / Low / Info

#### [SEC-FEE-002] `pullFee` does not resync MultiAsset reserve

| Field | Value |
|-------|--------|
| **Severity / Class** | Medium · **NEEDS_OWNER** |
| **Catalog / Pattern** | K1 |
| **Products** | `FeeCollectorManagerTarget.pullFee` |
| **Impact** | Reserve overstates inventory until `syncReserve`. `pullFee` does not read reserve. No user extract found. |
| **Evidence** | Target L51–54 vs L27–29; N-suite documents policy (`TCA-MGR-012`). |
| **Link** | `WP-N-FEE-001` (tests done; CODE deferred). |
| **Suggested WP-ID** | none until owner says reserve is security-relevant. |

#### [SEC-MGR-005] Live fee setters cap at 100% WAD; no timelock

| Field | Value |
|-------|--------|
| **Severity / Class** | Medium · **OWNED_ELSEWHERE** / **NEEDS_OWNER** |
| **Pattern** | PAT-CROPS-ADMIN |
| **Attacker** | ADM (owner **or** operator) |
| **Impact** | 100% of **new** mint to `feeTo`. Exit/claim/close do not `_splitMintedDetf` on MultiVault. |
| **Evidence** | `VaultFeeOracleRepo._validateWadPercentage` L58–61; ManagerFacet setters; Dilution `test_usageFee_100Percent_*`; defaults 0.1% / 5% / 50%. |
| **Link** | **`SEC-CROPS-003`**, `WP-SEC-CROPS-003`. Do not fork fee-oracle CODE without owner decision. |

#### [SEC-MGR-006] Instant `diamondCut` on manager / collector (expected platform)

| Field | Value |
|-------|--------|
| **Severity / Class** | Medium · **OWNED_ELSEWHERE** / **ACCEPTED_RISK** |
| **Pattern** | PAT-CROPS-ADMIN |
| **Impact** | Owner recuts platform in one tx. **Not** a DETF leftover-admin (L-SEC-11). 3-day buffer is ownership transfer only. |
| **Evidence** | `IndexedexManagerDFPkg.sol` L153–160, L281; `FeeCollectorDFPkg.sol` L116–123, L208; Crane `DiamondCutTarget` `onlyOwner`. |
| **Link** | **`SEC-CROPS-004`**. Document Safe ≥2-of-3 if launch requires it. |

#### [SEC-MGR-007] `setFeeTo` accepts `address(0)`

| Field | Value |
|-------|--------|
| **Severity / Class** | **Low** · **CODE** |
| **Pattern** | PAT-SHARP-FLAG |
| **Impact** | Next mint may burn/`detfToken` to zero or revert in `_mintDetf`. ADM only. Hook factory setter **does** reject zero. |
| **Evidence** | `VaultFeeOracleManagerFacet.setFeeTo` L63–65; Repo `_setFeeTo` no zero check. Contrast `VaultRegistryDeploymentTarget.setHookDiamondPackageFactory` L115–117. |
| **Suggested WP-ID** | fold into Wave 4 hygiene or `WP-SEC-CROPS-003` if owner touches feeTo. |

#### [SEC-MGR-008] 0-sentinel cannot express explicit 0% fee / 0 lock at vault override

| Field | Value |
|-------|--------|
| **Severity / Class** | **Low** · **ACCEPTED_RISK** / PAT-SHARP |
| **Impact** | `usageFeeOfVault==0` falls back to type/global (defaults > 0). `bondTerms.minLockDuration==0` same. Documented in Dilution + Bounds. |
| **Evidence** | `VaultFeeOracleQueryFacet.usageFeeOfVault` L96–107; `bondTermsOfVault` L178–186; `test_usageFee_zeroSentinel_noExplicitZeroFee`. |

#### [SEC-MGR-009] `facetCuts` vs `facetAddresses` order mismatch

| Field | Value |
|-------|--------|
| **Severity / Class** | **Low** · CODE hygiene |
| **Impact** | Interfaces zip with addresses (consistent). Cuts list OPERABLE earlier. Not a money bug. |
| **Evidence** | `IndexedexManagerDFPkg` L106–137 vs L150–178. |

#### [SEC-MGR-010] Stale “OperableFacet not included” comments

| Field | Value |
|-------|--------|
| **Severity / Class** | **Low** · **THEATER** / docs |
| **Evidence** | `VaultFeeOracleManagerFacet_Auth.t.sol` L16–17, L35–36; `VaultRegistryDeployment_Auth.t.sol` L26–28 vs DFPkg OPERABLE cut + passing `setOperator` tests. `TCA-MGR-010`. |

#### [SEC-FEE-003] Permissionless `syncReserve` / `pushSingleTokenFee`

| Field | Value |
|-------|--------|
| **Severity / Class** | **Info** · **ACCEPTED_RISK** |
| **Catalog** | F5 N/A (no value settle to caller) |
| **Impact** | Gas grief / stale-then-sync books. Intended push-hook. `TCA-MGR-011`. |
| **NEEDS_OWNER** | only if product wants restrict-to-registered-vaults. |

#### [SEC-REG-002] Package query has no seigniorage type-id set

| Field | Value |
|-------|--------|
| **Severity / Class** | **Low** · CODE/TEST optional |
| **Impact** | Asymmetry vs usage/dex/bond/lending lists. Oracle `seigniorageVaultTypeIds()` exists. `TCA-MGR-009`. Target also omits — **not** PAT-J-OMIT. |
| **Link** | optional fold `WP-J-MGR-001` (already closed). |

#### [SEC-MGR-011] Permissionless instantiation via registered DFPkg

| Field | Value |
|-------|--------|
| **Severity / Class** | **Info** · **ACCEPTED_RISK** |
| **Impact** | Any EOA can `DFPkg.deployVault` once pkg is registered (`test_deployVault_viaDFPkg_anyUser_succeeds`). Grows `vaults()`; each instance is a new diamond. Package disable stops **new** deploys of that pkg. Security boundary is `deployPkg` / `registerPackage`, documented. |

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| `test_unregisterVault_feeTypeIdsOfVault_bugStaleAssignment` | Documents CODE without failable packed-slot assert | `WP-SEC-REG-001` |
| `VaultRegistry_Disable` stranger cases | Bare `expectRevert()` — wrong selector still passes | Exact `NotOwner` |
| Auth file headers “OperableFacet not included” | Operational lie; operators **do** work | Comment fix (`SEC-MGR-010`) |
| Registration “security” without stranger tests | Indexing ≠ access proof | `WP-SEC-MGR-ACL-001` |
| `FeeCollectorProxy_Selectors.test_pullFee_callableViaProxy` | amount 0 + historical mock style | **Superseded** by `FeeCollector_N_MoneyOut` (keep selector smoke) |
| Liquid-reserve FO suite as ACL proof | Owner-only functional | Add attacker matrix |
| Coverage-audit claim “no manager IFacet / seigniorage omit / FeeCollector ACL G” | **Stale at `1e0d7c48`** — gap-closure landed | This report |

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| `TCA-MGR-001` / `WP-J-MGR-001` | Seigniorage query J-omit | **OWNED_ELSEWHERE** — **closed** at this SHA |
| `TCA-MGR-002` / `WP-J-MGR-002` | Manager/oracle/registry IFacet + J | **OWNED_ELSEWHERE** — **closed** |
| `TCA-MGR-003` / `007` / `WP-N-FEE-001` | FeeCollector pull/push tests | **OWNED_ELSEWHERE** — **closed** (CODE reserve still `NEEDS_OWNER`) |
| `TCA-MGR-004` / area `WP-CODE-REG-001` | Packed `feeTypeIdsOfVault` | Still open CODE. **Not** in global coverage backlog. This program may own `WP-SEC-REG-001` if Stage 2 treats Wave-2 as abandoned |
| `TCA-MGR-005/006/008` / area `WP-N-MGR-001` | ACL exact selectors | Still open TEST. Same adoption rule → `WP-SEC-MGR-ACL-001` |
| `TCA-MGR-009` | Package seigniorage set | Low; optional |
| `TCA-MGR-010` | Stale Operable comments | Low |
| `TCA-MGR-011` | Permissionless sync | ACCEPTED_RISK |
| `TCA-MGR-012` | pullFee reserve | NEEDS_OWNER (`SEC-FEE-002`) |
| `SEC-CROPS-001` / `WP-SEC-CROPS-001` | Disable-on-exit | **OWNED_ELSEWHERE** — cite, do not rewrite |
| `SEC-CROPS-003` / `004` | 100% fee; instant cut | **OWNED_ELSEWHERE** |
| `WP-I-*` / vault pull | N/A this SUT | Commons / product areas |

## 9. Work package stubs

No new High CODE WP. Do **not** schedule `sec_fix_*` for closed J/N fee WPs.

### WP-SEC-CROPS-001 (cite only — not owned here)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-CROPS-001` |
| **Title** | Strip registry disable from DETF claim/exit (and Uni V2 Out) |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Disable-gated DETF `*Common` / Bonding / ExchangeOut; Uni V2 In/Out — **not** manager disable repo |
| **Finding IDs** | `SEC-MGR-001`, `SEC-CROPS-001`, `SEC-CROPS-002` |
| **Problem** | Manager owner flag freezes permissionless unwind on families that call `isDisabled`. |
| **Production files (touch set)** | DETF/SE commons (see `S-crops-trust`). **Out of this area’s allowlist.** |
| **Test files** | Family adversarial / disable suites |
| **Out of scope files** | `VaultRegistryDisable*.sol` (keep deploy gate); MultiVault Common |
| **Depends on** | Owner OK on kill-switch shape |
| **Parallelizable with** | Per-family copies |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_crops-disable-exit` |
| **Implementation notes** | `ethskills-crops`; L-SEC-11; do not add disable to MultiVault |
| **Acceptance** | Mature `closeBondMature` + `redeemClaim` succeed after `setVaultAddressDisabled(detf, true)` on **proxy** |
| **Anti-theater** | Real manager disable; no mock registry; inbound may still revert `VaultDisabled` |
| **Proof-first?** | no |
| **Estimate** | L (multi-family) |

### WP-SEC-REG-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-REG-001` |
| **Title** | Delete packed `feeTypeIdsOfVault` on unregister |
| **Severity** | Medium |
| **Class** | BOTH |
| **Products** | VaultRegistryVaultRepo |
| **Finding IDs** | `SEC-REG-001`, `TCA-MGR-004` |
| **Problem** | `_removeVault` re-assigns packed IDs; test cannot fail. |
| **Production files (touch set)** | `contracts/registries/vault/VaultRegistryVaultRepo.sol` |
| **Test files (touch set)** | `test/foundry/spec/registries/vault/VaultRegistry_Registration.t.sol` |
| **Out of scope files** | Append-only `contentsIds` / `vaultTokens` policy; fee-oracle cascade |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-MGR-ACL-001`, all DETF WPs |
| **Conflicts with coverage-audit WP** | area-local `WP-CODE-REG-001` — **one owner**; skip if that `gap_cover_*` tree exists |
| **Suggested worktree** | `sec_fix_reg-unregister-pack` |
| **Implementation notes** | `delete` packed mapping; keep individual deletes; Crane TestBase / IndexedexTest |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/registries/vault/VaultRegistry_Registration.t.sol' --match-test 'feeTypeIdsOfVault|unregisterVault_clears'` — packed slot 0 after unregister; re-register isolation |
| **Anti-theater** | `vm.load` or exposed view; not comment-only |
| **Proof-first?** | no |
| **Estimate** | S |

### WP-SEC-MGR-ACL-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-MGR-ACL-001` |
| **Title** | Exact-selector access matrix (register / disable / liquid reserve / hook factory) |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | Registry managers + fee LR setters + deployment hook admin |
| **Finding IDs** | `SEC-MGR-004`, `TCA-MGR-005/006/008` |
| **Problem** | Incomplete negatives / bare `expectRevert`. |
| **Production files** | none |
| **Test files** | `VaultRegistry_Disable.t.sol`, Registration suites, `VaultFeeOracleManagerFacet_Auth.t.sol`, `VaultRegistryDeployment_Auth.t.sol` |
| **Out of scope files** | DETF disable enforcement (`WP-SEC-CROPS-001`) |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-REG-001` |
| **Conflicts with coverage-audit WP** | area-local `WP-N-MGR-001` — one owner |
| **Suggested worktree** | `sec_fix_mgr-acl` |
| **Implementation notes** | Mirror fee-oracle Auth style; `abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, stranger)` |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/{registries,oracles/fee}/**' --match-test 'revertsForNon|NotOwner|NotOperator|setHook'` includes new named tests |
| **Anti-theater** | Typed selectors; no bare `expectRevert()` |
| **Proof-first?** | no |
| **Estimate** | S–M |

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Reason |
|------|-------|--------|
| Catalog I1–I3 on manager/oracle/collector pull | N/A | No `pretransferred` credit |
| A0 / E6 / L / N / O on this SUT | N/A | Not share vaults; no refund; no AMM; no sigs; no quote–settle |
| Manager / FeeCollector `diamondCut` | **ACCEPTED_RISK** | Platform upgrade vs DETF immutability (L-SEC-11, `SEC-CROPS-004`) |
| 100% WAD fee | **NEEDS_OWNER** | `SEC-CROPS-003` — snapshot / cap / timelock |
| `pullFee` reserve resync | **NEEDS_OWNER** | Only if reserve is security-relevant |
| Permissionless sync/push | **ACCEPTED_RISK** | Push-hook model; no extract |
| Permissionless DFPkg `deployVault` | **ACCEPTED_RISK** | Instantiation after package registration |
| 0-sentinel (no explicit 0% / 0 lock) | **ACCEPTED_RISK** | Documented; operator can set 1 wei |
| Append-only `contentsIds` / `vaultTokens` / type-id sets | **ACCEPTED_RISK** / DEFER | Documented anti-spam history |
| QueryAware deep suite | DEFER | Support facet; inits only in SE DFPkg `initAccount` |
| BUSL / frontend CROPS | Info | `SEC-CROPS-006/007` |
| Fork-only mainnet manager deploy | DEFER | Hermetic `IndexedexTest` sufficient |
| Runtime forge this run | **BUILD_BLOCKED** / not required | No Critical CODE; monorepo compile 20–40+ min; static + existing test sources used. No `via_ir`. |

## 11. Commands run

```bash
# Inventory
ls contracts/manager contracts/fee/collector contracts/oracles/fee contracts/registries/vault
ls test/foundry/spec/manager test/foundry/spec/fee/collector test/foundry/spec/oracles/fee test/foundry/spec/registries/vault

# Surface / access / disable / J / collisions
rg -n 'seeigniorage|seigniorageTerms|vaultSeigniorage|feeTypeIdsOfVault|_removeVault' contracts test --glob '*.sol' --glob '!lib/**'
rg -n 'pullFee|pushSingleTokenFee|syncReserve' contracts/fee/collector test/foundry/spec/fee --glob '*.sol'
rg -n 'setVaultAddressDisabled|setPackageDisabled|isDisabled|_requireNotDisabled' contracts --glob '*.sol'
rg -n 'onlyOwner|onlyOwnerOrOperator|diamondCut|facetFuncs' contracts/{manager,fee,oracles/fee,registries/vault} --glob '*.sol'
rg -n 'TestBase_IFacet|controlFacetFuncs|revertsForNonOwner' test/foundry/spec/{manager,fee,oracles/fee,registries} --glob '*.sol'
rg -n 'WP-J-MGR-001|WP-J-MGR-002|WP-N-FEE-001|WP-CODE-REG-001|WP-N-MGR-001|TCA-MGR' docs --glob '*.md'

# Storage slots
rg -n 'STORAGE_SLOT|keccak256\("indexedex' contracts/{manager,fee,oracles,registries} --glob '*.sol'
```

No `forge test` this subagent (no Critical CODE requiring §3.8; existing gap-closure logs cited: `WP-J-MGR-001` 10/10, `WP-N-FEE-001` 8/8). No production/test edits. No remediations implemented.

---

## Return summary (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Path** | `docs/security/audit/areas/A-manager-fee-registry.md` |
| **Critical** | **0** |
| **High** | **1 open** (OWNED_ELSEWHERE `SEC-MGR-001` → `SEC-CROPS-001`) + **3 closed-at-SHA** (`SEC-MGR-002/003`, `SEC-FEE-001`) |
| **OWNED_ELSEWHERE** | **8** (`SEC-MGR-001/002/003/005/006`, `SEC-FEE-001`, plus TCA-MGR-004/012 adoption notes) |
| **Top WP-IDs** | `WP-SEC-CROPS-001` (cite; DETF/SE files); `WP-SEC-REG-001`; `WP-SEC-MGR-ACL-001`. **Do not** `sec_fix_*` `WP-J-MGR-001`, `WP-J-MGR-002`, `WP-N-FEE-001` |
