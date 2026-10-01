# Astra — NN-02 UI/deployed-source challenge ORIGINAL

**2026-09-27; independent challenge pass, prior history retained.** Assigned routing `openai/gpt-6-astra`, not provider attestation. No new-round peer artifacts read. Research-only; no RPC, shell, JS/browser execution, tests, deployment, code/configuration edits or delegation. Only this report written.

## Answer and changed evidence

**For the selected standard BondDepository, I found stronger evidence for all-note redemption, not a selective claim. This affects ordinary holders of that contract too. It must not be generalized to every NetNet product called a bond/note.**

Crucially, this is no longer supported only by the local vendor: **Sourcify returned an exact-match verification record, ABI and source for chain 4663/address `0xff32a969A0c567129eECD926D04657728E1980C1`.** The ABI exposes `redeem(address)` but no note-specific/range redemption; the returned implementation performs the same full-array scan. This materially strengthens—and narrows—the previous source-only conclusion.

**UI investigation is partial.** I fetched the official HTML and production JavaScript as text, found multiple bond-product code paths and minimum-note/count error messages, but could not fully extract the minified standard-bond write handler with the permitted tools. I therefore do **not** claim to have established its exact wallet-call target/signature/arguments. That remains an explicit gap, rather than inferring a handler from a button label or ABI occurrence.

## 1. Public verification evidence

After Context7 lookup for Blockscout/Sourcify APIs, these read-only HTTP requests were made:

- Blockscout `/api/v2/smart-contracts/0xff32…1980C1` and legacy `getsourcecode`: both **403**; no successful Blockscout verification claimed.
- [Sourcify complete verification record](https://sourcify.dev/server/v2/contract/4663/0xff32a969A0c567129eECD926D04657728E1980C1?fields=all).
- [Sourcify focused ABI/compiler/source response](https://sourcify.dev/server/v2/contract/4663/0xff32a969A0c567129eECD926D04657728E1980C1?fields=abi,compilation,sources), fully inspectable.

Record: `matchId=42442631`, `creationMatch=exact_match`, `runtimeMatch=exact_match`, `verifiedAt=2026-07-16T20:34:17Z`; contract `src/BondDepository.sol:BondDepository`; compiler `0.8.30+commit.73712a01`, optimizer 800, Osaka, `viaIR=false`.

The **complete returned ABI** includes individual **reads** `notes(address,uint256)` and `noteCount(address)`; aggregate read `pendingFor(address)`; and the sole redemption write `redeem(address to)`. The source reads `notes[msg.sender]`, loops from zero to its full length, increments `claimed`, then transfers aggregate NET to `to`. No cursor, deletion, pop, compaction, selective overload, delegatecall fallback, or receiver-controlled note admission appears in this implementation. Returned `Wired` source only supplies initialization guards, not an alternate claim path.

This is **Sourcify's deployment-verification attestation**, not my own block-pinned runtime measurement or executed transaction. I manually compared relevant functions with the vendor; I did not compute a full source/bytecode diff. The shared returned Constants source says `BOND_VEST=2 days`; stale interface prose still says five. Thus the two-day case now has verification-service source evidence, not just a local constant. It does not validate every other NN-01 dependency.

## 2. Vendor, service and tests independently checked

Local prefix `lib/crane/contracts/protocols/pol/net/`:

- `VENDOR.md:5–17,33–51`: no public upstream Git reported; 2026-08-28 verified-source dump from Sourcify/Blockscout, explicit address map and remapped imports. Crucially, shared `Constants.sol` was copied from NET, not independently from every dependency. The public depository response above supplies its own Constants and agrees on the relevant bond values.
- `src/BondDepository.sol:104–139`: arbitrary `to`; only positive payment is required; append after floor-rounded payout. `:143–165`: all-note redemption and aggregate preview, including historical entries. `:183–198`: cap on payout value and linear vesting, not note count. Public verification source matches these relevant behaviors.
- `src/interfaces/IBondDepository.sol:28–42`: aggregate-only redemption declaration. The concrete ABI adds individual getters, **not selective writes**.
- `services/NetNetBondService.sol:67–79`: calls `deposit(marketId,amount,maxPriceWad,to)` and directly `redeem(to)`; no hidden batching/pruning helper. Caller context is the service-using contract, not necessarily a user EOA.
- `lib/crane/test/foundry/spec/protocols/pol/net/hermetic/NetNet_Bond.t.sol:14–44` and `fork/NetNetFork_Bond.t.sol:14–36`: one USDG bond followed by aggregate redemption. These tests were read, not run; they do not prove arbitrary-history liveness or selective claims. `Behavior_IBondDepository.sol:43–50` checks vesting arithmetic only.

## 3. What the current UI evidence does—and does not—show

[Official Channels](https://docs.netnet.capital/official-channels) identifies `app.netnet.capital` as Shareholder Services and publishes the selected depository address. [App HTML](https://app.netnet.capital) loads:

`https://app.netnet.capital/assets/index-LJ9ip9MD.js`

I downloaded that public bundle without executing it. Allowed read/grep output truncates or omits its extremely long minified lines; a `.js.map` request returned **404**. The text was searched for redemption/claim variants, individual-note reads and the selected address, but matching ABI/text alone does not trace a transaction.

Directly readable fragments show:

- cached bundle line 93: `Ae("rwaDesk")`, legacy/current RWA desk selection, and `noteCount`-based reading;
- line 94: `TooManyNotes` text “Redeem some first,” and `PayoutBelowMinimum` text “less than 0.01 NET”;
- line 95: a separate `Ae("assetBondDesk")` path.

**These are disconfirming leads against blanket claims about all NetNet bond UIs.** They are not evidence that the standard `0xff32…` depository has a note cap, pruning or 0.01-NET minimum: its public source/ABI does not contain those errors/checks. The exact standard-bond UI caller/target/arguments, row filtering/pagination and any display limits remain untraced. I will not replace that missing evidence with the assumption `redeem(connectedWallet)`.

[Real World Bonds docs](https://docs.netnet.capital/rwa-desk) explicitly place equity-desk notes in the same subscription ledger “alongside any standard bonds.” Therefore an individual ledger row or Claim button may concern a different target. No public NetNet-owned source repository was found in the scoped searches; absence from search is not proof none exists.

## 4. Different products are not alternate primary-note exits

- **GenesisBond:** separate official address `0x575b7B7c97Ef3E21C82DAeB427899d583e1E913f`. Local `src/GenesisBond.sol:55–56,186–209` uses per-account purchased/claimed totals and `claim()`—not BondDepository's note array. Its five-day founding schedule does not change standard notes.
- **InverseBond:** separate `0x92166e94Eea5B7799b761653881692f881dfc4c9`; `src/InverseBond.sol:68–89` immediately swaps/burns NET for USDG, not vesting-note redemption.
- **TURBO:** [official docs](https://docs.netnet.capital/turbo) describe separate ERC-1155 knock-out series and cash-out/expiry claims in stock/USDG, with no NET leg. Those selectors cannot recover standard depository notes.
- **RWA/asset desks:** related user-facing bond products, but the mixed UI and their error messages cannot be imported into the selected contract. Their complete deployed implementations were not audited here.

## 5. Ordinary holders versus this wrapper

**Inference:** ordinary standard-bond holders face the same address-indexed scan, but their histories are usually distributed across wallets and their claim transaction can end at receiving NET. No typical-size distribution or successful claim history was measured here.

A shared custody wrapper could concentrate many users' histories, while the selected atomic Keep-YT/mint/stake sequence consumes additional transaction budget. Per-position custodians reduce concentration, not third-party appendability. These are reasons to assess the wrapper carefully—not evidence ordinary NetNet users have suffered an outage.

**Corrections to prior overbreadth:** “all NetNet bonds” is too broad; “no deployment-related evidence” is now outdated for this specific depository because Sourcify evidence was obtained. No measured gas threshold, attacker cost, observed outage, exhaustive current-UI trace, or impossibility theorem is claimed. Individual display/read access is established; a specific-note primary redemption is not.

## Handoff and limits

Prioritize obtaining readable production UI claim-handler source or another permitted static extraction, then trace target/ABI/args per product. Preserve the exact-match verification record in NN-01 evidence, without calling all deployment checks complete. Keep NN-02 open for quantified feasibility and provenance work; neither the UI fragments nor public ABI supplies the missing selective primary claim.

All web accesses dated **2026-09-27**. Current CLAUDE, current PRD §12, canonical `crane-netnet`, Crane/local adversarial guidance read directly. Public `/bonds` docs guess also returned 404; no failed URL was retried. No ordinary local read failures. High confidence in depository ABI/source semantics; limited confidence on UI behavior beyond the quoted fragments. No operational approval implied.
