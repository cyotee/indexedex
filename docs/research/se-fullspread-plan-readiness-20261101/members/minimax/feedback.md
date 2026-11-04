# Identity

Member `minimax`, council member for run `se-fullspread-plan-readiness-20261101`. This is the advisory pass on the coordinator's draft, after my initial `members/minimax/response.md`.

I read the draft and the local repository files needed to check its load-bearing claims. I did not read peer feedback, any other member file, the resolution, or `RUN.md`. I did not edit the draft, the PRD, the function-review file, the audit files, or any project code, and I did not implement or run anything.

# Draft under review

- Draft ID: `draft-se-fullspread-plan-readiness-20261101-r1`
- Path: `docs/research/se-fullspread-plan-readiness-20261101/coordinator/draft.md` (readable at that path; 10,931 bytes, 104 lines)
- Run ID: `se-fullspread-plan-readiness-20261101`
- Coordinator-supplied SHA-256: `3ed7a08203e0cb077ad442a4b2e8538cd315f13bd2a132ee46627f51cce5e2b3`. I recorded it as supplied. I did not recompute the hash and I did not hash the file, per the instruction.
- The file's own `Fingerprint:` field reads "not computed", consistent with the supplied hash describing those bytes.
- Sections present: Draft identity, Participation, Question, Proposed text (Decisions that block the plan; What is not a new product choice), Preserved disagreements, Evidence gaps, Coverage adopted from responses, Limits.

# Disposition

**REQUEST CHANGES.**

The draft's verdict is right and I reach it independently: not ready, and the owner must answer before a plan can be written without a product choice. The draft's discipline is also right — the three owner-mandated scope items are treated as scope, a tracker closure by deletion is not treated as a certificate of absence, and the finding-count disagreement is held open rather than papered over.

Five corrections matter. One numbered blocking decision is not a blocker on the evidence the draft itself cites, and the coordinator's "checked" note for it propagates into the coverage table. Two blocking decisions rest on a mis-stated premise. One of my three original blockers is missing from the numbered list even though the draft's own preserved-disagreement row says it would be added if the advisory showed it must be. And the final still owes the concrete matrix file inventory that the brief made a required part of the answer.

# Concerns

Corrections are named by draft section. Each is a correction, not a rewrite of the draft.

## 1. "Decisions that block the plan", item 4 — the address(0) floor is not a blocker

The draft states: "`ERC20Repo._increaseBalanceOf` reverts `ERC20InvalidReceiver` for `address(0)`. Coordinator checked that revert." and asks "which holder, or which mint path, satisfies both sentences?"

The cited function is real, but it is not on the mint path. `ERC20Repo._mint` at `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:329-334` has the `_increaseBalanceOf` call **commented out** on line 330 and writes `layoutStruct.balanceOf[recipient] += amount` directly. The shared `ERC20Facet` exposes no public mint — Crane's `ERC20Target` has exactly the nine `IERC20`/metadata selectors — so a family must mint through the repo, and every sibling family does: `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:99`, `.../upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:137`, `.../pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol:492`, all `ERC20Repo._mint(...)`.

The sibling family already performs exactly this act, with the same shared `erc20Facet` cut into its package (`UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol:150-152` installs `pkgInit.erc20Facet` with `ERC20_FACET.facetFuncs()`), and it does not mint to `address(0)`: `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:80` sets `DEAD_SHARES_SINK = address(0x000000000000000000000000000000000000dEaD)`.

So FS-OWN-11 is implementable as locked, and the residual choice is narrow: the plan writes the literal `address(0)` the lock names, or the repository's dead-address convention. That belongs in the plan's implementation notes, not in a list of decisions that block the plan.

**Exact correction to that item.** Replace it with a narrow plan note: "The 1,000-share floor is minted through `ERC20Repo._mint`, which does not route through `_increaseBalanceOf` and therefore does not revert on `address(0)`. The plan states whether it uses the locked literal `address(0)` or the sibling family's `DEAD_SHARES_SINK` convention."

## 2. "Coverage adopted from responses", row "ERC20Repo address(0) revert" — the checked locator is not the binding path

The row records "ERC20Repo address(0) revert | coordinator-checked | grok | `ERC20Repo.sol:192-196`". The locator is `_increaseBalanceOf`, which the mint path does not call. A coordinator-checked row is the strongest evidence class in the draft; it must not carry a claim that the mint path does not reach.

**Exact correction to that row.** "ERC-20 mint to `address(0)` | coordinator-checked | grok | `ERC20Repo.sol:329-334` (`_mint`, the path the families use) and `:192-196` (`_increaseBalanceOf`, the path the mint does not use); the sibling precedent is `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:80`."

## 3. "Limits" and "Evidence gaps" — the address-zero bullet understates the problem

The Limits bullet says "The address-zero revert is a source observation." It is a source observation, but of a function that is not on the path the locked sentence exercises. The bullet should say so, otherwise the final carries an apparent confirmation of a blocker that the evidence does not support.

**Exact correction to that bullet.** "The `ERC20InvalidReceiver` revert is a source observation of `ERC20Repo._increaseBalanceOf`, which the mint path does not call; FS-OWN-11's `address(0)` floor is therefore implementable through `ERC20Repo._mint`."

## 4. "Decisions that block the plan", item 2 — the premise is stated more strongly than the PRD supports, and the redemption side is missing

The draft states: "FS-OWN-12 and FS-OWN-14 deploy or move liquidity at the live pool price. FS-OWN-10 forbids a hidden tick or price cap."

Three corrections. First, neither FS-OWN-12 (the sleeve adjustment) nor FS-OWN-14 (the compound) says "at the live pool price"; the live fill comes from FS-MONEY-01's limit, and the owner is being asked to accept an unbounded limit, not to ratify a phrase the PRD does not contain. Second, FS-OWN-10 does not forbid a price cap: it drops `previewWithdrawalMode`, `wrappedNative()`, `previewZapCredit`, `maxZapBps` and `maxZapTickMove`, and its "No replacement view, cap, tick bound, or hidden constant is added" is scoped to those zap surfaces. Third, the item omits the redemption side entirely, and that is where APEX-2026-024 lives: FS-OWN-15 says a redemption "takes deployed liquidity first and may swap through the pool. The purpose is pool volume", which is the shape that dumps the opposing balance at a MIN/MAX limit.

**Exact correction to that item.** "2. Unbounded swap limits versus APEX-2026-023 and APEX-2026-024. FS-MONEY-01 fixes the entry swap's limit at `TickMath.MIN_SQRT_PRICE + 1` / `TickMath.MAX_SQRT_PRICE - 1`, FS-OWN-14 makes `compound()` permissionless over booked idle, and FS-OWN-15 lets a redemption swap through the pool for volume. The audit's loss comes from filling at a price the caller just moved (APEX-2026-023) and from selling the whole opposing balance at a MIN/MAX limit (APEX-2026-024). Owner question: is an unbounded limit accepted, and what exact pre-operation bound must the plan enforce, on the entry swap, on `compound()`, and on the redemption swap?"

## 5. "Decisions that block the plan", item 1 — the fee-base clause is already answered

The draft adds "The fee base is also unstated: depositor shares only, or also the 1,000-share floor." FS-OWN-24 states the base: `mulDiv(sharesMinted, usageFeeOfVault(address(this)), 1e18)`. The base is the shares minted by that mint. The only residual question is whether the genesis floor mint is fee-bearing, and `mulDiv(1000, f, 1e18)` is 0 for any `f < 1e15` (0.1 %), so it is immaterial at any realistic fee and should not be put in front of the owner as part of the same question.

**Exact correction to that item.** Drop the fee-base clause and keep the gross/net and preview/`minAmountOut` question, which is the part the audit's fix requires and the PRD does not state.

## 6. "Decisions that block the plan" — a fourth blocker is missing, and the draft's own rule says it should be added

My original response made three blockers: the usage fee (APEX-2026-044), live-price deployment (APEX-2026-023 and APEX-2026-024), and the quote mechanism. The draft carries the first two as items 1 and 2 and records the third in "Preserved disagreements" with the note: "If the advisory pass shows the plan must choose a quoter, that question is added in the final."

This advisory shows it does. FS-PKG-02's `InvalidPoolKey` list has no tick-spacing term, and FS-OWN-22 keeps only that the pool "is initialized on the bound manager and the hook is `address(0)`", so the PRD accepts a spacing-1 pool — the exact precondition of APEX-2026-041's dust-tick freeze and APEX-2026-026's step-limit freeze. The PRD also never states a pricing method, a step bound, a fallback on hitting the bound, or a partial-fill rule, and APEX-2026-051 is the analytic branch of that same surface. The plan would otherwise have to choose all four.

**Exact correction — add as a numbered item.** "N. Quote mechanism, step bound, fallback and tick spacing versus APEX-2026-041, APEX-2026-026 and APEX-2026-051. Owner question: for the entry and redemption swap previews, does the vault price with the V4 Quoter's bounded `quoteFromState`, with the analytic planner, or with a bounded exact-in fallback; when the bound is hit, does the route revert or pay a partial fill; and does `deployVault` accept any tick spacing or enforce a minimum?"

## 7. "Proposed text" — the final is missing the matrix file inventory

The draft's Proposed text says the plan "can name the live hook-by-SE matrix under `test/foundry/spec/hooks/uniswap/v4/standardExchange/` and the second-audit finding IDs." The brief made the concrete inventory a required part of the answer, and the final report is where it belongs. The final should carry: the new adapter `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`; seven new row files, `<Prefix>_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol`, under `constantProduct/single/`, `dual/`, `orbital/`, `single/`, `stable/quad/balancer/`, `stable/quad/curve/` and `weighted/`; the seven `<Prefix>_SeMatrixBehavior.sol` row-body contracts, reused unchanged because all ten `test_row_*` bodies are `virtual`; the two same-`PoolManager` adapters `FullSpreadSameManagerAmmFixture.sol` and `FullSpreadSameManagerWeightedFixture.sol`; and the evidence files `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md` item 1, and `acceptance.json` R10.3. It should also record the two deviations this family forces into the row set — the exact-out row tests cannot pass because `exchangeOut` reverts `ExchangeOutNotAvailable()`, and `test_row_partialConsumption_bookedNotRefunded` asserts "booked" where FS-OWN-32 refunds — and that the matrix PRD §5 pointer to a "V4 adversarial TestBase" is stale, that TestBase having been deleted with the retired families.

## 8. "Proposed text" — "It cannot assign expected results for the items below" is broader than the evidence

The draft says the plan "cannot assign expected results for the items below", which risks a final that reads as "nothing can be specified until the owner answers". Twelve findings have a fixed expected value under the locked PRD, and twenty-seven need no test in this family at all, each for a stated reason. Only six are blocked, plus one that becomes live only if the quote question is answered with a deviation guard.

**Exact correction to that paragraph.** "The plan can and must assign expected results now for the twelve findings whose mechanism the locked PRD already decides, and must record the twenty-seven exclusions with their reasons. Only the six blocked findings, and the one that becomes live if the quote question is answered with a spot-versus-TWAP guard, wait on an owner answer."

## 9. "Decisions that block the plan" — the flat list needs three classes, not one

The draft's fifteen items mix decisions of very different weight. The zero-liquidity denominator in item 5 and the `Compounded` amount in item 13 are real gaps; the WETH binding home in item 14 is a one-line implementation fact; the address-zero floor in item 4 was not a gap at all. The owner currently receives fifteen undifferentiated questions, and the two that most affect value transfer (items 1 and 2) are buried among thirteen narrower ones. The final should split them: (i) decisions that change value transfer or fee ownership — items 1, 2, 5, 6, 10, and the new quote item; (ii) decisions that change the ABI or the installation — items 4 (narrowed), 7, 11, 12, 13, 14, 15; (iii) decisions the plan can settle from the repository — the zero-address mint path, the `UnderlyingUnavailable` error home, the EIP-712 domain name and version, the zero-share-mint guard, and the emitted event names.

Item 15 also carries two unrelated questions in one number — the paired event ABI and the `SwapProjection` / `ExecutionPreparation` library slots. They should be split.

## 10. "Preserved disagreements", row "Finding-test count" — reconcile, do not re-open

The row says "The final inventory must not pretend those counts agree." That is right, and the counts are not a disagreement about the facts: they are a disagreement about classification granularity. The per-ID inventory exists in the member responses. The final's remaining work is reconciliation against the draft's own items 1 and 2, not a fresh pass. It should say that, so the final does not read as "the inventory is still missing".

# What was not adopted from others

- **Grok's position on the address-zero floor.** The draft's item 4 and the coordinator's coverage row carry it. I did not adopt it, and the correction above is against it. This is the one place where my advisory departs from another member's recorded finding rather than from the draft's synthesis.
- **Grok's position that FS-OWN-21 closed donation custody.** The draft kept the donation question (item 6). I did not adopt Grok's position and do not contest the draft's: one token cannot become full-range liquidity by itself, and the draft's item 6 is the better reading. I raise no correction to item 6.
- **Astra's extra sub-question on APEX-2026-039.** The draft's preserved-disagreement row records that "booking only the requested amount does not say who supplied it, or whether recipient-equals-vault is allowed", and the draft did not add a 039 question. I did not adopt that extra sub-question. FS-OWN-20 and the inherited Crane funding rule are enough to write the 039 absence test, and the exclusion of the exact-out path already removes the finding's exploit; adding a question here would widen the owner's list without a decision changing. I keep my original position that 039 needs a test, not a question.
- **Kimi's position that APEX-2026-026 does not apply and that APEX-2026-041 is a test.** I did not adopt it. The draft's preserved-disagreement row already records the split, and I hold my position: the PRD accepts a spacing-1 pool, so a dust-tick freeze is reachable, and a test with no expected value is not a test. The correction above adds the quote item to the numbered list rather than leaving it in the disagreement table.
- **Kimi's finding counts.** Not adopted as a count; the inventory in the member responses is reconciled rather than replaced.

# Limits

1. I reviewed one draft and one round. This advisory neither replaces the draft nor authorizes implementation, deployment, a configuration change, or any Git action, and it does not itself answer any of the fifteen owner questions it discusses.
2. The draft's supplied SHA-256 is recorded as the coordinator supplied it. I did not recompute it, and I did not hash the file.
3. My corrections to items 1, 2 and 4 rest on repository source I read directly in this session: `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol` lines 192-196 and 329-334, `lib/crane/contracts/tokens/ERC20/ERC20Target.sol`, `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:80`, `.../v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol:150-152` and `:279`, `.../v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:99`, `.../upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:137`, `.../pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol:492`, and the locked PRD itself. I did not execute anything, run a test, or reconstruct the retired V4 FullSpread sources.
4. I did not re-derive the other members' findings or their counts, and I did not read peer feedback. Where the draft attributes a claim to a member, I engage with the claim as the draft states it.
5. The severity ordering in Concern 9 is my proposal for the final's structure, not an instruction; the owner decides what to answer first, and the coordinator may reorder.
6. Native did not expose my runtime identity beyond this assignment, so I state nothing further about model, provider or reasoning internals.
