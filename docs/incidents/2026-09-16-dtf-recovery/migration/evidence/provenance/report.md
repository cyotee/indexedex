# Phase 01 provenance reconciliation

- Date: 2026-11-10.
- Status: read-only reconciliation of the frozen incident bundle. This file does not approve recipients, amounts, routes, or uploads.
- Runner: `scripts/recovery/dtf-migration/phase01/provenance/reconcile.mjs`
- Runner SHA-256: `98e5a00d7b3ab9b1eff93f54771ab019f78afb0f7c8929b194b5fa65e879f54c` (47860 bytes)
- Machine output: `docs/incidents/2026-09-16-dtf-recovery/migration/evidence/provenance/reconciliation.json`
- Output SHA-256: `874eb99734cb6f06a6c75982fbe9dcfc52f84e535c3666fb8d2f2f23b11f684f` (1626442 bytes)
- Schema: `dtf-migration-phase01-provenance-reconciliation/1`

No allocation was approved. `account-ledger.csv` was not treated as an upload. Held-exclusion lower bounds were not treated as proportional contribution attribution. No C0 quote was computed. No route was marked supported because an address exists. Frozen inputs were not rewritten.

## Accepted command

Working directory: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01`.

Binary: `/opt/homebrew/bin/bun`, version 1.4.2.

```text
bun scripts/recovery/dtf-migration/phase01/provenance/reconcile.mjs --input docs/incidents/2026-09-16-dtf-recovery --output docs/incidents/2026-09-16-dtf-recovery/migration/evidence/provenance/reconciliation.json
```

Result: exit 0. Stdout: `WROTE .../reconciliation.json bytes=1626442`.

The same command was run a second time. `cmp` of the two outputs was identical. Determinism: PASS.

Before those two runs, and again after them, SHA-256 was taken for every file under `docs/incidents/2026-09-16-dtf-recovery` except `migration/`, plus the six cited preincident source files S001-S006. The two hash lists matched (31 lines). Input integrity: PASS. No `.partial` output was left behind.

## What the runner does

It reads `sources.json` and `manifest.json`, hashes every declared file, and parses CSV quantities as canonical integer strings. A blank numeric cell is `UNKNOWN`. A non-canonical numeric token, including `1.5` and `00`, aborts with exit 2 and does not write a success file. Explicit `0` stays zero. Display decimals in the preincident sale files are ignored and are never summed.

Joins keep these identities apart:

- Weighted NFT `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` is a fixed-principal generation. Earlier CP NFT `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` is an LP-share lock. The same numeric token id is not one position.
- Source identity is chain plus collection plus token id. Purchase recipient and current owner are not that identity.
- Original contribution is direct DTF and observed WETH, separately. Native ETH is `UNKNOWN`. Routed intermediate DTF is not a second contribution.
- Weighted DETF, sDETF, and SY are 9-decimal. Earlier CP DETF and its receipt are 18-decimal. DTF, WETH, and TokenStaking weights are 18-decimal. Weights are not DETF units. sDETF must be replayed in gons; summing rebasing transfers is not a balance.
- SY shares are not a second claim on the wrapper's sDETF. TokenStaking weights and claim-vault SY are one remaining claim, not two.
- Principal, remaining principal, and held-exclusion lower bounds are not contribution quantities and are not awards.

## Coverage

All 15 source IDs S001-S015 were readable. Declared SHA-256 and byte counts matched the files on disk. Source fingerprint failures: 0.

The incident directory, excluding the new `migration/` tree, has 25 files. Every one is listed in source coverage, manifest coverage, or discovered-not-declared coverage. Missing from coverage: none.

`manifest.json` lists 21 files. Nineteen match. Two do not, and they were not rewritten:

| File | Declared bytes / SHA-256 | Observed bytes / SHA-256 |
| --- | --- | --- |
| `CUSTODY_AND_HARVEST.md` | 7357 / `0ddb0eb30523e26551dce653d3f3bfb2e439f7b0c83fe2c8c93aaf953d6f42cd` | 7920 / `ab837ca952449a6d9ac155f5cd641329134ed92c0b9a610007ad7cd9b33698d8` |
| `LOSS_AND_RECOVERY_LEDGER.md` | 15308 / `8564764d3d2140b25a9de361c49606c2e4d3d53cc404309ccc00bb955f572f07` | 15943 / `52758ad2bbfa4efce31668ba1079aff608a8c72798280512e0247a0fb1747a71` |

Those two rows are FAIL. The CSV and JSON evidence fingerprints still match. The stale manifest was not edited to hide the drift.

Cited context, hashed and not used as an allocation input:

- `../2026-09-16-dtf-pre-exploit/SNAPSHOT.md`
- `../2026-09-16-dtf-pre-exploit/DTF_SOLD.md`
- `../2026-09-16-dtf-pre-exploit/dtf-sold-to-detf-summary.json`
- `../2026-09-16-dtf-pre-exploit/holders.csv`, role `non_entitlement_census_not_joined`

S005 has 244 address rows. 211 have nonzero `dtf_wei_sold`, matching the provenance seller count. S006 categories are liquid 585, bond 27, donation 4, and tokenstaking migration 203. The migration rows are a collective input. Per-holder ancestry is `UNPROVEN`.

## Contribution joins

Weighted NFT joins: 43. Every inbound DTF/WETH transfer in the purchase transaction came from the recorded purchase recipient. S006 status: 27 matched, 14 absent because the purchase was WETH-only and preincident, 2 absent because IDs 44 and 45 are post-incident and outside S006. No S006 amount mismatch. No payer mismatch.

NFT 3, source `4663:0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e:3`:

- Direct DTF `362893857600000000000` at log 8.
- Direct WETH `999999000000000` at log 6.
- Native ETH `UNKNOWN`.
- Routed intermediate DTF `0`.
- Principal is not the contribution. C0 is `UNKNOWN`. Allocation approved: false. Route: `UNPROVEN`.

NFT 4 is WETH-only: DTF `0`, WETH `30000000000000000` at log 211.

Earlier CP joins: 16. S011 does not contain those purchase receipts, so independent replay is `ABSENT_UNPROVEN`. S009 still separates direct inputs from routed DTF.

- CP NFT 3: direct DTF `0`, direct WETH `2000000000000000000`, routed DTF `1778859964387451305574664`. The routed amount is not a second contribution.
- CP NFT 9: direct DTF `0`, direct WETH `100000000000000`, routed DTF `41454674363068691516`. Same rule.

Current owner is not the source identity. Observed differences: NFT 25 and 42 have the zero address and are not a second claim; NFT 26's cutoff owner differs from the purchase recipient. Transfers after the cutoff are `UNPROVEN`.

Payer rows and holder rows are different sets (244 payer rows, 342 position accounts, 173 address overlap). A payer total must not be added to an NFT join total. Bond DTF in S006 is already inside the sale file.

## Category coverage

Every required category has a row. `route_status` is `UNPROVEN` for all of them. An address or a frozen row is not support.

| Category | Rows | Provenance | Route |
| --- | ---: | --- | --- |
| weighted DETF, 9 decimals | 34 | observed units | UNPROVEN |
| earlier CP DETF, 18 decimals | 6 | observed units; acquisition unproved | UNPROVEN |
| weighted fixed-principal NFT | 43 | purchase joined | UNPROVEN |
| earlier CP NFT LP lock | 16 | S009 recorded; not fungible LP | UNPROVEN |
| weighted sDETF, gons required | 198 | observed units | UNPROVEN |
| earlier CP rebasing receipt, 18 decimals | 7 | latest-state observation, supply gap unresolved | UNPROVEN |
| weighted SY wrapper | 17 | observed shares, not a second backing claim | UNPROVEN |
| TokenStaking claim weights | 92 | observed weights, not an ERC-20 | UNPROVEN |
| claim-vault / related custody | 74 | related inventory rows, not a proved vault balance | UNPROVEN |
| underlying SE shares | 0 | absent, not proved absent on chain | UNPROVEN |
| fungible LP token | 0 | absent, distinct from the NFT LP lock, not proved absent | UNPROVEN |
| native ETH | 0 | not reconstructed | UNPROVEN |
| WETH | 27 transfer rows | partial inbound evidence only | UNPROVEN |

## Unknown values

Blank numeric encoding is `UNKNOWN`. The JSON contains 4752 unknown records plus a census. Material blanks:

- `account-ledger.csv` `V_eth`, `R_eth`, `E_eth`, and `H_eth`: 435 blanks each. Not zero.
- `account-ledger.csv` `new_detf_bond_allocation_raw`: 435 blanks. Not an award.
- `observed-recoveries.csv` `R_eth`: 69 blanks. Not zero, and not deducted.
- `positions.csv` `detf_equivalent_raw` for all 29 earlier CP rows: `UNKNOWN`. No invented common value.
- Earlier CP liquid and receipt acquisition fields that are blank: `UNKNOWN`.
- Native ETH, funded-snapshot C0, the earlier receipt supply gap, and descendant ownership after a claim or transfer: `UNKNOWN`.

Structural blanks are classified `NOT_APPLICABLE` rather than zero. NFT transfer rows leave `amount_raw` empty because they use `token_id`. Fungible transfer rows do the reverse. Non-bond S006 rows leave `bond_token_id` empty. Those census rows are in the JSON and were not coerced.

## Unresolved duplicates and descendants

Duplicate-key scan of positions, ledger, held exclusions, custody, recoveries, conversions, transfers, and both bond tables: zero duplicate keys.

Sixteen numeric token IDs appear in both NFT collections. Status: `DISAMBIGUATED_NOT_A_DUPLICATE`. A token-id-only join is unsafe. The overlapping IDs are in the JSON.

Unresolved descendant relationships:

- 7 post-incident bond claims, also present as `bond_to_sdetf` conversions. The sDETF output is a descendant representation, not a second credit. Later holders are `UNPROVEN`.
- 16 preincident claim conversions in S012. Same rule.
- 18 legacy-weight-to-SY conversions. Double credit with any remaining weight is unresolved.
- Stake and unstake conversions are representation changes, not external recoveries. Later proportional ancestry is `UNPROVEN`.
- SY backing and claim-vault SY must not be credited again beside the wrapper shares or the weights.
- Two addresses appear in both products and were not merged: `0x5f0a91bef93b0f947cd82ea39ec2939d6aec663a` and `0x73c121d572e065c8b6fa6acec6b40deffb62e1df`.
- No approved independent-allocation dataset exists. Paying the same contribution through an NFT, its claimed descendant, and an independent allocation is `UNRESOLVED_NO_APPROVED_INDEPENDENT_SET`.

## Historical diagnostics

These checks reproduce the frozen `reconciliation.json`. They are not awards and they are not proportional attribution.

| Check | Computed | Matches frozen file |
| --- | --- | --- |
| weighted position rows | 382 | yes |
| earlier position rows | 29 | yes |
| account rows | 435 | yes |
| nominal exposure | `2237832428068` | yes |
| NFT preincident gons | `208200941171774511655236409911455698947144975844` | yes |
| recovery rows | 69 | yes |
| recovery DTF sum | `59027441289824656686224552` | yes |
| issuable accounts | 0 | yes |
| held lower bound | `1674947599807` | yes |
| unresolved remainder | `562884828261` | yes |
| upfront credit | `0` | yes |

Look-through recomputation from raw units mismatched 0 weighted positions. Held lower bound plus unresolved remainder equals exposure. That partition is a historical diagnostic. It is not full proportional attribution of contribution history. `held_lower_bound_is_full_proportional_attribution` is false.

## Discovered gaps

All 41 gap IDs from the JSON:

- `account-ledger-upload`: FORBIDDEN. Do not upload the ledger.
- `descendant-double-credit`: `UNRESOLVED_NO_APPROVED_INDEPENDENT_SET`.
- `earlier-receipt-3` through `earlier-receipt-18`, except there is no 1 or 2: UNPROVEN. Older CP purchase receipts are not in S011.
- `fingerprint-CUSTODY_AND_HARVEST.md`: FAIL.
- `fingerprint-LOSS_AND_RECOVERY_LEDGER.md`: FAIL.
- `funded-snapshot-quote`: UNKNOWN. No post-funding quote book, so C0 is not computed.
- `fungible-proportional-ancestry`: UNPROVEN.
- `held-lower-bound`: NOT_ATTRIBUTION.
- `provenance-earlier_cp_receipt`: OBSERVED_LATEST_STATE. Exception C2 remains unresolved and the gap is not allocatable.
- `provenance-fungible_lp_token`: ABSENT_NOT_PROVED.
- `provenance-native_eth`: ABSENT_NOT_PROVED.
- `provenance-underlying_se_shares`: ABSENT_NOT_PROVED.
- `provenance-weth`: PARTIAL_INBOUND_EVIDENCE. The recorded note limits WETH coverage; the CSV's highest row is not proof of the query boundary.
- `route-claim_vault_sy_custody`, `route-earlier_cp_detf`, `route-earlier_cp_nft_lp_lock`, `route-earlier_cp_receipt`, `route-fungible_lp_token`, `route-native_eth`, `route-tokenstaking_claim`, `route-underlying_se_shares`, `route-weighted_detf`, `route-weighted_nft`, `route-weighted_sdetf`, `route-weighted_sy`, `route-weth`: all UNPROVEN.

E1 and E2 are not closed. This unit does not finalize ABI or storage.

## Fixture probes

Owned copies lived only under the lane run root. They were not written into the incident bundle.

Probe A, malformed float. Exit 2. Output absent.

```text
/opt/homebrew/bin/bun scripts/recovery/dtf-migration/phase01/provenance/reconcile.mjs --input /var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/phase01.JHBsOQ/fixtures/malformed-float --output /var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/phase01.JHBsOQ/fixtures/malformed-float/out.json
```

```text
MALFORMED_QUANTITY file=bad.csv locator=bad.csv:2:quantity_raw field=quantity_raw value="1.5"; refusing to substitute zero
```

Probe B, non-canonical `00`. Exit 2. Output absent. The runner did not normalize it to zero.

```text
MALFORMED_QUANTITY file=bad.csv locator=bad.csv:2:quantity_raw field=quantity_raw value="00"; refusing to substitute zero
```

Probe C, float in an unclassified column named `mystery`. Exit 2. Output absent.

```text
MALFORMED_QUANTITY file=bad.csv locator=bad.csv:2:mystery field=mystery value="1.5"; refusing to substitute zero
```

Probe D, blank beside an explicit zero. Exit 0. Output present. The blank row is `UNKNOWN`, not `0`.

```text
BLANK_ROWS=[{"field":"quantity_raw","file":"sample.csv","key":"sample.csv:row:1","line":2,"reason":"blank_numeric_not_zero","value":"UNKNOWN"}]
BLANK_PROBE=PASS
```

## RPC and compile

No Forge build was run. None is required for this read-only unit.

Read-only chain probe, before execution:

```text
cast chain-id --rpc-url robinhood_mainnet_alchemy
```

Exit 1. Stderr, with no secret printed because none was present:

```text
Error: environment variable `ALCHEMY_KEY` not found
```

`ALCHEMY_KEY` was unset in this process. No `.env` file was present at the worktree or the main checkout. The Foundry alias exists and was not printed. Code presence was not read. Route status stays `UNPROVEN` / FAIL for the probe. An address in the frozen bundle is still not support.

This lane does not depend on an outside fetch. An observed `ECONNRESET` on an optional outside fetch is recorded here and was not retried. Completed local inputs were not re-read. The accepted `reconciliation.json` field mapping is unchanged.

## Cleanup receipt

Target: `/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/phase01.JHBsOQ`.

- Process scan for that run root and for `reconcile.mjs`: `NO_MATCHING_PROCESSES`.
- Ports: none bound by this lane.
- `RUN_ROOT_BEFORE=present`.
- `rm -rf` of that directory only.
- Read-back: `ls` returned `No such file or directory`. `RUN_ROOT_AFTER=absent`.
- `reconciliation.json.partial`: absent.
- Accepted `reconciliation.json`: still present.

## Risks

- The two markdown fingerprint failures mean `manifest.json` is stale for those files. Do not refresh it by editing frozen inputs in this unit.
- Fungible, wrapper, and claim contribution ancestry is not proved. Do not configure from held lower bounds, ledger historical zeros, or gross payer columns.
- Claimed and wrapped descendants can double-pay the same original contribution if a later loader treats them as new purchases.
- Earlier CP receipt supply discrepancy stays unresolved and must not be assigned to users.
- WETH coverage and native ETH coverage are incomplete. Unknown is not zero.
- No funded snapshot is in this bundle, so original-credit quoting cannot start from this JSON.
- No live route was demonstrated. E1 and E2 remain open.
- This report does not authorize deployment, transfer, or a public transaction.

## DoneClaim

- changed_files:
  - `scripts/recovery/dtf-migration/phase01/provenance/reconcile.mjs` (new runner)
  - `docs/incidents/2026-09-16-dtf-recovery/migration/evidence/provenance/reconciliation.json` (generated)
  - `docs/incidents/2026-09-16-dtf-recovery/migration/evidence/provenance/report.md` (this file)
- tests_and_probes:
  - Accepted reconciler invocation, exit 0, 1626442 bytes, SHA-256 `874eb99734cb6f06a6c75982fbe9dcfc52f84e535c3666fb8d2f2f23b11f684f`.
  - Second identical invocation, `cmp` PASS.
  - Input SHA-256 list before and after, PASS, 31 lines, migration tree excluded.
  - Probe A `1.5`: exit 2, no output, refusal to substitute zero.
  - Probe B `00`: exit 2, no output, not normalized to zero.
  - Probe C unclassified `1.5`: exit 2, no output.
  - Probe D blank quantity: exit 0, value `UNKNOWN`.
  - Production asserts: 435 `UNKNOWN` rows for each of `V_eth`, `R_eth`, `E_eth`, `H_eth`; 69 `UNKNOWN` recovery `R_eth` rows; 0 source fingerprint failures.
  - `cast chain-id --rpc-url robinhood_mainnet_alchemy`: exit 1, `ALCHEMY_KEY` not found. Routes remain UNPROVEN.
  - Optional outside fetch `ECONNRESET`: recorded, not retried, not a local-input failure. JSON field mapping unchanged.
  - No Forge compile. Not required for this unit.
- evidence_paths:
  - `docs/incidents/2026-09-16-dtf-recovery/migration/evidence/provenance/reconciliation.json`
  - `docs/incidents/2026-09-16-dtf-recovery/migration/evidence/provenance/report.md`
- cleanup_receipts:
  - Run root `/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/phase01.JHBsOQ` removed.
  - Read-back `ls` confirmed absence.
  - No matching processes. No lane ports. No partial output file.
- risks:
  - Two frozen markdown fingerprints no longer match `manifest.json`.
  - Fungible ancestry, descendant ownership, native ETH, SE shares, and fungible LP coverage are unproved.
  - Live route closure and the funded-snapshot quote were not established. An optional outside `ECONNRESET` does not change that.
  - Nothing in this output is an approved allocation.
