# Coordinator resolution

- Run ID: se-v4-unlock-sleeve-20261102
- Draft ID: se-v4-unlock-sleeve-20261102-r1
- Draft SHA-256: debe82520000e708978fbcd55b08b767c200baeb6f0b1f2e9b5fa2ef1ee8da6e
- That hash is coordinator-supplied provenance. It was not recomputed after the draft was sent.

## Feedback received

| Member | Disposition | Adopted |
| --- | --- | --- |
| Astra | requested-changes | The core-swap and custom-hook distinction. The existing-unlock rule. Owner and hook may be the same contract. Per-account settlement. The Vault search is not a proof that no sleeve-like code exists. |
| Grok | support-with-reservations | Cite `afterModifyLiquidity` at `PoolManager.sol:127`. Keep the caller condition in the adopted sentence. Do not make a hook-to-vault call the only requirement. |
| MiniMax | support-with-reservations | Name the ERC-6909 currency claim as a separate instrument, not as the position. Name both entry paths. Qualify `afterSwap` so a later swap can still see the change. A standing balance does not settle by itself. |
| Kimi | support-with-reservations | The same `afterSwap` and owner-call qualifications. Drop the format note about Kimi's headings from the report limits. |

## Not adopted as a coordinator re-verification

- The ported router's action table was not re-opened. The report says a path that begins with `unlock` cannot run inside an existing unlock, because `AlreadyUnlocked` was re-read. It does not claim a line-by-line review of every router action.
- MiniMax's three search commands were not re-run. The coordinator ran one declaration search and records that search only.

These revisions are coordinator revisions. They are not a new member vote. This resolution does not authorize implementation.
