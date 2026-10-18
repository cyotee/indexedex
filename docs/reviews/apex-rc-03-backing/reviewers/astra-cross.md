# Astra — RC-03 replacement-session cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes my independent `astra-original.md`, preserved unchanged. I read all three supplied originals in full and treated them as untrusted evidence. No peer cross-review artifact was read.

## Decision

**Close RC-03. Both surfaces now use one backing calculation. No current production gap was established for the reported asymmetric aToken inclusion.**

The resolution is current-source closure, not another accounting rewrite. Do not add a second share ledger, invent a depositor for an unsolicited aToken transfer, change expected-hold membership policy or redirect the separate Aave reward stream.

In plain English: the old complaint was that two interfaces to the same IndexedEx shares could disagree about how much backing those shares represent. Today they consult the same calculator, including the same already-booked aToken component on a Stata proxy. The difference described by RC-03 is no longer present.

## Fresh independent source checks

- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:106–111`: `_stataBacking()` calls `backingReceiptUnits` with the bound Stata receipt, `address(this)` and `true`.
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:168–180`: `_isStata()` checks the proxy's ERC-165 Stata-family marker; `_totalReceiptBacking()` calls the same helper with the same bound reserve receipt and holder, using that marker as its third argument.
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:18–51`: the helper adds registered booked extras to booked underlying, then converts the combined amount once into receipt units and adds held receipts. The loop excludes the receipt and underlying and reads booked reserves, not an unsolicited live extra-token balance.

My independent pass also directly read package initialization at `AaveV3StataStandardExchangeDFPkg.sol:245–264`, its Stata marker declaration, full-set synchronization at `BasicVaultCommon.sol:48–53`, the other Stata issuance/exit/SY/transition consumers, and the targeted RC-03 test. Those observations remain attributed to Astra. They establish matching Stata-mode inputs, not merely two call sites with coincidentally similar names.

## Peer assessment

### Grok — agree; qualify the unsolicited-transfer shorthand

Agree with `grok-original.md:7–9` on current convergence and conditional aToken registration.

“An unsolicited aToken transfer is not read” should be understood as **the backing helper does not count its live balance directly before booking**. Expected-hold synchronization can subsequently record that balance; once booked, the same helper includes it on both surfaces. The transfer still creates no separately attributed depositor or second share account. If aToken is absent from the registered set, that aToken contributes zero—not a reason to invent a balance or treat the supported absence case as defective.

### MiniMax replacement — agree on closure; correct dispatch, transcription and coverage claims

Agree with `minimax-original.md:12,123–139` that the current reported split is absent. Corrections:

- **72,124:** `_isStata()` is determined by the **IndexedEx proxy's family marker**, not merely whether its external receipt is a Stata token. Generic mode deliberately excludes expected-hold extras even if its external receipt happens to be Stata-like. Fresh target lines 174–175 establish this distinction.
- **68–69:** the actual `_totalReceiptBacking` local is `IERC4626`, not `IERC20` as transcribed. Its passed receipt/holder/mode are the relevant equality.
- **111:** the transcribed sync loop contains an extra `0;`. The actual `BasicVaultCommon` loop inspected in the original pass is the ordinary `for (uint256 i; i < tokens.length; ++i)`. This is a report transcription error, not broken production code.
- **103,148:** registration requires the aToken address to be nonzero **and distinct from both underlying and receipt**. Its absence is explicitly supported by the requirement and would not, alone, justify reopening RC-03.
- **137:** shared helper use establishes source-level consistency; it does not by itself verify the required funded test or an executed later deposit. The specific test inspected by Astra proves booked inclusion and preview/conversion parity, not an independently run later-depositor scenario.

These corrections narrow the claims without producing a new implementation defect.

### Kimi replacement — agree on convergence; clarify units, ownership and history

Agree with `kimi-original.md:16–20` on common accounting, package registration and the targeted parity test.

- **16:** express the formula as **held receipts plus one conversion of (booked underlying + booked registered extras)**. Extras are not added as raw underlying units after receipt conversion. This matters to units and rounding; fresh library lines 25–29 and 50–51 make the order explicit.
- **18:** Common line 223 belongs to `_convertSharesToStata`, not a `totalAssets` function. It is an exit-conversion consumer of `_stataBacking`.
- **20,24:** “unowned surplus” is misleading after synchronization. The transferred aToken has no invented depositor attribution, but its booked value is included in existing share backing. Unattributed origin does not mean ownerless economic value.
- **28:** historical source accuracy at filing is unverified in this review. Current convergence supports closure but does not independently establish the exact earlier implementation. No history rewrite is needed.

## Test evidence and its limits

The original independent pass read `test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_APEX_R14.t.sol:124–148`:

- A real hermetic Aave supply produces aToken, which is transferred to the SE and booked through a subsequent money operation.
- Nonzero booked aToken is asserted at **133–134**.
- Adapter backing is shown to include more than the deliberately aToken-excluding comparison at **136–140**.
- SE issuance preview and adapter conversion are compared exactly at **144–147**.

This is substantive source-level coverage. Its final assertions do not execute another receipt deposit after the parity comparison, and no test was run by Astra. Do not claim a runtime pass or broader later-depositor proof from shared-helper existence alone. Under the assignment's explicit closure condition—both surfaces use one calculation—this limitation does not create a production repair or second-ledger requirement.

## Attribution, dissent and disposition

No evidence changes Astra's original closure recommendation. There is no unresolved dissent on the absence of the current backing-calculation split. The qualifications above concern precision, test-evidence strength and historical claims. No peer is represented as having revised its original.

**Confirmed:** shared helper, same bound receipt/holder on the Stata proxy, correct family flag and booked-extra inclusion. **Inference:** the September asymmetric-valuation mechanism is absent from the inspected current paths. **Unverified:** runtime execution, historical source and deployed-instance behavior. No production fix direction is required because no remaining RC-03 production defect was found.

Freshly examined the three original reports and the two backing entrypoints/common helper listed above, with no scoped defect established. The earlier independent report preserves the package, synchronization, consumer and test inventory. All supplied originals were present; the assigned output was absent before writing.

Only this assigned Markdown cross-review was created. No code, tests, PRD, original report, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

Close RC-03
I did not run Forge.
