# Astra — REQ-V4-01 plan readiness

**Ready. No unanswered owner decision is needed before writing the implementation plan.** I read the current controlling PRD in full, the three named current contracts in full, and only the inherited settlement declaration. No other reviewers' notes were read. This is a readiness assessment, not the implementation plan or authorization to edit code.

## Controlling decisions are now explicit

`docs/reviews/apex-req-v4-01-internal-settlement/REMEDIATION_PRD.md:9,37-38` records a new owner ruling: delete both legacy V4 redemption delegate wrappers and reroute the already-funded public share exit internally. This supersedes the earlier bounded proposal to leave the wrappers untouched. REQ-V4-02 remains separate (`:34,57`). Neither choice should be referred back to the owner.

The “edit only the body” sentence at PRD line 24 is read as limiting the edit within the yield target, not as overriding the expressly required changes to the other two files at lines 37-38. The duplicate item number does not create a substantive choice.

## Mechanical closures the plan must state

### 1. Edit the two callers before deleting their targets

First change `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol:26-35`:

- Keep `_settleNamedHolder`'s signature, named return, and `nonReentrant`.
- Replace the delegatecall, manual revert bubbling, and return-data decode with exactly:

```solidity
amount_ = _executeZapOutExactIn(tokenOut_, shares_, minimum_, receiver_, holder_);
```

- Retain `_pokeBoundPoolTwap()` after successful settlement. Do not replace this with an immediate return that skips the poke.
- Leave `_redeemVaultHeld` and `_standardRoute` unchanged: they select `address(this)` and `msg.sender`, respectively (`:11-23`).

Second change the public share-input branch in `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol:79-83`. Keep `_secureShareDelivery` before settlement, then replace its delegate helper invocation with exactly:

```solidity
amountOut = _executeZapOutExactIn(address(tokenOut), actualIn, minAmountOut, recipient, address(this));
```

The `address(tokenOut)` conversion follows the current caller's `IERC20` parameter and the inherited declaration's `address` parameter. Passing `address(this)` is already decided: these shares were delivered onto the vault. Do not substitute `msg.sender` or change pretransfer semantics. Keep the following TWAP update and return, and preserve the existing public entry's guards, including its already-present disable check at line 55.

The inherited function at `UniswapV4StandardExchangeInBase.sol:146-152` already has the five required parameters. Do not change its signature or copy its body.

### 2. Delete only the specified redemption indirection

After updating both callers:

- Delete `_delegateExecuteZapOutExactIn` from `UniswapV4StandardExchangeInTarget.sol:101-118`.
- Delete `executeNamedHolderRedemption` and its attached comment from `UniswapV4StandardExchangeInExecutionDelegate.sol:12-18`.
- Delete the four-argument `executeZapOutExactIn` wrapper from that delegate at `:27-34`, including its attached body comments.

Keep the execution-delegate contract, `executeZapInDeposit` (`:20-25`), and the deposit delegatecall in InTarget (`:89-99`). Keep the delegate address/constructor wiring because deposit settlement still uses it. Do not add replacement external redemption wrappers. Do not extend the edit into unrelated declaration cleanup; untouched declarations outside the specified functions can remain even if no longer referenced.

### 3. Preserve scope and prevent substitutions

- Do not add `_requireNotDisabled` to the yield helper; REQ-V4-02 remains open and is not waived.
- Do not add a new minimum-output error/check or a second reentrancy lock.
- Do not change V3, hookless, or Pons functions with matching names.
- Do not restore a self-call, retain a redemption delegate hop, paste the settlement engine, or delete legacy V4.
- Verify that the two removed wrapper names are no longer referenced as legacy V4 redemption call targets. A new unexpected caller is a source fact to report, not permission to reroute it ad hoc or change another family.

### 4. Build, measure the named deployed unit, and run the existing suite

The deployed runtime to measure is **`UniswapV4StandardExchangeInFacet`**, not the abstract yield target or the remaining delegate. PRD line 41 explicitly selects it and the **24,576-byte** limit.

The plan must name the three edited production sources when refreshing affected runtime artifacts through the repository's `scripts/forge-artifacts.py` workflow before testing. Measure the freshly built facet runtime, not creation bytecode or a stale artifact. If it exceeds the limit, stop and report its measured size; do not restore delegation or enable `via_ir`.

The existing test file, confirmed present, is:

`test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`

Re-read it during implementation and run it against refreshed artifacts, as required by PRD line 66. Do not rewrite assertions to bless the old hop or claim a pass from source presence. Report the actual commands, toolchain, facet runtime size, and test result. If a test conflicts with the required removal rather than observing holder behavior, report that precise conflict instead of silently expanding the repair.

## Owner questions

**Blocking: none. Non-blocking: none.** Internal settlement, wrapper deletion, public-share holder selection, preservation of deposit delegation, exclusion of the yield disable repair, and the size-failure disposition are all recorded. A future compile, size, or test failure is a stop-and-report result, not an unresolved owner choice needed to author the plan.

Only this assigned readiness report was written. No implementation plan file, PRD, source, test, configuration, or script was edited.

I did not run Forge.
