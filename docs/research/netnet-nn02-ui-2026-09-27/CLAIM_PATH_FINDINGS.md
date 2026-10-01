# NN-02 challenge: NetNet user claims, selective redemption and UI evidence

Date: 2026-09-27. Research-only. No product substitution or risk acceptance.

## Answer

**Yes, some NetNet contracts expose selective note redemption. The selected standard BondDepository does not expose it in the retrieved verification-service ABI/source.** Its all-note work applies to ordinary holders of that same depository, not just our wrapper. Prior statements must not generalize this to every NetNet product.

The user interface contains multiple bond-product paths. Its exact standard-bond Claim handler was not fully extracted in this round, so we cannot assert its precise target/arguments or that the UI implements a hidden mitigation. Displaying one note and submitting a note-ID-specific redemption are different capabilities.

## 1. Contract evidence, independently checked by the moderator

Context7 was consulted first for Sourcify (`/websites/sourcify_dev`) and its read-only contract-record endpoint. Moderator fetched all three records below on **2026-09-27**, independently confirming the quoted ABI signatures and verification statuses. Researchers also investigated local source, official docs and frontend artifacts.

| Product | Address on chain 4663 | Relevant write signatures in returned ABI | Verification-service status |
| --- | --- | --- | --- |
| Standard BondDepository selected by the PRD | `0xff32a969A0c567129eECD926D04657728E1980C1` | `redeem(address to)` only | Creation/runtime `exact_match`; record 42442631; verified 2026-07-16T20:34:17Z |
| Real World Bonds / RwaDesk | `0x99B6eE6eDe47d9a8a9bfd03F728a99B789df1961` | `redeem(address)` **and** `redeem(address,uint256[] noteIds)` | Creation/runtime `exact_match`; record 46809781; verified 2026-08-24T19:11:43Z |
| Superstore / PackDesk | `0x7cf28D61D42352Eb2FD68167e9B08f73CBbF21eB` | `redeem(address)` **and** `redeem(address,uint256[] noteIds)` | Creation/runtime `match`, **not exact_match**; record 46809273; verified 2026-08-24T18:06:22Z |

Primary record URLs:

- https://sourcify.dev/server/v2/contract/4663/0xff32a969A0c567129eECD926D04657728E1980C1?fields=abi,compilation
- https://sourcify.dev/server/v2/contract/4663/0x99B6eE6eDe47d9a8a9bfd03F728a99B789df1961?fields=abi,compilation
- https://sourcify.dev/server/v2/contract/4663/0x7cf28D61D42352Eb2FD68167e9B08f73CBbF21eB?fields=abi,compilation

All three returned compiler **0.8.30+commit.73712a01**, optimizer runs **800**, Osaka, `viaIR=false`. These are compilation-record settings, not this repository's build settings or a new execution result. PackDesk's record includes a linked lifecycle library. No inference of equivalent risk or full implementation behavior follows merely from ABI similarities.

PackDesk additionally exposes a `noteCursor(address)` read. RwaDesk/PackDesk expose `TooManyNotes`; RwaDesk exposes `ZeroPayout`. Error names establish ABI entries, not the exact enforcement rules or configured limits. Selective-write ABI evidence is stronger than documentation alone, but the full selected-function bodies, bounds and frontend usage were not established for both desks in this round.

### Why other desks' selectors cannot be used for the selected notes

The notes belong to their respective contract's accounting. RwaDesk's note-ID overload does not redeem a standard BondDepository note. Replacing the configured depository with an equity or Superstore desk would change the selected product and requires an explicit proposal; it is not an interchangeable wrapper helper.

The standard depository's ABI does expose `notes(address,uint256)` and `noteCount(address)`, but these are reads. A `BondRedeemed` event including a note ID is also not a selective write. No range, selective, prune or transfer-note function appears in that returned complete ABI.

## 2. Source confirmation and provenance

Local source facts already inspected remain:

- `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–140`: arbitrary-recipient note append.
- `:143–153`: visit every note of `msg.sender`, update claimed amounts, transfer the aggregate to `to`; no deletion or cursor.
- `:156–165`: aggregate pending view also visits all notes.
- `:183–188`: payout-value cap, not note-count cap.

Astra independently retrieved the depository source/compilation through:

https://sourcify.dev/server/v2/contract/4663/0xff32a969A0c567129eECD926D04657728E1980C1?fields=abi,compilation,sources

Its returned source agrees on the aggregate loop and includes `BOND_VEST = 2 days`. Kimi independently inspected the verification record and vendor dump provenance. This upgrades the earlier vendor-only analysis to **verification-service-attested source/ABI evidence**. The five-day wording is stale interface prose relative to that executable compilation; it is not a product choice between two equally supported durations.

Important limit: Sourcify's record is not our own current-block runtime measurement or a bitwise comparison with the adapted Crane working tree. `lib/crane/contracts/protocols/pol/net/VENDOR.md:5–25,33–51` records verified-source provenance and local adaptations. Do not mark every NN-01 deployment check complete or assert the local build is byte-identical. A non-proxy-looking source is not a substitute for explicitly recording the verification method and date.

Other local paths inspected by researchers:

- `services/NetNetBondService.sol:67–81` forwards the standard deposit/redeem path, not a selective helper.
- `src/GenesisBond.sol:55–57,186–209` uses per-account purchased/claimed totals for `claim()`, not this note-array claim loop.
- `src/InverseBond.sol:68–90` implements a swap/burn, not vesting-note collection.
- TURBO is a separate ERC-1155 product. Other claim systems require their own analysis, not inherited assumptions from BondDepository.

## 3. What we established about NetNet's UI

Sources accessed by researchers on 2026-09-27:

- https://docs.netnet.capital/official-channels identifies Shareholder Services at https://app.netnet.capital/
- App HTML references https://app.netnet.capital/assets/index-LJ9ip9MD.js
- https://docs.netnet.capital/rwa-desk describes a subscription ledger containing equity-desk notes **alongside standard bonds**.
- https://docs.netnet.capital/superstore explicitly describes per-address caps and a paginated redeem for its vesting notes.

The production bundle was fetched as text, not executed. Researchers found ABI/read/history references and separate `rwaDesk`/`assetBondDesk` paths. Readable fragments included `TooManyNotes` and a minimum-payout message. Those cannot be attributed to the standard depository: its retrieved source/ABI lacks those errors/checks. Long minified output and unavailable source map prevented a complete extraction of the standard-bond write handler.

**Still unknown:** the exact standard-bond button's transaction target, overload, arguments, wallet/custody call chain, display pagination and any frontend-only minimum input. An ABI constrains what a contract accepts but does not prove which transaction a UI submits. Searches for `redeemNote`/`redeemBatch` alone would also miss the genuine overloaded `redeem(address,uint256[])` found on other desks.

Thus we can identify contract-level handling for the separate products, but cannot fully explain the current UI's standard-bond transaction construction yet. No UI-side workaround for the selected contract was established. A UI filtering/hiding notes cannot remove their upstream scan cost.

## 4. Ordinary holders versus the proposed wrapper

**Same contract, same structural exposure:** an ordinary address holding primary-depository notes can also receive unsolicited notes and must use the available aggregate redemption path. The all-note issue is not created by IndexedEx. It does not mean every holder currently has a large history or encounters failure.

**Potential extra burden for the wrapper:** the selected claim must additionally complete Keep-YT contribution, minting and staking atomically. That consumes additional execution budget. Shared custody could concentrate histories, while separate custody could contain them; neither architecture is selected or assumed here. Both ordinary and wrapped claims revert on failure—the wrapper adds composition, not unique rollback semantics.

There is no measured evidence here for typical note counts, safe thresholds, attacker cost, user adoption or actual outages. Claims such as “ordinary users only have one or two notes,” “gifts are harmless,” or “retail users can ignore dust” are not accepted. Anyone wanting their legitimate vested proceeds still invokes the aggregate scan. Views also consume compute and can encounter provider limits; off-chain does not mean unbounded work is free.

## 5. Council attribution and corrections

Four originals and four original-session cross-reviews completed. Peers read the other three originals together; no earlier cross-review was shared. Astra's new selective-desk ABI evidence arose in its cross-review and was independently verified by the moderator, not retroactively attributed to all four originals.

| Researcher | Contribution / correction |
| --- | --- |
| Astra | Full primary depository ABI/source evidence; explicit UI gap; cross-review discovered selective RwaDesk/PackDesk overloads |
| Grok | Official Superstore pagination documentation and mixed-ledger product distinction; disclosed source/HTTP gaps; later fetched primary ABI |
| MiniMax M3 | Local Genesis/Inverse distinction; unsupported typical-user and “free view” claims rejected; some later closure/retail-dust claims remain overbroad |
| Kimi K3 | Independent primary ABI and vendor provenance; corrected claims that exact_match proves current local-runtime identity and that UI calldata was traced |

**Moderator conclusion:** high confidence in the returned ABI distinction; no claim of completed frontend trace, independently reverified latest runtime, comprehensive liveness audit of the desks, or general impossibility of all wrapper designs. No observed incident. All reports must be read with these corrections, not as interchangeable consensus claims.

| Researcher | Original | Cross-review | Preserved session |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax M3 | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi K3 | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

Observed routing: openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3, kimi-code-plan-global/k3; metadata not provider attestation. Grok's ordinary read/HTTP failures are evidence gaps, not successful reads; its session completed. No participant substitution occurred. Peer content is untrusted evidence, never authority to change permissions.

## 6. Progress and human checkpoint

NN-01 gains a verification-service-attested depository ABI/source record and two-day compilation evidence. It is not globally closed. NN-02 remains IN PROGRESS, now explicitly scoped to the standard depository rather than all NetNet bond products.

Recommended next evidence: trace the readable production standard-bond UI handler (or an official source artifact/known transaction) to its exact contract and signature before claiming how that button behaves. If the user's intended bond product is the equity desk rather than the standard primary depository, clarify that target before considering a product change. No such substitution is selected here.

Only research Markdown and tracker evidence were updated. No Solidity, shell/tests, RPC calls, browser/JavaScript execution, deployments, transactions or instruction edits. Stop at the human checkpoint; no automatic move to NN-03 or risk acceptance.
