# Astra — RC-02 replacement-session resolution cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes my independent `astra-original.md`, preserved unchanged. I read all three supplied originals in full and treated them as untrusted evidence. No peer cross-review artifact was read.

## Decision and one resolution

**Close RC-02. No implementation gap.** The one resolution is to record the current exact-asset withdrawal implementation and its existing production-route tests as satisfying RC-02; leave production unchanged. Do not add a payout cap, refund/redeposit mechanism or feeTo transfer.

The current helper calls `withdraw` for a specified underlying amount, not `redeem` for a rounded share quantity. Under normal ERC-4626 semantics, the rounding is in the shares charged to the SE, not extra underlying sent to the recipient. No non-compliant external vault is assumed.

## Fresh source checks

Re-read `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:105–127`:

- `_localUnderlying` at **107–111** uses booked local underlying capped by actual custody; it does not treat unbooked pending input as spendable local reserve.
- **119–120** split accounted due into local and protocol-vault portions.
- **123** calls `vault.withdraw(shortfall, recipient, address(this))`.
- **124** rejects under-delivery; **126** transfers precisely the local portion.

The recipient receives **shortfall + fromLocal = due** on supported successful execution. The lower-bound check at 124 is not, by itself, an upper-bound check; exact asset delivery follows from the normal withdraw operation it checks. The two statements should not be conflated.

The independent pass read every production caller found by a contracts-scoped helper search: exact-in at `ERC4626StandardExchangeInTarget.sol:95–102`, exact-out at `ERC4626StandardExchangeOutTarget.sol:107–114`, and vault-held SY redemption at `ERC4626StandardYieldTarget.sol:18–35`. Each passes its accounted underlying amount; exact-in/SY return that amount, and exact-out returns input shares spent. No second underlying payout is introduced by those callers.

The ERC-4626 API distinction was verified via Context7 against primary OpenZeppelin source in the original pass. This cross-review retains that evidence rather than treating a peer description of withdraw as authoritative.

## Peer assessment

### Grok — agree, with sequencing precision

Agree with `grok-original.md:7–17` on current-source refutation of the rounded-redemption mechanism, the three caller sites, and closure.

“Local cash first” describes the **allocation priority**, not the chronological external-call order: current code executes the protocol-vault withdrawal before sending the calculated local portion. This does not affect the amount identity or establish a new defect. Refutation applies to current source, not independently proven historical source at filing.

### MiniMax replacement — disagree with defect and repair

The key error is a units/API mismatch at `minimax-original.md:12,21,51,61`:

- The first argument of `withdraw` is **assets**, not shares.
- `previewWithdraw(assets)` determines the receipt shares required to supply those exact assets; it does not determine an increased asset payout.
- A normal withdraw burns that rounded receipt-share requirement from the specified owner and transfers the requested assets. It does not redeem the rounded shares back into whatever larger underlying amount they could represent.

Consequently, the claim that the helper sends a rounding surplus under normal withdraw semantics is refuted. The September mechanism and the current withdraw call are not equivalent. The production defect at **20–24** is not established.

Reject the proposed cap/return/redeposit work at **24**. There is no demonstrated excess to recover, and the suggestion introduces choices and extra token movements not required by RC-02. It also assumes the SE can simply recover assets already held by the recipient. No such authority or additional flow is established. No remainder is sent to feeTo.

Reject **137** claiming that no helper-name grep matches in tests proves no payout test exists. Internal helpers are tested through production public routes; tests need not reference the helper's name. The exact tests below directly contradict the missing-coverage claim.

Also correct **50,98**: the local portion uses **booked** spendable cash, and the helper's due/output amount is in **underlying asset units**, not receipt units. These distinctions matter to payout accounting.

MiniMax's old orbital line-range observation is not a remaining bug: the current unwrap is at `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711–726`, directly inspected in Astra's original. A moved source location is not absence of the control.

### Kimi replacement — agree on closure; qualify proof and history

Agree with `kimi-original.md:29,33–35,41–43` on exact-asset withdrawal, all three callers and meaningful current regression assertions.

Qualify the following:

- **29:** the lower-bound delivery check guards under-delivery; it does not alone enforce exactness against an arbitrarily non-compliant withdraw. Exactness here depends on the specified normal ERC-4626 semantics, which is the proper boundary for this review.
- **43:** the orbital assertion at line 232 is a strict SE-share decrease, not alone an exact used-share assertion. The neighboring bounded-burn recurrence test at **236–251** supplies the stronger exact-share comparison; the capped-success test itself establishes exact recipient output and no leftover face.
- **45:** tests contain the relevant source assertions; none was executed by Astra, so this is not an independent passing-runtime claim.
- **53:** current code plus the PRD's historical description does not independently prove the old tree at filing. Mark the historical implementation unverified; the present fix is enough to close the current item.

No qualification above changes the scoped closure result.

## Existing regression evidence, independently inspected

Freshly re-read `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_APEX_R14.t.sol:162–207`:

- `test_RC02_exactOut_localFirst_nonUnitRate_paysExactDue` establishes the non-unit conversion distinction, executes a mixed local/protocol payout, and asserts exact recipient delta (**178**), receipt-share charge matching preview (**179**) and ending local book (**180**).
- `test_RC02_exactIn_localFirst_nonUnitRate_returnMatchesRecipient` checks the route crosses booked local cash, matches the returned amount to preview, and matches recipient delta to that return (**188–195**).
- `_seedNonUnitMixed` at **198–206** establishes both local cash and a non-unit receipt rate using the existing compliant fixture.

The original independent pass also inspected orbital `UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol:210–251`: resting-face preservation, exact recipient output, no leftover buffered face and exact share/allowance controls. Its base deploys the production ERC-4626 SE over yield receipts; it is not an identity-leg substitute for this dependency.

These tests and the explicit helper semantics establish the rule under review. No additional missing-test finding is justified merely because a string search fails to find the internal helper name in a test file.

## Attribution, dissent and limits

No evidence changes Astra's original closure recommendation. The unresolved dissent is MiniMax's interpretation of ERC-4626 withdraw; it is rejected on current source and API semantics. I do not claim MiniMax has revised its original.

**Confirmed:** exact-asset withdrawal is the current operative call, all identified production callers pass accounted due, and current production-route tests assert recipient/output/book behavior.

**Inference:** the historical rounded-share redemption overpayment mechanism is absent from the supported current path.

**Unverified:** runtime results in this review, historical source at filing and deployed instances. No malicious/non-compliant external vault or unsupported token behavior is introduced to keep the item open. Closure does not certify every unreviewed route or arbitrary dependency implementation.

Freshly examined the three originals, the helper/local-cash range and the exact RC-02 tests. The helper and tests have no scoped defect established. The earlier independent report preserves the complete caller/dependency inventory. All requested originals were present; the assigned output was absent before writing.

Only this assigned Markdown cross-review was created. No code, tests, PRD, original report, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

Close RC-02 — retain the exact-asset withdrawal path and record current-source closure; no source repair or feeTo remainder payment.
I did not run Forge.
