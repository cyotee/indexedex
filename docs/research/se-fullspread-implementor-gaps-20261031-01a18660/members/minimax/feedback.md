# Advisory on draft se-fullspread-implementor-gaps-20261031-01a18660-r1

## Identity

- Member: MiniMax (`minimax/MiniMax-M3`), independent council member, profile: research.
- Run: `se-fullspread-implementor-gaps-20261031-01a18660`. Advisory round only.
- Output: `members/minimax/feedback.md` only. I did not edit `response.md`, the draft, the PRD, or the review file, and I did not read any peer response.
- I do not answer the owner questions below. Where a draft question omits a clause from my response, I name the clause and say why it is load-bearing; I do not say what the answer should be.

## Draft under review

- Draft ID: `se-fullspread-implementor-gaps-20261031-01a18660-r1`
- Path: `docs/research/se-fullspread-implementor-gaps-20261031-01a18660/coordinator/draft.md`
- Verification: `shasum -a 256` on the raw file returned `dcd2d1fd76fa2ebb501a074b1aa55b20d70173d494d104c190eec62ec5f9d0d5`, which equals the ID hash I was given. File is readable, 6624 bytes. I reviewed this draft.

## Disposition

**The draft states my questions accurately on substance, and covers 11 of my 12 questions.** One of my twelve is absent (the native leg's accounting unit), one is only half present (the entry liquidity derivation), and three carry a missing clause that is load-bearing for the owner's answer (Q1's denominator, Q7's selector consequence, Q1's exhausted-vault consequence). Two of the draft's questions are broader or narrower than mine in ways worth correcting before they reach the owner.

Nothing in the draft misstates a position I took. The draft also carries my two non-gap verdicts correctly: the later rate policy is correctly treated as not an open implementation choice, and the FS-OWN-07 "other semantics" sentence is correctly treated as stale rather than as a gap. The one place where the draft drops part of my correction is named below.

## Does the draft state my questions accurately?

| My question (`members/minimax/response.md`) | Draft question | Verdict |
| --- | --- | --- |
| Q1 — is the 1,000-share floor part of the ERC-20 `totalSupply()` or outside it | Q1 | **Accurate in substance, incomplete.** The draft asks the representation question correctly, but drops the denominator clause from my Q1. See OM-3 |
| Q2 — does compound withhold the sleeve target from reinvestment | Q4 | **Accurate** |
| Q3 — is a user redemption paid from local balances, or is the target retained and the payout reduced | Q3, Q5 | **Accurate, split across two questions.** See PP-3 |
| Q4 — which artifact is the runtime source of the PoolManager address and who writes it | Q6 | **Accurate** |
| Q5 — where the `wrappedNative` binding is read from at runtime | Q7 | **Accurate, incomplete.** See OM-4 |
| Q6 — native leg: native ETH in wei, or the wrapper face, in `localReserves()` and `reserves()` | — | **Absent.** See OM-1 |
| Q7 — does the package install a Position facet exposing `poolKey()` | Q10 | **Accurate**, but over-broad. See PP-1 |
| Q8 — `reserveOfToken` for a token outside `vaultTokens()` | Q11 | **Accurate** |
| Q9 — one-token exit with pro-rata idle in the unselected currency | Q14 | **Accurate and stronger** than mine: it also names the pro-rata liquidity leg and asks which accepted selector is the one-token exit |
| Q10 — `donate` destination, whether it may run while locked | Q15 | **Accurate and more complete** than mine: it adds the accepted-token set and the before-first-deposit case |
| Q11 — idle as stored counters or as the actual local balance | Q16 | **Accurate.** See PP-2 for the interaction with the draft's second recommendation bullet |
| Q12 — when the committed reserves snapshot is written | Q12 | **Accurate**, and it correctly bundles the "which views revert" half |

## Omitted load-bearing questions, by draft section

**OM-1 — "Questions for the owner": the native leg's accounting unit is missing.** Load-bearing. `reserves()` and `reserveOfToken()` are defined by FS-OWN-07 as the local term plus the deployed term, and the deployed term is denominated in the pool's actual currencies, which for a native leg is native ETH. `localReserves()` is defined by FS-OWN-04 as "the actual local balances of the underlying tokens", and the vault's local balance for a native leg can be native ETH or the wrapper's ERC-20 face. The two terms can therefore be denominated in different currencies, and the sibling baseline already states the convention the repo follows — "native booked reserves are ETH measured in wei, not a fictitious ERC-20 balance at address zero". The WETH/ETH ratio is 1:1, so the error is invisible in value and visible in code, in `reserveOfToken`, and in any comparison between a local balance and the pool's native delta. The draft's Q9 asks whether raw ETH reaches the user and Q17 asks the order of `vaultTokens()`; neither asks which unit the local term and the reserve views use. This should be a question in its own right, or an explicit clause in Q9 and Q17.

**OM-2 — "Questions for the owner": Q29 covers only half of the entry arithmetic.** Load-bearing. My response treated the entry balancing rule as closable from the cited source and supplied exact replacement prose for both halves: the amount traded before `_swap`, and the added-liquidity derivation. Draft Q29 asks only the first. The second half is the `LiquidityAmounts.getLiquidityForAmounts` value at the current pool price and the stored ticks, with each amount reduced by 2 wei, and it is the half that sets the shares minted for a given deposit. Q29 should either be extended to cover the liquidity derivation or be paired with a second question, and the coordinator should note that my response offered both halves as a closing recommendation rather than as an open question.

**OM-3 — "Questions for the owner": Q1 omits the denominator clause and the exhausted-vault consequence.** Load-bearing, twice. First, my Q1's second branch was explicit: if the floor sits outside the ERC-20 supply, the existing-supply branch's denominator must be defined, and my response named it as `MIN_SHARES + totalSupply()`. The draft's Q1 asks how the floor is represented but not what the deposit arithmetic divides by, so an owner could answer the representation and leave the second depositor's share count undefined. Second, my R7 recorded the consequence that follows from the same source: the genesis branch (`v.totalShares == 0`) is reachable only before the first deposit, because after every redeemable share is burned the vault retains the floor's residual supply and residual liquidity, so a later deposit takes the existing-supply branch and this PRD adds no re-genesis branch. The PRD's genesis sentence reads as though a genesis can recur, and the draft's Q1 does not tell the owner that it cannot. Add the denominator clause to Q1, and add the exhausted-vault consequence either to Q1 or as a closing recommendation.

**OM-4 — "Questions for the owner": Q7 omits the selector consequence of the WETH-aware option.** Load-bearing. My MG-06 named the three candidate homes for the `wrappedNative` binding: the family repo, the Crane WETH aware repo, or the V4 aware repo. The Crane WETH aware pattern is `WETHAwareRepo` plus `WETHAwareFacet` exposing `IWETHAware.weth()`, so choosing it installs a `weth()` getter on the diamond. That is a different selector from the family `wrappedNative()` that FS-OWN-10 forbids, it is not named in the PRD's facet tables, and it changes the manifest that FS-A01 asserts. The owner should see that cost before choosing a home for the binding, so Q7 should carry it.

**OM-5 — "Not a current gap": the third narrower gap behind the FS-OWN-07 sentence is dropped.** Load-bearing. My correction of inventory item 8 named three narrower gaps, not two: the unknown token, the reserve snapshot timing, and the population of the shared `vaultTokens()`. The third is not an owner question but a closing recommendation, so it belongs in "Recommendations that close a gap" rather than in "Not a current gap" — but it must appear somewhere. The shared getter reads a stored token set in `MultiAssetBasicVaultRepo` at slot `keccak256(abi.encode("indexedex.vaults.basic"))`, written by `MultiAssetBasicVaultRepo._initialize(address[] memory tokens)`, and FS-PKG-02's initialization list ("the name, symbol, pool key, and full-range ticks") does not include it. An implementor who does not write that set ships a vault whose `vaultTokens()` is empty, which breaks `reserves()` (defined in `vaultTokens()` order), the `amountsIn` order FS-OWN-09 requires, and the hook binds FS-HOOK-01 lists. Draft Q17 asks the order and content of `vaultTokens()`, and Q20 asks how one `PkgInit` field binds the two facets, but neither names the initialization write, and Q20 is the natural place to cross-reference it. My response carried this as exact replacement prose for FS-PKG-02.

## Precision points on the draft's framing

**PP-1 — Q10 asks the owner to decide something the locks decide.** My response separated the two halves of the query-facet question: the family query facet's selector list is determined by the locks (FS-OWN-06 keeps `tickLower()`, `tickUpper()` and `positionLiquidity()`, FS-OWN-04 keeps `localReserves()`, and the FS-FACET-01 row already lists the exclusions), so that half was closable with exact prose and no owner question; only the package membership of a shared V4 Position facet exposing `poolKey()` was an owner choice. As drafted, Q10 puts both halves to the owner, which invites the owner to re-decide the selectors the locks already keep. Either state the four lock-derived selectors as coordinator text, or scope Q10 to the Position-facet membership.

**PP-2 — Q16 and the second recommendation bullet state the same thing in opposite registers.** The bullet under "Recommendations that close a gap" asserts that pro-rata idle paid on withdrawal is Weir's stored idle counters and not `balanceOf(vault)`, while Q16 asks whether idle is the stored counters or the actual local balance. The draft's own framing — coordinator text, not an owner decision — makes this survivable, but the owner should see the consequence when answering Q15 and Q16: if the counters are the source of truth for the payout while `localReserves()` is the balance, then a `donate` that only moves the balance raises the local view without raising what a withdrawal pays, and Q15's "does it increase the idle a withdrawal pays" and Q16 cannot be answered independently of each other. Folding that dependency into the two questions, or into the bullet, would prevent the owner from answering them apart.

**PP-3 — Q3 narrows the locked-caller question.** My Q3 asked whether a user-facing redemption is paid out of the local balance and what that does to the sleeve target; the draft splits it into Q3 and Q5, which is a fair split, but Q3 adds "without opening an unlock" as a condition I did not impose. The draft's variant is the sharper reading of FS-OWN-04's own phrase and is worth keeping, but it should not remove the other variant from the owner's answer space: Q5 asks what happens to the target on redemption, and the answer depends on whether a call may spend local balances at all, with or without an unlock of its own.

## What the draft states correctly about my non-gap verdicts

- **Later rate policy.** "A later rate policy is not an open implementation choice. FS-OWN-03 already forbids installing one. Do not ask the implementor to pick a rate." matches my rejection of inventory item 9 exactly.
- **FS-OWN-07's "other semantics" sentence.** The draft's characterisation — stale, `IBasicVault` has three members, the lock already assigns them, and the live residue is an unknown token plus the snapshot timing — matches my correction of inventory item 8, subject to OM-5.

## Limits

- This is advisory only. It approves nothing, answers no owner question, and proposes no PRD edit. The corrections above are wording and completeness corrections to a coordinator draft that is still pending review.
- I reviewed only `coordinator/draft.md` at the verified hash, against my own `members/minimax/response.md`. I did not read the peer responses the draft lists as its sources, so I cannot say whether the draft reflects their positions accurately; my assessment covers only whether it reflects mine.
- The claims about repository behavior in OM-1, OM-4 and OM-5 come from the same read-only source reads recorded in my response (`contracts/vaults/basic/IBasicVault.sol`, `contracts/vaults/basic/MultiAssetBasicVaultRepo.sol`, `lib/crane/contracts/interfaces/IWETHAware.sol`, `lib/crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol`, `contracts/interfaces/IStandardExchangeInMulti.sol`, and the sibling baseline's S1-NATIVE-01). I ran no Forge, Git, install, or deployment for this round, and I did not re-verify the draft's hash with anything other than `shasum -a 256`.
- Where the draft's questions are broader than mine, I have not judged whether the broader form is correct on its own terms; I have only said whether it still carries my question, and where it drops a clause.
