# S3 Design Surfaces: Morpho Borrow → Uniswap V4 SE LP

**Date:** 2026-08-02  
**Status:** Design brief (pre-PRD) — lists what must be designed before implementation  
**Strategy ID:** **S3 / F1 / Template T1**  
**One-liner:** Strategy vault posts Morpho Blue collateral, borrows a loan asset, deploys proceeds (with user equity) into a Uni V4 Standard Exchange LP position; user holds strategy equity shares.

**Prerequisite (done / out of this brief):** S0 Morpho ERC-4626 wrap + V4 buffer/pricing hook (claim-rate surface only).

**Research basis:**

- [`2026-08-02-morpho-uniswap-lending-mm-strategies.md`](./2026-08-02-morpho-uniswap-lending-mm-strategies.md)  
- [`2026-08-02-morpho-uniswap-strategy-explanations.md`](./2026-08-02-morpho-uniswap-strategy-explanations.md)  
- [`2026-08-02-lending-cl-mm-protocol-process-research.md`](./2026-08-02-lending-cl-mm-protocol-process-research.md) §5.1 Template T1  
- **DFPkg PkgInit/PkgArgs/validation sketch:** [`2026-08-02-s3-dfpkg-pkgargs-interface-sketch.md`](./2026-08-02-s3-dfpkg-pkgargs-interface-sketch.md)

**Explicit non-goals (v1):** S4 (SE as Morpho coll), S5 (Morpho V2 Uni adapter host), S6 (Fluid unified), buffer-hook changes, DETF composition of the strategy diamond.

---

## 1. What we are building (scope picture)

```text
User
  │  deposit equity (coll token and/or loan token / pair tokens)
  ▼
┌─────────────────────────────────────────────────────────────┐
│  S3 Strategy Vault (NEW — IndexedEx diamond DFPkg)          │
│  • mints strategy ERC-20 equity shares                      │
│  • holds: Uni V4 SE shares + optional idle tokens           │
│  • Morpho: supplyCollateral + borrow + repay + withdrawColl │
│  • enforces min HF (strategy equity + Morpho plane)         │
└───────────────┬─────────────────────────────┬───────────────┘
                │                             │
                ▼                             ▼
     Morpho Blue market              Uni V4 Standard Exchange
     collToken / loanToken           (existing DFPkg instance)
     oracle / irm / lltv             managed CL position → SE shares
```

**Reuse, do not rebuild:** Morpho Blue (Crane), Uni V4 SE package, vault registry deploy path, fee oracle patterns from peer SEs.

**Must invent:** strategy shell, equity accounting, open/close/delever/liquidate flows, dual-HF policy, rebalance gates, TestBase + specs.

---

## 2. Design surfaces (checklist)

Each surface must land as **locked product law** in a PRD before implementation. Suggested defaults are recommendations, not locks.

### 2.1 Product identity

| # | Design item | Options | Suggested default | Why |
|---|-------------|---------|-------------------|-----|
| P1 | Strategy name / package path | e.g. `contracts/vaults/strategies/morpho/uniswap/v4/…` | New tree under `vaults/strategies/` (not under DETF; not under hooks) | Avoids DETF law; not a true DETF |
| P2 | Primary thesis | fee-first vs carry (borrow APR &lt; fee APR) | **Fee-first with max borrow APR kill** | Clear kill criterion |
| P3 | User-facing asset | multi-token deposit vs single-token zap | **Single-token equity in (coll or loan) + optional second** | UX; flash for the rest |
| P4 | Leverage model | fixed target LTV / target HF / max only | **Target Morpho HF band + hard max LTV buffer under LLTV** | Homora/Revert lesson |
| P5 | Share model | pooled ERC-20 vs per-user position NFT | **Pooled ERC-20 strategy shares (v1)** | Simpler accounting/gas |
| P6 | Instance binding | one Morpho market + one Uni V4 SE per instance | **Yes — immutable at deploy** | Same spirit as hook D16 |
| P7 | Chains v1 | RH / Base / ETH | **Pin one fork DoD chain first** (Base or RH with Morpho+Uni V4) | Avoid dual-chain ambiguity |

### 2.2 Morpho market design

| # | Design item | Must specify |
|---|-------------|--------------|
| M1 | `MarketParams` | `loanToken`, `collateralToken`, `oracle`, `irm`, `lltv` — existing market vs createMarket |
| M2 | Coll token | Which ERC-20 (e.g. WETH, wstETH) — **not** Uni SE shares in S3 |
| M3 | Loan token | Must be useful for the Uni pool (usually one pool currency, e.g. USDC) |
| M4 | Who supplies loan liquidity | External Morpho suppliers; strategy does not need to supply loan side |
| M5 | Authorization | Strategy diamond is borrower (`onBehalf` self); no user Morpho positions in v1 pooled model |
| M6 | Interest | When accrue is observed; share price includes accrued debt |
| M7 | Morpho liquidation | External liquidators may seize **coll only** — product must define cleanup if Morpho liquidates under strategy |

**Lock:** S3 never lists Uni V4 SE as Morpho `collateralToken` (that is S4).

### 2.3 Uni V4 SE (LP leg) design

| # | Design item | Must specify |
|---|-------------|--------------|
| U1 | SE instance | Deployed Uni V4 SE for fixed `PoolKey` + width policy |
| U2 | Range policy v1 | **Fixed ticks / width at SE deploy** vs rebalancing ALM |
| U3 | Routes used | Which `exchangeIn` / zap paths strategy may call (closed-form only) |
| U4 | Preview fidelity | Strategy open/close previews vs SE preview; dust policy |
| U5 | Who deploys SE | Strategy deploy script vs pre-existing SE address in `PkgArgs` |
| U6 | SE fees | Usage fees on SE mint must appear in strategy NAV / previews |

**Suggested default U2:** fixed range v1 (no keeper ALM) — rebalance is a later PRD; under leverage it changes HF.

### 2.4 Equity accounting & NAV

| # | Design item | Must specify |
|---|-------------|--------------|
| E1 | Gross assets | Mark of SE shares + idle tokens (how marked?) |
| E2 | Debt | Morpho borrow assets (accrued) in loan-token terms |
| E3 | Equity | `max(gross − debt, 0)` or insolvency halt rules |
| E4 | Share price | `equity / totalSupply` (inflation/donation policy on empty vault) |
| E5 | Deposit mint | Shares from equity delta after open (or preview-then-execute) |
| E6 | Withdraw burn | Pro-rata delever + exit; or queue equity withdraw with HF check |
| E7 | Fee model | Usage fee on mint? performance fee? none in v1? |
| E8 | Fee type / oracle | New `VaultFeeType` vs reuse USAGE/LENDING; feeTo path |

**Suggested default E7:** align with peer SE dilution mint on share-minting only if registry requires; else zero performance fee v1.

**Critical:** Define mark of SE shares (E1) — composition of underlyings × price sources vs SE-internal convert. Manipulation and OOR inventory must be specified.

### 2.5 Dual health planes (product law)

| Plane | Definition | Gates |
|-------|------------|-------|
| **Morpho HF** | Morpho coll value × LLTV vs debt | Max borrow; Morpho liquidate risk |
| **Strategy equity HF** | equity / gross or equity / debt style ratio | User withdraw; rebalance; strategy liquidate |

| # | Design item | Must specify |
|---|-------------|--------------|
| H1 | minMorphoHf / maxLtv vs LLTV | Buffer (e.g. never borrow above X% of max) |
| H2 | minStrategyHf | Below this → public delever / liquidate |
| H3 | Authoritative plane for withdraw | Usually both must pass after withdraw |
| H4 | Behavior if Morpho liquidates coll | Strategy may retain SE + residual debt? Forced SE sell? Pause? |
| H5 | Behavior if strategy equity &lt; 0 | Halt deposits; liquidate path; bad debt socialize? |

### 2.6 Open / increase leverage process

Design the exact state machine (atomic preferred):

```text
OPEN (user deposit → strategy shares)
  1. Pull user equity tokens
  2. Optional: flash loan loanToken
  3. Morpho.supplyCollateral(coll)
  4. Morpho.borrow(loan) up to policy cap
  5. Swap/zap as needed to SE deposit proportions
  6. SE.exchangeIn / mint SE shares to strategy
  7. Repay flash if any
  8. Require morphoHf ≥ minMorphoHf && strategyHf ≥ minStrategyHf
  9. Mint strategy shares to user
```

| # | Design item | Options | Suggested default |
|---|-------------|---------|-------------------|
| O1 | Atomicity | Multicall / Morpho flash / external flash | **Morpho `flashLoan` or Bundler3-style single tx** |
| O2 | Target leverage | User-chosen vs instance fixed | **Instance deploy-time target + user cannot exceed max** |
| O3 | Increase leverage later | `leverageUp` vs deposit-only | **deposit re-targets band; optional `leverageUp` v1.1** |
| O4 | Slippage | minOut on SE / swaps | **Caller supplies limits; strategy passes tight previews** |
| O5 | Empty vault / first deposit | Donation inflation | Peer SE first-deposit law; do not invent weaker rules |

### 2.7 Exit / delever / repay process

```text
EXIT (burn strategy shares → tokens out)
  1. Burn shares; compute pro-rata claim on equity
  2. Redeem SE shares → underlyings (partial)
  3. Swap to loanToken as needed
  4. Morpho.repay (pro-rata debt)
  5. Morpho.withdrawCollateral (pro-rata free coll)
  6. Return residual tokens to user (define payout token basket or zap to one)
  7. Require remaining position still healthy OR fully closed
```

| # | Design item | Must specify |
|---|-------------|--------------|
| X1 | Payout asset | Multi-token residual vs zap to single asset |
| X2 | Partial withdraw | Maintain leverage band vs proportional scale of coll+debt+SE |
| X3 | Full close dust | Max dust debt / residual SE |
| X4 | Order of operations | Redeem SE before repay vs flash repay first |
| X5 | Public `deleverTo(hf)` | Permissionless maintain |

**Suggested default X2:** proportional scale of SE, debt, and Morpho coll so leverage stays roughly constant on partial exit.

### 2.8 Liquidation & emergency

| # | Design item | Must specify |
|---|-------------|--------------|
| L1 | Strategy liquidate trigger | strategyHf &lt; threshold |
| L2 | Who can call | Permissionless with incentive |
| L3 | Incentive | % of residual equity / fixed bonus from position |
| L4 | Path | Forced full or partial close (same as EXIT) |
| L5 | Morpho liquidate coexistence | If Morpho seizes coll, strategy may be undercollateralized on Morpho while still holding SE — **recovery function** |
| L6 | Pause | Pause deposits / leverageUp only; always allow delever/exit? |
| L7 | Oracle failure | Revert open; allow delever with conservative marks? |

### 2.9 Maintain / rebalance (v1 scope)

| # | Design item | Suggested v1 |
|---|-------------|--------------|
| R1 | Uni range rebalance | **Out of scope** (fixed SE range) |
| R2 | Compound SE fees | If SE auto-compounds into position, NAV rises; no extra action |
| R3 | Interest accrual poke | View-based on Morpho; optional public accrue |
| R4 | Re-center leverage band | Public `rebalanceLeverage` if drift from target HF |
| R5 | Rate inversion kill | If borrow APR &gt; threshold, block leverageUp; allow only delever |

### 2.10 Package / architecture (Crane + IndexedEx)

| # | Design item | Must specify |
|---|-------------|--------------|
| A1 | Package kind | Vault DFPkg via **manager registry** (not bare `new`) |
| A2 | Facets | CREATE3 + FactoryService |
| A3 | PkgInit / PkgArgs | On **interface** (Crane rule) |
| A4 | Immutables / Repo | Morpho, market id/params, SE, coll, loan, HF params |
| A5 | Access | Unowned immutable instance after deploy vs owner for pause only |
| A6 | Morpho integration | `MorphoBlueService` / direct `IMorpho` from diamond context |
| A7 | Approvals | Morpho + SE + Permit2 policy (v1: standard approve from diamond) |
| A8 | Reentrancy | Diamond/SE/Morpho lock consistency |
| A9 | Interface surface | `deposit`, `withdraw`, `preview*`, `leverage` views, `delever`, `liquidate`, getters for HF/NAV |
| A10 | Registry / fee type | Vault type id; discovery via manager |

**Anti-patterns:** mock Morpho/SE SUT; bypass registry for vault DFPkg; subclass DETF packages; put strategy logic in buffer hook.

### 2.11 Oracles & pricing (S3-specific)

S3 does **not** need Morpho oracle for SE shares, but needs:

| # | Design item | Purpose |
|---|-------------|---------|
| Q1 | Morpho market oracle | Already on `MarketParams` for coll |
| Q2 | Strategy equity mark | SE share → value in numeraire (loan or USD) |
| Q3 | SE mark method | Redeem simulation / pro-rata balances × leg oracles / TWAP |
| Q4 | Leg price sources | Which oracles for pool tokens (if not same as Morpho) |
| Q5 | Manipulation bounds | Same-block LP skew; deposit inflation |
| Q6 | Numeraire | Loan token vs coll vs USD |

**Suggested default:** mark SE via **preview redeem** of pro-rata SE to underlyings + trusted leg oracles (or SE-documented convert); never spot-only from a single thin pool without bounds.

### 2.12 Deploy-time parameters (`PkgArgs` sketch)

Design the struct fields explicitly (names illustrative):

```text
PkgArgs {
  address morpho;
  MarketParams market;          // or bytes32 marketId + stored params
  address uniV4Se;              // IStandardExchange / vault
  address collateralToken;      // must match market.collateralToken
  address loanToken;            // must match market.loanToken
  uint256 targetLtvWad;         // or target health factor
  uint256 maxLtvWad;            // < Morpho LLTV
  uint256 minStrategyHfWad;
  uint256 liquidationStrategyHfWad;
  uint256 minMorphoHfWad;
  // fee / oracle hooks if any
  // salt namespace if CREATE3 instance helpers
}
```

Validation: non-zero addresses; coll/loan match market; maxLtv &lt; lltv; minHf consistent; SE.vaultTokens contains required legs.

### 2.13 Testing design (DoD before “done”)

| # | Suite | Must prove |
|---|-------|------------|
| T1 | Hermetic Morpho + Uni V4 ports | Open, partial withdraw, full close |
| T2 | Interest accrual | Debt up → share price down (or equity mark) |
| T3 | Preview == execution | Closed-form legs (± dust policy) |
| T4 | HF gates | Cannot open above maxLtv; withdraw blocked if breaches minHf |
| T5 | Strategy liquidate | Crash SE mark / underlyings → liquidate profitable for caller |
| T6 | Morpho liquidate coexistence | Coll seized → recovery / halt behavior |
| T7 | Reentrancy | Hostile ERC20 as configured token only if needed |
| T8 | Fork | Real Morpho market + real Uni V4 pool on chosen chain |
| T9 | Production-first | No mock Morpho/SE/manager; CREATE3 + registry path |

Inherit: `CraneTest` → `IndexedexTest` → Morpho TestBase + Uni V4 SE TestBase → `TestBase_S3…`.

### 2.14 Security / threat model (design, not code)

| Threat | Mitigation to design |
|--------|----------------------|
| Morpho liquidate leaves orphan SE | Recovery path L5 |
| NAV manipulation via donation / first depositor | Empty vault law E5/O5 |
| Same-tx LP + mark manipulation | Oracle bounds Q5; atomic open after SE mint order |
| Rebalance MEV (if ever added) | Out of v1 |
| Rate inversion | R5 kill switch |
| Share inflation on insolvency | E3 halt rules |
| Approval griefing | Exact approve / forceApprove patterns |
| Flash loan reentrancy | Checks-effects + SE/Morpho locks |

### 2.15 UX / integrator surface

| # | Design item |
|---|-------------|
| I1 | View: `nav()`, `sharePrice()`, `morphoHf()`, `strategyHf()`, `targetLtv()`, positions breakdown |
| I2 | Preview: `previewDeposit`, `previewWithdraw` |
| I3 | Events: Deposit, Withdraw, Borrow, Repay, Liquidate, Delever |
| I4 | Frontend: single “supply & leverage” vs advanced breakdown |
| I5 | Relation to S0 hook | Optional: users acquire Morpho/SE legs elsewhere; strategy does not require buffer hook |

### 2.16 Ops & governance

| # | Design item | Suggested v1 |
|---|-------------|--------------|
| G1 | Instance upgradeability | **Immutable unowned** after deploy (DETF-like) |
| G2 | Parameter changes | Deploy-time only; bad config → abandon instance |
| G3 | Keeper requirement | Optional public delever; no required keeper for v1 fixed range |
| G4 | Emergency | Pause deposits if owner exists; prefer immutable + public liquidate |

---

## 3. Design work order (dependency order)

Do not implement until **gates** below are locked in a PRD.

```text
Phase A — Product locks (1–2 pages)
  P1–P7, pair (coll, loan, Uni pool), chain, pooled shares, target/max LTV

Phase B — Economic & risk law
  E1–E8, H1–H5, Q1–Q6, R5, L1–L7

Phase C — State machines
  Open O1–O5, Exit X1–X5, Liquidate L*, Maintain R*

Phase D — Package architecture
  A1–A10, PkgArgs, interface, deploy validation

Phase E — Test & threat DoD
  T1–T9, security table

Phase F — PRD freeze → implementation
```

---

## 4. Minimum decision set to start the PRD

Answer these twelve; the rest of the brief can fill in with defaults:

1. **Chain + Morpho market** (coll, loan, existing market address/params)  
2. **Uni V4 pool + SE instance** (or deploy-with-strategy)  
3. **Target leverage / max LTV / min strategy HF** (numbers)  
4. **Pooled ERC-20 shares** (confirm)  
5. **User deposit tokens** (coll only / loan only / either / both)  
6. **Withdraw payout** (multi-token vs single-asset zap)  
7. **Atomic open via Morpho flash?** (yes/no)  
8. **Range rebalance v1?** (no recommended)  
9. **Strategy liquidate incentive**  
10. **Morpho liquidate recovery behavior**  
11. **Fee model v1**  
12. **Package path + immutable unowned?**  

---

## 5. What we do *not* need to design for S3 v1

| Skip | Why |
|------|-----|
| Morpho oracle for SE shares | SE is inventory, not Morpho coll |
| Morpho Vault V2 adapters hosting Uni | S5 |
| Recursive LP coll loop | S4 |
| Fluid liquidity layer | S6 |
| Buffer hook changes | S0 complete |
| DETF bond/claim/seigniorage | Different product |
| Full ALM rebalance under leverage | Later PRD |
| Per-user Morpho positions | Pooled v1 |

---

## 6. Deliverables before coding

| Deliverable | Content |
|-------------|---------|
| **PRD** | Locked decisions from §2 + state machines + non-goals + DoD tests |
| **Interface sketch** | `IMorphoUniswapV4LeveredLp` (name TBD) + errors/events |
| **PkgArgs / deploy validation** | Exact fields + reverts |
| **NAV/HF formulas** | Normative math (WAD) |
| **Sequence diagrams** | Open, partial exit, strategy liq, Morpho liq recovery |
| **TestBase outline** | Inheritance + fixtures (Morpho market, SE, tokens) |
| **Threat model** | §2.14 expanded if high risk |

---

## 7. Changelog

| Date | Change |
|------|--------|
| 2026-08-02 | Initial S3 design-surface brief for Morpho borrow → Uni V4 SE LP |
