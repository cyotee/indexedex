# Security Audit — A-detf-commons

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · MODE=full · `A-detf-commons` |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/detf/common/core/**`; `contracts/vaults/detf/common/claimToken/**`; `contracts/vaults/detf/common/bondNft/**`; `contracts/vaults/detf/common/inventory/**`; `contracts/vaults/detf/common/factory/**` |
| Test paths | `test/foundry/spec/vaults/detf/common/**`; `test/foundry/spec/saf/T01_FacetSelectors.t.sol`; `T03_Pretransfer.t.sol`; `T04_ClaimUnwind.t.sol`; seed `WP-I-CLAIM-001` / `T-basic-protocol-commons` / `T-detf-single-vault-seigniorage` |
| Skills cited | `docs/security/SECURITY_AUDIT_PRD.md` §2, §2.4, §3.8, §5–8, §19; `crane-adversarial-testing`; `indexedex-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `defi-incident-patterns` |
| Residual-risk scores | RebasingClaimToken **4**; DETFNFTVault **3**; factory helpers **4**; inventory policy interfaces **4**; shared core libs **4** (IR → `S-spec-detf`) |
| Forge | **Not run** (orchestrator owns runtime; L-SEC-3). Static re-verify of WP-I-CLAIM-001 CODE + existing `test_I1_*` / `test_I2_*` / `test_I3_*` sources. |

## 1. Executive summary

- **Residual-risk scores:** RebasingClaimToken **4** (same-tx inbound-delta + I1–I3 on proxy; J/I2 leftovers). DETFNFTVault **3** (D/authority holds when owner is the DETF diamond; unused `redeemPosition` LP basis is spec-drift; local D suite is theater). Factory / inventory / core libs **4**.
- **Critical / High counts:** **Critical 0**. **High 2** — `SEC-DETF-COM-001` (historical PAT-I-ABS on claim foreign-token, **OWNED_ELSEWHERE** / CODE closed at this SHA) and `SEC-DETF-COM-004` (**TEST** — J1–J3 not systematically proven on claim/bond proxies).
- **No new High CODE this program owns.** Claim `_secureTokenTransfer` is no longer PAT-I-ABS. Public redeem / `exchangeIn` / `exchangeOut` require `tokenIn == address(this)`; foreign-token pull is same-tx delta but **dead** on the public money surface.
- **Top recommended WPs (this program):**
  1. `WP-SEC-DETF-COM-J-001` — High TEST: Target ⊆ `facetFuncs` ⊆ cuts ⊆ loupe ⊆ **proxy** smoke for claim + bond DFPkgs.
  2. `WP-SEC-DETF-COM-D-001` — Medium CODE+TEST: `redeemPosition` must convert **originalShares** (LP principal), not `effectiveShares` (reward weight); local D negatives on proxy.
  3. **Do not** open a competing `sec_fix_*` for `WP-I-CLAIM-001`.
- **OWNED_ELSEWHERE count:** **6** linked TCA/WP touch-sets (`TCA-COMMON-005`, `TCA-DETF-SVS-003`, `WP-I-CLAIM-001`, `TCA-DETF-SVS-002`, `TCA-DETF-SVS-004`, `WP-TEST-DETF-SVS-001`).
- **Spec IR** for compound / expansion / thresholds / mint-split is **cited, not re-authored** (`S-spec-detf`).

Headline: **claim I1 is blocked at this SHA** (same-tx `observedDelta`, `TransferDeltaInsufficient(claimed, 0)`). The remaining commons money defects are a **legacy onlyOwner redeem that prices LP from lock-bonus weight** and **incomplete J proof** on the two shared diamonds. Family close/sell paths use `originalShares` and do **not** call `redeemPosition`.

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|---------------|
| **RebasingClaimToken** | `RebasingClaimTokenDFPkg`; `RebasingClaimTokenFacet` (29 sels) + Crane ERC5267 / ERC2612; Target + Repo | No dedicated gold TestBase. `RebasingClaimToken_TrustFlags.t.sol` deploys real DFPkg + **proxy** (mock DETF / `vm.mockCall` nftVault as **non-SUT**). SAF T03 on Uni V4 Single SE DETF. | Facet CREATE3 (`DetfFacetFactoryService`). DFPkg CREATE3 `deployPackageWithArgs` — **not** vault-registry (`IStandardVaultPkg` absent; documented). Instance: `pkg.deployToken(...)` via `diamondPackageFactory`. Owner typically the DETF diamond. | **4** |
| **DETFNFTVault** | `DETFNFTVaultDFPkg` (registry); Facets: ERC721 + ERC4626 Basic/Standard views + `DETFNFTVaultFacet` (28 sels) + Replace of ERC721 transfers; Target / Common / Repo / Service | No gold adversarial TestBase. `DETFNFTVaultDFPkg_Deploy.t.sol` registry deploy. `DETFNFTVault.t.sol` **stub theater**. D/F2 live on MultiVault / Single SE / CS product suites. | Facets CREATE3. DFPkg `indexedexManager` / `VAULT_REGISTRY_DEPLOYMENT.deployPkg`. Instance `pkg.deployVault` → registry. `processArgs` reverts `NotCalledByRegistry`. | **3** |
| **Detf*FactoryService** | `DetfFacetFactoryService`, `DetfPkgFactoryService`, `DetfComponentFactoryService`; `IDetfSelfNftInventoryDFPkg` alias | SAF T11 brand-strip; used by every DETF TestBase | CREATE3 / registry helpers only. `buildRICHIRPkgInit` is deprecated alias. | **4** |
| **Inventory policy hooks** | `IDetfBondInventoryPolicy`, `IDetfSelfNftInventoryPolicy`, `IDetfNftInventoryPolicy`, `IDetfFeeRecipientInventoryPolicy` | Exercised via family DETFs | Interfaces only. Bond vault implements bond policy. | **4** |
| **Shared core libs** | Threshold, compound, expansion (linear + epoch), mint split, usage fee, preview bps, bond lifecycle, bond NFT math, Balancer scale, safe transfer | Unit: `test/.../common/core/*.t.sol` | Pure / internal. Families call; full IR is `S-spec-detf`. | **4** |

### 2.1 File inventory (allowlist)

| Path | Role |
|------|------|
| `claimToken/RebasingClaimTokenTarget.sol` | Mint / redeem / exchange / burn / `_secureTokenTransfer` |
| `claimToken/RebasingClaimTokenFacet.sol` | 29 product selectors |
| `claimToken/RebasingClaimTokenRepo.sol` | Slot `keccak256("indexedex.vaults.protocol.richir")`; share scale 1e9; unused `lastSelfBalance` |
| `claimToken/RebasingClaimTokenDFPkg.sol` | 3 cuts (ERC5267, ERC2612, claim). `ERC20_FACET` stored **not cut** (ERC20 lives on claim facet) |
| `bondNft/DETFNFTVaultTarget.sol` | Positions, redeem, sell, harvest, `transferHeldToken`, ERC721 transfer guards |
| `bondNft/DETFNFTVaultFacet.sol` | 28 selectors (no retired `markDETFNFTSold`) |
| `bondNft/DETFNFTVaultRepo.sol` | Slot `keccak256("indexedex.vaults.protocol.nft")`; reward + LP conversion |
| `bondNft/DETFNFTVaultDFPkg.sol` | Registry deploy; replace ERC721 transfers onto protocol facet |
| `bondNft/DETFNFTVaultCommon.sol` / `DETFNFTVaultService.sol` | Lock terms + harvest structs |
| `factory/**` | CREATE3 / registry builders |
| `inventory/**` | Policy interfaces |
| `core/DETFThresholdPolicy.sol` | Policy/Open resolve; mint `>` / burn `<` |
| `core/DETFProtocolCompoundLib.sol` | Dust gate only (`DEFAULT_COMPOUND_DUST = 1`) |
| `core/DETFNaturalExpansionLib.sol` / `DETFEpochNaturalExpansionLib.sol` | Pure premium-closure mint |
| `core/DETFMintSplitLib.sol` / `DETFMintSplit.sol` | Half-seigniorage split |
| `core/DETFUsageFeeLib.sol` / `DETFPreviewLib.sol` | Fee / preview bps |
| `core/DETFBondLifecycleLib.sol` | create / sell / harvest / `addToDETFNFT` helper |
| `core/DETFBondNFTMathLib.sol` | Bonus curve, harvest math |
| `core/DETFSafeTransferLib.sol` | Low-level `transfer` + empty/`true` return |
| `core/DETFBalancerScaleLib.sol` | Rate-provider scale (family Balancer) |

### 2.2 Out of area (reference only)

| Surface | Owner |
|---------|--------|
| Family DETF packages (MultiVault, Single SE, CS, DualLiq, Uni V4 extra) | F1 sibling areas |
| `RebasingDETFTokenTarget` (composed-stable clone) | `A-detf-composed-stable` |
| Uni V4 DETF-local bond/claim (`…/uniswap/v4/common/{nft,rebasing}/**`) | `A-detf-univ4-extra` |
| Durable reserve-delta `_pullToken` on families | Family areas; blast in `A-commons-pull` |
| Full compound/expansion/threshold **spec IR** | `S-spec-detf` |

### 2.3 Test inventory (this area)

| Suite | Path | I / J / D? |
|-------|------|------------|
| Claim trust-flags | `test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_TrustFlags.t.sol` | **I1 / I2 / I3 on proxy**. I2 is zero-delta (same as I1). Mock DETF + `mockCall` nftVault (non-SUT). |
| Claim deploy / 4626 mint | `…/RebasingClaimTokenDFPkg_Deploy.t.sol` | Deploy + `mintFromNFTSale` empty-vault. No I/J catalog names. |
| Claim redemption stub | `…/RebasingClaimTokenRedemption.t.sol` | **Theater** (`public pure`; `@custom:adversarial-status stub-not-production-path`) |
| Bond deploy / law | `…/bondNft/DETFNFTVaultDFPkg_Deploy.t.sol` | Registry deploy; `BondNotMature`; EOA `redeemPosition` revert; add/remove 1:1. Not catalog-named D/J. |
| Bond unit stub | `…/bondNft/DETFNFTVault.t.sol` | **Theater** (pure arithmetic; uses product-brand comment) |
| SAF T01 | `test/foundry/spec/saf/T01_FacetSelectors.t.sol` | Partial J3 (2 bond views + `updateRedemptionRate`) |
| SAF T03 | `test/foundry/spec/saf/T03_Pretransfer.t.sol` | Production Uni V4 Single SE DETF: I1 + two-tx transfer-then-redeem reverts delta 0 |
| SAF T04 | `test/foundry/spec/saf/T04_ClaimUnwind.t.sol` | Honest redeem on live DETF |
| Core unit | `test/.../common/core/*.t.sol` | Pure lib gates (not product A–O) |
| Family D/F2 | MultiVault `Adversarial_BondClaim` / `Adversarial_Access.test_F2_bondNftVault_onlyOwner` | **F** for D2–D6 / F2 on MultiVault SUT (not this area’s files) |

## 3. Threat models

### 3.1 RebasingClaimToken (rebasingClaimToken diamond)

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `redeem` / `exchangeIn` / `exchangeOut` `pretransferred=true` | rebasingClaimToken → `rateAsset` via `detf.claimLiquidity` | `pretransferred` | none | **Blocked** when no in-window delta (`TransferDeltaInsufficient(claimed, 0)`). Two-tx push also reverts (same-tx law). |
| EXT | `redeem(..., false)` | caller shares → rateAsset | pull via internal `_transfer` | none | Honest pull. Burns `address(this)` shares after credit. |
| EXT | `exchangeOut` leftover | unused self-token | this-call surplus | none | Refunds `depositedIn − amountIn` only (**E6-safe**). |
| EXT | `updateRedemptionRate` | none | none | DETF preview as oracle | Permissionless cache poke. Stale same-block cache is intentional. |
| INT | ERC2612 `permit` (Crane facet) | allowance | signature | n/a | O1–O3 owned by Crane facet / `S-signatures`. No local ecrecover. |
| ADM | `mintFromNFTSale` / `burnShares` / `setDetf` / `transferHeldToken` | claim shares / any ERC20 / DETF pointer | `onlyOwner` | leftover owner | Owner is DETF by design. Leftover EOA can mint/burn/retarget/drain. No Ownable facet → cannot `transferOwnership` on proxy if mis-set. |
| ADM | `burnShares(..., pretransferred=true)` | shares of `address(this)` | owner-only | DETF | Burns inventory **without** delta. Family `redeemClaim` uses `pretransferred=false` (burn from user). |
| CFG | `mintFromNFTSale(assets, type(uint256).max)` after protocol credit | dilution | owner | nftVault view | Live-read after credit under-mints. Interface: sell must snapshot; buyClaim mints **then** `addToDETFNFT`. |
| HOS | foreign token in `_secureTokenTransfer` | FoT / missing return | pull | none | Public APIs reject `tokenIn != this`. Dead branch is FoT-delta if ever exposed. |

### 3.2 DETFNFTVault (bond NFT diamond)

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `claimRewards` | `rewardToken` | holder or DETF | fee-oracle terms n/a | Holder harvest only. Second claim at same `rewardPerShares` = 0. |
| EXT | `reallocateDetfNftRewards` | protocol NFT pending rewards | `feeTo` **or** DETF | fee oracle `feeTo` | Free-DETF harvest of **protocol** NFT only. Not user principal. |
| EXT | ERC721 `transferFrom` to DETF | bond NFT | none | none | **Blocked** (`ERC721InvalidReceiver`). DFPkg Replace wires guards. |
| EXT | `redeemPosition` / `sellPositionToDetfNft` / `createPosition` | LP / NFT | `onlyOwner` | DETF owner | EOA reverts. Production close uses family `originalShares` + sell + `removeFromDETFNFT`, **not** `redeemPosition`. |
| ADM / CFG | leftover EOA owner + `createPosition` (ledger-only) | phantom principal | `onlyOwner` | mis-set `PkgArgs.owner` | Phantom `originalShares` + family `closeBondMature` can unwind **real** reserve BPT. Production owner must be DETF. |
| ADM | `transferHeldToken` / `addToDETFNFT` / `removeFromDETFNFT` | any ERC20 / share ledger | `onlyOwner` | DETF | Intended orchestration. Leftover EOA drains custody LP. |
| CAP | donate `rewardToken` while `totalShares==0` | rewards | none | none | `_updateGlobalRewards` no-ops; first locker can absorb donation (A0-like rewards). |
| CAP | donate `lpToken` onto vault | LP | none | none | Inflates `_convertToAssets` if that helper is used (`redeemPosition`). Family close ignores this book. |
| HOS | FoT `rewardToken` | harvest | none | none | `lastRewardTokenBalance -= rewards` then transfer; FoT / skim can underflow (DoS harvest). |

### 3.3 Factory / inventory / core libs

| Actor | Surface | Asset moved | Trust flags | Worst case |
|-------|---------|-------------|-------------|------------|
| CFG | `PkgArgs.owner` / `setDetf` | child-diamond authority | deploy args | Mis-set owner (above). Factory itself moves no funds. |
| CFG | `ThresholdMode.Open` / zero expansion args | seigniorage / dilution | PkgArgs | Open mint+burn is **ACCEPTED_RISK** (documented). Zero rate arg → default (not off). `S-spec-detf`. |
| EXT | `DETFProtocolCompoundLib.isCompoundable` | none | n/a | Dust gate only. Compound join is family-owned. |
| EXT | `DETFBondLifecycleLib._addReservePoolBptToDetfNft` | approve + ledger credit | family caller | `forceApprove` unused by `addToDETFNFT` (ledger-only). Family must already hold BPT. |

## 4. Catalog matrix (A–O, E6, F5)

| ID | Product | F/P/G/N/A/VULN | Evidence |
|----|---------|----------------|----------|
| **A1** | Claim | **P** | Donation of claim tokens to diamond sits idle; same-tx I1 does not credit it. No `test_K1_*`. |
| **A1** | Bond | **P** | Reward donation accrues to `rewardPerShares` (MasterChef). LP donation only hits unused `convertToAssets`. |
| **A0** | Claim | **P** | Empty `totalAssets==0` mint is 1:1 (`test_mintFromNFTSale_emptyVault_*`). Rate=1e18 if `totalShares==0` or protocol `originalShares==0`. Redeem with 0 BPT → `ZeroAmount`. |
| **A0** | Bond | **P** | Rewards donated at `totalShares==0` not booked until first locker. LP 1:1 when empty. |
| **B** | Claim / bond | **N/A** | Pricing is DETF `previewExchangeIn` / family synthetic. Rate cache same-block. |
| **C** | Claim | **P** | `redeem`/`exchange*`/`burnShares` `nonReentrant`. `transferHeldToken` **not** locked (L-CLAIM-1: DETF may call under redeem lock). |
| **C** | Bond | **P** | Money paths `nonReentrant`. `addToDETFNFT` / `removeFromDETFNFT` not locked (DETF-orchestrated). |
| **D2–D6** | Bond | **P** | `onlyOwner` + mature + burn. Protocol NFT blocked. Local suite **theater**; MultiVault `test_D2_*`…`test_D6_*` **F** on family. `redeemPosition` LP basis **VULN-adjacent** (`SEC-DETF-COM-002`). |
| **D** | Claim | **P** | `mintFromNFTSale` / `burnShares` owner-only. User redeem burns after pull. Double redeem: insufficient shares. |
| **E1 / E5** | Claim | **P** | Zero amount typed. Deadline on exchange. FoT only on dead foreign branch. |
| **E6** | Claim | **F** | `exchangeOut` refunds this-call unused self-token only. |
| **E6** | Bond | **N/A** | No surplus-refund path. Harvest pays earned only. |
| **F / F5** | Both | **P** | No public migrate/reclaim. `reallocateDetfNftRewards` harvests protocol rewards only (not untracked LP). Leftover owner is CROPS (`SEC-DETF-COM-008`). |
| **G** | Commons | **N/A** | Nested DETF is family-owned. |
| **H** | Claim | **P** | Redeem burns then `claimLiquidity`; failure reverts (atomicity). SAF T04 honest path. No local H2 fail-leaves-balance catalog. |
| **H** | Bond | **P** | `redeemPosition` burn-then-`claimLiquidity`. Families use sell+remove+exit. |
| **I1** | Claim | **F** | `test_I1_*` proxy + T03 live DETF. Same-tx delta. |
| **I2** | Claim | **P** | Named I2 is zero-delta only. No short **partial** inbound vs claimed. |
| **I3** | Claim | **F** | Residual after honest redeem cannot fund second free pretransfer. |
| **I4** | Claim | **N/A** | Public `tokenIn` must be self; self-transfer is exact share accounting. |
| **I5** | Claim | **N/A** | No Permit2 on this package. ERC2612 is Crane. |
| **I** | Bond | **N/A** | No `pretransferred` on bond vault. |
| **J1** | Claim | **P** | Facet lists 29 Target money/views. ERC20_FACET unused. T01 only greps `updateRedemptionRate`. |
| **J1** | Bond | **P** | 28 product sels; ERC721 split to ERC721 facet + Replace transfers. T01 greps two views. |
| **J2–J3** | Both | **P** | Deploy tests call some views/money. No Target-derived full loupe + proxy smoke matrix. |
| **J4** | Both | **P** | Cuts match declared facets. Claim 3 cuts; bond 5 (incl. Replace). |
| **K1** | Claim | **P** | Same-tx I1 closes donation-as-credit. No named `test_K1_*`. |
| **K** | Bond | **P** | `lastRewardTokenBalance` vs `balanceOf`. FoT/skim desync (`SEC-DETF-COM-006`). |
| **L1–L3** | Commons | **N/A** | No AMM books here. Rate via DETF preview. |
| **M1–M3** | Commons | **N/A** | No user `target+calldata`. `transferHeldToken` is owner pull, not arbitrary call. |
| **N1** | Claim | **P** | Redeem quotes rate then `claimLiquidity` (DETF may move). Mid-tx DETF is owner/callback, not untrusted hook. |
| **N2** | Claim | **P** | `previewRedeem` is share→balance at current rate (≈ identity). Family previews own BPT math. |
| **O1–O3** | Claim | **P** | ERC2612 cut present. No local O suite. `S-signatures`. |
| **O** | Bond | **N/A** | No permit on NFT vault package. |

## 5. Domain notes

Walked locally (evm-audit hunt lists, not a second ID space):

| Domain | Walked | Notable |
|--------|--------|---------|
| **general** | yes | Dead foreign pull; unused `forceApprove`; unused `ERC20_FACET`; `ZeroAmount` reused for zero address. |
| **precision-math** | yes | Share scale 1e9; 4626 floor mint; expansion nested `mulDiv`; epoch `mintPerEpoch * epochs_` can overflow (DoS) if unlimited catch-up. |
| **erc20** | yes | BetterSafeERC20 / DETFSafeTransferLib; rebasing `balanceOf`; self-transfer via share ledger. |
| **erc4626** | yes | Claim mint vs protocol `originalShares`; virtual offset **not** used (owner-only mint). |
| **erc721** | yes | Transfer-to-DETF blocked; protocol NFT unsellable/unredeemable; `tokenURI` on protocol facet. |
| **proxies / J** | yes | CREATE3 + registry (bond) / diamond factory (claim). No DiamondCut on these pkgs (Crane base). |
| **access-control** | yes | `onlyOwner` money; `claimRewards` holder; `reallocateDetfNftRewards` feeTo/DETF. No Ownable facet. |
| **oracles** | yes | Bond terms via fee oracle; claim rate via DETF `previewExchangeIn`. Family-owned manipulation. |
| **flashloans** | N/A | No pricing in helpers. |
| **dos** | yes | Harvest underflow; expansion overflow; `R` N/A. |
| **CROPS** | yes | Child owner = DETF is intended. Mis-set owner + no `transferOwnership` selector = walkaway fail. DETF leftover admin is `S-crops-trust` / family. |
| **sharp-edges** | yes | `pretransferred` default is caller-supplied (not true-by-default). `mintFromNFTSale` 2-arg live-read. `PkgArgs.owner`. Threshold 0 → defaults. |
| **spec-compliance** | spot-check | Inventory: `originalShares` = LP principal; `effectiveShares` = reward weight. `redeemPosition` disagrees. Compound/expansion/threshold law → `S-spec-detf`. |
| **incidents** | yes | I1 trust-flag (closed); A0 first locker rewards; surplus-refund N/A on claim leftover (capped). |

## 6. Findings

### 6.1 [SEC-DETF-COM-001] Claim foreign-token PAT-I-ABS is closed (WP-I-CLAIM-001)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-001` |
| **Title** | Re-verify WP-I-CLAIM-001: same-tx delta on RebasingClaimToken; do not re-queue |
| **Severity** | **High** (historical) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed (static body + existing catalog tests; forge not re-run) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS (closed), PAT-THEATER-PRE (inverted) |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | Trust-flag free mint |
| **Products** | RebasingClaimToken (shared). RebasingDETFToken is **not** this allowlist. |
| **Blast radius** | Every DETF that deploys this claim DFPkg |
| **Attacker** | EXT (historical) |
| **Attack scenario** | Historical: `pretransferred=true` + `balanceOf >= claimed` credited **idle** inventory (foreign branch). **Current:** snapshot `balanceBefore`; if `pretransferred` and `amount > observedDelta` revert `TransferDeltaInsufficient`; else credit `claimed`. |
| **Preconditions** | n/a (closed) |
| **Impact** | None at this SHA on the public path. Foreign branch is also delta-gated but **unreachable** (`tokenIn` must be `address(this)`). |
| **Evidence** | `RebasingClaimTokenTarget.sol` L559–581. Tests: `RebasingClaimToken_TrustFlags.t.sol` `test_I1_*` / `test_I2_*` / `test_I3_*` (proxy); `T03_Pretransfer.t.sol` on Uni V4 Single SE DETF. Coverage `STAGE3_PROGRESS.md`: `WP-I-CLAIM-001` 7/7. Repo comment: unused `lastSelfBalance` kept for layout. |
| **Runtime** | Not re-run. Static + test source is enough to refuse a new Critical/High CODE. Orchestrator may re-execute `forge test --match-path 'test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_TrustFlags.t.sol' --match-test 'test_I'`. |
| **Recommended CODE** | none |
| **Recommended TEST** | Keep I1–I3 green. Optional I2 short-delta (`SEC-DETF-COM-003`). |
| **Anti-theater** | I1 must not transfer in-call; inventory already on diamond. |
| **Suggested WP-ID** | none (`sec_fix_*` skip) |
| **Link TCA / prior** | `TCA-COMMON-005`, `TCA-DETF-SVS-003`, `WP-I-CLAIM-001` (`gap_cover_i-claim`) |
| **Depends / parallel** | n/a |

### 6.2 [SEC-DETF-COM-002] `redeemPosition` converts lock-bonus weight to LP

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-002` |
| **Title** | Price mature redeem LP from `originalShares`, not `effectiveShares` |
| **Severity** | **Medium** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | D, E |
| **Pattern IDs** | PAT-SPEC-DRIFT |
| **EVM-audit domain** | erc4626 / erc721 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | DETFNFTVault (shared). ComposedStable has a **clone** Target (`A-detf-composed-stable`). |
| **Blast radius** | Live `onlyOwner` function on every shared bond diamond. **Current families do not call it** (`closeBondMature` uses `originalSharesOf` + sell + `removeFromDETFNFT`). Future family / leftover owner calling `redeemPosition` would use the wrong basis. |
| **Attacker** | ADM / CFG (must be owner); not EXT on correctly wired DETF |
| **Attack scenario** | 1. Two bonds: A long-lock (`effective > original`), B min-lock (`effective ≈ original`). LP (or DETF reserve book) backs **original** principal. 2. Owner calls `redeemPosition(A)`. 3. `_convertToAssets(effectiveSharesOf[A])` pays A a **bonus-weighted** share of the LP book. 4. B’s remaining conversion (or protocol claim backing if LP is on the DETF and protocol effective is in the denominator) shrinks. |
| **Preconditions** | Caller is NFT-vault owner. Positions with unequal lock bonuses. Path actually uses `redeemPosition` (not current MultiVault/Single SE close). |
| **Impact** | Cross-user principal skew if the path is used. Not a current-family EXT drain. |
| **Evidence** | `DETFNFTVaultTarget.sol` L159–171: `lpAmount = _convertToAssets(effectiveSharesOf[tokenId])` then `detf.claimLiquidity`. Contrast `IDetfBondInventoryPolicy` / Target comments: original = LP principal; effective = reward weight. Contrast family `closeBondMature` (`originalSharesOf`). `sellPositionToDetfNft` correctly moves **originalShares**. |
| **Recommended CODE** | `redeemPosition`: convert **`originalSharesOf[tokenId]`** (or document NEEDS_OWNER if bonus is meant to share LP). Keep effective for harvest only. |
| **Recommended TEST** | `test_D_redeemPosition_paysOriginalNotEffective`; two unequal locks; assert LP out ≈ original, not effective. `forge test --match-path 'test/foundry/spec/vaults/detf/common/bondNft/**' --match-test 'test_D_redeemPosition'`. |
| **Anti-theater** | Must deploy registry proxy; actually call `redeemPosition` (need DETF stub `claimLiquidity` **or** family TestBase). Do not treat `DETFNFTVault.t.sol` pure math as coverage. |
| **Suggested WP-ID** | `WP-SEC-DETF-COM-D-001` |
| **Link TCA / prior** | none for this CODE (D coverage was family-owned) |
| **Depends / parallel** | Parallel with claim J WP. Serial vs any other editor of `DETFNFTVaultTarget.sol` / Repo conversion. Cite CS clone in `A-detf-composed-stable`. |

### 6.3 [SEC-DETF-COM-003] Claim I2 short-delivery not proven

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-003` |
| **Title** | Add I2 partial inbound (`claimed > observedDelta > 0`) on claim proxy |
| **Severity** | Medium |
| **Class** | **TEST** |
| **Confidence** | confirmed |
| **Catalog IDs** | I2 |
| **Pattern IDs** | PAT-THEATER-PRE (weak I2) |
| **EVM-audit domain** | erc20 |
| **Products** | RebasingClaimToken |
| **Impact** | I2 name exists but is zero-delta (duplicate I1). A regression that credits `min(claimed, balance)` without requiring `claimed ≤ delta` would not fail I2. Production body still requires `amount_ > observedDelta` revert. |
| **Evidence** | `RebasingClaimToken_TrustFlags.t.sol` `test_I2_pretransferred_claimedGtDelta0_reverts` — no in-call transfer. Missing same-tx transfer of `claimed/2` then `redeem(claimed, true)`. |
| **Recommended TEST** | Multicall / callback: transfer `d < claimed` in-window; expect `TransferDeltaInsufficient(claimed, d)`. |
| **Suggested WP-ID** | fold into `WP-SEC-DETF-COM-J-001` TEST slice |
| **Link TCA / prior** | `WP-I-CLAIM-001` acceptance named I2 but implemented as I1-duplicate |

### 6.4 [SEC-DETF-COM-004] J1–J3 not systematically proven on claim/bond diamonds

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-004` |
| **Title** | Prove Target ⊆ facetFuncs ⊆ cuts ⊆ loupe ⊆ proxy for claim and bond DFPkgs |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | confirmed (static selectors look complete; tests do not prove the matrix) |
| **Catalog IDs** | J1–J4 |
| **Pattern IDs** | PAT-THEATER-FACET, PAT-J-OMIT |
| **EVM-audit domain** | proxies |
| **CROPS pillar** | n/a |
| **Incident theme** | Missing diamond selectors |
| **Products** | RebasingClaimTokenDFPkg, DETFNFTVaultDFPkg |
| **Blast radius** | Silent missing money/view API on every DETF child diamond |
| **Attacker** | n/a (availability / false confidence) |
| **Attack scenario** | Facet and hand-written T01 both omit the same selector → tests pass; proxy `FunctionNotFound` on redeem / sell / `transferHeldToken`. Static review of `facetFuncs` vs Target did **not** find an omitted money selector at this SHA. |
| **Preconditions** | New selector added to Target without Facet/cut. |
| **Impact** | User/DETF cannot call a documented money path. P0 catalog hole. |
| **Evidence** | T01 smokes `lockInfoOf`, `rewardPerShares`, `updateRedemptionRate` only. Deploy tests call a subset. No `test_J1_*` / `test_J2_*` / `test_J3_*`. Claim `facetFuncs` 29 vs Target public API (appears complete). Bond product sels 28 + ERC721 split (appears complete). |
| **Recommended TEST** | Build control list from Target/interfaces (`IRebasingClaimToken` + IERC20/metadata/SE in/out + both `mintFromNFTSale`; `IDETFNFTVault` + IERC721Metadata `tokenURI` + guarded transfers). After registry/factory deploy: loupe ≠ 0; low-level proxy call each sel (success or exact auth revert). `test_J1_claim_targetEqualsFacetFuncs`; `test_J2_claim_loupeWired`; `test_J3_claim_proxySmoke_*`; same for bond. |
| **Anti-theater** | Control from **Target**, not Facet source. Call **proxy**, not facet address. Do not count T01 as J3. |
| **Suggested WP-ID** | `WP-SEC-DETF-COM-J-001` |
| **Link TCA / prior** | `T-detf-single-vault-seigniorage` J marked **P**; no dedicated WP-J-CLAIM |
| **Depends / parallel** | Parallel with `WP-SEC-DETF-COM-D-001`. Parallel with family J WPs (different files). |

### 6.5 [SEC-DETF-COM-005] Bond/claim unit suites are theater

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-005` |
| **Title** | Do not score stub pure-math suites as D/H/I coverage |
| **Severity** | Medium |
| **Class** | **OWNED_ELSEWHERE** / **THEATER** |
| **Confidence** | confirmed |
| **Catalog IDs** | D, H |
| **Pattern IDs** | PAT-THEATER-FACET, PAT-MOCK |
| **Products** | DETFNFTVault.t.sol; RebasingClaimTokenRedemption.t.sol |
| **Impact** | False confidence only. |
| **Evidence** | Both files: `STUB / SPEC-ONLY`, `@custom:adversarial-status stub-not-production-path`. Bond stub still uses product-brand comments. |
| **Suggested WP-ID** | none new — `WP-TEST-DETF-SVS-001` |
| **Link TCA / prior** | `TCA-DETF-SVS-002`, `TCA-DETF-SVS-004`, `WP-TEST-DETF-SVS-001` |

### 6.6 [SEC-DETF-COM-006] Reward harvest `lastRewardTokenBalance` underflow / FoT

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-006` |
| **Title** | Harvest subtracts accounted rewards from lastBalance then transfers (FoT/skim DoS) |
| **Severity** | Medium |
| **Class** | **CODE** |
| **Confidence** | static-medium |
| **Catalog IDs** | K, H, L2 |
| **Pattern IDs** | PAT-K-DONATE |
| **EVM-audit domain** | erc20 / dos |
| **Products** | DETFNFTVaultService / Repo |
| **Impact** | If `rewardToken` is FoT or balance drops below lastBalance (skim / `transferHeldToken`), `lastRewardTokenBalance -= rewards_` underflows → **DoS** `claimRewards` / protocol harvest. Not a free extract. |
| **Evidence** | `DETFNFTVaultService.sol` L68–73; `_updateGlobalRewards` only writes when `current > last`. |
| **Recommended CODE** | Measure post-transfer delta; set `last = balanceOf`; or `last = last > rewards ? last - rewards : 0`. |
| **Recommended TEST** | `test_K_harvest_fotRewardToken_doesNotDoS`; FoT reward in PkgArgs. |
| **Suggested WP-ID** | cluster Medium in `WP-SEC-DETF-COM-D-001` or Wave-3 |
| **Link TCA / prior** | none |

### 6.7 [SEC-DETF-COM-007] Child diamonds: leftover / mis-set owner, no Ownable facet

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-007` |
| **Title** | Claim/bond init Ownable storage but do not cut Ownable; mis-set owner is sticky |
| **Severity** | Medium |
| **Class** | **CROPS** / **CODE** (surface) / **NEEDS_OWNER** if walkaway is required on children |
| **Confidence** | static-high |
| **Catalog IDs** | F, PAT-CROPS-ADMIN |
| **Pattern IDs** | PAT-CROPS-ADMIN, PAT-SHARP-FLAG |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | C / O / S |
| **Products** | RebasingClaimTokenDFPkg, DETFNFTVaultDFPkg |
| **Impact** | Correct wiring: owner = DETF, DETF unowned → children are DETF-operated, no user admin. Wrong `PkgArgs.owner` (EOA): `setDetf` / `transferHeldToken` / `createPosition` / mint/burn stay with EOA **and** proxy has no `transferOwnership` selector to fix it. Phantom `createPosition` + family `closeBondMature` can unwind reserve BPT. |
| **Evidence** | `initAccount` `MultiStepOwnableRepo._initialize(args.owner, 1 days)`. Claim cuts: ERC5267, ERC2612, claim facet only. Bond cuts: ERC721, ERC4626 views, protocol facet. |
| **Recommended CODE** | Family deploy must pass `owner = address(detf)` (verify; do not change law). Optional: cut Ownable **or** hardcode owner = DETF in `initAccount` and drop `PkgArgs.owner`. |
| **Recommended TEST** | `test_F_claim_ownerIsDetf_onFamilyDeploy`; `test_F_eoaOwner_createPosition_cannotCloseAgainstReserve` if product wants that invariant. |
| **Suggested WP-ID** | fold into family F1 / `S-crops-trust` addendum; no Wave-0 `sec_fix_*` unless a family is shown to pass EOA owner |
| **Link TCA / prior** | `S-crops-trust` (DETF unowned); MultiVault F1 leftover-admin |

### 6.8 [SEC-DETF-COM-008] Unused `ERC20_FACET` / dead foreign pull / unused `forceApprove`

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-008` |
| **Title** | Hygiene: unused claim ERC20_FACET; dead foreign `_secureTokenTransfer`; unused BPT approve |
| **Severity** | Low |
| **Class** | **CODE** (hygiene) |
| **Confidence** | confirmed |
| **Catalog IDs** | J, M, I4 |
| **Pattern IDs** | PAT-J-OMIT (false extra init), PAT-SHARP-FLAG |
| **Evidence** | `RebasingClaimTokenDFPkg` stores `ERC20_FACET` but `facetAddresses`/`facetCuts` omit it. `_secureTokenTransfer` foreign `safeTransferFrom` never used by public redeem/exchange. `DETFBondLifecycleLib._addReservePoolBptToDetfNft` `forceApprove` then `addToDETFNFT` (no `transferFrom`). |
| **Impact** | Integrator confusion; dead code drift. |
| **Suggested WP-ID** | Wave-4 fold |

### 6.9 [SEC-DETF-COM-009] Same-tx pretransfer (two-tx push fails)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-009` |
| **Title** | Claim credits same-tx inbound delta only (L-CLAIM-3 as implemented) |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** |
| **Confidence** | confirmed |
| **Catalog IDs** | I1 |
| **Pattern IDs** | PAT-SHARP-FLAG |
| **Products** | RebasingClaimToken (peer: Slipstream / Dual / LST — blast in `A-commons-pull`) |
| **Impact** | Two-tx “transfer then redeem(pretransferred=true)” **reverts**. Honest path is `pretransferred=false` (internal `_transfer`) or same-tx push+redeem. T03 locks this. Not a steal. |
| **Evidence** | Target L559–574; `test_I1_pretransferred_transferBeforeCall_revertsDelta0`; T03 `test_redeem_pretransferred_true_afterRealTransfer_revertsDelta0`. Contrast durable `U=B−R` on BasicVaultCommon / family `_pullToken`. |
| **Invariants** | Booked / idle inventory cannot fund I1. Victim claim shares unchanged. |
| **Suggested WP-ID** | none |

### 6.10 [SEC-DETF-COM-010] Owner-only `burnShares(pretransferred=true)` has no delta

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-010` |
| **Title** | DETF may burn claim inventory sitting on the diamond |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** |
| **Confidence** | confirmed |
| **Catalog IDs** | I1, D |
| **Evidence** | Target L446–462: `pretransferred` → `burnFrom = address(this)` if shares suffice. MultiVault `redeemClaim` uses `burnShares(..., false)` (burn from user). |
| **Invariants** | Only owner (DETF). User redeem uses `_secureTokenTransfer` delta. |
| **Suggested WP-ID** | none |

### 6.11 [SEC-DETF-COM-011] Threshold Open / expansion defaults (spec specialist)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-011` |
| **Title** | Cite shared threshold/expansion/compound libs to S-spec-detf; no new CODE here |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** / handoff |
| **Catalog IDs** | B3 |
| **Pattern IDs** | PAT-SPEC-DRIFT (only if family forks formula) |
| **Evidence** | `DETFThresholdPolicy` Open short-circuits mint/burn allow. `resolveThresholds(0,0)` → 1.05 / 0.95. Expansion `rateArg==0` → default **on**, not off. Compound is dust-only; join is family. Epoch `maxCatchUpEpochs==0` unlimited; `mintPerEpoch * epochs` overflow DoS possible. |
| **Suggested WP-ID** | none in this program; `S-spec-detf` + family areas |

### 6.12 [SEC-DETF-COM-012] Storage slot brand leftover / TrustFlags non-SUT mocks

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-COM-012` |
| **Title** | Claim slot string still says `richir`; I tests mock DETF not SUT |
| **Severity** | Info |
| **Class** | **DEFER** / **PAT-SLOT** / **PAT-MOCK** note |
| **Evidence** | `RebasingClaimTokenRepo.STORAGE_SLOT = keccak256("indexedex.vaults.protocol.richir")` — unique; do not rename without migration. TrustFlags `MockClaimDetf` + `vm.mockCall(nftVault)` — allowed for **non-SUT**; I1 on **proxy** still counts. Must not be cited as family DETF adversarial. |
| **Suggested WP-ID** | none |

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| `DETFNFTVault.t.sol` | Pure arithmetic; no DFPkg; header admits stub | `SEC-DETF-COM-005` / `WP-TEST-DETF-SVS-001` |
| `RebasingClaimTokenRedemption.t.sol` | Pure rate math; no redeem/pretransfer | Same |
| T01 “facet selectors” | Two views + one poke; both lists can omit the same money sel | `SEC-DETF-COM-004` full J matrix |
| `test_I2_pretransferred_claimedGtDelta0` | Zero delta ≡ I1 | Partial inbound I2 |
| Family `test_M14_*` `redeemPosition` EOA revert | Proves onlyOwner, not LP basis / double-redeem math | `SEC-DETF-COM-002` |
| Coverage “WP-I-CLAIM-001 7/7” without re-read | Could be stale if helper regressed | **Re-read at this SHA: helper is same-tx delta** |
| TrustFlags mock DETF as “DETF adversarially tested” | DETF is not SUT | Keep as claim-helper I only |
| Happy T04 / honest `redeem(false)` | Not I1 | Keep T03 + TrustFlags I1 |

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| `TCA-COMMON-005` / `TCA-DETF-SVS-003` / `WP-I-CLAIM-001` | **Yes** — `RebasingClaimTokenTarget._secureTokenTransfer` | **OWNED_ELSEWHERE**. CODE **closed** (same-tx delta + I1–I3 proxy). No `sec_fix_*`. |
| `TCA-DETF-SVS-002` / `TCA-DETF-SVS-004` / `WP-TEST-DETF-SVS-001` | **Yes** — stub suites | **OWNED_ELSEWHERE**. Hygiene only. |
| `TCA-COMMON-004` / `WP-I-CLONE-001` (RebasingDETFToken) | Clone outside allowlist | Blast only → `A-detf-composed-stable` |
| MultiVault / SSE `WP-I-DETF-*` / `WP-J-DETF-*` | Family pull / surface | Family areas. Commons does not re-own. |
| `WP-K-COMMON-001` | BasicVault K | `A-commons-pull`. Claim K is I3 absorb / `SEC-DETF-COM-003`. |
| `redeemPosition` effectiveShares | **No** prior TCA High | **New** Medium CODE `SEC-DETF-COM-002`. |
| Claim/bond J matrix | No WP-J-CLAIM | **New** High TEST `SEC-DETF-COM-004`. |

## 9. Work package stubs

**No Wave-0 `sec_fix_*` for claim PAT-I-ABS** (OWNED_ELSEWHERE / closed).

### WP-SEC-DETF-COM-J-001 — Claim + bond diamond J matrix (+ I2 short-delta)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-COM-J-001` |
| **Title** | Add Target-derived J1–J3 (and claim I2 short-delta) on production claim/bond proxies |
| **Severity** | High |
| **Class** | TEST |
| **Products** | RebasingClaimTokenDFPkg; DETFNFTVaultDFPkg |
| **Finding IDs** | `SEC-DETF-COM-004` (primary); fold `SEC-DETF-COM-003` |
| **Problem** | P0 J is not proven. T01 is a 3-selector smoke. I2 is an I1 duplicate. A dropped money selector would not fail CI. Attack one-liner: omit `redeem` / `transferHeldToken` / `sellPositionToDetfNft` from `facetFuncs` — users/DETF get `FunctionNotFound`. |
| **Production files (touch set)** | none required unless a real omit is found (then Facet/DFPkg only) |
| **Test files (touch set)** | new `test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_Surface.t.sol`; `…/bondNft/DETFNFTVault_Surface.t.sol`; extend TrustFlags for I2 short-delta |
| **Out of scope files** | Family DETF packages; Uni V4 local nft/rebasing; stub `*.t.sol` rewrite (owned by `WP-TEST-DETF-SVS-001`) |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-DETF-COM-D-001`; family J WPs; `WP-I-CLAIM-001` already closed |
| **Conflicts with coverage-audit WP** | none (no WP-J-CLAIM). Do not reopen `WP-I-CLAIM-001` CODE. |
| **Suggested worktree** | `sec_fix_detf-com-j` / branch `sec_fix/detf-com-j` |
| **Implementation notes** | `crane-adversarial-testing` J bar; `indexedex-testing` LR-7. Claim deploy: CREATE3 DFPkg (not registry). Bond: `indexedexManager.deployDETFNFTVaultDFPkg` + `deployVault`. Control from Target/`IRebasingClaimToken`/`IDETFNFTVault`. Never `via_ir`. Never `new` facets. DETF role names. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/common/**' --match-test 'test_J' -vv` and `--match-test 'test_I2_pretransferred_shortDelta'` green. Every Target money/view sel: loupe ≠ 0; proxy call ≠ FunctionNotFound. |
| **Anti-theater checks** | Control list not copied from Facet. Proxy not facet address. I2 must deliver `0 < delta < claimed` in-window. No `vm.mockCall` on claim/bond SUT. |
| **Proof-first?** | no (TEST; static J looks complete) |
| **Estimate** | M |

### WP-SEC-DETF-COM-D-001 — Align `redeemPosition` LP basis + local D/K harvest

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-COM-D-001` |
| **Title** | Redeem LP from originalShares; add proxy D/K harvest tests |
| **Severity** | Medium |
| **Class** | BOTH |
| **Products** | DETFNFTVault |
| **Finding IDs** | `SEC-DETF-COM-002` (primary); fold `SEC-DETF-COM-006` |
| **Problem** | Shared `redeemPosition` treats lock-bonus **reward weight** as LP claim. Families avoid the function today, but it is a live onlyOwner money API. Harvest lastBalance is FoT-fragile. Attack one-liner (if owner calls it): long-lock position extracts short-lock / protocol principal via `_convertToAssets(effective)`. |
| **Production files (touch set)** | `contracts/vaults/detf/common/bondNft/DETFNFTVaultTarget.sol`; optionally `DETFNFTVaultService.sol` lastBalance |
| **Test files (touch set)** | `test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVault_Authority.t.sol` (new) on registry proxy |
| **Out of scope files** | ComposedStable clone Target (sibling area); family `closeBondMature` bodies |
| **Depends on** | none. If CS clone copies the line, `A-detf-composed-stable` follows. |
| **Parallelizable with** | `WP-SEC-DETF-COM-J-001` |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-com-d` / branch `sec_fix/detf-com-d` |
| **Implementation notes** | Inventory law: original = LP; effective = rewards. Gold: family `closeBondMature`. DETF stub for `claimLiquidity` is a **non-SUT** double (like TrustFlags mock DETF) **or** drive via MultiVault TestBase `redeemPosition` after making DETF call it — prefer a minimal DETF stub so this WP does not edit family files. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/common/bondNft/**' --match-test 'test_D_' -vv`. Unequal-lock case: LP out matches original, not effective. Protocol NFT still `DETFNFTRestricted`. EOA still onlyOwner revert (exact selector). |
| **Anti-theater checks** | Not `DETFNFTVault.t.sol` pure math. Must call production `redeemPosition` on **proxy**. |
| **Proof-first?** | no |
| **Estimate** | M |

`SEC-DETF-COM-001` / `005` are OWNED_ELSEWHERE — **no** `sec_fix_*`.

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Notes |
|------|-------|-------|
| Claim PAT-I-ABS CODE | OWNED_ELSEWHERE / closed | Do not re-queue `WP-I-CLAIM-001` |
| Stub theater rewrite | OWNED_ELSEWHERE | `WP-TEST-DETF-SVS-001` |
| Same-tx vs durable-`U` | ACCEPTED_RISK | Claim = same-tx; families/commons pull = durable U (`A-commons-pull` SEC-COMMON-005) |
| `burnShares(pretransferred=true)` no delta | ACCEPTED_RISK | Owner/DETF orchestrator; families burn from user |
| `createPosition` ledger-only | ACCEPTED_RISK | Requires DETF owner + DETF already pulled LP |
| Rewards claimable while locked | ACCEPTED_RISK | Inventory comments: user/fee NFT rewards stay claimable |
| Claim redeem always-on (no burn threshold) | ACCEPTED_RISK | Interface: always redeemable; maturity gates **sell→claim**, not claim→rateAsset |
| Threshold Open / seigniorage / expansion | ACCEPTED_RISK + `S-spec-detf` | Do not re-author family law |
| Whether children need Ownable cut | NEEDS_OWNER | Walkaway vs immutability |
| Whether `redeemPosition` should exist at all | NEEDS_OWNER | Families unused; could deprecate vs fix basis |
| ERC2612 O1–O3 | DEFER | Crane facet; `S-signatures` |
| RebasingDETFToken / Uni V4 local claim-nft | N/A | Sibling areas |
| Family compound join / claimLiquidity | N/A | Family areas |
| via_ir | Forbidden | Never recommend |
| Forge this run | DEFER to orchestrator | Commands listed |

### Open questions

1. Should `redeemPosition` be removed from the shared facet (families unused) or fixed to `originalShares`?
2. Confirm every family `postDeploy` sets claim/bond `owner = address(detf)` (spot-check MultiVault gold: yes by convention; `S-crops-trust` addendum).
3. Should claim DFPkg drop unused `ERC20_FACET` from `PkgInit`?

## 11. Commands run

```bash
# Inventory
ls contracts/vaults/detf/common/{core,claimToken,bondNft,inventory,factory}

# Pull / trust / surface
rg -n '_secureTokenTransfer|pretransferred|TransferDeltaInsufficient' contracts/vaults/detf/common --glob '*.sol'
rg -n 'redeemPosition|effectiveSharesOf|_convertToAssets|transferHeldToken|onlyOwner' contracts/vaults/detf/common --glob '*.sol'
rg -n 'facetFuncs|diamondCut|ecrecover|permit' contracts/vaults/detf/common --glob '*.sol'

# Tests
rg -n 'test_I1_|test_I2_|test_I3_|test_J|test_D|RebasingClaimToken|DETFNFTVault' test --glob '*.sol'

# Coverage collision
rg -n 'WP-I-CLAIM-001|TCA-CLAIM|TCA-DETF-SVS|TCA-COMMON-005' docs/testing/coverage-audit

# Family close vs redeemPosition (reference)
rg -n 'function closeBondMature|redeemPosition\(' contracts/vaults/detf --glob '*.sol'
```

Forge **not** executed this run (monorepo compile 20–40+ min; orchestrator owns L-SEC-3). Static re-verify of `RebasingClaimTokenTarget._secureTokenTransfer` + TrustFlags/T03 source is the I1 close bill.
