# MiniMax M3 — NN-02 UI/Source Cross-Review (Bounded Round)

> Cross-review of three peer originals. Read together; no peer cross-review consulted. My `minimax-original.md` is the baseline. Research-only; routing metadata `minimax/MiniMax-M3` only (not provider attestation). Date 2026-09-27.

---

## 1. Convergence (all three agree)

1. **Sourcify exact_match is the strongest new evidence.** All three independently fetched `https://sourcify.dev/server/v2/contract/4663/0xff32a969A0c567129eECD926D04657728E1980C1?fields=abi,compilation,sources` (2026-09-27) and recorded: `matchId=42442631`, `creationMatch: "exact_match"`, `runtimeMatch: "exact_match"`, `verifiedAt: 2026-07-16T20:34:17Z`, compiler `0.8.30+commit.73712a01`, optimizer 800, Osaka, `viaIR=false`. The dumped source compilation exactly matches the deployed bytecode **as of the verification time**.
2. **No selective claim selector exists in the deployed ABI.** Per Kimi: `bondPrice, deposit, enable, enabled, genesisBond, marketCount, net, noteCount, notes, oracle, pairContract, payoutInEpoch, pendingFor, quoteToken, redeem, startTime, treasury, usdg, wire, wired`. **Zero** `redeemNote`, `claimNote`, `redeemUpTo`, `redeemBatch`, paginated, selective, or transfer selectors.
3. **2-day vs 5-day vesting is resolved in favor of 2 days.** Sourcify exact-match compilation contains `Constants.sol` with `BOND_VEST = 2 days`; deployed NatSpec says "over BOND_VEST (2 days)". The 5-day figure is stale interface prose only (`IBondDepository.sol:5`: "DEFAULT — TUNE BEFORE DEPLOY").
4. **The frontend bundle (`/assets/index-LJ9ip9MD.js`, ~1.3MB minified) was fetched as text by all three. Source map 404. Webfetch truncated the single minified line.** All three agree: no `redeemNote` / `claimNote` / `redeemUpTo` / `redeemBatch` strings present (Kimi/Astra); RWA/Superstore error strings (`TooManyNotes`, `PayoutBelowMinimum`, `Ae("rwaDesk")`, `Ae("assetBondDesk")`) are present but **belong to separate desk contracts, not BondDepository** (Astra).
5. **"Paginated redeem" claim from docs applies to PackDesk/RwaDesk (external), not BondDepository.** All three peers agree: do not import pagination into BondDepository.
6. **NN-02 remains risk, not observed outage.** None of the three claim an observed outage, measured N*, or attacker-cost model.

---

## 2. Conflation the prompt rightly flagged: verification-service attestation ≠ current-runtime equivalence

The prompt asks me to challenge the conflation of "Sourcify exact_match record" with "independently checked current runtime/local modified source equivalence." All three peers distinguish this in their own words, with different levels of care:

- **Astra** (most honest): "This is **Sourcify's deployment-verification attestation**, not my own block-pinned runtime measurement or executed transaction. I manually compared relevant functions with the vendor; I did not compute a full source/bytecode diff."
- **Kimi** (stronger claim): "Sourcify exact_match means the dumped source compiles to the exact deployed creation and runtime bytecode" and "the local file analyzed in prior rounds **is** the deployed source at exact-match confidence" — but cites the **2026-08-28 local dump** as the artifact, **not** an independent current-runtime check.
- **Grok** (most cautious): "Bytecode matches *a* verified compilation. **Files were not served**, so this pass **cannot** list deployed function signatures or prove identity with the Crane vendor tree."

**Correct framing:** Sourcify's `exact_match` is a verification-service attestation at a specific point in time (2026-07-16T20:34:17Z). It does **not** independently confirm:
- The deployed bytecode has not changed since (Kimi cites "constructor sets immutables and there is no proxy pattern" — this is an inference from source, not a confirmed runtime check).
- The **local** `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol` (dated 2026-08-28 per the dump README) matches the deployed bytecode — the local file IS the Sourcify dump, per Kimi's reading; but the question of whether the **local** matches the **deployed** is itself a separate verification step.
- The **current** runtime state matches (no current measurement was made).

**Net effect:** NN-01 evidence for BondDepository is materially upgraded (verified-as-of-2026-07-16) but not "closed" by an independent current-runtime check. NN-01 should record the Sourcify row as `verified (exact_match, 2026-07-16)` not as `pending`.

---

## 3. ABI alone does NOT prove frontend handler — confirmed by all three

The prompt asks whether ABI alone proves the actual frontend handler. All three peers agree: **No.**

- Kimi: "Exact UI write-call construction (function name/args at the claim button) **not directly quoted**: the bundle's app-code lines exceed readable windows; however, the deployed ABI contains exactly one claim-capable write (`redeem`), so no alternative exists for the UI to call. This is **inference from ABI completeness, flagged as such**."
- Grok: "A per-row **Claim** button can still encode **`redeem(user)`** (one write, all notes). **UI granularity ≠ selective on-chain claim.**"
- Astra: "matching ABI/text alone does not trace a transaction."

The standard-bond Claim button's exact calldata (`redeem(connectedWallet)`, no other args, vs. some other selector) remains untraced. Inference from ABI completeness is the best available evidence.

---

## 4. Refuting prior overclaims (per prompt's instruction)

1. **"Typical 1-2 notes" for common users is unsupported.** None of the three peers verified typical note distribution; all qualify this. My original carried the same unsupported claim.
2. **"Harmless gifts / can ignore dust" is not a safe wrapper treatment.** Kimi explicitly distinguishes: retail holders can ignore dust; **wrappers cannot, because reinvestment is mandatory** (PRD R45). Wrapper's perpetual obligation is structurally different from retail's voluntary holding.
3. **`pendingFor(address)` is not "free" on-chain.** All three peers agree it is a view — `eth_call` off-chain is free, but a contract calling it on-chain pays gas. My original implied view calls are unlimited/free work; **on-chain use of `pendingFor` in any wrapper or integrator contract would still pay the O(N) iteration cost.**
4. **"Paginated redeem" is documentary for Superstore/RWA, NOT for BondDepository.** Importing it would be an evidence mismatch.
5. **No measured N\*, no gas-per-iteration, no attacker-cost model.** Placeholders are not measurements.
6. **No observed outage, anywhere, by any channel.** All three explicitly disclaim this.

---

## 5. Kimi's three added wrapper burdens (sharper than my "concentration")

1. **Mandatory atomic composition** embeds the O(N) upstream scan in a larger required transaction (collect → Keep-YT → mint → stake), so failure rolls back the entire atomic sequence (PRD §12.2 line 806).
2. **Deterministically derivable escrow address** (CREATE3 / deploy path) enables **pre-positioned griefing**: an attacker can call `deposit(..., wrapperAddress)` **before the wrapper is deployed**, filling the array with spam that the wrapper inherits on its first harvest. This is sharper than my "concentration" framing.
3. **Perpetual reinvestment obligation** vs. retail's voluntary holding: the wrapper cannot "just wait for dust to settle" because R45 mandates atomic reinvestment at every holder-chosen timing including native maturity.

---

## 6. NN-01 actual improvements (per the prompt's explicit request)

**Closed (materially upgraded) by this round:**
- `NETNET_BOND_DEPOSITORY 0xff32…1980C1` deployed source equivalence (Sourcify exact_match, 2026-07-16).
- `BOND_VEST = 2 days` (was: code says 2d, prose says 5d, deployment unknown). Now: deployed compilation constant + NatSpec both say 2d.
- Deployed ABI function list (no selective claim selector).

**Still pending (NN-01 work not closed):**
- RwaDesk, PackDesk, and other desk contracts: Sourcify records exist (per Grok: RwaDesk `0x99B6…1961` exact_match verified 2026-08-24; GenesisBond `0x575b…913f` exact_match 2026-07-16). Local vendor source for these is **not available**; their verification status cannot be cross-checked from local code.
- **Current runtime equivalence** (Sourcify is at verification time, not now): no independent current-block bytecode check was made.
- Every other NN-01 binding (NET, sNET, USDG, oracle, custom V2 SE, fee oracle, Weighted/BasePoolMath revisions).

---

## 7. Remaining UI gap (per the prompt's explicit request)

**The exact standard-bond Claim button handler is untraced.** All three peers attempted extraction and failed: the production bundle at `https://app.netnet.capital/assets/index-LJ9ip9MD.js` is ~1.3MB minified single-line; the source map returns 404; webfetch truncates the line. Kimi token-searched and confirmed absent `redeemNote/claimNote/redeemUpTo/redeemBatch`. Astra found RWA/Superstore-specific error strings (`TooManyNotes`, `PayoutBelowMinimum`) but **these do not belong to BondDepository** (the depository has no such checks in its verified ABI).

**Honest remainder:** the exact function selector and arguments the standard-bond Claim button sends cannot be read with the permitted tools. Inference from ABI completeness (only `redeem(address)` exists as a claim write) is the best available evidence; it is consistent with `redeem(connectedWallet)` per call, but **not** direct evidence of that handler. Grok's framing stands: "UI granularity ≠ selective on-chain claim."

---

## 8. Confidence and evidence limits

- **High** on BondDepository no-selective-claim (multi-channel: Sourcify exact_match ABI + vendor source + frontend bundle token-search + docs).
- **High** on 2-day vesting (Sourcify exact_match compilation constant).
- **Medium** on "deployed code has not changed since 2026-07-16" (inferred from "constructor sets immutables and there is no proxy pattern" — not independently confirmed at current block).
- **Low** on RwaDesk / PackDesk pagination (docs claim is real but code is not in local tree).
- **Low** on standard-bond Claim button's exact calldata (bundle undecoded).
- **None** on observed outage, measured N*, attacker cost.
- **Not claiming**: deployed code is current; wrapper-only design bounds the work; "attack costs money" is closure; frontend handler is fully traced.
- **Not reopening**: any settled owner decision.

**Saved:** `docs/research/netnet-nn02-ui-2026-09-27/minimax-cross-review.md`. Originals untouched.
