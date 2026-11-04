# Advisory feedback

- Member: `kimi`
- Draft ID: `se-v4-unlock-sleeve-20261102-r1`
- Disposition: **support-with-reservations**

The draft's core answer is sound: an existing in-range position contributes to aggregate pool liquidity without a local sleeve, caller-based ownership controls which position a nested `modifyLiquidity` call changes, and resulting deltas must settle before the outer unlock returns.

## Corrections by draft section

### `Disagreement carried, not resolved by a vote`

Clarify the `afterSwap` timing statement. As written, “a change made in `afterSwap` is not” visible to “the swap that follows” can be read as saying that the change would not affect a later swap, while the next sentence explains the narrower and correct point: it cannot change the enclosing swap that has already computed. Use that narrower wording explicitly: a change in `beforeSwap` can affect the enclosing swap that follows it; a change in `afterSwap` cannot retroactively affect the enclosing swap that has already executed.

### `Answer`

Qualify the categorical requirement that “the hook call the vault.” The draft's `Agreement` section correctly states the general rule: the position owner must already receive execution in the existing callback chain and must call `modifyLiquidity` itself. A separate hook calling the vault is one way to satisfy that rule, but it is not the only possible arrangement; the position owner may itself be the hook. Restate the requirement in terms of the owner participating in the callback chain, then identify the separate-hook call to the vault as the integration path relevant to that arrangement.

### `Limits`

Remove or substantiate the statement that “Kimi's response omitted the template's later headings.” The draft does not identify the template or a required-heading rule, and a member-specific formatting assessment is not a limitation of the source analysis. This does not affect the technical conclusion, but it is unnecessary in the final report's limits.

## Status

This feedback supports the draft subject to the reservations above. It does not replace the draft and does not authorize implementation.
