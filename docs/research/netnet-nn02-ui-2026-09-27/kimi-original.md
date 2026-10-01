# Kimi K3 — ORIGINAL: NN-02 challenge round — does NetNet code/UI offer a selective bond claim?

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only, not provider attestation |
| Date | 2026-09-27 |
| Mission | Actively seek **disconfirming** evidence against "no selective bond claim exists." Every channel examined **confirmed** the conclusion; several also upgraded prior provenance gaps. No browser/JS execution, no shell/RPC/tests, no keys sent externally. |

## 1. Disconfirmation search — channels and results

### 1.1 Live deployed ABI (strongest evidence): Sourcify exact_match

`GET https://sourcify.dev/server/v2/contract/4663/0xff32a969A0c567129eECD926D04657728E1980C1?fields=abi` (accessed 2026-09-27) returns **`creationMatch: "exact_match"`, `runtimeMatch: "exact_match"`, `verifiedAt: 2026-07-16T20:34:17Z`, compiler 0.8.30**. Sourcify exact_match means the dumped source compiles to the exact deployed creation and runtime bytecode. The complete deployed function list: `bondPrice, deposit, enable, enabled, genesisBond, marketCount, net, noteCount, notes, oracle, pairContract, payoutInEpoch, pendingFor, quoteToken, redeem, startTime, treasury, usdg, wire, wired`. **There is no `redeemNote`, `claimNote`, `redeemUpTo`, batch, paginated, selective or transfer selector.** The only claim write is aggregate `redeem(address to)`. The public per-note getter `notes(address,uint256) → (payout, claimed, start, end)` and `noteCount(address)` are confirmed **in the live ABI**, not just source. Because the constructor sets immutables and there is no proxy pattern, this contract's code cannot have changed since verification.

### 1.2 Vendor provenance (local)

`lib/crane/contracts/protocols/pol/net/VENDOR.md:1–18,38` — the local `BondDepository.sol` was dumped 2026-08-28 from **Sourcify + Blockscout PRO verified sources** at `0xff32…1980C1`; `scripts/netnet/dump/by-address/0xff32…/metadata.json` independently records `backend: sourcify, match: exact_match, verifiedAt: 2026-07-16T20:34:17Z`. So the local file analyzed in prior rounds **is** the deployed source at exact-match confidence. Bonus closure: the dump's own NatSpec says "over BOND_VEST (2 days)" and `Constants.sol:76` (`BOND_VEST = 2 days`) is in the same exact-match compilation — **deployed vesting is 2 days**; the 5-day figure is stale prose in `IBondDepository.sol:5` ("DEFAULT — TUNE BEFORE DEPLOY"), never the deployed value.

### 1.3 Other NetNet bond products (structurally different, no hidden selective path)

`GenesisBond.sol:186–209` — scalar per-account accounting (`claim()`, `claimableNetOf`); no array. `InverseBond.sol` — standing bid, no notes. TURBO desk — ERC-1155, different family. Only `BondDepository` has the note-array shape. Crane's own wrapper `services/NetNetBondService.sol:73–81` merely forwards `p.bondDepository.redeem(p.to)` — no selective helper exists even in our own integration layer. The futures-desk `Zap.sol` contains **no** bond/redeem/note references (grep, this session).

### 1.4 Official documentation

`docs.netnet.capital/mechanism` (fetched 2026-09-27) §5 describes bond pricing/capacity only; `FEES.HTM` confirms "Staking, bonding, offering, claim, and all protocol operations — **none** (whitelisted)" covering BondDepository — i.e., claims exist and are fee-exempt, but no selective-claim UX is described anywhere. `official-channels` (fetched 2026-09-27) lists every NetNet contract: **no bond-claim helper/router exists** beyond the depository itself.

### 1.5 Official frontend bundle

`https://app.netnet.capital/` HTML references `/assets/index-LJ9ip9MD.js` (fetched as static text 2026-09-27; ~1.3 MB, no JS execution). Token search of the production bundle:

- Present: `0xff32a969` (depository address), `noteCount`, `pendingFor`, `maxPriceWad` (deposit slippage guard), `BondRedeemed` (event, history display), `"redeem"` ABI/call strings.
- **Absent: zero occurrences of `redeemNote`, `claimNote`, `redeemUpTo`, `redeemBatch`.**

The official UI therefore: **displays** per-note positions (public `notes` getter / `noteCount` / `pendingFor` / `BondCreated`+`BondRedeemed` events) and **writes** only deposits (with `maxPriceWad`) and the aggregate `redeem`. Per-note display is not per-note write.

### 1.6 Explorer

`https://robinhoodchain.blockscout.com/api/v2/smart-contracts/0xff32…` → **403** (Cloudflare; consistent with the dump README's note that the public instance needs a PRO key). Recorded as inaccessible; Sourcify provided the same evidence class. Not retried on the exact URL.

## 2. Answers

**Are we sure there is no selective bond claim?** Yes, to the strongest evidence standard available without re-verifying bytecode ourselves: live Sourcify exact_match ABI + exact-match source dump + official contract registry + official frontend bundle all agree. The conclusion survived an active disconfirmation search on every channel.

**How does the all-note problem affect ordinary NetNet bond holders, and how does the UI handle it?** Structurally it affects every holder equally: anyone can append notes to any address, and every claim scans the holder's full history forever (claimed notes are never pruned). In practice the UI treats claims as casual, user-timed, single aggregate transactions; a retail holder holds few notes, has no composition deadline, and can claim whenever convenient. Unsolicited notes to an EOA are bounded gifts (principal is paid; payout vests to the holder). Nothing in the official surface offers or needs selectivity.

**What is different for our wrapper?** Three added burdens, none present for retail: (a) the **mandatory atomic composition** — collect → Keep-YT → mint → stake must succeed in one transaction at holder-chosen times including native maturity (R45), so the O(N) upstream scan is embedded in a larger required transaction rather than standing alone; (b) the escrow address is **deterministically derivable in advance** (CREATE3/deploy path), so griefing can be pre-positioned before first use; (c) the wrapper's obligation is perpetual per position — it cannot simply choose to never claim, because reinvestment is mandatory, whereas a retail holder can ignore dust and claim only when worthwhile.

## 3. Corrections to prior overclaims (mine, attributed)

- **C1: "deployed equivalence pending NN-01" is substantially narrowed for the depository.** Live Sourcify exact_match (creation+runtime, verified 2026-07-16, immutable non-proxy) establishes local source ≡ deployed contract at `0xff32…1980C1`. The NN-01 manifest should record this row as **verified (Sourcify exact_match, accessed 2026-09-27)** rather than pending.
- **C2: the 2d-vs-5d vesting "unresolved deployment fact" is resolved in favor of 2 days** (exact-match compilation constant + deployed NatSpec); the 5-day text is stale interface prose. Record the resolution with provenance.
- **C3 (retained, no change):** all quantitative claims (per-iteration gas, N*, attacker cost) remain **unmeasured** — this round produced no gas evidence and none is claimed. Whether ordinary holders have ever experienced an outage from array growth is **not evidenced anywhere** and is not claimed.

## 4. Residual gaps (honest)

- Exact UI write-call construction (function name/args at the claim button) not directly quoted: the bundle's app-code lines exceed readable windows; however, the deployed ABI contains exactly one claim-capable write (`redeem`), so no alternative exists for the UI to call. This is inference from ABI completeness, flagged as such.
- UI-side minimum-deposit display thresholds, if any, not extracted.
- Blockscout PRO not queried (would require sending an API key externally — out of bounds).
- Side observation for NN-01/NN-13 (not solved here): FEES.HTM's exemption whitelist covers NetNet's own protocol contracts; the wrapper's Keep-YT path moves NET into Pendle SY/market addresses whose exemption status is unverified (queued-exemption delay is 2 days, `Constants.sol:41`).

## 5. Impact on NN-02

The design space confirmed in the prior round is unchanged: no upstream selective claim exists or is plausibly hidden; wrapper-only bounding of the upstream scan remains impossible; the quantified-liveness-study checkpoint recommended in the NN-02 cross-review stands. What this round adds is **certainty about the ABI** (eliminating Grok's "deployed code may differ" caveat) and two NN-01 sub-closures (depository source equivalence; 2-day vesting).
