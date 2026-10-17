# Kimi K3 — question pass: REDESIGN_PRD readiness

- **Label:** Replacement-session question pass, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No reviewers' notes were read. Nothing was edited; no plan or PRD was written.
- **Date:** 2026-10-14.
- **Subject:** `docs/reviews/legacy-v4-architecture-redesign-prd-review/REDESIGN_PRD.md` (read in full; 124 lines).
- **Question asked of me:** does the rewritten design still need an owner decision before an implementation plan?
- I did not run Forge.

## Answer: no owner question remains — ready

The rewrite closes every decision the council flagged. The four previously Assumed rows are now Decided (`:100-108`, including D3 shim deletion, D4 one callback facet and both delegates deleted, D7 fresh-package storage, D9 size limits). The credit-residual question I raised in the design cross-review is now explicit product law in the document itself: "Do not repair the stored-reserve pretransfer credit residual in this redesign. Preserve the current calculation" (`:113`). The selector table is complete and matches the current partition plus the one mandated move (`unlockCallback` → `UniswapV4StandardExchangeCallbackFacet`, `:47`); the component list is named with one responsibility each (`:21-31`); the deletion list is enumerated with its search preconditions (`:75-88`); the package cut order is fixed (`:63`); the size gate and the unverified status of the 31,908-byte claim are both recorded (`:90-94`). I checked each candidate product choice against the text and found it already selected; per the instruction I do not ask the owner to name files, errors, or layouts the document already names.

## Mechanical closures the later plan must state (none is an owner decision)

1. **Move/delete order.** Create the six internal libraries with moved content first (nothing deleted yet); rewire the targets/facets onto them; delete the two delegates and their wiring only after their last encoded callers are gone; delete `Common`/`InBase`/`OutBase`/`OutTarget` only after a zero-reference search; then the SY shim deletion and error-namespace repoint, with other families' import-path edits last and mechanical. The plan states this order so no intermediate state has a live caller aimed at a deleted function.
2. **Disposition of `UniswapV4StandardYieldExecutionTarget.sol`.** The file is not in the delete list and `:69` says yield redemption "keeps the current internal" settlement — so the plan should state: the file stays as the legacy family's SY hook layer (`_redeemVaultHeld` / `_standardRoute` overrides and `_settleNamedHolder`), narrowed to call the internal libraries, with the REQ-V4-02 `_requireNotDisabled` on the SY money entries (`:71`). Without that sentence an implementer could either delete the file or leave the pre-flattening body in it.
3. **What moves where for the two settlement bodies.** `:67` and `:70` already name the destinations (zap-in deposit and zap-out withdrawal bodies move once into `internal/UniswapV4StandardExchangePoolOps.sol`); the plan repeats that and forbids a second copy.
4. **Package wiring.** `IUniswapV4StandardExchangeDFPkg.sol`, `UniswapV4StandardExchangeDFPkg.sol`, and `UniswapV4_Component_FactoryService.sol` gain the callback facet and lose the delegate deployments, with the cut order of `:63`. Mechanical; the plan states it so the wiring is not improvised.
5. **Measured units.** Every deployed family facet, 24,576 hard / 23,000 advisory, measured after the artifact refresh (`scripts/forge-artifacts.py` with the edited production sources, then the suites). The 31,908 figure is not a baseline (`:94`).
6. **Test gate.** The existing legacy V4 suites — the vault-held redeem suite, the full-range book suite (including its facet-size assertion), the local liquid buffer suite, and the `adversarial/`/`decimals/` variants under `test/foundry/spec/protocol/dexes/uniswap/v4/` — run unchanged against the rebuilt package through the updated TestBase; the plan names them and forbids rewriting assertions to bless the old hops.
7. **Search preconditions restated.** The zero-importer search for `UniswapV4StandardExchangeOutTarget.sol` (`:83`) and the repository-wide consumer search before any quote-helper deletion (`:88`) are plan steps, not options.

## Notes for the record (not questions)

- The PRD's D6 line ("Include the REQ-V4-02 disable check on SY deposit and redeem", `:105`) covers both SY entries; that is the document's own selection and I do not re-open whether REQ-V4-02 named only redemption.
- `:59` refers to the twelve SY selectors by their current owner rather than enumerating them; the plan should spell out the twelve selector identities (from `NativeStandardYieldSelectors._appendQuery`) so the loupe check is exact. Mechanical, not an owner decision.

I did not run Forge.
