# Coordinator draft

## Draft identity

- Draft ID: draft-se-fullspread-plan-readiness-20261101-r1
- Path: docs/research/se-fullspread-plan-readiness-20261101/coordinator/draft.md
- Run ID: se-fullspread-plan-readiness-20261101
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md. Coordinator checked `ERC20Repo._increaseBalanceOf` at `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:192-196` and the APEX-2026-044 and APEX-2026-023 summaries in `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

Are the locked full-spread vault requirements complete enough to write an implementation and testing plan now, without leaving a product decision to the plan author or the implementor?

## Proposed text

Not ready. All four originals reach that verdict. The owner already required the future plan to add this vault to the integration testing matrix, add it to the integration tests, and test that the second-audit vulnerabilities are not present. Those three items are scope. They are not open choices, and they are not reasons to invent an owner answer.

The plan can name the live hook-by-SE matrix under `test/foundry/spec/hooks/uniswap/v4/standardExchange/` and the second-audit finding IDs. It cannot assign expected results for the items below. A finding the tracker closed by deleting the old FullSpread code is not certified absent in this new vault.

### Decisions that block the plan

1. Usage fee versus APEX-2026-044. FS-OWN-24 mints the depositor's shares and then mints extra shares to `feeTo`. That is the dilution the audit measured. The absence test cannot pass while that sentence stands, unless the owner accepts 044 for this vault. The fee base is also unstated: depositor shares only, or also the 1,000-share floor. Owner question: is the extra mint accepted, or must the fee be taken from the depositor's shares, with preview and `minAmountOut` using the net amount, and is the 1,000-share floor excluded from the fee base?

2. Live-price deployment versus APEX-2026-023. FS-OWN-12 and FS-OWN-14 deploy or move liquidity at the live pool price. FS-OWN-10 forbids a hidden tick or price cap. The audit's loss comes from adding liquidity at a price the caller just moved. Owner question: is placement at the live price accepted, or what exact pre-operation bound must the plan enforce?

3. `compound()` with no fees. FS-OWN-14 says compound deploys booked idle, and also says a no-fee call returns with no state change and no event. Owner question: if idle is present and fees are zero, does `compound()` still deploy idle and adjust the sleeve, or does it return immediately?

4. Share floor versus the shared ERC-20 facet. FS-OWN-11 mints 1,000 shares to `address(0)`. FS-FACET-01 installs `erc20Facet`. `ERC20Repo._increaseBalanceOf` reverts `ERC20InvalidReceiver` for `address(0)`. Coordinator checked that revert. Owner question: which holder, or which mint path, satisfies both sentences?

5. Sleeve value is outside the share formula. FS-MONEY-01 mints from added liquidity over existing liquidity and says idle is not in the denominator. The sleeve is now a required reserve, not dust. A later depositor can receive a claim on value they did not bring. A zero-liquidity denominator is also unspecified. Owner question: does issuance stay liquidity-only, accepting that transfer, or how does booked local value enter the share calculation, including when deployed liquidity is zero?

6. One-token donation. FS-OWN-21 deploys an underlying donation before `donate` returns. One token cannot become full-range liquidity by itself. Owner question: does the donation swap its own input, use the other holders' opposite token, or revert, and what happens to an amount that cannot be placed, including dust and a donation before the first mint?

7. View reverts. FS-OWN-19 says no view reverts. FS-A32 says busy economic views revert. `previewExchangeOut` is specified to revert `ExchangeOutNotAvailable()`. Owner question: which views may still revert, and what does a non-reverting unsupported or busy preview return?

8. External getters and the non-PoolManager addresses. `queryFacet` is still under function review. FS-OWN-16 writes only `poolManager`. FS-OWN-18 names six more components and does not say when they are written or which selectors this diamond exposes. Owner question: which Protocol Aware and Position getters are installed on this proxy, and what exact value is written at initialization for each of the six components besides PoolManager?

9. Hook fixture rate provider. This vault has no `getRate()`. The required hook and DETF integration still needs a named external provider, its valuation quantity, and whether the 32-byte decoder migration is in this plan. Owner question: which provider and valuation policy do those fixtures use, and is the decoder migration in scope?

10. Sleeve adjustment when the two tokens are out of ratio. FS-OWN-12 requires a per-token move. Adding or removing liquidity cannot fix a one-sided excess without a swap. FS-OWN-25 authorizes a swap for `exchangeIn` only. Owner question: may the sleeve adjustment swap, or may it only add and remove liquidity in the current pool ratio?

11. Borrowed-path shortfall units. FS-OWN-31 pays the caller's local fraction from the sleeve and otherwise reverts `UnderlyingUnavailable(protocol, required, available)`. The claim is two tokens. Owner question: what token and amount are `required` and `available` for a one-token exit, and may the vault spend more than that holder's local fraction?

12. First-mint share unit. FS-OWN-27 says scale to token decimals. FS-MONEY-01 says the first mint is raw V4 liquidity minus 1,000 and does not rescale that constant. Owner question: are genesis shares raw liquidity minus 1,000, or what conversion produces the 18-decimal share amount?

13. `Compounded` amount. The event does not say whether `amount` is harvested fees, amount reinvested, or net deployment after the sleeve move, or what is emitted when fees exist but no liquidity is added. Owner question: which quantity is `amount`?

14. WETH binding home. There is no `wrappedNative()` getter. `PkgInit.wrappedNative` remains. Owner question: must that field equal the network `WETH` constant, and which repo stores it?

15. Paired event ABI and the two linked-library slots. The mapped routes must emit paired events, but the names and arguments are not fixed. `SwapProjection` and `ExecutionPreparation` remain required libraries after PairToken economics were removed. Owner question: what are the event signatures, and what do those two libraries compute, or are the slots removed?

### What is not a new product choice

The matrix addition, the integration rows, and an audit-regression inventory can be listed now. Old exact-out and booked-remainder rows do not override this family's refund and no-exact-out rules. The tests assert the locked behavior. They do not reopen it.

A finding whose mechanism is only in a Balancer pool, an Aave or Stata vault, a DETF minter, or the Crane ownership library does not become a vault behavior choice. The plan records that exclusion. Members disagree on how many finding IDs need a direct test. That count is not an owner decision. The final inventory waits for the advisory pass.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Quote step cap and tick spacing | MiniMax: the quoter, step cap, fallback, and minimum spacing are owner choices because APEX-2026-041 and APEX-2026-026 are otherwise open. Kimi: 026 does not apply, and 041 is a test that the new planner must not gain an undocumented cap. Astra and Grok did not make the cap a blocker. | The draft does not add a spacing or step-cap question. If the advisory pass shows the plan must choose a quoter, that question is added in the final. |
| Pretransfer and APEX-2026-039 | Astra: booking only the requested amount does not say who supplied it, or whether recipient-equals-vault is allowed. Kimi: the existing unbooked rule is enough to write an absence test. | The draft does not add a 039 question. |
| Donation deployment | Astra and Kimi: one-token deployment is open. Grok: FS-OWN-21 closed donation custody and is not a blocker. | The draft keeps the conversion question because the locked sentence does not say how one token becomes liquidity. |
| Rate provider | Astra and Kimi: the required fixtures need a named provider. Grok: the plan must not invent a provider to make a matrix row pass. | The draft asks which existing provider the fixtures use. It does not authorize a new vault `getRate()`. |
| Finding-test count | MiniMax: 12 fixed tests, 6 conditional, 26 none. Kimi: 27 require coverage, 18 do not. Astra and Grok disposition all 45 without the same counts. | The final inventory must not pretend those counts agree. |

## Evidence gaps

- No member executed the new vault. It does not exist.
- The retired FullSpread sources were not reconstructed. Finding text was used where the old code is gone.
- Public search was not required and was not used by the coordinator.
- Kimi's response file existed before that task's completion notice. The coordinator read it only after the task settled.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Full-spread PRD | examined | all four | Later locks override stale sentences. Members still find conflicts inside the later locks. |
| Function-review file | examined | all four | It locks behaviors and does not assign every selector to a facet. |
| Second-audit report | examined | all four | Applicability counts disagree. Mechanism descriptions of 044 and 023 were checked by the coordinator. |
| Remediation tracker | examined | all four | Closing 011, 041, 042, and 051 by deletion does not certify this vault. |
| ERC20Repo address(0) revert | coordinator-checked | grok | `ERC20Repo.sol:192-196`. The other three did not cite this locator. |

## Limits

- Static, extracted, supplied-runtime, and unverified claims stay distinguished. The address-zero revert is a source observation. The share-formula transfer is an algebraic illustration from Astra, not an executed exploit.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- This draft is not the implementation plan and does not replace the PRD.
