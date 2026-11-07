# Hook failure diagnosis

## Question

What shared paths caused the listed Foundry failures, and what restores them without changing the live 49% fraction or making `asset()` a general bind requirement?

## Participation

Full council, invoking-agent coordination. All four initial responses settled:

- astra, `st_01a1ad25`, `chatgpt-subscription/gpt-6-astra:high`
- grok, `st_01a1ad26`, `xai/grok-4.7:xhigh`
- minimax, `st_01a1ad27`, `minimax/MiniMax-M3`
- kimi, `st_01a1ad28`, `kimi-coding/k3.1-pro:high`

No advisory feedback round was run. The user required the failures fixed in this session, so this report records the settled diagnoses and the fix that was then applied. It is not a member-approved revision.

## Agreed cause

`pairInVaultTokens` accepted only `vaultTokens()` membership and called that function without catching a missing selector. A rebasing wrapper lists its underlying, not its own share, so an identity wrapper leg was rejected as `TokenNotInVaultTokens` or `InvalidSE`. A bare vault or ordinary token with no `vaultTokens()` bubbled an empty revert before the package could emit its named error.

The full-spread row failures were stale expectations after that bind began succeeding, plus index rows that did not place the sibling face on the requested side of the primary face. The live 49% fraction was not changed. A 49% mint leaves a partial input remainder, not dust below 1%.

## Fix applied

- Admit recognized wrapper-share inventory, and treat a missing or reverting `vaultTokens()` as non-membership, in `UniswapV4SeBufferHookLegLib.pairInVaultTokens`. `asset()` is consulted only for the `pair == se` wrapper case.
- Point the single SE package at that helper.
- Mine the sibling lower face onto the requested side of the primary face.
- Assert unchanged sibling supply and zero conversion calls only when the bind was actually rejected.
- Expect the package's named bind error for a bare yield stub.
- Swap the sibling face, which has a product pool, not the share address.

## Result

The previously failing suites were rerun with Solar. The last three `PoolNotInitialized` rows then passed after the share-address swaps were pointed at the sibling face. The 49% sizer was not edited.
