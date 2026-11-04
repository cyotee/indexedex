# Grok model recheck

Rechecked 2026-10-26 by executing `members/grok/model.py` `run()`. This is not acceptance of every prose claim in the response.

| Row | Closed | Attacker target delta | Opposing delta |
| --- | --- | --- | --- |
| rule1 control, no JIT | yes | -1 | 0 |
| rule1 JIT, fee 3000 | yes | 1179070738173910 | 0 |
| rule2 swap 1 wei, 1%, 49%, 50%, 51%, then JIT | yes | all positive, 1045645242896000 through 1179070738173909 | 0 |
| quote mint then slice exit, no push | yes | 1103316364600005 | 0 |
| quote mint then slice exit, with push | yes | 2231288269068756 | 0 |
| rule4 proportional round trip | yes | 0 | 0 |
| as-written TWAP backfill with push | yes | 1970597147462162 | 0 |
| idealized TWAP inside the same transaction | yes | -573794679209779 | 0 |
| idealized TWAP after the window, same push ledger | yes | 1970597147462162 | 0 |

`self_fill_note` reports attacker target delta `14352624773100403` and opposing delta 0, with `pool_dust` of 2 and 2. That is not an exact zero-conservation row. It is not used as one.

`rule3_no_push_50pct_mark_all` is not closed. Its target delta is -1000. It is not a profit row.
