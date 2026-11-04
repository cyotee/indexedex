# Coordinator draft

## Draft identity

- Draft ID: se-remaining-functions-20261030-01a18660-r1
- Path: docs/research/se-remaining-functions-20261030-01a18660/coordinator/draft.md
- Run ID: se-remaining-functions-20261030-01a18660
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md

## Participation

- Council kind: full
- Requested members: Astra, Grok, MiniMax, Kimi
- Substantive initial responses: Astra st_01a192be, Grok st_01a192bf, MiniMax st_01a192c0, Kimi st_01a192c1
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking agent
- Coordinator is an independent vote: no

## Question

For each remaining open full-spread function, should this family keep it, drop it, or map it onto an accepted standard function?

## Proposed text

These are recommendations. They do not lock the PRD and do not authorize implementation.

All four originals agree that `previewExchangeIn`'s `amountRefunded` does not replace a per-currency credit split. `amountRefunded` is unkept input of the token the caller provided. It is not `credit0`, `credit1`, `uncredited0`, or `uncredited1`.

All four originals agree that `previewWithdrawalMode` is not kept as a selector. A caller does not choose compound-versus-collect. For a paired exit, the quote is `previewExchangeBundleOut`. For a single-token exit, the accepted quote is `previewExchangeIn`. Neither accepted preview returns the maintenance mode or its reason. Dropping the selector does not remove the internal maintenance choice.

All four originals agree that `wrappedNative()` is not kept as a family getter. The accepted bundle routes use the ERC-20 face already exposed by `vaultTokens()`, with the wrapped face at a native leg's index. `address(0)` stays rejected on those routes.

The two cap getters are not settled. See the disagreement table. Dropping a getter is not the same as dropping the cap. No original says the caps themselves are removed.

`previewZapCredit` is not settled. See the disagreement table.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| `previewZapCredit` | Astra, Kimi, and MiniMax: keep it as a read-only explanation of the same entry plan. It must agree with `previewExchangeIn` on quoted shares. It is not a second money route. Grok: map it onto `previewExchangeIn` and do not keep the selector, because the missing split is stage-one residual accounting this family has not locked, and a second quote can disagree. | Whether the diagnostic split is required before a residual policy exists. |
| `maxZapBps` and `maxZapTickMove` getters | Astra and Kimi: keep both getters so an integrator can read the configured caps without inferring them from a rejected quote. MiniMax and Grok: drop both getters. Keep both caps as configuration and enforcement. No accepted standard getter exists to map them onto. | Whether configuration that has no standard getter still needs a family getter. |
| Where the native face is named | Astra and Kimi: map `wrappedNative()` onto `vaultTokens()`, associated with the native leg through the retained PoolKey. MiniMax: drop the getter because `vaultTokens()` already exposes the face. Grok: drop it, and do not move it onto the Position Repo. | The getter is not kept. The wording is map versus drop. Grok's refusal to put it on the Position Repo is not answered by the other three. |

## Evidence gaps

- No original ran the functions. The zap residual behavior MiniMax describes is from the current PairToken implementation, not from a locked full-spread policy.
- The sleeve refill, shortfall, and locked-spend rules are still unspecified. They are not these functions.
- Raw ETH remains an owner decision from FS-OWN-09. None of these five functions restores it.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Refund versus credit split | Read | All four | No conflict on the distinction. Conflict on whether the split must stay public. |
| `previewWithdrawalMode` | Read | All four | Selector is not kept. Map versus drop is wording. |
| Cap getters | Read | All four | 2-2. Caps themselves are not dropped. |
| `wrappedNative` | Read | All four | Getter is not kept. Position Repo placement is open. |

## Limits

- Static reading only. No execution was run for this draft.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- The coordinator did not vote on the two open splits.
