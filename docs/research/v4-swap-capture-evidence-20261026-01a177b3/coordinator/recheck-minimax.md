# MiniMax model recheck

Rechecked 2026-10-26 by executing `members/minimax/model.py`. Token0 is target in that file. This is not acceptance of every table row in the response.

`main()` printed Rule 3 profit `+2.011307814` on a 100e18 deposit. The exact return is `182670959878875300000000000000000/90821980886249`. Attacker opposing ends at zero. Target and opposing each close if the ending target wallet is the payout, not the profit. The file's summed-token check is not that split.

The response table's JIT quote profits `+25.472084e18` and `+30.508645e18` are not the numbers `main()` printed for its depth-100 control (`+24.255709512e18`). Those table rows were not re-executed here.

The completion text's incumbent-loss split of 2.379517 was not rechecked as a separate identity. The rechecked object is the attacker's closed target profit.

Same function, fee 0.3%, deposit 100e18, book 1000e18, split-token conservation closed on every row:

| Vault liquidity share | Swap half of deposit | Swap the whole deposit |
| --- | --- | --- |
| 0 | -0.358973 | +2.011308 |
| 1/4 | -18.458912 | -16.494259 |
| 1/2 | -30.995310 | -29.317725 |
| 3/4 | -40.191064 | -38.727348 |
| 1 | -47.224303 | -45.926090 |

In this file, the positive row is the idle-opposing book, not the vault-as-LP book. That is a different machine from the active-interval ledger in `research/EXECUTED.md`, which was positive when the vault owned the interval. Both results stay. Neither is discarded because the other has the opposite sign.
