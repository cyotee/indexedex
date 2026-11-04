# Member response
## Identity
- Run ID: apex-012-deposit-process-20261024
- Member label: minimax
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/apex-012-deposit-process-20261024/members/minimax/response.md
- Requested role: council-member
- Requested model and reasoning: minimax/MiniMax-M3
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets
This response answers three questions:

1. Why the prior clarity review treated a deposit as a sale of target for the other token.
2. Whether the existing V4 Wings deposit path actually sells target.
3. Whether deleting `Quote.quote` from the share mint while retaining the rest of the existing deposit sequence is valid under the preserved rulings, and, if not, the smallest valid deposit process.

The primary targets were the APEX-2026-012 PRD, `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol`, and `UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol`. I also used the open-questions file, the prior council report, `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol`, and the liquidation-quote implementation to verify whether the quote is executable.

## Evidence

### What the PRD said, and why the prior review assumed an entry sale

The prior review's assumption came from the PRD, not from the deposit implementation. The PRD's Required outcome says that entry and exit convert through a real swap (`docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md:13`), and its Entry section is explicit:

> If the position is already two-sided, the vault swaps part of that deposit into the other token against the same pool ...

(`docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md:41-45`).

The prior council report then restated that premise as “After a deposit that spends some target in the entry swap” (`docs/reviews/apex-012-prd-clarity-20261024/REMEDIATION_PRD.md:52`) and developed a separate “Entry swap” requirements question (`docs/reviews/apex-012-prd-clarity-20261024/REMEDIATION_PRD.md:58`). Thus, the review treated the PRD sentence as the governing deposit design; it did not discover an entry swap in `_deposit`.

The later owner correction is recorded in the open-questions file: “a deposit does not sell target for the other token,” and the counter question is invalid while it assumes that sale (`docs/security/audit/second_review/APEX-2026-012-OPEN-QUESTIONS.md:27-33`). The source PRD and the owner correction therefore disagree: PRD Entry still describes an entry sale, while the correction describes the existing process and rejects the counterfactual.

### What the existing code does

The existing V4 deposit does **not** sell target for the other token.

- `_deposit` pulls target, harvests, obtains a quote value, calls `Accounting.issue`, credits local target, mints shares, and calls `_place` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:120-139`). There is no swap operation in that sequence.
- `_harvest` calls `Harvest.harvest`; `_place` calls `Harvest.placement` (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:94-105`). The Harvest library expressly says “Ordinary harvest never swaps” and describes only closing converted wings and placing residuals (`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol:18-20`). Its placement work produces liquidity modifications, not swaps (`UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol:147-192`).
- `Quote.quote` is a `view`: it quotes removal and a hypothetical opposing-token sale but “does not execute swaps” (`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol:18-19,106-109`).
- The executable opposing-token sale is `_swapDeficit`, which constructs `Common.Kind.Swap` (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:219-232`). It is called only from `_fund` while funding a redemption (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:190-208`), and `_fund` is reached from `_redeem` (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:147-170`). It is not reachable from `_deposit`.

Accordingly, the quote in `_deposit` is a live valuation input, not a sale. The actual execution defect remains that the money path uses that whole-book quote to issue shares.

### Why simply deleting the quote is insufficient

Deleting `Quote.quote` removes the forbidden valuation call, but it does not leave the current sequence with a valid share-mint basis:

1. `Accounting.issue` currently computes `S * credit / value` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol:17-22`). With no quote, `value` has no valid replacement in the existing sequence. A target-only denominator would price the other-token side as though it did not exist, contrary to “Each share owns `1 / S` of the position. Every holder has the same mix” (`docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md:27-37`).
2. The preserved no-gift ruling makes a target-only deposit into an already two-sided position impossible under a strict global-fraction ownership model. If the pre-deposit position contains `O > 0` other token and the deposit mints `n > 0` new shares, the depositor owns `n / (S + n)` of the whole post-deposit position and therefore claims a positive fraction of that pre-existing `O`. The PRD expressly prohibits that result: “The depositor does not receive a gift of other token that was already in the position” (`docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md:41-47`; Test 6 at `:91`).
3. `_deposit` mints before `_place` (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:132-138`). A mint based on “the liquidity actually added against the position that existed before the add” therefore cannot be computed from the retained sequence unless placement is first planned or executed, or the pre-add and post-add snapshots are otherwise made available.

## Assumptions

- I treat the owner's 2026-10-24 correction as controlling over the contradictory PRD Entry sentence. In particular, I do not infer an entry sale merely from the prior review's questions.
- I use “position” in the PRD's sense: vault liquidity plus idle inventory, across the core and both wings (`docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md:27-31`).
- I read “without an entry swap” literally: the proposed no-sale process does not execute a target-for-other conversion.
- This is a static design review. No Forge run was performed, as instructed.

## Coverage

- Examined the PRD Entry, Accounting, Owner ruling, Rate checkpoint, and deposit-related tests.
- Traced `_deposit`, `_harvest`, `_place`, `_fund`, `_redeem`, and `_swapDeficit`; traced Harvest's `harvest`, `placement`, `close`, and `place` behavior; checked that the quote function is view-only.
- Examined the open-questions owner correction, the prior council report, and `Accounting.issue`.
- Did not examine any current-run peer response, did not launch a sub-agent, and did not run Forge.

## Conclusions

1. **Why the prior review assumed a sale:** because PRD Entry expressly prescribed one and the prior report repeated that PRD premise in its counter and entry-swap questions. It was a document-driven assumption, not a finding about `_deposit`.
2. **Does the existing deposit sell target:** no. `_deposit` pulls target, performs no-swap harvest/placement, reads a hypothetical whole-book quote, mints, and places. The only executable opposing-token sale is `_swapDeficit` on the redemption-funding path.
3. **Is the quote-free rest of the existing sequence valid:** no. Removing the quote fixes the prohibited live-quote dependency, but it does not supply a share basis and, for a two-sided position, a target-only mint grants the depositor a fraction of already-held other token. The smallest valid process consistent with the owner's no-sale correction is a **target-only, proportional, no-swap deposit permitted only while the pre-deposit position contains no other token**. Otherwise the deposit must revert unless the owner separately reconciles the PRD Entry sale with the no-gift rule.

## Review findings

### F1 — A quote-free target-only mint is not a valid two-sided deposit

- **Location:** `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:120-139`, especially the quote-based issue at `:132-133` and mint-before-place order at `:133-138`; `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol:17-22`; PRD Entry and Accounting at `APEX-2026-012-APPORTIONED-RESERVE-PRD.md:27-47`.
- **Preserved ruling:** a share is a fraction of the entire position, and “The depositor does not receive a gift of other token that was already in the position” (PRD `:31`, `:43`; Test 6 `:91`). The later-deposit proportional-addition/no-new-range rule is PRD `:24`.
- **Impact:** replacing the quote with a target-only denominator would make the share basis inconsistent with a two-sided position; using the ordinary global fraction would give the new holder a positive slice of pre-existing other token; and retaining mint-before-place prevents a direct “liquidity actually added” basis. The owner's correction validly invalidates the old gross/net entry-swap counter question, but quote deletion alone does not produce a valid replacement.
- **Smallest valid no-sale deposit process:**
  1. Before minting, snapshot the pre-deposit supply, each held position's liquidity, and idle target/other inventory.
  2. If any pre-deposit other token is held, revert the target-only deposit. A two-sided target-only deposit cannot satisfy both global fractional ownership and the no-gift ruling without an owner-approved conversion or a different ownership rule.
  3. Pull target and harvest without selling other token.
  4. Add the target contribution to the existing held positions and idle inventory in one common proportional factor `r`; do not open a range. If the implementation cannot apply the same `r` to every held component (subject to the specified rounding rule), revert/refund rather than mint unequal fractions.
  5. Mint `n = floor(S * r)` shares (residual rounding stays with the existing holders). This makes the depositor's post-mint fraction `n / (S + n)` of every held component.
  6. Credit the settled-target counter by the target actually received (`D` for a successful no-swap deposit) and leave other-token principal untouched.
  7. Use no liquidation quote, `slot0` rate, or entry swap.

  This is the smallest process that preserves the owner's no-sale correction and the preserved rulings without inventing an economic transfer. The only ruling that could require an entry conversion instead of a revert is the explicit no-gift ruling; that conversion must not be silently inferred from the prior review or the stale PRD sentence because the owner has rejected that premise.

## Limits

- The conclusions are about the named V4 Wings deposit path and the PRD's preserved rulings. They do not specify the unresolved first-deposit range-opening rule, the exact rounding/refund policy, V3 implementation, redeem slicing, or settled-counter debit rules at exit.
- The finding exposes a conflict between the PRD's Entry sentence and the later owner correction. It does not edit or supersede either document.
- No runtime behavior was verified, and no implementation was proposed beyond the minimum design sequence needed to answer the council question.
