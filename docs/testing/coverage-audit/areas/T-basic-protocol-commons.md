# Test Coverage Audit — T-basic-protocol-commons

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · pilot · `T-basic-protocol-commons` |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/basic/**` (primary); secure-transfer / claim pull helpers under `contracts/vaults/**` and SE commons as **blast-radius reference** |
| Test paths | `test/foundry/spec/vaults/basic/**`; `test/foundry/fork/*/vaults/basic/**`; seed `docs/NEGATIVE_TEST_COVERAGE_REPORT.md`; cross-cite SE/DETF pretransfer tests (not owned) |
| Skills / PRD version cited | `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` (DRAFT, locks L-TCA-1…8, §2.4 PAT-*, §3.8, §7.2, §8, §19); `crane-adversarial-testing` A–K + I/J DoD; `crane-testing` LR-7; `indexedex-testing` / `indexedex-adversarial-testing` |
| Finding ID prefix | `TCA-COMMON-NNN` |

---

## 1. Executive summary

### Maturity (0–5)

| Product / surface | Maturity | Worst open severity |
|-------------------|----------|---------------------|
| **BasicVaultCommon** (shared pull/credit) | **1** | **High CODE** (PAT-I-ABS) |
| **BasicVaultFacet / Target** (view-only IBasicVault) | **1** | Low (optional adversarial deferred historically) |
| **MultiAssetBasicVault*** (views / multi-asset repo) | **0–1** | Info (no money pull surface found) |
| **ERC4626StandardExchangeCommon._securePull** (reference good pattern) | **3–4** (I partial on product tests) | Owned by SE/ERC4626 areas; **not** PAT-I-ABS |
| **RebasingClaimTokenTarget._secureTokenTransfer** | **2** | **High CODE** residual foreign-token path; self-path delta-aware (L-CLAIM-3 partial) |
| **ProtocolDETFCommon / SeigniorageDETFCommon** | **N/A** | **Removed / not in tree** (stale prior-task refs) |

### Blocker / High counts

| Severity | Count | Notes |
|----------|------:|-------|
| **Blocker** | **0** | End-to-end free **share** mint not runtime-proven in this area (no product proxy SUT owned here). Helper free-credit is proven; product areas may escalate. |
| **High** | **5** | PAT-I-ABS epicenter + theater + missing I1–I3 + clone surfaces + claim foreign-token residual |
| **Medium** | **3** | K documentation / I4 harness / duplicate `_refundExcess` |
| **Low / Info** | **4** | Good-pattern refs, BasicVault optional defer, deploy path notes |

### Top 5 recommended WPs

1. **`WP-I-COMMON-001`** — Wave-0 CODE: fix `BasicVaultCommon._secureTokenTransfer` pretransfer to **delta-only** credit (align with ERC4626/Rocket `_securePull`); rewrite unit tests that greenwash absolute credit.
2. **`WP-I-COMMON-002`** — Wave-0 TEST: shared I1–I3 harness helpers + BasicVaultCommon unit suite proving no free credit when inventory pre-exists.
3. **`WP-I-CLONE-001`** — Serial after 001: align **local clone** `_secureTokenTransfer` / `_pullToken` copies (Uni V3/V4, Slipstream, ComposedStable, MultiVault, DETF commons, RebasingDETFToken) — or force inheritance from fixed common where possible.
4. **`WP-I-CLAIM-001`** — RebasingClaimToken foreign-token pretransfer: enforce delta/last-balance (complete L-CLAIM-3); I1–I3 on claim proxy.
5. **`WP-K-COMMON-001`** — Document + test K interaction: donation / absolute inventory vs post-fix pretransfer (when credit = delta, K free-credit via pretransfer closes; residual K is product reserve-snapshot paths).

### Headline

**PAT-I-ABS is confirmed in production `BasicVaultCommon._secureTokenTransfer` (lines 33–38):** when `pretransferred=true`, the function `require`s absolute `balanceOf(this) >= amount` and **returns the caller-claimed amount with no balance delta**. NatSpec claims “balance-delta accounting” and “prevents over-crediting,” but that only holds for the **`pretransferred=false`** branch. Crane adversarial skill documents this exact anti-pattern as Category **I**. Existing unit tests **assert the buggy return** (`test_secureTokenTransfer_pretransferred_returnsAmount`) — **PAT-THEATER-PRE**. Recommend **single Wave-0 CODE WP** on this common before per-product I suites land.

---

## 2. Product inventory

### 2.1 Packages / surfaces in allowlist

| Product | DFPkg / key Targets | TestBase | Test roots | Deploy path quality |
|---------|---------------------|----------|------------|---------------------|
| **BasicVaultCommon** | Shared internal lib (not a DFPkg); inherited by SE commons | **Harness-only** (`BasicVaultCommonHarness` via `new`) | `test/foundry/spec/vaults/basic/*`; fork Permit2 Base/Eth | **Poor for SUT bar** — unit harness OK for pure helper; **does not** count as product H/A–K |
| **BasicVaultFacet / Target** | View facet: `vaultTokens`, `reserveOfToken`, `reserves` | None found dedicated | Historical “BasicVault optional defer” | Facet exists; **no money entrypoints**; CREATE3/FactoryService expected if packaged |
| **MultiAssetBasicVaultFacet / Target** | Multi-asset view surface | None found | — | Same as BasicVault views |
| **ERC4626BasedBasicVaultFacet** | ERC4626-based basic facet | — | — | Out of deep money-path review beyond inheritance map |
| **RebasingClaimToken** (claim commons) | `RebasingClaimTokenDFPkg`, `RebasingClaimTokenTarget/Facet` | Product TestBases under DETF trees | Claim / SAF tests cite pretransfer | Registry/DFPkg path (product areas own deploy proof); transfer helper co-reviewed here |
| **DETFSafeTransferLib** | Library transfer helper only | N/A | N/A | No pretransfer flag |
| **Protocol / Seigniorage “Common” pull** | **Not present** under `contracts/vaults/**` | Stale docs | `docs/NEGATIVE_TEST_COVERAGE_REPORT.md` cites removed `ProtocolDETF*` paths | Prior tasks (IDXEX-061) outdated |

### 2.2 Inheritance of `BasicVaultCommon` (direct)

| Contract | Path | Notes |
|----------|------|-------|
| `AerodromeStandardExchangeCommon` | `contracts/protocols/dexes/aerodrome/v1/` | **Overrides** `_secureTokenTransfer` for reserved excess; **still PAT-I-ABS** on non-reserved available balance (`return amountTokenToDeposit`) |
| `CamelotV2StandardExchangeCommon` | `contracts/protocols/dexes/camelot/v2/` | Inherits BasicVaultCommon as-is |
| `UniswapV2StandardExchangeCommon` | `contracts/protocols/dexes/uniswap/v2/` | Inherits as-is |
| `AaveV3StataStandardExchangeCommon` | `contracts/protocols/lending/aave/v3.6/` | Inherits as-is; uses `_secureSelfBurn` |

### 2.3 Call sites — `_secureTokenTransfer` / inheritance blast radius

#### A. Via `BasicVaultCommon` (or override → super)

| Consumer | File (representative) | Usage |
|----------|----------------------|--------|
| Aerodrome SE In/Out | `AerodromeStandardExchangeInTarget.sol`, `...OutTarget.sol` | `amountIn = _secureTokenTransfer(...)` on swap/zap/vault routes; `_refundExcess`; `_secureSelfBurn` |
| Camelot V2 SE In/Out | `CamelotV2StandardExchangeInTarget.sol`, `...OutTarget.sol` | Same pattern |
| Uniswap V2 SE In/Out | `UniswapV2StandardExchangeInTarget.sol`, `...OutTarget.sol` | Same pattern |
| Aave V3 Stata Out | `AaveV3StataStandardExchangeOutTarget.sol` | `_secureSelfBurn` for share burn pretransfer |

#### B. **Local clone** `_secureTokenTransfer` (same PAT-I-ABS shape; not BasicVaultCommon inheritance)

| Clone surface | Path | Pretransfer behavior |
|---------------|------|----------------------|
| Uni V3 SE In/Out | `UniswapV3StandardExchange{In,Out}Target.sol` | `balanceOf >= amount` → `return amountIn` |
| Uni V4 SE Common | `UniswapV4StandardExchangeCommon.sol` | `balanceOf < amount` revert → `return amountIn` |
| Slipstream SE In/Out | `SlipstreamStandardExchange{In,Out}Target.sol` | Same absolute pattern |
| ComposedStable DETF Common | `ComposedStableCommonDetfCommon.sol` | **`if (pretransferred_) return amount_;`** — no balance check |
| RebasingDETFToken | `RebasingDETFTokenTarget.sol` | **`return amount_`** — no balance check |
| MultiVault `_pullToken` | `MultiVaultWeightedDetfCommon.sol` | **`if (pretransferred_) return amount_;`** |
| MixedBuffer / Single SE DETF / UniV4 DETF commons | multiple `*DetfCommon.sol` | `if (pretransferred_) return amount_;` (same class) |

#### C. **Good-pattern reference** (delta-based — Wave-0 target shape)

| Surface | Path | Pretransfer behavior |
|---------|------|----------------------|
| ERC4626 SE Common | `ERC4626StandardExchangeCommon._securePull` | Measures **delta**; `pretransferred && delta < amountIn` → `InsufficientDeposit`; overshoot refund |
| Rocket rETH SE | `RocketPoolRETHStandardExchangeCommon._securePull` | Delta; zero / short revert |
| Lido wstETH SE | `LidoWstETHStandardExchangeCommon._securePull` | Same family |
| EtherFi weETH SE | `EtherFiWeETHStandardExchangeCommon._securePull` | Same family |
| RebasingClaimToken **self** path | `RebasingClaimTokenTarget._secureTokenTransfer` | Delta vs `lastSelfBalance` (L-CLAIM-3) for claim token |

#### D. Claim / NFT transfer helpers (commons)

| Helper | Pretransfer / pull | Notes |
|--------|-------------------|--------|
| `RebasingClaimTokenTarget._secureTokenTransfer` | Self: delta vs last; **Foreign: absolute ≥ amount → return amount** | Foreign path still PAT-I-ABS-class |
| `RebasingDETFTokenTarget._secureTokenTransfer` | Blind `return amount_` | High CODE (product area + this cross-cut) |
| `DETFSafeTransferLib` | No flag | N/A for I |
| `DETFNFTVault*` / bond NFT commons | No `_secureTokenTransfer` match | Authority catalog **D** owned by DETF areas |

### 2.4 Trust-flag entrypoints (shared)

Any external API with `bool pretransferred` that eventually calls the helpers above is in blast radius. Representative:

- SE: `exchangeIn` / `exchangeOut` on Aerodrome, Camelot, Uni V2/V3/V4, Slipstream, Aave Stata, ERC4626 SE, Rocket/Lido/EtherFi
- DETF: mint/exchange/bond/redeem/donate paths using `_pullToken` / `_secureTokenTransfer`
- Claim: `redeem` / `burnShares` with `pretransferred` on rebasing claim tokens

### 2.5 Test inventory (this area)

| Suite | Path | What it proves | Counts for I1–I3? |
|-------|------|----------------|-------------------|
| TokenTransfer unit | `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol` | FoT + dust for **false** path; **pretransfer returns claimed amount**; insufficient absolute reverts | **No** — I1 inverted (theater) |
| Permit2 unit | `test/foundry/spec/vaults/basic/BasicVaultCommon_Permit2.t.sol` | BetterPermit2 pull; same pretransfer theater | **No** |
| Permit2 Base fork | `test/foundry/fork/base_main/vaults/basic/BasicVaultCommon_TokenTransfer_Permit2_BaseFork.t.sol` | Production Permit2 path | **No** for I1–I3 |
| Permit2 Eth fork | `test/foundry/fork/eth_main/vaults/basic/...EthFork.t.sol` | Same | **No** |
| SE free-mint (ref) | e.g. ERC4626 `test_FreeMint_pretransferred_noDelta_*`; Rocket/Lido/EtherFi `test_A0_pretransferred*` | Product-level I-class on **delta** `_securePull` products | **Yes** for those products — not for BasicVaultCommon consumers |
| Aerodrome reserved dust | `AerodromeStandardExchangeIn_Swap.t.sol` `test_Route1Swap_pretransferred_true_reverts_whenOnlyReservedDust` | Partial guard on **reserved** excess | **Not** I1 against general inventory |
| Donation K (ref) | Aerodrome/UniV2 VaultDeposit donation mismatch tests | K on ERC4626 reserve deposit routes | Product-owned |

---

## 3. Layer matrix

Legend: **F** full · **P** partial · **G** gap · **N/A** · **S** stub/theater risk · maturity 0–5.

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Maturity | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|----------|-------|
| BasicVaultCommon | P | P | N/A | N/A | **G/S** | G | G | N/A | G | G | G | **1** | H: FoT/dust on pull path; I theater; not a diamond |
| BasicVaultFacet | G | G | P | P* | N/A | N/A | G | N/A | G | G | G | **1** | Views only; J = 3 view selectors match Target |
| RebasingClaimToken pull | P | P | P | (product) | **P/G** | P | (product) | P | G | G | G | **2** | Self delta OK; foreign absolute; no formal I1–I3 names |
| ERC4626 `_securePull` (ref) | F | P | (product) | (product) | **P→F** | P | P | P | G | G | G | **3–4** | Free-mint tests exist; catalog naming incomplete |
| Local PAT-I-ABS clones | — | — | — | — | **G** | — | — | — | — | — | — | **0–2** | Owned by product areas; listed for Wave-0 clone WP |

\*J for BasicVault: Target API ⊆ facetFuncs for 3 views; **no money API** — J bar on money routes N/A for this facet.

---

## 4. Catalog matrix (A–K)

Evidence for **BasicVaultCommon / shared commons** only. Product SE/DETF cells are cross-references.

| ID | BasicVaultCommon | RebasingClaim (commons) | Evidence (test name or G) |
|----|------------------|-------------------------|---------------------------|
| **A1** Donation | G | G | No commons-level donation suite; SE donation tests elsewhere |
| **A2–A3** | G | G | G |
| **B*** | N/A | N/A | No pricing in common |
| **C*** | G | G | No reentrancy on helper alone |
| **D*** | N/A | P | Claim authority in product suites (partial historically) |
| **E1/E5** | P | P | FoT delta on `pretransferred=false`; zero-amount not unit-tested on helper |
| **F*** | N/A | (product) | Common is internal |
| **G*** | N/A | N/A | |
| **H2–H3** | G | G | |
| **I1** | **G / THEATER** | **G** (foreign); partial self | `test_secureTokenTransfer_pretransferred_returnsAmount` is **anti-I1** (asserts free credit of claimed amount against seeded inventory with **no transfer in call**) |
| **I2** | **P** (absolute short only) | G | `test_secureTokenTransfer_pretransferred_insufficientBalance_reverts` — only absolute shortfall, not short **delta** vs claim |
| **I3** | **G** | G | No residual-reuse second-call suite on common |
| **I4** | **P** | P | FoT tests on `pretransferred=false` |
| **I5** | P | G | Permit2 path fork/unit for pull; not signed-amount ≠ delivered adversarial |
| **J1–J3** | N/A (lib) | product-owned | BasicVaultFacet: 3 view selectors only |
| **K1** | G at common | P | Common has no `lastTotalAssets`; K free-credit via absolute pretransfer **is** PAT-I-ABS. Product donation mismatch tests (Aerodrome/UniV2 Route4) are **ref** only |

---

## 5. Findings

### 5.1 [TCA-COMMON-001] High · CODE · PAT-I-ABS · RUNTIME_PROVEN (helper free-credit)

- **Summary:** `BasicVaultCommon._secureTokenTransfer` on `pretransferred=true` credits the **caller-claimed** `amountTokenToDeposit` after an absolute `balanceOf >= amount` check, without measuring inbound **delta**. Vault inventory (reserves, dust, prior donations, other users’ pretransfers) is treated as the caller’s delivery. This is the Crane skill Category I anti-pattern verbatim and contradicts L-CLAIM-3 / agent law (“credit only observed balance delta”).
- **Evidence:**
  - Production: [`contracts/vaults/basic/BasicVaultCommon.sol`](../../../../contracts/vaults/basic/BasicVaultCommon.sol) **L33–38**:
    ```solidity
    if (pretransferred) {
        require(
            tokenIn.balanceOf(address(this)) >= amountTokenToDeposit,
            "BasicVaultCommon: insufficient pretransferred balance"
        );
        return amountTokenToDeposit;
    }
    ```
  - NatSpec L19–27 claims delta accounting for the function; **false for pretransfer branch**.
  - Non-pretransfer branch L41–50 correctly uses `balBefore` / delta (I4 partial).
  - **Runtime proof (helper):** existing suite seeds vault then claims without transfer in-call:
    - `test_secureTokenTransfer_pretransferred_returnsAmount` — vault holds `DEPOSIT+DUST`, alice calls `pretransferred=true`, asserts `actual == DEPOSIT` (**PASS = free credit of claimed amount**).
    - Same pattern: `test_pretransferred_returnsAmount` in Permit2 suite.
  - Law anchors: `docs/STRUCT_AUDIT_FIXES_PRD.md` **L-CLAIM-3**; `docs/agent/INDEXEDEX_AGENT_LAW.md` trust-flag free mint; crane-adversarial-testing SKILL L104–124.
- **Why bar fails:** I1 requires zero transfer + existing inventory → **no free credit**. Helper **returns claimed amount**. Downstream SE routes assign `amountIn = _secureTokenTransfer(...)` → blast radius free principal / free swap input credit (product areas confirm share mint e2e).
- **Severity note:** Classified **High** (not Blocker) per §3.8 — runtime proof is **helper free-credit**, not e2e attacker **share** balance increase on a production diamond. Static + helper runtime is overwhelming for CODE; product areas should escalate to **Blocker** if e2e free mint is demonstrated. Label: `RUNTIME_PROVEN_HELPER` / e2e `RUNTIME_UNPROVEN` in this area.
- **Recommended CODE change:** Align with `ERC4626StandardExchangeCommon._securePull`:
  1. Always snapshot `balBefore = balanceOf(this)` (or last synced reserve if product stores one).
  2. If `!pretransferred`: pull via allowance / Permit2.
  3. `delta = balanceAfter - balBefore`.
  4. If `pretransferred && delta < amount`: revert exact error (prefer typed selector over string).
  5. Credit / return **min(delta, amount)** or strict equality per product law; refund overshoot via existing `_refundExcess` policy.
  6. Update NatSpec to match.
  7. Revisit Aerodrome override: reserved-balance subtraction must compose with **delta**, not absolute available − reserved → claimed return.
- **Recommended TEST:**
  - `test_I1_pretransferred_noTransfer_existingInventory_revertsOrZeroCredit`
  - Setup: mint inventory to harness; **no** transfer from attacker; `pretransferred=true`; amount ≤ inventory.
  - Pass: revert **or** `actualIn == 0`; never `actualIn == amount`.
  - Match-path: `test/foundry/spec/vaults/basic/**`
- **Suggested WP:** `WP-I-COMMON-001`
- **Priority:** Wave **0** (serial commons)

### 5.2 [TCA-COMMON-002] High · THEATER · PAT-THEATER-PRE

- **Summary:** Unit/fork tests document and assert that pretransfer returns the claimed amount against pre-seeded balance, greenwashing PAT-I-ABS as intended IDXEX-035/061 behavior. IDXEX-061 only added absolute floor check — **not** delta proof.
- **Evidence:**
  - `BasicVaultCommon_TokenTransfer.t.sol` L183–196 (`test_secureTokenTransfer_pretransferred_returnsAmount`)
  - `BasicVaultCommon_Permit2.t.sol` L165–173
  - Fork happy pretransfer tests (Base/Eth) seed then claim
  - Task history: `tasks/archive/IDXEX-061-*`, `IDXEX-035` notes that absolute check “doesn’t prove tokens were transferred”
- **Why bar fails:** Happy-path / “returns amount” is **explicitly not** I1–I3 coverage (PRD §2.4, skill DoD).
- **Recommended CODE:** none alone — fix 001 then **replace** tests.
- **Recommended TEST:** Delete or invert theater asserts; add I1–I3 with exact selectors; keep FoT/dust for `pretransferred=false`.
- **Suggested WP:** `WP-I-COMMON-002` (depends on 001)
- **Priority:** Wave 0–1

### 5.3 [TCA-COMMON-003] High · TEST · Catalog I1–I3 missing on BasicVaultCommon + consumers

- **Summary:** No `test_I1_` / `test_I2_` / `test_I3_` suites for BasicVaultCommon-backed SE products under this area’s unit roots. Grep shows I-class free-mint tests primarily on **delta-based** products (ERC4626, Rocket, Lido, EtherFi) and scattered Aerodrome reserved-dust cases — not formal I catalog for absolute-balance consumers.
- **Evidence:** `rg 'function test_I1_|test_I2_|test_I3_' test/` — no hits under `vaults/basic/`; product free-mint tests use names like `test_FreeMint_*` / `test_A0_*` on correct `_securePull` paths.
- **Why bar fails:** P0 I1–I3 mandatory when `pretransferred` exists.
- **Recommended TEST:** Shared helper in adversarial TestBase: `_assertNoFreeCreditOnPretransferClaim(token, amount)`; port to Aerodrome/Camelot/UniV2 after CODE fix (product WPs may own proxy suites; this WP owns common unit + template).
- **Suggested WP:** `WP-I-COMMON-002` (+ product Wave 1)
- **Priority:** High

### 5.4 [TCA-COMMON-004] High · CODE · PAT-I-ABS (clone surfaces — blast radius)

- **Summary:** Multiple independent `_secureTokenTransfer` / `_pullToken` copies implement the same absolute or blind-return pretransfer semantics. Fixing only BasicVaultCommon **does not** close Uni V3/V4, Slipstream, ComposedStable, MultiVault, UniV4 DETF, RebasingDETFToken.
- **Evidence (sample):**
  - `UniswapV3StandardExchangeInTarget.sol` L199–204
  - `UniswapV4StandardExchangeCommon.sol` L1076–1080
  - `SlipstreamStandardExchangeOutTarget.sol` L242–244
  - `ComposedStableCommonDetfCommon.sol` L297–300 (`return amount_` only)
  - `MultiVaultWeightedDetfCommon.sol` L442–443
  - `RebasingDETFTokenTarget.sol` L410–411
- **Why bar fails:** Same I bar monorepo-wide.
- **Recommended CODE:** Prefer single shared library or inherit fixed BasicVaultCommon; else apply identical delta patch to each clone in coordinated WPs (serial merge plan).
- **Recommended TEST:** Per-product I1 after CODE; common unit template.
- **Suggested WP:** `WP-I-CLONE-001` (depends on design from 001)
- **Priority:** Wave 0 design / Wave 1 parallel per package after API freeze
- **Ownership:** Production clones live outside allowlist deep-fix; this finding is **cross-cut inventory** for orchestrator Wave-0 planning.

### 5.5 [TCA-COMMON-005] High · CODE · PAT-I-ABS residual · RebasingClaimToken foreign token

- **Summary:** Self-claim path uses `lastSelfBalance` delta (L-CLAIM-3 progress). **Foreign** token branch still `balanceNow_ >= amount_` → `return amount_` without proving same-tx delta vs a last snapshot.
- **Evidence:** `RebasingClaimTokenTarget.sol` L541–550 vs L553–559 (self OK).
- **Why bar fails:** I1 on foreign token redeem/deposit paths.
- **Recommended CODE:** Snapshot last foreign balance or measure delta across call; update snapshot after consume.
- **Recommended TEST:** `test_I1_claim_foreignToken_pretransferred_noDelta_reverts` on claim proxy.
- **Suggested WP:** `WP-I-CLAIM-001`
- **Priority:** Wave 1 (can parallelize with clone WP after law confirmed)

### 5.6 [TCA-COMMON-006] Medium · CODE · PAT-K-DONATE interaction

- **Summary:** Absolute pretransfer credit **is** a K-class free-credit of prior inventory. After TCA-COMMON-001, pure donation→next pretransfer free mint should close at the pull layer. Residual K remains on product `lastTotalAssets` / reserve snapshot paths (ERC4626Service strict mismatch — partially tested on Aerodrome/UniV2 Route4).
- **Evidence:** NEGATIVE_TEST_COVERAGE_REPORT §B donation tests marked done for Route4; B3 beneficiary design still open historically.
- **Recommended CODE:** None in BasicVaultCommon beyond 001; product K WPs elsewhere.
- **Recommended TEST:** After 001: `test_K1_donationThenPretransferClaim_noFreeCredit` on harness + one SE proxy.
- **Suggested WP:** `WP-K-COMMON-001` (TEST-heavy; depends on 001)
- **Priority:** Wave 0–2

### 5.7 [TCA-COMMON-007] Medium · THEATER / TEST · Aerodrome override partial mitigation

- **Summary:** `AerodromeStandardExchangeCommon` override excludes `_excessToken*` from available balance but still `return amountTokenToDeposit` without delta. Tests for “only reserved dust reverts” do **not** prove I1 against non-reserved vault holdings (e.g. idle swap inventory).
- **Evidence:** `AerodromeStandardExchangeCommon.sol` L52–76; `test_Route1Swap_pretransferred_true_reverts_whenOnlyReservedDust`.
- **Recommended CODE:** Fold into 001 + rewrite override for delta vs reserved.
- **Suggested WP:** `WP-I-COMMON-001` + SE Aerodrome product I suite (area `T-se-aerodrome-camelot-univ2`)
- **Priority:** High product follow-on

### 5.8 [TCA-COMMON-008] Medium · TEST · I2 incomplete (absolute vs short delivery)

- **Summary:** Insufficient-balance pretransfer revert only covers `balance < claim`. Does not cover: vault holds ≥ claim from inventory, attacker transferred **partial** new funds, claim full amount (short **delta**).
- **Evidence:** `test_secureTokenTransfer_pretransferred_insufficientBalance_reverts`
- **Recommended TEST:** `test_I2_pretransferred_shortDelta_reverts` after delta fix.
- **Suggested WP:** `WP-I-COMMON-002`
- **Priority:** High (with I suite)

### 5.9 [TCA-COMMON-009] Low · CODE · NatSpec / error style

- **Summary:** Misleading NatSpec on delta safety; string revert `"BasicVaultCommon: insufficient pretransferred balance"` vs typed errors used elsewhere (`InsufficientDeposit`).
- **Recommended CODE:** Fix docs + consider typed error for exact-selector negatives.
- **Suggested WP:** fold into `WP-I-COMMON-001`
- **Priority:** Low/Medium hygiene

### 5.10 [TCA-COMMON-010] Info · CODE pattern reference

- **Summary:** `ERC4626StandardExchangeCommon._securePull` and staking SE `_securePull` implementations are the **canonical correct pattern** for Wave-0. Product free-mint tests (`test_FreeMint_pretransferred_noDelta_*`, `test_A0_pretransferred*`) show the bar is achievable.
- **Class:** Info — no WP required beyond citing as implementation template.

### 5.11 [TCA-COMMON-011] Info · DEFER · BasicVault as user deposit surface

- **Summary:** 2026-07 adversarial plan Wave 3C BasicVault optional — deferred; BasicVaultTarget is **view-only** (no deposit). Adversarial A–H on BasicVaultFacet is low value until a money DFPkg appears.
- **Status:** Still deferred as product surface; **BasicVaultCommon remains P0** as shared lib.

### 5.12 [TCA-COMMON-012] Low · TEST · PAT-MOCK / harness deploy

- **Summary:** Common unit tests use `new BasicVaultCommonHarness` — acceptable for pure internal helper, **must not** be counted as SE/DETF adversarial coverage. Fork Permit2 tests correctly avoid mock Permit2.
- **Priority:** Info/Low documentation

### 5.13 [TCA-COMMON-013] Info · Stale production names

- **Summary:** Tasks/docs still reference `ProtocolDETFCommon` / `SeigniorageDETFCommon` `_secureTokenTransfer`. **No such contracts** under `contracts/` today. Claim/DETF commons replaced those roles.
- **Action:** Orchestrator should not spawn WPs for deleted paths.

---

## 6. Theater list

| Test / control | Why theater | Fix |
|----------------|-------------|-----|
| `test_secureTokenTransfer_pretransferred_returnsAmount` | Asserts free credit of claimed amount vs pre-seeded inventory; zero same-tx transfer | Invert → I1 must not credit |
| `test_pretransferred_returnsAmount` (Permit2 suite) | Same | Same |
| Fork `test_fork_secureTokenTransfer_pretransferred_*` | Happy pretransfer with pre-mint to harness; not I1–I3 | Keep only if real transfer in same setup **and** add I1–I3 |
| NatSpec “balance-delta… prevents over-crediting” on full function | Documents safety the pretransfer branch does not provide | Rewrite after CODE fix |
| `test_Route1Swap_pretransferred_true` (many SE happy paths) | Real transfer + pretransfer=true — **not** I1 (skill anti-pattern) | Product suites need separate I1 |
| IDXEX-061 “balance validation” narrative | Absolute check sold as security fix | Supersede with delta law |

---

## 7. Prior-report diff

| Claim (doc) | Status now |
|-------------|------------|
| 2026-07 adversarial matrix: BasicVault **G** on A/C/E/F; optional Wave 3C deferred | **Still gap** for BasicVault facet; **New elevated P0** on BasicVaultCommon I (catalog I not in 2026-07 A–H matrix) |
| 2026-07: Seigniorage has dust / FoT secure transfer tests | **Partial / relocated** — FoT lives on BasicVaultCommon unit tests; Seigniorage product suites may differ post-reorg |
| 2026-07: Protocol claim/NFT **S**/G | **Still gap** for formal I; claim self-path improved (L-CLAIM-3); foreign residual **New/Still** CODE |
| NEGATIVE_TEST_COVERAGE_REPORT §B Route4 donation mismatch | **Closed** for cited Aerodrome/UniV2 tests (present) |
| NEGATIVE_TEST_COVERAGE_REPORT §C1 pretransfer not strict | **Still gap** / product-law — ERC4626 may still pull when short; BasicVaultCommon pretransfer never pulls |
| NEGATIVE_TEST_COVERAGE_REPORT ProtocolDETF / RICHIR paths | **Stale** — paths/products reorganized; do not treat as inventory truth |
| STRUCT_AUDIT L-CLAIM-3 pretransfer delta | **Partial** on RebasingClaimToken self; **Open CODE** on BasicVaultCommon + most clones + claim foreign |
| IDXEX-035 “balance-delta fix” | **Partial** — non-pretransfer only; pretransfer still absolute |
| IDXEX-061 pretransfer balance validation | **Closed as written** (absolute require) but **insufficient vs I bar** — creates false security |
| Fuzz/invariant 2026-07 reports | **No L1–L3** on BasicVaultCommon (N/A for pure helper; product L3 still gap elsewhere) |
| Catalog I/J/K columns | **New** relative to 2026-07 A–H-only matrix — primary value of this pilot area |

---

## 8. Work package stubs

### WP-I-COMMON-001 — Wave-0 CODE: delta-only pretransfer in BasicVaultCommon

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-COMMON-001` |
| **Title** | Fix BasicVaultCommon pretransfer to credit observed delta only |
| **Severity** | High |
| **Class** | CODE (+ test updates in same WP or 002) |
| **Products** | All BasicVaultCommon inheritors (Aerodrome, Camelot, Uni V2, Aave Stata); template for clones |
| **Finding IDs** | TCA-COMMON-001, TCA-COMMON-007, TCA-COMMON-009 |
| **Problem** | `pretransferred=true` returns claimed amount after absolute balance check, enabling free credit of vault inventory. Aerodrome override inherits the same return-claimed pattern. |
| **Production files (touch set)** | `contracts/vaults/basic/BasicVaultCommon.sol`; `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol` (override rewrite) |
| **Test files (touch set)** | `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol`; `BasicVaultCommon_Permit2.t.sol`; fork Permit2 files if asserts break |
| **Out of scope files** | Uni V3/V4/Slipstream/DETF clone bodies (→ WP-I-CLONE-001); product adversarial trees except compile fixes |
| **Depends on** | none |
| **Parallelizable with** | none on same files; claim WP can design in parallel |
| **Suggested worktree** | `gap_cover_i-common` / branch `gap_cover/i-common` |
| **Implementation notes** | Copy semantics from `ERC4626StandardExchangeCommon._securePull` (L155–181) and Rocket `_securePull`. Skills: crane-adversarial-testing Category I, L-CLAIM-3. Prefer typed `InsufficientDeposit` if import graph allows; else keep string but document exact bytes for tests. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/basic/**' -vv` green; new I1 fails on **pre-fix** code (prove with temporary red test in worktree). Required names: `test_I1_pretransferred_noTransfer_existingInventory_*`, `test_I2_pretransferred_shortDelta_*`, existing FoT tests still green for `pretransferred=false`. |
| **Anti-theater checks** | I1 must not transfer tokens in-call; must not assert `actual == claimed` against pure inventory; no `vm.mockCall` on harness token pull path |
| **Estimate** | M |

### WP-I-COMMON-002 — Wave-0/1 TEST: I1–I3 + kill theater

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-COMMON-002` |
| **Title** | Replace pretransfer theater with I1–I3 unit suite + shared helper |
| **Severity** | High |
| **Class** | TEST |
| **Products** | BasicVaultCommon; template for SE product areas |
| **Finding IDs** | TCA-COMMON-002, TCA-COMMON-003, TCA-COMMON-008 |
| **Problem** | No catalog I suite; existing tests encode wrong postcondition. |
| **Production files** | none (or error selector only if 001 landed) |
| **Test files** | `test/foundry/spec/vaults/basic/BasicVaultCommon_TrustFlags.t.sol` (new); edit TokenTransfer/Permit2; optional `test/foundry/spec/vaults/basic/helpers/TrustFlagAsserts.sol` |
| **Out of scope** | Product proxy adversarial (owned by SE/DETF areas) |
| **Depends on** | `WP-I-COMMON-001` (or write red tests first in same worktree) |
| **Parallelizable with** | product J WPs; not with clone CODE on same branches |
| **Suggested worktree** | `gap_cover_i-common-tests` or same as 001 |
| **Implementation notes** | Naming `test_I1_*`, `test_I2_*`, `test_I3_*` per skill. I3: successful pretransfer consume then second claim without new transfer. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_I' -vv`; `rg 'function test_I1_' test/foundry/spec/vaults/basic` ≥1 |
| **Anti-theater** | I1 zero transfer; I2 short delivery; I3 residual reuse; exact selector |
| **Estimate** | S–M |

### WP-I-CLONE-001 — Align clone pull helpers (blast radius)

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-CLONE-001` |
| **Title** | Delta-pretransfer for local `_secureTokenTransfer` / `_pullToken` clones |
| **Severity** | High |
| **Class** | CODE |
| **Products** | Uni V3/V4 SE, Slipstream, ComposedStable, MultiVault, UniV4 DETFs, RebasingDETFToken, MixedBuffer, Single SE DETF commons |
| **Finding IDs** | TCA-COMMON-004 |
| **Problem** | Independent absolute/blind pretransfer copies remain after BasicVaultCommon fix. |
| **Production files** | Listed clone paths in §2.3.B (split sub-WPs per package if merge risk) |
| **Test files** | Product area adversarial after CODE |
| **Out of scope** | BasicVaultCommon (done in 001); ERC4626/Rocket already correct |
| **Depends on** | `WP-I-COMMON-001` API/semantics freeze |
| **Parallelizable with** | Per-package after API freeze; **not** two agents on same file |
| **Suggested worktree** | `gap_cover_i-clones` or per-protocol `gap_cover_i-univ4-pull` etc. |
| **Implementation notes** | Prefer extract `SecurePullLib` to one place if inheritance awkward. Orchestrator may split by area ownership. |
| **Acceptance** | Per-product I1 green; monorepo `rg` for `if (pretransferred) { return amount` style reduced to intentional documented exceptions only |
| **Anti-theater** | Proxy I1, not harness-only for diamond products |
| **Estimate** | L |

### WP-I-CLAIM-001 — Claim foreign-token pretransfer delta

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-I-CLAIM-001` |
| **Title** | Complete L-CLAIM-3 on RebasingClaimToken foreign-token pretransfer |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | RebasingClaimToken (+ RebasingDETFToken if still blind return) |
| **Finding IDs** | TCA-COMMON-005; related TCA-COMMON-004 RebasingDETF |
| **Problem** | Foreign token absolute credit; DETF rebasing token blind return. |
| **Production files** | `contracts/vaults/detf/common/claimToken/RebasingClaimTokenTarget.sol`; `.../RebasingDETFTokenTarget.sol` |
| **Test files** | Claim behavior / SAF / product adversarial trust-flag |
| **Out of scope** | Bond NFT authority D-catalog (separate) |
| **Depends on** | Product law confirm for claim foreign tokens (L-CLAIM-3 already locked) |
| **Parallelizable with** | `WP-I-COMMON-002` tests; not same Target file as DETF product WPs without merge plan |
| **Suggested worktree** | `gap_cover_i-claim` |
| **Implementation notes** | STRUCT_AUDIT_FIXES_PRD L-CLAIM-3; mirror self-path last balance fields for foreign tokens used in redeem |
| **Acceptance** | `test_I1_*` / `test_I2_*` on claim proxy; forge match claim paths |
| **Anti-theater** | No happy-only pretransfer; proxy not facet-only |
| **Estimate** | M |

### WP-K-COMMON-001 — K regression after I fix

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-K-COMMON-001` |
| **Title** | Prove donation inventory cannot fund pretransfer credit after delta fix |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | BasicVaultCommon harness + one SE inheritor smoke |
| **Finding IDs** | TCA-COMMON-006 |
| **Problem** | Need explicit K×I regression so Stage 3 does not reintroduce absolute credit. |
| **Depends on** | WP-I-COMMON-001 |
| **Suggested worktree** | same as i-common-tests |
| **Acceptance** | `test_K1_donationThenPretransferClaim_noFreeCredit` green |
| **Anti-theater** | Attacker shares/credit unchanged |
| **Estimate** | S |

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Class | Notes |
|------|-------|-------|
| BasicVaultFacet full A–H adversarial | DEFER | View-only; 2026-07 Wave 3C optional still valid |
| ProtocolDETFCommon / SeigniorageDETFCommon fixes | N/A | Contracts not in tree |
| Donation beneficiary economics (B3 NEGATIVE report) | NEEDS_OWNER | Revert vs benefit next depositor — product law; K tests should match chosen law |
| Whether `pretransferred=true` may still pull (ERC4626 short path) | NEEDS_OWNER | UX strictness; separate from delta credit law |
| E2e free **share** mint severity escalation | DEFER to product areas | This area: High helper; products may raise Blocker with share-balance proof |
| L1–L3 on pure helper | N/A | Property fuzz belongs on product conservation |
| via_ir | Forbidden | Never recommend |

### Open questions

1. Should Wave-0 extract a single `SecureTokenPull` library used by SE + DETF + claim, or only patch BasicVaultCommon + N clones?
2. Exact typed error for pretransfer shortfall (reuse `InsufficientDeposit` vs new `InsufficientPretransferDelta`)?
3. Aerodrome reserved excess: is reserved balance allowed to back **legitimate** pretransfer, or must all credit be same-tx delta only? (Law: L-CLAIM-3 → delta; reserved is accounting overlay.)
4. Confirm RebasingDETFToken blind return is still production-reachable post-reorg.

---

## 10. Commands run

```bash
# Production helper + inheritance
rg -n '_secureTokenTransfer|_securePull|_secureSelfBurn|_refundExcess' contracts --glob '*.sol'
rg -n 'is BasicVaultCommon|BasicVaultCommon' contracts test --glob '*.sol'
rg -n 'if \(pretransferred|pretransferred_\) return' contracts --glob '*Common*.sol'

# Tests / catalog
rg -n 'function test_I1_|function test_I2_|function test_I3_|pretransferred|FreeMint|test_A0_pretransfer' test --glob '*.sol'
rg -n 'pretransfer|BasicVaultCommon|trust|I1' docs/NEGATIVE_TEST_COVERAGE_REPORT.md docs/testing/ADVERSARIAL_VAULT_COVERAGE_*.md docs/STRUCT_AUDIT_FIXES_PRD.md

# Area files read
# contracts/vaults/basic/BasicVaultCommon.sol
# contracts/vaults/basic/BasicVaultFacet.sol / BasicVaultTarget.sol
# contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol (_securePull good pattern)
# contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol (override)
# contracts/vaults/detf/common/claimToken/RebasingClaimTokenTarget.sol
# test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol
# test/foundry/spec/vaults/basic/BasicVaultCommon_Permit2.t.sol
# lib/crane/.claude/skills/crane-adversarial-testing/SKILL.md (Category I)
# docs/testing/TEST_COVERAGE_AUDIT_PRD.md §2–§8, §19
# docs/testing/coverage-audit/00_SCOPE_PARTITION.md
```

**Not run (optional):** full `forge test` suite — not required for High CODE with existing green theater tests as helper runtime proof; Stage 2 may require e2e share-mint proof under `docs/testing/coverage-audit/repro/` for Blocker upgrade.

---

## Appendix A — Blast radius map (call sites)

```text
BasicVaultCommon._secureTokenTransfer  [PAT-I-ABS]
├── AerodromeStandardExchangeCommon (override reserved; still claimed return)
│   └── AerodromeStandardExchangeIn/OutTarget  (many routes)
├── CamelotV2StandardExchangeCommon
│   └── CamelotV2StandardExchangeIn/OutTarget
├── UniswapV2StandardExchangeCommon
│   └── UniswapV2StandardExchangeIn/OutTarget
└── AaveV3StataStandardExchangeCommon
    └── AaveV3StataStandardExchangeOutTarget (_secureSelfBurn)

CLONES (independent PAT-I-ABS / blind return)
├── UniswapV3StandardExchangeIn/OutTarget
├── UniswapV4StandardExchangeCommon → In/OutTarget
├── SlipstreamStandardExchangeIn/OutTarget
├── ComposedStableCommonDetfCommon → ExchangeIn/Out/Bonding
├── MultiVaultWeightedDetfCommon._pullToken
├── MixedBuffer / Single SE DETF / UniV4 DETF *Common._pullToken patterns
└── RebasingDETFTokenTarget._secureTokenTransfer

DELTA-CORRECT (reference)
├── ERC4626StandardExchangeCommon._securePull
├── RocketPoolRETH / LidoWstETH / EtherFiWeETH ._securePull
└── RebasingClaimTokenTarget (self path only)

BasicVaultTarget / Facet — views only (no pull)
```

## Appendix B — Recommended single Wave-0 CODE WP

**Primary:** `WP-I-COMMON-001` only for production money-path root cause in allowlist.  
**Do not** fork all products until commons land (PRD §8.1 Wave 0).  
Clone WP is **second** serial/planning unit once the return semantics and error selectors are frozen.

---

**Area status: COMPLETE**  
**Blocker: 0 · High: 5 (TCA-COMMON-001…005)**  
**Top WP-IDs: `WP-I-COMMON-001`, `WP-I-COMMON-002`, `WP-I-CLONE-001`, `WP-I-CLAIM-001`, `WP-K-COMMON-001`**
