# Astra advisory feedback

## Identity

- Assigned member: Astra.
- Requested model/account route: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model/account route and reasoning setting: not exposed.
- This is one advisory pass, not a new original contribution or an independent coordinator vote.

## Draft under review

- Draft ID: `se-remaining-functions-20261030-01a18660-r1`.
- Path: `docs/research/se-remaining-functions-20261030-01a18660/coordinator/draft.md`.
- Expected SHA-256: `694cdf6054d69b261f498825808e9a8c2f6dd1108b2a9ec0d732a3aa17520e15`.
- Observed raw-file SHA-256, computed with `shasum -a 256`: `694cdf6054d69b261f498825808e9a8c2f6dd1108b2a9ec0d732a3aa17520e15`.
- Verification: matched before reading. The complete draft was readable and reviewed.

## Disposition

**Support with corrections.** The draft accurately represents my five function decisions and preserves the substantive splits rather than deciding them by vote. It misstates my position on moving `wrappedNative()` to the Position Repo.

My original recommendations remain:

| Function | Original recommendation | Draft accuracy |
| --- | --- | --- |
| `previewZapCredit` | Keep the diagnostic query for shares and per-currency credit/residual information. | Accurate. The refund return does not replace that split, and the query must explain the same entry plan. |
| `previewWithdrawalMode` | Map payout quoting to `previewExchangeBundleOut` for paired exits and `previewExchangeIn` for existing scalar exits; remove the mode selector. | Accurate. The draft expressly acknowledges loss of mode/reason returns and preservation of the internal maintenance choice. |
| `maxZapBps` | Keep the getter. | Accurate. Getter removal and cap removal remain separate decisions. |
| `maxZapTickMove` | Keep the getter. | Accurate. The disagreement is about public configuration discovery, not removal of enforcement. |
| `wrappedNative` | Map discovery to `vaultTokens()` with the retained PoolKey association; remove the standalone getter and do not move that public selector to the Position Repo merely to preserve it. | Partly accurate. The map recommendation is recorded, but the express Position Repo recommendation is omitted and then described as unanswered. |

## Concerns and corrections by draft section

### Preserved disagreements: "Where the native face is named"

The sentence "Grok's refusal to put it on the Position Repo is not answered by the other three" is incorrect as a statement about my original.

My original, Conclusions, "5. `wrappedNative`: map", expressly says:

> Recommend that the standalone getter is unnecessary on this family; do **not** move an otherwise redundant public `wrappedNative()` selector to the Position Repo merely to preserve it.

**Correction:** retain the recorded map-versus-drop descriptions, but add to the Positions cell:

> Astra also expressly recommends against moving the redundant public selector to the Position Repo; that recommendation does not decide where the internal wrapper binding is stored.

Replace the sentence claiming the other three did not answer Grok with:

> Astra and Grok both recommend against moving the standalone public getter to the Position Repo. Astra leaves internal wrapper-binding storage undecided. Map versus drop describes the public-discovery recommendation, not a requirement to add another getter.

This corrects the attribution of my original. It does not count agreement as authority, infer the unexamined members' positions, or settle either the zap-query or cap-getter split.

### Coverage adopted from responses: `wrappedNative` row

"Position Repo placement is open" conflates the public getter with internal storage and omits my explicit recommendation.

**Correction:** replace that row's Conflict or gap cell with:

> Getter is not kept. Astra and Grok expressly oppose relocating the redundant public selector to the Position Repo. Internal wrapper-binding storage is not decided by Astra's recommendation.

The coordinator should not turn this attribution correction into a claim of council unanimity about storage or selector placement. My feedback verifies only what my original said; the draft's accounts of the other originals are not independently checked here.

## Preserved splits

Keep the `previewZapCredit` and cap-getter disagreements open. My preference to retain those queries does not override the counterarguments recorded in the draft, and a participant count cannot establish the correct interface.

For `previewZapCredit`, retaining the diagnostic does not import the baseline's no-refund residual policy as new-family law. For the cap getters, retaining or dropping their selectors does not change the caps' scope or enforcement. The draft preserves both distinctions sufficiently for this advisory pass.

## Limits

Only the frozen draft and my original already present in this conversation informed this comparison. No peer originals or feedback were read, no underlying sources were reopened, and no new external research was performed. The claims about other members remain the coordinator's attributions, not findings independently verified by Astra.

Only this assigned feedback file is written. The original response, frozen draft, PRD, function-review file, project code, and configuration are unchanged. No tests, builds, installs, Git operations, deployment, or delegation were performed.

This advisory neither replaces my original nor the frozen draft, does not lock a product decision, and authorizes no implementation. It requests no further advisory round.
