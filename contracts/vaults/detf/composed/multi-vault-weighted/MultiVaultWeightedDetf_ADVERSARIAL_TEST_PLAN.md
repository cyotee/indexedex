# MultiVaultWeightedDetf — Adversarial Test Implementation Plan

## Purpose

Define a production-first adversarial / abuse-oriented Foundry test matrix for **MultiVaultWeightedDetf** (primary) and note which cases should be ported to peer DETFs (`standardExchange/single`, `composed/stable/common`, etc.).

This plan **extends** existing coverage (reentrancy `IsLocked`, `InvalidRoute` rejects, pre-live gates, claim inventory guards, residual free inventory, default-threshold price-shift). It does **not** replace happy-path matrix tests (`N=1..7`, nested, multi-leg mint/burn/claim).

## Status

**IMPLEMENTED (P0/P1)** — adversarial suites under `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/adversarial/` are green (30 tests). Full multi-vault path remains green under:

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/adversarial/**'
forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**'
```

## Scope

### In scope

| Surface | Entry points |
|---------|----------------|
| Exchange | `exchangeIn`, `previewExchangeIn` (exact-out stays `InvalidRoute`) |
| Liveness / reserve | `initializeReserve`, first/later `bond(BPT\|vaultShare)` |
| Bond / claim | `sellNFT`, `sellPositionToProtocol`, `redeemClaim`, lock clamp |
| Pricing gates | `syntheticPrice`, `isMintingAllowed`, `isBurningAllowed` |
| Inventory | Free DETF / free vault shares on diamond; BPT ownership vs bond NFT accounting |
| Nested composition | Outer multi-vault with nested Single SE DETF as a leg |
| N-range | Prefer N=1 and N=2 for attack sequences; N=3 smoke where stack/gas allows |

### Out of scope

- Full Base-fork MEV reconstruction unless hermetic cannot express the attack
- Binary-search exact-out implementation (must remain `InvalidRoute`)
- Mainnet deploy / frontend
- Subclassing peer DETF contracts (reuse TestBase + production packages only)

### Testing rules (non-negotiable)

1. **Production-first:** real MultiVaultWeightedDetf, manager, registry, DFPkg, Balancer weighted reserve, production SE vault packages.
2. **No `MockStandardExchange`** as SUT or leg.
3. **Allowed harnesses:** hostile ERC20 (reentrancy/donation), attacker contracts, `vm.prank` / flash-loan simulator EOAs, mintable underlyings for funding.
4. **Assertions:** drive real entry points; prefer exact conservation / balance deltas; document ≤ few-wei only when Balancer math forces it.
5. **Fail modes:** either exploit is **blocked** (revert / no value theft) or **documented intentional economic risk** with invariant that still holds (e.g. “spot arb is free on external reserve pool, not DETF surface”).

---

## Threat model (short)

| Actor | Capabilities |
|-------|----------------|
| External user / MEV searcher | Atomic multi-call, flash capital, underlying pool trades, direct ERC20 transfers to DETF/pool |
| Malicious ERC20 vault share | Reentrancy on `transfer` / `transferFrom` (hostile share pattern already used) |
| Nested DETF user | Outer + inner entry points in one flow |
| Bond / claim holder | Sell NFT, redeem claim to chosen `rateAsset` |
| Cannot | Diamond cut instance, change immutable weights/rates, own DETF after deploy |

**Assets of concern:** user vault shares, DETF balances, reserve BPT, protocol NFT principal, claim token value, fee/protocol DETF slices.

---

## Already covered (baseline — keep green)

| ID | Case | Location |
|----|------|----------|
| BASE-R1 | Nested reentrancy mint → `IsLocked` | `*_Reentrancy.t.sol` |
| BASE-R2 | Nested reentrancy bond → `IsLocked` | `*_Reentrancy.t.sol` |
| BASE-G1 | Pre-live mint / share-bond | `*_Liveness.t.sol` |
| BASE-G2 | RateAsset mint, share↔share, exact-out | `*_MintBurn.t.sol` |
| BASE-G3 | Bad deploy weights / duplicate vault | `*_Deploy.t.sol` |
| BASE-G4 | Lock too short | `*_Bonding.t.sol` |
| BASE-G5 | Claim: junk rateAsset / no inventory | `*_Claim.t.sol` |
| BASE-E1 | Residual free inventory after success | multi suites |
| BASE-E2 | Default-threshold mint+burn via underlying trades | `*_PriceShift.t.sol` |

New suites should **import / not duplicate** these; add cross-function variants only.

---

## Attack catalog

Sources: industry ERC-4626 inflation/donation literature, AMM spot manipulation, Balancer V3 op constraints (min balances, max in ratio), and DETF-specific seigniorage/bond/claim design.

### Category A — Donation / inflation / first-mover

Classic ERC-4626 first-depositor inflation (donate assets after dust mint) is **partially analogous** when synthetic or mint quote depends on `balanceOf` rather than internal accounting. DETF mint is curve-based against reserve pool state, not pure `totalAssets/totalSupply` 4626 math — still test donation paths.

| ID | Attack | Setup | Action | Pass criteria |
|----|--------|-------|--------|----------------|
| A1 | **Donate vault shares to DETF diamond** before mint | Live N=1 | Attacker `transfer` large vault shares to DETF without calling `exchangeIn` | Shares sit idle or are swept safely; **attacker cannot mint free DETF** or inflate another user’s mint; residual policy documented |
| A2 | **Donate DETF to diamond** | Live | Direct transfer DETF to DETF | No change to other users’ balances; no synthetic self-destruct; residual free DETF not claimable by attacker via burn of 0 |
| A3 | **Donate BPT to diamond** | Live with bond NFT accounting | Transfer reserve BPT to DETF | Synthetic may move; **attacker cannot redeem others’ bond principal**; claim redeem still requires claim burn |
| A4 | **Dust first-bond / initializeReserve grief** | Inert | Tiny `initializeReserve` + bond, or unbalanced tiny legs | Either reverts (min amounts) or later users can still mint/bond; no permanent DoS of live path without disproportionate cost |
| A5 | **Share inflation via seigniorage split destinations** | Live, fees > 0 | Observe feeTo / protocol NFT DETF mints | Fee slices do not allow double-claim of same reserve; user cannot steal fee/protocol DETF without holding those positions |

### Category B — Spot / rate manipulation (oracle-less but pool-implied)

Spot manipulation is a top DeFi loss class when protocols use manipulable AMM spot for mint/redeem. Our mint/burn is gated by **synthetic** (fully diluted BPT claim), not pure spot — still attackable via reserve balances + rate providers + free DETF supply.

| ID | Attack | Setup | Action | Pass criteria |
|----|--------|-------|--------|----------------|
| B1 | **Underlying SE pool skew → open mint → arb burn** | Default thresholds | Flash-style: skew underlying → mint → reverse skew → burn | Either no free lunch (net ≤ fees + slippage) **or** document seigniorage extraction bounds; victim holders’ residual claim non-decreasing modulo fees |
| B2 | **Reserve pool external swap** (Balancer/SE router) between DETF and vaultShare | Live reserve with external liquidity path | Sandwich user mint/burn around reserve swap | User minOut protects; attacker profit does not drain protocol NFT principal |
| B3 | **Rate provider jump** (trade underlying until rate moves hard) | Rated leg | Mint/burn at boundary of thresholds | Gates flip correctly; no mint when `synthetic ≤ mintThreshold`; no burn when `≥ burnThreshold` |
| B4 | **Cross-leg rate desync (N=2)** | Disparate rateAssets | Manipulate only one leg’s underlying | Other leg mint/burn still consistent; no share↔share on DETF |
| B5 | **MaxInRatio / min balance grief** | Small reserve | Attacker joins unbalanced max; victim large mint | Victim either succeeds with fair quote or clean revert; **no stuck intermediate balances** on DETF |

### Category C — Reentrancy & cross-function reentry

Extend beyond single-function hostile share.

| ID | Attack | Setup | Action | Pass criteria |
|----|--------|-------|--------|----------------|
| C1 | **Reenter `initializeReserve` from share transfer** | Inert, hostile share as leg | Nested second `initializeReserve` / `bond` | Nested `IsLocked` or equivalent; no double-live / double-mint |
| C2 | **Reenter `sellNFT` / `redeemClaim`** | Live, hostile path if callable mid-transfer | Nested redeem/mint | Locked; claim inventory not double-spent |
| C3 | **Cross-entry: mint → reenter bond** | Hostile share | Nested bond during mint | `IsLocked` (extend BASE-R2) |
| C4 | **Cross-entry: redeemClaim → reenter exchangeIn** | Claim path with callback token as rateAsset if feasible | Nested mint | Locked or rateAsset path doesn’t callback; no free DETF |
| C5 | **Read-only reentrancy on preview** | If any external call in preview | View path | Preview pure/view-safe; no state change |

### Category D — Bond / claim economic attacks

| ID | Attack | Setup | Action | Pass criteria |
|----|--------|-------|--------|----------------|
| D1 | **Sell NFT without claim token** | Misconfigured deploy if possible | `sellNFT` | `ClaimTokenNotConfigured` (already production behavior) |
| D2 | **Redeem claim without burning authority** | Live, BPT on diamond | Call `redeemClaim` with 0 claim / wrong owner | Revert; **no BPT drain** (regression for prior free-BPT bug class) |
| D3 | **Double redeem same claim** | After sell | Redeem full claim twice | Second reverts; protocol BPT not over-exited |
| D4 | **Claim redeem selects unrated / wrong rateAsset** | Mixed rated | Redeem to address(0) or junk | `InvalidRoute` |
| D5 | **Bond lock clamp bypass** | Live | Lock `> max` and `< min` | Min reverts; max clamps; bonus not above max curve |
| D6 | **Steal protocol NFT principal via redeem** | After multiple sells | Redeem more BPT than burned claim principal | Cap by burned shares and DETF BPT; no over-claim |
| D7 | **Sell then immediate redeem vs locked bond terms** | Before/after unlock | Sell is allowed by design; redeem independent of lock | Documented; no path to free principal without sell |

### Category E — Accounting / conservation / residual

| ID | Attack | Setup | Action | Pass criteria |
|----|--------|-------|--------|----------------|
| E1 | **Mint then partial burn conservation** | Open thresholds | Round-trip vaultShare → DETF → vaultShare | Out ≤ in + known fees/slippage; residual free inventory 0 |
| E2 | **Multi-leg burn leaves dust on other legs** | N=2 | Burn to leg 0 after multi-leg reserve | Other legs re-joined or zero free inventory |
| E3 | **Fee recipient cannot be drained by user burn** | Fees accrued | User burns | FeeTo DETF balance non-decreasing except feeTo’s own actions |
| E4 | **Non-dilution of existing holders (economic)** | Holder A, then B mints | Measure A’s pro-rata synthetic claim | A’s claim non-decreasing modulo intentional fee mint destinations (peer DETF standard) |
| E5 | **Zero amount / expired deadline** | Live | `amount=0`, `deadline < now` | Revert `ZeroAmount` / `DeadlineExpired` |

### Category F — Access control & immutability

| ID | Attack | Setup | Action | Pass criteria |
|----|--------|-------|--------|----------------|
| F1 | **No instance owner diamondCut** | Deployed instance | Attempt upgrade / ownership | No owner / cut fails |
| F2 | **Bond NFT vault onlyOwner paths** | Random EOA | Direct `createPosition` / `sellPositionToProtocol` on NFT vault | Revert onlyOwner |
| F3 | **Claim `mintFromNFTSale` / `burnShares` onlyOwner** | Random EOA | Call claim token directly | Revert; only DETF can mint/burn shares |
| F4 | **Immutable weights / rates after deploy** | Live | No setter exists | Static: no public setWeights; storage unchanged after ops |

### Category G — Composition / nested

| ID | Attack | Setup | Action | Pass criteria |
|----|--------|-------|--------|----------------|
| G1 | **Outer mint does not brick inner** | Nested live | Outer mint/burn with nested shares | Inner still `exchangeIn` for third user |
| G2 | **Inner mint does not inflate outer free inventory** | Nested | Inner activity only | Outer residual clean; outer synthetic defined |
| G3 | **Recursive opacity** | Nested | Grep/static: outer production sources don’t import concrete inner protocol types | Structural assert in test or CI comment |

### Category H — DoS / griefing

| ID | Attack | Setup | Action | Pass criteria |
|----|--------|-------|--------|----------------|
| H1 | **Gas grief initializeReserve N=7** | Inert N=7 | Boundary amounts | Completes under block gas or reverts cleanly |
| H2 | **Balancer TokenBalanceBelowMin grief on claim redeem** | Small pool | Full claim redeem | Either succeeds or reverts without stranding partial burns (claim not burned if exit fails — **critical invariant**) |
| H3 | **Repeated failed mints leave approvals only** | Live | Fail minOut | No inventory left on DETF |

---

## Priority & phasing

### Phase 0 — Harness (1–2 days)

**Deliverables**

- [x] `test/foundry/spec/vaults/detf/composed/multi-vault-weighted/adversarial/TestBase_MultiVaultWeightedDetf_Adversarial.sol`
  - Extends `TestBase_MultiVaultWeightedDetf`
  - Helpers: attacker/victim, hostile share, reentry target, `_openLiveN1`, `_assertNoFreeInventoryStrict`, `_swapUnderlying`, `_goLiveHostile`
- [x] Compile + live smoke via suite setUp paths

**Exit:** compile + one smoke that goes live as attacker. **DONE**

### Phase 1 — Guards & access (extend baseline)

**Files:** `Adversarial_Guards.t.sol`, `Adversarial_Access.t.sol`

- [x] E5 zero/deadline
- [x] F1–F4 immutability / onlyOwner
- [x] D2–D4 claim authority (emphasize **D2 no free BPT**) — see also `Adversarial_BondClaim.t.sol`
- [x] H3 failed mint residual

**Exit:** all Phase 1 green; D2 is regression-critical. **DONE**

### Phase 2 — Reentrancy expansion

**Files:** `Adversarial_Reentrancy.t.sol`

- [x] C1–C3 (C4 deferred — rateAsset hostile without breaking SE not wired)
- [x] Keep BASE-R1/R2 as reference; adversarial covers init/redeem/bond cross-entry

**Exit:** every nested entry asserts `IsLocked` (or stronger).

### Phase 3 — Donation / inflation

**Files:** `Adversarial_Donation.t.sol`

- [x] A1–A3 (A4–A5 deferred P2 — dust grief / fee-slice in FeeNonDilution suite)
- [x] Explicit invariant: **donations cannot mint DETF without `exchangeIn`**
- [x] Explicit: **claim redeem cannot exceed burned claim principal in BPT terms** (D6)

**Exit:** no profitable theft vector in A1–A3; grief cases documented. **DONE**

### Phase 4 — Economic / manipulation

**Files:** `Adversarial_Economic.t.sol`, `Adversarial_PriceManipulation.t.sol`

- [x] B1 (seigniorage bounds when both gates open) + B1b (default deadband mutual exclusion) + B3
- [x] B2, B4–B5 **deferred P2** (NatSpec on `Adversarial_PriceManipulation.t.sol`)
- [x] E1, E4 non-dilution / round-trip
- [x] Bound seigniorage extraction as intentional under open thresholds; hard safety invariants hold

**Exit:** written economic invariants in test comments + asserts. **DONE (P0)**

### Phase 5 — Bond/claim deep + nested + grief

**Files:** `Adversarial_BondClaim.t.sol`, `Adversarial_Nested.t.sol`, `Adversarial_Griefing.t.sol`

- [x] D5–D6 (D7 **deferred P2** — NatSpec on BondClaim)
- [x] G1 (G2–G3 **deferred P2** — NatSpec on Nested)
- [x] H2 atomic claim redeem (EVM full-tx revert restores claim after burn-then-exit fail)
- [x] H3 in Guards
- [x] E2–E3, H1 **deferred P2** (NatSpec on Economic / Griefing)

**Exit:** nested opacity + atomic claim redeem proven. **DONE (P0/P1)**

### Phase 6 — Peer DETF port (optional follow-up)

**Deferred** — non-goal for MultiVault adversarial green. Peer ports:

| Peer | Priority ports |
|------|----------------|
| `standardExchange/single` | A1–A3, B1, C*, D2-class, E1, E4, F* |
| `composed/stable/common` | claim redeem, multi-leg economic |
| Dual-liquidity / protocol DETF | only if SE surface complete |

Do **not** block MultiVault adversarial green on peer ports.

---

## Suggested file layout

```text
test/foundry/spec/vaults/detf/composed/multi-vault-weighted/
  adversarial/
    TestBase_MultiVaultWeightedDetf_Adversarial.sol
    Adversarial_Guards.t.sol
    Adversarial_Access.t.sol
    Adversarial_Reentrancy.t.sol
    Adversarial_Donation.t.sol
    Adversarial_Economic.t.sol
    Adversarial_PriceManipulation.t.sol
    Adversarial_BondClaim.t.sol
    Adversarial_Nested.t.sol
    Adversarial_Griefing.t.sol
    README.md                    # optional: matrix table + run command
```

Run:

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/adversarial/**' -vv
```

---

## Invariants checklist (assert in multiple tests)

1. **Residual:** after successful user ops, DETF holds ~0 free vault shares and ~0 free DETF (BPT may remain).
2. **Claim atomicity:** if `redeemClaim` reverts, user claim balance unchanged.
3. **Claim authority:** BPT exit amount ≤ burned claim principal (external share units) and ≤ DETF BPT balance.
4. **Live gate:** no user seigniorage mint while `!isReserveLive`.
5. **Route gate:** rateAsset mint / share↔share / exact-out always `InvalidRoute`.
6. **Reentrancy:** any nested DETF entry during nonReentrant function → `IsLocked`.
7. **Thresholds:** mint iff `synthetic > mintThreshold`; burn iff `synthetic < burnThreshold` (default 1.05 / 0.95).
8. **Non-dilution (soft):** existing holder DETF balance unchanged by others’ mints; economic claim non-decreasing modulo fee destinations.

---

## Production bugs expected to surface

| Symptom | Likely fix locus |
|---------|------------------|
| Claim burned but redeem reverts mid-exit | Make redeemClaim check-effects-interactions; burn after successful unwind or use pull pattern |
| Donation of vault shares mints value | Never trust `balanceOf` for mint without accounting |
| Free BPT redeem without claim | Keep `ClaimTokenNotConfigured` + mandatory `burnShares` |
| Nested MaxInRatio grief | Not always a bug; ensure clean revert, no partial state |
| Fee slice double-spend | Split mint destinations immutable accounting |

If an attack **succeeds with profit**, open a production fix PR before greenwashing the test as “expected.”

---

## Acceptance criteria (plan done when)

1. Adversarial suites under `adversarial/` implement **all P0/P1 IDs**: A1–A3, B1, B3, C1–C3, D2–D6, E1, E4–E5, F1–F4, G1, H2–H3. **DONE**
2. Remaining IDs (A4–A5, B2, B4–B5, C4–C5, D7, E2–E3, G2–G3, H1, peer ports) explicitly deferred with reason in suite NatSpec. **DONE**
3. `forge test --match-path '…/adversarial/**'` exit 0. **DONE**
4. Existing non-adversarial multi-vault path remains green. **DONE**
5. Plan checklist + pass matrix updated. **DONE**

### Pass matrix (P0/P1)

| ID | Test | Status |
|----|------|--------|
| A1 | `test_A1_donateVaultShares_cannotMintFreeDetf` | pass |
| A2 | `test_A2_donateDetfToDiamond_noTheft` | pass |
| A3 | `test_A3_donateBpt_cannotRedeemOthersPrincipal` | pass |
| B1 | `test_B1_skewMintReverseBurn_seigniorageBounds` (+ B1b) | pass |
| B3 | `test_B3_thresholdGates_blockMintWhenNotAllowed` | pass |
| C1–C3 | `Adversarial_Reentrancy` | pass |
| D2–D6 | `Adversarial_BondClaim` | pass |
| E1, E4 | `Adversarial_Economic` | pass |
| E5, H3 | `Adversarial_Guards` | pass |
| F1–F4 | `Adversarial_Access` | pass |
| G1 | `test_G1_outerActivity_doesNotBrickInner` | pass |
| H2 | `Adversarial_Griefing` | pass |

### Priority tags

| Priority | IDs |
|----------|-----|
| **P0** (must before “adversarially tested”) | D2, D3, D6, C1–C3, A1, A3, E1, E5, F2–F3, H2, H3, B1, B3 |
| **P1** | A2, A4, B4, D4, D5, E2, E4, F1, G1, BASE regression |
| **P2** | B2, B5, C4–C5, A5, D7, E3, F4, G2–G3, H1, peer ports |

---

## References (external patterns mapped here)

- ERC-4626 **inflation / first depositor / donation** attacks (OpenZeppelin, MixBytes, Solodit donation checklist) → Categories **A**, **E**
- **Spot / oracle manipulation** via AMM trades (industry DeFi incident class) → Category **B**
- **Reentrancy** on token hooks / ERC777-style callbacks (classic + AMM literature) → Category **C**
- Balancer V3 operational bounds (**min balances**, **max in ratio**, multi-token pools) → **B5**, **H2**
- Stable-pool **rate/invariant manipulation** (historical Balancer V2 class; weighted less exposed but rate providers still matter) → **B3–B4**
- Composition / nested vault risk (inner broken by outer) → Category **G**

---

## Revision history

| Date | Change |
|------|--------|
| 2026-07-15 | Initial adversarial plan from existing gaps + ERC-4626 donation/inflation, AMM spot manipulation, reentrancy, Balancer V3 bounds, DETF bond/claim authority |
| 2026-07-15 | Implemented P0/P1 adversarial suites (30 tests green). B1 documents intentional seigniorage when both mint/burn gates open; hard safety invariants enforced. P2 deferred: A4–A5, B2/B4–B5, C4–C5, D7, E2–E3, G2–G3, H1, peer ports. |
