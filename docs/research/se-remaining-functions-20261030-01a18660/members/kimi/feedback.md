# Kimi advisory feedback

## Identity

- Member: Kimi
- Actual Native identity: not exposed

## Draft under review

- Draft ID: `se-remaining-functions-20261030-01a18660-r1`
- Path: `docs/research/se-remaining-functions-20261030-01a18660/coordinator/draft.md`
- Verified raw-file SHA-256: `694cdf6054d69b261f498825808e9a8c2f6dd1108b2a9ec0d732a3aa17520e15`

## Disposition

**Support with fidelity corrections.** The draft substantially states my original response accurately: I keep `previewZapCredit` and both cap getters, drop `previewWithdrawalMode`, and map `wrappedNative()` to `vaultTokens()`. It also accurately preserves my reasons that a same-input refund is not a per-currency credit split and that removing a getter does not remove a cap.

## Corrections

### Preserved disagreements — “Where the native face is named”

The statement that Grok's refusal to put `wrappedNative()` on the Position Repo “is not answered by the other three” is inaccurate for Kimi. My original expressly said: “do not move this getter to the Position Repo.” Correct the attribution to record that Kimi also rejected Position Repo placement while recommending that the family getter map to `vaultTokens()`. The companion **Coverage adopted from responses** row should not treat Kimi's Position Repo placement as open.

### Coverage adopted from responses — `previewWithdrawalMode`

“Map versus drop is wording” does not fully preserve my original classification. I explicitly recommended **drop rather than map**, because no single accepted preview covers both paired and single-token withdrawals and neither accepted preview returns the maintenance mode or reason. The **Proposed text** otherwise represents my position correctly: remove the selector, retain the internal maintenance choice, and use the accepted route previews for economic quotes.

## Limits

This feedback addresses fidelity to my original only. It does not resolve the preserved disagreements by voting, replace the draft, amend the PRD, or authorize implementation.
