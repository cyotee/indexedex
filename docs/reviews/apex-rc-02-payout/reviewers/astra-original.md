# Astra — RC-02 local-first payout review

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes were read. The controlling RC-02 text in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:86–99,231` was freshly read successfully; no guard denial occurred.

## Verdict

**Close RC-02. No implementation gap was established in the current local-first payout path.**

The September description is **not true of the current helper**: it no longer redeems a rounded-up receipt-share amount. It calls the protocol vault's exact-asset `withdraw(shortfall, recipient, address(this))`, then transfers the local portion. For a normal ERC-4626 vault and supported standard underlying transfers, the recipient receives exactly the accounted due amount. Rounding affects the receipt shares charged for the withdrawal, not the requested underlying assets sent.

The helper still checks for under-delivery, but that lower-bound check does not recreate the old overpayment mechanism. Treating it as an outstanding excess-payout defect would require assuming an ERC-4626 withdraw that sends more assets than requested, contrary to the dependency behavior specified by the owner. No such non-compliant vault is invented here.

Closure is against current source and inspected tests, not a finding that the historical report was necessarily mistaken, a deployment upgrade, or an independently executed regression result.

## Helper and amount proof

File: `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol`.

- **107–111:** local spending is the lesser of booked underlying and actual underlying held. Unbooked pending credit is not selected as local payout inventory.
- **116–120:** the helper computes the local portion as the lesser of due and spendable local cash, and the remaining portion as due minus that local portion.
- **121–124:** if the remaining portion is positive, it calls **`vault.withdraw` at 123**, not `previewWithdraw` followed by `redeem`. The recipient-balance check rejects an under-delivery.
- **126:** transfers precisely the local portion to the same recipient.

Therefore, on successful supported execution, underlying received is exactly:

**protocol-vault requested assets + local transfer = shortfall + fromLocal = due.**

This also covers the all-local and all-protocol-vault cases without introducing another branch or payout policy. No conversion from rounded-up withdrawal shares back into a larger redemption amount occurs in this helper. There is no remainder forwarding to `feeTo`, no new exact-input refund and no catch. Callers synchronize expected-hold reserves after settlement through Common **274–279**.

The accounting preview at Common **175–178** still uses `previewWithdraw` to determine the SE share requirement for an exact-output operation. That is a quote, not the old `redeem(previewWithdraw(shortfall))` payout mechanism. Do not conflate the two merely because the word previewWithdraw remains elsewhere in the file.

## Every direct production caller found

A scoped `contracts/**/*.sol` search for `_payUnderlyingLocalFirst` returned its definition and exactly these three call sites. All three were read with their surrounding production control flow:

| Caller | Site and flow | Accounting/result relationship |
|---|---|---|
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeInTarget.sol` | `_exchangeIn`, **95–102**, helper at **100** | SE-share-to-underlying exact-in computes `amountOut` from its preview, checks minimum, burns the requested SE shares, pays that exact `amountOut`, syncs reserves and returns the same amount. |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol` | `exchangeOut`, **107–114**, helper at **112** | Exact-out computes and bounds the required SE-share input, burns/refunds according to existing credit rules, pays precisely the requested `amountOut`, syncs reserves and returns input shares spent. That return is not an underlying-output claim. |
| `contracts/vaults/standard/erc4626/ERC4626StandardYieldTarget.sol` | `_redeemVaultHeld`, **18–35**, helper at **26** | Underlying-output SY redemption computes named return `amount_`, checks minimum, burns the explicitly selected vault-held shares, pays that amount and syncs reserves. |

`contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30–57` was also read to distinguish indirect SY dispatch: internal-balance redemption reaches the override above; ordinary routing reaches `_exchangeIn`. Both use the accounted amounts identified above. There is no fourth direct helper caller in the scoped search.

The separate receipt-token-to-underlying route at InTarget **82–89** legitimately calls `redeem(actualIn, ...)` because its **input is an exact receipt-share quantity**, and it returns the actual assets from redeem. It is not a local-first payout of a previously fixed underlying due and does not establish the reported RC-02 mismatch.

## ERC-4626 semantic confirmation

Used Context7 first for the library/API distinction, resolving `/openzeppelin/openzeppelin-contracts`. The returned primary source is [OpenZeppelin ERC4626.sol](https://github.com/openzeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC4626.sol): withdraw computes the share charge with previewWithdraw and sends the specified assets; redeem computes assets from a specified share burn. Withdrawal rounding is applied to shares, not by increasing assets delivered to the receiver. Only a generic public API question was sent externally.

The repository's test dependency exhibits that distinction directly: `contracts/test/stubs/SimpleYieldERC4626.sol:124–127,164–183` rounds previewWithdraw's share requirement upward, while withdraw transfers exactly its asset argument. `CappedPausableERC4626.sol:8,43–59` inherits that payout behavior and changes deposit capacity/pausing, not withdrawal into an overpaying mock.

## Existing tests substantiate the corrected rule

### Non-unit rate and mixed local/protocol payout

`test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_APEX_R14.t.sol` deploys the production SE through its established TestBase at **25–31** and uses a capped/yield-bearing external fixture.

- **198–206:** `_seedNonUnitMixed` establishes booked local cash, actual receipt holdings and a non-unit receipt rate. This is not an invented non-compliant withdraw.
- **163–180:** `test_RC02_exactOut_localFirst_nonUnitRate_paysExactDue` establishes that redeeming the rounded withdrawal shares would overpay, then executes the production exact-output route. It asserts the exact recipient underlying delta at **178**, receipt-share charge matching preview at **179**, and ending local reserve book at **180**.
- **184–195:** `test_RC02_exactIn_localFirst_nonUnitRate_returnMatchesRecipient` uses the same mixed/non-unit setup, establishes the payout crosses local cash, and asserts both return/preview equality and recipient delta equal to the exact-in return.
- **120–138:** the existing local-first control additionally checks local cash is used before receipts and the ending booked balance. It is supplemental, not the only exact-payout evidence.

These tests exercise the normal rounding distinction that motivated the report. A test requiring an exact-asset withdrawal to manufacture a redemption remainder is neither necessary nor consistent with RC-02's permitted exact-asset solution.

### Orbital capped unwrap and resting inventory

Production `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711–726` requests an exact token output from its SE, caps the approved share amount, resets approval after return, and rejects a short delivery. For the inspected ERC-4626 SE dependency, its exact-output route reaches the corrected exact-asset helper; the hook is not receiving a rounded-share redemption surplus from that helper.

`test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol` contains:

- **224–234:** `test_R6_cappedUnwrap_fundedSuccess`, asserting exact recipient output and zero leftover buffered face after the funded unwrap.
- **236–251:** exact output, quoted SE-share burn, input debit and allowance-reset assertions.
- **210–221:** a resting-face control that checks the hook's opening face balance survives the exact-output operation rather than being paid as this caller's output.

The base `contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol:114–121` constructs yield receipts and deploys their production ERC-4626 SEs. Thus the composition evidence is not an identity token masquerading as an SE. The orbital control is not itself the non-unit/mixed-local test; that boundary is exercised in the direct production SE regressions above.

No missing-test blocker is established: the production rule is directly supported by exact-asset payout semantics and current regression assertions. No additional test or production edit is proposed solely to force a historical red case or assume a non-compliant external vault.

## Facts, inference and limits

**Facts:** current helper uses withdraw, all three direct production callers pass their accounted due, reserve sync remains after settlement, and exact recipient-delta/non-unit-rate tests exist.

**Inference:** the historical rounded-redeem overdelivery mechanism is absent for the current supported dependency behavior. Local and withdrawn asset amounts sum to due; no receipt-rounding remainder needs to be forwarded or swept.

**Unverified:** runtime results in this review, historical source at filing, deployed bytecode and every possible external vault implementation. Ordinary ERC-4626 withdrawal semantics and supported underlying-token behavior are the stated boundary; this is not a promise about arbitrary malicious or non-compliant dependencies. No source search finding is treated as a substitute for a live execution trace.

## Files examined without a scoped defect

The Common helper and accounting/sync context; all three direct production caller files; NativeStandardYield dispatch; orbital exact-output unwrap; the R14 exact-payout and orbital capped-unwrap test ranges; orbital SE fixture construction; and the SimpleYield/CappedPausable withdrawal implementation. The controlling RC-02 text was available. All cited inputs were present; the assigned output was absent before writing. Repository routing and canonical testing/adversarial guidance were read directly earlier in this session.

Only this assigned Markdown report was created. No code, tests, PRD, original review, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop. No remainder should be sent to `feeTo`, and no remediation choice remains for this closed current-source finding.

Close RC-02
I did not run Forge.
