# Resolution ledger — v4-adaptation-r1

Frozen draft: `coordinator/draft.md`. Originals remain unchanged. Final revisions are coordinator revisions in REPORT.md, not another member-approved draft. All four requested advisories have settled.

## Original-recommendation synthesis

- Implementation vehicle: all four originals select the existing local full-range PairToken SE family, not wholesale copying an external vault.
- External ranking: Astra/MiniMax favor Weir as the strategy shape; Grok/Kimi favor lpTOKEN as external accounting/conversion reference. Preserve that distinction rather than call it unanimous selection of one source tree.
- The Pool: third as overall foundation. MiniMax separately favors its post-conversion net-contribution idea as a donor; this does not authorize scalar NAV issuance or change the local attributable per-currency equation.
- Do not adopt MiniMax's categorical PositionManager exclusion: canonical without-unlock routing exists. Direct custody is simpler, not exclusively legal.
- Do not adopt MiniMax's cross-contract transient-invisibility claim, per-currency rather than per-address/currency delta-count explanation, queued-redemption default, or claim that rate limits prove absence of arbitrage.
- Do not adopt Grok's original withholding of the user's Rate Provider goal. He expressly withdrew that recommendation in advisory.
- No silent change to current SY accounting, issuance, fees, dead shares, native support, exact-output policy, hookless backing, or atomic supported domain. No unapproved general simulator, oracle market, queue or new redemption restriction.

## Grok — SUPPORT WITH CORRECTIONS

1. **Adopt.** Put the normalized one-whole-share executable Rate Provider first and retain it as the requested semantics in this assessment. NAV/common-reference adapters remain alternatives proposed by some members, not accepted replacements. Do not demote the user's goal through “preferred alternative” wording. Nonlinearity prevents treating the reference as a guaranteed arbitrary-size payout; it does not forbid rate-aware pools.
2. **Adopt.** Preserve MiniMax's separate donor ranking for The Pool's post-conversion issuance intuition while retaining the local two-currency attributable-credit rule.
3. **Preserve verified corrections.** PositionManager without-unlock execution is possible; caller-specific deltas and shared outer zero-count boundary remain distinct; transient data is accessible through its owner's accessor during the same transaction.
4. Grok's earlier no-provider recommendation withdrawn. His source/settlement and strict one-token recommendations retained. No new round or implementation authorized.

## Kimi — SUPPORT

- No material correction. Preserves same-manager entry, direct-custody preference rather than impossibility, strict conversion, local ownership, normalized executable quote and explicit-only alternative rate policy.
- Kimi's accounting-rate preference remains an alternative, not approval to change the requested getRate. Keep valuation/reference and exact execution distinct.

## MiniMax — SUPPORT WITH CORRECTIONS

- C1: **Adopt citation refinement.** Add the concrete TransientStateLibrary `isUnlocked`/`currencyDelta` -> manager.exttload accessor, with EIP-1153 as mechanism and local `_start` as observed use. The unlocked flag identifies no locker. Coordinator read the complete local helper.
- C2: **Adopt precision.** Separate Astra's adapter preference, Kimi's accounting-rate choice, Grok's original deferral and advisory withdrawal, and MiniMax's withdrawn restrictions. External-code-only versus strategy ranking remains explicit.
- C3: **Partially adopt.** Credit The Pool's intention to charge post-conversion net contribution rather than gross input. Do not claim its actual scalar NAV difference proves caller-attributable reserve growth under self-impact. lpTOKEN contributes portfolio funding discipline, not an approved replacement issuance formula. Local per-currency rule remains controlling.
- C4: **Clarify, do not remove a genuine burden.** PositionManager is legally composable with without-unlock entry, but NFT/payer/approval/settlement layers still increase adaptation scope relative to direct custody. An external swap adapter does not inherently require an independent market; current venue/wiring is unverified, not evidence of impossibility. ERC4626 also does not inherently promise zero-slippage exit; only current selected methods/policies are compared.
- C5: **Adopt.** MiniMax withdrew queued/rate-restricted redemption as a recommendation. Record that withdrawal rather than continue to present it as a council-supported default.
- C6: **Not adopted.** Making the vault absorb execution spread changes pro-rata economics and does not prove no arbitrage; it can move losses to other holders. No new subsidy, guaranteed redemption price or liquidity-bound option is introduced to manufacture safety. The requested atomic amount-specific path already keeps the goal without a queue.
- Original errors remain preserved and explicitly corrected: NFT impossibility and same-transaction transient invisibility were false, not merely differences of preference.

## Astra — SUPPORT WITH CORRECTIONS

- C1: **Adopt.** Preserve MiniMax's separate second-place donor preference for The Pool, while the coordinator ranks it third overall. Common implementation agreement does not mean every external donor ranking is identical.
- C2: **Adopt.** Qualify the dimensional warning: with current 18-decimal shares and 18-decimal target, raw accounting and normalized accounting have matching numeric scale; six-decimal target differs. Neither numeric case makes accounting NAV equal to executable proceeds or proves invariant safety. Preserve precision rather than amplify rounding already present in a displayed rate.
- C3: **Adopt as alternative-policy clarification.** Actual current attributed inventory marked at a historical reference differs from a hypothetical position computed at the historical price. An optional accounting adapter must name which it does; it remains unapproved and not a silent getRate/SY replacement.
- Preserve explicit approved conditional maintenance in the common engine; no unconditional collect-only hook shortcut or queue.
- Concrete accessor references, PositionManager without-unlock, caller-specific delta closure, post-commit reads during global unlock, strict single-token allocation and categorized ownership are retained.

## Final disposition and coverage

- All four originals and advisories preserved. Three advisories SUPPORT WITH CORRECTIONS, Kimi SUPPORT. No missing participant, second round, or claim of re-approval of final text.
- Final recommendation: Weir/local full-range strategy; current local family as implementation vehicle; lpTOKEN strongest external inventory/full-consumption reference. The Pool's useful donor idea does not replace local issuance.
- Requested executable, normalized one-whole-share Rate Provider retained. No new NAV semantics, queue, rate-limited redemption, subsidy, second market, oracle hook, or forbidden exact-output implementation is adopted.
- User-facing recommendation includes the required interface/accounting/hook/rate adaptations, distinction between rate reference and actual amount-specific settlement, and unresolved pricing/observation/authorization decisions.
- Static source/document checks only. No product code/PRD edits, tests/builds, deployments or measured composed-transaction proof.
