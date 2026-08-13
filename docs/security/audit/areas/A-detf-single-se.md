# Security Audit — A-detf-single-se

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · MODE=full · A-detf-single-se |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**`. Shared DETF commons / claim / bond NFT / Uni V4 extra families as **reference only**. |
| Test paths | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**` (incl. `adversarial/`, `fuzz/`, `invariant/`); `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**` (incl. `adversarial/`); fork `test/foundry/fork/**/uniswap/v4/standardExchange/constantProduct/single/**` |
| Skills cited | `SECURITY_AUDIT_PRD` §2, §2.4, §3.8, §5–8, §19; `crane-adversarial-testing` + `references/implementation-test-dod.md`; `indexedex-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `defi-incident-patterns` (theme→catalog); `docs/agent/INDEXEDEX_AGENT_LAW.md` DETF; L-CLAIM-3 / L-GAPS-9 / L-RSRV-*; `docs/testing/coverage-audit/areas/T-detf-single-se.md`; `A-commons-pull` §2.2.A; `A-detf-multi-vault` gold |
| Residual-risk scores | SingleStandardExchangeDETF (Balancer) → **3**; UniswapV4SingleStandardExchangeDETF (CP) → **3** |
| Forge | **Not run** (orchestrator owns runtime; L-SEC-3). Static re-verify only. |

---

## 1. Executive summary

- **Residual-risk:** Balancer Single SE **3** · Uni V4 CP Single SE **3**. No confirmed Critical/High **CODE** extract at this SHA. Both package-local `_pullToken` bodies are reserve-delta (`U = B − R`) + `TransferDeltaInsufficient`. Burn pulls via the same helper. Catalog I1–I3 and J1–J3 suites exist on **production proxies**. Leftover High is **TEST** (missing `test_A0_*` on both products).
- **Critical / High counts:** **Critical 0** · **High 1** (TEST only: `SEC-DETF-SSE-010` missing A0). **No High CODE. No leftover `diamondCut` / owner on live instances (L-SEC-11 statically clean).**
- **Top recommended WPs (this program):**
  1. `WP-SEC-DETF-SSE-A0-001` — add catalog `test_A0_*` on both production proxies (High TEST).
  2. `WP-SEC-DETF-SSE-F1-001` — tighten F1 leftover-admin proof (loupe `diamondCut` == 0; valid empty `FacetCut[]`) (Medium THEATER/TEST).
  3. `WP-SEC-DETF-SSE-J3-001` — J3 full-API proxy smoke leftover (`redeemClaim` / `closeBondMature` / `claimRewards`) (Medium TEST).
  4. `WP-SEC-DETF-SSE-CP-AH-001` — Uni V4 CP A–H P0 catalog port (A1/A3/D2/D3/E5/H2/F1 named) (Medium TEST).
  5. `WP-SEC-DETF-SSE-N2-001` — claim/close preview≡execute on Balancer (Medium TEST; CODE already quotes settlement via `_previewBptUnwind`).
- **OWNED_ELSEWHERE count:** **8** (`SEC-DETF-SSE-001`…`008` → `TCA-DETF-SSE-001`…`009` + `WP-I-DETF-SSE-001/002`, `WP-J-DETF-SSE-001`, `WP-I-DETF-SSE-CP-001`, `WP-J-DETF-SSE-CP-001`, `WP-I-DETF-SSE-UV4-001`, `WP-I-CLONE-001`). **Do not** schedule competing `sec_fix_*` on those touch-sets.
- **Re-verify vs coverage-audit (2026-08-09):** Historical PAT-I-ABS (`if (pretransferred_) return amount_`) is **gone**. Current bodies match A-commons-pull §2.2.A and L-CLAIM-3. I/J suites that TCA called **G** now exist and pass the I bar (I1 does **not** transfer) and J bar (Target ⊆ facetFuncs ⊆ loupe ⊆ **proxy**). Legacy listing-family `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/` is **deleted** (PRD: do not reintroduce). Residual risk is **not** 5: A0 untested, Uni V4 CP A–H catalog still thin, F1 theater, J3 not full-API.

---

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|---------------|
| **SingleStandardExchangeDETF** (Balancer V3) | `SingleStandardExchangeDETDFPkg.sol`; Facet: ExchangeIn (32 sels: exchange/bond/info/query + atomic compound); Targets: ExchangeIn/Out/Query, Bonding, Info; Common+Repo | `TestBase_SingleStandardExchangeDETF.sol` (CREATE3 facets + `indexedexManager.deploy*DFPkg` / `deployVault`; Aerodrome SE leg) | **Gold.** Facets via `*_FactoryService`; DFPkg via manager registry; never `new` on user path. Crane factory **base** cuts are ERC165 + Loupe + ERC8109 + PostHook — **not** DiamondCut / Ownable. | **3** |
| **UniswapV4SingleStandardExchangeDETF** (CP single) | `UniswapV4SingleStandardExchangeDETDFPkg.sol`; Facet: combined (33 sels); Targets: ExchangeIn/Out, Bonding (info on same); Common+Repo | `TestBase_UniswapV4SingleStandardExchangeDETF.sol` (registry/CREATE3; hermetic Uni V4 CP buffer hook reserve) | **Gold.** Same registry path. Reserve is hook LP (`reserveHook`), not Balancer BPT. | **3** |
| **UniswapV4SingleStandardExchangeDETF** (legacy `…/uniswap/v4/standardExchange/single/`) | **Directory gone.** Family PRD: “Removed topology — listing pool `hooks=0`; **deleted**; do not reintroduce.” Remaining `…/hooks/…/standardExchange/single/` is a **buffer hook**, owned by `A-hooks-v4-se-buffer`. | n/a | **N/A — no product.** `WP-I-DETF-SSE-UV4-001` / `TCA-DETF-SSE-004` are stale. | **N/A** |

**Out of this area (do not invent):** Uni V4 **weighted / orbital / curve-quad** DETFs + `…/uniswap/v4/common/{nft,rebasing}` → `A-detf-univ4-extra`. Shared rebasing claim / bond NFT packages → `A-detf-commons`.

### 2.1 Production file inventory

#### Balancer Single SE

| Path | Role |
|------|------|
| `SingleStandardExchangeDETDFPkg.sol` | Registry-gated `processArgs`; 6 facetCuts; `postDeploy` weighted reserve + bond NFT + rebasing claim |
| `SingleStandardExchangeDETFExchangeInFacet.sol` | Combined IFacet + `facetFuncs` (32) |
| `SingleStandardExchangeDETFExchangeInTarget.sol` | `exchangeIn` mint / passthrough / routes burn |
| `SingleStandardExchangeDETFExchangeOutTarget.sol` | `_burnDetfExactIn` via `_pullToken` (no public `exchangeOut`) |
| `SingleStandardExchangeDETFExchangeInQueryTarget.sol` | `previewExchangeIn` |
| `SingleStandardExchangeDETFBondingTarget.sol` | `bond` / sell / buyClaim / close / redeemClaim / claimLiquidity |
| `SingleStandardExchangeDETFInfoTarget.sol` | views + `compoundProtocolRewards` |
| `SingleStandardExchangeDETFCommon.sol` | pricing, thresholds, join/exit, expansion, compound, **`_pullToken`**, hold-set sync |
| `SingleStandardExchangeDETFRepo.sol` | diamond slot `keccak256("vault.detf.standardExchange.single.single-standard-exchange-detf.repo")` |
| `*_FactoryService.sol` | CREATE3 helpers |
| `TestBase_SingleStandardExchangeDETF.sol` | gold TestBase |

#### Uni V4 CP Single SE

| Path | Role |
|------|------|
| `UniswapV4SingleStandardExchangeDETDFPkg.sol` | Registry-gated; 6 facetCuts; first-bond creation rate in `PkgArgs` |
| `UniswapV4SingleStandardExchangeDETFFacet.sol` | Combined IFacet + `facetFuncs` (33) |
| `UniswapV4SingleStandardExchangeDETFExchangeInTarget.sol` | mint / burn route / SE passthrough |
| `UniswapV4SingleStandardExchangeDETFExchangeOutTarget.sol` | `_burnDetfExactIn` pair-only via `_pullToken`; burn vs **protocol LP** |
| `UniswapV4SingleStandardExchangeDETFBondingTarget.sol` | bond / sell→claim / redeemClaim / claimLiquidity / claimRewards / compound |
| `UniswapV4SingleStandardExchangeDETFCommon.sol` | pricing, **`_pullToken`**, `_settleToPair`, nested push, protocol/user LP partition |
| `UniswapV4SingleStandardExchangeDETFRepo.sol` | ERC-7201-style slot `keccak256(abi.encode(uint256(keccak256("vault.detf.uniswap.v4.se.cp.single.repo")) - 1))` |
| `interfaces/IUniswapV4SingleStandardExchangeDETF.sol` | Product interface + `PkgArgs` |
| `*_FactoryService.sol` | CREATE3 helpers |
| `TestBase_UniswapV4SingleStandardExchangeDETF.sol` | gold TestBase |
| `*_PRD.md` / `*_IMPLEMENTATION_AND_TEST_PLAN.md` | Family law (listing-family deleted) |

### 2.2 Trust-flag / money entrypoints

| Product | Entrypoint | Flag | Credit path (this SHA) |
|---------|------------|------|------------------------|
| Balancer | `exchangeIn` mint | `pretransferred_` | `_pullToken` → join vaultShare → mint `detfToken` |
| Balancer | `exchangeIn` burn | `pretransferred_` | `_pullToken(detfToken)` → burn → proportional exit |
| Balancer | `bond` | `pretransferred_` | `_pullToken` then first-bond bootstrap / live join |
| Balancer | `buyClaim` | `pretransferred_` | `_pullToken(detfToken)` then single-sided join (uses **claimed** amount for join; detfToken is this diamond ERC-20) |
| Balancer | `redeemClaim` / `closeBondMature` | n/a | burn claim / sell mature NFT; no pretransfer flag |
| Balancer | `compoundProtocolRewards` | n/a | permissionless; credits protocol NFT BPT, not caller |
| Balancer | `claimLiquidity` | n/a | gated `this` / bondNftVault / rebasingClaimToken |
| Balancer | `exchangeOut` | n/a | **no public selector** (burn is `exchangeIn` tokenIn=`detfToken`) |
| Uni V4 CP | `exchangeIn` mint | `pretransferred_` | `_settleToPair` → `_pullToken` / nested SE push |
| Uni V4 CP | `exchangeIn` burn | `pretransferred_` | `_pullToken(detfToken)` → burn vs **protocolLp** only |
| Uni V4 CP | `bond` | `pretransferred_` | `_settleToPair` then first/live bond join |
| Uni V4 CP | `redeemClaim` | n/a | `burnShares` then withdraw protocol LP |
| Uni V4 CP | `sellPositionToDetfNft` | n/a | maturity in `DETFBondLifecycleLib._sellPositionToDetfNft` |
| Uni V4 CP | `claimLiquidity` / `compoundProtocolRewards` | n/a | auth-gated / protocol NFT only |
| Both | `initializeReserve` | n/a | **No such API.** First `bond` is the go-live gate. |

### 2.3 Test roots

| Root | Role |
|------|------|
| `SingleStandardExchangeDETF_*.t.sol` | H/N: deploy, mint, burn, bonding, guards, disable, expansion, compound, product-law M1–M15, nested push, composed-stable matrix |
| Balancer `adversarial/` | A–H P0 in `Adversarial_SingleSE_P0.t.sol` + **I1–I3** + **J1–J3** |
| Balancer `fuzz/` / `invariant/` | L1 conservation; L3 handler mint/burn/donate |
| Uni V4 CP `*_Deploy/FirstBond/MintBurn/Bond/Claim/Expansion/PriceMovement/NestedPush.t.sol` | H/N/P happy + nested I |
| Uni V4 CP `adversarial/` | **I1–I3** + **J1–J3** only |
| Uni V4 CP `*_Adversarial.t.sol` | C reentrancy + LP partition (not A–K catalog) |
| Fork `…/constantProduct/single/` | FK1 inert → first bond → mint |

---

## 3. Threat models

### 3.1 SingleStandardExchangeDETF (Balancer V3)

**Product:** live, unowned diamond. Inert until first `bond`. No `initializeReserve`.

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn` mint | vaultShare / SE token → detfToken | `pretransferred` | fee oracle split; Policy/Open gates | free mint from booked inventory (**blocked** at SHA); unbooked donation sniping (**L-RSRV-DUST**, accepted) |
| EXT | `exchangeIn` burn | detfToken → vaultShare / SE token | `pretransferred` | burn gate | free extract of diamond detfToken inventory (**blocked** once booked) |
| EXT | `bond` (incl. first) | vaultShare / allowlisted → bond NFT + reserveBpt | `pretransferred` | lock terms from fee oracle | free bond from unbooked vaultShare (dust); first-bond consume of pre-seeded inventory (**A0 untested**) |
| EXT | `sellPositionToDetfNft` / `closeBondMature` | bond NFT → claim / settlement | maturity | none | pre-maturity exit (**blocked** `_requireMature` + NFT vault) |
| EXT | `redeemClaim` | rebasingClaimToken → rateAsset / vaultShare | none | none | D2 free BPT without claim (**blocked**); H2 burn-without-payout (**full-tx revert**) |
| EXT | `buyClaim` | detfToken → claim | `pretransferred` | none | join uses claimed not measured actual (FoT N/A on detfToken) |
| EXT | `compoundProtocolRewards` | protocol pending detfToken → reserveBpt on protocol NFT | none | none | F5 skim to caller (**no**; credits protocol NFT only; atomic is `NotSelf`) |
| EXT | `claimLiquidity` | reserve BPT unwind | none | none | unprivileged call (**`NotAuthorized`** unless self/NFT/claim) |
| EXT | `diamondCut` / `owner()` | whole diamond | n/a | n/a | leftover upgrade (**statically absent**; F1 test is weak ABI) |
| CAP | skew underlying SE + mint/burn | vaultShare / detfToken | open vs Policy | thresholds | unbounded seigniorage (**Open = ACCEPTED_RISK** with B1 invariants; Policy deadband **B3**) |
| HOS | `PkgArgs` hostile vaultShare | same | pull | none | reenter mint/bond/redeem (**C1–C3 `IsLocked`**) |
| INT | push + `pretransferred=true` | vaultShare / detfToken | L-RSRV-CALLER any caller | none | claimed > U reverts `TransferDeltaInsufficient`; claimed ≤ U credits |
| ADM | fee oracle / registry `setVaultAddressDisabled` | fee slice; **all `_requireActive` money paths** | n/a | **manager** (out of area) | disable bricks mint/burn/bond/buyClaim/close/redeem (**sell still works**). Blast → `A-manager-fee-registry` |
| CFG | hostile share / zero minOut / Open mode | all | PkgArgs | deploy-time only | misconfigured Open seigniorage; hostile share accepted if passed at deploy |

### 3.2 UniswapV4SingleStandardExchangeDETF (constantProduct / single)

**Product:** live, unowned diamond. First permissionless `bond` at `creationPairPerDetfWad`. User bond LP physically on **bond NFT**; protocol LP on **rebasing claim** package.

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn` mint | pairToken / vaultShare / SE token → detfToken | `pretransferred` | fee oracle; Policy/Open | free mint from booked pair (**blocked**); unbooked U sniping (accepted dust) |
| EXT | `exchangeIn` burn | detfToken → **pairToken only** | `pretransferred` | burn gate | free extract of booked detfToken (**blocked**); burn of **user-bonded LP** (**blocked** — `EmptyProtocolLp` until sell/compound creates protocol LP) |
| EXT | `bond` (first / live) | pairToken → hook LP on bond NFT | `pretransferred` | creation rate; lock terms | A0 first-bond drain of pre-seeded pair (**untested**); first-bond MEV at creation rate (PRD non-goal / ACCEPTED_RISK) |
| EXT | `sellPositionToDetfNft` | bond NFT → rebasing claim + LP migrate NFT→claim | maturity via lifecycle lib | none | pre-maturity sell (**blocked** `DETFBondLifecycleLib.BondNotMature` + NFT vault) |
| EXT | `redeemClaim` | rebasingClaimToken → pair / vaultShare / SE token | none | none | D2 free protocol LP without claim (**blocked** `burnShares`); H2 minOut fail (**full-tx revert**) |
| EXT | `claimRewards` | free detfToken harvest | holder-only | none | non-holder harvest (**`NotAuthorized`**) |
| EXT | `claimLiquidity` | hook LP → pair | none | none | unprivileged (**`NotAuthorized`** unless bond/claim/self) |
| EXT | `compoundProtocolRewards` | protocol pending detfToken → protocol LP | none | none | F5 skim to caller (**no**; protocol holder only; atomic `NotSelf`) |
| EXT | `diamondCut` / `owner()` | whole diamond | n/a | n/a | leftover upgrade (**statically absent**; **no** F1 test) |
| CAP | skew hook / SE + mint/burn | pairToken / detfToken | open vs Policy | thresholds | Open seigniorage ACCEPTED_RISK; Policy regimes tested via real trades |
| HOS | hostile pair as `PkgArgs.pairToken` | same | pull | none | reenter mint (**C `IsLocked`** — exists) |
| INT | push + `pretransferred=true` | pairToken / detfToken | any caller | none | same I1–I3 law as Balancer |
| ADM | fee oracle / registry disable | `_requireActive` paths | n/a | manager | same freeze as Balancer (`redeemClaim` uses `_requireActive`) |
| CFG | `creationPairPerDetfWad` / Open / hostile pair | all | PkgArgs | deploy-time | off-peg first bond (PRD intentional); hostile pair accepted if CFG deploys it |

---

## 4. Catalog matrix (A–O, E6, F5)

Legend: **F** found/covered · **P** partial · **G** gap · **N/A** · **VULN** production appears exploitable.

| ID | Product | F/P/G/N/A/VULN | Evidence |
|----|---------|----------------|----------|
| A1 | Balancer | **F** | `Adversarial_SingleSE_P0.test_A1_donateVaultShares_cannotMintFreeDetf` (pull path; idle not joined) |
| A1 | CP | **G** | No `test_A1_*`. Happy mint does not donate. → `SEC-DETF-SSE-013` |
| A2 | Balancer | **F** | `test_A2_donateDetfToDiamond_noTheft` |
| A2 | CP | **G** | No catalog A2 |
| A3 | Balancer | **F** | `test_A3_cannotDrainBptWithoutBondAuthority` |
| A3 | CP | **P** | Burn-after-first-bond-only reverts `EmptyProtocolLp` (`MintBurn`); not catalog-named A3 |
| A4–A5 | both | **N/A** | Deferred P2 |
| **A0** | both | **G** | **No `test_A0_*`.** Production: inert until first bond; pull-false first bond joins **pulled** amount only. Residual is **proof**, not confirmed drain. → `SEC-DETF-SSE-010` |
| B1 | Balancer | **P** | `test_B1_openThresholds_mintBurn_boundsSafety` (weaker than MultiVault skew bounds) |
| B1 | CP | **P** | `PriceMovement` policy regimes via real trades; no `test_B1_*` seigniorage bounds |
| B2 | both | **N/A** | Deferred P2 |
| B3 | Balancer | **F** | `test_B3_thresholdGates_coupleToSynthetic` + ThresholdMode hermetic |
| B3 | CP | **P** | `test_policy_blocks_mint_when_synthetic_below_threshold` |
| C1–C3 | Balancer | **F** | P0 C1–C3 + `Reentrancy.t.sol`; exact `IsLocked` |
| C | CP | **P** | `test_reentrancy_mint_hitsIsLocked` only (hostile pair + production DETF; SimpleYield SE is **non-SUT** double) |
| C4–C5 | both | **N/A** | Deferred P2 |
| D2 | Balancer | **F** | `test_D2_sellPosition_nonOwner_reverts` |
| D2 | CP | **G** | Happy sell exists; no catalog non-owner sell |
| D3 | Balancer | **F** | `test_D3_doubleSell_secondReverts` |
| D3 | CP | **G** | no double-sell catalog |
| D5 | Balancer | **F** | `test_D5_lockClamp_minRevert_maxOk` |
| D5 | CP | **P** | `test_lockTooShort_reverts` (bare revert) |
| D6 | Balancer | **F** | `test_D6_cannotRedeemMoreThanClaimPrincipal` |
| D6 | CP | **P** | Claim suite redeem matrix; no over-redeem catalog |
| E1 | Balancer | **F** | `test_E1_mintThenPartialBurn_conservation` |
| E1 | CP | **P** | MintBurn preview≡exec; no `test_E1_*` |
| E4 | Balancer | **F** | `test_E4_holderBalance_notDilutedByOthersMint` |
| E4 | CP | **G** | no catalog E4 |
| E5 | Balancer | **F** | `test_E5_zeroAmount_reverts`, `test_E5_expiredDeadline_reverts` (+ Guards) |
| E5 | CP | **P** | J3 ZeroAmount on mint/bond; no dedicated E5 deadline |
| **E6** | both | **N/A** | No `balance − floor` refund / reclaim / surplus-pay-to-caller. Nested SE push does not refund leftover to `msg.sender`. L-RSRV-ABSORB. |
| F1 | Balancer | **P** | `test_F1_diamondCut_notCallableByAttacker` exists but **diamondCut calldata is not a valid `FacetCut[]`** (theater). Static cuts have **no** DiamondCut/Ownable. → `SEC-DETF-SSE-011` |
| F1 | CP | **G** | No F1 test. Static cuts same (no DiamondCut). |
| F2 | Balancer | **F** | `test_F2_bondNftVault_createPosition_onlyOwner` |
| F2 | CP | **G** | no catalog F2 |
| F3 | Balancer | **N/A** | Claim mint/burn onlyOwner is claim-package (commons). Sell authority covered D2. |
| F3 | CP | **N/A** | same |
| F4 | Balancer | **F** | `test_F4_noSetWeights` |
| F4 | CP | **N/A** | No weights API (CP reserve) |
| **F5** | both | **F** | `compoundProtocolRewards` permissionless by law; credits **protocol NFT/LP**, not caller. `claimLiquidity` auth-gated. No migrate/resize/reclaim. |
| G1 | Balancer | **P** | ComposedStable matrix + nested push suite; not formal adversarial G1 |
| G1 | CP | **P** | NestedPush T_NEST_*; hook is reserve (not outer DETF) |
| H2 | Balancer | **F** | `test_H2_redeemClaim_minOutTooHigh_claimUnchanged` |
| H2 | CP | **G** | Claim redeem happy; no minOut atomicity catalog |
| H3 | Balancer | **F** | `test_H3_minOutTooHigh_leavesNoInventory` |
| H3 | CP | **P** | FirstBond dust revert; no residual catalog |
| **I1** | both | **F** | mint / burn / bond booked-inventory + **no transfer** → `TransferDeltaInsufficient(claimed, 0)` |
| **I2** | both | **F** | short same-tx push → `(claimed, shortDelta)` via helper |
| **I3** | both | **F** | residual after honest end-sync cannot fund second `true` |
| I4 | both | **N/A** | Legs are SE vaultShare / pair (not FoT product); detfToken is this diamond ERC-20 |
| I5 | both | **N/A** | No Permit2 / product EIP-712 money path (ERC-2612 is standard share permit only) |
| **J1** | both | **P** | Target/interface control list ⊆ `facetFuncs`; not a full Target-derived **equals** list (atomic compound extra is Facet-only — OK) |
| **J2** | both | **F** | Loupe `facetAddress(sel) != 0` for product controls on proxy |
| **J3** | both | **P** | Proxy views + ZeroAmount mint/bond + one mint/burn (CP) + compound + `claimLiquidity` NotAuthorized (Balancer). **Not** each money selector as success/exact-access (`redeemClaim`, `closeBondMature`, `claimRewards`). → `SEC-DETF-SSE-012` |
| J4 | both | **P** | DFPkg `facetCuts` bind `facetFuncs()`; no dedicated J4 length test |
| **K1** | both | **P** | I3 + A1 (Balancer) after honest sync. **No `test_K1_*`.** Bare donation **does** free-credit until sync (**L-RSRV-DUST**, accepted — not VULN) |
| L1 | Balancer | **P** | Fuzz conservation; no public skim. `_bptForDetfShares` uses raw diamond BPT (donation subsidizes burners — same class as MultiVault L1 P) |
| L1 | CP | **P** | Burn uses **protocolLp** only (better partition than raw diamond LP). No public skim. |
| L2 | both | **N/A** | FoT underlyings not a product claim |
| L3 | Balancer | **P** | Invariant handler mint/burn/donate; no bond/claim/pretransfer ops |
| L3 | CP | **G** | No invariant handler |
| M1–M3 | both | **N/A** | No user `target+calldata`; nested call is configured `underlyingVault`. ProductLaw `test_M1_*` are **maturity** IDs, not catalog M |
| N1 | both | **P** | No dedicated TOCTOU suite; C lock covers same-tx reentry; Balancer join/exit under outer `nonReentrant` |
| N2 | Balancer | **P** | mint/burn preview≡exec **F**; claim/close previews use `_previewBptUnwind` (settlement asset — **better than MultiVault gold**). **No** `test_N2_previewRedeemClaim_equalsExecute`. |
| N2 | CP | **P** | mint/burn preview≡exec **F**; **no** `previewRedeemClaim` / `closeBondMature` API (sell→redeem only) |
| O1–O3 | both | **N/A** | No product permit/signature money path; ERC-2612 on detfToken is standard share permit (commons / token specialist) |

**P0 DETF subset:** Balancer A1/A3/B3/C1–C3/D2/D3/D6/E1/E5/F2/H2/H3 = **F**; I1–I3 = **F**; J1–J3 = **P**; K1 = **P**; **A0 = G**. CP: I1–I3/J2 = **F**; A0/A1/D2/D3/H2/F1 = **G**; C/B3/N2 mint = **P**.

---

## 5. Domain notes

Walked locally (evm-audit domains as hunt lists; ship-gate remains Crane DoD):

| Domain | Notes |
|--------|--------|
| **general** | Routes closed-form; no public `exchangeOut` (burn is exact-in). CEI + `nonReentrant` on money paths. `try/catch` only on best-effort compound (product law) and `_tryInitDetfNft` (if NFT init fails, `detfNftId=0` — Low wiring risk, not extract). |
| **precision-math** | WAD / Balancer `FixedPoint`; `_bptForDetfShares` linear on diamond BPT. CP burn = `burnPrincipal * protocolLp / (supply + pending)` (debt-inclusive; does **not** realize expansion). Uni V4 `_toWad` / `_fromWadFloor` for non-18 pair decimals. |
| **erc20** | `BetterSafeERC20`; pull false is FoT-safe (returns delta). `buyClaim` join uses claimed amount after pull (detfToken not FoT). |
| **erc4626** | detfToken is diamond ERC-20, not 4626. Rebasing claim is 4626-like (commons; M4/M8). CP adversarial uses `SimpleYieldERC4626` only as **hostile SE double**, not DETF SUT. |
| **defi-amm** | Balancer: pricing = weighted reserve + rate providers; synthetic from owned BPT (diamond + bond NFT). CP: hook CP buffer DETF↔pair; first bond at creation rate. Spot skew = B1 / L3. |
| **proxies** | Crane MinimalDiamond + package cuts. Unique repo slots (plain keccak vs ERC-7201-style). No DiamondCut in factory base or DFPkg. PostHook removed after `postDeploy`. |
| **access-control** | Instance unowned. `claimLiquidity` allowlist. `compoundProtocolRewardsAtomic` `NotSelf`. Bond NFT / claim token onlyOwner for mint/burn (separate packages). |
| **oracles** | Thresholds deploy-time storage; fees via fee oracle (blast → manager). No spot-as-sole mint oracle (synthetic + deadband / creation rate). |
| **flashloans** | CAP skew covered by B1/B3; Open seigniorage accepted. First-bond creation-rate MEV is PRD non-goal. |
| **dos** | minOut / deadline / `EmptyProtocolLp` / `InvariantRatio` dust rejoin. N=max gas deferred P2. Registry disable is a **kill switch** (see §10). |
| **erc721** | Bond NFT maturity gates sell/close; rewards claimable while locked (M3). CP sell uses lifecycle lib + NFT vault double-check. |
| **CROPS** | Walkaway: users can mint/burn/bond/sell-mature/redeem without team **unless** registry disable is on. Disable bricks `_requireActive` paths (mint/burn/bond/buyClaim/close/redeem); **sell still works**. Fee oracle residual trust (other area). **L-SEC-11 leftover admin: statically absent.** |
| **sharp-edges** | `pretransferred` default is caller-supplied (L-RSRV-CALLER). PkgArgs zeros → Policy + 1.05/0.95 (Balancer). CP requires non-zero `creationPairPerDetfWad`. `minOut=0` common in tests (user footgun, not CODE). Hostile `vaultShares` / pair accepted if CFG deploys them. |
| **spec** | Sell→claim / close only after maturity — **code matches** (Balancer `_requireMature`; CP lifecycle lib + NFT). Compound public + lazy — matches. No `initializeReserve` (first bond is the gate — unlike MultiVault). Balancer claim/close previews already unwind to settlement (port **ahead** of MultiVault `SEC-DETF-MV-009`). |
| **incidents** | A0 empty-vault (untested); I trust-flag (fixed+tested); L1 skim (no public reclaim); E6 surplus-refund (no path); F5 structural (compound does not pay caller). Theme map: first-deposit drain → A0; donation → A/K; leftover admin → F/CROPS-S. |

---

## 6. Findings

### 6.1 [SEC-DETF-SSE-001] — PAT-I-ABS Balancer mint/bond (re-verified closed)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-001 |
| **Title** | Historical absolute / blind pretransfer credit on Balancer `_pullToken` |
| **Severity** | Info (was coverage Blocker) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high (CODE shape re-read at `1e0d7c48`; forge not run) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | trust-flag free mint |
| **Products** | SingleStandardExchangeDETF |
| **Blast radius** | this package (clone of commons / MultiVault pattern) |
| **Impact** | None remaining on booked inventory if reserve-delta + end-sync hold |
| **Evidence** | `SingleStandardExchangeDETFCommon.sol` 517–533: `U = B0 - R`; `amount_ > U` → `TransferDeltaInsufficient`; pull-false returns `balance − B0`. Mint/bond call `_pullToken`. A-commons-pull §2.2.A already listed this peer. Coverage: `TCA-DETF-SSE-001`, `WP-I-DETF-SSE-001` (STAGE3 closed `e2e6482`). |
| **Recommended TEST** | none new (owned) |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none — **do not** open `sec_fix_*` |
| **Link TCA / prior** | TCA-DETF-SSE-001, WP-I-DETF-SSE-001, WP-I-CLONE-001 |
| **Depends / parallel** | n/a |

### 6.2 [SEC-DETF-SSE-002] — PAT-I-ABS Balancer burn (re-verified closed)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-002 |
| **Title** | Historical burn pretransfer skipped pull / burned diamond inventory |
| **Severity** | Info (was coverage Blocker) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | trust-flag free extract |
| **Products** | SingleStandardExchangeDETF |
| **Blast radius** | this package |
| **Impact** | None remaining: burn calls `_pullToken` then burns `actualIn_` |
| **Evidence** | `SingleStandardExchangeDETFExchangeOutTarget.sol` 39–44. Tests: `test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf`. `TCA-DETF-SSE-002`, `WP-I-DETF-SSE-001`. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-SSE-002, WP-I-DETF-SSE-001 |
| **Depends / parallel** | n/a |

### 6.3 [SEC-DETF-SSE-003] — PAT-I-ABS Uni V4 CP (re-verified closed)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-003 |
| **Title** | Historical absolute / blind pretransfer on Uni V4 CP `_pullToken` / burn |
| **Severity** | Info (was coverage Blocker) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | trust-flag free mint |
| **Products** | UniswapV4SingleStandardExchangeDETF |
| **Blast radius** | this package |
| **Impact** | None remaining on booked inventory |
| **Evidence** | `UniswapV4SingleStandardExchangeDETFCommon.sol` 482–495 same `U = B − R` law. Burn: `ExchangeOutTarget.sol` 48–50 `_pullToken`. A-commons-pull §2.2.A lists this peer. `TCA-DETF-SSE-003`, `WP-I-DETF-SSE-CP-001` (STAGE3 `c20ef7e`). |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-SSE-003, WP-I-DETF-SSE-CP-001, WP-I-CLONE-001 |
| **Depends / parallel** | n/a |

### 6.4 [SEC-DETF-SSE-004] — Legacy Uni V4 listing DETF gone

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-004 |
| **Title** | Legacy `…/uniswap/v4/standardExchange/single/` DETF product no longer exists |
| **Severity** | Info (was coverage Blocker on a scaffold) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed (directory listing + family PRD) |
| **Catalog IDs** | I1 |
| **Pattern IDs** | PAT-I-ABS (historical) |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | none (deleted listing-family draft) |
| **Blast radius** | none — do not invent a product |
| **Impact** | `WP-I-DETF-SSE-UV4-001` / `TCA-DETF-SSE-004` are **stale**. STAGE3 marked the WP closed (`0f6f083`); production tree is gone. Hook path `contracts/hooks/uniswap/v4/standardExchange/single/` is **not** this product. |
| **Evidence** | `list_dir` of `…/uniswap/v4/standardExchange/` shows only `constantProduct/single`, `orbital`, `weighted`, `stable/quad/curve`. Family PRD line 16: “Removed topology … **deleted**; do not reintroduce.” |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none — do not schedule `sec_fix_*` for a deleted tree |
| **Link TCA / prior** | TCA-DETF-SSE-004, WP-I-DETF-SSE-UV4-001, TCA-DETF-SSE-013 |
| **Depends / parallel** | n/a |

### 6.5 [SEC-DETF-SSE-005] — Balancer I-suite ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-005 |
| **Title** | Catalog I1–I3 tests already filed (Balancer) |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed (files present; I bar met statically) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-THEATER-PRE (absent — I1 does **not** transfer) |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | SingleStandardExchangeDETF |
| **Blast radius** | tests only |
| **Impact** | none |
| **Evidence** | `adversarial/Adversarial_TrustFlag.t.sol`: I1 mint/burn/bond, I2 mint, I3 mint. Helper does **not** transfer on I1. Exact `TransferDeltaInsufficient(claimed, 0|short)`. `WP-I-DETF-SSE-002` / `TCA-DETF-SSE-005`. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-SSE-005, WP-I-DETF-SSE-002 |
| **Depends / parallel** | n/a |

### 6.6 [SEC-DETF-SSE-006] — Balancer J-suite ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-006 |
| **Title** | J1–J3 suite exists (partial completeness leftover in 6.12) |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-THEATER-FACET (historical; Surface now deploys proxy) |
| **EVM-audit domain** | proxies |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | SingleStandardExchangeDETF |
| **Blast radius** | tests |
| **Impact** | none for ownership; residual incompleteness = `SEC-DETF-SSE-012` |
| **Evidence** | `adversarial/Adversarial_Surface.t.sol`; controls from interfaces; J3 calls **proxy**. `WP-J-DETF-SSE-001` STAGE3 closed. Static `facetFuncs` includes bond/claim/compound (32 sels). |
| **Recommended TEST** | none (residual → 6.12) |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-SSE-006, WP-J-DETF-SSE-001 |
| **Depends / parallel** | n/a |

### 6.7 [SEC-DETF-SSE-007] — Uni V4 CP I-suite ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-007 |
| **Title** | Catalog I1–I3 tests already filed (Uni V4 CP) |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-THEATER-PRE (absent) |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | UniswapV4SingleStandardExchangeDETF |
| **Blast radius** | tests |
| **Impact** | none |
| **Evidence** | `…/constantProduct/single/adversarial/Adversarial_TrustFlag.t.sol` I1 mint/burn/bond, I2, I3. NestedPush also has T_LOCAL_I1 / T_NEST_3. `TCA-DETF-SSE-008` I portion, `WP-I-DETF-SSE-CP-001`. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-SSE-008, WP-I-DETF-SSE-CP-001 |
| **Depends / parallel** | n/a |

### 6.8 [SEC-DETF-SSE-008] — Uni V4 CP J-suite ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-008 |
| **Title** | J1–J3 suite exists (Uni V4 CP; leftover in 6.12) |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-THEATER-FACET (historical) |
| **EVM-audit domain** | proxies |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | UniswapV4SingleStandardExchangeDETF |
| **Blast radius** | tests |
| **Impact** | none for ownership |
| **Evidence** | `adversarial/Adversarial_Surface.t.sol`; J3 mint+burn on **proxy**. `TCA-DETF-SSE-009`, `WP-J-DETF-SSE-CP-001`. |
| **Recommended TEST** | none (residual → 6.12) |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-SSE-009, WP-J-DETF-SSE-CP-001 |
| **Depends / parallel** | n/a |

### 6.9 [SEC-DETF-SSE-009] — K1 CODE ownership (closed by pull)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-009 |
| **Title** | Historical K1 donation+pretransfer free credit (CODE half) |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | K1 |
| **Pattern IDs** | PAT-K-DONATE |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | donation inflation |
| **Products** | SingleStandardExchangeDETF (CP covered by same I3) |
| **Blast radius** | this family |
| **Impact** | Booked residual cannot fund pretransfer (I1/I3). Unbooked U until first sync remains **L-RSRV-DUST** (accepted). No named `test_K1_*` — residual TEST is Medium, not a new CODE WP. |
| **Evidence** | TCA-DETF-SSE-007; I3 after honest sync. Prefer merge was WP-I-DETF-SSE-002. |
| **Recommended TEST** | optional `test_K1_*` alias of I3 (do not fork a `sec_fix_*`) |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-SSE-007, WP-I-DETF-SSE-002 |
| **Depends / parallel** | n/a |

### 6.10 [SEC-DETF-SSE-010] — Missing A0 empty-inventory proof

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-010 |
| **Title** | Add catalog A0 proof that first live minter/bonder cannot drain pre-seeded inventory |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | static-high (no `test_A0_*`; production **appears** gated) |
| **Catalog IDs** | A0 |
| **Pattern IDs** | PAT-A0-EMPTY |
| **EVM-audit domain** | erc4626 |
| **CROPS pillar** | n/a |
| **Incident theme** | empty vault / first deposit drain |
| **Products** | SingleStandardExchangeDETF; UniswapV4SingleStandardExchangeDETF |
| **Blast radius** | both Single SE DETF packages (ports copy MultiVault A0 hole) |
| **Attacker** | EXT / CFG |
| **Attack scenario** | 1. Deploy inert DETF (`isReserveLive=false`; mint/burn revert). 2. Donate vaultShare (Balancer) or pairToken (CP) to the diamond. 3. Attacker is first `bond(..., pretransferred=false)` — should join **only pulled** amount; extra donation stays idle then end-sync books it. 4. Attacker alternatively `bond(..., pretransferred=true)` claiming the donation as U while `R=0` (bootstrap) — **must not** convert **other users’** pre-seeded assets into attacker bond principal beyond L-RSRV-DUST. 5. After first honest bond+sync, first `exchangeIn` must not drain leftover seed. 6. Pass = attacker enrichment ≤ their own pull; first mint cannot drain pool self-leg / protocol LP. |
| **Preconditions** | Fresh instance; donated inventory before live; no mock SUT |
| **Impact** | Unproven P0: if A0 were live, first bonder/minter drains residual. Static read: mint requires `_requireReserveLive`; first bond pull-false uses measured pull then joins that amount; CP first bond sizes DETF join from creation rate × **pulled pair**. **Ship-gate still requires the test.** |
| **Evidence** | `rg test_A0_` under both allowlisted test trees → **no matches**. Balancer `bond` (`BondingTarget.sol` 82–150) pulls then `_joinReserveBothLegs(detfForPool_, vaultShares_)` then `_syncAllExpectedHoldReserves`. CP `_firstBondJoin` (`BondingTarget.sol` 98–110) uses `_settleToPair` output. Skill `indexedex-adversarial-testing` lists A0 as mandatory P0. Parallel to `SEC-DETF-MV-007`. |
| **Runtime** | n/a (not Critical CODE) |
| **Recommended CODE** | none unless A0 test fails (then treat as CODE) |
| **Recommended TEST** | `test_A0_preLive_donatedVaultShare_cannotBeFirstMinted`; `test_A0_donatedInventory_firstBondDoesNotStealOthersSeed`; `test_A0_emptyUserSupply_donatedInventory_notDrainedByFirstMint` (CP: pairToken). Setup: registry-deploy; donate; first bond as specified; assert attacker enrichment ≤ own pull. `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/**' --match-test 'test_A0_'` and matching CP path. |
| **Anti-theater** | Must donate **before** live; must not count L-RSRV-DUST same-tx self-push as A0; must call **proxy**; no `MockStandardExchange` as DETF/SE SUT |
| **Suggested WP-ID** | `WP-SEC-DETF-SSE-A0-001` |
| **Link TCA / prior** | none (coverage-audit did not file A0; MultiVault peer `SEC-DETF-MV-007`) |
| **Depends / parallel** | Parallel with F1/J3/CP-AH; do not touch `_pullToken` (owned) |

### 6.11 [SEC-DETF-SSE-011] — F1 leftover-admin theater

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-011 |
| **Title** | F1 `diamondCut` call uses invalid ABI; CP has no F1 test |
| **Severity** | Medium |
| **Class** | **THEATER** |
| **Confidence** | confirmed |
| **Catalog IDs** | F1 |
| **Pattern IDs** | PAT-THEATER-FACET, PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control / proxies |
| **CROPS pillar** | S (upgrade surface) |
| **Incident theme** | none |
| **Products** | SingleStandardExchangeDETF; UniswapV4SingleStandardExchangeDETF |
| **Blast radius** | tests (production statically clean) |
| **Attacker** | EXT (test theater only) |
| **Attack scenario** | 1. Reviewer treats `test_F1_diamondCut_notCallableByAttacker` as proof Cut is absent. 2. Call encodes `diamondCut((address,uint8,bytes4[])[],address,bytes)` with `new bytes(0)` as the **first** argument (not a `FacetCut[]`). 3. Call fails ABI decode even if selector exists. 4. CP has **no** F1 at all. |
| **Preconditions** | n/a (test quality) |
| **Impact** | False confidence on L-SEC-11. Production DFPkg cuts are ERC20/EIP712/Permit + MultiAsset views + product facet only. |
| **Evidence** | `Adversarial_SingleSE_P0.t.sol` 226–233. CP: no `test_F1_*`. DFPkg `facetCuts()` 6 entries — no `IDiamondCut`. Same class as `SEC-DETF-MV-008`. |
| **Recommended CODE** | none |
| **Recommended TEST** | See `WP-SEC-DETF-SSE-F1-001` |
| **Anti-theater** | Loupe `facetAddress(IDiamondCut.diamondCut.selector)==0`; low-level call with **valid empty `FacetCut[]`**; `owner()` FunctionNotFound **or** address(0) only |
| **Suggested WP-ID** | `WP-SEC-DETF-SSE-F1-001` |
| **Link TCA / prior** | none (coverage scored F1 as F on Balancer) |
| **Depends / parallel** | Parallel with A0 |

### 6.12 [SEC-DETF-SSE-012] — J3 not full product API

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-012 |
| **Title** | J3 proxy smoke omits redeem/close/claimRewards success-or-exact-access |
| **Severity** | Medium |
| **Class** | **TEST** |
| **Confidence** | confirmed |
| **Catalog IDs** | J3 |
| **Pattern IDs** | PAT-THEATER-FACET (partial) |
| **EVM-audit domain** | proxies |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | both |
| **Blast radius** | tests (no static selector omit found) |
| **Impact** | A missing money selector could still pass J3. Static skim: Balancer 32 / CP 33 `facetFuncs` include redeem/claim/compound. |
| **Evidence** | Balancer J3: views + ZeroAmount mint/bond + sell bare revert + buyClaim ZeroAmount + claimLiquidity `NotAuthorized` + compound. **No** `redeemClaim` / `closeBondMature` / `previewRedeemClaim` call. CP J3: views + ZeroAmount + mint/burn success + compound; **no** `redeemClaim` / `claimRewards` / `claimLiquidity` NotAuthorized. |
| **Recommended TEST** | See `WP-SEC-DETF-SSE-J3-001` |
| **Anti-theater** | Each product selector on **proxy**; success **or** exact product/access revert — never empty-code |
| **Suggested WP-ID** | `WP-SEC-DETF-SSE-J3-001` |
| **Link TCA / prior** | residual of TCA-DETF-SSE-006 / 009 (suites exist; completeness leftover) |
| **Depends / parallel** | Parallel with A0; do not re-own WP-J-* |

### 6.13 [SEC-DETF-SSE-013] — Uni V4 CP A–H catalog incomplete

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-013 |
| **Title** | Uni V4 CP lacks catalog-named A1/A3/D2/D3/E5/H2/F1 after I/J landed |
| **Severity** | Medium |
| **Class** | **TEST** |
| **Confidence** | confirmed |
| **Catalog IDs** | A1–A3, D2, D3, E5, H2, F1 |
| **Pattern IDs** | none (gap, not theater) |
| **EVM-audit domain** | general |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | UniswapV4SingleStandardExchangeDETF |
| **Blast radius** | tests |
| **Impact** | Happy Claim/Bond/MintBurn cover some behaviors without catalog IDs or exact-selector negatives. Not a confirmed CODE vuln. |
| **Evidence** | `rg function test_A1_|test_D2_|test_H2_|test_F1_` under CP DETF tests → no matches. Coverage `TCA-DETF-SSE-008` leftover after I/J; suggested `WP-ADV-DETF-SSE-CP-001` was **never** in STAGE3 44/44. |
| **Recommended TEST** | Port P0 names from Balancer `Adversarial_SingleSE_P0.t.sol` onto CP TestBase |
| **Anti-theater** | Production proxy; exact selectors; no mock DETF |
| **Suggested WP-ID** | `WP-SEC-DETF-SSE-CP-AH-001` |
| **Link TCA / prior** | TCA-DETF-SSE-008 residual (I/J owned; A–H not closed) |
| **Depends / parallel** | After I/J (already landed); parallel with A0 |

### 6.14 [SEC-DETF-SSE-014] — Claim/close preview≡execute unproven (Balancer)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-014 |
| **Title** | No N2 test that `previewRedeemClaim` / `previewCloseBondMature` match execute |
| **Severity** | Medium |
| **Class** | **TEST** |
| **Confidence** | static-high (CODE looks correct; unproven) |
| **Catalog IDs** | N2 |
| **Pattern IDs** | PAT-N-TOCTOU |
| **EVM-audit domain** | general |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | SingleStandardExchangeDETF |
| **Blast radius** | this package (CODE already better than MultiVault) |
| **Impact** | If preview drifts from `_exitRedepositSettle` dust-rejoin, integrators set wrong `minOut` (grief or under-protect). **Not** the MultiVault “returns raw BPT” bug — `_previewBptUnwind` quotes vaultShare / SE `previewExchangeIn`. |
| **Evidence** | `BondingTarget.sol` 314–323, 280–290; `Common.sol` 104–121. No `test_N2_*`. Contrast mint/burn preview≡exec. |
| **Recommended TEST** | `test_N2_previewRedeemClaim_equalsExecute`; `test_N2_previewCloseBondMature_equalsExecute` |
| **Anti-theater** | Compare preview to **execute out** of the same `tokenOut` |
| **Suggested WP-ID** | `WP-SEC-DETF-SSE-N2-001` |
| **Link TCA / prior** | none (peer `SEC-DETF-MV-009` is CODE on MultiVault — **do not** copy that fix here) |
| **Depends / parallel** | Parallel with A0 |

### 6.15 [SEC-DETF-SSE-015] — Registry disable bricks redeem/close

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-SSE-015 |
| **Title** | Registry kill-switch freezes `_requireActive` exit (redeem/close/mint/bond) |
| **Severity** | Medium |
| **Class** | **NEEDS_OWNER** |
| **Confidence** | static-high |
| **Catalog IDs** | F, CROPS-C |
| **Pattern IDs** | PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | C (censorship / freeze) |
| **Incident theme** | leftover admin / pause bricks exit |
| **Products** | both |
| **Blast radius** | family + manager disable API |
| **Impact** | Compromised/hostile manager can freeze redeem/close. Sell-to-claim still works (no `_requireActive`). Not leftover `diamondCut`. Product Disable tests treat mint block as intended. |
| **Evidence** | `_requireNotDisabled` in both Commons; used by `_requireActive` → mint/burn/bond/buyClaim/close/redeem. `sellPositionToDetfNft` (Balancer) does **not** check disable. MultiVault gold claimed disable cannot brick instance functions — **this family differs**. |
| **Recommended CODE** | none until product owner: either document kill-switch as ACCEPTED_RISK or exempt redeem/close (walkaway). |
| **Recommended TEST** | if exempt: `test_disable_doesNotBrickRedeemOrClose`. Else document in CROPS record. |
| **Anti-theater** | Must hit redeem/close, not only mint |
| **Suggested WP-ID** | none here — **A-manager-fee-registry** / `S-crops-trust` own disable policy |
| **Link TCA / prior** | Disable hermetic is product H, not a coverage I/J WP |
| **Depends / parallel** | Manager area |

---

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|----------------------------|-----|
| `test_F1_diamondCut_notCallableByAttacker` (Balancer) | First ABI arg is `bytes(0)`, not `FacetCut[]` — fails decode even if Cut is live | Valid empty `FacetCut[]` + loupe `diamondCut==0` |
| Implicit “I covered by A1” | A1 is pull-path; I is `pretransferred=true` | I suite now exists — do not regress |
| Implicit “J closed because H uses proxy” | H does not enumerate Target ⊆ facetFuncs ⊆ loupe | J suite exists; extend J3 |
| Bare `expectRevert` on D2/D3/F2/H3/preLive/CP lockTooShort | Wrong selector still passes | Exact selectors (`TCA-DETF-SSE-010` leftover) |
| CP `*_Adversarial.t.sol` as “adversarial suite” | C + partition only; not A–K | Port catalog names (`SEC-DETF-SSE-013`) |
| J3 “proxy smoke” | Does not call each money selector | `SEC-DETF-SSE-012` |
| Coverage 2026-08-09 “PAT-I-ABS live Blocker” | CODE has been reserve-delta since gap-closure | Treat as OWNED_ELSEWHERE closed |

**Not theater:** I1 (no in-call transfer, inventory present, exact selector); C1–C3 exact `IsLocked` (Balancer); E5 exact selectors; mint/burn preview≡exec; ProductLaw M1/M2 exact `BondNotMature`; production registry deploy; CP I1/I2/I3 same bar.

**PAT-THEATER-PRE:** not present on I suites.

**PAT-MOCK:** no mock of Balancer DETF SUT. CP C-test uses `SimpleYieldERC4626` + hostile pair as **configured PkgArgs SE/pair**, DETF is production DFPkg proxy — acceptable (TCA-DETF-SSE-015).

---

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| TCA-DETF-SSE-001 / 002 · WP-I-DETF-SSE-001 | Yes — `_pullToken` + burn pull (Balancer) | **OWNED_ELSEWHERE** — CODE re-verified **fixed** (reserve-delta). No `sec_fix_*`. |
| TCA-DETF-SSE-003 · WP-I-DETF-SSE-CP-001 | Yes — CP `_pullToken` + I suite | **OWNED_ELSEWHERE** — CODE + I tests present |
| TCA-DETF-SSE-004 · WP-I-DETF-SSE-UV4-001 | Legacy listing DETF tree | **OWNED_ELSEWHERE / stale** — **directory gone**; do not re-own |
| TCA-DETF-SSE-005 · WP-I-DETF-SSE-002 | Yes — Balancer I tests | **OWNED_ELSEWHERE** — tests present and meet I bar |
| TCA-DETF-SSE-006 · WP-J-DETF-SSE-001 | Yes — Balancer J suite | **OWNED_ELSEWHERE**; residual completeness = new TEST `SEC-DETF-SSE-012` |
| TCA-DETF-SSE-007 | K1 CODE+TEST | CODE **OWNED_ELSEWHERE** (fixed by 001); named `test_K1_*` still absent (I3 covers) |
| TCA-DETF-SSE-008 | CP I/J/K + A–H | I/J **OWNED_ELSEWHERE**; A–H residual = `SEC-DETF-SSE-013` (new TEST, not competing CODE) |
| TCA-DETF-SSE-009 · WP-J-DETF-SSE-CP-001 | Yes — CP J | **OWNED_ELSEWHERE**; J3 leftover in 6.12 |
| TCA-DETF-SSE-010 | bare expectRevert | **OWNED_ELSEWHERE** (Medium TEST; keep) |
| TCA-DETF-SSE-011 · WP-L3-DETF-SSE-001 | L3 handler | **OWNED_ELSEWHERE** |
| TCA-DETF-SSE-012 | port residual vs MultiVault layout | **OWNED_ELSEWHERE** / opportunistic |
| TCA-DETF-SSE-013 | legacy product maturity | **N/A** — product deleted |
| TCA-DETF-SSE-014 / 015 | baseline / no mock SUT | Info — still true |
| WP-I-CLONE-001 | clone pull API freeze | **OWNED_ELSEWHERE** — both `_pullToken` clones already match freeze |

**Stale coverage claim:** 2026-08-09 “I = G / `_pullToken` returns amount_” / “zero `test_I*` / no J suite” is **false** at `1e0d7c48`.

---

## 9. Work package stubs

OWNED_ELSEWHERE findings have **no** `sec_fix_*` stubs.

### WP-SEC-DETF-SSE-A0-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-SSE-A0-001` |
| **Title** | Add Single SE catalog A0 residual-inventory tests (Balancer + CP) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | SingleStandardExchangeDETF; UniswapV4SingleStandardExchangeDETF |
| **Finding IDs** | SEC-DETF-SSE-010 |
| **Problem** | P0 A0 has no `test_A0_*` on either product. First-minter/bonder drain of pre-seeded inventory is unproven. Production looks gated (inert + pull-false first bond + end-sync) but ship-gate requires the test. |
| **Production files (touch set)** | none unless test fails |
| **Test files (touch set)** | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/Adversarial_SingleSE_P0.t.sol` (or new `Adversarial_EmptyVault.t.sol`); `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/adversarial/` (new or TrustFlag) |
| **Out of scope files** | `_pullToken` / TrustFlags (owned); MultiVault; Uni V4 weighted/orbital/quad |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-DETF-SSE-F1-001`, J3, CP-AH, N2 |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-sse-a0` · branch `sec_fix/detf-sse-a0` |
| **Implementation notes** | Gold TestBases; donate vaultShare (Balancer) / pairToken (CP) **before** first bond; DETF role names; L-RSRV-DUST ≠ A0; copy MultiVault `WP-SEC-DETF-MV-A0-001` shape |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/**' --match-test 'test_A0_'` and `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**' --match-test 'test_A0_'` green |
| **Anti-theater checks** | Donate before first bond; proxy calls; no mock SE as DETF SUT; attacker cannot drain **others’** seed after first honest sync |
| **Proof-first?** | no (TEST; if it fails, escalate to CODE + proof) |
| **Estimate** | S–M |

### WP-SEC-DETF-SSE-F1-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-SSE-F1-001` |
| **Title** | Tighten F1 leftover-admin proof on both Single SE DETFs |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | both |
| **Finding IDs** | SEC-DETF-SSE-011 |
| **Problem** | Balancer F1 uses invalid `diamondCut` ABI; CP has no F1. Production statically has no Cut/Ownable. |
| **Production files (touch set)** | none |
| **Test files (touch set)** | Balancer `Adversarial_SingleSE_P0.t.sol`; CP new Access or Surface |
| **Out of scope files** | DFPkg cuts unless a selector is actually found (none expected) |
| **Depends on** | none |
| **Parallelizable with** | A0, J3 |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-sse-f1` · branch `sec_fix/detf-sse-f1` (or fold into A0 tree) |
| **Implementation notes** | Mirror `WP-SEC-DETF-MV-F1-001`; loupe + valid empty `FacetCut[]` |
| **Acceptance** | `test_F1_*` asserts `facetAddress(diamondCut)==0` and `owner()` missing/zero |
| **Anti-theater checks** | Must not pass solely because ABI decode failed |
| **Proof-first?** | no |
| **Estimate** | S |

### WP-SEC-DETF-SSE-J3-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-SSE-J3-001` |
| **Title** | Extend J3 to every product money selector on proxy |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | both |
| **Finding IDs** | SEC-DETF-SSE-012 |
| **Problem** | J3 omits redeem/close/claimRewards. J bar is Target ⊆ facetFuncs ⊆ cuts ⊆ loupe ⊆ PROXY call. |
| **Production files (touch set)** | none unless omit found (static skim found none) |
| **Test files (touch set)** | both `adversarial/Adversarial_Surface.t.sol` |
| **Out of scope files** | Facet `facetFuncs` unless J1 fails |
| **Depends on** | none (do not reopen WP-J-DETF-SSE-*) |
| **Parallelizable with** | A0, F1, CP-AH |
| **Conflicts with coverage-audit WP** | residual of WP-J-*; **do not** duplicate CODE — TEST completeness only |
| **Suggested worktree** | `sec_fix_detf-sse-j3` · branch `sec_fix/detf-sse-j3` |
| **Implementation notes** | Smoke redeem/close/claimRewards: success **or** exact access/guard revert |
| **Acceptance** | J3 loops product controls; each call on proxy |
| **Anti-theater checks** | Never call facet impl as SUT; never `FunctionNotFound` |
| **Proof-first?** | no |
| **Estimate** | S |

### WP-SEC-DETF-SSE-CP-AH-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-SSE-CP-AH-001` |
| **Title** | Port Uni V4 CP A–H P0 catalog names onto production TestBase |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | UniswapV4SingleStandardExchangeDETF |
| **Finding IDs** | SEC-DETF-SSE-013 |
| **Problem** | After I/J, CP still lacks catalog A1/A3/D2/D3/E5/H2/F1. Happy suites are not a substitute. |
| **Production files (touch set)** | none |
| **Test files (touch set)** | `…/constantProduct/single/adversarial/` (new `Adversarial_P0.t.sol` or extend existing) |
| **Out of scope files** | Balancer P0 (already F); `_pullToken` |
| **Depends on** | none (I/J already landed) |
| **Parallelizable with** | A0, F1, J3 |
| **Conflicts with coverage-audit WP** | none (suggested `WP-ADV-DETF-SSE-CP-001` never staged) |
| **Suggested worktree** | `sec_fix_detf-sse-cp-ah` · branch `sec_fix/detf-sse-cp-ah` |
| **Implementation notes** | Copy Balancer P0 IDs; adapt to pairToken / protocolLp / no closeBondMature |
| **Acceptance** | `forge test --match-path '…/constantProduct/single/adversarial/**' --match-test 'test_A1_|test_A3_|test_D2_|test_D3_|test_H2_|test_F1_|test_E5_'` |
| **Anti-theater checks** | Exact selectors; proxy; no mock DETF |
| **Proof-first?** | no |
| **Estimate** | M |

### WP-SEC-DETF-SSE-N2-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-SSE-N2-001` |
| **Title** | Prove Balancer claim/close preview ≡ execute |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | SingleStandardExchangeDETF |
| **Finding IDs** | SEC-DETF-SSE-014 |
| **Problem** | `_previewBptUnwind` already quotes settlement; no test compares to execute (dust-rejoin may drift). |
| **Production files (touch set)** | none unless test fails (then BondingTarget / Common only) |
| **Test files (touch set)** | `SingleStandardExchangeDETF_Bonding.t.sol` and/or ProductLaw |
| **Out of scope files** | MultiVault `_previewExitSettle` (different bug); CP (no preview API) |
| **Depends on** | none |
| **Parallelizable with** | A0, F1 |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-sse-n2` · branch `sec_fix/detf-sse-n2` |
| **Implementation notes** | Do **not** port MultiVault N2 CODE (raw BPT) — this family already unwinds |
| **Acceptance** | `forge test --match-path '…/balancer/v3/standardExchange/single/**' --match-test 'test_N2_'` ; preview ≈ execute (documented ≤ few-wei if Balancer forces) |
| **Anti-theater checks** | Same `tokenOut`; not merely `preview > 0` |
| **Proof-first?** | no |
| **Estimate** | S |

---

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Note |
|------|-------|------|
| Open-threshold seigniorage | **ACCEPTED_RISK** | B1: victim balances + no free principal + residual inventory. Policy deadband exclusive. |
| L-RSRV-DUST unbooked U until first sync | **ACCEPTED_RISK** | Next `pretransferred` may credit `min(claimed, U)`. After honest money-route sync, I1/I3 block. |
| First-bond creation-rate MEV (CP) | **ACCEPTED_RISK** | Family PRD §0.4 #10 non-goal. |
| Registry disable bricks `_requireActive` | **NEEDS_OWNER** | `SEC-DETF-SSE-015`. Intentional kill-switch vs walkaway. Owner: `A-manager-fee-registry` / `S-crops-trust`. |
| leftover `diamondCut` / owner | **ACCEPTED_RISK** (none) | Statically absent. F1 test theater only. |
| E6 / F5 surplus refund | **N/A** | No `balance − floor` path; compound does not pay caller. |
| M1–M3 / O1–O3 / I5 | **N/A** | No user calldata / product permit money path. |
| I4 / L2 FoT | **N/A** | Not a product claim. |
| A4–A5 / B2 / C4–C5 / H1 | **DEFER** | P2 as in Balancer P0 NatSpec. |
| L3 handler bond/claim/pretransfer | **DEFER** | TCA-DETF-SSE-011 / WP-L3 already owns. |
| `_bptForDetfShares` uses raw diamond BPT | **ACCEPTED_RISK** / L1 P | Donation subsidizes burners (same as MultiVault). Not a public skim. |
| `buyClaim` join uses claimed amount | **ACCEPTED_RISK** | detfToken is this diamond ERC-20 (FoT N/A). |
| `_tryInitDetfNft` try/catch | **DEFER** / Low | If NFT init fails, `detfNftId=0`; not an EXT extract. |
| Uni V4 weighted/orbital/quad | **N/A** | `A-detf-univ4-extra`. |
| Legacy listing DETF | **N/A** | Directory gone. |
| Shared claim / bond NFT packages | **N/A** | `A-detf-commons`. |
| `via_ir` | **forbidden** | Never recommend. |

---

## 11. Commands run

```bash
# Inventory
ls contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single
ls contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange
ls contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single
ls test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single
ls test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single

# Pattern hunt (allowlisted trees)
rg -n "function _pullToken|pretransferred|TransferDeltaInsufficient|diamondCut|onlyOwner|onlyOperator|facetFuncs|initializeReserve|redeemClaim|buyClaim|claimLiquidity|compoundProtocolRewards" \
  contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single

rg -n "function test_A0_|function test_I1_|function test_I2_|function test_I3_|function test_J1_|function test_J2_|function test_J3_|function test_K1_|function test_F1_" \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single \
  test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single

rg -n "uniswap/v4/standardExchange/single" --glob '*.{sol,md}' | head

# Coverage collision
rg -n "WP-I-DETF-SSE|WP-J-DETF-SSE|WP-I-CLONE-001|TCA-DETF-SSE" docs/testing/coverage-audit

# Read (selected)
# SingleStandardExchangeDETFCommon.sol ~517-560
# UniswapV4SingleStandardExchangeDETFCommon.sol ~460-557
# ExchangeOutTarget (both) burn _pullToken
# BondingTarget sell/redeem/claimLiquidity
# DFPkg facetCuts (both)
# Adversarial_TrustFlag.t.sol / Adversarial_Surface.t.sol (both)
# DETFBondLifecycleLib.sol maturity gate
# UniswapV4SingleStandardExchangeDETF_PRD.md removed topology
# A-commons-pull.md §2.2.A ; A-detf-multi-vault.md gold
# STAGE3_PROGRESS.md WP-I/J-DETF-SSE-* closed
```

**Forge:** not run (static re-verify; L-SEC-3 / orchestrator). No `docs/security/audit/repro/SEC-DETF-SSE-*/` — no Critical CODE candidate.

**Skills walked:** `crane-adversarial-testing` catalog A–K + A0/L/M/N/O + E6/F5 + I/J bars; `implementation-test-dod.md` headings 1–3; `indexedex-adversarial-testing` DETF mapping; `indexedex-testing` registry deploy; `ethskills-security` reentrancy/CEI/SafeERC20/4626 inflation/proxies; `defi-incident-patterns` theme→catalog (A0, I, E6, F5, J).
