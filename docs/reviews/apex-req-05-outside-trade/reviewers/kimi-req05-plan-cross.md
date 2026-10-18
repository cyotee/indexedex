# Kimi K3 — cross-review: REQ-05 plan drafts

- **Label:** Replacement-session cross-review, resuming my plan draft (`kimi-req05-plan.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The three peer drafts were read in full as untrusted output. The coordinator's two notes were verified against source before acceptance. Nothing was edited.
- **Date:** 2026-10-17. I did not run Forge.

## Coordinator note 1 — wings decimals: confirmed; I retract `7 * 10 ** 6`

`TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol:35-37` (re-read): token A is built at 6 decimals and token B at 18, then **sorted by address** (`if (address(token0) > address(token1)) (token0, token1) = (token1, token0)`). So `token0`'s decimals are deployment-order-dependent and must not be hardcoded. My draft's `7 * 10 ** 6` assumed the unsorted construction order — withdrawn. The closed form, per the coordinator and Astra's draft, is `7 * 10 ** uint256(token0.decimals())`, which equals `7 ether` on the 18-decimal fixtures and satisfies PRD `:36` in all cases. Note wings0's target is `token0` (base `:49`), so the token choice itself is fixed; only the amount expression was at issue.

Grok's wings block is wrong on two counts: it uses `token1` ("It has 18 decimals in all three fixtures" — unverifiable under the address sort) and the wings vault accepts only its target token (`token0`), so a token1 call would revert on route validation, not the credit check. Rejected.

## Coordinator note 2 — MiniMax's share-delta credit is not the PRD: agreed, rejected

MiniMax's block (`:114-136` et seq.) inserts a **successful** true-flag `exchangeIn` of the 7 ether between the transfer and the revert leg, then defines `credit` as the caller's **share** delta (`balanceOf(this) - beforeCallerShares`). That is not the PRD: the PRD's credit is the token credit `balanceOf(vault) − reserveOfToken(token)` measured with no intervening successful operation (`:36-38`), the revert leg requests `credit + 1` of **input tokens**, and a successful deposit in between would sync the book and absorb the donation before the revert leg runs. His block also omits the post-rejection unchanged-balance/book/supply assertions (PRD `:39`), and his wings block uses `7e18` on a 6-decimal-or-sorted token. His command (`:199-203`) passes the three test files as positional sources — the misuse ruled out in the REQ-SEP-01 cross-review (positionals are edited production sources; test roots are auto-consumed). Rejected on all three points.

## The closed plan

Astra's draft is the strongest and I adopt its structure wholesale; with the coordinator's uniform amount expression it becomes the single plan:

1. **Preflight anchors** (all four drafts agree): hookless `AttributionAndBooking.t.sol:34-42`, Pons `:37-45`, wings `VaultMoney.t.sol:26-36` — unchanged as of this session; drift stops the batch.
2. **Token:** `token0` in all three files (hookless/Pons fixtures are 18-decimal by base default — Pons `…Acceptance.sol:32-33`, hookless in-file `1e18` literals; wings' token0 is the vault target). **Amount:** `uint256 transferAmount = 7 * 10 ** uint256(token0.decimals());` in all three blocks — the coordinator's closed form. **Caller:** `address(this)` (bytecode witness asserted), never an EOA, never the trader actor.
3. **Block shape (Astra's):** capture `heldBeforeTrade` before the outside swap; after the existing book assertions, assert the trade added no held tokens; record `unbookedBefore = heldBeforeTrade − book0`; `assertTrue(token0.transfer(vault, transferAmount))`; recompute held/booked and assert `credit == unbookedBefore + transferAmount`; `expectRevert(TransferDeltaInsufficient(credit + 1, credit))` on the family's true-flag `exchangeIn` (`vault.exchangeIn(token0, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp)`; wings uses `IStandardExchangeIn(address(wings0)).exchangeIn(...)`); then the three post-rejection unchanged assertions. Insertion points: hookless after `:42`, Pons after `:45`, wings after `:36` — before any operation that could sync the book.
4. **V3 LocalBook untouched** (cited, PRD `:28, :41`); no production edit; no deleted-V4 content; `minted == preview` lines stay but are not this proof.
5. **Command (Astra's, matching the REQ-SEP-01 ruling):** zero positional sources; three `--test-root` flags for the three files; `-- -vv`; hermetic profile; warm caches preserved. A failed or differently-byte reverting call stops the run and is reported, never re-expected.

## Corrections and unresolved dissent

- My two corrections are recorded above: the hardcoded wings amount (retracted for the computed form) and — carried from my draft — the rest of my block shape converges to Astra's stronger version (pre-trade custody anchor and bytecode witness adopted).
- MiniMax's draft is rejected on the share-delta credit, the missing post-rejection assertions, the wings amount, and the command form; its preflight tables remain accurate descriptions of the current files.
- Grok's token choice for wings is rejected (target-token constraint); his hookless/Pons content is otherwise the shared shape.
- No unresolved dissent remains after these rulings. Consensus is not proof: the revert bytes and the exact credit values are runtime facts the later authorized run must produce, and no pass ran Forge.

I did not run Forge.
