# Criteria ledger

Snapshot: IndexedEx working tree `5709cb3507a9df72b11ec476d27b79ef88696c3a` plus uncommitted IndexedEx edits recorded in `REVIEW_MANIFEST.md`.

Baseline claim: 108 nested IDs at `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:13`. Observed inventory from that plan's explicit `R<number>.<number>` labels: 108. No rows added or dropped to force the count. This file does not assert code compliance.

Field contract: applicability, review state, inspection result, execution evidence, and readiness effect stay independent. Preparation values below are not inspection results.

| Field | Preparation value |
| --- | --- |
| `owner_and_review_state` | Assigned lane, `UNINSPECTED` until that lane's original is collected |
| `inspection_result` | `NOT_ASSESSED` |
| `execution_evidence` | `MISSING` / supplied outcome `UNKNOWN`, unless a later row cites a supplied artifact |
| `readiness_effect` | `UNDETERMINED` |
| `confidence_and_limits` | Not assessed |

Detailed control text lives at the cited plan line. A one-line label is not a substitute.

## Original IDs

| criterion_id | plan line | primary owner | applicability note from documents only | review state | inspection |
| --- | --- | --- | --- | --- | --- |
| R1.1 | 461 | C01 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R1.2 | 462 | C01 | APPLICABLE; `UNSUPPORTED_USE` reserved for D12 | UNINSPECTED | NOT_ASSESSED |
| R1.3 | 463 | C01 | APPLICABLE | UNINSPECTED | NOT_ASSESSED |
| R1.4 | 464 | C01 | APPLICABLE | UNINSPECTED | NOT_ASSESSED |
| R1.5 | 465 | C01 | APPLICABLE | UNINSPECTED | NOT_ASSESSED |
| R1.6 | 466 | C01 | APPLICABLE | UNINSPECTED | NOT_ASSESSED |
| R2.1 | 469 | C13 | Red-run-on-preserved-source portion not pre-judged; Stage-1 plan :39 says historical logs stay historical | UNINSPECTED | NOT_ASSESSED |
| R2.2 | 470 | C13 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R2.3 | 471 | C13 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R2.4 | 472 | C13 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R2.5 | 473 | C13 | D32 false-flag boundary must be read, not assumed | UNINSPECTED | NOT_ASSESSED |
| R2.6 | 474 | C13 | Standalone Balancer adapter exception is partial, not a deleted ID | UNINSPECTED | NOT_ASSESSED |
| R3.1 | 477 | C02 | V3 primary; C03/C04/C05 must not inherit this row | UNINSPECTED | NOT_ASSESSED |
| R3.2 | 478 | C02 | Same split | UNINSPECTED | NOT_ASSESSED |
| R3.3 | 479 | C02 | Same split | UNINSPECTED | NOT_ASSESSED |
| R3.4 | 480 | C02 | Same split | UNINSPECTED | NOT_ASSESSED |
| R3.5 | 481 | C02 | D28 may amend exact-in equality; confirm from plan :118 before closing | UNINSPECTED | NOT_ASSESSED |
| R3.6 | 482 | C02 | Do not reconstruct stored-total cases on vaults that no longer use them | UNINSPECTED | NOT_ASSESSED |
| R3.7 | 483 | C02 | Callback/lock coverage | UNINSPECTED | NOT_ASSESSED |
| R4.1 | 486 | C01 | Documentary inventory only; no fresh chain read | UNINSPECTED | NOT_ASSESSED |
| R4.2 | 487 | C01 | Same | UNINSPECTED | NOT_ASSESSED |
| R4.3 | 488 | C01 | Historical fork evidence only; do not rerun | UNINSPECTED | NOT_ASSESSED |
| R4.4 | 489 | C01 | Selector derivation is source inspection, not a chain call | UNINSPECTED | NOT_ASSESSED |
| R4.5 | 490 | C01 | Missing fork evidence stays an evidence gap | UNINSPECTED | NOT_ASSESSED |
| R4.6 | 491 | C01 | Immutable instances are not upgraded by source review | UNINSPECTED | NOT_ASSESSED |
| R5.1 | 507 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R5.2 | 508 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R5.3 | 509 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R5.4 | 510 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R5.5 | 511 | C06 | Do not misclassify custody as 001-M | UNINSPECTED | NOT_ASSESSED |
| R5.6 | 512 | C06 | Live exposure is evidence, not a fix | UNINSPECTED | NOT_ASSESSED |
| R6.1 | 515 | C09 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R6.2 | 516 | C09 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R6.3 | 517 | C09 | D12 consumption is residual, not automatic defect | UNINSPECTED | NOT_ASSESSED |
| R6.4 | 518 | C09 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R6.5 | 519 | C09 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R6.6 | 520 | C09 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R6.7 | 521 | C09 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R6.8 | 522 | C09 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R6.9 | 523 | C09 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R6.10 | 524 | C09 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R7.1 | 527 | C07 | ERC-4626 and Morpho stay separate | UNINSPECTED | NOT_ASSESSED |
| R7.2 | 528 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R7.3 | 529 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R7.4 | 530 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R7.5 | 531 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R7.6 | 532 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R8.1 | 535 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R8.2 | 536 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R8.3 | 537 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R8.4 | 538 | C07 | Includes Uni V2/Camelot exact-out only as consumers; C08 owns those packages | UNINSPECTED | NOT_ASSESSED |
| R8.5 | 539 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R9.1 | 542 | C06 | Helper inventory is not consumer closure | UNINSPECTED | NOT_ASSESSED |
| R9.2 | 543 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R9.3 | 544 | C06 | D28 sufficiency rule; confirm plan :118 | UNINSPECTED | NOT_ASSESSED |
| R9.4 | 545 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R9.5 | 546 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R9.6 | 547 | C06 | Consumer routing; family lanes cooperate | UNINSPECTED | NOT_ASSESSED |
| R9.7 | 548 | C06 | Helper pass does not close findings | UNINSPECTED | NOT_ASSESSED |
| R10.1 | 551 | C09 | Retraction: do not invent a missing beforeSwap guard | UNINSPECTED | NOT_ASSESSED |
| R10.2 | 552 | C09 | Weighted dust retraction | UNINSPECTED | NOT_ASSESSED |
| R10.3 | 553 | C10 | Denominator unresolved; do not adopt 195/1/7 or 165/3/7 | UNINSPECTED | NOT_ASSESSED |
| R10.4 | 554 | C01 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R10.5 | 555 | C02 | C03/C04/C05/C09 must give their own residual conclusions | UNINSPECTED | NOT_ASSESSED |
| R10.6 | 556 | C11 | D41 | UNINSPECTED | NOT_ASSESSED |
| R10.7 | 557 | C11 | D48 | UNINSPECTED | NOT_ASSESSED |
| R10.8 | 558 | C11 | D49 staticcall exception is narrow | UNINSPECTED | NOT_ASSESSED |
| R11.1 | 561 | C13 | Execution evidence likely MISSING; that is not unread source | UNINSPECTED | NOT_ASSESSED |
| R11.2 | 562 | C13 | Same | UNINSPECTED | NOT_ASSESSED |
| R11.3 | 563 | C13 | Same | UNINSPECTED | NOT_ASSESSED |
| R11.4 | 564 | C13 | D12 consumption is permitted where locked | UNINSPECTED | NOT_ASSESSED |
| R11.5 | 565 | C13 | Same | UNINSPECTED | NOT_ASSESSED |
| R11.6 | 566 | C13 | Historical counts are not closure | UNINSPECTED | NOT_ASSESSED |
| R12.1 | 569 | C13 | Supplied Stage-1 note is not a full release run | UNINSPECTED | NOT_ASSESSED |
| R12.2 | 570 | C13 | Later selector rulings may amend unchanged-selector text | UNINSPECTED | NOT_ASSESSED |
| R12.3 | 571 | C13 | Do not inherit 34909 passes | UNINSPECTED | NOT_ASSESSED |
| R12.4 | 572 | C13 | 24576-byte limit; Ext split is an authorized path | UNINSPECTED | NOT_ASSESSED |
| R12.5 | 573 | C13 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R12.6 | 574 | C13 | No migration claim | UNINSPECTED | NOT_ASSESSED |
| R13.1 | 577 | C06 | D32 rejects stay rejects | UNINSPECTED | NOT_ASSESSED |
| R13.2 | 578 | C06 | D12 residual is not a defect label | UNINSPECTED | NOT_ASSESSED |
| R13.3 | 579 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R13.4 | 580 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R13.5 | 581 | C06 | Family lanes cooperate | UNINSPECTED | NOT_ASSESSED |
| R13.6 | 582 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R13.7 | 583 | C06 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R13.8 | 584 | C01 | Documentation mapping | UNINSPECTED | NOT_ASSESSED |
| R14.1 | 587 | C08 | Zero-leftover families must show zero, not invent a case | UNINSPECTED | NOT_ASSESSED |
| R14.2 | 588 | C08 | Native-BPT excluded from this issuance rule; C11 owns that boundary | UNINSPECTED | NOT_ASSESSED |
| R14.3 | 592 | C08 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.4 | 593 | C08 | Lido sleeve behavior is not rewritten to match Rocket/EtherFi | UNINSPECTED | NOT_ASSESSED |
| R14.5 | 611 | C07 | Stata | UNINSPECTED | NOT_ASSESSED |
| R14.6 | 613 | C07 | Aave loop | UNINSPECTED | NOT_ASSESSED |
| R14.7 | 614 | C07 | Aave loop | UNINSPECTED | NOT_ASSESSED |
| R14.8 | 616 | C11 | Native-BPT | UNINSPECTED | NOT_ASSESSED |
| R14.9 | 617 | C11 | D49 exception only | UNINSPECTED | NOT_ASSESSED |
| R14.10 | 618 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.11 | 619 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.12 | 620 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.13 | 621 | C07 | Shared receipt adapter | UNINSPECTED | NOT_ASSESSED |
| R14.14 | 622 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.15 | 623 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.16 | 624 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.17 | 625 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.18 | 626 | C07 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.19 | 627 | C08 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.20 | 628 | C08 | APPLICABLE pending inspection | UNINSPECTED | NOT_ASSESSED |
| R14.21 | 630 | C07 | D46 fixtures | UNINSPECTED | NOT_ASSESSED |

Count check: R1 6, R2 6, R3 7, R4 6, R5 6, R6 10, R7 6, R8 5, R9 7, R10 8, R11 6, R12 6, R13 8, R14 21. Sum 108.

## Supplemental rows

These do not change the 108 denominator.

| criterion_id | authority | primary owner | review state | inspection |
| --- | --- | --- | --- | --- |
| S2-ADD-001 | Stage-1 REQ-01, OD-08 | C12 | UNINSPECTED | NOT_ASSESSED |
| S2-ADD-002 | Stage-1 REQ-02, OD-08 | C12 | UNINSPECTED | NOT_ASSESSED |
| S2-ADD-003 | Stage-1 REQ-03 | C06 | UNINSPECTED | NOT_ASSESSED |
| S2-ADD-004 | Stage-1 REQ-04 | C10 | UNINSPECTED | NOT_ASSESSED |
| S2-ADD-005 | Stage-1 REQ-05, four vault identities | C02, C03, C04, C05 each own their test | UNINSPECTED | NOT_ASSESSED |
| S2-ADD-006 | Stage-1 REQ-06, OD-03 | C07 | UNINSPECTED | NOT_ASSESSED |
| S2-ADD-007 | Stage-1 REQ-07, OD-02 | C11 | UNINSPECTED | NOT_ASSESSED |
| S2-ADD-008 | Stage-1 REQ-08 | C01 | UNINSPECTED | NOT_ASSESSED |
| S2-ADD-009 | Wings O1–O7/A3, own accounting | C05 | UNINSPECTED | NOT_ASSESSED |

Wings must not inherit FullSpread donation or residual accounting.
