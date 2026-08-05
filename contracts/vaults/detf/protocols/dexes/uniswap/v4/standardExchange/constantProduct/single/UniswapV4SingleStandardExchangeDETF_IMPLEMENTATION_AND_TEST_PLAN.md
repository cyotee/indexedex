# Implementation & Test Plan: UniswapV4SingleStandardExchangeDETF

**PRD (product law SoT):** [`UniswapV4SingleStandardExchangeDETF_PRD.md`](./UniswapV4SingleStandardExchangeDETF_PRD.md) (**DRAFT v0.5**)  
**This plan (implementor SoT once accepted):** greenfield family package under `constantProduct/single/` — **do not** implement the superseded listing dual-OOR draft under `…/standardExchange/single/`.  
**Package root:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/`  
**Date:** 2026-08-04  
**Status:** **Canonical plan aligned to PRD v0.5** — ready for implementor stamp, then phased coding. **No production code in this doc-only pass.**

---

## Authority

| Layer | Role |
|-------|------|
| **PRD v0.5** | Product law — wins on any conflict; patch this plan if PRD changes |
| **This plan** | Phases, file map, deploy path, math freeze notes, test matrix, DoD |
| **AGENTS.md** | DETF common expectations; CREATE3; manager vault registry for DETF DFPkg; production-first tests; co-located PRDs |
| **Crane skills** | `crane-deployment`, `crane-architecture`, `crane-testing` |
| **IndexedEx skills** | `indexedex-testing`, `indexedex-adversarial-testing` |
| **Balancer Single SE peer** | Behavioral reference only — **do not subclass** |
| **Reserve hook package** | Hard dependency — frozen deposit/withdraw/LP ABI or DoD green |

**Process rule:** If this plan and PRD disagree, **PRD wins** and this plan must be patched.

**Role names only:** `detfToken`, `pairToken`, `standardExchangeVault`, `backingVaultShare`, `reserveHook` / `reserveLp`, `bondNft`, `rebasingClaimToken`, `creationPairPerDetfWad`. No brand tickers.

---

## Read order for implementors

1. PRD §1 locked summary + §2 roles + §3 topology  
2. PRD §4 liveness / first bond + §5 pricing (esp. **§5.5 debt-inclusive synthetic**, **§5.6 burn effectiveSupply**)  
3. PRD §7–§9 mint / bond / claim  
4. PRD §10 compound + **epoch expansion** + §10.4 tables  
5. **This plan** §0–§6 (gates, phases, files, tests)  
6. Peer `TestBase_SingleStandardExchangeDETF` + hook `TestBase_*ConstantProduct*` as pattern only  

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD v0.5 | Present at package path |
| DETF package Solidity | **None** — greenfield |
| Uni V4 DETF common nft/rebasing | May not exist — **adapt or new** under `detf/protocols/dexes/uniswap/v4/common/` (LP principal, not BPT) |
| Shared `detf/common/core/*` | Exists — reuse thresholds, usage fee, bond math, compound helpers; **extend** expansion for epochs |
| Hook package | Present under `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/` — **Phase 0 gate** |
| Superseded listing PRD/code | `…/standardExchange/single/` — **do not extend** for this product |
| Balancer Single SE | Gold peer for seigniorage split / facet shape / TestBase ladder |

---

## 1. Goals / non-goals

### Goals (v1 DoD)

1. Ship **true DETF** diamond + DFPkg under this path via **IndexedEx manager vault registry**.  
2. Wire **one** backing `IStandardExchange` + **one** reserve CP buffer hook (raw = DETF, pair = `pairToken`).  
3. **Permissionless first bond** at `creationPairPerDetfWad` → `isReserveLive`; MINIMUM_LIQUIDITY edge.  
4. **Primary mint** (live): settle to pair → seigniorage quote/split → `depositSingle(pair)` protocol LP; **Policy debt-inclusive** mint gate; **no** expansion realize.  
5. **Primary burn**: free DETF → **pair only**; `lpOut = detfBurned * protocolLp / (totalSupply + pending)`; debt-inclusive burn gate; **no** expansion realize.  
6. **Bond after live**: **no** synthetic mint gate; proportional deposit; LP on bond NFT; **realizes** expansion.  
7. Bond NFT + rebasing claim packages; protocol LP held by **rebasing**; sell → claim; claim redeem pair / share / SE token.  
8. **Protocol compound** single-sided DETF → protocol LP (best-effort lazy + public).  
9. **Epoch natural expansion** (Policy): deploy-time epoch length + `R`; unlimited whole-epoch catch-up; pending in synthetic; realize only on bond / claimRewards / compound.  
10. Production-first tests: hermetic + at least one fork profile; **gentle + launch-rich** expansion matrix equal priority; no SUT mocks.

### Non-goals (v1)

- Implementing the reserve hook inside this package.  
- Listing dual-OOR / TWAP / hooks=0 topology.  
- Subclassing Balancer Single SE contracts.  
- Multi-vault / multi-SE composition.  
- Fee-oracle expansion params.  
- Year-long constant 3–4 digit APY marketing.  
- Permit2 on DETF surface (optional later).  
- Full shared-PRD migration of all Balancer families (plan amendment; may ship epoch lib usable by peers).

---

## 2. Hard gates & dependencies

| Gate | Requirement |
|------|-------------|
| **G0 Hook** | Hook deposit / depositSingle / withdraw / withdrawSingle / LP ERC-20 / preview zap-out **ABI frozen** or DoD green for hermetic use |
| **G1 SE** | Backing SE closed-form pair ↔ share routes (hook Phase 0 SE / ERC-4626 wrapper acceptable in hermetic) |
| **G2 Crane** | `CraneTest` → `IndexedexTest` → vault components; create3Factory + diamondPackageFactory |
| **G3 Registry** | DETF DFPkg via `indexedexManager.deploy*DFPkg` / registry path; **never** `new` DFPkg/facets |

**Coding must not invent hook APIs.**

---

## 3. Architecture (implementor map)

### 3.1 Deploy topology

```text
IndexedexManager / Vault Registry
  └── UniswapV4SingleStandardExchangeDETFDFPkg
        postDeploy:
          - deploy/bind reserve hook (create3 FactoryService + HookMiner)
          - poolManager.initialize(sort(DETF, pair), fee=0, hooks=hook)  // plumbing sqrtPrice only
          - deploy bond NFT package (owner=DETF)
          - deploy rebasing claim package (owner=DETF; holds protocol LP)
          - store PkgArgs: SE, pair, creation rate, thresholds, expansion epochs/R, refs
          - validate pair ∈ SE.tokens(); DETF ∉ SE.tokens()

Facets (CREATE3): Info / ExchangeIn / ExchangeOut / Bonding / (Claim surface as needed)
Diamond instance = detfToken ERC-20 (immutable / unowned after deploy)
```

### 3.2 Suggested file map

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/
  standardExchange/constantProduct/single/
    UniswapV4SingleStandardExchangeDETF_PRD.md
    UniswapV4SingleStandardExchangeDETF_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
    interfaces/
      IUniswapV4SingleStandardExchangeDETF.sol          # PkgInit/PkgArgs HERE (Crane rule)
      IUniswapV4SingleStandardExchangeDETFInfo.sol      # optional split
    UniswapV4SingleStandardExchangeDETFRepo.sol
    UniswapV4SingleStandardExchangeDETFCommon.sol
    UniswapV4SingleStandardExchangeDETFInfoTarget.sol
    UniswapV4SingleStandardExchangeDETFExchangeInTarget.sol
    UniswapV4SingleStandardExchangeDETFExchangeOutTarget.sol
    UniswapV4SingleStandardExchangeDETFBondingTarget.sol
    UniswapV4SingleStandardExchangeDETFClaimTarget.sol   # direct claim mint/redeem if not on bonding
    UniswapV4SingleStandardExchangeDETF*Facet.sol
    UniswapV4SingleStandardExchangeDETFDFPkg.sol
    UniswapV4SingleStandardExchangeDETF_Facet_FactoryService.sol
    UniswapV4SingleStandardExchangeDETF_Pkg_FactoryService.sol
    UniswapV4SingleStandardExchangeDETF_Component_FactoryService.sol
    TestBase_UniswapV4SingleStandardExchangeDETF.sol
  common/
    nft/      # LP-principal bond NFT package (adapt common bondNft patterns)
    rebasing/ # claim on protocol hook LP; holds protocol LP
```

Shared (prefer extend, not fork):

| Lib | Use |
|-----|-----|
| `DETFThresholdPolicy` | Policy/Open resolve + gates |
| `DETFUsageFeeLib` / peer mint split | Seigniorage split |
| `DETFBondNFTMathLib` / `DETFBondLifecycleLib` | Lock clamp, bond lifecycle |
| `DETFProtocolCompoundLib` | Compoundable dust helpers |
| `DETFNaturalExpansionLib` | **Extend or add** `DETFEpochNaturalExpansionLib` for whole-epoch pending + mint |

### 3.3 Storage (Repo sketch)

```text
// UniswapV4SingleStandardExchangeDETFRepo layout (names indicative)
isReserveLive
standardExchangeVault / backingVaultShare
pairToken
reserveHook / poolKey or poolManager ref
bondNftVault
rebasingClaimToken / protocolLpHolder (= rebasing)
feeOracle
creationPairPerDetfWad
thresholdMode, mintThreshold, burnThreshold
expansionEpochLength
expansionClosureRatePerYearWad
expansionMaxCatchUpEpochs          // 0 = unlimited
lastExpansionTimestamp             // 0 until first realize-path seed after live
// fee-recipient NFT id wiring as peer
```

Slot form: Crane ERC1967-style `DEFAULT_SLOT = bytes32(uint256(keccak256(abi.encode("…"))) - 1)`.

### 3.4 Public surface (facet split)

| Facet group | Functions (min) |
|-------------|-----------------|
| **Info** | `isReserveLive`, `syntheticPrice` (debt-inclusive), `pendingExpansionDetf`, optional `syntheticPriceSpot`, thresholds, `isMintingAllowed` / `isBurningAllowed`, `creationPairPerDetfWad`, expansion getters, SE/hook/pair getters, `acceptedBondTokens` |
| **ExchangeIn** | Mint DETF from pair/share/SE token; SE passthrough if peer-like |
| **ExchangeOut / burn on In** | Burn DETF → **pair only** (`InvalidRoute` else) |
| **Bonding** | `bond`, maturity close, `sellPositionToDetfNft`, `claimRewards` |
| **Claim** | Direct deposit (pair/share/SE/DETF); redeem claim with tokenOut matrix |
| **Compound** | `compoundProtocolRewards` (+ optional atomic peer if size allows) |

**Errors:** `InvalidRoute`, mint/burn not allowed, reserve not live, lock too short, min out, first-bond below MINIMUM_LIQUIDITY / geometric fail. **No** `UnsupportedRoute`.

---

## 4. Core algorithms (freeze for implementors)

All internal math in **1e18 WAD**; scale at ERC-20 boundary. `YEAR = 365 days`.

### 4.1 Decimal scale

```text
toWad(amount, decimals) / fromWad — use consistent lib helper
creationPairPerDetfWad stored and consumed only in WAD space
```

### 4.2 Debt-inclusive synthetic (PRD §5.5)

```text
fdPairWad = sum over (protocol LP holder + bond NFT + diamond if any)
            of previewZapOutToPair(lp)   // hook preview; exclude address(0) MINIMUM_LIQUIDITY dust

S_spot = (fdPairWad * 1e18 / totalSupply) * 1e18 / creationPairPerDetfWad
         // totalSupply==0 → 1e18

pending = previewPendingExpansionMint()  // §4.5
effectiveSupply = totalSupply + pending
synthetic = (fdPairWad * 1e18 / effectiveSupply) * 1e18 / creationPairPerDetfWad
```

**Gates:** Policy primary mint/burn use `synthetic`. Open: gates always pass when live. First bond: ungated.

### 4.3 Pending expansion preview (PRD §10.2)

```text
previewPendingExpansionMint():
  if !live || Open || lastExpansionTimestamp == 0: return 0
  if now <= last: return 0
  epochs = (now - last) / expansionEpochLength
  if maxCatchUpEpochs > 0: epochs = min(epochs, maxCatchUpEpochs)
  if epochs == 0: return 0
  S_spot = … as above
  if S_spot <= 1e18: return 0
  closurePerEpoch = expansionClosureRatePerYearWad * expansionEpochLength / YEAR
  premium = S_spot - 1e18
  mintPerEpoch = totalSupply * premium * closurePerEpoch / (1e18 * S_spot)
  mint = mintPerEpoch * epochs
  return mint <= dust ? 0 : mint
```

### 4.4 Realize expansion (bond / claimRewards / compound only)

```text
_realizeExpansionIfNeeded():
  if !live || Open: return
  if last == 0:
    last = now; return   // seed after live; no pre-live backlog
  pending = previewPendingExpansionMint()
  if pending == 0: return
  _mintDetf(bondNftVault, pending)  // reward ledger sink
  epochs = … same as preview …
  last += epochs * expansionEpochLength
  // then bond vault reward update sees balance ↑
```

**Forbidden on primary mint/burn:** `_realizeExpansionIfNeeded` and any advance of `lastExpansionTimestamp`.

### 4.5 Seigniorage mint split (peer)

```text
pairBoosted = pairNotional * (1e18 + seigniorageIncentive) / 1e18
gross = quoteDetfAgainstReserve(pairBoosted)   // closed form vs live effective reserves
feeTo = gross * usageFee / 1e18
afterFee = gross - feeTo
inventory = afterFee * (seigniorageIncentive / 2) / 1e18
user = afterFee - inventory
```

**Live primary mint:** `depositSingle(pair)` → protocol LP holder; mint free user/feeTo/inventory only (no DETF self-leg join).  
**Bond:** mint join DETF + free legs; proportional `deposit(joinDetf, pair)`; LP → bond NFT.  
**First bond:** join DETF from **creation rate** (boosted notional); synthetic ungated; set live.

### 4.6 `quoteDetfAgainstReserve` (economic shape)

- Live: closed-form DETF out for exact-in **pair** notional against hook **effective reserves** (raw DETF face × SE claim in pair), fee-aware as ConstProd / hook math requires.  
- **Not** creation rate after live; **not** tick-walk.  
- Single preview path shared by mint/bond quotes.  
- Freeze fixed-point in Phase B against hook `preview` / math libs; document ≤ few-wei if SE dust forces it.

### 4.7 Primary burn (PRD §5.6)

```text
// no expansion realize
require live + debt-inclusive burn gate (Open: when live)
pending = previewPendingExpansionMint()
effectiveSupply = totalSupply + pending
lpOut = detfBurned * protocolLp / effectiveSupply
burn DETF
withdrawSingle(lpOut, pairToken) → user
// tokenOut != pair → InvalidRoute
```

### 4.8 Bond after live

- **No** Policy/synthetic mint gate.  
- Call `_realizeExpansionIfNeeded` then reward update.  
- Proportional join; LP on NFT; lock clamp (revert &lt; min, clamp to max).  
- `effectiveShares` = pair principal × lock bonus only.

### 4.9 Claim

- Protocol LP on rebasing package.  
- Mint claim from zap-out-to-pair contribution; no seigniorage on free DETF / new money deposit.  
- Redeem: `lpOut = shares * protocolLp / claimSupply`; pay pair / vaultShare / SE token; else `InvalidRoute`.

### 4.10 Protocol compound

```text
compoundProtocolRewards():
  _realizeExpansionIfNeeded()   // public compound IS a realize path
  update bond rewards
  harvest protocol NFT pending free DETF (best-effort)
  depositSingle(DETF) on hook → protocol LP ↑
  no new claim shares
```

Lazy: on bond / claimRewards after realize; **not** on primary mint/burn.

### 4.11 PkgArgs resolve

| Arg | `0` resolves to |
|-----|-----------------|
| `expansionEpochLength` | `8 hours` |
| `expansionClosureRatePerYearWad` | `0.10e18` (10% premium/yr) |
| `expansionMaxCatchUpEpochs` | `0` (unlimited) |
| thresholds | `DETFThresholdPolicy` defaults (1.05e18 / 0.95e18) |
| thresholdMode | Policy if omitted/zero |

Launch-rich templates set explicit `R` (e.g. `4.4e18` for ~1y walk from S≈5) — see PRD §10.4.

---

## 5. Phased implementation

### Phase 0 — Dependency readiness (no DETF product logic)

| ID | Work | Exit |
|----|------|------|
| 0.1 | Confirm hook TestBase can deposit/withdraw/zap + LP for a mintable raw + pair + wrapper SE | Green hermetic hook tests used by DETF TestBase |
| 0.2 | Document hook selectors/ABI surface consumed by DETF | Checklist in TestBase comments |
| 0.3 | Confirm SE `pair ∈ tokens()` validation pattern | Reuse in DFPkg postDeploy |

**Do not** start Phase 1 DETF diamond until 0.1 is usable in-process.

### Phase 1 — Scaffold + deploy path

| ID | Work | Exit |
|----|------|------|
| 1.1 | Interfaces with **`PkgInit` / `PkgArgs` on interface** | Compiles |
| 1.2 | Repo + Common stubs | Compiles |
| 1.3 | Facets + FactoryService deploy paths (CREATE3) | Facet registry labels |
| 1.4 | DFPkg + manager `deploy*DFPkg` + `postDeploy` wiring (hook, pool init plumbing, children) | Inert instance deployable |
| 1.5 | TestBase: `CraneTest` → `IndexedexTest` → … → deploy DFPkg | `test_deploy_inert` green |

### Phase 2 — First bond → live

| ID | Work | Exit |
|----|------|------|
| 2.1 | Bond NFT package (LP principal) under `uniswap/v4/common/nft/` | Create position with LP |
| 2.2 | First bond: creation-rate join + free legs + LP on NFT + `isReserveLive` | Permissionless first bond green |
| 2.3 | Pre-live: primary mint/burn revert; non-first bond revert | Spec green |
| 2.4 | MINIMUM_LIQUIDITY / dust first bond reverts clearly | Spec green |

### Phase 3 — Primary mint / burn + seigniorage

| ID | Work | Exit |
|----|------|------|
| 3.1 | `quoteDetfAgainstReserve` + split | Unit/integration vs hook state |
| 3.2 | Live primary mint path | Preview == execution |
| 3.3 | Primary burn pair-only + effectiveSupply | Preview == execution; non-pair `InvalidRoute` |
| 3.4 | Debt-inclusive gates for mint/burn (Open matrix) | Spec green |
| 3.5 | After first bond only: burn reverts (no protocol LP) | Spec green |
| 3.6 | Primary mint/burn **do not** change `lastExpansionTimestamp` / mint expansion | Explicit asserts |

### Phase 4 — Bond lifecycle + claim

| ID | Work | Exit |
|----|------|------|
| 4.1 | Second+ bond: **no** synthetic gate; realize expansion; LP on NFT | Spec green |
| 4.2 | Lock clamp; claimRewards free DETF | Spec green |
| 4.3 | Maturity: pair-only | Spec green |
| 4.4 | Sell → protocol LP + claim mint | Spec green |
| 4.5 | Rebasing package holds protocol LP; direct claim deposits | Spec green |
| 4.6 | Claim redeem pair / share / SE token | Spec green |
| 4.7 | Fee-recipient NFT like peer | Spec green |

### Phase 5 — Epoch expansion + compound

| ID | Work | Exit |
|----|------|------|
| 5.1 | Epoch expansion lib (shared or family) + storage | Pure unit tests on formula |
| 5.2 | `pendingExpansionDetf` + debt-inclusive `syntheticPrice` | Warp time without realize → synthetic falls |
| 5.3 | Realize on bond / claimRewards / compound only | Cross-path matrix |
| 5.4 | `compoundProtocolRewards` best-effort join | Spec green |
| 5.5 | **Gentle** and **launch-rich** PkgArgs matrix rows equal priority | Both green |
| 5.6 | Open never expands; Policy only | Spec green |

### Phase 6 — Hardening

| ID | Work | Exit |
|----|------|------|
| 6.1 | Fork TestBase (Base and/or Robinhood 4663 as available) | Smoke + one full lifecycle |
| 6.2 | Adversarial: reentrancy `IsLocked`; donation notes; empty protocol burn | Spec green |
| 6.3 | Price movement under **default** thresholds via real trades + dilution | Spec green |
| 6.4 | Residual free inventory zero where peers require | Spec green |
| 6.5 | Size / forge build | Facets within project limits |

### Phase 7 — Docs / shared law follow-through

| ID | Work | Exit |
|----|------|------|
| 7.1 | Patch shared expansion PRD when epoch form is adopted for all families | PR open or merged |
| 7.2 | PRD LOCK stamp if product signs off | Status LOCK |
| 7.3 | Optional: handoff note for UI (APY honesty, debt-inclusive synthetic) | Doc only |

---

## 6. Testing plan

### 6.1 Test layout

```text
contracts/.../constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol

test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/
  UniswapV4SingleStandardExchangeDETF_Deploy.t.sol
  UniswapV4SingleStandardExchangeDETF_FirstBond.t.sol
  UniswapV4SingleStandardExchangeDETF_MintBurn.t.sol
  UniswapV4SingleStandardExchangeDETF_Bond.t.sol
  UniswapV4SingleStandardExchangeDETF_Claim.t.sol
  UniswapV4SingleStandardExchangeDETF_Expansion.t.sol
  UniswapV4SingleStandardExchangeDETF_Compound.t.sol
  UniswapV4SingleStandardExchangeDETF_Adversarial.t.sol   # or under adversarial path

test/foundry/fork/.../uniswap/v4/standardExchange/constantProduct/single/
  UniswapV4SingleStandardExchangeDETF_Fork.t.sol
```

### 6.2 TestBase requirements

- Inherit production ladder (`CraneTest` → `IndexedexTest` → vault/hook SE bases as needed).  
- Deploy real DFPkg via **manager registry**; real hook; real SE (wrapper hermetic).  
- Helpers: fund pair/share; firstBond; warp epochs; read `syntheticPrice` / pending / protocol LP; assert preview==exec.  
- **Two expansion configs** as first-class:
  - **Gentle:** epoch 8h (or 0→default), `R=0`→10%/yr  
  - **Launch-rich:** epoch 8h, `R=4.4e18`  

### 6.3 Spec matrix (minimum)

| Area | Cases |
|------|--------|
| Deploy | Inert; getters; pair validation fail; DETF-in-SE tokens fail |
| First bond | Live; mid≈creation; free legs split; LP on NFT; second pre-live bond reverts; dust revert |
| Mint | Debt-inclusive gate; Open; preview==exec; inventory to bond vault; **lastExpansion unchanged** |
| Burn | Pair only; effectiveSupply; empty protocol LP revert; non-pair InvalidRoute; **lastExpansion unchanged** |
| Bond live | No synthetic gate; realize expansion; claimRewards; lock clamp; maturity pair-only; sell→claim |
| Claim | Free DETF depositSingle; pair zap-in; redeem matrix; InvalidRoute |
| Expansion | Pending accrual warps synthetic; realize paths only; Open never; dual R matrix; seed last |
| Compound | Protocol LP ↑; best-effort failure; public compound realizes expansion |
| Adversarial | Nested reentrancy IsLocked; donation awareness |

### 6.4 Commands (indicative)

```bash
forge test --match-path 'test/foundry/spec/**/constantProduct/single/**' -vv
forge test --match-contract UniswapV4SingleStandardExchangeDETF -vv
# fork when ready:
forge test --match-path 'test/foundry/fork/**/constantProduct/single/**' -vv
```

---

## 7. Anti-patterns (reject in review)

| Anti-pattern | Correct |
|--------------|---------|
| `new` facet / DFPkg | CREATE3 FactoryService + manager registry |
| Subclass Balancer Single SE | Fresh codepath + shared libs |
| Implement dual-OOR listing PRD | This constantProduct family only |
| Invent hook methods | Call hook PRD surface only |
| `UnsupportedRoute` | `InvalidRoute` |
| Policy-gate second bond | Bonds ungated when live |
| Realize expansion on primary mint/burn | Only bond / claim / compound |
| Burn uses on-chain supply only | `effectiveSupply = totalSupply + pending` |
| Synthetic ignores pending | Debt-inclusive for gates |
| Expansion params on fee oracle | Deploy-time PkgArgs only |
| Mock DETF/manager/registry/hook under test | Production deploy path |
| Single expansion TestBase only | Gentle **and** launch-rich equal rows |

---

## 8. Definition of Done (product + engineering)

- [x] Phases 0–6 hermetic (product path) green under `FOUNDRY_PROFILE=uv4_single_se_cp_detf`  
- [ ] At least one fork lifecycle smoke green (or documented env block) — **deferred** (Phase 6.1 / Phase 7 follow-through)  
- [x] PRD §15 testing expectations covered for hermetic matrix (custody, Policy both regimes, compound, fee NFT, realize paths)  
- [x] Preview == execution on closed-form mint/burn routes  
- [x] Debt-inclusive synthetic + realize-path matrix proven  
- [x] No SUT mocks; CREATE3 + registry path only  
- [x] Facet sizes acceptable under dedicated profile  
- [x] PRD conflict check: physical LP custody matches v0.5 LOCK (see Deviations)  

---

## 9. Suggested work ordering for agents

1. Phase 0 hook readiness in TestBase.  
2. Phase 1 scaffold + inert deploy.  
3. Phase 2 first bond.  
4. Phase 3 mint/burn (before expansion).  
5. Phase 4 bond/claim (realize hooks stubbed then wired).  
6. Phase 5 expansion lib + compound.  
7. Phase 6 adversarial + fork.  
8. Phase 7 shared-law note.

Prefer vertical slices with tests at each phase exit over big-bang coding.

---

## 10. Implementation status (hermetic)

| Phase | Status | Evidence |
|-------|--------|----------|
| 0 | [x] | Hook TestBase + SE wrapper reused |
| 1 | [x] | Inert deploy; feeRecipientNftId != 0 when default bond terms set pre-deploy |
| 2 | [x] | First bond → live; LP physically on bond NFT |
| 3 | [x] | Mint/burn preview==exec; empty protocol LP after first-bond-only reverts |
| 4 | [x] | Sell migrates LP NFT→claim; redeemClaim pulls protocol LP from claim |
| 5 | [x] | Epoch lib units; compound assertGt protocol LP on claim after forced inventory |
| 6.2–6.3 | [x] | Adversarial IsLocked + physical partition; Policy mint+burn regimes via real depth/skew |
| 6.1 fork | [ ] | Deferred |

**Verification command:**
```bash
FOUNDRY_PROFILE=uv4_single_se_cp_detf forge test \
  --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/*' -vv
```
**Last run:** 38 passed / 0 failed (hermetic suite).

---

## 11. Deviations (honest)

| Area | Plan / PRD intent | Shipped | Why |
|------|-------------------|---------|-----|
| **Physical LP custody** | Protocol LP on rebasing; user bond LP on bond NFT | **Shipped** | `transferHeldToken` on claim + bond NFT; mint/compound → claim; bond join → bond NFT; sell migrates NFT→claim; burn/redeem/claimLiquidity pull then withdraw |
| **convertToAssets** | NFT convert used diamond `reserveOfToken` only | **Updated** | Prefer NFT `balanceOf`; exclude protocol NFT effective shares when LP is physically on NFT (protocol LP on claim) |
| **Fee-recipient NFT** | Soft try/catch → 0 if bond terms missing | **Still soft at deploy** | postDeploy still try/catch (no hard revert if feeTo/terms missing). **TestBase sets `setDefaultBondTerms` before first deploy** and hermetic asserts `feeRecipientNftId() != 0` |
| **Foundry profile** | Default monorepo build | **`uv4_single_se_cp_detf`** | Default profile has pre-existing stack-too-deep elsewhere; dedicated profile for this family |
| **Fork (6.1)** | Required DoD | **Deferred** | Hermetic product path complete; fork smoke is follow-through |
| **Bond NFT path** | Plan mentioned `uniswap/v4/common/nft/` | Uses shared `detf/common/bondNft` + claim packages | Same packages as peers; Uni family wires via DFPkg postDeploy |
| **Policy price test** | Real trades for both regimes | **Shipped** | Pair single-sided deposit raises synthetic; free seigniorage + external DETF deposit skew lowers it; Open is not used as sole mint/burn proof |

**Previously rejected incomplete states (do not reintroduce):**
- `_protocolLpHolder() = address(this)` diamond-only custody  
- Policy mint proven only on Open  
- Compound test that passes when `detfIn == 0`  
- `feeRecipientNftId` left 0 with no hermetic assert  

---

## 12. Revision history

| Version | Date | Notes |
|---------|------|-------|
| v0.1 | 2026-08-04 | Initial plan against PRD v0.5: phases, algorithms, file map, test matrix, gates |
| v0.2 | 2026-08-05 | Hermetic Phases 0–6 product path complete; physical LP custody; Policy both regimes; forced compound; fee NFT assert; honest deviations |

---

## 13. Acceptance

| Role | Sign-off |
|------|----------|
| Product | Pending (PRD v0.5+) |
| Protocol / implementor | Hermetic product path complete under profile; fork deferred |

**Status:** Hermetic Phases 0–6 (ex-fork) implemented and green under `FOUNDRY_PROFILE=uv4_single_se_cp_detf`.
