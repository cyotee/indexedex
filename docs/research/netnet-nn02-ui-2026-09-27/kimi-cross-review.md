# Kimi K3 — NN-02 UI challenge CROSS-REVIEW (Astra / Grok / MiniMax M3 originals)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Basis | Full reads of the three originals (untrusted evidence); my unchanged original. No peer cross-reviews. |

## 1. Four-way consensus (verified)

- **Standard BondDepository (`0xff32…1980C1`): no selective claim exists.** Live Sourcify record: `creationMatch`/`runtimeMatch` = `exact_match`, `verifiedAt 2026-07-16T20:34:17Z`, compiler 0.8.30 (fetched independently by me and Astra, both full ABI; Grok's Sourcify file endpoints 403/404'd — his "cannot list deployed signatures" is superseded, not contradicted).
- **Do not generalize "all NetNet bonds":** GenesisBond is scalar per-account (`GenesisBond.sol:55–57,186–209`), InverseBond is a one-shot swap, TURBO is ERC-1155, and RWA/Superstore desks are **external, unvendored** contracts whose docs advertise "per-address caps and a **paginated redeem**" (Superstore docs, fetched by Grok/MiniMax) — pagination is **documentary, wrong contract** for NN-02's depository; `paginated` appears in zero vendored Solidity files (MiniMax verified).
- **UI per-row display ≠ per-note write.** Grok's RWA-docs find ("subscription ledger… alongside any standard bonds") means a UI Claim button may target different contracts per row; the standard-depository path remains aggregate-only.
- **Exact UI write handler: untraced by everyone.** Astra: refuses to "replace missing evidence with the assumption `redeem(connectedWallet)`." Grok: "cannot state the wallet to/data." Mine: flagged as ABI-completeness inference. The source map is 404; no public NetNet repo found (absence from search ≠ nonexistence).
- **No observed outage, no measured distribution, no gas numbers.** NN-02 stays an open risk, not an incident.

## 2. New disconfirming leads — and why they don't move the standard path

Astra's bundle fragments are the round's best new evidence: line 93 `Ae("rwaDesk")` + noteCount-based reading; line 94 **`TooManyNotes` "Redeem some first,"** and **`PayoutBelowMinimum` "less than 0.01 NET"**; line 95 `Ae("assetBondDesk")`. These prove the app carries **multiple bond-product code paths with cap/minimum error text** — but those errors/checks exist nowhere in the standard depository's source or ABI, so they belong to other desks or UI-side validation. They disconfirm blanket claims about *the whole NetNet UI*, not the analysis of `0xff32…`.

## 3. Corrections (attributed)

- **C1 (self, per Astra + moderator): exact_match scope tempered.** Sourcify's record attests the *dumped* source ≡ deployed bytecode (creation+runtime, as verified 2026-07-16). The local **port** is an *adaptation* (imports rewritten per VENDOR.md) whose equivalence to the dump is manual comparison, not byte-identity; and Astra's nuance stands: shared `Constants.sol` came from NET's dump, cross-checked against the depository's own dumped Constants. "Code cannot change" rests on EVM immutability of non-proxy code — redeployment/selfdestruct history was not event-checked. NN-01 wording: record the depository row as **verification-service source evidence (Sourcify exact_match, 2026-07-16; accessed 2026-09-27)** — strong, scoped, and **not** "all deployment checks complete" (Astra). The **2-day vesting** now has verification-service compilation evidence vs stale interface prose; current *state* (tax, exemptions, live fees) remains open.
- **C2 (MiniMax §2): reject "typical user buys 1–2 bonds… not meaningfully affected."** No distribution was measured — Astra explicitly measured none. Also reject my own softer "retail holders hold few notes" on the same ground. And MiniMax R3's "view… free (off-chain eth_call)": views are not consensus-metered but are **not free/unlimited** — RPC gas caps and rate limits apply; a huge array can break rendering too.
- **C3 (self + MiniMax): "bounded gifts"/"can ignore dust" rejected as comfort claims.** Unsolicited notes cost the attacker, but a holder who wants *their own* vested value cannot skip the dust — the aggregate scan visits everything. Temper to: gifts transfer value; they never reduce work.
- **C4 (MiniMax, repeated from last round):** again lists BoardroomDesk/NetNetGear/BasketsDesk/Credit/StockMorphoOracles as pinned in `ROBINHOOD_MAIN.sol:485–528`. My full pre-update read contains none of them (that range ends at blackjack :527). They **do** appear on `docs.netnet.capital/official-channels` (my own fetch) — likely the confusion source. Caveat: the user-reported constants update happened after my read; current file state not re-verified this round.
- **C5 (Grok, retained):** his "Sourcify metadata without files" was endpoint-specific; the ABI *was* served at `?fields=abi` (me) and `?fields=abi,compilation,sources` (Astra). Peer gaps filled, not errors.

## 4. Remaining UI gap and honest status

**Exact claim handler: still not extracted** by anyone. What is established: (a) the contract exposes exactly one claim-capable write, so any successful standard-bond claim tx must call `redeem`; (b) the bundle contains the ABI strings, `noteCount`/`pendingFor`/`maxPriceWad`/`BondRedeemed`, and multi-desk paths with cap/minimum errors. What is *not* established: the precise target/args encoding per UI button, row filtering, or display pagination. Next permitted step: targeted static extraction of the public bundle around the `redeem` ABI occurrences, or an official repo/artifact from NetNet if one surfaces — then trace per product. Until then the honest statement is Astra's: ABI completeness constrains the handler to one possible write; the handler itself is unquoted.

## 5. Impact on NN-01/NN-02

- **NN-01:** two rows strengthen with scoped wording (depository source via Sourcify exact_match; vesting = 2 days from the same compilation). Nothing else closes; live state checks (pair tokens/fees, tax/exemption, SY conversion, Blockscout re-pull post-update) remain pending.
- **NN-02:** unchanged as *risk analysis* — no selective upstream claim, no wrapper-side bound on the scan, no observed outage, no measured economics. The investigate-first checkpoint from the prior cross-review stands, now with the ABI-certainty caveat eliminated and the UI evidence honestly partial.

## 6. Limits

Peer claims treated as untrusted; all shared code/ABI/docs facts cross-matched to my own reads/fetches this session. Bundle line numbers are session-cache references (Astra's 93–95; my saved fetch), not stable citations. Post-update constants file not re-read. No execution, no keys, no RPC; originals unchanged.
