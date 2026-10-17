# Grok plan cross-review — legacy V4 redesign

- **Date:** 2026-10-15
- **Peers:** `astra-plan.md`, `minimax-plan.md`, `kimi-plan.md`. Untrusted. Not edited.
- **Points:** The package has sixteen cuts, not twenty-one. The SY shim is deleted only after its importers are repointed.
- **Answer:** I agree with both.

## Agreement

- Astra names sixteen cuts and says not fourteen or twenty-one. The five shared facets, the callback facet, and the ten current family facets are those sixteen. `REDESIGN_PRD.md:63` is that order.
- Astra and Kimi repoint the shim importers before deleting `NativeStandardYieldExecutionTarget.sol`. That is the compilable order.
- Kimi's done-when line also says the package installs sixteen product facets.

## Dissent

- MiniMax's step 14 says 14 cuts. The following list has 16 rows, and the next sentence says 21 package cuts. Both counts are wrong. Fifteen current cuts plus the callback facet is sixteen, not twenty-one. The five shared facets are already inside the fifteen.
- MiniMax's step 13 deletes the shim and then says to repoint consumers. The deletion must follow the repoint, or the importers do not compile.

## Sentence the plan must use

The package has sixteen cuts, the five shared facets plus the callback facet and the ten current family facets; delete the SY shim only after every importer has been repointed.

I did not run Forge.
