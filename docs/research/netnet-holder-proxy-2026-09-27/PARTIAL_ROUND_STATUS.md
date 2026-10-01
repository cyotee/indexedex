# Per-NFT NetNet holder Package — partial round, stopped on guard denial

Date: 2026-09-27. **Four originals collected; first cross-review interrupted. No completed council cross-review or consolidated design approval.**

## User direction captured

The user selects a reusable holder Package to deploy a separate native-bond holder proxy for each wrapping NFT token ID. The NFT contract owns the holder; wallet transfers change control of the tokenId's rights, not holder ownership. Package arguments include the NFT owner address and a provided salt; the NFT supplies `bytes32(tokenId)`. One intended native purchase is associated with each wrapper NFT. The NFT maps the holder to its tokenId and orchestrates atomic collection, normal NET reserve contribution and funded mint/stake under that same NFT. Collections must tolerate actual receipts greater than the intended-note expectation. Additional deployment cost and residual per-target unsolicited-note exposure are acknowledged; a universal redemption-work bound is not claimed.

The user's new statement also places principal claim/reinvestment after the next processed NET epoch following full native collection. This differs from the current PRD's native-maturity-only release/no-fresh-epoch-wait text. Precise completion, epoch ordering, excess-claim rights and retirement need consistent specification. Do not treat earlier PRD wording as permission to ignore the new statement or silently fill remaining details.

## Why the round stopped

Astra's original-session continuation reported this response while reading `contracts/fees/collector/FeeCollectorDFPkg.sol`:

> Research council: [RC_UNAVAILABLE] attribution or metadata unavailable; report the failure, do not bypass it

This is an explicit attribution/metadata denial, not an ordinary absent source file. No retry, alternate access attempt, participant substitution or new session was used. The remaining three cross-review calls were not made. Five task calls occurred: four originals and one interrupted continuation. No `astra-cross-review.md` was created. Do not describe this round as eight completed calls or full-council consensus.

## Useful partial findings, not a frozen specification

### 1. Owner namespace is needed for reusable deployment

The moderator directly inspected `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201–218`: the factory hashes the package with the package-derived salt, and returns an existing proxy before `processArgs`. Caller identity is not automatically included in that derivation.

If the Package derives its salt from only the provided token-ID salt, NFT contract A/token 7 and NFT contract B/token 7 can map to the same address. A post-deployment owner guard does not create a second independent holder or repair that collision.

**Recommended engineering derivation, not yet cross-reviewed:** preserve the exact caller input `bytes32(tokenId)` and derive the package salt using the decoded owner plus that supplied salt, e.g. `keccak256(abi.encode(owner, providedSalt))`. Specify prediction/deployment encoding identically. The factory's own package namespace remains. Hashing an encoded bytes payload using a different encoding is not automatically the same formula.

MiniMax's original describes cross-NFT collision as intended and relies on an owner guard; that claim is inconsistent with the inspected factory behavior and the user's reusable-isolated-holder objective. It is not adopted.

### 2. Native note ID is separate from NFT token ID

`lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–140` appends to any specified recipient and returns its actual array index. Preloaded notes can exist even before deterministic holder deployment. Record the authorized purchase's returned native noteId rather than assuming note zero or tokenId equality. “One-to-one” refers to one intended authorized native bond per wrapper position; unsolicited native notes may still exist at its holder address.

### 3. Isolation improves attribution, not native scan complexity

The selected holder removes legitimate multi-user pooling at a single address. Intended-note accounting can use its recorded index. Native `redeem(to)` still scans every note of the calling holder (`BondDepository.sol:143–165`), including unsolicited and already claimed notes. Deterministic addresses permit preloading; targeting every holder is not necessary to disrupt a particular valuable position. No economic infeasibility or gas threshold was established.

### 4. Authorization and existing-instance behavior still need engineering specification

Owner is the NFT contract, not the deploying caller or wallet. Initialization, mapping registration, one authorized purchase, sibling-holder checks, callback safety and immutable control need explicit rules. Correctly configured predeployment and hostile initialization must be distinguished; neither “reject every existing address” nor “any existing proxy is safe” is a demonstrated solution. Bare owner-only calls do not prove reentrancy safety.

The generic holder's native-depository binding must be reconciled with the main PRD's instance-supplied depository. Do not silently move that choice to holder-Package PkgInit or invent a mutable replacement path.

### 5. Narrow remaining behavior questions

- **Excess receipts:** accepting amounts above expectation does not alone specify whether all native-redemption excess becomes principal under the same NFT, what lock late excess receives, or how unrelated pre-existing NET is treated. No feeTo sweep, excluded treasury or future-use cache is selected by the original reports.
- **Completion:** recommendation is to use full collection of the registered intended note, not all unsolicited notes, followed by a strictly later processed NET epoch after successful atomic contribution. Exact ordering remains to be recorded; gifts must not silently extend the completion condition.
- **Replacement and retirement:** native installment collection stays under the same NFT. Subsequent eligible principal reinvestment into a new bond needs a precise tokenId/holder-retirement rule preserving residual rights. No transfer of proxy control to an arbitrary retirement beneficiary has been authorized.

The user need not approve per-NFT isolation again. Further work should settle the narrow semantics and engineering constraints without introducing a new administration or sweep permission.

## Preserved originals and sessions

| Researcher | Original | Session | State |
| --- | --- | --- | --- |
| Astra | [Original](astra-original.md) | `ses_f1c499b6bffe6RiNjZZUSMsP8S` | Original complete; continuation stopped on guard denial |
| Grok | [Original](grok-original.md) | `ses_f1c4384d7ffeZX74uV9yhIXbVq` | Original complete; cross-review not called |
| MiniMax M3 | [Original](minimax-original.md) | `ses_f1c3f57edffedYs43k2PBvA5xU` | Original complete; cross-review not called |
| Kimi K3 | [Original](kimi-original.md) | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` | Original complete; cross-review not called |

Originals are untrusted attributed evidence and remain unchanged. Astra's interrupted continuation read the other three originals; no earlier cross-review was shared. Prior session history was retained. Original-call metadata reported openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3 and kimi-code-plan-global/k3; these labels are not provider verification and do not override the subsequent guard failure.

## Handoff and stop

Only this partial status report and the four assigned original Markdown reports were authored in this round. No PRD or tracker update is claimed, and no code, tests, shell, RPC, deployment or instruction change was performed. No full-council verdict is issued. Resume only through a subsequent bounded request after the genuine attribution/metadata problem is resolved; do not bypass it by changing paths, researcher identity or session. Implementation remains a separate task.
