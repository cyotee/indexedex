# Astra advisory feedback

## Identity

- Run ID: `se-v4-unlock-sleeve-20261102`
- Member: astra
- Profile: research
- Phase: advisory pass, continued Astra conversation
- Requested role: council-member
- Requested model and reasoning: `chatgpt-subscription/gpt-6-astra:high`
- Actual runtime role, model, reasoning, task ID, and session ID: not exposed
- Peer feedback read: no
- Peer original responses read: no

## Draft under review

- Path: `docs/research/se-v4-unlock-sleeve-20261102/coordinator/draft.md`
- Draft ID: `se-v4-unlock-sleeve-20261102-r1`
- Coordinator-supplied SHA-256: `debe82520000e708978fbcd55b08b767c200baeb6f0b1f2e9b5fa2ef1ee8da6e`
- The exact named file was opened and read completely. The hash is recorded as supplied provenance; it was not recomputed or independently verified.

## Disposition

**requested-changes**

I support the central conclusion: a sleeve is not a core V4 prerequisite for using existing in-range liquidity or for an owner to modify its position at a hook boundary within an existing unlock. The draft needs narrower wording about custom hooks and explicit preservation of the existing-unlock and per-account settlement conditions. These are corrections to the answer's scope, not a recommendation to restore a sleeve.

The source references below are retained from this conversation's initial source examination. Only the draft was read during this advisory pass.

## Concerns and section-specific corrections

### 1. Agreement and Answer: distinguish the core swap from custom hook execution

The sentence "A custom hook on that pool trades against that same aggregate" is too broad. The first Answer paragraph similarly assumes that the intended custom hook's swap necessarily uses the underlying pool's ordinary liquidity.

The core swap uses aggregate active liquidity. A permitted custom hook can instead adjust the amount sent to that core swap, including to zero, and contribute custom-accounting deltas. The draft should not collapse those two mechanisms. This distinction was present in my initial response, supported by `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:249-282`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:286-318`, and `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:315-325`.

Recommended replacement for the end of the first Agreement paragraph and the first Answer paragraph:

> For any portion executed by the pool's core swap, the position contributes to aggregate liquidity while in range; no preliminary withdrawal to a local sleeve is required. This does not establish that every custom hook executes against that aggregate. A hook can alter the amount passed to the core swap and account for a contribution through hook deltas. Whether the intended hook uses this position directly or sources its underlying currencies through its owner remains an integration question.

Retain the draft's aggregate-liquidity citations and add the hook-delta citations above. This preserves the no-sleeve conclusion without claiming a specific hook architecture.

### 2. Answer: require reuse of the existing unlock, and avoid assuming distinct owner and hook contracts

The second Answer paragraph says the vault must call `modifyLiquidity` before unlock returns, but it does not explicitly exclude a vault entry that first calls `unlock` again. That distinction is essential: the answer should not imply that calling an ordinary redemption entry is sufficient if it unconditionally opens another unlock.

The required hook-to-vault call also assumes two different addresses. If the hook itself owns the core position, it can make the manager call directly. The core rule is the identity of the immediate caller, not a mandatory extra contract hop. Sources retained from the initial examination: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55-64`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:108-116`, and `lib/crane/contracts/protocols/dexes/uniswap/v4/base/BaseActionsRouter.sol:26-47`.

Recommended replacement for the second Answer paragraph:

> A sleeve is not required by V4 for the position owner to modify its position during a hook callback. The owner must call `modifyLiquidity` within the existing unlocked interval, without attempting another `unlock`. If the hook and owner are distinct contracts, the hook needs an authorized owner entry that supports that execution path; if the hook itself owns the position, it can call the manager directly. The participating accounts' currency deltas must all be resolved before the original unlock callback returns. Holding the vault's share does not itself grant core position ownership.

Keep the subsequent statement that this particular integration was not examined.

### 3. Agreement: qualify settlement by account and distinguish updated position state from booked credit

"Any delta created in that window must be cleared" is directionally correct but loses two material conditions from the initial evidence:

- A vault's credit does not automatically cancel a different hook's debt.
- An after-modification callback observes the modified position, but the outer modification's caller/hook currency deltas are booked only after that callback returns.

These conditions affect the precise question of accessing liquidity while a modification is already executing. Sources retained from the initial examination: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/CurrencyDelta.sol:10-40`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:123-132`, and `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:316-332`.

Recommended replacement for the final Agreement paragraph:

> Every participating account's delta in each currency must be resolved before the original unlock callback returns; credits and debts of different addresses do not automatically net. In an after-modification hook, the position has already changed, but the outer call's currency deltas have not yet been booked. Access to updated position state therefore does not imply an already-recorded withdrawal credit. These are accounting and sequencing conditions, not a requirement for standing local inventory.

Use "resolved" rather than "cleared" here to avoid confusing general settlement with the separate `clear` operation.

### 4. Disagreement carried, not resolved by a vote: remove the unsupported sleeve-search conclusion

"No member found a sleeve in the admitted tree" is broader than the required search for a contract named `Vault`. My initial response reported that exact declaration search, not a comprehensive inventory proving the absence of sleeve-like implementations.

Recommended replacement:

> The reported searches found no contract declaration named exactly `Vault` in the admitted V4 tree. That search does not establish the absence of every differently named local-inventory or sleeve implementation.

In **What the sources show**, make the same bounded wording explicit and retain the search provenance, rather than treating the absence of the exact contract name as evidence about every architecture in the tree.

## What was not adopted from others

I did not read other members' originals or feedback. Their positions are available to me only through the coordinator's characterization in this draft; I cannot independently confirm those attributions.

I do not adopt a funding condition as proof of a universal sleeve requirement, nor the draft's implication that every custom hook necessarily trades against the core aggregate. I support the draft's distinction between hook-boundary access and an interruption inside the pool mathematics. None of these positions requires choosing an implementation.

## Limits

- Only the exact coordinator draft was read in this pass. No sources, original responses, PRD, blockers file, or peer feedback were reopened.
- No hash computation, runtime execution, tests, Forge, installs, Git, network research, or sub-agent delegation was performed.
- Corrections use the draft and source observations already present in this Astra conversation. They are not a fresh verification of the live source tree.
- Only `members/astra/feedback.md` was written; `response.md` is preserved.
- This feedback does not replace the draft and does not authorize implementation. It does not request another advisory round.
