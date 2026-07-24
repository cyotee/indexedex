# Lido wstETH Standard Exchange Vault — Implementation and Testing Plan

**Date:** 2026-07-23  
**Status:** IMPLEMENTED (hermetic gating green; mainnet fork optional)  
**Normative product:** [`LIDO_WSTETH_STANDARD_EXCHANGE_VAULT_PRD.md`](./LIDO_WSTETH_STANDARD_EXCHANGE_VAULT_PRD.md)  
**Research:** `docs/research/2026-07-23-ethereum-staking-ported-protocols-custom-se-assessment.md`  

**Methodology skills:** `crane-deployment`, `crane-testing`, `indexedex-testing`, `crane-adversarial-testing`, `indexedex-adversarial-testing`

This plan is ordered for incremental delivery. Each phase leaves a green, reviewable slice. Do not reopen PRD-locked Lido deposit/withdraw constraints or Fee Oracle three-tier cascade without a PRD revision.

---

## 0. Locked decisions (from PRD + this plan)

| Topic | Decision |
|-------|----------|
| Yield asset | **wstETH** (non-rebasing); `IERC4626.asset()` / primary locked asset = wstETH |
| Liquid sleeve | **WETH**; target via Fee Oracle `liquidReservePercentage` (WAD) |
| Oracle API | `defaultLiquidReservePercentage` / `OfTypeId` / `liquidReservePercentageOfVault` |
| Default liquid % | **`0.05e18`** (5%) unless overridden |
| Type id for policy | Vault **usage fee type id** (marker interface id) |
| Primary Lido ETH out | **Async** WithdrawalQueue only; **not** closed-form `exchangeOut` |
| Claim asset | **Native ETH** → vault wraps to **WETH** |
| Insufficient sleeve | **Custom error** with requested + available amounts (see §2.3) |
| SE → Lido queue inside exchangeOut | **Forbidden** (no silent queue) |
| Deploy path | CREATE3 facets + **registry** DFPkg; never `new` SUT |
| SUT mocks | **Forbidden** (Lido, manager, registry, fee oracle, SE diamond) |
| Preview fidelity | Closed-form routes: **preview == execution** (exact; ≤ few-wei only if documented multi-leg force) |

---

## 1. Goals and non-goals

### Goals

1. Implement Fee Oracle **liquid reserve percentage** API end-to-end.  
2. Implement Lido wstETH SE package: In/Out routes, marker, rebalance, multi-bucket NAV.  
3. Prove closed-form routes with **preview == execution**.  
4. Prove **invariant** suite (conservation, sleeve bounds, NAV integrity).  
5. Prove **adversarial** suite (donation, reentrancy, residual inventory, access, grief).  
6. Mainnet **fork** coverage for real Lido + WithdrawalQueue where hermetic is insufficient.

### Non-goals (this plan)

- Secondary-market DEX fallback inside SE.  
- User-facing unstETH NFT product UX (vault-owned NFTs only for rebalance).  
- Exact on-chain withdrawal ETA.  
- DETF composition beyond “opaque SE leg” smoke (optional Phase 7).  
- True 0% liquid via stored `0` without set-flag (document 0=unset; default non-zero).

---

## 2. Error surface (normative)

### 2.1 Insufficient liquid sleeve

Any path that requires **paying or locking WETH from the liquid sleeve** and finds `available < requested` **must** revert with a custom error that logs both values:

```solidity
/// @notice Liquid WETH sleeve cannot satisfy the requested amount.
/// @param requested Amount of WETH required by the operation (wei).
/// @param available Current liquid sleeve balance (WETH.balanceOf(vault), wei).
error InsufficientLiquidReserve(uint256 requested, uint256 available);
```

**Applies to (at minimum):**

- `exchangeOut` / `exchangeIn` when `tokenOut == WETH` (or exact-out WETH paths).  
- Any internal helper `_pullLiquidWeth` / `_requireLiquidWeth`.  
- Previews: **do not gate on liquid sleeve**. Quote against full `totalReserveEth` / closed-form asset rates so clients can price full extractable value. **Execution** of any path that pays WETH reverts `InsufficientLiquidReserve(requested, available)` when the sleeve is short; users catch payability via `eth_call` / simulation, not preview.

**Does not apply to:**

- SE → wstETH when locked inventory is short (use a distinct error, e.g. `InsufficientLockedReserve(requested, available)` if needed).  
- Lido stake-limit failures (bubble Lido / wrap with `StakingPaused` / `StakeLimit` if we add local checks).

### 2.2 Other errors (indicative)

| Error | When |
|-------|------|
| `InvalidRoute` | SE → ETH primary, non-closed-form, unsupported pair |
| `DeadlineExpired` | past deadline |
| `Slippage` / minOut | amountOut &lt; min |
| `ZeroAmount` | zero in/out where forbidden |
| `StakingUnavailable` | optional wrapper when `isStakingPaused` or stake limit 0 blocks stake leg |
| `WithdrawalQueuePaused` | rebalance queue leg when placement paused |
| `RequestAmountBounds` | outside 100 wei–1000 stETH after conversion (or rely on Lido errors) |

---

## 3. Layout

### 3.1 Production sources

```text
contracts/protocols/staking/lido/
  LIDO_WSTETH_STANDARD_EXCHANGE_VAULT_PRD.md
  LIDO_WSTETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
  interfaces/
    ILidoWstETHStandardVault.sol          # marker + views
    ILidoWstETHStandardExchangeDFPkg.sol  # PkgInit / PkgArgs only
  LidoWstETHStandardExchangeRepo.sol      # WETH sleeve, request id set, config addrs
  LidoWstETHStandardExchangeCommon.sol    # NAV, previews, fee, liquid checks
  LidoWstETHStandardExchangeInTarget.sol / InFacet.sol
  LidoWstETHStandardExchangeOutTarget.sol / OutFacet.sol
  LidoWstETHRebalanceTarget.sol / RebalanceFacet.sol
  LidoWstETHMarkerTarget.sol / MarkerFacet.sol
  LidoWstETHStandardExchangeDFPkg.sol
  LidoWstETH_Component_FactoryService.sol
```

### 3.2 Fee Oracle deltas

```text
contracts/interfaces/IVaultFeeOracleQuery.sol      # + liquid reserve queries
contracts/interfaces/IVaultFeeOracleManager.sol    # + setters + events
contracts/oracles/fee/VaultFeeOracleRepo.sol
contracts/oracles/fee/VaultFeeOracleQueryFacet.sol
contracts/oracles/fee/VaultFeeOracleManagerFacet.sol
# DFPkg / diamond cut lists if facetFuncs are static
```

### 3.3 Crane surface (as needed)

```text
lib/crane/.../staking/ethereum/lido/interfaces/   # stake limit views; IWithdrawalQueue
lib/crane/.../staking/ethereum/lido/services/LidoService.sol  # queue + claim + wrap ETH helpers
```

### 3.4 Tests

```text
contracts/test/bases/TestBase_LidoWstETHStandardExchange.sol
# or contracts/protocols/staking/lido/test/bases/...

test/foundry/spec/oracles/fee/
  VaultFeeOracle_LiquidReservePercentage.t.sol

test/foundry/spec/protocol/staking/lido/
  LidoWstETHStandardExchange_Deploy.t.sol
  LidoWstETHStandardExchange_Routes.t.sol
  LidoWstETHStandardExchange_PreviewExecution.t.sol
  LidoWstETHStandardExchange_LiquidSleeve.t.sol
  LidoWstETHStandardExchange_Rebalance.t.sol
  LidoWstETHStandardExchange_Fees.t.sol
  invariant/
    LidoWstETHStandardExchange_Invariant.t.sol
    Handler_LidoWstETHStandardExchange.sol
  adversarial/
    TestBase_LidoWstETHStandardExchange_Adversarial.sol
    Adversarial_Donation.t.sol
    Adversarial_Reentrancy.t.sol
    Adversarial_Accounting.t.sol
    Adversarial_Access.t.sol
    Adversarial_Griefing.t.sol
    Adversarial_SleeveDrain.t.sol

test/foundry/fork/eth_main/vaults/staking/lido/
  LidoWstETHStandardExchange_Fork.t.sol
  LidoWstETHStandardExchange_Rebalance_Fork.t.sol
```

---

## 4. Implementation phases

### Phase 1 — Fee Oracle liquid reserve API

**Deliverables**

- Storage + validate WAD in `VaultFeeOracleRepo`.  
- Query resolution: vault → type (`_usageFeeIdOfVault`) → global.  
- Manager setters + events.  
- Facet function lists updated.  
- Init / migration: global default `0.05e18` (or set in first operator tx documented in tests).

**Tests**

| ID | Case |
|----|------|
| FO-1 | Global only → vault resolves global |
| FO-2 | Type override → vault of that usage type resolves type |
| FO-3 | Vault override wins over type/global |
| FO-4 | Clear vault override (`0`) falls back |
| FO-5 | `> 1e18` reverts `Percentage_ExceedsWAD` |
| FO-6 | Events emit old/new |

**Exit:** `forge test --match-path '**/VaultFeeOracle_LiquidReserve*'`

---

### Phase 2 — Crane Lido surface extensions

**Deliverables**

- Interfaces: stake pause/limit views; WithdrawalQueue request/status/claim/min-max.  
- `LidoService` (or sibling lib): `_requestWithdrawalsWstETH`, `_claim`, `_wrapEthToWeth`.  
- Document mainnet addresses in README (already partially present).

**Tests**

- Unit/domain where possible; fork smoke: submit, wrap, optional small request if funded.

**Exit:** compile + smoke fork optional; not blocking Phase 3 closed-form if queue only used in Phase 4.

---

### Phase 3 — SE package core (deploy + closed-form routes)

**Deliverables**

- Marker `ILidoWstETHStandardVault`.  
- Repo: stETH, wstETH, WETH, withdrawalQueue, fee oracle aware, request id set (empty until Phase 4).  
- Common: multi-bucket **totalReserveEth**, share mint/burn math, usage fee via marker id.  
- In/Out targets: routes per PRD §7.  
- DFPkg + Component FactoryService + registry `vaultFeeTypeIds`.  
- TestBase: deploy path, fund WETH/stETH/wstETH helpers.

**NAV (v1 lock for code)**

```text
totalReserveEth =
    WETH.balance(vault)
  + getStETHByWstETH(wstETH.balance(vault))
  + sum(pending request face stETH)
  + sum(claimable ETH for finalized unclaimed requests)
```

Share conversion uses `totalReserveEth` and SE `totalSupply` (first depositor / inflation defenses per existing vault patterns).

**Liquid check helper**

```solidity
function _requireLiquidWeth(uint256 requested) internal view {
    uint256 available = IERC20(weth).balanceOf(address(this));
    if (available < requested) revert InsufficientLiquidReserve(requested, available);
}
```

**Exit:** deploy + route matrix green without rebalance queue (sleeve funded manually in tests).

---

### Phase 4 — Rebalance + queue lifecycle

**Deliverables**

- `rebalance()` / split entrypoints: claimAndWrap, stakeExcess, queueDeficit.  
- Hysteresis band constants (document final values in Common; start with **10% of targetLiquid** or **0** band + cooldown if simpler).  
- Cap max new requests per call (e.g. 5).  
- `receive()` + reentrancy lock on claim/rebalance/exchange.  
- Views: `liquidReserveEth`, `lockedReserveEth`, `actualLiquidReservePercentage`, `targetLiquidReservePercentage`.

**Exit:** hermetic simulation where possible + fork for real queue finalize (may use warp + cheat only if fork cannot finalize; prefer real oracle path or skip finalize step with documented limitation and claim path when already finalized on fork state).

---

### Phase 5 — Spec completeness (fees, sleeve, preview)

- Usage fee on mint to `feeTo` when type fee &gt; 0; zero when overridden to 0.  
- Full preview == execution matrix.  
- InsufficientLiquidReserve decode tests (`vm.expectRevert` with exact args).

---

### Phase 6 — Invariant suite

See §6.

---

### Phase 7 — Adversarial suite

See §7.

---

### Phase 8 — Fork hardening + docs

- Mainnet fork: real submit/wrap, WETH routes, rebalance stake leg, queue request (claim if environment allows).  
- Update package README / link from staking research.  
- Optional: attach as SE leg smoke under Single SE DETF matrix (opaque).

---

## 5. Functional / unit / integration test matrix

### 5.1 Deploy

| ID | Case | Assert |
|----|------|--------|
| D1 | Registry deploy DFPkg + vault | marker, vaultTokens, asset=wstETH |
| D2 | Fee type id = marker interfaceId | usageFeeOfVault / liquidReserveOfVault type path |
| D3 | Anti-pattern: no raw `new` DFPkg in TestBase | review |

### 5.2 Routes + preview == execution

For each closed-form route in PRD §7.1:

| ID | Pattern |
|----|---------|
| P1 | `previewExchangeIn` / `Out` then execute; `assertEq(preview, executed)` |
| P2 | minOut = preview succeeds; minOut = preview+1 reverts Slippage |
| P3 | deadline past reverts |
| P4 | zero amount reverts |

**Required pairs (minimum):**

- WETH ↔ SE (sleeve funded)  
- wstETH ↔ SE  
- stETH ↔ wstETH  
- ETH → wstETH / SE (native)  
- stETH → SE  

### 5.3 Liquid sleeve

| ID | Case | Assert |
|----|------|--------|
| L1 | SE → WETH with sleeve ≥ amount | success; sleeve decreases; preview==exec |
| L2 | SE → WETH with sleeve &lt; amount | `InsufficientLiquidReserve(requested, available)` exact |
| L3 | preview SE → WETH when sleeve short | **succeeds** (quotes full NAV); exec reverts `InsufficientLiquidReserve` |
| L4 | After L2, state unchanged | balances, supply |
| L5 | Partial sleeve: request exactly `available` | success |
| L6 | request `available + 1` | revert with those two args |

Example expect:

```solidity
uint256 available = weth.balanceOf(seVault);
uint256 requested = available + 1;
vm.expectRevert(
    abi.encodeWithSelector(
        ILidoWstETHStandardVault.InsufficientLiquidReserve.selector, // or errors lib
        requested,
        available
    )
);
IStandardExchangeOut(seVault).exchangeOut(/* WETH out path */, requested, ...);
```

### 5.4 Rebalance

| ID | Case |
|----|------|
| R1 | liquid &gt; target → stake reduces WETH, increases wstETH |
| R2 | liquid &lt; target → creates queue NFT owned by vault; wstETH down |
| R3 | claim finalized → WETH up; request cleared |
| R4 | staking paused → stake leg no-op or clear revert; no partial corrupt state |
| R5 | queue placement paused → queue leg skipped; claim still works |
| R6 | deficit &gt; 1000 stETH-eq → multiple requests ≤ max per tx |

### 5.5 Fees

| ID | Case |
|----|------|
| F1 | usage fee &gt; 0 → fee shares to feeTo on mint |
| F2 | type fee 0 → no fee shares |
| F3 | liquidReservePercentage does not affect fee math except via inventory |

---

## 6. Invariant testing

### 6.1 Handler design

`Handler_LidoWstETHStandardExchange` (ghost-tracked) on **production** vault:

| Action (weighted) | Notes |
|-------------------|--------|
| `exchangeIn_wethToSe` | fund attacker/user with WETH |
| `exchangeOut_seToWeth` | catch `InsufficientLiquidReserve` as non-failing handler path |
| `exchangeIn_wstToSe` / `exchangeOut_seToWst` | |
| `wrap_steth` / `unwrap` | if exposed as exchange routes |
| `rebalance` | permissionless |
| `donate_weth` / `donate_wsteth` | adversarial donation for invariant “no free mint” |
| `warp` | limited time advance for any time-gated logic |

Use mintable WETH/stETH only as **funding** harnesses; Lido path on fork handler variant may use deal/hoax carefully.

### 6.2 Invariants (must hold)

| Inv | Statement |
|-----|-----------|
| **I1 Solvency** | `totalReserveEth() >= 0` and SE share redeemable value bounded: sum user shares ≤ totalSupply; `convertToAssets(totalSupply) ≈ totalReserveEth` (exact or documented dust) |
| **I2 Sleeve accounting** | `liquidReserveEth() == WETH.balanceOf(vault)` |
| **I3 No negative sleeve** | never pay WETH without `_requireLiquidWeth` (enforced by no silent underflow) |
| **I4 Conservation (approx)** | ghost: sum(user SE shares) + feeTo shares == totalSupply |
| **I5 Donation non-dilution (mint)** | donating WETH/wstETH without mint does not increase `convertToShares` credit for next minter beyond total assets share math (standard 4626 inflation defenses; assert attacker cannot extract others’ principal via donation+mint+burn cycle beyond known dust) |
| **I6 Residual free inventory** | after successful exchange, vault holds no unexpected intermediate stETH/ETH dust above dust bound (e.g. ≤ 10 wei) unless documented |
| **I7 Request ownership** | every tracked request id owner is vault (or zero if claimed) |
| **I8 Reentrancy** | `isLocked` false outside calls; nested entry fails |
| **I9 Liquid policy non-binding on Out** | policy % does not create WETH from nowhere; Out only from actual sleeve |
| **I10 Preview consistency** | for random closed-form route samples in handler (optional ghost): last preview equals last execution when both succeeded |

### 6.3 Failures that must not be invariant breaks

- User reverts on `InsufficientLiquidReserve` — expected; handler continues.  
- Lido stake limit reverts on rebalance stake leg — state unchanged.

### 6.4 Commands

```bash
forge test --match-path 'test/foundry/spec/protocol/staking/lido/invariant/**' -vv
```

---

## 7. Adversarial testing

### 7.1 Threat model (summary)

| Actor | Surface | Asset at risk |
|-------|---------|----------------|
| Attacker EOA | exchangeIn/Out, rebalance, donate | WETH, wstETH, SE shares, queue ETH |
| Hostile ERC20 | if ever accepted as vault token (v1: not a share token) | reentrancy into exchange/rebalance |
| MEV searcher | sandwich around rebalance stake | secondary; document bounds |
| Operator | fee oracle liquid % | grief yield vs Out availability (governance risk) |

### 7.2 Attack catalog

| ID | Theme | Attack | Pass criteria |
|----|--------|--------|---------------|
| **A1** | Donation | Donate WETH to vault; victim mints/burns | No free SE mint to attacker; victim not drained |
| **A2** | Donation | Donate wstETH | Same |
| **A3** | Donation | Donate ETH directly (if receive open) | ETH wrapped or rejected safely; no share credit without path |
| **C1** | Reentrancy | Hostile token reenters `exchangeOut` during transfer | `IsLocked`; no double pay |
| **C2** | Reentrancy | Reenter `rebalance` / claim during ETH receive | `IsLocked` or CEI; no double claim |
| **C3** | Reentrancy | Reenter `exchangeIn` during WETH pull | `IsLocked` |
| **E1** | Accounting | Round-trip WETH→SE→WETH | conservation ± dust; residual 0 |
| **E2** | Accounting | Round-trip wstETH→SE→wstETH | same |
| **E5** | Guards | zero amount, bad deadline | exact selectors |
| **F1** | Access | non-owner diamondCut / admin if any | revert / no surface (unowned instance) |
| **F2** | Access | random EOA cannot steal queue NFTs / claim others’ | only vault owner of requests |
| **H1** | Grief | SE→WETH with empty sleeve | `InsufficientLiquidReserve(req, avail)`; no state change |
| **H2** | Grief | Spam rebalance queue requests | caps prevent unbounded gas DoS per tx; vault still operable |
| **H3** | Grief | minOut fail mid-path | full revert; no partial mint |
| **S1** | Sleeve drain | Many small SE→WETH until empty; next fails with correct args | sequential exact errors |
| **S2** | Sleeve | Attacker fills sleeve via mint then empties; cannot pull locked wstETH as WETH without queue | WETH Out never spends wstETH |
| **S3** | Policy | Set liquid % to 100% via oracle; rebalance does not mint WETH without queue finalization | async only |
| **Q1** | Queue | Attacker cannot claim vault-owned request | NotOwner |
| **Q2** | Queue | Double claim same request | revert; no second ETH |
| **R1** | Route | SE→ETH primary via exchangeOut | `InvalidRoute` |
| **R2** | Route | Unsupported token pair | `InvalidRoute` |

### 7.3 Priority

| Priority | IDs | Ship gate |
|----------|-----|-----------|
| **P0** | A1–A2, C1–C3, E1–E2, E5, H1, H3, S1–S2, R1, Q1–Q2 | Yes |
| **P1** | A3, F1–F2, H2, S3, R2 | Before release |
| **P2** | MEV sandwich on rebalance stake; full bunker-mode fork drama | Defer OK with NatSpec |

### 7.4 Adversarial TestBase

```solidity
abstract contract TestBase_LidoWstETHStandardExchange_Adversarial is TestBase_LidoWstETHStandardExchange {
    address internal attacker;
    address internal victim;
    // optional: reentrancy harness if a route pulls attacker-controlled ERC20

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
    }

    function _fundSleeve(uint256 wethAmount) internal { /* deal + exchangeIn or direct deal to vault for donation tests */ }
    function _expectInsufficientLiquid(uint256 requested, uint256 available) internal { /* vm.expectRevert selector+args */ }
}
```

Naming: `test_A1_donateWeth_noFreeMint`, `test_H1_exchangeOutWeth_emptySleeve_revertsWithArgs`, etc.

### 7.5 Commands

```bash
forge test --match-path 'test/foundry/spec/protocol/staking/lido/adversarial/**' -vv
forge test --match-path 'test/foundry/spec/protocol/staking/lido/**' -vv
```

---

## 8. Fork test plan

| ID | Case | Notes |
|----|------|-------|
| FK1 | Deploy SE on fork with mainnet stETH/wstETH/WETH/queue | registry path |
| FK2 | submit ETH → wstETH → SE | real Lido |
| FK3 | WETH sleeve Out | fund sleeve first |
| FK4 | rebalance stake excess | real submit |
| FK5 | requestWithdrawalsWstETH from vault | real queue; keep NFT |
| FK6 | claim if already-finalized request available or multi-step script | document if environment cannot finalize |

```bash
forge test --fork-url $ETH_RPC_URL --match-path 'test/foundry/fork/eth_main/vaults/staking/lido/**' -vv
```

---

## 9. Component checklist (implementation order)

### Phase 1 — Fee Oracle

- [ ] `VaultFeeOracleRepo` storage + get/set + validate  
- [ ] `IVaultFeeOracleQuery` + QueryFacet resolution  
- [ ] `IVaultFeeOracleManager` + ManagerFacet setters/events  
- [ ] facetFuncs / diamond cut updates  
- [ ] Unit tests FO-1…FO-6  

### Phase 2 — Crane

- [ ] Stake limit / pause on integration interface  
- [ ] WithdrawalQueue interface + service helpers  
- [ ] ETH→WETH wrap helper  

### Phase 3 — SE core

- [ ] Marker interface + facet  
- [ ] Repo + Common (NAV, `_requireLiquidWeth` → `InsufficientLiquidReserve`)  
- [ ] In/Out facets  
- [ ] DFPkg + FactoryService  
- [ ] TestBase + D* + route matrix + L* sleeve tests  
- [ ] Preview == execution suite  

### Phase 4 — Rebalance

- [ ] Rebalance facet  
- [ ] Request id set bookkeeping  
- [ ] R* tests (+ fork FK4–FK6)  

### Phase 5–7 — Hardening

- [ ] Fees F*  
- [ ] Invariant handler + I1–I10  
- [ ] Adversarial P0/P1 catalog  
- [ ] Deferred P2 NatSpec  

---

## 10. Acceptance criteria

- [ ] PRD liquid oracle API implemented and tested.  
- [ ] Lido SE deploys only via IndexedEx registry path.  
- [ ] Closed-form routes: **preview == execution**.  
- [ ] WETH Out shortfall: **`InsufficientLiquidReserve(requested, available)`** with correct values; state unchanged.  
- [ ] Rebalance can stake excess and enqueue withdrawals; claim wraps to WETH.  
- [ ] No closed-form primary Lido ETH Out.  
- [ ] Invariant suite green under handler fuzz.  
- [ ] Adversarial **P0** green; **P1** green or deferred with NatSpec.  
- [ ] Fork smoke for real Lido paths.  
- [ ] No mocks of SUT Lido/manager/registry/fee oracle/SE diamond.

---

## 11. Risks during implementation

| Risk | Mitigation |
|------|------------|
| stETH rebase mid-tx | Prefer wstETH inventory; minimize stETH hold time |
| NAV vs share inflation | Follow existing ERC4626 vault offset patterns; donation tests |
| Fork cannot finalize queue | Split FK5 request vs FK6 claim; use historical finalized state if needed |
| Gas on multi-request rebalance | Cap per tx; handler invariant |
| 0 = unset liquid policy | Non-zero global default; document |

---

## 12. Suggested execution commands (summary)

```bash
# Phase 1
forge test --match-path '**/VaultFeeOracle_LiquidReserve*' -vv

# Phase 3–5 hermetic/spec
forge test --match-path 'test/foundry/spec/protocol/staking/lido/**' -vv

# Invariants
forge test --match-path 'test/foundry/spec/protocol/staking/lido/invariant/**' -vv

# Adversarial
forge test --match-path 'test/foundry/spec/protocol/staking/lido/adversarial/**' -vv

# Fork
forge test --fork-url $ETH_RPC_URL --match-path 'test/foundry/fork/eth_main/vaults/staking/lido/**' -vv
```

---

## 13. Changelog

| Date | Change |
|------|--------|
| 2026-07-23 | Initial implementation + testing plan (functional, invariant, adversarial); `InsufficientLiquidReserve(requested, available)` normative |

---

*Do not mark IMPLEMENTED until acceptance criteria are met with command evidence. Adversarial P0 is a ship gate for “adversarially tested” claims.*
