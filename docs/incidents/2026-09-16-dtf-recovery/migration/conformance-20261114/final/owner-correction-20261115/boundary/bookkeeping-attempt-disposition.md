# Bookkeeping attempt dispositions

The original `delivery/` receipt is immutable and reports exit 1 with 343
messages: two messages for each of 166 symlinks, two checks for each of four
retained-byte divergences, and three generated-record ordering failures.
Those three files were listed before they existed. This was a boundary-input
construction error, not a new product defect or an absent lifecycle proof.

The input generator then had a recorded embedded-newline syntax failure at
`commands/correct-input/`, exit 1. It wrote no replacement inventory. The exact
command and stderr are retained. `commands/correct-input-fixed/` records the
successful serialization correction, exit 0.

The final delivery input refreshes only this task's actual owned bookkeeping
files and declares only audit files that exist when delivery starts. It does
not change any retained-source row, external task source, assertion, runtime
evidence, old source-qualified record, symlink or product acceptance criterion.
The input refresh and corrected delivery commands have separate exact receipts.

`delivery-corrected/delivery.json` and `commands/delivery-corrected/` contain the
current authentic strict-recorder result. `boundary-result-corrected.json` is
the current summary. The earlier `boundary-result.json`, delivery receipt and
inventory remain historical; `inventory-before-input-correction.json` preserves
the first published baseline.

The current `inventory.json` is the last published real baseline, with its
actual recorder parent bound by raw SHA-256. It includes immutable command
outputs created after the recorder scan and applies the self-reference exception
only to itself and the final boundary DoneClaim. This correction is offline
bookkeeping, not a reopened acceptance run. All remaining strict-recorder
failures remain failures.
