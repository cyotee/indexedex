# Security Audit — A-detf-composed-stable

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · MODE=full · A-detf-composed-stable |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/**`; `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**`. Shared `contracts/vaults/detf/common/claimToken` **RebasingClaimToken** is **A-detf-commons** (blast only). **RebasingDETFToken** under `stable/common` **is in-scope**. |
| Test paths | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/**` (incl. `adversarial/`, `sequences/`); `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**` (incl. `adversarial/`) |
| Skills cited | `SECURITY_AUDIT_PRD` §2, §2.4, §3.8, §5–8, §19; `crane-adversarial-testing`; `indexedex-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `defi-incident-patterns`; `docs/agent/INDEXEDEX_AGENT_LAW.md` DETF sections; `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` (L-RSRV-*); `docs/vaults/DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md` (L-DETF-*) |
| Residual-risk scores | ComposedStableCommonDetf → **3**; RebasingDETFToken → **3**; ComposedStable BondNFTVault → **4**; MixedBufferMultiVaultStableDetf → **3** |
| Forge | **Not run** (orchestrator owns runtime; L-SEC-3). Static re-verify only. No Critical CODE → no runtime proof required. |

---

## 1. Executive summary

- **Residual-risk:** ComposedStableCommonDetf **3**, RebasingDETFToken **3**, BondNFTVault **4**, MixedBufferMultiVaultStableDetf **3**. No confirmed Critical extract. Historical PAT-I-ABS on CS `_secureTokenTransfer`, RebasingDETFToken pull/exact-out, and MixedBuffer `_pullToken` / burn is **closed** at this SHA (reserve-delta / same-tx delta). Gap-closure `WP-I-DETF-CS-001/002`, `WP-I-DETF-MB-001`, `WP-ADV-DETF-MB-001`, `WP-J-DETF-CS-MB-001`, `WP-G-E-DETF-CS-001`, `WP-I-CLONE-001` are **OWNED_ELSEWHERE** (STAGE3 44/44). Leftover Highs are **new** to this program: missing `nonReentrant` on CS mint/bond, leftover minter on the family `detfToken`, and missing catalog `test_A0_*`.
- **Critical / High counts:** **Critical 0** · **High 3** (2 CODE: `SEC-DETF-CS-013` lock, `SEC-DETF-CS-014` leftover `detfToken` owner/minter; 1 TEST: `SEC-DETF-CS-015` A0). **No leftover `diamondCut` / Ownable on the live DETF diamonds (L-SEC-11 statically clean).**
- **Top recommended WPs (this program):**
  1. `WP-SEC-DETF-CS-LOCK-001` — add `nonReentrant` on CS `exchangeIn` + `bond` (High CODE).
  2. `WP-SEC-DETF-CS-TOKEN-001` — strip leftover owner/minter on family `detfToken` after DETF is operator (High CODE / CROPS).
  3. `WP-SEC-DETF-CS-A0-001` — catalog A0 on CS + MixedBuffer production proxies (High TEST).
- **OWNED_ELSEWHERE count:** **12** (`SEC-DETF-CS-001`…`012` → `TCA-DETF-CS-001`…`011` + `WP-I-DETF-CS-001/002`, `WP-I-DETF-MB-001`, `WP-ADV-DETF-MB-001`, `WP-J-DETF-CS-MB-001`, `WP-G-E-DETF-CS-001`, `WP-I-CLONE-001`). **Do not** schedule competing `sec_fix_*` on those touch-sets.
- **Re-verify vs coverage-audit (2026-08-09) and pilot A-commons-pull §2.2.A:** CS `_secureTokenTransfer` and MB `_pullToken` are **no longer** `if (pretransferred_) return amount_`. Current bodies are reserve-delta `U = B − R` + `TransferDeltaInsufficient`. RebasingDETFToken pull is same-tx observed delta (I1-safe). Historical PAT-I-ABS = **OWNED_ELSEWHERE**. Stale TCA “I/J G / no adversarial on MB / no G on CS” is **false** at `1e0d7c48`.

---

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|---------------|
| **ComposedStableCommonDetf** | `ComposedStableCommonDetfDFPkg.sol`; Facets: ExchangeIn (13), ExchangeOutQuery (4), Bonding (11), RebasingDETFTokenPricing; MultiAsset Basic+Standard (views); Targets live on facet contracts (no split Target files for ExchangeIn/Bonding) | `TestBase_ComposedStableCommonDetf*.sol`; gold money graph = `ComposedStableCommonDetf_IntegratedDeploy.t.sol` | **Gold on integrated:** CREATE3 facets + `indexedexManager.deployComposedStableCommonDetfDFPkg` / `deployVault`. Companions passed in `PkgArgs` (not created in `postDeploy`). Crane factory **base** cuts are ERC165 + Loupe + ERC8109 + PostHook — **not** DiamondCut / Ownable. | **3** |
| **RebasingDETFToken** | `RebasingDETFTokenDFPkg.sol`; Facet 28 sels (ERC20 + claim + SE in/out); PricingFacet is cut on the **DETF** diamond, not this token | `RebasingDETFTokenBehavior.t.sol` (CREATE3 DFPkg + **Mock DETF** backend); IntegratedDeploy production claim | DFPkg via CREATE3 factory (`deployToken`); `MultiStepOwnable` init owner then gold path transfers to DETF | **3** |
| **ComposedStable BondNFTVault** | `ComposedStableCommonDetfBondNFTVaultDFPkg.sol`; ERC721 + ERC4626 vault facets + BondNFTVaultFacet + MultiStepOwnable | IntegratedDeploy + BondNFT deploy spec | Registry `deployVault`; owner transferred to DETF in gold setUp | **4** |
| **MixedBufferMultiVaultStableDetf** | `MixedBufferMultiVaultStableDetfDFPkg.sol`; ExchangeIn (4), Bonding (12), Info; ERC20/2612/5267 + MultiAsset Basic/Standard | `TestBase_MixedBufferMultiVaultStableDetf.sol` (co-located) | **Gold:** CREATE3 + `indexedexManager.deployVault`. `postDeploy` creates MixedBuffer reserve, bond NFT (owner=DETF), shared RebasingClaimToken (owner=DETF). | **3** |

### 2.1 Production file inventory

#### Composed stable (`…/stable/common/`)

| Path | Role |
|------|------|
| `ComposedStableCommonDetfDFPkg.sol` | Registry-gated `processArgs`; 6 facetCuts; `postDeploy` no-op |
| `ComposedStableCommonDetfExchangeIn.sol` | mint/burn exact-in; thresholds; compound; **`exchangeIn` has no `nonReentrant`** |
| `ComposedStableCommonDetfExchangeOutQueryFacet.sol` | exact-out + `claimLiquidity`; E6 refund = this-call overpay |
| `ComposedStableCommonDetfBondingFacet.sol` | bond (**no lock**) / sell / buyClaim / close / redeemClaim |
| `ComposedStableCommonDetfCommon.sol` | multi-leg join/exit; **`_secureTokenTransfer` reserve-delta**; nested push; `_previewExitSettle` |
| `ComposedStableCommonDetfRepo.sol` | slot `keccak256("detf.composed.stable.common.repo")` |
| `ComposedStableCommonDetfBondNFTVault*.sol` | bond NFT inventory diamond |
| `RebasingDETFTokenTarget.sol` / `Facet.sol` / `DFPkg.sol` | claim companion; same-tx delta pull; `burnShares` pretransfer still burns `address(this)` |
| `RebasingDETFTokenPricingFacet.sol` | IDETF views cut onto **DETF** diamond |
| `*_FactoryService.sol` | CREATE3 helpers |
| `TestBase_ComposedStableCommonDetf*.sol` | TestBase (unit + components) |

#### Mixed buffer (`…/mixedBuffer/`)

| Path | Role |
|------|------|
| `MixedBufferMultiVaultStableDetfDFPkg.sol` | Registry + `postDeploy` reserve / NFT / claim |
| `MixedBufferMultiVaultStableDetfCommon.sol` | stable math; **`_pullToken` reserve-delta**; residual helper |
| `MixedBufferMultiVaultStableDetfExchangeInTarget.sol` | mint/burn; **`nonReentrant`** |
| `MixedBufferMultiVaultStableDetfExchangeOutTarget.sol` | burn → buffer via `_pullToken` then burn diamond `detfToken` |
| `MixedBufferMultiVaultStableDetfBondingTarget.sol` | bootstrap / bond / sell / close / redeem / `claimLiquidity` gated |
| `MixedBufferMultiVaultStableDetfExchangeInFacet.sol` | 4 sels (in/out + previews) |
| `MixedBufferMultiVaultStableDetfBondingFacet.sol` | 12 sels |
| `MixedBufferMultiVaultStableDetfInfoFacet.sol` | views + compound |
| `MixedBufferMultiVaultStableDetfRepo.sol` | slot `keccak256("vault.detf.composed.stable.mixedBuffer.mixed-buffer-multi-vault-stable-detf.repo")` |
| `TestBase_MixedBufferMultiVaultStableDetf.sol` | gold TestBase |

### 2.2 Trust-flag / money entrypoints

| Product | Entrypoint | Flag | Credit path (this SHA) |
|---------|------------|------|------------------------|
| **CS DETF** | `exchangeIn` mint | `pretransferred` | `_secureTokenTransfer` → `U = B − R`; claimed > U → `TransferDeltaInsufficient` |
| **CS DETF** | `exchangeIn` burn | `pretransferred` | same pull on family `detfToken` (separate ERC-20) |
| **CS DETF** | `exchangeOut` | `pretransferred` | pull `maxAmountIn` via same helper; refund `depositedIn − amountIn_` (this-call) |
| **CS DETF** | `bond` | *none* | always `_secureTokenTransfer(..., false)` |
| **CS DETF** | `buyClaim` | `pretransferred` | pull then join **claimed** `detfAmount` |
| **RebasingDETFToken** | `redeem` / `exchangeIn` | `pretransferred` | same-tx `observedDelta`; claimed > delta → revert |
| **RebasingDETFToken** | `exchangeOut` | `pretransferred` | pull measured `amountIn` (not blind `maxAmountIn`) |
| **RebasingDETFToken** | `burnShares` | `pretransferred` | if true, burn from `address(this)` **without delta** (onlyOwner / DETF) |
| **MixedBuffer** | `exchangeIn` mint | `pretransferred` | `_pullToken` reserve-delta |
| **MixedBuffer** | burn via exchangeIn/Out | `pretransferred` | `_pullToken(detfToken)` then `_burnDetf(this, actualIn)` |
| **MixedBuffer** | `bond` / `buyClaim` | `pretransferred` | `_pullToken` on buffer / vaultShare / reserveBpt / detfToken |
| **MixedBuffer** | `bootstrapFirstBond` | *none* | always pull `false`; end-sync |

### 2.3 Test roots

| Root | Role |
|------|------|
| CS IntegratedDeploy + Threshold/Expansion/Compound/ProductLaw/NestedPush | Production-graph H |
| CS ExchangeIn/Out/Bonding unit | Route math — **MockStandardExchange** (not SUT money coverage) |
| CS `adversarial/Adversarial_ComposedStable_P0.t.sol` | Partial A–H on production graph; bare `expectRevert`; F1 ABI theater |
| CS `adversarial/Adversarial_ComposedStable_SecurePull.t.sol` | I1–I3 (DAI / U=0; L-RSRV-DUST documented) |
| CS `adversarial/Adversarial_Surface.t.sol` | J1–J3 on production proxy |
| CS `adversarial/Adversarial_ComposedStable_GE.t.sol` | E residual + G1 CS-as-nested |
| CS `sequences/` | L2 choreography |
| CS Rebasing behavior | Claim H + I1–I3 on **claim proxy** with **Mock DETF** backend |
| MB full matrix | Deploy/Mint/Burn/Bond/Claim/Guards/Nested/NLegs/… |
| MB `adversarial/Adversarial_MixedBuffer_P0.t.sol` | A–H P0 + C + G1 |
| MB `adversarial/Adversarial_MixedBuffer_TrustFlag.t.sol` | I1–I3 mint/burn/bond booked residual |
| MB `adversarial/Adversarial_Surface.t.sol` | J1–J3 (J2 ExchangeIn-only) |

---

## 3. Threat models

### 3.1 ComposedStableCommonDetf (live, unowned diamond; family `detfToken` is a **separate** mintable ERC-20)

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn` mint | pairToken / rateAsset → detfToken | `pretransferred` | fee oracle; Policy/Open | free mint from booked inventory (**blocked**); unbooked pairToken sniping (**L-RSRV-DUST** — DAI **not** in hold-set); **reenter mint/bond mid-pull (no lock)** |
| EXT | `exchangeIn` burn | detfToken → pairToken / rateAsset | `pretransferred` | burn gate | free extract of diamond detfToken (**blocked** once booked); no lock on burn |
| EXT | `exchangeOut` | detfToken → tokenOut | `pretransferred` | burn gate | E6 surplus refund of **this-call** unused (`depositedIn − amountIn_`) — not `balance − floor` |
| EXT | `bond` | pairToken → bond NFT | always `false` | lock terms | reenter via hostile pairToken (**no lock**); leftover admin n/a on diamond |
| EXT | `sellPositionToDetfNft` / `closeBondMature` | bond NFT → claim / settlement | maturity | none | pre-maturity exit (`BondNotMature`); preview units lie (`SEC-DETF-CS-016`) |
| EXT | `redeemClaim` | rebasingClaimToken → rateAsset / family burn token | none (DETF); claim token may pretransfer when caller is claim diamond | none | D2 without claim (**blocked**); H2 full-tx revert |
| EXT | `buyClaim` | detfToken → claim | `pretransferred` | none | join uses claimed not measured (FoT N/A on mintable detfToken) |
| EXT | `compoundProtocolRewards` | protocol pending detfToken → reserve BPT on protocol NFT | none | none | F5 skim to caller (**no**; credits protocol NFT; atomic is `NotSelf`) |
| EXT | `claimLiquidity` | reserve BPT unwind | none | none | unprivileged (`NotAuthorized` unless self/NFT/claim) |
| EXT | `diamondCut` / `owner()` | whole diamond | n/a | n/a | leftover upgrade (**statically absent**; F1 test is weak ABI) |
| CAP | skew underlying SE + mint/burn | vaultShare / detfToken | Open vs Policy | thresholds | Open seigniorage (**ACCEPTED_RISK** with B1 invariants) |
| HOS | hostile pairToken / vaultShare via routes | same | pull | none | reenter mint/bond (**lock missing** — `SEC-DETF-CS-013`) |
| INT | push + `pretransferred=true` | pairToken / detfToken | L-RSRV-CALLER | none | claimed > U reverts; DAI unbooked always funds true |
| ADM | leftover **detfToken** owner / operator | unbounded detfToken mint | n/a | deployer still owner in gold path | inflate family share / dilute (`SEC-DETF-CS-014`) |
| ADM | leftover companion owner if CFG skips transfer | claim `transferHeldToken` / NFT mint | MultiStepOwnable | gold tests transfer to DETF | drain claim inventory; gold path transfers |
| CFG | hostile route `underlyingVault` / zero minOut / Open | all | PkgArgs | deploy-time | misconfigured Open; hostile SE as route |

### 3.2 RebasingDETFToken (claim companion; Ownable — intended owner = DETF)

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `redeem` / `exchangeIn` | rebasingClaimToken → rateAsset | `pretransferred` | none | free redeem from idle inventory (**blocked** same-tx delta) |
| EXT | `exchangeOut` | claim → rateAsset | `pretransferred` | none | historical maxIn credit (**fixed**; now measures `amountIn`) |
| EXT | `burnShares` | claim shares | `pretransferred` | onlyOwner / DETF | unprivileged (**blocked**); owner/DETF can burn `address(this)` without inbound |
| EXT | `transferHeldToken` | any ERC-20 on claim diamond | n/a | onlyOwner | if leftover deployer owner: drain; gold path owner=DETF and DETF has no wrapper → **stuck dust** |
| ADM | `mintFromNFTSale` / `setDetf` | claim inflation / retarget | n/a | onlyOwner | gold path owner=DETF after buffer; CFG skip = High |

### 3.3 MixedBufferMultiVaultStableDetf (live, unowned diamond; detfToken **is** the diamond)

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn` mint | bufferToken / vaultShare → detfToken | `pretransferred` | fee oracle; gates | free mint booked inventory (**blocked**); unbooked dust sniping (L-RSRV-DUST) |
| EXT | `exchangeIn`/`exchangeOut` burn | detfToken → bufferToken | `pretransferred` | burn gate | free buffer vs donated detfToken (**blocked** once booked) |
| EXT | `bootstrapFirstBond` | buffer + vaultShares → BPT bond | always `false` | go-live | A0 first-bonder drain of pre-seeded inventory (**unproven**; pull-false + no credit of donations) |
| EXT | `bond` | buffer / vaultShare / reserveBpt | `pretransferred` | live only | same I class; **locked** |
| EXT | sell / close / redeemClaim | NFT / claim → bufferToken | maturity | none | D2/H2 covered in P0; preview buffer units (unlike CS BPT lie) |
| EXT | `claimLiquidity` | reserve BPT | none | none | unprivileged (`NotAuthorized`) |
| EXT | `compoundProtocolRewards` | protocol DETF → protocol NFT BPT | none | none | F5 no caller skim |
| EXT | `diamondCut` | diamond | n/a | n/a | statically absent; F1 theater |
| HOS | hostile vaultShare in PkgArgs | same | pull | none | C1–C3 `IsLocked` **tested** |
| CAP | Open skew | detfToken / buffer | Open | thresholds | ACCEPTED_RISK + B1 |
| ADM | leftover Cut/owner | n/a | n/a | n/a | **absent**; companions owned by DETF in `postDeploy` |

---

## 4. Catalog matrix (A–O, E6, F5)

| ID | Product | F/P/G/N/A/VULN | Evidence |
|----|---------|----------------|----------|
| A1 | CS | **F** | `Adversarial_ComposedStable_P0.test_A1_donateDai_cannotMintFreeDetf` (pull path) |
| A1 | MB | **F** | `test_A1_donateBuffer_cannotMintFreeDetf`; `test_A1_donateVaultShares_cannotMintFreeDetf` |
| A2 | CS | **F** | `test_A2_donateDetfToken_noTheft` |
| A2 | MB | **F** | `test_A2_donateDetfToDiamond_noTheft` |
| A3 | CS | **P** | combined D2 `test_A3_D2_redeemWithoutClaim_noPrincipalDrain` |
| A3 | MB | **F** | `test_A3_D2_redeemWithoutClaim_noBptDrain` |
| A4–A5 | both | **N/A** | Deferred P2 (MB P0 NatSpec) |
| **A0** | CS | **G** | **No `test_A0_*`.** Inert until reserve bootstrap; mint after live. → `SEC-DETF-CS-015` |
| **A0** | MB | **G** | **No `test_A0_*`.** `bootstrapFirstBond` pull-false; donations not joined. Proof missing. |
| B1 | CS | **P** | Threshold/ProductLaw; no catalog-labeled skew suite |
| B1 | MB | **F** | `test_B1_openThresholds_mintBurn_boundsSafety` |
| B3 | CS | **P** | ThresholdMode (not adversarial-labeled) |
| B3 | MB | **F** | `test_B3_thresholdGates_coupleToSynthetic` |
| C1–C3 | CS | **VULN** | **No `nonReentrant` on `exchangeIn` / `bond`.** P0 NatSpec still defers C. → `SEC-DETF-CS-013` |
| C1–C3 | MB | **F** | P0 C1–C3 + `MixedBuffer…_Reentrancy` exact `IsLocked` |
| D2 | CS | **F** | P0 A3/D2 |
| D2 | MB | **F** | P0 A3/D2 + sell non-owner |
| D3 | CS | **F** | `test_D3_doubleRedeemClaim_secondReverts` |
| D3 | MB | **F** | double sell / over-redeem |
| D6 | MB | **F** | `test_D6_redeemBoundedByClaimAndInventory` |
| D6 | CS | **P** | over-redeem via D3/H2; no explicit inventory-cap test |
| E1 | CS | **P** | sequences + GE mint/partial burn |
| E1 | MB | **F** | `test_E1_mintThenPartialBurn_conservation` |
| E4 | both | **F** | P0 holder non-dilution |
| E5 | CS | **P** | zero preview; expired deadline **bare** revert |
| E5 | MB | **F** | exact `ZeroAmount` / `DeadlineExpired` |
| **E6** | CS | **F** | `exchangeOut` refunds `depositedIn − amountIn_` only (`ExchangeOutQueryFacet` ~169–175). Not `balance − floor`. |
| **E6** | MB | **N/A** | No surplus-pay-to-caller refund path |
| F1 | both | **P** | Tests exist; **invalid `diamondCut` ABI** (theater). Static cuts have no Cut/Ownable. → `SEC-DETF-CS-017` |
| F2–F3 | CS | **P** | F2 onlyOwner; F3 claim onlyOwner not cataloged on production claim |
| F2–F3 | MB | **F** | P0 F2/F3 |
| F4 | MB | **F** | `test_F4_noSetWeightsOrThresholds` |
| **F5** | both | **F** | compound permissionless → protocol NFT only; `claimLiquidity` auth-gated; atomic `NotSelf` |
| G1 | CS | **F** | GE: CS-as-nested under outer SingleSE; CS-as-outer nested DETF legs **N/A** (product law) |
| G1 | MB | **F** | Nested.t.sol + P0 `test_G1_outerActivity_doesNotBrickInner` |
| H2 | CS | **F** | `test_H2_redeemClaim_failLeavesClaim` |
| H2 | MB | **F** | `test_H2_redeemClaim_minOutFail_claimUnchanged` |
| H3 | both | **F** | minOut fail residual |
| **I1–I3** | CS | **P** | SecurePull suite exists; **DAI not in hold-set** so I1 is U=0 / dust law, not booked pairToken. Hold-set I1 (detfToken/BPT) **thin**. |
| **I1–I3** | MB | **F** | TrustFlag booked residual mint/burn/bond; I1 does **not** transfer |
| **I1–I3** | Rebasing | **P** | Behavior I1–I3 on claim **proxy** (CREATE3); backend is **Mock DETF** (payout theater; pull revert is real) |
| I4 | both | **N/A** | Legs are SE shares / mintable detfToken / buffer; not FoT product |
| I5 | both | **N/A** | No user Permit2 money path (CS Permit2 is router spend for Balancer) |
| **J1** | CS | **P** | Surface subset + compoundAtomic; bonding length floor was 4 but asserts 11 sels |
| **J1** | MB | **F** | Target-derived 40-sel control ⊆ union facetFuncs |
| **J2** | CS | **F** | All four product facets loupe-mapped |
| **J2** | MB | **P** | Loupe loop is **ExchangeIn only** (Bonding/Info not iterated) |
| **J3** | CS | **P** | Views + one mint + compound; not redeem/close/exchangeOut |
| **J3** | MB | **P** | Views + mint + expected reverts; not full API |
| J4 | both | **P** | DFPkg `facetCuts` bind `facetFuncs()`; no dedicated length test |
| **K1** | CS | **P** | A1 pull-path; I3 residual; DAI unbooked is dust not K1 |
| **K1** | MB | **F** | I3 booked residual after honest sync |
| L1 | both | **P** | No public skim; nested push does not refund leftover to `msg.sender` |
| L2 | both | **N/A** | FoT not a product claim |
| L3 | both | **P** | No L3 handler; B1 Open bounds on MB |
| M1–M3 | both | **N/A** | No user `target+calldata`. CS `_approvePermit2Spend` is configured router only |
| N1 | both | **P** | MB lock covers same-tx; CS mint/bond unlocked (see C) |
| N2 | CS | **VULN** | mint preview used in IntegratedDeploy `assertGe`; **`_previewExitSettle` returns `bptIn_` for non-rateAsset** → `SEC-DETF-CS-016` |
| N2 | MB | **P** | close/redeem preview quotes buffer via live balances + SE preview; no dedicated `test_N2_*` |
| O1–O3 | both | **N/A** | ERC-2612 is share permit on MB diamond / Rebasing; no product Permit2 witness |

**P0 DETF subset:** A1/A3/D2/D3/E5/F2/H2/H3 = **F** (MB stronger); **I1–I3** MB **F**, CS **P**; **J1–J3** **P**; **A0 = G** both; **C** CS **VULN**, MB **F**; E6 CS **F** / MB N/A; F5 **F**; N2 CS **VULN** (Medium).

---

## 5. Domain notes

Walked locally (evm-audit domains as hunt lists; ship-gate remains Crane DoD):

| Domain | Notes |
|--------|--------|
| **general** | CS routes closed-form; `InvalidRoute` on claim as exchange token; CEI partial. CS mint/bond **lack** reentrancy guard. MB CEI + `nonReentrant` on money paths. `try/catch` only on best-effort compound (product law). |
| **precision-math** | WAD / Balancer StableMath + weighted reserve. CS `_previewExitSettle` is linear BPT for non-rateAsset. MB burn preview uses live balances. Expansion via `DETFNaturalExpansionLib`. |
| **erc20** | `BetterSafeERC20`; pull-false FoT-safe (returns delta). CS family `detfToken` is mintable Ownable/Operable (not the diamond). MB detfToken **is** diamond ERC-20. |
| **erc4626** | Bond NFT vault is 4626-like (LP = reserve BPT). Rebasing claim is 4626-like (commons pattern). |
| **defi-amm** | CS: weighted reserve of detfToken + stable BPT + common BPT; routes through SE vaults. MB: MixedBuffer stable (buffer + N vaultShares + self-leg). Spot skew = B1. |
| **proxies** | Unique repo slots (listed §2.1). No DiamondCut in factory base or DFPkgs. CS PricingFacet on DETF diamond (views only). Rebasing DFPkg **omits unused `erc20Facet` from cuts** (ERC20 lives on RebasingDETFTokenFacet — not a clash). |
| **access-control** | DETF instances unowned. `claimLiquidity` allowlist. Companions MultiStepOwnable: gold CS transfers to DETF; MB `postDeploy` sets owner=DETF. **Family `detfToken` owner remains deployer** (operator=DETF only). |
| **oracles** | Thresholds deploy-time; fees via fee oracle (blast → `A-manager-fee-registry`). No spot-as-sole mint oracle (synthetic + deadband). |
| **flashloans** | CAP skew covered by B1 on MB; CS B thin. Open seigniorage accepted. |
| **dos** | minOut / deadline; N=max deferred P2. CS multi-leg join revert is atomic (no partial persist). |
| **erc721** | Bond NFT maturity gates sell/close. CS BondNFTVault `transferFrom` replaced with guarded selectors. |
| **CROPS** | Walkaway: mint/burn/bond/sell-mature/redeem without team. Registry disable cannot brick instance functions. **L-SEC-11 leftover Cut/owner on DETF diamonds: statically absent.** Leftover **share-token** minter is the CROPS High. Fee oracle residual trust (other area). |
| **sharp-edges** | `pretransferred` caller-supplied (L-RSRV-CALLER). CS companions + `detfToken` owner are **manual** (not DFPkg). PkgArgs zeros → Policy + defaults. `minOut=0` common. Hostile `underlyingVault` / vaultShares accepted if CFG deploys them. Permit2 expiry `type(uint48).max` to configured router. |
| **spec** | Sell→claim / close only after maturity — **code matches** (`_requireMature`). Compound public + lazy — matches. CS-as-outer nested DETF legs **N/A** (GE NatSpec). No family `*_PRD.md` co-located under `stable/` (shared `docs/detf/*` + agent law). |
| **incidents** | A0 empty-vault (untested); I trust-flag (fixed + tested); L1 skim (no public reclaim); E6 surplus-refund (CS capped this-call); F5 structural (compound does not pay caller); C reentrancy (CS live). |

---

## 6. Findings

### 6.1 [SEC-DETF-CS-001] — PAT-I-ABS CS `_secureTokenTransfer` (re-verified closed)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-001 |
| **Title** | Historical blind pretransfer credit on ComposedStable `_secureTokenTransfer` |
| **Severity** | Info (was coverage Blocker) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high (CODE shape re-read at `1e0d7c48`; forge not run) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | trust-flag free mint |
| **Products** | ComposedStableCommonDetf |
| **Blast radius** | this package (clone of commons pattern; commons owned by A-commons-pull) |
| **Impact** | None remaining on **booked** hold-set if reserve-delta + end-sync hold |
| **Evidence** | `ComposedStableCommonDetfCommon.sol` 301–316: `U = B0 - R`; `amount_ > U` → `TransferDeltaInsufficient`; pull-false returns `balance − B0`. Call sites ExchangeIn ~164/194, ExchangeOut ~137, buyClaim ~214. Pilot A-commons-pull §2.2.A listed this clone as reserve-delta — **confirmed**. Coverage `TCA-DETF-CS-001` / `WP-I-DETF-CS-001` STAGE3 closed. |
| **Recommended TEST** | none new (owned) |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none — **do not** open `sec_fix_*` |
| **Link TCA / prior** | TCA-DETF-CS-001, WP-I-DETF-CS-001, WP-I-CLONE-001 |
| **Depends / parallel** | n/a |

### 6.2 [SEC-DETF-CS-002] — PAT-I-ABS RebasingDETFToken pull / exact-out (re-verified closed)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-002 |
| **Title** | Historical blind pretransfer + exact-out `maxAmountIn` credit on RebasingDETFToken |
| **Severity** | Info (was coverage Blocker) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **Products** | RebasingDETFToken |
| **Blast radius** | CS claim companion only (shared RebasingClaimToken is A-detf-commons) |
| **Impact** | Pull/exact-out free credit **closed**. Residual `burnShares` pretransfer = `SEC-DETF-CS-020`. |
| **Evidence** | `RebasingDETFTokenTarget.sol` 428–454: snapshot + `observedDelta`; pretransfer `amount_ > observedDelta` → `TransferDeltaInsufficient`. `exchangeOut` ~222–226 calls `_secureTokenTransfer(tokenIn, amountIn, …)` (quoted in, not `maxAmountIn`). Tests: `RebasingDETFTokenBehavior.test_I1_*` / `test_I2_*` / `test_I3_*`. `WP-I-DETF-CS-001` STAGE3 closed. |
| **Recommended TEST** | none (owned) |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-CS-002, WP-I-DETF-CS-001 |
| **Depends / parallel** | n/a |

### 6.3 [SEC-DETF-CS-003] — PAT-I-ABS MixedBuffer `_pullToken` (re-verified closed)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-003 |
| **Title** | Historical blind `_pullToken` on MixedBuffer |
| **Severity** | Info (was coverage Blocker) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **Products** | MixedBufferMultiVaultStableDetf |
| **Blast radius** | this package |
| **Impact** | None remaining on booked hold-set |
| **Evidence** | `MixedBufferMultiVaultStableDetfCommon.sol` 538–551: same `U = B − R` as MultiVault. Tests: `Adversarial_MixedBuffer_TrustFlag` I1/I2/I3. `WP-I-DETF-MB-001` STAGE3 closed. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-CS-003, WP-I-DETF-MB-001, WP-I-CLONE-001 |
| **Depends / parallel** | n/a |

### 6.4 [SEC-DETF-CS-004] — PAT-I-ABS MixedBuffer burn skip-transfer (re-verified closed)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-004 |
| **Title** | Historical MixedBuffer burn skipped transfer and burned diamond inventory |
| **Severity** | Info (was coverage Blocker) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1, A2 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **Products** | MixedBufferMultiVaultStableDetf |
| **Blast radius** | this package |
| **Impact** | Closed — burn now `_pullToken` then `_burnDetf(this, actualIn_)` |
| **Evidence** | `MixedBufferMultiVaultStableDetfExchangeOutTarget.sol` 42–46. I1 burn: `test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf`. `WP-I-DETF-MB-001`. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-CS-004, WP-I-DETF-MB-001 |
| **Depends / parallel** | n/a |

### 6.5 [SEC-DETF-CS-005] — CS I-suite ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-005 |
| **Title** | Catalog I1–I3 tests already filed for ComposedStable + Rebasing |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed (files present) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-THEATER-PRE (partial leftover → 6.18) |
| **EVM-audit domain** | erc20 |
| **Products** | ComposedStableCommonDetf; RebasingDETFToken |
| **Blast radius** | tests |
| **Impact** | none for ownership; residual theater = `SEC-DETF-CS-018` |
| **Evidence** | `Adversarial_ComposedStable_SecurePull.t.sol`; `RebasingDETFTokenBehavior.t.sol` I1–I3. `WP-I-DETF-CS-002` STAGE3 closed. |
| **Recommended TEST** | residual → 6.18 |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-CS-005, WP-I-DETF-CS-002 |
| **Depends / parallel** | n/a |

### 6.6 [SEC-DETF-CS-006] — MB I-suite ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-006 |
| **Title** | MixedBuffer I1–I3 + K1 booked-residual tests exist |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | I1–I3, K1 |
| **Pattern IDs** | PAT-THEATER-PRE (absent on TrustFlag — I1 does **not** transfer) |
| **EVM-audit domain** | erc20 |
| **Products** | MixedBufferMultiVaultStableDetf |
| **Blast radius** | tests |
| **Impact** | none |
| **Evidence** | `Adversarial_MixedBuffer_TrustFlag.t.sol`; folded into `WP-ADV-DETF-MB-001` / `WP-I-DETF-MB-001`. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-CS-006, TCA-DETF-CS-009, WP-ADV-DETF-MB-001 |
| **Depends / parallel** | n/a |

### 6.7 [SEC-DETF-CS-007] — J-suite ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-007 |
| **Title** | J1–J3 suites exist (partial leftover in 6.19) |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-THEATER-FACET (historical; Surface now deploys proxy) |
| **EVM-audit domain** | proxies |
| **Products** | ComposedStableCommonDetf; MixedBufferMultiVaultStableDetf |
| **Blast radius** | tests |
| **Impact** | residual incompleteness = `SEC-DETF-CS-019` |
| **Evidence** | CS/MB `adversarial/Adversarial_Surface.t.sol`; `WP-J-DETF-CS-MB-001` STAGE3 closed. |
| **Recommended TEST** | residual → 6.19 |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-CS-007, WP-J-DETF-CS-MB-001 |
| **Depends / parallel** | n/a |

### 6.8 [SEC-DETF-CS-008] — MB A–H adversarial ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-008 |
| **Title** | MixedBuffer catalog A–H P0 suite exists |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | A–H P0 |
| **Pattern IDs** | none |
| **EVM-audit domain** | general |
| **Products** | MixedBufferMultiVaultStableDetf |
| **Blast radius** | tests |
| **Impact** | none (A0 still missing — 6.15) |
| **Evidence** | `Adversarial_MixedBuffer_P0.t.sol` (27 tests); `WP-ADV-DETF-MB-001` STAGE3 32/32. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-CS-008, TCA-DETF-CS-011, WP-ADV-DETF-MB-001 |
| **Depends / parallel** | n/a |

### 6.9 [SEC-DETF-CS-009] — K1 ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-009 |
| **Title** | K1 donate→pretransfer folded into I WPs |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | K1 |
| **Pattern IDs** | PAT-K-DONATE |
| **EVM-audit domain** | erc20 |
| **Products** | CS; MixedBuffer |
| **Blast radius** | tests |
| **Impact** | unbooked donation is L-RSRV-DUST (`SEC-DETF-CS-022`) |
| **Evidence** | MB I3; CS I3/dust control. TCA-DETF-CS-009 folded into I WPs. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-CS-009, WP-I-DETF-CS-002, WP-ADV-DETF-MB-001 |
| **Depends / parallel** | n/a |

### 6.10 [SEC-DETF-CS-010] — G/E ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-010 |
| **Title** | ComposedStable nested G1 (as nested) + production residual E |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | G1, E1, E2 |
| **Pattern IDs** | none |
| **EVM-audit domain** | defi-amm |
| **Products** | ComposedStableCommonDetf |
| **Blast radius** | tests |
| **Impact** | none; CS-as-outer nested DETF legs documented N/A |
| **Evidence** | `Adversarial_ComposedStable_GE.t.sol`; `WP-G-E-DETF-CS-001` STAGE3 10/10. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-CS-010, WP-G-E-DETF-CS-001 |
| **Depends / parallel** | n/a |

### 6.11 [SEC-DETF-CS-011] — claim adversarial ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-011 |
| **Title** | Claim D/H adversarial exists (CS P0 + MB P0) |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | D2, D3, D6, H2 |
| **Pattern IDs** | none |
| **EVM-audit domain** | erc721 |
| **Products** | CS; MixedBuffer; RebasingDETFToken |
| **Blast radius** | tests |
| **Impact** | none |
| **Evidence** | CS P0 D3/H2; MB P0 D2/D3/D6/H2; shared claim I owned by `WP-I-CLAIM-001` (A-detf-commons). |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-CS-011, WP-ADV-DETF-MB-001, WP-I-CLAIM-001 |
| **Depends / parallel** | n/a |

### 6.12 [SEC-DETF-CS-012] — clone-pull alignment ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-012 |
| **Title** | Clone pull helpers aligned to reserve-delta (Wave-0 clone WP) |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **Products** | CS; MixedBuffer |
| **Blast radius** | clone set (commons) |
| **Impact** | none remaining on these two clones |
| **Evidence** | `WP-I-CLONE-001` STAGE3 closed; bodies match MultiVault / BasicVaultCommon. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | WP-I-CLONE-001, TCA-COMMON-004 |
| **Depends / parallel** | n/a |

### 6.13 [SEC-DETF-CS-013] — CS mint/bond missing reentrancy lock

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-013 |
| **Title** | Add `nonReentrant` on ComposedStable `exchangeIn` and `bond` |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high · **RUNTIME_UNPROVEN** |
| **Catalog IDs** | C1–C3, N1 |
| **Pattern IDs** | none (C-class production omit) |
| **EVM-audit domain** | general |
| **CROPS pillar** | n/a |
| **Incident theme** | reentrancy |
| **Products** | ComposedStableCommonDetf |
| **Blast radius** | this family (mint/burn/bond). MixedBuffer already locked. |
| **Attacker** | HOS / EXT |
| **Attack scenario** | 1. CFG or route `baseToken` / `vaultToken` is a hostile ERC-20 that callbacks on `transferFrom`. 2. Attacker calls `exchangeIn(..., pretransferred=false)` or `bond`. 3. During pull, token reenters `exchangeIn(pretransferred=true)` against in-flight unbooked `U = B − R` (R not yet synced) **or** reenters `bond` / `buyClaim` / `exchangeOut`. 4. Same-tx unbooked surplus can be credited a second time before outer end-sync. 5. Gold MultiVault / MixedBuffer block this with `IsLocked`. CS ExchangeIn does **not** inherit `ReentrancyLockModifiers`; `bond` inherits the modifier set but **does not apply** `nonReentrant`. |
| **Preconditions** | Hostile pairToken (or vaultShare) accepted as a live route token; or any ERC-777-style callback token. |
| **Impact** | Cross-function reentry during multi-leg join/exit. Not proven unbounded extract (outer `actualIn` may collapse to 0 after inner consume) — **not Critical** without runtime. Still a P0 lock hole vs product law. |
| **Evidence** | `ComposedStableCommonDetfExchangeIn.sol` 233–241: `exchangeIn` has **no** `nonReentrant`. `ComposedStableCommonDetfBondingFacet.sol` 115–118: `bond` unlocked; contrast 153/201/243/289 `nonReentrant` on sell/buyClaim/close/redeem. ExchangeOut 188 is locked. Coverage TCA-DETF-CS-014 asked to confirm — **confirmed missing**. CS P0 NatSpec still defers C. |
| **Runtime** | n/a (High, not Critical CODE). Stage 2 proof-first recommended. |
| **Recommended CODE** | `ComposedStableCommonDetfExchangeIn`: inherit `ReentrancyLockModifiers`; mark `exchangeIn` `nonReentrant`. `ComposedStableCommonDetfBondingFacet.bond`: add `nonReentrant`. Same lock slot as other facets. |
| **Recommended TEST** | `test_C1_hostilePairToken_reenterExchangeIn_hitsIsLocked`; `test_C2_hostilePairToken_reenterBond_hitsIsLocked`; `test_C3_mintReenterBond_hitsIsLocked`. Production IntegratedDeploy + hostile ERC-20 as `baseToken` (or route vaultShare). Exact `IsLocked`. `forge test --match-path '…/stable/common/adversarial/**' --match-test 'test_C'` |
| **Anti-theater** | Hostile token must be a **configured route token** via production PkgArgs — not `vm.mockCall` on SUT. Nested call must complete outer transfer. Assert `reentryAttempts==1` and `nestedCallSucceeded==false`. |
| **Suggested WP-ID** | `WP-SEC-DETF-CS-LOCK-001` |
| **Link TCA / prior** | TCA-DETF-CS-014 (coverage TEST; **this is the CODE confirm**) — not the same as a closed CODE WP |
| **Depends / parallel** | Parallel with TOKEN/A0; do not touch `_secureTokenTransfer` (owned) |

### 6.14 [SEC-DETF-CS-014] — Leftover owner/minter on family `detfToken`

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-014 |
| **Title** | Strip leftover owner/minter on ComposedStable family `detfToken` after DETF is operator |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high (gold path leaves deployer as owner) |
| **Catalog IDs** | F, A0 |
| **Pattern IDs** | PAT-CROPS-ADMIN, PAT-SHARP-FLAG |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | S (upgrade/admin) / C (custody of mint) |
| **Incident theme** | leftover admin |
| **Products** | ComposedStableCommonDetf (family share token) |
| **Blast radius** | every CS instance using `ERC20MintBurnOwnableOperable` as `PkgArgs.detfToken` |
| **Attacker** | ADM / CFG |
| **Attack scenario** | 1. Deployer deploys mintable `detfToken` with `owner = deployer` (`IntegratedDeploy._deployDetfToken`). 2. After DETF deploy, gold path only `_authorizeDetfTokenOperator(deployedDetfVault)` — **does not** transfer/renounce token ownership. 3. Deployer (or compromised key) calls `mint` / `setOperator` on `detfToken`. 4. Inflated supply dilutes `_syntheticDetfEthPrice` / expansion / reserve accounting; minted tokens can be sold via `exchangeIn` burn into reserve inventory. 5. MixedBuffer is immune (diamond **is** the share). MultiVault is immune (same). |
| **Preconditions** | Production CS architecture **requires** an external mintable `detfToken` (diamond is not ERC-20). Gold integrated path is the documented deploy. |
| **Impact** | Unbounded family-share inflation by leftover admin after the DETF diamond is “unowned/immutable.” L-SEC-11 on the **diamond** is clean; the **share token** is not. |
| **Evidence** | `ComposedStableCommonDetf_IntegratedDeploy.t.sol` 297–301, 632–646: operator set; bond/claim ownership transferred; **detfToken owner stays `owner`**. `_mintDetf` (`Common.sol` 962–964) is `IERC20MintBurn.mint`. No DFPkg hook to own/renounce the share token. |
| **Runtime** | n/a (High; static deploy-path evidence is the gold TestBase itself) |
| **Recommended CODE** | After `setOperator(DETF, true)`, transfer `detfToken` ownership to the DETF **or** renounce + disable further `setOperator`. Prefer DETF-owned with no public mint wrapper (mint only via operator). Document in DFPkg NatSpec. Product-owner may instead declare managed share as `ACCEPTED_RISK` — then **must** publish invariants (who holds the key; no silent extra minter). |
| **Recommended TEST** | `test_F_detfToken_ownerIsDetfOrRenounced`; `test_F_deployer_cannotMintAfterGoLive`; `test_F_onlyDetfOperator_mints`. `forge test --match-path '…/stable/common/**' --match-test 'test_F_detfToken'` |
| **Anti-theater** | Must call **share token** `owner()` / `mint` as deployer after integrated setUp — not only DETF `owner()`. |
| **Suggested WP-ID** | `WP-SEC-DETF-CS-TOKEN-001` |
| **Link TCA / prior** | none (coverage did not file CROPS leftover minter) |
| **Depends / parallel** | May `NEEDS_OWNER` if product wants a managed share. Parallel with LOCK/A0. |

### 6.15 [SEC-DETF-CS-015] — Missing A0 empty-inventory proof

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-015 |
| **Title** | Add catalog A0 proof that first live minter/bonder cannot drain pre-seeded inventory |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | static-high (no `test_A0_*`; production **appears** gated) |
| **Catalog IDs** | A0 |
| **Pattern IDs** | PAT-A0-EMPTY |
| **EVM-audit domain** | erc4626 |
| **CROPS pillar** | n/a |
| **Incident theme** | empty vault / first deposit drain |
| **Products** | ComposedStableCommonDetf; MixedBufferMultiVaultStableDetf |
| **Blast radius** | both money products in this area |
| **Attacker** | EXT / CFG |
| **Attack scenario** | 1. Deploy inert instance (`totalSupply` user detfToken = 0 / MB `!isReserveLive`). 2. Donate pairToken / buffer / vaultShare / reserveBpt to the diamond. 3. CS: bootstrap reserve then first mint/bond. MB: `bootstrapFirstBond` then first mint. 4. Attacker must **not** convert **others’** pre-seeded inventory into principal beyond L-RSRV-DUST same-tx window. 5. Pass = enrichment ≤ own pull after first honest money-route sync. |
| **Preconditions** | Fresh instance; donated inventory before live; no mock SUT |
| **Impact** | Unproven P0. Static read: CS mint after live uses reserve-delta; MB bootstrap pull-false and does not credit donations. Ship-gate still requires the test. |
| **Evidence** | `rg test_A0_` under `stable/` + `mixedBuffer/` → **no matches**. MB `bootstrapFirstBond` (`BondingTarget.sol` 82–143) pulls `false` and end-syncs. CS IntegratedDeploy bootstrap does not consume stray donations into first mint credit. |
| **Runtime** | n/a (not Critical CODE) |
| **Recommended CODE** | none unless A0 test fails (then treat as CODE) |
| **Recommended TEST** | `test_A0_cs_preLive_donatedPairToken_cannotBeFirstMinted`; `test_A0_mb_donatedBuffer_bootstrapDoesNotStealOthersSeed`; `test_A0_mb_emptyUserSupply_donatedInventory_notDrainedByFirstMint`. `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/{stable,mixedBuffer}/**' --match-test 'test_A0_'` |
| **Anti-theater** | Donate **before** live; do not count L-RSRV-DUST same-tx self-push as A0; call **proxy**; no `MockStandardExchange` |
| **Suggested WP-ID** | `WP-SEC-DETF-CS-A0-001` |
| **Link TCA / prior** | none (coverage-audit did not file A0) |
| **Depends / parallel** | Parallel with LOCK/TOKEN; do not touch `_pullToken` / `_secureTokenTransfer` |

### 6.16 [SEC-DETF-CS-016] — CS claim/close preview returns BPT for non-rateAsset

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-016 |
| **Title** | `previewRedeemClaim` / `previewCloseBondMature` quote raw BPT when `tokenOut` is not rateAsset |
| **Severity** | **Medium** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | N2 |
| **Pattern IDs** | PAT-N-TOCTOU |
| **EVM-audit domain** | general |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | ComposedStableCommonDetf |
| **Blast radius** | CS family; same helper if cloned |
| **Attacker** | INT / EXT (integrator minOut from preview) |
| **Attack scenario** | 1. Holder sells mature bond → claim or `closeBondMature(tokenOut=pairToken)`. 2. Integrator sets `minOut = preview*(tokenOut)`. 3. `_previewExitSettle` returns `previewClaimLiquidity` only for `rateAsset`; else **`return bptIn_`** (`Common.sol` 1261–1267). 4. Wrong units → revert (exit grief) or sandwichable SE hop. |
| **Preconditions** | Live instance; claim or mature bond; `tokenOut` ≠ rateAsset |
| **Impact** | Wrong minOut: revert or unprotected unwind. Not unbounded extract. |
| **Evidence** | `_previewExitSettle` 1261–1267; used by BondingFacet `previewRedeemClaim` / `previewCloseBondMature`. Contrast MB `_previewExitSettleBuffer` (buffer + share legs). |
| **Runtime** | n/a (Medium) |
| **Recommended CODE** | Preview via same path as `_consolidatePoolBptsToTokenOut` / underlying `previewExchangeIn`. |
| **Recommended TEST** | `test_N2_previewRedeemClaim_equalsExecute`; `test_N2_previewCloseBondMature_equalsExecute`. |
| **Anti-theater** | Compare preview to **execute out** of the same `tokenOut`; not merely `preview > 0` |
| **Suggested WP-ID** | fold into a Medium `WP-SEC-DETF-CS-N2-001` (not Wave-0) |
| **Link TCA / prior** | TCA-DETF-CS-016 (preview≡execute TEST) — this is the **CODE** half for claim/close |
| **Depends / parallel** | Parallel with A0 |

### 6.17 [SEC-DETF-CS-017] — F1 leftover-admin theater (CS + MB)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-017 |
| **Title** | F1 `diamondCut` call uses invalid ABI; cannot fail if Cut is live |
| **Severity** | Medium |
| **Class** | **THEATER** |
| **Confidence** | confirmed |
| **Catalog IDs** | F1 |
| **Pattern IDs** | PAT-THEATER-FACET, PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control / proxies |
| **CROPS pillar** | S |
| **Incident theme** | none |
| **Products** | ComposedStableCommonDetf; MixedBufferMultiVaultStableDetf |
| **Blast radius** | tests (production statically clean — 6.24) |
| **Impact** | False confidence on L-SEC-11 |
| **Evidence** | CS P0 `test_F1_diamondCut_blocked` 132–137; MB P0 `test_F1_diamondCut_notCallableByAttacker` 316–323 — first arg is `bytes(0)`, not `FacetCut[]`. |
| **Recommended CODE** | none |
| **Recommended TEST** | Loupe `facetAddress(IDiamondCut.diamondCut.selector)==0`; valid empty `FacetCut[]` call |
| **Anti-theater** | Valid ABI; `owner()` FunctionNotFound **or** address(0) only |
| **Suggested WP-ID** | fold into Medium `WP-SEC-DETF-CS-F1-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Parallel with A0 |

### 6.18 [SEC-DETF-CS-018] — CS I1 is U=0 / dust law, not booked hold-set

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-018 |
| **Title** | ComposedStable I1 suite never books a hold-set token |
| **Severity** | Medium |
| **Class** | **THEATER** / TEST residual |
| **Confidence** | confirmed |
| **Catalog IDs** | I1, K1 |
| **Pattern IDs** | PAT-THEATER-PRE (adjacent) |
| **EVM-audit domain** | erc20 |
| **Products** | ComposedStableCommonDetf |
| **Blast radius** | tests (production hold-set is detfToken + stable/common BPT) |
| **Impact** | Suite can stay green if booked **detfToken** I1 regresses; DAI is never in `vaultTokens` so U is raw balance |
| **Evidence** | `Adversarial_ComposedStable_SecurePull.t.sol` NatSpec 13–17 + I1 38–60: “DAI not in hold-set”; `test_L_RSRV_DUST_bareDaiDonation_freeCreditsPretransfer` documents free credit. Contrast MB TrustFlag `_bookBufferResidual`. |
| **Recommended TEST** | `test_I1_bookedDetfToken_cannotFundPretransferBurn`; `test_I1_bookedStableBpt_cannotFundPretransfer`. |
| **Anti-theater** | End-sync first; `R == B`; no in-call transfer |
| **Suggested WP-ID** | Medium TEST fold-in; **do not** re-open `WP-I-DETF-CS-001` CODE |
| **Link TCA / prior** | TCA-DETF-CS-005 closed WP — **new residual**, not a second CODE WP |
| **Depends / parallel** | Parallel |

### 6.19 [SEC-DETF-CS-019] — J residual incompleteness

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-019 |
| **Title** | MB J2 skips Bonding/Info; CS/MB J3 is not full-API proxy smoke |
| **Severity** | Medium |
| **Class** | **TEST** |
| **Confidence** | confirmed |
| **Catalog IDs** | J2–J3 |
| **Pattern IDs** | PAT-J-CTRL |
| **EVM-audit domain** | proxies |
| **Products** | CS; MixedBuffer; RebasingDETFToken (`updateRedemptionRate` not in `facetFuncs`) |
| **Blast radius** | tests |
| **Impact** | Silent omit on Info/compoundAtomic or stub `exchangeOut` would not fail J2 on MB |
| **Evidence** | MB Surface 139–148 loops ExchangeIn only. CS J3 146–215 smokes views + one mint. Rebasing `updateRedemptionRate` exists on Target (`RebasingDETFTokenTarget.sol` 279) but is **absent** from Facet 28 sels (rate still recomputed in `_getCurrentRedemptionRate` — Low omit). |
| **Recommended TEST** | J2 Bonding+Info; J3 each money selector (views + expected revert). |
| **Anti-theater** | Never assert only on `new Facet()` for J2/J3 |
| **Suggested WP-ID** | fold into F1 TEST WP |
| **Link TCA / prior** | TCA-DETF-CS-007 (closed WP-J) — residual TEST only |
| **Depends / parallel** | Parallel |

### 6.20 [SEC-DETF-CS-020] — Rebasing `burnShares` pretransfer still burns `address(this)`

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-020 |
| **Title** | `burnShares(..., pretransferred=true)` burns diamond inventory without inbound delta |
| **Severity** | Medium |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1 |
| **Pattern IDs** | PAT-I-ABS (gated) |
| **EVM-audit domain** | erc20 |
| **Products** | RebasingDETFToken |
| **Blast radius** | CS claim companion (shared RebasingClaimToken is A-detf-commons blast) |
| **Attacker** | ADM (onlyOwner / DETF) |
| **Attack scenario** | Privileged caller burns `address(this)` shares without proving inbound claim tokens. External EXT is blocked (`NotOwner`). After gold ownership transfer, only DETF can do this — CS `redeemClaim` sets `pretransferred=true` when `msg.sender == claimToken` (internal path after claim-diamond pull). Wrong inventory attribution if DETF is confused / leftover owner. |
| **Preconditions** | onlyOwner or DETF |
| **Impact** | Mis-burn of escrowed claim inventory. Not unprivileged extract. |
| **Evidence** | `RebasingDETFTokenTarget.sol` 245–264. Coverage TCA-DETF-CS-002 noted this; pull/exact-out were fixed, **this branch remains**. |
| **Recommended CODE** | Measure inbound claim delta or always burn `owner` after transfer. |
| **Recommended TEST** | `test_I1_burnShares_pretransferred_noInbound_reverts` as DETF. |
| **Anti-theater** | Do not first transfer then burn (that is happy escrow). |
| **Suggested WP-ID** | Medium `WP-SEC-DETF-CS-BURN-001` |
| **Link TCA / prior** | TCA-DETF-CS-002 residual (do not re-open closed pull WP) |
| **Depends / parallel** | Parallel |

### 6.21 [SEC-DETF-CS-021] — CS companion ownership is a CFG sharp edge

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-021 |
| **Title** | CS DFPkg `postDeploy` does not take ownership of bond NFT / claim / share token |
| **Severity** | Medium |
| **Class** | **CODE** (deploy-path) / sharp-edges |
| **Confidence** | static-high |
| **Catalog IDs** | F, CROPS-S |
| **Pattern IDs** | PAT-SHARP-FLAG, PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | S |
| **Products** | ComposedStableCommonDetf + companions |
| **Blast radius** | every CS deploy (MB auto-owns companions in `postDeploy`) |
| **Impact** | If CFG skips IntegratedDeploy-style transfers: leftover owner on claim (`transferHeldToken` drain) and NFT (`createPosition`). If they skip, `bond`/`sell` also **break** (onlyOwner). Gold tests transfer NFT+claim, **not** `detfToken` (6.14). |
| **Evidence** | `ComposedStableCommonDetfDFPkg.postDeploy` 266–268 returns true. Contrast `MixedBufferMultiVaultStableDetfDFPkg._deployBondNftVault` / `_deployRebasingClaimToken` owner=`detf_`. |
| **Recommended CODE** | Document required post-deploy ownership DAG in DFPkg NatSpec; optionally take ownership in a one-shot hook. Share-token strip is 6.14. |
| **Recommended TEST** | `test_F_companions_ownerIsDetf` on IntegratedDeploy. |
| **Anti-theater** | Read `owner()` on NFT + claim + detfToken after setUp |
| **Suggested WP-ID** | fold into `WP-SEC-DETF-CS-TOKEN-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Serial with TOKEN |

### 6.22 [SEC-DETF-CS-022] — L-RSRV-DUST unbooked pretransfer

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-022 |
| **Title** | Unbooked surplus funds `pretransferred=true` by product law |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** |
| **Confidence** | confirmed (law + tests) |
| **Catalog IDs** | I, K |
| **Pattern IDs** | PAT-K-DONATE, PAT-I-ABS (mitigated to unbooked-only) |
| **EVM-audit domain** | erc20 |
| **Products** | CS; MixedBuffer |
| **Blast radius** | all reserve-delta vaults |
| **Impact** | Anyone may snipe **not-yet-synced** donations. After honest money-route sync, booked residual cannot free-credit (MB I1/I3). CS pairToken (DAI) is **never booked** (not in hold-set) — perpetual dust window on leftover DAI. |
| **Evidence** | L-RSRV-DUST / L-RSRV-BOOTSTRAP / L-RSRV-CALLER; CS SecurePull dust control; MB TrustFlag NatSpec. |
| **Invariants required for acceptance** | Victim pull-path balances unchanged (A1); no free **booked** principal (I1); residual after fail = 0 (H3); unbooked window is intentional recovery. |
| **Recommended TEST** | already in I/K suite |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | L-RSRV-* PRD |
| **Depends / parallel** | n/a |

### 6.23 [SEC-DETF-CS-023] — Open-threshold seigniorage

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-023 |
| **Title** | Skew mint/burn under Open thresholds is intentional seigniorage |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** |
| **Confidence** | confirmed |
| **Catalog IDs** | B1, L3 |
| **Pattern IDs** | none |
| **EVM-audit domain** | defi-amm |
| **Products** | CS (Open mode); MixedBuffer (Open mode) |
| **Blast radius** | Open-mode instances |
| **Impact** | Bounded extract when both gates open |
| **Evidence** | MB `test_B1_*`; CS ThresholdMode Open deploy helper. Agent law: Open gates always pass. |
| **Invariants** | Victim token balances unchanged by attacker path; no free reserve principal without claim/NFT; residual inventory clean; Policy cannot mint-and-burn same regime. |
| **Recommended TEST** | existing MB; CS B1 still thin (coverage leftover) |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | none |
| **Depends / parallel** | n/a |

### 6.24 [SEC-DETF-CS-024] — L-SEC-11 leftover admin on DETF diamonds (clean bill)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-024 |
| **Title** | Live DETF diamonds have no DiamondCut / Ownable facet |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** (intentional unowned; not a leftover-admin High on the diamond) |
| **Confidence** | static-high |
| **Catalog IDs** | F1 |
| **Pattern IDs** | PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | S |
| **Products** | ComposedStableCommonDetf; MixedBufferMultiVaultStableDetf |
| **Blast radius** | instance |
| **Impact** | None on the diamond — cannot upgrade / pause instance. Share-token leftover is **6.14**, not this bill. |
| **Evidence** | CS DFPkg `facetCuts` 154–186: MultiAsset Basic/Standard, Bonding, ExchangeIn, ExchangeOutQuery, Pricing. MB DFPkg 246–266: ERC20/5267/2612 + MultiAsset + ExchangeIn + Bonding + Info. No `onlyOwner` / `diamondCut` in package sources. MB companions owned by DETF in `postDeploy`. |
| **Recommended TEST** | tighten via 6.17 |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | L-SEC-11 |
| **Depends / parallel** | n/a |

### 6.25 [SEC-DETF-CS-025] — Rebasing behavior I/H uses Mock DETF backend

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-CS-025 |
| **Title** | RebasingDETFTokenBehavior I-suite is valid for pull; redeem payout is Mock DETF |
| **Severity** | Medium |
| **Class** | **THEATER** (payout / H only) |
| **Confidence** | confirmed |
| **Catalog IDs** | H2, D |
| **Pattern IDs** | PAT-MOCK |
| **EVM-audit domain** | general |
| **Products** | RebasingDETFToken |
| **Blast radius** | tests |
| **Impact** | I1 revert happens **before** `redeemClaim` — pull proof still counts. Happy redeem / H2 payout against Mock is **not** SUT claim unwind. Production H2 lives on CS P0 IntegratedDeploy. |
| **Evidence** | `RebasingDETFTokenBehavior.t.sol` `MockRebasingDETF.redeemClaim` 118–129 mints mock WETH. Claim diamond itself is CREATE3 DFPkg. |
| **Recommended TEST** | Keep I1 on this file; do not cite Mock redeem as claim-unwind coverage. |
| **Anti-theater** | Production claim redeem = IntegratedDeploy / CS P0 |
| **Suggested WP-ID** | none (process) |
| **Link TCA / prior** | TCA-DETF-CS-012 PAT-MOCK |
| **Depends / parallel** | n/a |

---

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|----------------------------|-----|
| CS/MB `test_F1_diamondCut_*` | First arg is `bytes(0)`, not `FacetCut[]` — always fails decode | Valid empty cuts + loupe `facetAddress(cutSel)==0` |
| CS `Adversarial_ComposedStable_SecurePull` I1 on DAI | DAI not in hold-set; U is raw balance; booked detfToken/BPT never tested | Book hold-set token then I1 (`SEC-DETF-CS-018`) |
| CS ExchangeIn/Bonding/Burn/Out **Mock** harness | `MockStandardExchange` — not production SUT | Score only IntegratedDeploy + adversarial |
| `RebasingDETFTokenBehavior` redeem / H | Mock DETF mints WETH | I1 pull OK; unwind = CS P0 |
| MB `…_IFacet_Test` length floors | Declaration only | Keep as metadata; J is Surface |
| Implicit “A1 covers I/K” | A1 never sets `pretransferred=true` | I suite exists — do not regress |
| Bare `expectRevert` on CS P0 D2/D3/F2/H2/H3 | Wrong selector still passes | Exact selectors (Medium TEST; no coverage WP scheduled) |
| CS J3 “proxy smoke” | Does not call redeem/close/exchangeOut | `SEC-DETF-CS-019` |
| MB J2 | ExchangeIn facet only | Loop Bonding + Info |
| Implicit “K1 = donations never credit” | Bare donation **does** free-credit until sync / forever for CS DAI | Cite L-RSRV-DUST |

**Not theater:** MB TrustFlag I1 (no in-call transfer, booked inventory); MB C1–C3 exact `IsLocked`; MB E5 exact selectors; CS IntegratedDeploy mint/bond/claim; CS/MB Surface J on **proxy**; GE G1 outer/inner; production registry deploy.

**PAT-THEATER-PRE:** not present on MB I suite. CS I1 is U=0 (not happy transfer) but **not** booked-hold-set I1.

**PAT-MOCK:** CS unit ExchangeIn/Bonding/Out; Rebasing Behavior DETF backend.

---

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| TCA-DETF-CS-001 · WP-I-DETF-CS-001 | Yes — CS `_secureTokenTransfer` | **OWNED_ELSEWHERE** — CODE re-verified **fixed**. No `sec_fix_*`. |
| TCA-DETF-CS-002 · WP-I-DETF-CS-001 | Yes — Rebasing pull/exact-out | **OWNED_ELSEWHERE** — pull/exact-out **fixed**. Residual burnShares = new Medium `SEC-DETF-CS-020`. |
| TCA-DETF-CS-003/004 · WP-I-DETF-MB-001 | Yes — MB `_pullToken` + burn | **OWNED_ELSEWHERE** — CODE **fixed**. |
| TCA-DETF-CS-005 · WP-I-DETF-CS-002 | Yes — I tests | **OWNED_ELSEWHERE**; residual theater = `SEC-DETF-CS-018` (do not re-edit pull helper) |
| TCA-DETF-CS-006/008/009/011 · WP-ADV-DETF-MB-001 | Yes — MB adversarial + I | **OWNED_ELSEWHERE** |
| TCA-DETF-CS-007 · WP-J-DETF-CS-MB-001 | Yes — J suite | **OWNED_ELSEWHERE**; residual = `SEC-DETF-CS-019` |
| TCA-DETF-CS-010 · WP-G-E-DETF-CS-001 | Yes — G/E | **OWNED_ELSEWHERE** |
| WP-I-CLONE-001 | Yes — clone pull alignment | **OWNED_ELSEWHERE** — CS/MB bodies match |
| WP-I-CLAIM-001 | Shared RebasingClaimToken | **Out of area** (A-detf-commons); MB uses that package |
| TCA-DETF-CS-012 PAT-MOCK | Yes | Process leftover; `SEC-DETF-CS-025` |
| TCA-DETF-CS-013 bare revert | Area stub `WP-N-DETF-CS-001` **not** in global STAGE3 backlog | Medium TEST this program may own (cluster; not High) |
| TCA-DETF-CS-014 C deferred | Coverage TEST | **CODE confirm** = `SEC-DETF-CS-013` (new `sec_fix_*`, not `gap_cover_*`) |
| TCA-DETF-CS-015 L1/L3 | Wave 3 TEST | **DEFER** / coverage if scheduled later |
| TCA-DETF-CS-016 preview≡exec | TEST | CODE half for claim preview = `SEC-DETF-CS-016` |
| WP-I-COMMON-001 | Commons `_secureTokenTransfer` | **Out of area** (blast only) |

**Stale coverage claim:** 2026-08-09 “I = G / `_secureTokenTransfer` returns amount_ / MB no adversarial / CS G nested G” is **false** at `1e0d7c48`.

---

## 9. Work package stubs

### WP-SEC-DETF-CS-LOCK-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-CS-LOCK-001` |
| **Title** | Lock ComposedStable `exchangeIn` and `bond` |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | ComposedStableCommonDetf |
| **Finding IDs** | SEC-DETF-CS-013 |
| **Problem** | Mint/burn (`exchangeIn`) and `bond` are not `nonReentrant`. Hostile route token can reenter money paths against in-flight unbooked `U`. Gold DETF / MixedBuffer already lock. |
| **Production files (touch set)** | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeIn.sol`; `…/ComposedStableCommonDetfBondingFacet.sol` |
| **Test files (touch set)** | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/adversarial/` (new C file or extend P0) |
| **Out of scope files** | `_secureTokenTransfer`; MixedBuffer; RebasingDETFToken; commons pull |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-DETF-CS-TOKEN-001`, `WP-SEC-DETF-CS-A0-001` |
| **Conflicts with coverage-audit WP** | none (TCA-DETF-CS-014 was TEST-only; no closed CODE WP on these functions) |
| **Suggested worktree** | `sec_fix_detf-cs-lock` · branch `sec_fix/detf-cs-lock` |
| **Implementation notes** | Crane `ReentrancyLockModifiers` / `IsLocked`; gold MB C1–C3; no `via_ir`; DETF role names; hostile token as **route `baseToken`** via production PkgArgs |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/adversarial/**' --match-test 'test_C'` green; exact `IsLocked` |
| **Anti-theater checks** | No `vm.mockCall` on SUT; nested call during `transferFrom`; outer transfer completes; attacker product balance does not increase from reentry |
| **Proof-first?** | **yes** (High CODE was RUNTIME_UNPROVEN — add failing C test before/with the lock) |
| **Estimate** | M |

### WP-SEC-DETF-CS-TOKEN-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-CS-TOKEN-001` |
| **Title** | Make family `detfToken` unprivileged after DETF is the only minter |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | ComposedStableCommonDetf (share token + IntegratedDeploy) |
| **Finding IDs** | SEC-DETF-CS-014, SEC-DETF-CS-021 |
| **Problem** | Gold path leaves deployer as Ownable on the mintable family share. After the DETF diamond is unowned, that key can still inflate `detfToken`. Companions are transferred only in tests, not DFPkg. |
| **Production files (touch set)** | Deploy helpers / NatSpec on `ComposedStableCommonDetfDFPkg.sol`; possibly a one-shot post-deploy hook. **Do not** invent a new facet with `new`. If CODE is “transfer ownership to DETF + no mint wrapper,” touch the documented deploy path used by IntegratedDeploy and any production script under allowlist. |
| **Test files (touch set)** | `ComposedStableCommonDetf_IntegratedDeploy.t.sol`; new `adversarial/Adversarial_Access.t.sol` |
| **Out of scope files** | MixedBuffer (diamond is share); `_secureTokenTransfer`; A-manager-fee-registry |
| **Depends on** | `NEEDS_OWNER` if product wants a managed share token (then document ACCEPTED_RISK + invariants instead of strip) |
| **Parallelizable with** | LOCK, A0 |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-cs-token` · branch `sec_fix/detf-cs-token` |
| **Implementation notes** | After `setOperator(DETF,true)`, transfer or renounce. Companions already have transfer helpers — extend to `detfToken`. L-SEC-11 is about the diamond; this WP is the share. |
| **Acceptance** | `forge test --match-path '…/stable/common/**' --match-test 'test_F_detfToken'` ; deployer `mint` reverts; `owner()` is DETF or 0 |
| **Anti-theater checks** | Call the **share token**, not the DETF diamond `owner()` |
| **Proof-first?** | no (deploy-path static is the proof; test is the close) |
| **Estimate** | M |

### WP-SEC-DETF-CS-A0-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-CS-A0-001` |
| **Title** | Add catalog A0 residual-inventory tests for CS + MixedBuffer |
| **Severity** | High |
| **Class** | TEST |
| **Products** | ComposedStableCommonDetf; MixedBufferMultiVaultStableDetf |
| **Finding IDs** | SEC-DETF-CS-015 |
| **Problem** | P0 A0 has no `test_A0_*`. First-minter/bonder drain of pre-seeded inventory is unproven. Production looks gated (inert + pull-false bootstrap) but ship-gate requires the test. |
| **Production files (touch set)** | none unless test fails |
| **Test files (touch set)** | CS `adversarial/` (Donation or new EmptyVault); MB `adversarial/Adversarial_MixedBuffer_P0.t.sol` |
| **Out of scope files** | `_pullToken` / `_secureTokenTransfer` (owned); peer DETFs |
| **Depends on** | none |
| **Parallelizable with** | LOCK, TOKEN |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-cs-a0` · branch `sec_fix/detf-cs-a0` |
| **Implementation notes** | Gold IntegratedDeploy / MB TestBase; donate buffer/pairToken/BPT before live; DETF role names; L-RSRV-DUST ≠ A0 |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/{stable,mixedBuffer}/**/adversarial/**' --match-test 'test_A0_'` green |
| **Anti-theater checks** | Donate before first bond/bootstrap; proxy calls; no mock SE; attacker cannot drain **others’** seed after first honest sync |
| **Proof-first?** | no (TEST; if it fails, escalate to CODE + proof) |
| **Estimate** | S–M |

Medium CODE/TEST leftovers (`SEC-DETF-CS-016`…`020`) do **not** get Wave-0 `sec_fix_*` stubs here; Stage 2 may cluster them after Highs.

---

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Note |
|------|-------|------|
| A4–A5, B2, C4–C5, D7, G2–G3, H1 | **DEFER** | MB P0 NatSpec P2 |
| E6 surplus-refund | **N/A** on MB; **F** on CS (this-call cap) | No `balance − floor` pay-to-caller |
| M1–M3 arbitrary call | **N/A** | No helper calldata surface |
| O1–O3 / I5 | **N/A** | No product Permit2 witness; ERC-2612 is share permit |
| I4 FoT | **DEFER** | SE shares / detfToken / buffer not FoT product |
| CS-as-outer nested DETF share legs | **N/A** | Product law / GE NatSpec |
| L-RSRV-DUST unbooked sniping | **ACCEPTED_RISK** | `SEC-DETF-CS-022` + invariants |
| Open seigniorage | **ACCEPTED_RISK** | `SEC-DETF-CS-023` |
| Unowned DETF diamond / no Cut | **ACCEPTED_RISK** | `SEC-DETF-CS-024` (clean) |
| Managed family `detfToken` | **NEEDS_OWNER** | If not stripped (`SEC-DETF-CS-014`), must publish key + no-extra-minter invariants |
| Shared RebasingClaimToken | **reference** | A-detf-commons / `WP-I-CLAIM-001` |
| Fee oracle authority | **OWNED_ELSEWHERE** | A-manager-fee-registry |
| L1/L3 fuzz handlers | **DEFER** | TCA-DETF-CS-015 Wave 3 |
| Runtime forge this session | **not run** | Orchestrator owns; no Critical CODE to prove |
| `via_ir` | **forbidden** | not recommended |

---

## 11. Commands run

```bash
# Inventory
ls contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/
ls contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/
ls test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/
ls test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/

# Trust-flag / surface / catalog / leftover admin
rg -n 'function _secureTokenTransfer|function _pullToken|pretransferred|TransferDeltaInsufficient|diamondCut|onlyOwner|nonReentrant|facetFuncs|test_I[123]_|test_J[123]_|test_A0_|test_K1_|test_E6_|test_F5_|test_G1_' \
  contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common \
  contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer

rg -n 'WP-I-DETF-CS-001|WP-I-DETF-MB-001|WP-I-DETF-CS-002|WP-ADV-DETF-MB-001|WP-J-DETF-CS-MB-001|WP-G-E-DETF-CS-001|WP-I-CLONE-001' \
  docs/testing/coverage-audit

# Reads (normative)
# SECURITY_AUDIT_PRD §2/2.4/3.8/5–8/19
# 00_SCOPE_PARTITION.md
# crane-adversarial-testing + indexedex-adversarial-testing + indexedex-testing
# ethskills-security + defi-incident-patterns
# A-detf-multi-vault.md (style) + A-commons-pull.md §2.2.A
# T-detf-composed-stable.md + WORK_PACKAGE_BACKLOG + STAGE3_PROGRESS
# Production: CS Common/ExchangeIn/Out/Bonding/DFPkg/Repo; Rebasing Target/Facet/DFPkg;
#   BondNFTVault DFPkg; MB Common/ExchangeIn/Out/Bonding/DFPkg/Repo
# Tests: SecurePull, Surface, P0, GE, TrustFlag, MB P0, IntegratedDeploy, Rebasing Behavior

# Forge (orchestrator-owned; NOT executed)
# forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/adversarial/**' -vv
# forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/adversarial/**' -vv
```

**Not run:** `forge` (hard rule 5 / forge patience). Critical CODE count = 0 → no L-SEC-3 runtime proof required this area.

---

## Return status (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Critical** | **0** |
| **High** | **3** (`SEC-DETF-CS-013` CODE lock; `SEC-DETF-CS-014` CODE leftover `detfToken` minter; `SEC-DETF-CS-015` TEST A0) |
| **OWNED_ELSEWHERE** | **12** (`SEC-DETF-CS-001`…`012`) |
| **Top WP-IDs** | `WP-SEC-DETF-CS-LOCK-001` · `WP-SEC-DETF-CS-TOKEN-001` · `WP-SEC-DETF-CS-A0-001` |
| **Focus note** | Multi-leg residual: **P→F** (GE + MB Nested/NLegs). Claim: **P→F** on CS P0 + MB P0. G nested: **F** MB + CS-as-nested; CS-as-outer N/A. I/J: CODE fixed + suites exist (CS I1 residual theater; MB J2 incomplete). PAT-I-ABS: **closed** on CS/MB/Rebasing pull. Leftover admin on DETF diamonds: **clean**. |
