# Astra — REQ-03 completeness cross-review

I read all three supplied completeness originals, re-read the current PRD in full, and re-read the relevant callback, token harness, and scanner source. Peer statements are evidence, not authority. No PRD or code was edited; my original remains preserved.

## Conclusion

**Two implementation-mechanism choices remain under the owner's literal requirement of no implementer choice.** The behavioral decisions are closed, but the PRD does not yet prescribe the observation record's storage mechanism or the scanner list's representation.

I therefore narrow my original conclusion. It correctly identified no remaining product decision or obstacle to starting implementation, but treated coding-mechanism latitude as permissible. This turn expressly includes that latitude. Under that stricter completeness test, I dissent from the peers' unconditional “no decision remains” conclusions. MiniMax and Kimi themselves describe alternative mechanisms in their originals; those alternatives demonstrate that the text does not select one.

## REQ-03-R1 — prescribe the observation record and callback mechanism

**Already closed:** PRD lines 28-35 select the same rebasing vault, a successful outer observation deposit, and a separate preserved rollback test. Do not reopen those decisions.

**Still open:** Line 33 says the callback “records” the nested outcome and the test reads “that record,” but does not choose test-contract storage versus an external recorder/event mechanism, or select a callback implementation. Current `RebasingAwareERC4626_Adversarial.t.sol:28-32` already uses a low-level nested call, but has no surviving observation record and ends by reverting.

**Exact text to add after the observation acceptance criterion:**

> Implement the observation in `RebasingAwareERC4626_Adversarial.t.sol` using a separate callback named `recordNestedDeposit` and three private storage fields on that test contract: `nestedDepositAttempts` (`uint256`), `nestedDepositSucceeded` (`bool`), and `nestedDepositReturnData` (`bytes`); reset all three before the observation deposit, have the callback increment the attempt count and store the success flag and complete return data from the same low-level nested deposit call used by `observeNestedDeposit`, and return normally without assertions or a deliberate revert; after the outer deposit succeeds, assert that exactly one attempt occurred, the stored success flag is false, and the stored return data equals the ABI-encoded `IReentrancyLock.IsLocked` error; keep the existing callback and rollback test unchanged, and do not introduce an external recorder, event-based observation, new harness variant, or production change.

This closes the representation and assertion-location choices without changing the owner-selected behavior. Names above are proposed requirements, not claims that these fields currently exist.

**Correction to MiniMax:** `ReentrantERC20Harness.sol:68-77` does not swallow callback failures merely when `bubbleRevert` is false: it then rejects through `require(ok, ...)`. A normally returning observation callback is sufficient because line 71 returns on success. No harness modification or toggle-based failure suppression is needed.

**Exact additional sentence:**

> Reuse the existing `ReentrantERC20Harness` unchanged, keep its bubble-revert setting true, and point only the new observation test at `recordNestedDeposit`; the existing rollback test continues to use `observeNestedDeposit`.

## REQ-03-R3 — prescribe extension of the existing roots tuple

**Already closed:** PRD lines 54-77 supply the exact directory inventory and recursive-selection requirements. Family selection and discovery must not be delegated back to the implementer.

**Still open:** “The two roots already in the scanner stay. Add the rest” at line 55 does not explicitly select the current `roots` tuple over a parallel tuple or external manifest. MiniMax's original alternates between adding to `roots` and introducing a third tuple; Kimi expressly permits either carrier. Equivalent outcomes still leave a mechanism choice.

Current `scripts/apex_bare_expectrevert_scan.sh:14-26` already recursively enumerates `roots`, adds explicit custody files, and applies its existing APEX-content inclusion. The minimal fixed mechanism is to extend `roots`.

**Exact sentence to add:**

> Append the fifteen additional directory paths listed above, in the listed order, as `Path(...)` entries in the existing Python `roots` tuple in `scripts/apex_bare_expectrevert_scan.sh`, retaining its two existing entries and leaving the `custody` tuple, recursive `*.sol` enumeration, APEX-content inclusion, deduplication, violation detection, report output, and `--check` exit behavior unchanged; do not introduce a parallel directory tuple or an external inventory file.

This selects the concrete edit while preserving the current output's meaning: lines 36-41 emit violation sites, not a row for every selected file. It does not authorize repairing the newly selected tests or suppressing their violations.

## REQ-03-R2 and remaining scope

Agree with all peers that R2 is already closed by PRD lines 43-46: assert successful total supply against captured supply plus requested shares, preserving the existing assertions and fuzz domain. No addition is needed.

The proposed R1/R3 sentences close only the mechanism choices explicitly raised in this turn. They do not reopen ownership, alter the bytecode guard, broaden revert expectations, or add product work. They require coordinator adoption before becoming controlling text. No runtime result is claimed.

I did not run Forge.
