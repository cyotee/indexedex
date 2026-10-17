# Astra — REQ-V4-01 bounded question cross-review

**Ready. No additional owner decision is required on these two points.** I read all three supplied originals and re-read the separate REQ-V4-01/02 sections, the current yield helper and delegate wrapper, and the relevant explicit-holder plan sentences. Peer interpretations are not authority. My original remains preserved; no PRD or code was edited.

## 1. Must `executeNamedHolderRedemption` be deleted here? No

**Agree with Grok's bounded scope and MiniMax's one-file repair; dissent from Kimi's assertion that deletion is required.**

`docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:77` prohibits keeping the holder-taking wrapper **as the yield path**. It does not require deleting its declaration. The current hop is at `UniswapV4StandardYieldExecutionTarget.sol:29-34`; the separate wrapper declaration is at `UniswapV4StandardExchangeInExecutionDelegate.sol:13-18`. Replacing that hop with the inherited internal call satisfies the specified routing requirement without editing the delegate.

The older explicit-holder plan `:51-55` preserves the existing four-argument wrapper and prohibits adding a holder argument to that public wrapper. It does not supply a new instruction to delete this separate function in REQ-V4-01. Even if the function becomes unused, that fact alone does not make deletion mandatory under this item's acceptance text.

**Closed sentence for the new PRD:**

> In REQ-V4-01, remove the yield helper's call to `executeNamedHolderRedemption` by calling the inherited `_executeZapOutExactIn` internally; leave `UniswapV4StandardExchangeInExecutionDelegate.sol`, including `executeNamedHolderRedemption` and the existing four-argument wrapper, unchanged, and do not retain either delegate wrapper as the yield-redemption route.

This fixes the scope rather than leaving optional cleanup to the implementer. It does not certify every possible future use of the retained declaration.

## 2. Must REQ-V4-02's disable check be included here? No

**Agree with Grok and retain my original separation; dissent from Kimi's proposed combined repair as a mandatory consequence of REQ-V4-01.**

The application PRD assigns internal settlement to REQ-V4-01 at `:68-80` and disable rejection to a separate REQ-V4-02 at `:82-93`. The latter requires the existing disable check before burn and preserves the lock/TWAP update. The older explicit-holder plan `:70` confirms that disable behavior remains required; it does not require these separately identified items to be implemented in one session.

Sharing `_settleNamedHolder` as an edit location does not merge their scopes. Current `UniswapV4StandardYieldExecutionTarget.sol:26-35` already has the reentrancy modifier and post-settlement TWAP call; those must remain during the routing edit. Leaving the separately tracked missing disable check for REQ-V4-02 is not an owner amendment allowing disabled redemption and must not be reported as closing that item.

**Closed sentence for the new PRD:**

> This PRD implements REQ-V4-01 only: preserve `_settleNamedHolder`'s existing `nonReentrant` modifier and post-settlement `_pokeBoundPoolTwap()` call, do not add or otherwise change disable-check behavior in this item, and leave REQ-V4-02's required disable-check repair separately open without claiming it is satisfied or waived.

## Owner questions

None. The recorded split permits a choice-free bounded PRD using the two sentences above. Deleting unused infrastructure or combining separately tracked repairs would expand this item's scope; neither is necessary to satisfy the recorded internal-call requirement.

I did not run Forge.
