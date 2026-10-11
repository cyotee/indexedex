# Astra — RC-01 implementer questions

## Answer

**No further owner decision about the required behavior is needed.** I found no requirement that permits two incompatible implementations while satisfying the PRD as a whole. The holder, caller gate, prohibited routing, permitted reuse mechanism and ordinary-EOA acceptance are settled.

There is **one incorrect V3 source locator that should be corrected in the implementation handoff**. It is a factual documentation issue, not an unresolved owner preference. Following that locator alone would not implement the PRD. I did not edit the PRD or any source.

## Why the behavior is settled

References below are to `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md` unless otherwise stated.

- **Holder selection:** lines 14 and 56–58 require the existing settlement to receive an explicit holder: the vault for internal balance, the original caller for ordinary redemption. Lines 62 and 71 require the requested burn only, without refunding other vault shares.
- **Ordinary holders:** lines 61 and 72 expressly exclude ordinary own-share redemption from the code-less-pretransfer rejection. Line 76 requires a code-less positive-control holder, not just a test contract.
- **Internal-balance callers:** lines 61 and 73 retain the initiating-caller bytecode check before burn. An implementation that removes this gate to make ordinary redemption succeed is not an allowed alternative.
- **Reuse mechanism:** lines 56–57 prohibit duplicating settlement and specify an internal call when inherited, otherwise delegatecall to the existing exact-input execution delegate. Lines 68–69 prohibit external exchangeIn self-calls and synthetic pretransfer after staging caller shares.
- **Base-route exception:** line 64 specifically permits the unchanged base false-flag delegatecall to exchangeIn. Read with that explicit exception, the broader “Neither path re-enters exchangeIn” wording at line 14 is not an owner decision between removing every base route and fixing only the offending overrides.
- **Already-conforming families:** lines 45–52 and 87 say to inventory and cite them, not refactor them merely to impose identical syntax. The stated Wings flag example therefore does not authorize the rejected V3 pattern of moving caller shares and changing the exchangeIn pretransfer flag.

## Incorrect locator — not a choice between two valid repairs

**PRD sentence, line 42:**

> “The V3 settlement burn that currently chooses `address(this)` or `msg.sender` from the pretransfer flag (`UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:29-49`). Give it the holder argument. Do not add a self-call to avoid that edit.”

The cited code does select those burn holders, but it is **the exact-output withdrawal function**, not the exact-input settlement identified elsewhere in this PRD:

- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:14–26` defines `executeZapOutWithdrawal`, calculates shares from desired output, and bounds them by a maximum.
- Its branches at `:29–49` and `:59–68` implement pretransfer credit/refund and exact-output payment.
- The cited yield target instead resolves the **In execution delegate** and invokes `executeZapOutExactIn` at `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:24–34`.
- Its offending ordinary path is separately visible at `:39–50`: caller-share staging followed by true-flag exchangeIn delegatecall.

**Why this does not require an owner preference:** lines 14, 56–58 and 62 already specify the existing redemption settlement, an explicit original holder, and the requested share burn. Line 57 names `executeZapOutExactIn`. Changing only the exact-output function named in line 42 would leave the offending ordinary override intact; it would fail lines 69, 72 and 76. Substituting exact-output economics for ordinary requested-share redemption is likewise not a second compliant interpretation.

The handoff should identify the actual existing exact-input settlement and its holder-propagation call chain. The erroneous locator is not a reason to preserve the true-flag workaround, recreate an external self-call, or infer a separate exact-output redesign. No code change is authorized by this clarification.

## Residual risks that are not owner questions

1. **Wrong-function implementation from the locator above.** A change can look responsive to line 42 while leaving ordinary holders rejected. The explicit acceptance criteria already reject that outcome.
2. **Inherited settlement versus copied settlement.** Legacy V4 `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutBase.sol:17–24` inherits InBase. Its existing exact-input path and two burn locations are at `UniswapV4StandardExchangeInBase.sol:121–155,157–198`. Propagating the holder through the existing helpers is implementation work; it is not an owner choice to duplicate the engine or retain the self-call.
3. **Preserving settlement protections during reuse.** Holder propagation must preserve the existing locking, payout, minimum and bookkeeping behavior. Correct call plumbing and production-proxy tests are engineering obligations, not permission to choose a weaker ordinary-holder policy.
4. **Incomplete verification.** Separate legacy V4 and V3 assertions are already mandated at lines 72–76. A contract-only ordinary-success test or one passing family is insufficient by the PRD's own wording. No test was run here.

## Scope and stop

Read the complete 94-line PRD. Re-read only the cited V3 yield target/exact-output delegate and legacy V4 settlement/inheritance source to resolve the locator and reuse statements. No other reviewer file was read. No new defect review, unrelated-family review, shell, build, test, source edit or PRD edit was performed.

**Owner questions: none.** The V3 locator correction should be carried into the handoff as a factual correction; the required behavior is already settled. Stop.
