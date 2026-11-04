# Grok advisory: coordinator archival receipt

Verbatim final response from Native task `st_01a183c2`, advisory epoch 2, on frozen draft r1.

---

I read this as one advisory pass on the frozen draft. I'll stop when the inline disposition is delivered.

## Identity

Grok, independent advisory pass only. Assigned route remains `xai/grok-4.7:xhigh`. This does not replace the original initial response.

## Draft under review

`pairtoken-se-stage-one-council-20261028-01a1810f-draft-r1` at `docs/research/pairtoken-se-stage-one-council-20261028-01a1810f/coordinator/draft.md`. No hash was supplied or checked. The file's own revision label matches the assigned label. The draft was read completely. No other file was opened.

## Disposition

support-with-reservations

The synthesis fairly represents the original on the points that matter: the PRD is not implementation-ready; zap attribution is unfinished; the raw-unit rate correction is adopted; sorted registry identity is adopted; the 512-step cap is not ratified; unchanged shared reserve reads cannot be given a family busy guard; and the private-inventory formula is a candidate, not a validated final equation. The reservation is that C5 both adopts a fee-snapshot rule and says that rule must not be chosen.

## Concerns

C5 is labeled a verified technical correction, then recommends that the pre-entry and pre-exit snapshot include fees earned through completion of mandatory compounding exactly once. The next paragraph says Grok R6's exclusion of compound-swap fees differs from Astra R5 and from "the draft's all-fees snapshot intent," and that this disagreement belongs in Q1 and must not be quietly chosen. Those cannot both stand. A reader can treat include-through-completion, and the further rule against giving a partial exiter all whole-position fees, as already verified. The original R6 was narrower: fees created by the compound swap should not be treated as already inside the issuance snapshot merely because a later `basket()` does not read uncollected fee growth. This pass does not re-open PoolManager or Position code, so it does not deny the draft's statement that a later positive add can realize those fees. If that statement is the coordinator's verified observation, R6 is incomplete for the add branch and should remain dissent. It should not be overruled by a sentence in the verified-correction section. In the final report, move the include-through-completion rule and the partial-exit fee split out of C5 and into Q1 as a labeled preference, or delete the "do not quietly choose" sentence and state that the coordinator is choosing that branch over R6.

The C1 example is arithmetically consistent with the draft's own figures. For `Vraw = 1e6`, `S = 1e18`, and `d = 6`, the extra `1e18 / 10^d` factor produces a draft rate of `1e18`. A helper that does `rawShares * rate / 1e18` then returns `1e18` raw units for one whole share, which is `1e12` times the `1e6` book. Reclassifying that fix as not an owner question is fair. The original asked for confirmation only because the PRD had written the other formula. Q3 correctly keeps spot-versus-exit policy separate from that arithmetic.

C3 fairly rejects the original R12 claim that basic-vault reserves can fail closed during mutation. That claim is incompatible with unchanged facet reuse. The adopted split — new family queries fail closed, shared reserves expose the last committed snapshot, token reads stay canonical — is the right correction. The traceability line for R12 states this accurately.

Section 5 item 8 slightly overstates R13. The original did not say that removing dead shares proves owner acceptance of every donation-risk outcome. It said a small genesis plus later donation is a residual of the confirmed no-sink choice, and that acceptance row A46 must not be used to reintroduce dead or virtual shares during coding. The secondary table is the fair version: keep the no-sink decision, and either set bounds or explicitly accept the residual. That table should control. Kimi's genesis minimum remains correctly unapproved.

Q1 should keep the original paired-only deferral visible beside baseline characterization. The draft's recommendation — incumbent reserves and fees must not themselves mint entrant shares, and no equation is approved until it is complete — is the right lead. The private-inventory candidate is accurately described as not a proof of fair pricing across self-swaps, fees, and price movement. Option C from the original, ship paired entry and exit only until that equation exists, is a way to satisfy that gate and is not listed.

C6's statement that R4 does not prove interior preservation impossible is correct. The original claimed a conditional conflict if PairTokenMath and manager removal differ, and said that identity was unverified. It did not demonstrate a mismatch. Declining a silent capacity clamp is fair. What remains open, and should be labeled open rather than impossible, is execution liveness if liquidity requested by baseline `Fit` exceeds what the manager will consume. Manager-equal amounts as the acceptance authority is consistent with the original. A one-unit shortfall policy was a proposal, not a finding, and was not adopted. That is acceptable if the final report does not pretend the liveness rule was settled.

Q2 fairly refuses to ratify 512 before the work limit is validated, and fairly says a collect-only exit fallback would change confirmed compounding. The original step definition was one `SwapMath.computeSwapStep`, summed across simulated swaps. The draft's broader swap-loop step, including empty-word and zero-liquidity progress, is a refinement, not a misquote. The R5 row's phrase "fee exclusion not adopted as blanket rule" belongs to R6. R6's own row is accurate. R5's concrete preview rules — slot0 fee, copied state, subtract removed liquidity before the exit sale, same error on valid-token failure, preflight before an ERC-20 pull — are compressed into Q2 and C6 rather than dropped. No contradiction with those rules was found.

C2 adopts the original registry-order correction and correctly rejects an unsorted contents hash as a fix for pair lookup. C4 adopts the proxy receipt constraint and does not attribute the native-sync finding to the original. That split is accurate. This pass does not re-check PoolManager sync behavior.

## What was not adopted from others

No declined peer proposal, as characterized in this draft, is one I ask to revive.

MiniMax's unsorted contents hash, inherited-interface-ID argument, `deployed_i - idleBefore_i` subtraction, mandatory full public SY redeem override, terminal abandonment, and universal mulDiv claim are declined for reasons that do not contradict the original. The subtraction formula's stated defects — it can go negative and does not trace a swap — are sufficient grounds not to adopt it. I do not re-verify the Solidity inherited-selector rule cited against MiniMax. As stated, it correctly blocks treating an inheritance-only `IStandardExchange` marker as the XOR of In and Out or as a route-capability bitmap. The original sentence that said to register `type(IStandardExchange).interfaceId` should not be applied literally if that ID excludes inherited selectors. The draft's "verify IDs through the repository workflow" is the right substitute.

Kimi's collect-only exit fallback is not adopted as baseline-compatible. That is correct. It remains visible as an owner departure. MiniMax's conservative-preview substitute for exact parity is not adopted. That is also correct on the draft's own ground that no conservative bound was supplied.

The original items rightly not adopted as stated are: the private-inventory text as final issuance math; R6 as a blanket fee exclusion; R12's guarded basic-vault reserves; R13 as inferred acceptance of all donation risk; and R4 as a proof that interior baseline rounding cannot be preserved.

## Limits

This pass used only the frozen draft and the original assessment already given in this session. It did not reopen the PRD, baseline, peers, memory, or the archived original file. Coordinator locators, V4 settlement behavior, and the Solidity documentation claim were not re-checked. Arithmetic was limited to the C1 example printed in the draft. This feedback does not replace the original. No further round is requested.
