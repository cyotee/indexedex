# PRD: Uni V4 SE DETF peg vs first-bond opening price

**Status:** Accepted v0.1 — requirements locked.  
**Date:** 2026-08-20  
**Implementor SoT:** [`UNISWAP_V4_SE_DETF_PEG_AND_OPENING_PRICE_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_SE_DETF_PEG_AND_OPENING_PRICE_IMPLEMENTATION_AND_TEST_PLAN.md)

| | |
|--|--|
| **Bug** | Peg and first-bond opening price are one `PkgArgs` field. First bond is forced onto the peg. Policy mint has no runway. |
| **Fix** | Two fields. Peg stays `creationPairPerDetfWad`. Opening is `openingPairPerDetfWad`. |
| **Scope** | All four Uni V4 hook DETF families: CP Single, Curve Quad, Weighted, Orbital. |
| **Out** | Balancer DETFs. Hook DFPkg auto-mine. Public 46630 broadcast. Anvil diamond-impersonation richness. |

---

## 0. Why this exists

`creationPairPerDetfWad` is pair per DETF at empty book **and** the 1.0 of synthetic:

```
G = pair * 1e18 / creationPairPerDetfWad          // first bond
S = (fdPair / supply) * 1e18 / creationPairPerDetfWad
```

Raising it moves the join and the peg together. Synthetic after first bond stays ~1 (then extra bond-split DETF pulls it lower). You cannot launch mint-open by changing that one number.

Product intent: the creator sets a **peg** and an **opening price**. Opening above peg puts more pair per DETF in the reserve than the peg. After first bond, synthetic is above 1. Policy mint (1.05) can pass. Expansion has runway down toward the peg.

Demo PRD D38/D47 that said “do not raise creation; impersonate the diamond and `depositSingle`” is **wrong** for this law. First bond as the deployer EOA is the only launch path.

---

## 1. Locked law (N1–N18)

| ID | Law |
|----|-----|
| N1 | **Peg** = `creationPairPerDetfWad` (per pair on multi-leg). Pair per DETF when synthetic = 1e18. Policy mint/burn compare synthetic to 1.05 / 0.95 around this 1.0. |
| N2 | **Opening** = `openingPairPerDetfWad` (per pair on multi-leg). Pair per DETF the first bond actually joins at. |
| N3 | Empty-book first-bond DETF self-leg: `G = pair * 1e18 / opening` (resolved opening, N6). Not `/ creation`. |
| N4 | Synthetic, mint/burn gates, and expansion use **creation only**. Never opening. |
| N5 | After `isReserveLive`, mint/bond quotes use the **live reserve curve**. Opening is first-bond-only. |
| N6 | `opening == 0` resolves to `creation` at init (open at peg). Store the resolved value. Views never return 0 if creation was valid. |
| N7 | `creation > 0` still required (existing `InvalidCreationRate`). Resolved opening is always > 0. |
| N8 | `opening > creation` is launch-rich (synthetic > 1 after a join that matches opening, before extra mint). `opening < creation` is allowed (open below peg). |
| N9 | Multi-leg: `openingPairPerDetfWad.length == creationPairPerDetfWad.length == m`. Slot `i` opening 0 resolves to slot `i` creation. Orbital: `openingPair0PerDetfWad` / `openingPair1PerDetfWad` beside the two creation fields. |
| N10 | Extra DETF minted on first bond (user + pot from seigniorage split) still increases supply. If that leaves mint closed at opening `1.1e18`, **raise opening** until a hermetic first bond with default Policy 1.05 is mint-open, and record that WAD. Do **not** impersonate the DETF. Do **not** call hook `depositSingle` as the diamond. Do **not** change mint threshold to fake it. |
| N11 | No Anvil-only launch-rich. No `anvil_impersonateAccount` / `anvil_setBalance` to LP the reserve. |
| N12 | Uni V4 pool `deployPair` tick-0 1:1 must not block an opening ≠ 1e18 first join. If empty-book `deposit` fails or ignores the opening ratio, init sqrtPrice from the opening pair/DETF ratio (token order) is **in scope**. |
| N13 | `PkgArgs` lives on the **package interface**. `calcSalt` hashes full `PkgArgs` (opening included). `deployVault(args, mineNonce)` arity unchanged. |
| N14 | Role names only. No RICH/RICHIR as roles. |
| N15 | Never `new` facets/DFPkgs. Never `via_ir`. Production-first tests. |
| N16 | Balancer DETF families are **out of this PRD**. |
| N17 | Default TestBase / at-peg scripts: `opening = 0` (resolves to creation `1e18`). 46630 leaf demo: creation `1e18`, opening start `1.1e18` then N10. |
| N18 | Existing diamonds are immutable. This is new deploys only. |

---

## 2. Field names (mandatory)

| Family | Peg (keep) | Opening (add) |
|--------|------------|-----------------|
| CP Single | `creationPairPerDetfWad` | `openingPairPerDetfWad` |
| Curve Quad | `creationPairPerDetfWad[]` | `openingPairPerDetfWad[]` |
| Weighted | `creationPairPerDetfWad[]` | `openingPairPerDetfWad[]` |
| Orbital | `creationPair0PerDetfWad`, `creationPair1PerDetfWad` | `openingPair0PerDetfWad`, `openingPair1PerDetfWad` |

NatSpec on opening: “Pair per DETF on first bond. 0 → use creation (open at peg).”

Views on the DETF info surface: same names, return **resolved** storage.

---

## 3. Formulae (normative)

Empty book, pair amount `P` (WAD), resolved opening `O`, creation `C`:

```
G = P * 1e18 / O
S = (fdPair * 1e18 / supply) * 1e18 / C
```

If the join puts `P` pair and `G` DETF in the counted reserve and supply were only `G`:

```
S = O / C
```

Launch-rich: `O > C` ⇒ `S > 1`. Policy mint if `S > mintThreshold` (default 1.05e18).

---

## 4. Tests (minimum)

Hermetic, production-first, gold TestBase. No SUT mocks.

| ID | Family | Assert |
|----|--------|--------|
| T1 | All four | `opening = 0` → stored opening == creation; first bond same G as today at C=1e18 |
| T2 | All four | `creation = 1e18`, `opening = 1.1e18` (or N10 WAD) → first-bond G uses opening; `creationPairPerDetfWad` view unchanged |
| T3 | CP + Quad | After that first bond, `isMintingAllowed` true (per-pair on Quad, all legs). If false, apply N10 and re-run |
| T4 | CP | `opening = 0` still first-bonds; synthetic near current at-peg behavior |
| T5 | All four | `creation = 0` still reverts `InvalidCreationRate` |
| T6 | Quad/Weighted | opening array length mismatch reverts (same style as creation length errors) |
| T7 | CP | Live mint/burn quotes after first bond do not use opening |

Adversarial: do not add a donate-to-hook richness path.

---

## 5. Scripts

`scripts/foundry/anvil_robinhood_testnet/`:

- Set opening on leaf DETFs (N17 / N10). Keep creation `1e18`.
- First bond as the EOA. Remove diamond-impersonation `depositSingle` richness (RichnessLib `_depositPairOnHook` / `_unlockAnvilAccount`).
- `isReserveLive` after first bond is the live gate. Mint-open is T3, not a second LP step.

Other PkgArgs construction sites (main/fee_detf/research/TestBases): add `opening: 0` so they compile and stay at-peg unless they opt in.

---

## 6. Docs to patch when code lands

- This PRD + the implementation plan (DoD checkboxes).
- Four family `*_PRD.md`: peg vs opening; delete “creation is also first-bond price” where it says that.
- `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` §16.2 empty-pool quote: Uni V4 uses **opening**; synthetic peg stays creation.
- `docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md` D38/D47: D38 creation remains peg `1e18`. Opening is the launch-rich lever. D47 diamond `depositSingle` **rescinded**.
- One paragraph in `docs/agent/INDEXEDEX_AGENT_LAW.md` under DETF PkgArgs.

---

## 7. Non-goals

- Balancer DETFs.
- Changing seigniorage `p` or mint/burn default 1.05/0.95 (except N10 forbids changing mint threshold to fake open).
- Public broadcast.
- Hook package mine-nonce / staged init (already shipped).
- Frontend Insights copy beyond whatever still assumes one rate.

---

## 8. DoD (product)

- [x] Four families have both fields; first bond uses opening; S uses creation.
- [x] `opening = 0` ≡ at peg.
- [x] Hermetic T1–T7 green.
- [x] No diamond impersonation in 46630 leaf scripts.
- [x] Family PRDs + alignment + demo D38/D47 text match this file.
