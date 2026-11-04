# Coordinator ledger

Executed 2026-10-26 from `research/ledger.py`. SHA-256 `558fe479e1d6cdfa673c33484533416b7ce77ca4abfe83cae9f35faad326c7ae`. Reproduce with `python3 research/ledger.py` from this run root. Standard-library Python only. The program writes `research/results.json` and does not touch production code.

This is exact rational arithmetic for one infinite-range interval. Token1 is target. Token0 is opposing. The fee is taken from input and credited to current liquidity. It is not added to the curve. No Forge run, no PoolManager trace, no wing activation, no harvest, and no reproduction of the audit PoC. A positive row is a closed target-token gain with opposing, shares, and debt at zero, and both token totals conserved. It is not a production exploit.

## Deposit swap and exit swap, executed-price mint

Rule: swap a fraction of the deposit, mark the old book and the retained tokens at `target spent / opposing received`, mint `supply * credit / value`, add matched liquidity, park the excess idle, burn the new shares, and sell only that slice's opposing.

Vault owns the whole interval. Deposit 200. Swap half. Fee 0.3%.

| Claim | Exact | Decimal |
| --- | --- | --- |
| Target profit | `909146072454192229/210758608401740140` | 4.313684168578358362 |
| Ending opposing | 0 | 0 |

Zero fee, same sizes: profit `80/17` = 4.705882352941176471. That identity was derived before the script asserted it.

The same rule with the exit sale omitted does not close in target. Target delta is `-99850/1247` = -80.072173215717722534, and opposing left is `49850/1247` = 39.975942261427425822. That residual is not a profit and not a safety proof. Selling it is the closed row above.

288 cases: 6 vault fractions, 4 fees, 3 entry splits, 4 deposits. Executed-price profit was positive in 155. The proportional control was positive in 0. At 0.3% and a 200 deposit with a half swap, the proportional loss equals the no-vault swap-and-reverse loss, `-8973027/19940090` = -0.449999322971962514.

## Exit swap against the live quote

Mint remains `supply * deposit / quote`. The quote sells vault opposing after removing vault liquidity. Unsold opposing adds nothing. Exit is either that quote paid in target, or a proportional slice sold for actual proceeds.

| Vault fraction | JIT multiple of pool liquidity | Exit | Target profit |
| --- | --- | --- | --- |
| 1/2 | 0 | quote | 0 |
| 1/2 | 0 | slice | 12.199409 |
| 1/2 | 10 | quote | 25.866279 |
| 1/2 | 10 | slice | 12.117813 |
| 1 | 0 | quote | 0 |
| 1 | 0 | slice | 22.199955 |
| 1 | 10 | quote | 60.440726 |
| 1 | 10 | slice | 22.178387 |
| 1 | 100 | quote | 65.810536 |
| 1 | 100 | slice | 22.177741 |

The slice sale removes the extra profit that appears when redemption pays the JIT-inflated quote. It does not remove the profit from minting against a quote that haircuts unsold opposing. At full ownership and no JIT, the quote redeem pays the deposit back, and the slice sale still nets 22.199955 target.

JIT capital is repaid in kind through the same pool. `end0` is 0 on every row above. Where `sleeve_covered` is false, the quote payout was funded by closing vault liquidity, not by an idle-target sleeve. That is the settled funding shape, not the in-unlock sleeve path.

## Both swaps, mint still the live quote

The vault swaps half of a 200 target deposit before the quote. The quote does not include the pending swap proceeds. Mint credits the gross deposit. The slice exit then sells the withdrawn opposing. Fee 0.3%.

| Vault fraction | Target profit |
| --- | --- |
| 1/2 | `943314298764595081/197242412301484730` = 4.782512 |
| 1 | `985035973/59820180` = 16.466617 |

Ending opposing is 0. The quote-redeem variant of this order was not executed: the idle target did not cover the quote payout, and that branch stopped rather than inventing a funding path.

## What this supports

Executed deposit and exit swaps do not eliminate reserve extraction for these two priced mint rules. The swap prices the quantity that traded. Marking inventory that did not trade at that execution price, or minting from the live whole-book quote, still leaves a closed target gain in the rows above. A price-free proportional join did not. That control gives up full credit for the unmatched token.

This file is not a council verdict and not implementation authority. `getRate` was not redefined.
