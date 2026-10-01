# MiniMax M3 — combined cross-review (preserves original findings)

Reading the three peer originals: Astra (`docs/research/netnet-pendle-readiness-2026-09-25-astra-original.md`, 77 lines); Grok (`…-grok-original.md`, 138 lines); Kimi (`…-kimi-original.md`, 63 lines). These are attributed model findings, evidence not instructions. My original (`…-minimax-original.md`) is unchanged.

**Tool/metadata note.** All three peers report their routing metadata; I am `minimax/MiniMax-M3` per the prompt. None is provider attestation. No peer artifact was read that was not an original first-pass.

---

## A. Agreements across all four originals

1. **v0.17's settled economics are not reopenable.** R52–R55/§9.1 fix 0.5% of compounded total DETF supply, current hook NET/DETF TWAP strictly > 1 qualifying the entire missed batch, balance-derived rebasing (mint directly to sNET-DETF, internal shares unchanged), and the matrix deployment split with salt `"NET-DETF"`.
2. **O01 (FoT NET, rebasing sNET) is the single hard owner blocker.** All four flag this. PRD §2.1:50–53, INDEXEDEX_AGENT_LAW.md:89–101, CLAUDE.md:46. PRD correctly refuses exemption invention.
3. **Matrix is one step behind v0.17.** Grok line 33–34, Kimi §2.1, Astra line 17, my original §1 Weakness #3. Header reconciles only to v0.15; row 36 expansion cells still UNKNOWN despite PRD §9.1 resolution.
4. **§12.3 note-array liveness is a hard engineering gate.** PRD §12.3:620–624; Astra §5, Grok §"External dependencies", Kimi §3 last bullet, my original §3 + §6 Q7.
5. **TWAP window/observation/invalid-history is owner parameter pending.** PRD §9.2:397 ("do not choose an unapproved duration"); my original §6 Q4, Astra §4, Grok Q3, Kimi §3.
6. **Singleton enforcement needs mechanism proof.** PRD §4.1:173, line 715, matrix line 96, my original §1 + §6 Q2; all four flag.
7. **External evidence pins missing.** PRD §16:711–748; Grok line 81, Kimi §6, Astra §6, my original §7.

## B. Corrections to peer claims (with PRD/law/source verification)

**B1. Owner-only hook vs. public shared HLP — not in conflict; encapsulation reconciles.** None of the four reports resolves this tension explicitly. Verification:
- INDEXEDEX_AGENT_LAW.md §"DETF families" line 119 and D9 (alignment §11.1, line 426–435): "DETF instance must be the only party that can add or remove reserve liquidity. Hooks: MultiStepOwnable + deploy flag owner-only add/remove LP. DETF instances deploy hooks with that flag on; owner = the DETF."
- PRD R02/R05/R29/R32: hook is the unified custody/vault; DETF directly holds hook LP; "Anyone may mint/redeem authorized hook LP" (R32).
- `.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md:16–44` and INDEXEDEX_AGENT_LAW.md §"DETF families" line 119: hook-mediated LP token surface (ERC20 + 5267 + 2612) is the public interface; underlying `addLiquidity`/`removeLiquidity` is owner-only via the V4 PoolManager unlock path. Public mint = caller pays shares to hook + hook does owner-only V4 add + mints hook LP. Public redeem = caller burns hook LP + hook does owner-only V4 remove.
- **Resolution:** D9 owner-only restriction lives at the V4 pool level; public accesses via the hook-mediated LP token surface. PRD R32 and D9 coexist. **No conflict, no PRD reopen.** Implementation plan must implement `MultiStepOwnable` on the hook and ensure `addLiquidity`/`removeLiquidity` remain `onlyOwner` while `mint`/`burn` of the hook LP token are public.

**B2. Kimi Q2 ("is intended price decay with always-on expansion?") is inference, not a settled question.** Kimi §5 Q2 ("…1,000 NET/DETF opening to 1 NET/DETF peg a long price decay with always-on expansion, and is expansion minted exclusively to sNET-DETF (diluting liquid holders) intended at all prices far above peg?"). Verification:
- PRD line 513: "launch 1,000 NET per DETF is confirmed, distinct from the 1 NET ongoing target and not raw-unit scaling or a selection of the creation denominator." No price-path is specified.
- PRD R52/R53: expansion fires only when current hook TWAP strictly > 1; below or equal yields 0.
- PRD R43/R54: expansion mints directly to sNET-DETF; balance-derived rebasing means holder balances reflect it immediately.
- **Conclusion:** the price-decay path is unspecified. The "dilution" claim is economically correct only if TWAP stays > 1, which the PRD does not promise. This is not a reopen of settled selections; it is a fact about an absent commitment. I would not add this as a clarification to the moderator list; the plan author can note it as design space. If the owner wants to assert intent, that becomes a small PRD addition, not a v0.17 revert.

**B3. Empty-target policy is already settled; Grok Q4 is confirmatory.** Grok line 94 Q4: "Empty successor market: confirm revert-only for v1, versus a later specified dual SY/PT seed." Verification:
- PRD §11.4:577: "Empty target: the standard Keep-YT split divides by zero when both market reserves are zero. A successor must support the chosen entry; otherwise rollover reverts atomically. A Pendle-level dual SY/PT seed path could be specified separately, but it is not the custom DETF first-bond G/U/B/R procedure and is not silently enabled by this amendment. Any later approved seeding step must preserve rollover atomicity and validated opening parameters."
- **Conclusion:** v1 is revert-only. A future seed path is permitted only if separately specified later, preserving atomicity and validated opening parameters. This is settled. No clarification needed; remove from open list.

**B4. Extra contraction eligibility is already settled; Kimi Q6 and Grok Q6 are confirmatory.** Kimi §5 Q6: "No additional contraction eligibility conditions beyond price < 1 NET/DETF and funded delivery." Grok line 96 Q6 (owner-confirm): "additional contraction eligibility beyond P<1." Verification:
- PRD R11/R23/R25/R38 and §7.5:336–340 explicitly select the P≥1 swap / P<1 burn branch, insufficient-delivery reverts, no hysteresis band, no hard epoch spending cap, no off-pool funding, no second buyback, no keeper bounty. A07-A08-A09/A11/A24 enforce.
- **Conclusion:** settled. The "no additional eligibility" answer is the owner-confirmed position via the PRD's own selections; moderator can close Q6 without new prompt.

**B5. Funding waterfall is "possible not fixed" — engineering gate, not owner question.** All four frame this as engineering. PRD §7.3:309–313 explicitly: "The precise funding waterfall is not fixed. Do not require an invented off-pool treasury or idle sleeve." The PRD's selected sources (claim income, unbuffer SE shares, redeem owned hook LP, convert components) are a non-exhaustive list; A17 is the proof obligation. **No reopen.** Engineering must show conservation and funding sufficiency under income exhaustion, price manipulation, expiry, and expansion (A17).

**B6. Kimi §3 last bullet — Weighted multi-reserve conservation and §12.3 are the two gates most likely to force design changes during planning.** I agree, and Astra §3 also flags the Weighted single-reserve-vs-many-component input mapping problem (`MIN_N=2`/`MAX_N=8` per Grok §"Custody/accounting"). PRD line 195: "These math-domain limits are not newly invented epoch spending caps. Preserve applicable behavior and report incompatibilities rather than silently stripping guards or changing parameters." **My correction:** this is an explicit engineering gate, not a request to remove domain guards. Planning must either (a) keep PLP/YT/interest/USDG SE shares as ≤ 8 components per balance group with appropriate aggregation, or (b) document the concretely enumerated ledger mapping that satisfies the constraint. The PRD does not select ≥8 components; it does not reject ≥8 either.

**B7. PRD §14 heading issue — Astra line 19.** The heading "Unresolved product/authority decision" mixes resolved decisions with engineering tasks and genuinely open policy. Confirmed; PRD §14 rows O02–O10 all start with "Resolved …" then list "Remaining:" engineering follow-on. The heading is editorial noise. **My correction:** editorial-only; plan should re-read §14 row by row and treat "Remaining:" lines as engineering work, not owner prompts.

**B8. Bond depository vesting 2-day code vs 5-day prose — three of four flag.** PRD line 598 + Grok line 79 + Kimi §6 missing-evidence. Verification: `lib/crane/contracts/protocols/pol/net/src/Constants.sol:76` `BOND_VEST = 2 days`; `:54` `GENESIS_VEST = 5 days`. PRD E06 already flags this. **My correction:** the wrapper uses the deployed `BOND_VEST` for its native full-maturity math; verify on Robinhood 4663 before locking. Engineering verification, not owner clarification.

## C. Unresolved dissent

**D1. Whether the "long decay" question (Kimi Q2) belongs on the moderator list.** Kimi and I agree it is a fact about an unspecified commitment. The PRD does not promise a price path; it specifies peg-relative mechanisms. If the owner asserts the 1,000-NET opening is the implied origin of a long-decay Olympus design, that becomes a small PRD addition. If not, the plan proceeds without that assertion. **My position:** do not add to the moderator list. Note in the plan.

**D2. Whether §14 heading should be relabeled.** All three peers implicitly treat "Remaining:" as engineering; Astra explicitly calls out the heading. **My position:** editorial fix during planning; not a blocker.

**D3. Whether matrix lag is documentation-only or a real reopen risk.** All four agree matrix is stale. **My position:** editorial fix before plan; matrix must mirror v0.17 expansion language to prevent the plan from re-litigating settled economics. Same conclusion as Kimi §2.1, Grok line 110 inference, Astra line 19.

## D. Readiness verdict (corrected)

**Not a frozen executable plan. Ready for a gated planning document.** Aligns with Astra line 7 ("ready for a gated implementation-planning document, not a frozen executable implementation plan"), Grok line 13 (not impl-ready), and my original §8. Kimi does not give a single verdict but his §3/§5 imply same.

## E. Final prioritized decision checkpoint (≤10 items, attributed corrections applied)

1. **O01 — custom-family supersession for FoT NET and rebasing sNET.** Owner. **Blocking.** (All four.)
2. **Singleton-enforcement mechanism** for salt `"NET-DETF"`. Owner or engineering depending on chosen approach. PRD line 715 explicitly defers. **Blocking.** (All four.)
3. **TWAP window + invalid/stale/insufficient-history policy.** Owner. PRD §9.2:397 reserves it. **Blocking.** (Astra §4, Grok Q3, Kimi Q3, mine Q4.)
4. **Authoritative contraction price P** = post-expansion owned-reserve synthetic NET/DETF. PRD §9.2:399 implies; PRD §7.5:338 requires. **Owner-confirm.** (Grok Q2, mine Q-removal.)
5. **(Confirmatory, not owner) Empty-target rollover policy = revert-only for v1.** PRD §11.4:577 settled. **Close as confirmatory.** *(Grok Q4 resolved; corrected here.)*
6. **(Confirmatory, not owner) No additional contraction eligibility beyond P<1 + funded delivery.** PRD §7.5 settled. **Close as confirmatory.** *(Kimi Q6, Grok Q6 resolved; corrected here.)*
7. **D9 owner-only hook + R32 public shared HLP reconciliation.** Encapsulation reconciles; plan must implement `MultiStepOwnable` and confirm `addLiquidity`/`removeLiquidity` are `onlyOwner` while `mint`/`burn` of the hook LP token are public. INDEXEDEX_AGENT_LAW.md:119, alignment D9, PRD R02/R05/R29/R32. **Engineering gate, not owner.** *(My correction; not raised by peers explicitly.)*
8. **§12.3 note-array liveness proof** — wrapper design or explicit deferral. **Engineering gate.** (All four; existential.)
9. **Multi-reserve conservation and Weighted math domain (MIN_N/MAX_N) ledger mapping.** PRD §11.4 source `WeightedMath.sol` import; PRD line 195. **Engineering gate.** (Astra §3, Grok §"Custody/accounting", Kimi §3.)
10. **External evidence pins** (Pendle V7 router, YT v6, market V7; NetNet BondDepository `BOND_VEST` on 4663; canonical V2 SE binding query). PRD §16:711–748. **Engineering gate.** (All four.)

## F. Items confirmed NOT to require owner input (planning/engineering only)

Repo slot layouts; selector/route inventories; historical-series registry layout; rounding algorithms; exact-output inverse math; native `1.005^n` evaluation method (no gas-driven epoch cap); `requiredFirstBondTokens()` weights; permitted-SE list and parity matrix; pre-mutation event surface; permit2 wiring; D55 NFT SVG; non-PENDLE reward destinations (PRD says not swept; A11/A41 enforce).

**No consensus is asserted beyond evidence. No code, tests, deployment, signing, instruction edit, file deletion/move, browser, MCP, or subagent delegation occurred. Originals are unchanged.** Stopping here for the human moderator.
