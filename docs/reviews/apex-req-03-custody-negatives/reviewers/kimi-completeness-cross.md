# Kimi K3 — completeness cross-review: REQ-03 custody-negatives PRD

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. My completeness original is `kimi-completeness.md` in this directory. The three peer completeness notes were read in full as untrusted model output. The PRD under review (`../REMEDIATION_PRD.md`, current 87-line revision with the 2026-10-14 owner rulings) controls. No code or PRD edited.
- **Date:** 2026-10-14.

## Assigned question: is any choice still open?

**Agree with Astra, Grok, and MiniMax: no.** The PRD leaves no owner-level decision for the implementer. This matches my own completeness original. On the two sub-questions named for this cross-review:

### 1. How the observation callback stores the nested result — not an open owner decision

The PRD's acceptance criterion (`REMEDIATION_PRD.md:33`) fixes the functional contract completely: "the callback records that the nested deposit was attempted and rejected with `IReentrancyLock.IsLocked`, then returns without reverting. The outer deposit finishes. The test reads that record after the call." The current callback already obtains `(ok, reason)` via a low-level call (`RebasingAwareERC4626_Adversarial.t.sol:29`); the only change is persisting that pair instead of asserting and re-bubbling. Whether the record lives in test-contract storage or an equivalent channel, and the identifiers involved, are routine coding choices that cannot violate the criteria — the outer transaction commits, so any ordinary record survives. I agree with Astra ("routine coding details") and MiniMax ("a design choice within the closed acceptance criteria"), and my original's classification stands. No sentence needed.

### 2. Whether the scanner adds the listed directories to the existing `roots` tuple — not an open owner decision

The acceptance criterion is behavioral (`:73`): "The scanner selects every directory in that list, recursively, with or without an APEX marker." Extending `roots`, adding a parallel tuple, or any other carrier that satisfies the behavioral criterion is compliant; the owner ruling (`:54`) forecloses only the family-selection decision, which is what mattered. I agree with Grok and MiniMax; my original's "carrier" note was the same observation. No sentence needed.

## Verification against the current tree this round

- MiniMax's claim that both Balancer spellings in the directory list exist is confirmed by my own reads: `test/foundry/spec/protocol/dexes/balancer/v3/` (routers, `TestBase_StandardExchangeRouter.sol`, `WrappedStandardExchangeRateProvider.t.sol`) and `test/foundry/spec/protocols/dexes/balancer/v3/` (`pools/`) are distinct directories with distinct content. The singular/plural pair in the PRD (`:69-70`) is deliberate. My original's verification note is closed; nothing for the implementer to decide, and `:77` already forbids dropping or substituting an entry if a path were absent.
- Astra's point about the post-expansion scanner state is correct and already closed by the PRD: the expanded scanner will legitimately report the known bare expectations (e.g., `ERC4626StandardExchange_Routes.t.sol:332,335,383,409,559`; `RebasingAwareERC4626_Accounting.t.sol:131,143`), and `:76` ("It does not rewrite those tests in this item") plus the `:77` non-goal establish that a nonzero `--check` result from correctly selected files is the expected landing state, not a license to weaken selection or broaden the item. If the coordinator wants that expectation spelled out, one optional sentence — "A nonzero `--check` exit caused by existing bare expectations in newly selected directories is the expected end state of this item; those rewrites are a later item" — would make it explicit, but I do not score its absence as an open decision, because the current text already determines the behavior.

## Unresolved dissent

None. All four passes converge: the PRD as revised leaves no implementer decision. Consensus is not proof, but the two sub-questions named for this cross-review were re-checked against current code rather than taken on agreement.

I did not run Forge.
