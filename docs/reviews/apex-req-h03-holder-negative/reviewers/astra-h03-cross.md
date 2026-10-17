# Astra — REQ-H03 replacement-session cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes my successful original `astra-h03.md`, which remains preserved. I read all three supplied original reports in full: `grok-h03.md`, `minimax-h03.md`, and `kimi-h03.md`. They and the coordinator's notes were treated as untrusted evidence. No peer cross-review artifact was read.

## Decision and closed recommendation

**No blocking question. Agree with Grok and retain Astra's original recommendation. Disagree with MiniMax and Kimi's custom-error recommendation.**

The current holder-burn failure is exactly **`Panic(uint256)` with argument `0x11`**, not `ERC20InsufficientBalance(address,uint256,uint256)`.

The single closed alternative to the two dissenting peer recommendations is:

> In `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`, replace only the bare expectation with `vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));`, preserving the existing call, holder, balance assertions and all other tests; add no import and make no production change.

Do not add a catch, change the holder argument, replace the code-less ordinary-success caller, or restore the withdrawn legacy V4 twin. This report recommends the test edit; it does not implement or authorize implementation.

## Independently rechecked source facts

The coordinator's factual route notes are confirmed by direct fresh reads, not accepted on authority:

1. The test at **142–152** still has a bare `vm.expectRevert()` at 147 and ordinary `redeem(..., false)` at 148. Holder/vault/recipient assertions remain at 149–151.
2. `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:30–44` dispatches the ordinary route through the virtual `_standardRoute` at 41.
3. `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18–29` overrides that route: line 22 supplies `msg.sender` to `_settleNamedHolder`, and line 29 passes the holder to `_executeZapOutExactIn`. It does not fall through to the base `_exchangeIn` route for this ordinary self-share input.
4. `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:212–261` burns that holder through `ERC20Repo._burn` at 236 in the sleeve branch or 257 in the unlocked branch.
5. `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:376–377` invokes the storage overload. At **361**, the call to `_decreaseBalanceOf` is commented out; **362** directly subtracts from the holder's stored balance using checked arithmetic. No surrounding `unchecked` block is present.
6. The custom error at `ERC20Repo.sol:229` belongs to the separate `_decreaseBalanceOf` function at 222–232. Its existence does not make it the error emitted by `_burn`.

Thus `BasicVaultCommon._secureSelfBurn` is not the ordinary SY route shown here. The checked-subtraction error semantics were verified against Solidity primary documentation via Context7 in my original pass: arithmetic underflow/overflow outside `unchecked` uses `Panic(uint256)` with code `0x11`.

The controlling application PRD at **138–148**, freshly re-read, requires the holder-balance error **for this route**. It does not require replacing the existing burn with a custom-error implementation or identify a wrong holder argument.

## Peer review

### Grok — agree

`grok-h03.md:10–20` correctly traces ordinary redemption to the explicit caller holder and direct checked burn subtraction. Its one-line encoded-panic expectation matches my original recommendation and the freshly inspected code. No correction needed to its scoped fix.

### MiniMax replacement — disagree with the selected error and inferred production gap

`minimax-h03.md:80` accurately acknowledges that the actual burn produces `Panic(0x11)`. That fact contradicts its headline at 12, conclusion at 87 and proposed expectation at 109 naming `ERC20InsufficientBalance`.

The PRD does not elevate the unused helper into the required production behavior. Calling it “canonical” at 20 is not call-chain evidence. The proposed restoration of `_decreaseBalanceOf` at 82 is a separate production redesign, not necessary to close REQ-H03 and not justified as a defect by this PRD. Reject that additional work for this item.

Also reject line 65's claim that unchanged balances and a zero minimum exclude unrelated quote/pool/route failures. Atomic reversion can preserve balances for many failure causes, and a zero minimum does not suppress other errors. That is why the bare expectation is inadequate in the first place. Upstream execution success was not dynamically verified in this review.

The closed correction is the encoded `Panic(0x11)` expectation above, with no `IERC20Errors` import and no production edit. MiniMax's instruction to pick between forms at 107 is unnecessary; there is one specified assertion here.

### Kimi replacement — disagree with the call trace and selected error

`kimi-h03.md:17–19` omits the concrete V3 `_standardRoute` override, incorrectly routes through `BasicVaultCommon._secureSelfBurn`, and attributes the helper's line-229 error to `_burn`. Fresh source reads contradict all three steps for this test.

The other tests cited at 21 do not establish the error on this path. An allowance-free ordinary redemption does not imply which burn helper runs. The unused-helper custom error therefore cannot justify the import or expectation at 27–30, or the closure sentence at 44.

Kimi's hypothetical future token-implementation substitution at 40 is speculation, irrelevant to the current closed test repair. No implementer choice between token implementations or error variants is needed. Its preservation requirements and refusal to weaken production are otherwise appropriate.

## Retained Astra finding — H03-1

- **Title:** Insufficient-holder negative accepts unrelated failures.
- **Severity:** Low.
- **File and line:** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol:147`.
- **Intended behavior:** Pin the production holder-insufficiency failure for ordinary V3 redemption and preserve unchanged holder, vault and recipient balances, plus code-less ordinary-success coverage.
- **Broken invariant:** Bare `vm.expectRevert()` accepts failures unrelated to holder insufficiency; balance rollback does not identify the cause.
- **Impact class:** Test-oracle specificity / regression detection.
- **Fix direction:** Use the exact full encoded `Panic(uint256)` with code `0x11` specified above, without modifying production or adding a catch.
- **Confidence:** High on source and compiler-defined burn behavior; no runtime verification claimed.

No revision to the original finding or fix is required. The peer reports add no evidence that changes my view of the actual error. Unresolved dissent is specifically MiniMax/Kimi's proposed custom-error expectation; I do not claim that either peer has revised its position.

## Limits and disposition

**Confirmed:** explicit caller-holder selection, the two burn sites, direct checked subtraction, the unused custom-error helper, the bare current expectation, and the PRD's test-only scope.

**Unverified:** the full test's runtime path and passing result after the recommended edit. A matching `Panic(0x11)` is narrower than any revert but is not a unique source-location identifier; another arithmetic failure with that code could also match. This limitation does not authorize manufacturing a new production custom error. If later authorized validation fails, stop and diagnose rather than broaden the expected error.

Files freshly examined without another scoped production defect: `NativeStandardYieldTarget.sol:30–44`, the V3 `UniswapV3FullSpreadStandardYieldExecutionTarget.sol:18–29`, `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:212–261`, and Crane `ERC20Repo.sol:222–232,350–378`. The test retains the known H03-1 gap. All three requested original reports and the controlling PRD were present; the assigned output did not exist before this write.

Only this assigned Markdown cross-review was created. No original report, code, test, PRD, plan, configuration or instruction file was edited. No delegation, shell, build, deployment or tests were used. Return to the coordinator/human and stop.

I did not run Forge.
