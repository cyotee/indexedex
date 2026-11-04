# Brief

## Identity

- Run ID: se-fullspread-implementor-gaps-20261031-01a18660
- Profile: research
- Council kind: full
- Requested members: Astra, Grok, MiniMax, Kimi
- Coordinator mode: invoking agent
- Output root: docs/research/se-fullspread-implementor-gaps-20261031-01a18660/
- Authorization: the owner asked whether the council has questions to clarify the requirements or recommendations to improve quality. The owner said decisions are not left to the implementor. This brief does not authorize a PRD edit or contract implementation.

## Question

Which sentences in the updated full-spread PRD still force an implementor to choose a product behavior, and what exact owner question or closing recommendation removes that choice?

## Rule

A gap is a sentence where two competent implementors could ship different money, storage, selector, or route behavior and both claim the PRD. Naming, file layout, and a later hook-record procedure are not gaps unless they change that behavior.

Do not invent a product decision. If an existing owner lock or a cited `WeirVaults.sol` function already settles the sentence, the recommendation is the exact PRD sentence that says so. If it does not, the item is a question for the owner. A recommendation that adds a cap, a fee, a holder address, a new return field, or a new selector is forbidden.

## Minimum inventory

Read the current PRD and confirm, correct, or reject each item. Add every other gap you find.

- Genesis floor representation beyond the cited `_deposit` supply rule.
- A positive credit in the unselected currency on a one-token route, given `(amountOut, amountRefunded)` and no new return field.
- Sleeve refill, shortfall, and whether a locked caller may spend the sleeve. FS-OWN-04.
- Whether `poolManager` stays a `PkgInit` field, and how that address is written into the aware repo. FS-OWN-01.
- Where the `wrappedNative` package binding is stored. FS-OWN-10.
- Raw ETH entry and exit. FS-OWN-09.
- `queryFacet` still under function review.
- FS-OWN-07's table sentence that other reserve semantics are not specified.
- A later rate policy. FS-OWN-03.
- Pro-rata idle on the accepted one-token exit, which cannot install `zapTo`.

## Targets

Read these. Do not edit them.

- contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md
- contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md
- contracts/protocols/strategy/weir/WeirVaults.sol, only where a cited function would close a gap

## Member boundaries

Write only `members/<member>/response.md`. Do not edit the PRD, the review file, or this brief. Do not read peer responses. Do not delegate. Do not run Forge, Git, installs, or deployments.

Response headings: Identity, Question and targets, Evidence, Gaps, Questions for the owner, Recommendations that close a gap, Limits.

Every gap names the PRD section, quotes the deferring sentence, and says why an implementor would have to choose. A question is one specific question. A closing recommendation is exact replacement prose and the lock or source line that authorizes it.
