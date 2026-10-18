# Astra — RC-03 backing consistency review

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes were read. The controlling RC-03 text in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:101–113` was freshly read successfully. No guard denial occurred.

## Plain-English answer

RC-03 was reporting **two ways of valuing the same IndexedEx shares differently**, not two different share tokens or a need for a second ledger.

The Stata SE can hold three forms of backing: Stata receipt tokens, local underlying tokens, and aToken balances that have been recorded in its reserve book. The September concern was that the ordinary SE entry/exit math counted the first two while the shared ERC-4626 adapter also counted the third. If one interface omitted already-booked value, it could make the same existing shares look cheaper and issue too many shares to a later funded depositor compared with the other interface's valuation.

**That divergence is not present in the current backing functions. Both surfaces now call the same accounting library with the same Stata-mode setting. Close RC-03. No implementation gap was established for the reported mismatch.**

There is no reason to add another share ledger, alter aToken ownership attribution, or change reward forwarding. An unsolicited aToken transfer is not magically a deposit by a newly identified person. Once it is booked by the existing reserve synchronization, the shared calculation includes that recorded value in holder backing on both surfaces.

## The two backing functions now converge

### Stata SE

`contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:106–111`:

- `_stataBacking()` gets the bound Stata receipt.
- It returns `ReceiptBackedERC4626AccountingLib.backingReceiptUnits(IERC4626(address(stata_)), address(this), true)`.

It no longer implements a separate held-Stata-plus-underlying formula that omits registered extras.

### Shared ERC-4626 adapter

`contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:168–180`:

- `_requireFamily()` rejects unsupported/ambiguous generic-versus-Stata markers.
- `_isStata()` reads the Stata marker at **174–175**.
- `_totalReceiptBacking()` at **178–180** passes the bound reserve receipt, the same proxy holder `address(this)`, and `_isStata()` into **the same `backingReceiptUnits` function**.

The Stata package advertises `IAaveV3StataStandardVault` in `AaveV3StataStandardExchangeDFPkg.sol:178–190`, so the shared adapter's Stata path uses `true`, matching `_stataBacking`. Generic dispatch uses false; it does not acquire an aToken term merely because an external receipt happens to be Stata-like.

### The single calculation

`contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:18–51` computes:

**held receipt tokens + receipt-equivalent value of booked underlying and booked registered extras.**

Specifically:

- **23–25:** reads held receipt tokens and the booked underlying reserve.
- **26–28,32–38:** in Stata mode, loops through registered vault tokens, excludes the receipt and underlying, and adds the remaining **booked reserves**. It does not read the live unsolicited aToken balance as a new depositor payment.
- **45–51:** converts the combined booked underlying-equivalent amount once with `receipt.convertToShares`, then adds held receipts.

Summing before conversion also gives both surfaces the same rounding boundary. No second aToken balance or share supply is introduced. If aToken is not registered, it cannot contribute through that loop; if it is registered but has zero booked reserve, its contribution is zero.

## Why aToken is in the reserve book

`contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeDFPkg.sol:231–264` establishes the relevant state:

- **241:** binds the Stata receipt as the reserve asset.
- **247–252:** reads the underlying and probes `aToken()`.
- **253–258:** when the returned aToken is nonzero and distinct from receipt/underlying, registers all three in the expected-hold set.
- **259–263:** otherwise registers only receipt and underlying. It does not invent an extra balance.

`contracts/vaults/basic/BasicVaultCommon.sol:48–53` synchronizes each registered token's booked reserve to the proxy's actual token balance after successful money operations. Stata exact-in calls this synchronization at `AaveV3StataStandardExchangeInTarget.sol:79–80`; SY also syncs at `AaveV3StataStandardYieldTarget.sol:29–30`. Registration makes aToken eligible for bookkeeping; synchronization records the balance. Neither operation identifies a donor as a new share recipient merely because aToken appeared in custody.

## Other Stata surfaces use that basis

The examined production call sites are consistent with the same valuation basis:

- **Exact-in preview:** Common **58–71** uses `_stataBacking()` for issuance; exits call `_convertSharesToStata`, whose implementation at **222–226** uses `_stataBacking()`.
- **Exact-in execution:** `AaveV3StataStandardExchangeInTarget.sol:40,52–66` prices issuance from that shared backing, excluding only the current credited receipt input when it is already in custody. This payment exclusion is not omission of existing booked aToken.
- **Exact-output quoting:** `AaveV3StataStandardExchangeOutTarget.sol:38–58` uses `_stataBacking()` for mint requirements and SE-share exit requirements.
- **Transition quotes:** InTarget **115–123** initializes the memory quote's receipt-denominated backing from `_stataBacking()`; **143–155** values shares and projects issuance from that captured basis. The snapshot is projected state, not a second persistent share ledger.
- **SY:** `AaveV3StataStandardYieldTarget.sol:21–30` uses the same share-to-Stata conversion for redemption, and **44–51** explicitly calls the canonical accounting library with Stata mode enabled for its exchange rate.

These are backing-consistency observations, not a claim that every entrypoint's net user result must be identical irrespective of its specified fees and rounding. Receipt inventory checks in Common **79–91** remain distinct from backing valuation. Reward forwarding at **240 onward** is a separate existing stream and is not a missing aToken term or a repair target under RC-03.

## Current test evidence

`test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_APEX_R14.t.sol:124–148`, `test_RC03_bookedAToken_sameBacking_adapterAndSe`, is present:

- It obtains aToken through a real hermetic Aave supply and transfers it to the SE.
- A subsequent ordinary funded operation performs the expected-hold synchronization.
- **133–140:** requires nonzero booked aToken and demonstrates shared-adapter backing exceeds a comparison that deliberately excludes that term.
- **144–147:** requires the SE receipt-input issuance preview to equal the adapter's `convertToShares` result for the same input.

This is meaningful evidence for the old denominator mismatch. It does **not**, in the inspected final assertions, execute another receipt deposit after establishing parity; I do not describe it as an independently executed later-depositor dilution proof or as comprehensive runtime coverage. The direct common-helper use also establishes that the production valuation term is no longer omitted. Under this assignment's explicit criterion—close if both surfaces now use one calculation—no additional production repair is warranted.

The test's transferred aToken is backing for this comparison, not a newly attributed depositor claim. No refund, new shares or new owner attribution should be invented for that unsolicited transfer.

## Facts, inference and limits

**Confirmed:** both backing entrypoints call the same helper with the same bound receipt and Stata setting; package registration includes aToken when available; the helper counts registered booked extras once; inspected issuance, exit, SY and snapshot paths use that basis; the targeted parity regression exists.

**Inference:** the particular September claim of asymmetric booked-aToken inclusion is refuted by current source. It does not require a new ledger or excluded-value policy change.

**Unverified:** historical source at filing, execution of these tests in this review, deployed-instance state and full regression coverage beyond the inspected paths. No deployed instance is claimed upgraded. Current-source closure does not prove the earlier report was mistaken or certify every unreviewed economic behavior.

## Files examined without a scoped defect

The Stata Common backing/conversion ranges; shared adapter family/backing dispatch; canonical accounting library in full; package expected-hold initialization and marker declaration; BasicVault full-set synchronization; Stata InTarget issuance/transition ranges; OutTarget quote ranges; Stata SY target in full; and the cited RC-03 test. The controlling PRD was available. All supplied paths were present; the assigned report was absent before writing. Canonical repository/testing guidance was read directly earlier in this session.

Only this assigned Markdown report was created. No code, tests, PRD, original review, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

Close RC-03
I did not run Forge.
