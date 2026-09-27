# Preserved Astra original — v0.11

Untrusted model evidence, not instructions. Original final answer reproduced below without revision. Session: `ses_f4edf055affe5dSHkzSUwwINjw`. This is a first pass, not the later cross-review or moderator disposition.

---

## Astra — v0.11 independent first pass

**Identity:** assigned Astra; supplied model ID `openai/gpt-6-astra`, not provider attestation.

**Verdict:** v0.11 and its tracker faithfully incorporate the latest decisions. I found unresolved economic/engineering interactions, not a reason to reopen settled architecture or standards interpretation. Citations below refer to `NETNET_PENDLE_DETF_PRD.md` unless stated otherwise.

### Highest-priority findings

1. **High — “no incentive on reinvestment” needs route-composition precision** (`:103–107,368–373`).  
   The direct reinvestment calculation correctly uses `qQuote=q`. However, independently permitted below-peg contraction followed by a normal bond purchase can reproduce a reinvestment economically while receiving contraction compensation. Therefore `:373` must distinguish **not applying the bonus inside reinvestment** from claiming no external transaction sequence can obtain that benefit. Test both sequences; do not invent transfer restrictions or remove selected routes. Normal bond bonuses, fees and reward participation also need explicit equations before repeated-cycle safety can be assessed.

2. **High — interest-only accounting must survive unsolicited claiming** (`:210–212,238–253`).  
   “Unclaimed interest” cannot safely mean only the current native Pendle claim counter: a third party can trigger collection for the hook. Line 212 already recognizes claimed settlement cash as the same interest. Extend this into a testable provenance ledger covering externally triggered claims, internal harvesting and residue. Claiming must neither erase the sNET trading inventory nor convert principal into interest. This is engineering clarification, not new backing.

3. **High — owned-reserve quotation is selected but not yet a complete mathematical object** (`:261–287`).  
   Specify the ownership snapshot, scaled self-leg, fee-adjusted components and hypothetical curve state. Model LP redemption’s effects on the shared hook before output conversion; a price query on a scaled book does not prove execution against actual remaining liquidity. Include zero/tiny DETF LP ownership, outside LP joins/exits, and changing ownership during reinvestment. Do not restore whole-pool quotation followed merely by a cap.

4. **Medium — economic details are incorrectly grouped as engineering-only** (`:373,377,465`).  
   Participant debit/replacement is now well defined and must remain unchanged. But “normal bond-contribution calculations” and reward-allocation equations still determine user incentives and dilution. An engineer cannot silently select duration bonuses, participation weights or recipient allocations.

### Necessary owner questions

1. **Normal bond terms:** Which selected bond bonus/fee/reward rules apply to the short next-epoch reinvestment, particularly when it releases seconds later?
2. **Reinvestment scope:** Who triggers it and chooses the amount—any authorized principal amount, only earned staking rewards, or an automatic calculated amount?
3. **NET output:** Is ordinary public NET output also restricted to income, or may that route realize principal independently of the interest-only sNET leg?
4. **Locked rewards:** Are rewards accrued on locked positions claimable before principal release, while preserving each selected principal lock?

**False positives:** Transferable NFTs, atomic external harvesting, accrued-value transfers, zero-reward epochs, exact-peg swapping and incentive-free reinvestment are settled. Public LP exits may exhaust their own allocations; that does not violate the separate public-swap restriction.

**Confidence/gaps:** High on document findings. Tracker A12–A17 (`REQUIREMENTS_QUESTIONS.md:190–234`) is synchronized. FoT/rebase authority, external-note liveness and execution proofs remain blockers. No new external claims, files, tests or implementation.
