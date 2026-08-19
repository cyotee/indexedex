# Security Audit — Scope Partition (Stage 1 MODE=full)

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Mode | **full** (L-SEC-1 pilot exit passed; `PILOT_EXIT.md` remains in place) |
| PRD | `docs/security/SECURITY_AUDIT_PRD.md` §§2–8, §12, §15.3, **L-SEC-1…14** |
| Execute plan | `docs/security/SECURITY_AUDIT_EXECUTE_PLAN.md` Tasks O5–O7 |
| Full-pass prompt | `docs/security/PROMPT_SECURITY_AUDIT_FULL_PASS.md` |
| Alchemy | `ALCHEMY_KEY` may be present; fork proofs use `foundry.toml` `*_alchemy` + `FOUNDRY_PROFILE=fork` (L-SEC-6) |
| Split rule | Execute-plan §2.2 names one `A-se-v3-v4-lending` bucket. **Split wins** (OBJECTIVE / L-SEC-2). Child areas are non-overlapping. |

Inventory sources: `docs/agent/INDEXEDEX_CONTENT_INVENTORY.md` + `contracts/` tree (every `*DFPkg*.sol` / money facet/target). `research/**` has **no** `.sol` product contracts.

---

## Reused pilot reports (do not rewrite)

| ID | Production allowlist | OUT_FILE | Hole? |
|----|----------------------|----------|-------|
| `A-commons-pull` | `contracts/vaults/basic/**`; `ISecurePullErrors`; clone pull as **reference blast** | `areas/A-commons-pull.md` | No — inventory names only `basic/` + clones (clones assigned to owning product areas) |
| `A-detf-multi-vault` | `…/multi-vault-weighted/**` | `areas/A-detf-multi-vault.md` | No |
| `A-se-amm-v2` | Aerodrome v1 + Camelot v2 + Uni V2 SE | `areas/A-se-amm-v2.md` | No — Slipstream is **not** v1/v2; assigned `A-slipstream-buffer` |
| `S-sharp-edges` | Pilot PkgArgs / flags | `specialists/S-sharp-edges.md` | Extend with addendum **only** if full-pass adds material Highs that belong there |
| `S-crops-trust` | Pilot unowned / manager reach | `specialists/S-crops-trust.md` | Same addendum rule; full CROPS walk is `A-manager-fee-registry` + `S-crops-trust` reuse |

Thin pilot `AGGREGATE.md` + `WORK_PACKAGE_BACKLOG.md` archived at `docs/security/audit/archive/2026-08-13/` before overwrite.

---

## Full-pass product areas (owning area = SUT package home)

### F1 — remaining DETF families

| ID | Production allowlist (deep review ONLY) | Test allowlist (primary) | OUT_FILE | Focus |
|----|-----------------------------------------|--------------------------|----------|--------|
| `A-detf-single-se` | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**` | `test/**/standardExchange/single/**`; `test/**/uniswap/v4/standardExchange/constantProduct/single/**` | `areas/A-detf-single-se.md` | Port vs MultiVault; PAT-I-ABS clones; I/J; residual |
| `A-detf-composed-stable` | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/**`; `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**` | `test/**/stable/common/**`; `test/**/mixedBuffer/**` | `areas/A-detf-composed-stable.md` | Multi-leg residual, claim, G, I/J |
| `A-detf-dual-liquidity` | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**` | `test/foundry/fork/**/crossVersion/v2/**`; matching hermetic if any | `areas/A-detf-dual-liquidity.md` | **Fork-first (L-SEC-5)**; missing fork P0 = High/Critical |
| `A-detf-univ4-extra` | `…/uniswap/v4/standardExchange/weighted/**`; `…/orbital/**`; `…/stable/quad/curve/**`; Uni V4 DETF common `…/uniswap/v4/common/{nft,rebasing}/**` | Matching `test/**/uniswap/v4/standardExchange/{weighted,orbital,stable/quad}/**` | `areas/A-detf-univ4-extra.md` | Extra Uni V4 families (not CP-single); I/J/A0 |
| `A-detf-commons` | `contracts/vaults/detf/common/{core,claimToken,bondNft,inventory,factory}/**` | `test/**` touching rebasing claim / DETF NFT vault / `WP-I-CLAIM-001` seeds | `areas/A-detf-commons.md` | Claim token I; bond NFT D; shared compound/expansion libs as **reference** for `S-spec-detf` |

### F2 — split SE / hooks / platform (execute-plan `A-se-v3-v4-lending` **split**)

| ID | Production allowlist | Test allowlist | OUT_FILE | Focus |
|----|----------------------|----------------|----------|--------|
| `A-se-univ3` | `contracts/protocols/dexes/uniswap/v3/**` | Matching TestBases + `test/**/uniswap/v3/**` | `areas/A-se-univ3.md` | Live PAT-I-ABS (pilot blast); E6 refund entire balance |
| `A-se-univ4` | `contracts/protocols/dexes/uniswap/v4/**` (SE vault, **not** DETF, **not** hooks) | `test/**` Uni V4 SE vault (not DETF/hook trees) | `areas/A-se-univ4.md` | Local liquid buffer; I/J; L/B; E6 |
| `A-se-aave` | `contracts/protocols/lending/aave/v3.6/**`; `contracts/protocols/lending/aave/cross-version/**` | `test/**/aave/**`; `TestBase_Aave*` | `areas/A-se-aave.md` | Stata share math; loop rebalance; I/J; lending domain |
| `A-se-morpho-erc4626` | `contracts/vaults/standard/erc4626/**` (generic ERC-4626 SE; Morpho is TestBase consumer, no separate Morpho DFPkg) | `TestBase_ERC4626StandardExchange.sol`; `TestBase_ERC4626MorphoHermetic.sol`; matching spec | `areas/A-se-morpho-erc4626.md` | ERC4626 pull (delta peer); Morpho hermetic wiring |
| `A-se-lst` | `contracts/protocols/staking/{lido,etherfi,rocket-pool}/**` | Matching `TestBase_*StandardExchange` + `test/**/staking/**` | `areas/A-se-lst.md` | Rebase / weETH / rETH; same-tx delta pull |
| `A-se-balancer-v3` | `contracts/protocols/dexes/balancer/v3/pools/**`; `…/rateProviders/**`; `…/routers/**` (SE router DFPkg, **not** coordinator) | `test/**/balancer/v3/{pools,routers,rateProviders}/**` | `areas/A-se-balancer-v3.md` | Buffer/multi-vault pools; rate providers; SE router J/M |
| `A-hooks-v4-se-buffer` | `contracts/hooks/uniswap/v4/standardExchange/**` (every SE buffer hook DFPkg) | `test/**/hooks/**/standardExchange/**` | `areas/A-hooks-v4-se-buffer.md` | Every SE buffer hook; J; residual; `_securePull` |
| `A-hooks-v4-swap-factory` | `contracts/hooks/uniswap/v4/{factory,weighted,orbital,stable}/**` | Matching hook factory + swap-hook tests | `areas/A-hooks-v4-swap-factory.md` | Factory CREATE3 flags; swap hooks; J |
| `A-manager-fee-registry` | `contracts/manager/**`; `contracts/fee/collector/**`; `contracts/oracles/fee/**`; `contracts/registries/vault/**` | `test/foundry/spec/{manager,fee,oracles/fee}/**`; registry/manager specs | `areas/A-manager-fee-registry.md` | Access; disable/exit; fee non-dilution; CROPS |
| `A-routers-permit2` | `contracts/routers/**` (coordinator); Permit2 witness paths on this router | `test/foundry/spec/routers/**`; `test/foundry/fork/**/routers/**` | `areas/A-routers-permit2.md` | M, O, I5, allowance theater |
| `A-slipstream-buffer` | `contracts/protocols/dexes/aerodrome/slipstream/**`; `contracts/vaults/slipstream/**` | `test/**/slipstream/**`; `test/foundry/fork/base_main/slipstream/**` | `areas/A-slipstream-buffer.md` | Same-tx delta pull; CL buffer |

### F2b — research / empty

| ID | Production | Status |
|----|------------|--------|
| `A-research-contracts` | `research/**` | **N/A — no `.sol` products.** Documented here so inventory is closed. **No area report file required.** |

---

## Product → owning area (L-SEC-2 — every money product named)

| Product | Path | Owning area |
|---------|------|-------------|
| BasicVaultCommon + BasicVault facets/repos | `contracts/vaults/basic/**` | `A-commons-pull` (pilot) |
| ISecurePullErrors | `contracts/interfaces/ISecurePullErrors.sol` | `A-commons-pull` (pilot) |
| MultiVaultWeightedDetf | `…/multi-vault-weighted/**` | `A-detf-multi-vault` (pilot) |
| Aerodrome V1 SE | `contracts/protocols/dexes/aerodrome/v1/**` | `A-se-amm-v2` (pilot) |
| Camelot V2 SE | `contracts/protocols/dexes/camelot/v2/**` | `A-se-amm-v2` (pilot) |
| Uniswap V2 SE | `contracts/protocols/dexes/uniswap/v2/**` | `A-se-amm-v2` (pilot) |
| SingleStandardExchangeDETF (Balancer V3) | `…/balancer/v3/standardExchange/single/**` | `A-detf-single-se` |
| UniswapV4SingleStandardExchangeDETF (CP) | `…/uniswap/v4/standardExchange/constantProduct/single/**` | `A-detf-single-se` |
| ComposedStableCommonDetf + RebasingDETFToken + bond NFT pkg | `…/balancer/v3/stable/common/**` | `A-detf-composed-stable` |
| MixedBufferMultiVaultStableDetf | `…/balancer/v3/mixedBuffer/**` | `A-detf-composed-stable` |
| DualLiquidity (removed)CrossVersion | `…/crossVersion/v2/**` | `A-detf-dual-liquidity` |
| UniswapV4StandardExchangeWeightedDETF | `…/uniswap/v4/standardExchange/weighted/**` | `A-detf-univ4-extra` |
| UniswapV4StandardExchangeOrbitalDETF | `…/uniswap/v4/standardExchange/orbital/**` | `A-detf-univ4-extra` |
| UniswapV4StandardExchangeCurveQuadStableDETF | `…/uniswap/v4/standardExchange/stable/quad/curve/**` | `A-detf-univ4-extra` |
| UniV4DetfBondNft + UniV4DetfRebasingClaim | `…/uniswap/v4/common/{nft,rebasing}/**` | `A-detf-univ4-extra` |
| RebasingClaimToken (shared) | `contracts/vaults/detf/common/claimToken/**` | `A-detf-commons` |
| DETFNFTVault (shared) | `contracts/vaults/detf/common/bondNft/**` | `A-detf-commons` |
| DETF shared core / inventory / factory | `contracts/vaults/detf/common/{core,inventory,factory}/**` | `A-detf-commons` (libs; `S-spec-detf` consumes) |
| Uniswap V3 SE | `contracts/protocols/dexes/uniswap/v3/**` | `A-se-univ3` |
| Uniswap V4 SE (vault) | `contracts/protocols/dexes/uniswap/v4/**` | `A-se-univ4` |
| Aave V3 Stata SE | `contracts/protocols/lending/aave/v3.6/**` | `A-se-aave` |
| Aave CrossVersion Loop | `contracts/protocols/lending/aave/cross-version/**` | `A-se-aave` |
| ERC4626 Standard Exchange | `contracts/vaults/standard/erc4626/**` | `A-se-morpho-erc4626` |
| Morpho (no dedicated DFPkg) | TestBase `TestBase_ERC4626MorphoHermetic.sol` | `A-se-morpho-erc4626` |
| Lido wstETH SE | `contracts/protocols/staking/lido/**` | `A-se-lst` |
| EtherFi weETH SE | `contracts/protocols/staking/etherfi/**` | `A-se-lst` |
| Rocket Pool rETH SE | `contracts/protocols/staking/rocket-pool/**` | `A-se-lst` |
| Slipstream SE | `contracts/protocols/dexes/aerodrome/slipstream/**` | `A-slipstream-buffer` |
| SlipstreamVaultRepo | `contracts/vaults/slipstream/**` | `A-slipstream-buffer` |
| Balancer V3 buffer / multi-vault pools | `contracts/protocols/dexes/balancer/v3/pools/**` | `A-se-balancer-v3` |
| SE rate providers | `…/balancer/v3/rateProviders/**` | `A-se-balancer-v3` |
| BalancerV3StandardExchangeRouter | `…/balancer/v3/routers/**` | `A-se-balancer-v3` |
| SE buffer hook DFPkgs (CP single, single, dual, weighted, orbital, quad bal/curve) | `contracts/hooks/uniswap/v4/standardExchange/**` | `A-hooks-v4-se-buffer` |
| Swap hook DFPkgs (weighted, orbital, quad bal/curve) + hook factory | `contracts/hooks/uniswap/v4/{weighted,orbital,stable,factory}/**` | `A-hooks-v4-swap-factory` |
| IndexedexManager | `contracts/manager/**` | `A-manager-fee-registry` |
| Fee collector | `contracts/fee/collector/**` | `A-manager-fee-registry` |
| Fee oracle | `contracts/oracles/fee/**` | `A-manager-fee-registry` |
| Vault registry | `contracts/registries/vault/**` | `A-manager-fee-registry` |
| BalancerV3↔UniV4 coordinator router | `contracts/routers/balancerV3-uniswapV4/**` | `A-routers-permit2` |
| Constants / shared interfaces | `contracts/constants/**`, `contracts/interfaces/**` | Reference-only (not a money SUT); cited by owning product |
| `research/**` | no `.sol` | F2b N/A |

**Orphans found and assigned (not DEFER’d as “not launch”):** Uni V4 weighted/orbital/quad DETFs; DETF shared claim/bond; ERC4626 SE; Slipstream SE + repo; Balancer V3 pools/rate providers/SE router; hook factory + every hook DFPkg; Aave loop.

---

## Specialists (F3) — after area inventories exist

| SPEC_ID | Skill | OUT_FILE | Trigger |
|---------|-------|----------|---------|
| `S-spec-detf` | spec-to-code-compliance; corpus = family `*_PRD.md` + `docs/detf/*` + `INDEXEDEX_AGENT_LAW.md` DETF | `specialists/S-spec-detf.md` | All DETF areas |
| `S-token-weird` | ethskills-audit erc20/erc4626 | `specialists/S-token-weird.md` | Full |
| `S-amm-oracle-flash` | ethskills-audit defi-amm / oracles / flashloans | `specialists/S-amm-oracle-flash.md` | SE + DETF + hooks |
| `S-diamond-proxy` | ethskills-audit proxies + catalog J | `specialists/S-diamond-proxy.md` | Full |
| `S-signatures` | ethskills-audit signatures + O / I5 | `specialists/S-signatures.md` | Routers / Permit2 |
| `S-incidents` | defi-incident-patterns (map only) | `specialists/S-incidents.md` | After areas |
| `S-evm-general` | general + precision-math + dos | `specialists/S-evm-general.md` | Full |
| `S-sharp-edges` | **reuse** pilot | addendum only if needed | — |
| `S-crops-trust` | **reuse** pilot | addendum only if needed | — |

### F4 — adversarial-modeler

One `specialists/S-adv-modeler-<FINDING_ID>.md` (or append) per leftover **Critical/High CODE** that is **not** OWNED_ELSEWHERE.

---

## Explicitly excluded

| Path | Why |
|------|-----|
| `frontend/**`, `broadcast/**`, `out/**`, `cache_forge/**` | Not production SUT |
| `lib/**` except Crane patterns as reference | Not IndexedEx product law |
| `lib/DeFiHackLabs` as compile/test dep | Reference corpus only |
| `docs/security/SECURITY_AUDIT_REMEDIATION_PRD.md` | Stage 2 — not this run |
| `sec_fix_*` / `gap_cover_*` worktrees | Stage 3 — not this run |
| `contracts/test/**` TestBases | Tests, not SUT (cited from owning area) |

---

## Coverage-audit collision (L-SEC-4)

Seed: `docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md`. Same production touch-set as `TCA-*` / `WP-I-*` → **OWNED_ELSEWHERE**; no competing `sec_fix_*`.

| Coverage WP | Likely SEC area |
|-------------|-----------------|
| `WP-I-COMMON-001/002` | `A-commons-pull` (already) |
| `WP-I-DETF-MV-*` / `WP-J-DETF-MV-001` / `WP-K-DETF-MV-001` | `A-detf-multi-vault` (already) |
| `WP-I-SE-AC-001` / `WP-J-SE-AC-001` / `WP-ADV-SE-AC-001` | `A-se-amm-v2` (already) |
| `WP-I-CLONE-001` | clones across full-pass areas — link, do not re-own CODE if WP already describes the fix |
| `WP-I-CLAIM-001` | `A-detf-commons` |
| `WP-I-DETF-SSE-001/002` / `WP-J-DETF-SSE-001` / `WP-I-DETF-SSE-CP-001` / `WP-J-DETF-SSE-CP-001` / `WP-I-DETF-SSE-UV4-001` | `A-detf-single-se` |
| `WP-I-DETF-CS-001/002` / `WP-I-DETF-MB-001` / `WP-ADV-DETF-MB-001` / `WP-J-DETF-CS-MB-001` / `WP-G-E-DETF-CS-001` | `A-detf-composed-stable` |
| `WP-I-DETF-DL-001/002` / `WP-J-DETF-DL-001` | `A-detf-dual-liquidity` |
| `WP-I-CLONE-UAB-001` / `WP-I-SE-UAB-001` / `WP-ADV-SE-UAB-001` / `WP-J-SE-UAB-001` | `A-se-univ4` + `A-se-aave` |
| `WP-I-HOOK-*` / `WP-J-HOOK-001` / `WP-ADV-HOOK-001` | hook areas |
| `WP-J-MGR-001/002` / `WP-N-FEE-001` | `A-manager-fee-registry` |
| `WP-I5-RTR-001` / `WP-N-RTR-001` / `WP-J-RTR-001` / `WP-J-ROUTER-UAB-001` | `A-routers-permit2` + `A-se-balancer-v3` |

---

## Ownership rule

Tests may be cited across areas. **Owning** area is where the SUT package lives. Commons owns `BasicVaultCommon` / `ISecurePullErrors`. Other areas cite commons as blast only.

---

## Wave graph

```text
F1 (parallel): A-detf-single-se, A-detf-composed-stable, A-detf-dual-liquidity,
               A-detf-univ4-extra, A-detf-commons
F2 (parallel, split): A-se-univ3, A-se-univ4, A-se-aave, A-se-morpho-erc4626,
                      A-se-lst, A-hooks-v4-se-buffer, A-hooks-v4-swap-factory,
                      A-manager-fee-registry
F2b (parallel with F2 or next): A-routers-permit2, A-slipstream-buffer, A-se-balancer-v3
F3 (after area inventories): 7 specialists
F4 (after Critical/High CODE set): adversarial-modeler per leftover owned CODE
Orchestrator: FULL AGGREGATE + WORK_PACKAGE_BACKLOG
```
