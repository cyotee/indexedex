# Coordinator draft

## Draft identity

- Draft ID: draft-v3-fullspread-v4-se-parity-20261117-r1
- Path: `docs/research/v3-fullspread-v4-se-parity-20261117/coordinator/draft.md`
- Run ID: v3-fullspread-v4-se-parity-20261117
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: the four settled initial responses and the locators named below, re-read by the coordinator after those responses settled

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

Astra, grok, and kimi used `upperLowerWings` as the V4 SE vault. MiniMax used the on-disk V4 full-spread vault. That split is preserved below. It is not consensus, and it is not a vote count treated as proof.

## Question

Does `docs/research/v3-fullspread-v4-accounting-plan-20261116/UNISWAP_V3_FULL_SPREAD_V4_ACCOUNTING_IMPLEMENTATION_PLAN.md` accurately define how to refactor the Uniswap V3 Full Spread vault so that it behaves like the Uniswap V4 SE vault? If, and only if, that plan is an accurate definition of that refactor, was the Uniswap V3 Full Spread vault actually refactored so that it behaves like the Uniswap V4 SE vault?

## Proposed text

The confirmation the question asks for is not available. Q1 is not an unqualified yes under either comparator a member actually used. Q2 is therefore not confirmed. A separate observation, which is not that confirmation, is that the current V3 sources follow the plan's V4 full-spread accounting and do not follow upper/lower wings behavior.

The plan does not ask this question. Its own question, at plan lines 4-5, is what ordered plan a later author must follow so the V3 vault satisfies the locked PRD. Line 8 says the plan does not replace that PRD and does not authorize implementation. The PRD, at lines 11-13 and 31, names the Uniswap V4 full-spread vault as the behavior source and says pair-token and upper/lower wings are not the template. All four responses recorded that difference. The coordinator re-read those lines. Satisfying the PRD is evidence. It is not a substitute for the council question.

Two comparators are live in the tree, and the responses do not agree which one the question names.

- Astra, grok, and kimi used `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/`. Their reason is the router sentence at `CLAUDE.md` line 24: that family is the supported V4 SE family, and both V4 FullSpread families are deleted and must not be restored. They read the full-spread files anyway. They did not treat those files as absent, and they did not treat them as the supported V4 SE vault.
- MiniMax used `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. The reason is that those production files are present, the PRD the plan names as authority points there, and the plan's gas citation at line 193 is a citation of a V4 implementation plan rather than of wings. MiniMax treated the router sentence as a governance-sensitive reading, not as a substitute for the files.

The coordinator does not pick a winner. Both files were present at admission. The router sentence and the PRD sentence were both re-read. They conflict as instructions about which vault is "the" V4 SE vault. That conflict is a preserved disagreement, not a license to call the plan accurate.

Under the wings reading, Q1 is plan not accurate. The coordinator checked the behaviors those three responses treat as decisive:

- Wings issues initial shares equal to target-token credit and later shares as `supply * credit / value`, and its accounting comment says there is no permanent sink (`upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol` lines 8-9 and 18-22). The plan requires raw-liquidity shares, a first add above 1,000, and `balanceOf(address(0))` of 1,000 inside `totalSupply` (plan lines 43 and 65).
- Wings exposes `getRate` as value per share (`upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol` lines 27-31) and executes `exchangeOut` (`upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultOutTarget.sol` lines 8-24). The plan forbids `getRate` (plan lines 33 and 36) and makes enabled `exchangeOut` fail closed (plan step 5, lines 100-108).
- Wings keeps an oracle liquid-reserve sleeve (`Accounting.sol` lines 41-48). The plan removes the sleeve (plan step 6, beginning line 110, under V3-ACC-08).

Those are different receipts and different successful calls. They are not a filename difference, and they are not cured by refusing `unlockCallback`. The plan's refusal of `unlockCallback` (plan lines 32 and 36) would be a permissible V3 mechanism only if the wings economic result were kept. It is not. Astra, grok, and kimi each reached plan not accurate on this reading. The coordinator's locator check does not contradict them.

Under the full-spread reading, Q1 is plan partially accurate, which the brief says is not a yes. MiniMax found the required economic rows matched the on-disk V4 full-spread planner: the 1,000 floor outside gross shares, liquidity share basis, usage fee taken from gross shares, one 49 percent entry swap, boundary add, zero-active refund, proportional bundle add, floored exit claims, booked versus unbooked balances, reserves excluding booked balances, privileged maintenance, and fail-closed exact-out. Astra, grok, and kimi did not adopt this as their Q1 comparator, but grok's separate observation says current V3 matches the present full-spread planner's economic results on the rows the plan copies. The coordinator does not promote that observation into agreement that Q1 is yes.

Two gaps keep the full-spread reading from being an accurate definition of "behaves like" that vault. The coordinator re-read both sides:

- Appointment while disabled. The plan, at lines 24 and 92, chooses that `setOperator` and `setOperatorFor` revert `VaultDisabled`. It labels that a plan choice, not a lock. V4 full-spread `setOperator` and `setOperatorFor` carry only `onlyLiveFeeToOwner` and do not call the disable gate (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` lines 122-131). Current V3 calls `_requireNotDisabled()` on both (`v3/UniswapV3FullSpreadStandardExchangeVaultMaintenanceTarget.sol` lines 63-73). A plan-faithful vault therefore differs from the V4 vault on a gate the brief included in "behave like."
- Zero-output pass-through. Plan line 95 says a pass-through refunds unspent input and that `minAmountOut` binds the swap output. It does not say what a zero-output quote does. V4 `_pass` records the quote's received amount and refunds the unspent input, and it does not set a failure flag (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` lines 120-130). Current V3 sets `failed` when `amountOut` is zero (`v3/UniswapV3FullSpreadStandardExchangeVaultPlanner.sol` lines 281-284) and then reverts `ExchangeInNotAvailable` (`v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol` lines 37-38 and 45). A zero-output pass-through that V4 can settle as a refund cannot be executed on the current V3 path.

A third difference is real and narrower. V4 bundle previews return zero words for an invalid route (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol` lines 24-36 and 42-48). Current V3 bundle previews revert (`v3/UniswapV3FullSpreadStandardExchangeVaultBundleQueryTarget.sol` lines 11-12 and 27-33). MiniMax reported this. The coordinator checked those lines. It is a preview-failure difference, not by itself the economic mint or exit formula.

MiniMax's further claim that the two proportional-liquidity implementations can differ by about one liquidity unit is inference from the two libraries. No member measured it. This draft does not adopt it as an observed behavioral difference.

The floor write is a named mechanism difference, not an unread gap. V4 execution calls `ERC20Repo._mint(address(0), Types.MIN_SHARES)` (`v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultExecution.sol` line 239). The plan, at line 43, forbids that call and requires a non-reverting write. Current V3 writes `balanceOf[address(0)]` and `totalSupply` directly (`v3/UniswapV3FullSpreadStandardExchangeVaultRepo.sol` lines 43-48). The plan states that result. It does not claim the V4 call path. Static reading does not prove the resulting balance.

Q2 is not confirmed. The question allows that confirmation only if the plan is an accurate definition of the requested refactor. Partial is not that accuracy. A wings mismatch is not that accuracy. No response returned Q1 as plan accurate.

Separate observation, not the requested confirmation: the current V3 production tree implements the plan's full-spread accounting on the paths read. The coordinator checked the direct floor write, the pass-through failure path, the appointment disable gate, and the bundle-query import of the V4 full-spread interface (`v3/UniswapV3FullSpreadStandardExchangeVaultBundleQueryTarget.sol` line 6). All four responses, in the observation section rather than in Q2, say the V3 tree substantially follows the plan. No response reported a material contradiction between the plan's required economic rows and the current V3 sources on the paths that member read. Gas, tests, and deployed bytecode were not run. This observation does not say the V3 vault behaves like upper/lower wings. Astra, grok, and kimi say it does not. The coordinator's wings checks above agree with that negative.

Import remains a V3 route the V4 full-spread vault does not have. The PRD, at line 195, says V4 has no import and that this is a V3 entry, not a V4 copy. Keeping it means the refactored V3 vault has a behavior the compared V4 vault does not. That is extra behavior, not a missed copy of wings or of full-spread.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Which live vault the question's "Uniswap V4 SE vault" names | Astra, grok, and kimi: `upperLowerWings`, because `CLAUDE.md` line 24 names it as the supported V4 SE family and says the full-spread families are deleted. MiniMax: on-disk `v4/fullSpread`, because the PRD names it, the files are present, and the plan's gas citation points at that family's plan. | The coordinator does not select one. The confirmation fails under both positions, for different reasons. |
| Whether a plan choice that changes an observable gate counts against accuracy | MiniMax: the appointment-disable choice is a reason Q1 is only partial, because the brief's "behave like" includes disable gates. Astra, grok, and kimi: that choice is not what makes Q1 fail; the wings economic mismatch does. | Both can be true. This draft keeps the choice as a full-spread gap and does not treat it as the wings verdict. |
| One-liquidity-unit proportional sizing | MiniMax: possible, inferred, not measured. The other three did not rely on it for their verdict. | Not adopted as an observed difference. |

## Evidence gaps

- No Forge build, test, or gas measurement was run. Every behavioral claim is static.
- The possible one-liquidity-unit sizing difference is unverified.
- Pair-token was not a behavior source in any response. It was not examined as the comparator.
- The external Standard Exchange rate-provider facet was not re-read by the coordinator for this draft. Provider sentences in the plan remain plan text, not a new runtime check.
- `CLAUDE.md` line 24 and the presence of `v4/fullSpread` sources were both observed. This draft does not resolve whether those files are the deleted family or a later tree. It does not restore anything.
- Live files can change. This draft is not an atomic snapshot.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| The implementation plan | examined | all four; coordinator re-read lines 4-5, 8, 24, 32-33, 36, 43, 65, 92, 95, 193 | none on the plan's own question |
| The locked PRD | examined | all four; coordinator re-read lines 11-13, 31, 195 | none on which family the PRD names |
| V3 production Solidity | examined on the cited paths | all four observations; coordinator re-read Repo 43-48, Planner 281-284, InBase 37-45, MaintenanceTarget 63-73, BundleQueryTarget 6-33 | no material plan-versus-code contradiction adopted; not a whole-tree proof |
| V4 full-spread production Solidity | examined on the cited paths | MiniMax as comparator; grok as a separate observation; coordinator re-read MoneyTarget 122-131, Planner 120-130, Execution 239, QuoteTarget 24-48 | not the Q1 comparator for astra, grok, or kimi |
| V4 upper/lower wings production Solidity | examined on the cited paths | astra, grok, and kimi as comparator; coordinator re-read Accounting 8-22 and 41-48, EconomicTarget 27-31, OutTarget 8-24 | MiniMax read enough to exclude it, not enough to use it as the comparator |
| Pair-token | not examined | not used | optional; no required document named it as the behavior source |

## Limits

- Static, extracted, supplied-runtime, and unverified claims stay distinguished. This draft uses static analysis and source observation only. There is no supplied runtime evidence.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- This draft does not authorize implementation. Advisory review has not happened. Silence after this draft is sent is not approval.
