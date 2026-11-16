# Task 9 reference failures

Date: 2026-11-15.

## Phrase inspection

Command: `tool.grep({pattern:"11 selectors|12 selectors|no price setter|captureMigrationSnapshot|TODO|TBD", path:["docs/incidents/2026-09-16-dtf-recovery/migration/surrender-spec.md","docs/incidents/2026-09-16-dtf-recovery/migration/package-evidence.md"]})`.

Result: no matches. No stale selector-count phrase and no placeholder token required inspection.

## Negative hash row

| Field | Value |
| --- | --- |
| Confirmed path | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-4/proxy-census.json` |
| Confirmed SHA-256 | `5f8816dbce2b2442ba34de5bb6089bfef0cb9afe0b58ae6e045fcd06d21b9a18` |
| Temp path | `docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-9/negative/proxy-census.one-byte-off.json` |
| Temp SHA-256 | `019496421514ea3bff4b26dbe12a58bf658939423a037b66747d39fe5788fadb` |
| Checker result | mismatch reported |
| Confirmed hash after the temp write | `5f8816dbce2b2442ba34de5bb6089bfef0cb9afe0b58ae6e045fcd06d21b9a18` |
| Original unchanged | true |

The failure path is detected. The package record cites the confirmed digest, not the temp digest.
