# Mission: DETF Threshold Modes — P6 F6 + F7 (Wave 4)

**Goal:** Complete Wave 4 for the threshold-modes program:

1. **F6** — Align `IProtocolDETF` (+ errors/proxy as needed) NatSpec / optional interface methods with product law (`thresholdMode`, live-coupled allow views, synthetic gates).
2. **F7** — **Audit** `contracts/vaults/seigniorage/` and either:
   - **Parity:** wire Policy/Open + synthetic gates like F1–F5, **or**
   - **Formal Out:** document that the package is frozen/unused and **out of** threshold-mode implement scope.

Then mark **P6 `done`** in the tracker and **stop** (do not start P7 AGENTS.md unless this session’s Out/parity work already required a one-line inventory note — full P7 is separate).

Copy this entire file into a new agent session.

You are an **execution agent**. Product law is formal **LOCKED**. Do not re-open Policy/Open economics. Prefer **audit evidence** over assumption for F7.

---

## Program context (as of handoff)

| Phase | Status |
|-------|--------|
| **P0–P5** | `done` — core + F1–F5 shipped (incl. F5 synthetic migration); PRD formal LOCKED |
| **P6** F6 NatSpec + F7 audit parity-or-Out | **`todo` → you** |
| **P7** AGENTS.md + family PRD “conforms to …” | out of scope (next after P6) |

Tracker: `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` (update as you go).  
PRD inventory: `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` §7 F6/F7 rows + changelog if F7 decision lands.

---

## Read first (in order)

1. `contracts/vaults/detf/DETF_Threshold_Modes_PRD.md` — **LOCKED** + **§16**; §7 **F6** / **F7** inventory; claim `RedemptionNotAllowed` independent of Open
2. `contracts/vaults/detf/DETF_Threshold_Modes_PROGRESS.md` — Wave 4 stubs for F6/F7
3. Core (shipped): `contracts/vaults/detf/core/DETFThresholdPolicy.sol`
4. **F6 surfaces:**
   - `contracts/interfaces/IProtocolDETF.sol`
   - `contracts/interfaces/IProtocolDETFErrors.sol`
   - `contracts/interfaces/proxies/IProtocolDETFProxy.sol` (if present)
   - F5 implementer (reference): `contracts/vaults/detf/composed/single/` (now has `thresholdMode()`)
5. **F7 surfaces:**
   - `contracts/vaults/seigniorage/**` (DETF + NFT vault + factories)
   - `contracts/interfaces/ISeigniorageDETF.sol` (+ errors if any)
   - `SeigniorageDETF_ADVERSARIAL_TEST_PLAN.md`
   - Tests: `test/foundry/spec/protocol/vaults/seigniorage/**`, fork under `test/foundry/fork/**/seigniorage/**`
6. Repo `Agents.md` — production-first if you implement F7 parity; role names only

---

## Scope (strict)

### In scope

#### F6 — IProtocolDETF interface / NatSpec

- Add / align NatSpec for mint/burn **Policy deadband** vs **Open** (deploy-time mode; gates always synthetic).
- Add **`thresholdMode()`** to the interface (or document why optional inheritance differs) so F5 and future implementers share a typed surface.
- Align comments that still imply “always Policy” or confuse synthetic with pure spot.
- Confirm `MintingNotAllowed` / `BurningNotAllowed` remain the gate errors; **`RedemptionNotAllowed` stays independent of Open** (claim path).
- Proxy interface: add selector only if the proxy interface enumerates methods (match existing style).
- Minimal compile fixes if adding interface methods requires implementers already on the diamond to match (F5 already has `thresholdMode()` — good).

#### F7 — Seigniorage audit → parity **or** Out

**Step A — Audit (required before code):**

Document in PROGRESS (and a short markdown note under `contracts/vaults/seigniorage/` **or** expand tracker F7 section) with evidence:

| Question | How to answer |
|----------|----------------|
| Is this still a **true DETF** (diamond share + seigniorage mint/burn vs reserve)? | Read Common / ExchangeIn-Out / DFPkg |
| Gate price today | synthetic / spot / peg heuristic / none? |
| Thresholds / mode storage? | Repo + PkgArgs |
| Deployed / launched / maintained? | Tests still green? Scripts/deploy refs? Comments “legacy”? |
| Active production path vs abandoned? | Grep deploy scripts, frontend, registry types |

**Step B — Decision (exactly one):**

| Decision | When | Work |
|----------|------|------|
| **Parity** | Package is active true DETF that should remain launchable | Full product-law wiring like F1–F5: trailing `thresholdMode`, resolve/validate, synthetic gates, live-coupled info, `ThresholdModeSet`, Open helpers/tests as needed |
| **Formal Out** | Frozen unused legacy; no further product surface | **Do not** implement mode wiring. Document **Out** in PROGRESS + PRD inventory F7 row + short note in seigniorage plan/README if one exists. Leave code as-is. |

**Bias:** Program intent is migrate all true DETFs **if active**. Prefer **Out** only with concrete evidence of abandonment (no deploy path, tests skipped/broken by design, explicit legacy markers, zero product references). If ambiguous, **document evidence and choose Out only if maintenance cost dominates and human would accept abandoning the package**; otherwise implement **Parity** or mark `blocked` with a short question in PROGRESS (prefer not blocking — make the best call with evidence).

### Out of scope

- Re-opening F1–F5 product behavior
- P7 AGENTS.md + multi-family “conforms to …” sweep (except a single F7 Out inventory line if needed)
- Frontend, fee-oracle thresholds, asymmetric modes
- DualLiquidity / Standard Exchange (explicitly out of this PRD)
- Expanding claim-redeem into Open gates

---

## Locked product rules (if F7 parity)

Same as F1–F5:

- Explicit `ThresholdMode { Policy, Open }`; never infer Open from zeros
- `0,0` → `1.05e18` / `0.95e18`
- After resolve: mint > burn both modes
- Gates **synthetic**; live in family; Open short-circuit only in lib
- MUST: `thresholdMode()`, live-coupled `isMintingAllowed()` / `isBurningAllowed()`
- `ThresholdModeSet` once at init, resolved values
- Trailing `PkgArgs.thresholdMode`
- Production-first; role names only

### Upstream API (shipped)

```text
// DETFThresholdPolicy.sol
enum ThresholdMode { Policy, Open }
resolveAndRequireValidThresholds / requireValidThresholdMode
_isMintingAllowed(mode, mintTh, price) / _isBurningAllowed(mode, burnTh, price)
// 2-arg Policy wrappers remain for any unported call sites during migration
```

---

## F6 detailed acceptance

- [ ] `IProtocolDETF` documents Policy vs Open and synthetic gate input (NatSpec accurate)
- [ ] `thresholdMode()` present on interface (return type `ThresholdMode` from core lib, or uint8 if diamond style forces — **prefer** `ThresholdMode` import)
- [ ] `isMintingAllowed` / `isBurningAllowed` NatSpec: inert/live + mode + synthetic (not “Policy only”)
- [ ] `mintThreshold` / `burnThreshold` NatSpec: display/storage; Open still stores resolved values; gates ignore under Open
- [ ] Errors file: no claim that Open removes `RedemptionNotAllowed`
- [ ] `forge build` still green for implementers (esp. F5 SingleVaultDetf)
- [ ] Optional smoke: `forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**' -vv` if interface change risks F5

---

## F7 detailed acceptance

### If Out

- [ ] Written audit summary (paths checked, gate pattern today, deploy/test evidence)
- [ ] PROGRESS F7 status = `done` with **Out** + date
- [ ] PRD inventory F7 row updated (Open formalized = **Out** / not shipping)
- [ ] No half-wired mode storage without tests

### If Parity

- [ ] Trailing mode + resolve/validate + event
- [ ] Synthetic (or already-correct) gates + mode-aware lib + live family
- [ ] Info surface + selectors
- [ ] Tests green for seigniorage suite(s) you own:

```bash
forge test --match-path 'test/foundry/spec/protocol/vaults/seigniorage/**' -vv
# plus fork only if you touch fork-only wiring and can run it
```

- [ ] PROGRESS F7 = `done` with **Parity** + pass counts
- [ ] PRD inventory F7 updated (Open formalized = Yes/shipped or in progress → shipped)

---

## Process

1. Set **P6** to `in_progress` in PROGRESS (date + “F6 + F7”).
2. **F6 first** (usually small interface/NatSpec pass).
3. **F7 audit** → write decision + evidence in PROGRESS.
4. Execute **Parity implement** or **Out documentation** only.
5. Update PRD inventory/changelog lightly for F7 decision (no product-law rewrites).
6. Mark **P6 `done`**. Leave **P7 `todo`**.
7. **Stop.**

---

## Exact verify commands

```bash
forge build

# F6 / F5 implementer safety if interface methods added
forge test --match-path 'test/foundry/spec/vaults/detf/composed/single/**' -vv

# F7 only if Parity implement
forge test --match-path 'test/foundry/spec/protocol/vaults/seigniorage/**' -vv
```

If F7 is **Out**, forge seigniorage suite is **not** required for P6 DoD (document that).

---

## Success / definition of done (P6)

| Item | Done when |
|------|-----------|
| F6 | Interface + NatSpec aligned; `thresholdMode` on surface; build (and F5 smoke if needed) green |
| F7 | Audit recorded **and** either Parity shipped green **or** formal Out documented |
| Tracker | P6 `done`; F6/F7 rows updated; changelog entry |
| PRD | Inventory F7 (and F6 if needed) reflects shipped/Out |
| Handoff | Next = **P7** AGENTS.md + family PRD conform notes |

Tracker changelog example:

> P6 done: F6 IProtocolDETF thresholdMode + NatSpec; F7 **Out** (evidence: …) | **or** F7 **Parity** (N/N seigniorage tests). Next: P7 AGENTS + conform notes.

---

## Handoff

- **Do not start P7** (full AGENTS.md + multi-family “conforms to …” sweep) in this session.
- Do not re-open F1–F5 packages except minimal interface inheritance compile fixes.
- If F7 Parity is large and blocked mid-flight: leave P6 `in_progress`, document partial work, do not claim done.

---

## Risks

| Risk | Response |
|------|----------|
| F7 half-migrated | Forbidden — full Parity or clean Out |
| Interface break for non-F5 implementers | Grep implementers of `IProtocolDETF`; add method only if all can satisfy or use optional separate interface (prefer single MUST surface as PRD) |
| Claiming Out without evidence | Require written audit table |
| Expanding claim into Open | Out of scope |
| Spot gates on F7 if Parity | Migrate to synthetic like F5 |
