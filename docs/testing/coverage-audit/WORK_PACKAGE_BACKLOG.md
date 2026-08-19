# Work Package Backlog — Stage 1 Coverage Audit

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Source areas | Pilot + full (updated after F1/F2) |
| Ranking | PRD §9 composite (severity × exploitability × blast) |
| Worktree prefix | `gap_cover_` (L-TCA-8) |
| Aggregate | [`AGGREGATE.md`](./AGGREGATE.md) |
| Blocker/High coverage | **69/69** finding IDs in finding→WP index; **44** formal §8 WPs |

## Ranked WPs (Blocker / High first)

### 1. WP-I-COMMON-001 — Fix BasicVaultCommon pretransfer delta credit

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-COMMON-001` |
| **Title** | Fix BasicVaultCommon pretransfer to credit observed delta only |
| **Severity** | **Blocker** (aggregate elevation; helper free-credit runtime **confirmed**) |
| **Class** | CODE (+ test updates) |
| **Products** | All BasicVaultCommon inheritors (Aerodrome, Camelot, Uni V2, Aave Stata); Aerodrome override |
| **Finding IDs** | TCA-COMMON-001, TCA-SE-AC-001 (root CODE) |
| **Problem** | `pretransferred=true` returns claimed amount after absolute `balanceOf >= amount`, enabling free credit of vault inventory without inbound delta. NatSpec overclaims delta safety. Aerodrome override still returns claimed amount. |
| **Production files (touch set)** | `contracts/vaults/basic/BasicVaultCommon.sol`; `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol` |
| **Test files (touch set)** | `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol`; `BasicVaultCommon_Permit2.t.sol`; fork Permit2 basic vault files if asserts break |
| **Out of scope files** | Uni V3/V4/Slipstream/DETF clone bodies (→ WP-I-CLONE-001); product adversarial trees except compile fixes |
| **Depends on** | none |
| **Parallelizable with** | none on same files |
| **Suggested worktree** | `gap_cover_i-common` / branch `gap_cover/i-common` |
| **Implementation notes** | Align with `ERC4626StandardExchangeCommon._securePull` and Rocket/Lido/EtherFi `_securePull`. Skills: crane-adversarial Category I; L-CLAIM-3. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/basic/**' -vv`; new `test_I1_pretransferred_noTransfer_existingInventory_*` fails on pre-fix code, passes post-fix |
| **Anti-theater checks** | I1 must not transfer tokens in-call; must not assert `actual == claimed` against pure inventory |
| **Wave** | **0** |

### 2. WP-I-COMMON-002 — I1–I3 unit suite + kill theater

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-COMMON-002` |
| **Title** | Replace pretransfer theater with I1–I3 unit suite |
| **Severity** | High |
| **Class** | TEST |
| **Products** | BasicVaultCommon |
| **Finding IDs** | TCA-COMMON-002, TCA-COMMON-003 |
| **Problem** | Existing tests assert free credit as correct; no I1–I3 catalog tests. |
| **Production files** | none (unless error selector from 001) |
| **Test files** | `test/foundry/spec/vaults/basic/BasicVaultCommon_TrustFlags.t.sol` (new); edit TokenTransfer/Permit2 |
| **Out of scope** | Product proxy adversarial |
| **Depends on** | WP-I-COMMON-001 |
| **Parallelizable with** | product J WPs |
| **Suggested worktree** | `gap_cover_i-common-tests` or same as 001 |
| **Implementation notes** | `test_I1_*`, `test_I2_*`, `test_I3_*` naming |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_I' -vv` |
| **Anti-theater** | I1 zero transfer; I2 short delivery; I3 residual reuse |
| **Wave** | **0–1** |

### 3. WP-I-DETF-MV-001 — MultiVault delta-safe `_pullToken` + burn pretransfer

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-MV-001` |
| **Title** | Fix MultiVaultWeightedDetf pretransfer pull/burn free credit |
| **Severity** | **Blocker** |
| **Class** | CODE |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | TCA-DETF-MV-001, TCA-DETF-MV-002 |
| **Problem** | Package `_pullToken` returns amount when pretransferred without balance/delta; burn path may extract diamond inventory. |
| **Production files** | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol`; ExchangeIn/Out/Bonding Targets as needed |
| **Test files** | `test/.../multi-vault-weighted/adversarial/` new I files |
| **Out of scope** | A–H rewrite |
| **Depends on** | Prefer after WP-I-COMMON-001 semantics freeze (clone pattern) |
| **Parallelizable with** | other product CODE after API freeze |
| **Suggested worktree** | `gap_cover_i-detf-mv` |
| **Implementation notes** | Gold TestBase_MultiVaultWeightedDetf; registry deploy; DETF role names |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' --match-test 'test_I' -vv` |
| **Anti-theater** | I1 no transfer; proxy calls; no mock SE |
| **Wave** | **1** |

### 4. WP-I-SE-AC-001 — SE I1–I3 on Aero/Camelot/UniV2

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-SE-AC-001` |
| **Title** | SE I1–I3 adversarial proving no free extract via pretransfer |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Aerodrome, Camelot, Uni V2 Standard Exchange |
| **Finding IDs** | TCA-SE-AC-002, TCA-SE-AC-003 |
| **Problem** | Happy pretransfer tests only; no free-mint adversarial on SE money paths. |
| **Production files** | none if commons fixed; else blocked |
| **Test files** | `test/foundry/spec/vaults/standard-exchange/adversarial/**`; protocol SE adversarial |
| **Out of scope** | Uni V3/V4 SE (other area) |
| **Depends on** | WP-I-COMMON-001 |
| **Parallelizable with** | WP-I-DETF-MV-002, WP-J-SE-AC-001 |
| **Suggested worktree** | `gap_cover_i-se-ac` |
| **Implementation notes** | Copy Lido/Rocket `test_A0_pretransferred_noDelta` pattern |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/standard-exchange/adversarial/**' --match-test 'test_I' -vv` |
| **Anti-theater** | No real transfer in I1; production vault via manager registry |
| **Wave** | **1** |

### 5. WP-J-DETF-MV-001 — MultiVault J1–J3 proxy surface

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-DETF-MV-001` |
| **Title** | MultiVault Target-derived facet controls + loupe + proxy smoke |
| **Severity** | High |
| **Class** | TEST |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | TCA-DETF-MV-004 |
| **Problem** | Declaration tests use facet `new` without proxy J1–J3 proof. |
| **Production files** | only if PAT-J-OMIT CODE found |
| **Test files** | multi-vault-weighted IFacet/proxy surface tests |
| **Out of scope** | A–H rewrite |
| **Depends on** | none |
| **Parallelizable with** | WP-I-DETF-MV-002 |
| **Suggested worktree** | `gap_cover_j-detf-mv` |
| **Implementation notes** | controlFacetFuncs from Target API; J3 call on diamond |
| **Acceptance** | `forge test --match-path 'test/.../multi-vault-weighted/**' --match-test 'test_J' -vv` |
| **Anti-theater** | J3 must call **proxy**, not facet impl address |
| **Wave** | **1** |

### 6. WP-I-CLONE-001 — Align clone pull helpers

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-CLONE-001` |
| **Title** | Delta-pretransfer for local `_secureTokenTransfer` / `_pullToken` clones |
| **Severity** | High |
| **Class** | CODE |
| **Products** | Uni V3/V4 SE, Slipstream, ComposedStable, UniV4 DETFs, RebasingDETFToken, MixedBuffer, Single SE DETF commons |
| **Finding IDs** | TCA-COMMON-004 |
| **Problem** | Independent absolute/blind pretransfer copies remain after BasicVaultCommon fix. |
| **Production files** | clone paths listed in T-basic-protocol-commons §2.3.B |
| **Test files** | product adversarial after CODE |
| **Out of scope** | BasicVaultCommon; already-correct ERC4626/Rocket |
| **Depends on** | WP-I-COMMON-001 |
| **Parallelizable with** | per-package after freeze |
| **Suggested worktree** | `gap_cover_i-clones` |
| **Implementation notes** | Prefer shared SecurePullLib if inheritance awkward |
| **Acceptance** | Per-product I1 green; reduce blind `return amount` patterns |
| **Anti-theater** | Proxy I1 for diamond products |
| **Wave** | **0–1** |

### 7. WP-ADV-SE-AC-001 — Expand SE adversarial + Uni V2 instance

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-ADV-SE-AC-001` |
| **Title** | Shared SE adversarial harness + UniV2SE_Adversarial |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Aerodrome, Camelot, Uni V2 SE |
| **Finding IDs** | TCA-SE-AC-005, TCA-SE-AC-006 |
| **Problem** | Uni V2 lacks adversarial; shared harness empty; Aero/Camelot A1/E5/F1/H3 only |
| **Production files** | none |
| **Test files** | `test/foundry/spec/vaults/standard-exchange/adversarial/**` |
| **Out of scope** | I suite (WP-I-SE-AC-001) |
| **Depends on** | none for classic A–H; I after commons |
| **Parallelizable with** | WP-J-SE-AC-001 |
| **Suggested worktree** | `gap_cover_adv-se-ac` |
| **Implementation notes** | Exact selectors; production TestBases |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/standard-exchange/adversarial/**' -vv` |
| **Anti-theater** | No mock SUT; exact selectors not bare expectRevert |
| **Wave** | **2** |

### 8. WP-J-SE-AC-001 — SE facet + proxy J1–J3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-SE-AC-001` |
| **Title** | Aero/Camelot/UniV2 Facet Behavior + proxy J suite |
| **Severity** | High |
| **Class** | TEST (+ CODE if OMIT) |
| **Products** | Aerodrome, Camelot, Uni V2 SE |
| **Finding IDs** | TCA-SE-AC-004 |
| **Problem** | Missing formal J declaration/proxy proof |
| **Production files** | facetFuncs only if OMIT |
| **Test files** | `*_IFacet.t.sol` + proxy smoke |
| **Out of scope** | Uni V4 SE |
| **Depends on** | none |
| **Parallelizable with** | WP-ADV-SE-AC-001 |
| **Suggested worktree** | `gap_cover_j-se-ac` |
| **Implementation notes** | Target-derived controls; loupe on proxy |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/protocol/dexes/**/*IFacet*' -vv` for SE packages |
| **Anti-theater** | J3 proxy not facet address |
| **Wave** | **1–2** |

### 9. WP-I-DETF-MV-002 — MultiVault I1–I3 tests

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-MV-002` |
| **Title** | MultiVault I1–I3 (+ bond pretransfer) adversarial |
| **Severity** | High |
| **Class** | TEST |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | TCA-DETF-MV-003 |
| **Problem** | No I catalog tests on gold suite |
| **Production files** | none if 001 landed |
| **Test files** | `adversarial/Adversarial_TrustFlags.t.sol` (new) |
| **Out of scope** | A–H rewrite |
| **Depends on** | WP-I-DETF-MV-001 |
| **Parallelizable with** | WP-J-DETF-MV-001 |
| **Suggested worktree** | `gap_cover_i-detf-mv-tests` or same as 001 |
| **Implementation notes** | Extend gold adversarial; DETF roles |
| **Acceptance** | `forge test --match-path 'test/.../multi-vault-weighted/adversarial/**' --match-test 'test_I' -vv` |
| **Anti-theater** | I1 no transfer of rateAsset/pairToken |
| **Wave** | **1** |

### 10. WP-I-CLAIM-001 — Claim foreign-token pretransfer

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-CLAIM-001` |
| **Title** | Complete L-CLAIM-3 on RebasingClaimToken foreign-token path |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | RebasingClaimToken, RebasingDETFToken |
| **Finding IDs** | TCA-COMMON-005, TCA-DETF-SVS-003 |
| **Problem** | Foreign token absolute credit residual |
| **Production files** | `RebasingClaimTokenTarget.sol`; `RebasingDETFTokenTarget.sol` |
| **Test files** | claim / SAF trust-flag tests |
| **Out of scope** | Bond NFT D-catalog |
| **Depends on** | L-CLAIM-3 product law (locked) |
| **Parallelizable with** | WP-I-COMMON-002 |
| **Suggested worktree** | `gap_cover_i-claim` |
| **Implementation notes** | Mirror self-path last balance |
| **Acceptance** | `test_I1_*` / `test_I2_*` on claim proxy |
| **Anti-theater** | Proxy not facet-only |
| **Wave** | **1** |

## Wave sketch (Stage 2 input)

| Wave | Contents |
|------|----------|
| **0** | WP-I-COMMON-001, WP-I-COMMON-002, start WP-I-CLONE-001 |
| **1** | Product Blocker/High I+J (MV, SE, claim) parallel by package |
| **2** | Remaining A–H ports, SE adversarial expand, K1, theater kill |
| **3** | L1/L3 property layer on products missing it |
| **4** | P2 / optional BasicVault surface / stub retirement |

## Clustered Mediums (pilot)

- Exact-selector hygiene on SE E5/H3 bare expectRevert
- Camelot full route H matrix
- K residual after I fix (WP-K-COMMON-001 Medium)
- MultiVault bare expectRevert N hygiene

*Full-pass areas append additional Blocker/High WPs below this line after F1/F2.*

---

## Full-pass Blocker/High WPs (appended after F1+F2)

### 11. WP-I-DETF-SSE-001 — Single SE DETF Balancer pull/burn delta

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-SSE-001` |
| **Title** | Fix SingleStandardExchangeDETF `_pullToken` + burn pretransfer free credit |
| **Severity** | Blocker |
| **Class** | CODE |
| **Products** | SingleStandardExchangeDETF (Balancer V3) |
| **Finding IDs** | TCA-DETF-SSE-001, TCA-DETF-SSE-002 |
| **Problem** | Package-local `_pullToken` returns amount when pretransferred; burn may extract diamond inventory without delta proof. |
| **Production files (touch set)** | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**` Common + In/Out Targets |
| **Test files (touch set)** | `test/**/standardExchange/single/adversarial/**` I suite |
| **Out of scope files** | MultiVault (separate WP); Uni V4 packages |
| **Depends on** | Prefer after WP-I-COMMON-001 semantics freeze |
| **Parallelizable with** | WP-I-DETF-MV-001 (different files) |
| **Suggested worktree** | `gap_cover_i-detf-sse` |
| **Implementation notes** | Mirror MultiVault fix; gold TestBase_SingleStandardExchangeDETF; registry deploy |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**' --match-test 'test_I' -vv` |
| **Anti-theater checks** | I1 no transfer; proxy calls; no MockStandardExchange |
| **Wave** | **1** |

### 12. WP-I-DETF-SSE-CP-001 — Uni V4 CP Single SE DETF PAT-I-ABS

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-SSE-CP-001` |
| **Title** | Fix Uni V4 CP Single SE DETF pretransfer pull/burn + I suite |
| **Severity** | Blocker |
| **Class** | BOTH |
| **Products** | UniswapV4SingleStandardExchangeDETF constantProduct/single |
| **Finding IDs** | TCA-DETF-SSE-003, TCA-DETF-SSE-008 (CODE+TEST) |
| **Problem** | Same PAT-I-ABS class as Balancer Single SE on Uni V4 CP package. |
| **Production files** | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**` |
| **Test files** | matching test tree + adversarial if missing |
| **Out of scope** | Legacy single path (WP-I-DETF-SSE-UV4-001) |
| **Depends on** | WP-I-COMMON-001 semantics |
| **Parallelizable with** | WP-I-DETF-SSE-001 |
| **Suggested worktree** | `gap_cover_i-detf-sse-cp` |
| **Implementation notes** | DETF roles; production-first deploy |
| **Acceptance** | `forge test --match-path 'test/**/uniswap/v4/**/constantProduct/single/**' --match-test 'test_I' -vv` |
| **Anti-theater** | Proxy I1 |
| **Wave** | **1** |

### 13. WP-I-DETF-SSE-UV4-001 — Legacy Uni V4 Single SE absolute pretransfer

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-SSE-UV4-001` |
| **Title** | Fix legacy Uni V4 Single SE absolute-balance pretransfer |
| **Severity** | Blocker |
| **Class** | CODE |
| **Products** | UniswapV4SingleStandardExchangeDETF legacy single |
| **Finding IDs** | TCA-DETF-SSE-004 |
| **Problem** | Absolute balance pretransfer free credit on scaffold-maturity package. |
| **Production files** | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/**` |
| **Test files** | expand beyond T01/T02 after CODE |
| **Out of scope** | CP package |
| **Depends on** | WP-I-COMMON-001 semantics |
| **Parallelizable with** | WP-I-DETF-SSE-CP-001 |
| **Suggested worktree** | `gap_cover_i-detf-sse-uv4` |
| **Implementation notes** | Product immature — still ship-blocking if deployable |
| **Acceptance** | I1 hermetic on gold TestBase when present |
| **Anti-theater** | No happy-only pretransfer |
| **Wave** | **1** |

### 14. WP-I-DETF-CS-001 — ComposedStable + Rebasing blind pretransfer

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-CS-001` |
| **Title** | Delta-safe ComposedStableCommon + RebasingDETFToken pretransfer |
| **Severity** | Blocker |
| **Class** | CODE |
| **Products** | ComposedStableCommonDetf, RebasingDETFToken |
| **Finding IDs** | TCA-DETF-CS-001, TCA-DETF-CS-002 |
| **Problem** | `_secureTokenTransfer` returns amount_ blind; exchangeOut may credit maxAmountIn. |
| **Production files** | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/**` |
| **Test files** | composed stable adversarial I suite |
| **Out of scope** | MixedBuffer (WP-I-DETF-MB-001) |
| **Depends on** | WP-I-COMMON-001 semantics |
| **Parallelizable with** | WP-I-DETF-MB-001 |
| **Suggested worktree** | `gap_cover_i-detf-cs` |
| **Implementation notes** | Claim paths use DETF role names |
| **Acceptance** | `forge test --match-path 'test/**/stable/common/**' --match-test 'test_I' -vv` |
| **Anti-theater** | I1 no transfer |
| **Wave** | **1** |

### 15. WP-I-DETF-MB-001 — MixedBuffer pull/burn free credit

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-MB-001` |
| **Title** | Fix MixedBufferMultiVaultStableDetf `_pullToken` + burn pretransfer |
| **Severity** | Blocker |
| **Class** | CODE |
| **Products** | MixedBufferMultiVaultStableDetf |
| **Finding IDs** | TCA-DETF-CS-003, TCA-DETF-CS-004 |
| **Problem** | Blind return amount_; burn skips transfer and burns diamond inventory. |
| **Production files** | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**` |
| **Test files** | new adversarial/ + I suite |
| **Out of scope** | ComposedStable common (WP-I-DETF-CS-001) |
| **Depends on** | WP-I-COMMON-001 semantics |
| **Parallelizable with** | WP-I-DETF-CS-001 |
| **Suggested worktree** | `gap_cover_i-detf-mb` |
| **Implementation notes** | No adversarial dir today — add with CODE |
| **Acceptance** | `forge test --match-path 'test/**/mixedBuffer/**' --match-test 'test_I' -vv` |
| **Anti-theater** | Proxy I1; no mock SUT |
| **Wave** | **1** |

### 16. WP-I-DETF-DL-001 — DualLiquidity `_receive` / `_receiveOut` delta

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-DL-001` |
| **Title** | Fix DualLiquidity pretransfer free mint/extract on `_receive` paths |
| **Severity** | Blocker |
| **Class** | CODE |
| **Products** | DualLiquidity (removed)CrossVersionUniswapVault |
| **Finding IDs** | TCA-DETF-DL-001, TCA-DETF-DL-002 |
| **Problem** | `pretransferred=true` no-op receive; absolute-held spend + surplus refund theft class. |
| **Production files** | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/**` |
| **Test files** | fork I1–I3 (WP-I-DETF-DL-002) |
| **Out of scope** | BasicVaultCommon (different package) |
| **Depends on** | none (package-local) |
| **Parallelizable with** | other Wave-1 package CODE |
| **Suggested worktree** | `gap_cover_i-detf-dl` |
| **Implementation notes** | Fork-first product — L-TCA-5; use `*_alchemy` RPC |
| **Acceptance** | `FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**/crossVersion/**' --match-test 'test_I' --fork-url base_mainnet_alchemy -vv` |
| **Anti-theater** | I1 no transfer of pairToken; real fork balances |
| **Wave** | **1** |

### 17. WP-I-CLONE-UAB-001 — Uni V4 SE + Aave Stata free credit/mint

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-CLONE-UAB-001` |
| **Title** | Fix Uni V4 SE absolute pull + Aave Stata free share mint on pretransfer |
| **Severity** | Blocker |
| **Class** | CODE |
| **Products** | UniswapV4StandardExchange; AaveV3StataStandardExchange |
| **Finding IDs** | TCA-SE-UAB-001, TCA-SE-UAB-002, TCA-SE-UAB-003 |
| **Problem** | Uni V4 local `_secureTokenTransfer` absolute claim; Aave In skips pull with no balance check then mints shares. |
| **Production files** | `contracts/protocols/dexes/uniswap/v4/**`; `contracts/protocols/lending/aave/v3.6/**` |
| **Test files** | product I1 free-mint adversarial |
| **Out of scope** | Balancer router (stronger) |
| **Depends on** | WP-I-COMMON-001 for Aave inheritance paths if any |
| **Parallelizable with** | WP-I-SE-AC-001 tests after CODE |
| **Suggested worktree** | `gap_cover_i-se-uab` |
| **Implementation notes** | Good pattern: ERC4626StandardExchangeCommon._securePull |
| **Acceptance** | `forge test --match-path 'test/**/uniswap/v4/**' --match-test 'test_I|test_FreeMint|test_A0' -vv`; Aave match-path free mint |
| **Anti-theater** | No mock Stata for free-mint proof |
| **Wave** | **1** |

### 18. WP-I-HOOK-CP-001 — Hook Single SE CP free extract

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-HOOK-CP-001` |
| **Title** | Gate hook CP pretransferred raw→pair so SE book cannot free-extract |
| **Severity** | Blocker |
| **Class** | BOTH |
| **Products** | Uniswap V4 Single SE CP buffer hook |
| **Finding IDs** | TCA-HOOK-001 |
| **Problem** | `pretransferred=true` on raw→pair unwraps SE book without free/delta gate. |
| **Production files** | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/**` (and related Target) |
| **Test files** | `test/**/hooks/**/adversarial/**` I1 |
| **Out of scope** | Dual hook (WP-I-HOOK-DUAL-001) |
| **Depends on** | none |
| **Parallelizable with** | WP-J-HOOK-001 |
| **Suggested worktree** | `gap_cover_i-hook-cp` |
| **Implementation notes** | indexedex-uniswap-v4-hook-packages skill; deployHookVault path |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/hooks/**' --match-test 'test_I1|test_A0' -vv` |
| **Anti-theater** | I1 must not fund SE book; proxy hook address |
| **Wave** | **1** |

### 19. WP-J-MGR-001 — Fee seigniorage query PAT-J-OMIT

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-MGR-001` |
| **Title** | Fix seigniorage vault fee-type query wiring + proxy test |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | VaultFeeOracle / manager fee query surface |
| **Finding IDs** | TCA-MGR-001 |
| **Problem** | Target typo `seeigniorageTermsTypeId`; not on interface/facetFuncs — silent missing API. |
| **Production files** | fee oracle Target/Facet/interface under `contracts/oracles/fee/**` |
| **Test files** | proxy loupe + call smoke |
| **Out of scope** | Full manager J matrix (WP-J-MGR-002) |
| **Depends on** | none |
| **Parallelizable with** | WP-J-MGR-002 |
| **Suggested worktree** | `gap_cover_j-mgr-seigniorage` |
| **Implementation notes** | Fix spelling + cut selectors + interface |
| **Acceptance** | `forge test --match-path 'test/**/fee/**' --match-test 'test_J|seigniorage' -vv` |
| **Anti-theater** | Call on **proxy**, not facet impl |
| **Wave** | **1** |

### 20. WP-I5-RTR-001 — Coordinator Permit2 security suite

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I5-RTR-001` |
| **Title** | Permit2 replay / wrong spender / token mismatch / I5 suite |
| **Severity** | High |
| **Class** | TEST |
| **Products** | BalancerV3UniswapV4CoordinatorRouter |
| **Finding IDs** | TCA-RTR-001 |
| **Problem** | Strong H/P but missing P0 Permit2 abuse matrix. |
| **Production files** | none expected |
| **Test files** | `test/foundry/spec/routers/balancerV3-uniswapV4/**` |
| **Out of scope** | SE vault I suites |
| **Depends on** | none |
| **Parallelizable with** | WP-J-RTR-001, WP-N-RTR-001 |
| **Suggested worktree** | `gap_cover_i5-rtr` |
| **Implementation notes** | Production Permit2; exact fail selectors |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/routers/balancerV3-uniswapV4/**' --match-test 'test_I5|replay|spender' -vv` |
| **Anti-theater** | Exact selectors; no bare expectRevert |
| **Wave** | **2** |

### 21. WP-J-HOOK-001 — Hooks facet + proxy J matrix

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-HOOK-001` |
| **Title** | Hook Target ⊆ facetFuncs ⊆ loupe ⊆ proxy callable |
| **Severity** | High |
| **Class** | TEST (+ CODE if OMIT) |
| **Products** | Uni V4 hook packages |
| **Finding IDs** | TCA-HOOK-005 |
| **Problem** | Area-wide J fail/partial |
| **Production files** | only if selectors missing |
| **Test files** | hook IFacet + proxy smoke |
| **Out of scope** | SE vault J |
| **Depends on** | none |
| **Parallelizable with** | WP-I-HOOK-CP-001 |
| **Suggested worktree** | `gap_cover_j-hooks` |
| **Implementation notes** | deployHookVault / factory loupe |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/hooks/**' --match-test 'test_J|IFacet' -vv` |
| **Anti-theater** | J3 proxy not facet address |
| **Wave** | **1–2** |

### 22. WP-J-MGR-002 — Manager/registry/oracle full J matrix

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-MGR-002` |
| **Title** | Full facet declaration + proxy J for manager/registry/oracle |
| **Severity** | High |
| **Class** | TEST |
| **Products** | IndexedexManager, VaultRegistry, VaultFeeOracle |
| **Finding IDs** | TCA-MGR-002 |
| **Problem** | Almost no `*_IFacet` / J1–J3 beyond FeeCollectorManager |
| **Production files** | none unless OMIT |
| **Test files** | new IFacet tests under test/foundry/spec/manager|registries|fee|oracles |
| **Out of scope** | WP-J-MGR-001 seigniorage CODE |
| **Depends on** | none |
| **Parallelizable with** | WP-N-FEE-001 |
| **Suggested worktree** | `gap_cover_j-mgr` |
| **Implementation notes** | controlFacetFuncs from Target |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/**/*Manager*IFacet*' -vv` expand |
| **Anti-theater** | Proxy smoke |
| **Wave** | **2** |

### 23. WP-N-FEE-001 — FeeCollector money-out proof

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-N-FEE-001` |
| **Title** | FeeCollector pullFee ACL + real balances; pushSingleTokenFee |
| **Severity** | High |
| **Class** | TEST |
| **Products** | FeeCollector |
| **Finding IDs** | TCA-MGR-003 |
| **Problem** | Money-out under-tested; mock theater risk |
| **Production files** | none |
| **Test files** | fee collector specs |
| **Out of scope** | fee oracle math (strong) |
| **Depends on** | none |
| **Parallelizable with** | WP-J-MGR-002 |
| **Suggested worktree** | `gap_cover_n-fee` |
| **Implementation notes** | Real token balances; exact ACL selectors |
| **Acceptance** | `forge test --match-path 'test/**/fee/collector/**' -vv` |
| **Anti-theater** | No mock fee token accounting as sole proof |
| **Wave** | **2** |

## Ranking note

Composite order remains: **Wave-0 commons** first, then **product Blocker CODE** by blast radius (SE inheritors / DETF clones / Dual / Hooks / Aave free mint), then **High TEST** J/I5/N packages in parallel.


---

## High WPs promoted from area stubs (full §8) — complete Blocker/High coverage

> Every Blocker/High finding ID appears in **Finding IDs** of at least one WP below or above.
> Mediums remain clustered / optional.

### 24. WP-I-DETF-SSE-002 — Balancer Single SE I1–I3 + K1 tests

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-SSE-002` |
| **Title** | Add Balancer Single SE adversarial I1–I3 (+ bond + burn) and K1 |
| **Severity** | High |
| **Class** | TEST |
| **Products** | SingleStandardExchangeDETF |
| **Finding IDs** | TCA-DETF-SSE-005, TCA-DETF-SSE-007 |
| **Problem** | Catalog I P0 absent; K1 pretransfer unproven after CODE fix. |
| **Production files (touch set)** | none (after WP-I-DETF-SSE-001) |
| **Test files (touch set)** | `test/**/standardExchange/single/adversarial/Adversarial_TrustFlag.t.sol` (new) or extend P0 |
| **Out of scope files** | Uni V4 packages; MultiVault |
| **Depends on** | WP-I-DETF-SSE-001 |
| **Parallelizable with** | WP-J-DETF-SSE-001 |
| **Suggested worktree** | `gap_cover_i-detf-sse-tests` |
| **Implementation notes** | Copy MultiVault I patterns; exact selectors; DETF role names |
| **Acceptance** | `forge test --match-path 'test/**/standardExchange/single/adversarial/**' --match-test 'test_I' -vv` |
| **Anti-theater checks** | I1 no transfer; I2 short; I3 residual reuse; no mock SE |
| **Wave** | **1** |

### 25. WP-J-DETF-SSE-001 — Balancer Single SE J1–J3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-DETF-SSE-001` |
| **Title** | Balancer Single SE J1–J3 surface suite on production proxy |
| **Severity** | High |
| **Class** | TEST |
| **Products** | SingleStandardExchangeDETF |
| **Finding IDs** | TCA-DETF-SSE-006 |
| **Problem** | No declaration suite; no loupe/proxy catalog proof. |
| **Production files (touch set)** | only if PAT-J-OMIT found |
| **Test files (touch set)** | `*_IFacet.t.sol` + `Adversarial_Surface.t.sol` under single/ |
| **Out of scope files** | A–H rewrite; I suite |
| **Depends on** | none |
| **Parallelizable with** | WP-I-DETF-SSE-001 |
| **Suggested worktree** | `gap_cover_j-detf-sse` |
| **Implementation notes** | Target-derived controls; J3 on proxy after registry deploy |
| **Acceptance** | `forge test --match-path 'test/**/standardExchange/single/**' --match-test 'test_J' -vv` |
| **Anti-theater checks** | J3 proxy not facet impl address |
| **Wave** | **1** |

### 26. WP-J-DETF-SSE-CP-001 — Uni V4 CP Single SE J1–J3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-DETF-SSE-CP-001` |
| **Title** | Uni V4 CP Single SE J1–J3 surface suite |
| **Severity** | High |
| **Class** | TEST |
| **Products** | UniswapV4SingleStandardExchangeDETF (CP) |
| **Finding IDs** | TCA-DETF-SSE-009 |
| **Problem** | No J proof on CP facet/proxy. |
| **Production files (touch set)** | only if OMIT |
| **Test files (touch set)** | CP package IFacet + proxy smoke |
| **Out of scope files** | Balancer Single SE |
| **Depends on** | none |
| **Parallelizable with** | WP-I-DETF-SSE-CP-001 |
| **Suggested worktree** | `gap_cover_j-detf-sse-cp` |
| **Implementation notes** | J3 on proxy |
| **Acceptance** | `test_J1_*`…`test_J3_*` on CP proxy |
| **Anti-theater checks** | J3 on proxy not facet impl |
| **Wave** | **1** |

### 27. WP-I-DETF-CS-002 — ComposedStable I1–I3 + K1 tests

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-CS-002` |
| **Title** | ComposedStable + claim adversarial I1–I3 (+ K1) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | ComposedStableCommonDetf; RebasingDETFToken |
| **Finding IDs** | TCA-DETF-CS-005, TCA-DETF-CS-009 |
| **Problem** | Catalog I P0 and K1 pretransfer linkage absent. |
| **Production files (touch set)** | none after CODE |
| **Test files (touch set)** | extend `Adversarial_ComposedStable_P0.t.sol` or TrustFlag suite |
| **Out of scope files** | MixedBuffer (WP-ADV-DETF-MB-001) |
| **Depends on** | WP-I-DETF-CS-001 |
| **Parallelizable with** | WP-J-DETF-CS-MB-001 |
| **Suggested worktree** | `gap_cover_i-detf-cs-tests` |
| **Implementation notes** | Gold MultiVault I patterns; claim foreign-token path |
| **Acceptance** | `test_I1_*`, `test_I2_*`, `test_I3_*`, `test_K1_*` green on production graph |
| **Anti-theater checks** | I1 no transfer; I2 short; I3 second call without new funds |
| **Wave** | **1** |

### 28. WP-ADV-DETF-MB-001 — MixedBuffer adversarial A–H + I + claim

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-ADV-DETF-MB-001` |
| **Title** | MixedBuffer adversarial A–H P0 + I1–I3 + claim D/H |
| **Severity** | High |
| **Class** | TEST |
| **Products** | MixedBufferMultiVaultStableDetf |
| **Finding IDs** | TCA-DETF-CS-006, TCA-DETF-CS-008, TCA-DETF-CS-011 |
| **Problem** | No adversarial dir; I/K/claim thin. |
| **Production files (touch set)** | none after WP-I-DETF-MB-001 |
| **Test files (touch set)** | `test/**/mixedBuffer/adversarial/*.t.sol` (new) |
| **Out of scope files** | ComposedStable rewrite |
| **Depends on** | WP-I-DETF-MB-001 for I cases |
| **Parallelizable with** | WP-J-DETF-CS-MB-001 |
| **Suggested worktree** | `gap_cover_adv-detf-mb` |
| **Implementation notes** | Catalog-labeled A1,A3,D2,D3,E1,E5,F,H2,H3,I1–I3,K1 |
| **Acceptance** | `forge test --match-path 'test/**/mixedBuffer/adversarial/**' -vv` |
| **Anti-theater checks** | No mock SUT; exact selectors; I1 no transfer |
| **Wave** | **2** |

### 29. WP-J-DETF-CS-MB-001 — ComposedStable + MixedBuffer J1–J3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-DETF-CS-MB-001` |
| **Title** | J1–J3 surface suite CS multi-facet + MB combined facet on proxy |
| **Severity** | High |
| **Class** | TEST |
| **Products** | ComposedStableCommonDetf; MixedBufferMultiVaultStableDetf |
| **Finding IDs** | TCA-DETF-CS-007 |
| **Problem** | Declaration theater / missing J1–J3 on both products. |
| **Production files (touch set)** | only if PAT-J-OMIT |
| **Test files (touch set)** | IFacet + proxy surface under stable/ + mixedBuffer/ |
| **Out of scope files** | I suites |
| **Depends on** | none |
| **Parallelizable with** | WP-I-DETF-CS-001, WP-I-DETF-MB-001 |
| **Suggested worktree** | `gap_cover_j-detf-cs-mb` |
| **Implementation notes** | Target-derived controls; loupe non-zero |
| **Acceptance** | `test_J1_*`, `test_J2_*`, `test_J3_*` green |
| **Anti-theater checks** | J3 proxy not facet address |
| **Wave** | **1** |

### 30. WP-G-E-DETF-CS-001 — ComposedStable nested G + multi-leg residual

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-G-E-DETF-CS-001` |
| **Title** | ComposedStable nested G1 + production multi-leg residual E2 |
| **Severity** | High |
| **Class** | TEST |
| **Products** | ComposedStableCommonDetf |
| **Finding IDs** | TCA-DETF-CS-010 |
| **Problem** | G nested outer gap; multi-leg residual incomplete as adversarial E2. |
| **Production files (touch set)** | none |
| **Test files (touch set)** | composed stable adversarial / residual sequences |
| **Out of scope files** | MixedBuffer G (partial elsewhere) |
| **Depends on** | none for residual; nested may need product-law confirm |
| **Parallelizable with** | WP-I-DETF-CS-002 |
| **Suggested worktree** | `gap_cover_g-e-detf-cs` |
| **Implementation notes** | Production-graph residual asserts; DETF roles |
| **Acceptance** | residual asserts on free vaultShare/BPT/pairToken dust; G1 if applicable |
| **Anti-theater checks** | Real multi-route ops not pure unit math |
| **Wave** | **2** |

### 31. WP-I-DETF-DL-002 — DualLiquidity fork I1–I3 + K1

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-DETF-DL-002` |
| **Title** | DualLiquidity fork adversarial I1–I3 + K1 (pretransfer) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | DualLiquidity (removed)CrossVersionUniswapVault |
| **Finding IDs** | TCA-DETF-DL-003, TCA-DETF-DL-005 |
| **Problem** | Catalog I/K P0 absent; happy pretransfer theater; ShareInflation ≠ I/K. |
| **Production files (touch set)** | none after WP-I-DETF-DL-001 |
| **Test files (touch set)** | fork `adversarial/Adversarial_TrustFlag.t.sol` |
| **Out of scope files** | ShareInflation rewrite (keep A3) |
| **Depends on** | WP-I-DETF-DL-001 |
| **Parallelizable with** | WP-J-DETF-DL-001 after CODE |
| **Suggested worktree** | `gap_cover_i-detf-dl-tests` |
| **Implementation notes** | L-TCA-5 fork priority; `*_alchemy` RPC; donate pairToken then pretransfer |
| **Acceptance** | `FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**/crossVersion/**/adversarial/**' --match-test 'test_I|test_K1' --fork-url base_mainnet_alchemy -vv` |
| **Anti-theater checks** | I1 no attacker transfer; never count ShareInflation as I |
| **Wave** | **1** |

### 32. WP-J-DETF-DL-001 — DualLiquidity J1–J3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-DETF-DL-001` |
| **Title** | DualLiquidity J1–J3 surface suite on production proxy |
| **Severity** | High |
| **Class** | TEST |
| **Products** | DualLiquidity (removed)CrossVersionUniswapVault |
| **Finding IDs** | TCA-DETF-DL-004 |
| **Problem** | No Target-derived J suite; loupe only partial. |
| **Production files (touch set)** | only if OMIT |
| **Test files (touch set)** | `adversarial/Adversarial_Surface.t.sol` |
| **Out of scope files** | I suite |
| **Depends on** | none |
| **Parallelizable with** | WP-I-DETF-DL-001 |
| **Suggested worktree** | `gap_cover_j-detf-dl` |
| **Implementation notes** | Controls from IStandardExchangeIn/Out; J3 on proxy |
| **Acceptance** | `test_J1_*`, `test_J2_*`, `test_J3_*` green |
| **Anti-theater checks** | Never assert only on facet implementation address |
| **Wave** | **1** |

### 33. WP-K-DETF-MV-001 — MultiVault K1 donation→pretransfer

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-K-DETF-MV-001` |
| **Title** | MultiVault K1 donation + pretransfer credit regression |
| **Severity** | High |
| **Class** | TEST |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | TCA-DETF-MV-005 |
| **Problem** | K1 incomplete once I path considered. |
| **Production files (touch set)** | none after I CODE |
| **Test files (touch set)** | adversarial TrustFlag / Donation |
| **Out of scope files** | A–H rewrite |
| **Depends on** | WP-I-DETF-MV-001 |
| **Parallelizable with** | WP-I-DETF-MV-002 (merge preferred) |
| **Suggested worktree** | merge `gap_cover_i-detf-mv-tests` |
| **Implementation notes** | donate then pretransfer claim |
| **Acceptance** | `test_K1_*` or I1 alias with donate setup |
| **Anti-theater checks** | Must use `pretransferred=true` after donate |
| **Wave** | **1** |

### 34. WP-I-HOOK-DUAL-001 — Dual hook free-pretransfer gate + I

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-HOOK-DUAL-001` |
| **Title** | Dual free-pretransfer gate + I suite |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Dual SE BCP Hook |
| **Finding IDs** | TCA-HOOK-002, TCA-HOOK-003 (Dual portion), TCA-HOOK-006 |
| **Problem** | Dual SE API has flag without free gate or I proofs; adversarial vacuum. |
| **Production files (touch set)** | `contracts/hooks/uniswap/v4/standardExchange/dual/**` Target |
| **Test files (touch set)** | new Dual SE adversarial / Pretransfer suite |
| **Out of scope files** | CP Single CODE (WP-I-HOOK-CP-001); pure AMM |
| **Depends on** | none |
| **Parallelizable with** | WP-I-HOOK-CP-001, WP-I-HOOK-SEBUF-001 |
| **Suggested worktree** | `gap_cover_i-hook-dual` |
| **Implementation notes** | Free gate + I1–I3; exact selectors |
| **Acceptance** | unfunded pretransfer typed revert; funded free path proven; residual I3 |
| **Anti-theater checks** | no happy-only pretransfer |
| **Wave** | **1** |

### 35. WP-I-HOOK-SEBUF-001 — SE buffer free-only I1–I3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-HOOK-SEBUF-001` |
| **Title** | SE buffer free-only I1–I3 (Orbital, Weighted, Bal, Curve) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | SE Orbital / Weighted / Bal Quad / Curve Quad buffers |
| **Finding IDs** | TCA-HOOK-003, TCA-HOOK-004, TCA-HOOK-007, TCA-HOOK-009 |
| **Problem** | Partial or missing I proofs; residual reuse unproven; Weighted SE pretransfer untested. |
| **Production files (touch set)** | only if free gate bug found |
| **Test files (touch set)** | existing `*_Adversarial.t.sol` per product |
| **Out of scope files** | Dual CODE (WP-I-HOOK-DUAL-001); CP free extract CODE |
| **Depends on** | none (gates present except gaps) |
| **Parallelizable with** | CP/Dual CODE WPs, WP-J-HOOK-001 |
| **Suggested worktree** | `gap_cover_i-hook-sebuf` |
| **Implementation notes** | Each product: I1 unfunded, I2 short free, I3 residual |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/hooks/**' --match-test 'test_I' -vv` |
| **Anti-theater checks** | funded path not counted as I1 |
| **Wave** | **1** |

### 36. WP-ADV-HOOK-001 — Dual + pure AMM adversarial ports

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-ADV-HOOK-001` |
| **Title** | Dual + pure AMM adversarial catalog ports |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Dual; Orbital/Weighted/Quad pure AMM |
| **Finding IDs** | TCA-HOOK-006, TCA-HOOK-008 |
| **Problem** | Catalog holes vs single-buffer gold. |
| **Production files (touch set)** | none |
| **Test files (touch set)** | hook adversarial suites |
| **Out of scope files** | I CODE gates |
| **Depends on** | WP-I-HOOK-DUAL-001 for Dual I cases (or include there) |
| **Parallelizable with** | WP-J-HOOK-001 |
| **Suggested worktree** | `gap_cover_adv-hook` |
| **Implementation notes** | A1 donation, C reentrancy, F1 cut, H minOut with exact selectors |
| **Acceptance** | named catalog tests green on production hooks |
| **Anti-theater checks** | exact selectors not bare expectRevert |
| **Wave** | **2** |

### 37. WP-H-CAM-001 — Camelot H matrix + Route4 K1

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-H-CAM-001` |
| **Title** | Camelot route H matrix + Route4 K1 donation parity |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Camelot V2 SE |
| **Finding IDs** | TCA-SE-AC-007 |
| **Problem** | Camelot lacks Aero-class happy/negative/donation coverage. |
| **Production files (touch set)** | none |
| **Test files (touch set)** | `test/foundry/spec/protocol/dexes/camelot/v2/**` |
| **Out of scope files** | DFPkg deploy (already strong) |
| **Depends on** | none |
| **Parallelizable with** | WP-J-SE-AC-001, WP-ADV-SE-AC-001 |
| **Suggested worktree** | `gap_cover_h-cam` |
| **Implementation notes** | Route1 + Route4 execVsPreview + donation mismatch |
| **Acceptance** | route matrix green; exact `ERC4626TransferNotReceived` where applicable |
| **Anti-theater checks** | No mock SUT |
| **Wave** | **2** |

### 38. WP-E5-AERO-001 — Aerodrome vault-level deadline

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-E5-AERO-001` |
| **Title** | Aerodrome vault-level deadline + E5 tests |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Aerodrome V1 SE |
| **Finding IDs** | TCA-SE-AC-008 |
| **Problem** | Missing vault-level deadline guard on some routes. |
| **Production files (touch set)** | `AerodromeStandardExchangeInTarget.sol`, `...OutTarget.sol` |
| **Test files (touch set)** | adversarial or route negatives |
| **Out of scope files** | Camelot/UniV2 |
| **Depends on** | none |
| **Parallelizable with** | WP-J-SE-AC-001 |
| **Suggested worktree** | `gap_cover_e5-aero` |
| **Implementation notes** | DeadlineExceeded on expired deadline |
| **Acceptance** | exact selector tests for deposit-only and swap routes |
| **Anti-theater checks** | Exact selector not bare expectRevert |
| **Wave** | **1** |

### 39. WP-I-SE-UAB-001 — Uni V4 + Aave + CrossVersion I1–I3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-SE-UAB-001` |
| **Title** | I1–I3 proofs Uni V4 + Aave Stata (+ CrossVersion) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Uni V4 SE, Aave Stata SE, CrossVersion Loop |
| **Finding IDs** | TCA-SE-UAB-004, TCA-SE-UAB-005, TCA-SE-UAB-009 |
| **Problem** | No false-claim / short / residual-reuse coverage; theater happy pretransfer only; K1 linkage. |
| **Production files (touch set)** | none after WP-I-CLONE-UAB-001 |
| **Test files (touch set)** | new adversarial under uniswap/v4 and aave paths |
| **Out of scope files** | Balancer router I5 (strong) |
| **Depends on** | WP-I-CLONE-UAB-001 for green |
| **Parallelizable with** | WP-J-SE-UAB-001 |
| **Suggested worktree** | `gap_cover_i-se-uab` |
| **Implementation notes** | I1 no transfer; I2 short; I3 residual; K1 donate+pretransfer |
| **Acceptance** | `forge test --match-path 'test/**/adversarial/**' --match-test 'test_I|test_K1' -vv` for UAB products |
| **Anti-theater checks** | I1 no transfer; funded happy path not I coverage |
| **Wave** | **1** |

### 40. WP-ADV-SE-UAB-001 — Uni V4 + Aave SE adversarial catalog

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-ADV-SE-UAB-001` |
| **Title** | Uni V4 + Aave Stata SE adversarial catalog (A1/C/E5/H3/F + K1) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Uni V4 SE, Aave Stata SE |
| **Finding IDs** | TCA-SE-UAB-007, TCA-SE-UAB-008 |
| **Problem** | No SE adversarial suites; Aave mockCall theater risk. |
| **Production files (touch set)** | none |
| **Test files (touch set)** | production-proxy adversarial (retire mock-only as coverage) |
| **Out of scope files** | Balancer buffer gold |
| **Depends on** | none for A/E/H/F; I depends WP-I-SE-UAB-001 |
| **Parallelizable with** | WP-J-SE-UAB-001 |
| **Suggested worktree** | `gap_cover_adv-se-uab` |
| **Implementation notes** | Named catalog tests; typed reverts; no mock SUT for money paths |
| **Acceptance** | adversarial suites green without mockCall-on-SUT |
| **Anti-theater checks** | PAT-MOCK not counted |
| **Wave** | **2** |

### 41. WP-J-SE-UAB-001 — Aave + Uni V4 J surface

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-SE-UAB-001` |
| **Title** | Aave IFacet + Uni V4 LiquidReserve IFacet + proxy loupe J2–J3 |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Aave Stata SE; Uni V4 SE |
| **Finding IDs** | TCA-SE-UAB-006, TCA-SE-UAB-007 (J portion) |
| **Problem** | Aave J1–J3 missing; Uni V4 incomplete J. |
| **Production files (touch set)** | only if OMIT |
| **Test files (touch set)** | IFacet + proxy smoke |
| **Out of scope files** | Balancer router formal J (WP-J-ROUTER-UAB-001) |
| **Depends on** | none |
| **Parallelizable with** | WP-I-SE-UAB-001 |
| **Suggested worktree** | `gap_cover_j-se-uab` |
| **Implementation notes** | Target-derived controls; loupe non-zero |
| **Acceptance** | J1–J3 green on proxy |
| **Anti-theater checks** | J3 on proxy not facet impl |
| **Wave** | **1** |

### 42. WP-J-ROUTER-UAB-001 — Balancer SE Router formal J

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-ROUTER-UAB-001` |
| **Title** | Balancer SE Router formal facet declaration matrix |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Balancer SE routers |
| **Finding IDs** | TCA-SE-UAB-010 |
| **Problem** | Formal J declaration gap despite strong H/P. |
| **Production files (touch set)** | only if OMIT |
| **Test files (touch set)** | router IFacet / package surface |
| **Out of scope files** | Coordinator router (WP-J-RTR-001) |
| **Depends on** | none |
| **Parallelizable with** | WP-J-SE-UAB-001 |
| **Suggested worktree** | `gap_cover_j-router-uab` |
| **Implementation notes** | money selectors ⊆ facetFuncs ⊆ loupe ⊆ proxy |
| **Acceptance** | full J matrix green |
| **Anti-theater checks** | proxy calls |
| **Wave** | **2** |

### 43. WP-N-RTR-001 — Coordinator exact-selector N + theater kill

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-N-RTR-001` |
| **Title** | Exact-selector N matrix + kill bare expectRevert theater |
| **Severity** | High |
| **Class** | TEST |
| **Products** | BalancerV3UniswapV4CoordinatorRouter |
| **Finding IDs** | TCA-RTR-002 |
| **Problem** | Bare reverts on minOut/witness/access; exact-fail theater. |
| **Production files (touch set)** | none |
| **Test files (touch set)** | `test/foundry/spec/routers/balancerV3-uniswapV4/**` |
| **Out of scope files** | I5 suite (WP-I5-RTR-001) |
| **Depends on** | none |
| **Parallelizable with** | WP-I5-RTR-001, WP-J-RTR-001 |
| **Suggested worktree** | `gap_cover_n-rtr` |
| **Implementation notes** | abi.encodeWithSelector / typed errors |
| **Acceptance** | no bare expectRevert on money negatives in touched files |
| **Anti-theater checks** | exact selectors required |
| **Wave** | **2** |

### 44. WP-J-RTR-001 — Coordinator Facet + proxy J1–J3

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-J-RTR-001` |
| **Title** | Coordinator Facet declaration + loupe + proxy surface (J1–J3) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Coordinator facets + DFPkg |
| **Finding IDs** | TCA-RTR-003 |
| **Problem** | No formal Target⊆facetFuncs⊆cuts⊆loupe⊆proxy proof. |
| **Production files (touch set)** | none unless PAT-J-OMIT at implement time |
| **Test files (touch set)** | new Behavior_IFacet / package surface suite |
| **Out of scope files** | SE vault J |
| **Depends on** | none |
| **Parallelizable with** | WP-I5-RTR-001, WP-N-RTR-001 |
| **Suggested worktree** | `gap_cover_j-rtr` |
| **Implementation notes** | Crane Behavior_IFacet; controls from coordinator interface; J3 on proxy |
| **Acceptance** | J1 controls match facetFuncs; J2 loupe complete; J3 money selectors on proxy |
| **Anti-theater checks** | Must not only call facet implementation address |
| **Wave** | **1** |

---

## Finding → WP index (all Blocker/High)

| Finding ID | Severity | Primary WP-ID(s) |
|------------|----------|------------------|
| TCA-COMMON-001 | High→Blocker epic | WP-I-COMMON-001 |
| TCA-COMMON-002 | High | WP-I-COMMON-002 |
| TCA-COMMON-003 | High | WP-I-COMMON-002 |
| TCA-COMMON-004 | High | WP-I-CLONE-001 |
| TCA-COMMON-005 | High | WP-I-CLAIM-001 |
| TCA-DETF-MV-001 | Blocker | WP-I-DETF-MV-001 |
| TCA-DETF-MV-002 | Blocker | WP-I-DETF-MV-001 |
| TCA-DETF-MV-003 | High | WP-I-DETF-MV-002 |
| TCA-DETF-MV-004 | High | WP-J-DETF-MV-001 |
| TCA-DETF-MV-005 | High | WP-K-DETF-MV-001 |
| TCA-DETF-SSE-001 | Blocker | WP-I-DETF-SSE-001 |
| TCA-DETF-SSE-002 | Blocker | WP-I-DETF-SSE-001 |
| TCA-DETF-SSE-003 | Blocker | WP-I-DETF-SSE-CP-001 |
| TCA-DETF-SSE-004 | Blocker | WP-I-DETF-SSE-UV4-001 |
| TCA-DETF-SSE-005 | High | WP-I-DETF-SSE-002 |
| TCA-DETF-SSE-006 | High | WP-J-DETF-SSE-001 |
| TCA-DETF-SSE-007 | High | WP-I-DETF-SSE-002 |
| TCA-DETF-SSE-008 | High | WP-I-DETF-SSE-CP-001 |
| TCA-DETF-SSE-009 | High | WP-J-DETF-SSE-CP-001 |
| TCA-DETF-CS-001 | Blocker | WP-I-DETF-CS-001 |
| TCA-DETF-CS-002 | Blocker | WP-I-DETF-CS-001 |
| TCA-DETF-CS-003 | Blocker | WP-I-DETF-MB-001 |
| TCA-DETF-CS-004 | Blocker | WP-I-DETF-MB-001 |
| TCA-DETF-CS-005 | High | WP-I-DETF-CS-002 |
| TCA-DETF-CS-006 | High | WP-ADV-DETF-MB-001 |
| TCA-DETF-CS-007 | High | WP-J-DETF-CS-MB-001 |
| TCA-DETF-CS-008 | High | WP-ADV-DETF-MB-001 |
| TCA-DETF-CS-009 | High | WP-I-DETF-CS-002 |
| TCA-DETF-CS-010 | High | WP-G-E-DETF-CS-001 |
| TCA-DETF-CS-011 | High | WP-ADV-DETF-MB-001 |
| TCA-DETF-DL-001 | Blocker | WP-I-DETF-DL-001 |
| TCA-DETF-DL-002 | Blocker | WP-I-DETF-DL-001 |
| TCA-DETF-DL-003 | High | WP-I-DETF-DL-002 |
| TCA-DETF-DL-004 | High | WP-J-DETF-DL-001 |
| TCA-DETF-DL-005 | High | WP-I-DETF-DL-002 |
| TCA-DETF-SVS-003 | High | WP-I-CLAIM-001 |
| TCA-SE-AC-001 | Blocker | WP-I-COMMON-001 (+ WP-I-SE-AC-001 tests) |
| TCA-SE-AC-002 | High | WP-I-SE-AC-001 |
| TCA-SE-AC-003 | High | WP-I-SE-AC-001 |
| TCA-SE-AC-004 | High | WP-J-SE-AC-001 |
| TCA-SE-AC-005 | High | WP-ADV-SE-AC-001 |
| TCA-SE-AC-006 | High | WP-ADV-SE-AC-001 |
| TCA-SE-AC-007 | High | WP-H-CAM-001 |
| TCA-SE-AC-008 | High | WP-E5-AERO-001 |
| TCA-SE-UAB-001 | Blocker | WP-I-CLONE-UAB-001 |
| TCA-SE-UAB-002 | Blocker | WP-I-CLONE-UAB-001 |
| TCA-SE-UAB-003 | High | WP-I-CLONE-UAB-001 |
| TCA-SE-UAB-004 | High | WP-I-SE-UAB-001 |
| TCA-SE-UAB-005 | High | WP-I-SE-UAB-001 |
| TCA-SE-UAB-006 | High | WP-J-SE-UAB-001 |
| TCA-SE-UAB-007 | High | WP-ADV-SE-UAB-001 + WP-J-SE-UAB-001 |
| TCA-SE-UAB-008 | High | WP-ADV-SE-UAB-001 |
| TCA-SE-UAB-009 | High | WP-I-SE-UAB-001 |
| TCA-SE-UAB-010 | High | WP-J-ROUTER-UAB-001 |
| TCA-HOOK-001 | Blocker | WP-I-HOOK-CP-001 |
| TCA-HOOK-002 | High | WP-I-HOOK-DUAL-001 |
| TCA-HOOK-003 | High | WP-I-HOOK-DUAL-001 + WP-I-HOOK-SEBUF-001 |
| TCA-HOOK-004 | High | WP-I-HOOK-SEBUF-001 |
| TCA-HOOK-005 | High | WP-J-HOOK-001 |
| TCA-HOOK-006 | High | WP-I-HOOK-DUAL-001 + WP-ADV-HOOK-001 |
| TCA-HOOK-007 | High | WP-I-HOOK-SEBUF-001 |
| TCA-HOOK-008 | High | WP-ADV-HOOK-001 |
| TCA-HOOK-009 | High | WP-I-HOOK-SEBUF-001 |
| TCA-MGR-001 | High | WP-J-MGR-001 |
| TCA-MGR-002 | High | WP-J-MGR-002 |
| TCA-MGR-003 | High | WP-N-FEE-001 |
| TCA-RTR-001 | High | WP-I5-RTR-001 |
| TCA-RTR-002 | High | WP-N-RTR-001 |
| TCA-RTR-003 | High | WP-J-RTR-001 |

**Count:** 69 Blocker/High finding IDs → indexed. Formal WPs with full §8: **44** (WPs 1–44).
