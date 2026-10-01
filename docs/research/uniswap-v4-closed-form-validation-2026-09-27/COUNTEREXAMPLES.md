# Counterexamples

All integer swap and share results below were reproduced by production Solidity, except the CF-G and shortcut rows, which are Python-only vectors.

| Case | Input | Result |
|---|---|---|
| CF-R fee | Active liquidity `1_000_000`, vault owns all of it, sqrt price `2^96`, target `77444695801180412768602321494`, fee 3,000 pips, free balances `50_000` and `5_000` | Production swap reaches the target with input `23,029`, output `22,510`, fee `70`. Inventory ratio error is **2 bp**. |
| CF-R cap | Same book, sqrt cap `79129312616115486070837105845` | Price impact is exactly 25 bp. Mismatch falls from **1,840 bp to 1,747 bp**. |
| CF-B | `reserveOut=50`, `reserveOther=50`, `amountOut=12`, `supply=100` | Radical returns 13. Production `_singleExit` returns 11 at both 12 and 13 shares. |
| CF-G | `supply=1000`, both reserves `50`, `amountOut=5` | Candidates 52 and 53 both forward to 3. Python only. |
| Shortcut | Swap input-with-fee `10,133`, output `10,000`, supply and reserves `1_000_000`, shares `10_000` | Pre-swap contribution sizing misses the post-swap requirement by **102 bp**. Python only. |
| CF-Q | `UniswapV4Quoter.quoteFromState` | `while` loop at lines 172–176 sizes the quote. A searched quote is not a closed form. |

The CF-B reserves are smaller than an 18-decimal activation minimum. The failure is still a real inverse failure of the production function. On one activated-scale book (`supply=1e15`, reserves `1e18`, 1% output), the same radical did bracket. That does not make it the external combined route.
