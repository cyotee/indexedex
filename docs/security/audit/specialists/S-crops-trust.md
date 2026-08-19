# Security Audit specialist — S-crops-trust

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Status | **COMPLETE** (pilot; manager/fee/registry reviewed only as reachable from MultiVault + Aero/Camelot/Uni V2) |
| Inputs (area reports read) | None yet under `docs/security/audit/areas/` (empty at write time). Consumed: `00_SCOPE_PARTITION.md`, `01_METHODOLOGY_NOTES.md`, `docs/security/SECURITY_AUDIT_PRD.md` §2 / §3.5 / §7.3–7.4 / L-SEC-11, `docs/agent/INDEXEDEX_AGENT_LAW.md` (Governance and immutability), `docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md` + `areas/T-detf-multi-vault.md` + `areas/T-manager-fee-registry.md`, production sources listed in §6 |
| Skill | `ethskills-crops` (C/O/P/S + walkaway); `crane-access` (MultiStepOwnable / Operable / diamondCut); IndexedEx DETF unowned law |
| Finding ID prefix | `SEC-CROPS-NNN` |
| Critical / High | **0 Critical · 1 High** |

---

## CROPS record (pilot: MultiVault DETF + manager/fee)

Chosen default: MultiVault DETF diamond is deploy-time configured, then **unowned / uncuttable**; fees and registry live on a **separate owned manager diamond**. That split is the most CROPS-aligned onchain posture in the pilot set — provided disable-gated families do not re-import a pause onto the DETF.

**Censorship Resistance**
- Risk: IndexedexManager owner can `setVaultAddressDisabled` / `setPackageDisabled`. Uni V2 SE (and non-pilot DETF families that call `_requireNotDisabled`) treat that flag as a kill switch on money paths. MultiVault DETF itself does **not** consult `isDisabled`.
- Mitigation: MultiVault bond / sell→claim / redeemClaim / closeBondMature / `exchangeOut` to `vaultShare` are permissionless contract calls. Aero/Camelot SE (typical MultiVault legs) do not honor disable.
- User escape: call DETF + SE directly; no frontend, relayer, or keeper required. If a leg is a disable-gated SE (Uni V2), the last hop `vaultShare → rateAsset` can be frozen (see SEC-CROPS-002).

**Open (visibility)**
- Risk: contracts and frontend live in this monorepo; README points at `LICENSE` but no `LICENSE` file is present at repo root.
- Mitigation: source is public; ABIs/events are in-tree.
- User escape: fork and call contracts with any client.

**Free, as in Freedom (license)**
- Risk: `package.json` + README claim **BUSL-1.1**; most IndexedEx Solidity headers are `BSL-1.1`. BUSL is source-available, not OSI-free (EF Mandate). Crane deps are AGPL.
- Mitigation: none on-tree (no change-date file found).
- User escape: legal fork of production is restricted until any BUSL change date (undocumented here). Info only (SEC-CROPS-005).

**Privacy**
- Risk: all bond/claim/mint/burn amounts, counterparties, and unlock times are public logs; no extra identity flow on the DETF diamond.
- Mitigation: no protocol-level identity or offchain attestation required to exit.
- User escape: any RPC; no IndexedEx indexer is on the money path.
- Frontend analytics / hosted RPC: **Info only** (does not gate onchain exit).

**Security**
- Risk: manager owner has instant `diamondCut`, fee setters (operator can push usage/dex/seigniorage to 100% WAD), `setFeeTo` (owner), registry disable, FeeCollector `pullFee`. MultiVault instance has **no** `owner` init and **no** `diamondCut` facet.
- Mitigation: DETF thresholds / expansion / weights are deploy-time only. Bond `unlockTime` is stored on the NFT at create. Bond NFT + rebasing claim are owned **by the DETF diamond** (not a human); their `onlyOwner` mint/burn is the intended satellite wiring.
- User escape (walkaway): if the team **disappears**, a MultiVault holder can still `bond`, wait the stored unlock, `sellPositionToDetfNft` / `closeBondMature`, `redeemClaim`, and `exchangeOut` via permissionless calls. Fee oracle reads keep working at last-set values. `compoundProtocolRewards` is public (no keeper). Walkaway **fails** only if a hostile admin has already disabled a disable-gated nested SE, or if the holder needs a Policy-mode `exchangeOut` while synthetic is outside the burn gate (product law, not admin).

Accepted compromises:
- Manager/FeeCollector are owned admin diamonds by design (not DETF instances).
- Live fee oracle (WAD-capped at 100%) can tax **new** mint; cannot rewrite stored MultiVault thresholds or existing bond unlocks.
- BUSL / hosted frontend: documented Info; onchain exit does not depend on them.

---

## 1. Cross-cut thesis

PAT-CROPS-ADMIN on the **pilot MultiVault diamond is not present**: Crane `DiamondPackageCallBackFactory` installs only ERC165 / Loupe / ERC8109 / transient post-deploy hook (no `diamondCut`); `MultiVaultWeightedDetfDFPkg.facetCuts()` is ERC20 + permit + vault + exchange/bonding/info only; `initAccount` never calls `MultiStepOwnableRepo._initialize`. L-SEC-11 leftover-cut/owner on this live DETF is **stripped** (static-high).

The remaining trust plane is the **manager diamond**, which *is* supposed to have owner + `diamondCut` + fee/disable. That plane does **not** bind MultiVault money functions — except (1) live fee reads on mint split / new-bond terms, and (2) nested SE `exchangeIn` when redeeming to `rateAsset`. **Disable-gated DETF families** (Single SE, Uni V4 DETFs, DualLiquidity — not re-inventoried) re-import a manager-owner **pause onto claim/exit**, which contradicts agent law “no admin pause surface on the diamond.” That is the High PAT-CROPS-ADMIN hit. Uni V2 SE (pilot) applies the same kill switch to In **and** Out. Aero/Camelot do not. F1 on MultiVault exists but is theater (malformed `diamondCut` calldata; `owner()==self` allowed). Frontend/hosting is Info. Coverage I/J/K WPs on pull/surface are **OWNED_ELSEWHERE**.

---

## 2. Findings

### 2.1 [SEC-CROPS-001] Disable-gated DETF families retain a manager-owner pause on claim/exit

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-CROPS-001` |
| **Title** | Registry `isDisabled` gates DETF bond/claim/exit on families that call `_requireNotDisabled` |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | F (immutability / leftover admin), F5 N/A |
| **Pattern IDs** | **PAT-CROPS-ADMIN** |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | C + S |
| **Incident theme** | admin-key / pause-without-exit (generic); `none` from HackLabs map |
| **Products** | SingleStandardExchangeDETF; Uni V4 Single SE CP / Orbital / Weighted / Curve Quad Stable DETFs; DualLiquidity (cross-cut). **Not** MultiVaultWeightedDetf (no check). |
| **Blast radius** | DETF family (every instance that delegates `_requireActive` → `_requireNotDisabled`); manager owner is the only ADM |
| **Attacker** | **ADM** |
| **Attack scenario** | 1. Compromised or hostile IndexedexManager owner calls `IVaultRegistryDisableManager.setVaultAddressDisabled(detf, true)` (or `setPackageDisabled(pkg, true)`). 2. `isDisabled(detf)` is true via fee-oracle-cast registry on the manager diamond. 3. Holder of a **mature** bond calls `closeBondMature` → `_requireActive` → `VaultDisabled`. 4. Claim holder calls `redeemClaim` → same revert. 5. `detfToken` holder calls `exchangeOut` → same revert. 6. New `bond` / `buyClaim` also revert. Inventory stays in reserve/BPT/claim; ADM cannot pull it, but **no permissionless exit** until re-enable. |
| **Preconditions** | Target is a disable-gated DETF family (not MultiVault). Manager owner key exists (production-intended). No need for inventory already disabled; one tx. |
| **Impact** | Freeze of mint, bond, sell-adjacent buyClaim, **closeBondMature**, **redeemClaim**, and **exchangeOut** on that DETF. Contradicts agent law + L-SEC-11 spirit (no admin pause on an “unowned” instance). Not an unbounded extract. |
| **Evidence** | `SingleStandardExchangeDETFCommon.sol` L131–144 `_requireActive` → `_requireNotDisabled` via `IVaultRegistryDisableQuery(StandardVaultRepo._feeOracle())`. `SingleStandardExchangeDETFBondingTarget.sol` L90 (`bond`), L212 (`buyClaim`), **L252 (`closeBondMature`)**, **L301 (`redeemClaim`)**. `SingleStandardExchangeDETFExchangeOutTarget.sol` L31. Same `_requireNotDisabled` shape: `UniswapV4SingleStandardExchangeDETFCommon.sol` L61–71; Orbital/Weighted/Curve Quad Commons ~L87–102; `DualLiquidity (removed)CrossVersionUniswapVaultCommon.sol` L528–536. MultiVault contrast: `MultiVaultWeightedDetfCommon.sol` L92–97 `_requireActive` has **no** disable check. |
| **Runtime** | not required (not Critical CODE). Static call graph is complete. |
| **Recommended CODE** | Remove `_requireNotDisabled()` from claim/exit/out/`closeBondMature`/`redeemClaim` (and from `_requireActive` if that helper is shared with exit). If a deploy-time kill switch is still wanted, gate **only** `deployVault` / new mint / new bond — never unwind. Do **not** add disable to MultiVault. |
| **Recommended TEST** | `test_CROPS_001_disable_doesNotBlock_closeBondMature_or_redeemClaim` on each disable-gated family proxy after registry deploy; `vm.prank(owner); setVaultAddressDisabled(detf, true)`; mature bond `closeBondMature` and `redeemClaim` must succeed; mint/bond may revert if product keeps an inbound gate. Match-path: family `test/foundry/spec/vaults/detf/**` + Uni V4 equivalents. |
| **Anti-theater** | Must call **proxy** after `indexedexManager.deploy*`; must use exact `VaultDisabled` on the inbound path if kept; must **not** `expectRevert` on exit. Do not mock registry. |
| **Suggested WP-ID** | `WP-SEC-CROPS-001` |
| **Link TCA / prior** | none (coverage `T-manager-fee-registry` tests disable **registry logic**, not DETF exit). Not `WP-I-*` / `WP-J-DETF-MV-001`. |
| **Depends / parallel** | Serial across families that share a Common helper; parallel per family if helpers are copies. After Wave 0 commons. Full-pass `A-detf-single-se` / Uni V4 / DualLiq own the production files. |

### 2.2 [SEC-CROPS-002] Uni V2 SE kill switch bricks In and Out (and MultiVault `rateAsset` hop)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-CROPS-002` |
| **Title** | Uni V2 `_requireNotDisabled` on `exchangeIn` and `exchangeOut` freezes SE exit |
| **Severity** | **Medium** |
| **Class** | **CODE** (or `NEEDS_OWNER` if a full SE kill switch is explicit product law) |
| **Confidence** | static-high |
| **Catalog IDs** | F |
| **Pattern IDs** | PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | C + S |
| **Incident theme** | none |
| **Products** | UniswapV2StandardExchange; MultiVault redeem-to-`rateAsset` **when a leg is that SE** |
| **Blast radius** | single SE package + any MultiVault instance whose `underlyingVaults[i]` is Uni V2 |
| **Attacker** | ADM |
| **Attack scenario** | 1. Owner `setVaultAddressDisabled(uniV2Se, true)`. 2. `exchangeOut` reverts `VaultDisabled` (`UniswapV2StandardExchangeOutTarget.sol` L403). 3. MultiVault `redeemClaim(rateAsset)` transfers `vaultShare` into the SE and calls `exchangeIn` (`MultiVaultWeightedDetfBondingTarget.sol` L542–545) → same revert. 4. Holder can still burn DETF to `vaultShare` (MultiVault does not check disable) but cannot convert `vaultShare` → `pairToken` / `rateAsset`. |
| **Preconditions** | Uni V2 SE registered; manager owner. |
| **Impact** | Freeze of Uni V2 SE exit and MultiVault last hop through that SE. Aero/Camelot legs unaffected (no `isDisabled` consult). |
| **Evidence** | `UniswapV2StandardExchangeCommon.sol` L36–39; InTarget L369; OutTarget L403. Tests: `UniswapV2StandardExchange_Disable.t.sol` covers **In only** (L24–107) — Out freeze untested. Aero/Camelot Commons/DFPkgs: no `_requireNotDisabled`. |
| **Recommended CODE** | Stop calling `_requireNotDisabled` on Out (and on In when `tokenIn` is `vaultShare` / user exit). Keep package disable as a **deploy** gate on the registry. |
| **Recommended TEST** | `test_CROPS_002_disable_doesNotBlock_exchangeOut`; `test_CROPS_002_multivault_redeemClaim_rateAsset_if_leg_univ2`. Exact `VaultDisabled` only if inbound gate remains. |
| **Anti-theater** | Real SE proxy; real disable via manager; do not only re-test `exchangeIn`. |
| **Suggested WP-ID** | `WP-SEC-CROPS-001` (cluster with 001; Uni V2 file set is disjoint and can ship as `WP-SEC-CROPS-001b`) |
| **Link TCA / prior** | none |
| **Depends / parallel** | Parallel with DETF-family slice of WP-SEC-CROPS-001 |

### 2.3 [SEC-CROPS-003] Fee oracle can set usage/dex/seigniorage to 100% WAD with no timelock

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-CROPS-003` |
| **Title** | Live fee setters cap at 1e18; operator can 100% tax new mint |
| **Severity** | **Medium** |
| **Class** | **NEEDS_OWNER** |
| **Confidence** | static-high |
| **Catalog IDs** | none (economics / trust) |
| **Pattern IDs** | PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | S |
| **Incident theme** | none |
| **Products** | VaultFeeOracleManager on IndexedexManager; MultiVault mint split via `_usageFeeWad` / `_seigniorageIncentiveWad` |
| **Blast radius** | all vaults/DETFs that read the oracle |
| **Attacker** | ADM (owner **or** operator — `onlyOwnerOrOperator` on fee setters; `setFeeTo` is `onlyOwner`) |
| **Attack scenario** | 1. Operator `setUsageFeeOfVault(multivault, 1e18)`. 2. Next vault-share `bond` / mint `_splitMintedDetf` sends 100% of gross to `feeTo` (`DETFUsageFeeLib` + `MultiVaultWeightedDetfCommon.sol` L222–229). 3. Existing `detfToken`, mature bonds, and claims still exit without usage fee (`exchangeOut` / `closeBondMature` / `redeemClaim` do not call `_splitMintedDetf`). 4. Owner `setFeeTo(attacker)` redirects future protocol mint. |
| **Preconditions** | Operator or owner key. |
| **Impact** | Extract on **new** mint only; cannot seize existing inventory or change stored unlocks / thresholds. |
| **Evidence** | `VaultFeeOracleRepo.sol` L58–61 `_validateWadPercentage` (`value_ > ONE_WAD` only); `VaultFeeOracleManagerFacet.sol` L68–87 usage, L113–132 dex, L135–165 seigniorage, L63–65 `setFeeTo` onlyOwner. MultiVault `_usageFeeWad` L157–160; burn/claim paths do not apply it. |
| **Recommended CODE** | Product decision: snapshot fees at DETF `postDeploy`, or cap usage ≪ 1e18, or timelock fee mutations. Do not silently change economics in Stage 3 without owner. |
| **Recommended TEST** | After a decision: `test_CROPS_003_usageFee_max_doesNotBlock_redeemClaim`; optional `test_CROPS_003_setUsageFee_revertsAboveProductCap`. |
| **Anti-theater** | Assert holder balances on an **existing** position, not only the next mint. |
| **Suggested WP-ID** | `WP-SEC-CROPS-003` (docs / owner decision first; CODE only if owner picks a cap or snapshot) |
| **Link TCA / prior** | Fee WAD bounds **F** in `T-manager-fee-registry` (tests the 100% cap as correct). Not a competing CODE WP with `WP-N-FEE-001`. |
| **Depends / parallel** | Independent of 001 |

### 2.4 [SEC-CROPS-004] Manager and FeeCollector `diamondCut` is instant `onlyOwner` (no timelock)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-CROPS-004` |
| **Title** | Admin diamonds keep instant ERC-2535 cut; ownership transfer is 3-day buffered |
| **Severity** | **Medium** |
| **Class** | **ACCEPTED_RISK** (document) / **NEEDS_OWNER** (Safe + cut timelock if launch requires it) |
| **Confidence** | static-high |
| **Catalog IDs** | F (admin diamond — expected) |
| **Pattern IDs** | PAT-CROPS-ADMIN |
| **EVM-audit domain** | proxies / access-control |
| **CROPS pillar** | S |
| **Incident theme** | none |
| **Products** | IndexedexManagerDFPkg; FeeCollectorDFPkg |
| **Blast radius** | protocol-wide config, disable, fees; FeeCollector inventory (protocol fees, not DETF reserve) |
| **Impact** | Owner can recut manager (rewrite fee/disable) or collector in one tx. MultiStepOwnable buffer (3 days) applies only to **ownership transfer**, not to `diamondCut` (`DiamondCutTarget.sol` L40–46 `onlyOwner`). |
| **Evidence** | `IndexedexManagerDFPkg.sol` L49–50, L153–160 (cut facet first), L281 `_initialize(owner, 3 days)`. `FeeCollectorDFPkg.sol` L21, L208. Crane `DiamondCutTarget.sol` L40–46. |
| **Recommended CODE** | None unless owner requires a timelock module. Document launch owner as Safe ≥2-of-3. |
| **Recommended TEST** | None for ACCEPTED_RISK. If CODE: cut-timelock negatives on manager proxy. |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | `WP-SEC-CROPS-004` (DOCS / owner) |
| **Link TCA / prior** | `WP-N-FEE-001` / `TCA-MGR-003` own FeeCollector **pullFee ACL tests** — do not fork that touch-set. |
| **Depends / parallel** | none |

### 2.5 [SEC-CROPS-005] MultiVault `test_F1_noOwnerOnInstance` cannot fail a leftover cut

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-CROPS-005` |
| **Title** | F1 adversarial test is theater (malformed cut; `owner()==self` allowed) |
| **Severity** | **Low** |
| **Class** | **THEATER** / **TEST** |
| **Confidence** | confirmed (test source) |
| **Catalog IDs** | F1, J2 |
| **Pattern IDs** | PAT-THEATER-FACET (F1 variant) |
| **EVM-audit domain** | access-control / proxies |
| **CROPS pillar** | S |
| **Incident theme** | none |
| **Products** | MultiVaultWeightedDetf (test only) |
| **Blast radius** | false confidence on L-SEC-11; production appears stripped |
| **Impact** | Test encodes `diamondCut` with `new bytes(0)` as `FacetCut[]` — ABI decode fails even if a real cut facet exists. Allows `owner() == instance_`. Coverage-audit marked F1 **F**. |
| **Evidence** | `test/.../multi-vault-weighted/adversarial/Adversarial_Access.t.sol` L16–34. |
| **Recommended CODE** | none (production cuts already omit Ownable/Cut) |
| **Recommended TEST** | `test_F1_loupe_hasNo_diamondCut_or_owner`; `facetAddress(IDiamondCut.diamondCut.selector)==0`; well-formed `diamondCut([], 0, "")` from attacker **and** from TestBase `owner` both revert/`false`; if `owner()` exists, require `== address(0)` (not self). |
| **Anti-theater** | Must use a well-formed `IDiamond.FacetCut[]`; must query loupe on the **proxy**. |
| **Suggested WP-ID** | `WP-SEC-CROPS-002` |
| **Link TCA / prior** | Adjacent to `WP-J-DETF-MV-001` / `TCA-DETF-MV-004` (J loupe) but **not** the same touch-set (J is Target⊆facetFuncs). Can merge into that WP if still open; else small `sec_fix_` TEST-only tree. |
| **Depends / parallel** | Parallel with J WP if different files; merge if editing the same Access suite |

### 2.6 [SEC-CROPS-006] BUSL-1.1 / missing LICENSE file

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-CROPS-006` |
| **Title** | Stack is source-available BUSL/BSL, not OSI-free; README LICENSE link is missing |
| **Severity** | **Info** |
| **Class** | **ACCEPTED_RISK** (license is product choice) |
| **Confidence** | confirmed |
| **Catalog IDs** | none |
| **Pattern IDs** | none |
| **EVM-audit domain** | n/a |
| **CROPS pillar** | O / Free |
| **Incident theme** | none |
| **Products** | monorepo (`package.json` `"license": "BUSL-1.1"`; SPDX `BSL-1.1` on DETF/SE/manager) |
| **Blast radius** | legal fork, not funds |
| **Impact** | Third parties cannot freely operate a competing protocol from this source under OSI terms. |
| **Evidence** | `package.json` L35; `README.md` L3, L618 (`LICENSE` badge/link); `LICENSE` absent at repo root. |
| **Recommended CODE** | none |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none (docs/legal) |
| **Link TCA / prior** | none |
| **Depends / parallel** | n/a |

### 2.7 [SEC-CROPS-007] Hosted frontend does not gate onchain exit

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-CROPS-007` |
| **Title** | Frontend/hosting CROPS notes (Info) |
| **Severity** | **Info** |
| **Class** | **ACCEPTED_RISK** |
| **Confidence** | static-medium (frontend not a money SUT) |
| **Catalog IDs** | none |
| **Pattern IDs** | none |
| **EVM-audit domain** | n/a |
| **CROPS pillar** | C / P (UX only) |
| **Incident theme** | none |
| **Products** | `frontend/**` (out of Stage 1 SUT) |
| **Impact** | Host can take down UI / pin an RPC; users still exit via direct contract calls (MultiVault surfaces above). |
| **Evidence** | PRD §0.3 / this task rule 5: frontend CROPS is Info unless it gates onchain exit. No such gate found on MultiVault/SE diamonds. |
| **Recommended CODE** | none |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | none |
| **Depends / parallel** | n/a |

---

## 3. Products implicated

| Product | CROPS posture (pilot view) | Findings |
|---------|----------------------------|----------|
| **MultiVaultWeightedDetf** (diamond) | Unowned, no `diamondCut`, no `isDisabled`, permissionless bond/claim/exit | SEC-CROPS-005 (test theater only) |
| **DETF bond NFT + rebasing claim** (satellites) | `MultiStepOwnable` storage owner = **DETF diamond**; no cut facet; `onlyOwner` mint/burn is DETF-orchestrated | none (explicit non-finding) |
| **UniswapV2StandardExchange** | No instance owner in DFPkg init; **disable bricks In+Out** | SEC-CROPS-002 |
| **Aerodrome / Camelot V2 SE** | No Ownable init; **no** `isDisabled` consult | none |
| **IndexedexManager** (fee oracle + registry + disable) | Owned; instant cut; 3-day owner transfer buffer; operator can set fees | SEC-CROPS-001/002/003/004 |
| **FeeCollector** | Owned; `pullFee` onlyOwner; instant cut | SEC-CROPS-004; pullFee **tests** OWNED_ELSEWHERE `WP-N-FEE-001` |
| **Single SE / Uni V4 DETFs / DualLiquidity** | Cross-cut only: `_requireNotDisabled` on `_requireActive` including **claim/exit** | SEC-CROPS-001 |
| **Frontend** | Info | SEC-CROPS-007 |

---

## 4. Recommended epic WPs

Wave 0 style (trust / leftover admin). Do **not** schedule `sec_fix_*` on coverage-audit primary files.

| WP-ID | Title | Severity | Class | Findings | Production touch-set | Parallel |
|-------|-------|----------|-------|----------|----------------------|----------|
| **WP-SEC-CROPS-001** | Strip registry disable from DETF claim/exit (and Uni V2 Out / share-out In) | High | CODE+TEST | SEC-CROPS-001, SEC-CROPS-002 | Disable-gated DETF `*Common.sol` / Bonding / ExchangeOut; `UniswapV2StandardExchange{In,Out}Target.sol` | After owner OK on kill-switch shape. Family files are parallel; do not edit MultiVault Common (already clean). Suggested worktree: `sec_fix_crops-disable-exit` (split per family if L-SEC-13). |
| **WP-SEC-CROPS-002** | Harden MultiVault F1 (loupe + well-formed cut) | Low | TEST | SEC-CROPS-005 | `Adversarial_Access.t.sol` only | Merge into `WP-J-DETF-MV-001` if that gap-cover tree still owns the Access suite; else `sec_fix_crops-f1`. |
| **WP-SEC-CROPS-003** | Owner decision: fee snapshot / cap / timelock | Medium | DOCS → optional CODE | SEC-CROPS-003 | `VaultFeeOracleRepo.sol` / ManagerFacet **only if** owner picks CODE | Do not start until NEEDS_OWNER returns. |
| **WP-SEC-CROPS-004** | Document manager/collector as owned god-diamond; optional Safe+cut timelock | Medium | DOCS | SEC-CROPS-004 | none unless owner requires timelock | Independent |

**OWNED_ELSEWHERE (do not open `sec_fix_*`):**

| This audit | Coverage WP | Why |
|------------|-------------|-----|
| FeeCollector `pullFee` ACL / reserve | `WP-N-FEE-001` / `TCA-MGR-003` | Same collector money-out tests |
| Manager/oracle/registry J declaration | `WP-J-MGR-001`, `WP-J-MGR-002` | FacetFuncs/loupe, not CROPS posture |
| MultiVault `_pullToken` / I1–I3 | `WP-I-DETF-MV-001`, `WP-I-DETF-MV-002` | PAT-I-ABS, not admin |
| MultiVault J1–J3 | `WP-J-DETF-MV-001` | Surface completeness; F1 theater may **merge** |

---

## 5. Explicit non-findings

Checked and **clean** (or accepted as designed):

1. **MultiVault leftover `diamondCut` / human owner / operator** — factory base facets omit Cut; DFPkg 8 cuts omit Ownable/Operable/Cut; `initAccount` does not `_initialize` Ownable. L-SEC-11 **stripped** on this instance.
2. **MultiVault admin pause** — `_requireActive` is amount + deadline only. Registry disable cannot brick MultiVault bond/claim/`exchangeOut` to `vaultShare`.
3. **Weights / thresholds / expansion post-deploy** — no `setWeights`; thresholds resolved once into repo. `test_F4_weightsImmutable_afterOps`.
4. **Bond maturity rewrite** — `unlockTimeOf[tokenId]` stored at create (`DETFNFTVaultTarget` / repo). Live oracle bond terms affect **new** locks only (`_effectiveLockDuration`).
5. **Usage fee on exit** — MultiVault burn/claim/close do not `_splitMintedDetf`.
6. **Walkaway if team disappears** — MultiVault holder can permissionlessly `initializeReserve` / `bond` / `sellPositionToDetfNft` / `closeBondMature` / `redeemClaim` / `exchangeOut` / `compoundProtocolRewards`. No keeper. Fee oracle is still on-chain at last values.
7. **Satellite leftover human admin** — bond NFT + claim `MultiStepOwnableRepo._initialize(detf, 1 days)`; facetFuncs do **not** expose ownership-transfer or `diamondCut`. `onlyOwner` = DETF diamond (F2/F3). `setDetf` is onlyOwner and not called post-deploy by the DETF surface.
8. **Aero / Camelot leftover owner or disable** — DFPkg init has no Ownable; no `isDisabled` consult.
9. **Manager disable of MultiVault address** — no effect on MultiVault functions (flag can be set, never read).
10. **FeeCollector as user-fund custody** — holds protocol fees; `pullFee` onlyOwner is intended. ACL **test** gaps stay on `WP-N-FEE-001`.
11. **PAT-I-ABS / J omit / K donate** — not CROPS; OWNED_ELSEWHERE.
12. **Frontend cannot freeze MultiVault exit** — Info (SEC-CROPS-007).

---

## 6. Commands / checklists walked

No `forge` (Stage 1 specialist; PRD + task forbid). No worktrees. No `via_ir`.

**Checklists**
- ethskills-crops: C (pause/disable/frontend), O/F (BUSL), P (public chain data only), S (walkaway, leftover admin, oracle/fee keys).
- crane-access: MultiStepOwnable init + buffer; Operable on manager fee setters; `diamondCut` `onlyOwner`.
- PRD PAT-CROPS-ADMIN + L-SEC-11 leftover cut/owner on live DETF.
- Agent law: instances immutable/unowned; no admin pause; fees via oracle; thresholds deploy-time.
- Coverage-audit collision map (`WP-I-*`, `WP-J-*`, `WP-N-FEE-001`).

**Searches (ripgrep)**
- `diamondCut|onlyOwner|onlyOperator|MultiStepOwnable` under `contracts/vaults/detf/**/multi-vault-weighted/**`
- `isDisabled|_requireNotDisabled` under `contracts/`
- `facetCuts` / `initAccount` on MultiVault, bond NFT, claim, Aero, Camelot, Manager, FeeCollector DFPkgs
- `test_F1_` / disable suites under `test/foundry`
- coverage-audit `WORK_PACKAGE_BACKLOG.md` for disable/CROPS WPs (none)

**Primary files read**
- `MultiVaultWeightedDetfDFPkg.sol` (`facetCuts` L255–275, `initAccount` L296–367)
- `MultiVaultWeightedDetfCommon.sol` (`_requireActive` L92–97, fee reads L151–161, mint split L222–229)
- `MultiVaultWeightedDetfBondingTarget.sol` (permissionless bond/sell/close/redeem; `_exchangeShareToRateAsset` L527–549)
- `Adversarial_Access.t.sol` (F1–F4)
- Crane `DiamondPackageCallBackFactory.sol` (base facets; no Cut)
- Crane `DiamondCutTarget.sol`
- `IndexedexManagerDFPkg.sol`, `VaultFeeOracleManagerFacet.sol`, `VaultFeeOracleRepo.sol`
- `VaultRegistryDisableManagerTarget.sol`, `IVaultRegistryDisableQuery.sol`
- `FeeCollectorManagerTarget.sol`, `FeeCollectorDFPkg.sol`
- `DETFNFTVaultDFPkg.sol`, `RebasingClaimTokenDFPkg.sol` (+ facetFuncs)
- `UniswapV2StandardExchangeCommon.sol` / InTarget / OutTarget + `UniswapV2StandardExchange_Disable.t.sol`
- `AerodromeStandardExchangeDFPkg.sol`, Camelot DFPkg init
- `SingleStandardExchangeDETFCommon.sol` + BondingTarget (blast)
- `package.json`, `README.md` license section

**Not walked (out of pilot deep review)**
- Full `A-manager-fee-registry` inventory (hooks deploy ACL, seigniorage query typo — already TCA-MGR-*).
- Formal frontend hosting/RPC map beyond Info.
- Runtime loupe on a live MultiVault proxy (static DFPkg + factory cuts are conclusive for leftover Cut/owner).

## Full-pass addendum (2026-08-13)

- `A-detf-single-se`: leftover `diamondCut` / owner **absent** (confirms pilot MultiVault split).
- Uni V4 extra BondingTargets call `_requireNotDisabled()` — **confirms** `SEC-CROPS-001` blast (weighted/orbital/quad). No new CROPS High ID.
- Manager remains the owned upgrade/fee/disable plane (`A-manager-fee-registry` in-flight; seigniorage J stays `WP-J-MGR-001`).
- Frontend still Info (does not gate onchain exit).
