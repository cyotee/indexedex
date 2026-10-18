# Astra — REQ-05 replacement-session plan cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes `astra-req05-plan.md`, preserved unchanged. I read all three supplied original drafts in full. Peer text and coordinator notes were treated as untrusted evidence; no peer cross-review artifact was read.

## Decision

**No blocking question.** Retain the exact three-file implementation in Astra's original sections “Exact edits” 1–4 and its single validation command. Use **`token0` and `address(this)` in all three files**, and the measured token surplus—not minted shares—as credit. The only newly added `exchangeIn` in each test is the rejecting `credit + 1` call. Preserve the pre-existing successful continuation after the new rejection checks.

No original Astra implementation recommendation needs reversal: it already uses those choices and decimal-aware wings sizing. This cross-review closes the peer disagreements explicitly below; it does not authorize implementation.

## Coordinator notes independently checked

1. **Confirmed:** fresh read of `TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol:35–37` shows creation of 6- and 18-decimal tokens followed by an address-based swap of the variables. Neither post-sort name has an intrinsically fixed decimal count. Line **49** binds `wings0` to the final `token0` target.
2. **Confirmed:** controlling PRD **32,36–39** defines credit as held token balance minus stored book before the rejecting request. It requires no intervening successful deposit. A share balance delta is a different quantity and is not its credit oracle.
3. **Confirmed route relevance:** fresh read of wings production `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:81–91` shows true-flag `_pull` checks the caller, computes available target-token custody above its local book, and rejects a request above that availability. This is a token-delivery check, not a caller share-balance check. No production change is needed to implement the requested test.

## Peer agreements and objections

### Grok

Agree with the preflight, placement before the existing deposit, measured surplus/revert shape and test-only command.

Reject `grok-req05-plan.md:21,48–54`: `token1` is not guaranteed to retain 18 decimals after sorting, and `token0` is not guaranteed to retain 6. More importantly, `wings0` targets `token0`; choosing its opposing token could test route rejection instead of the required target-token credit check. Use token0 throughout, with wings' amount derived from its actual decimals. Do not use the suggested wings token1 call.

### MiniMax replacement

Agree with choosing the test contract and token0, but reject the proposed new test sequence:

- **100:** all three token0 fixtures are not statically 18-decimal; wings sorts mixed-decimal tokens.
- **102–104,127–135,151–159,175–183:** the inserted successful deposit consumes/books the transferred input before the intended rejection. Its minted-share delta is neither available token credit nor guaranteed to equal a raw token amount. The following call then measures a different accounting boundary. Remove the new successful call entirely and calculate credit directly from custody minus book before the single rejecting call.
- The snippets also omit the PRD's post-rejection custody/book/supply checks. Include them as pinned below.
- **199–203:** the test paths must be passed as repeated `--test-root` consumers, not as edited production positional sources. Use the one command below.
- **231–232:** do not leave token top-ups or caller/route/error selection to the implementer. Use the existing funded test contract and stop on a failed precondition; do not modify fixtures or substitute an expected error.

### Kimi replacement

Agree with the block's ordering, balance-minus-book calculation, rollback assertions and repeated-test-root command. Reject **9,24** assigning six decimals to wings token0 from its pre-sort construction. Use `7 * 10 ** uint256(token0.decimals())`, not a fixed six-decimal amount. Its line 57 must be read as a required future outcome, not an observed green run; no compilation/runtime result is established here.

## Closed edit specification

Change only `test_outsidePoolTradeDoesNotRefreshVaultBook` in:

1. `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol` — insert the rejection block after original line **42**.
2. `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol` — after original line **45**.
3. `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol` — after original line **36**.

Use the literal assertion blocks in the preserved Astra original, with this fixed sequence and no substitutions:

1. Immediately before the existing outside trade, capture `heldBeforeTrade = token0.balanceOf(subject)` after the existing supply snapshot. `subject` here denotes `address(vault)` for each FullSpread test and `address(wings0)` for wings; the original supplies the explicit expressions, not a new variable or helper requirement.
2. Keep the existing direct pool trade and both book/supply invariance assertions unchanged.
3. In a local scoped block, assert the test caller has bytecode and custody covers `book0`. Record `unbookedBefore = heldBeforeTrade - book0`. Assert current vault token0 custody still equals `heldBeforeTrade`, so the outside trade has not added held input.
4. Transfer **`7 ether` of token0** in hookless and Pons. In wings transfer **`7 * 10 ** uint256(token0.decimals())` of token0**. Assert transfer success. No new mint, EOA prank or external actor is introduced.
5. Read `held` and `booked` after transfer, assert `booked == book0`, compute **`credit = held - booked`**, and assert **`credit == unbookedBefore + transferAmount`**. Credit remains denominated in token0 units; vault shares are only the requested output asset.
6. Expect the complete encoded `ISecurePullErrors.TransferDeltaInsufficient(credit + 1, credit)` and immediately execute the one new call specified below. Do not insert an intervening preview, read, synchronization, rebalance or successful deposit between expectation and call.
7. After rejection, assert the vault's token0 balance equals `held`, its token0 reserve equals `booked`, and its total share supply equals the original `supply`. The custody baseline is **after transfer**, not before it. The separate prior transfer remains held after the later call reverts.
8. Leave the existing funded continuation and all other tests unchanged. Its preview parity remains supplementary and is not cited as this proof.

### Exact new calls and expected error

For **each** FullSpread file:

```solidity
vm.expectRevert(
    abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, credit + 1, credit)
);
vault.exchangeIn(token0, credit + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp);
```

For **wings**:

```solidity
vm.expectRevert(
    abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, credit + 1, credit)
);
IStandardExchangeIn(address(wings0)).exchangeIn(
    token0, credit + 1, IERC20(address(wings0)), 0, address(this), true, block.timestamp
);
```

No extra imports are required by the original blocks. Caller and recipient are the existing test contract `address(this)`; no `vm.prank` is added. Leave V3 LocalBook unchanged and cite its existing proof. No production edit, catch, custody redesign, legacy V4 restoration, duplicate V3 test or new file.

## One validation command for later authorized execution

From IndexedEx root, default hermetic profile:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol \
  -- -vv
```

Run the three whole files, with no production positional source and no test-name filter. Preserve `out/` and `cache_forge/`; do not enable `via_ir` or change compiler profiles. If any cited source anchor drifts, stop and report. If an assertion, exact revert or original continuation fails, stop and report actual results; do not switch token/caller, change the fixed transfer rule, weaken the error, add a successful credit-consuming call, alter production or expand scope.

## Astra plan findings

| Finding | Severity / impact | File and line | Broken requirement and fix | Confidence |
|---|---|---|---|---|
| Post-sort wings decimal and token assumptions | Medium / wrong test domain or wrong-route rejection | `grok-req05-plan.md:21,48–54`; `kimi-req05-plan.md:9,24`; `minimax-req05-plan.md:100,171` | PRD requires the fixed whole-token amount for the actual selected token and its credit route; use target token0 and its actual decimals | High, directly verified sorting/target selection |
| Successful deposit consumes the intended credit and mixes units | Medium / invalid credit oracle | `minimax-req05-plan.md:127–135,151–159,175–183` | PRD requires available custody-minus-book followed by rejection; remove the inserted successful deposit, measure token credit and preserve rollback assertions | High from draft sequence and PRD |

These are defects in proposed test plans, not demonstrated production unearned-credit defects. Originals remain preserved. No peer is represented as having retracted its position. The coordinator's notes are confirmed on the direct evidence above rather than accepted as findings without inspection.

All requested originals were present. Freshly examined the mixed-decimal wings setup, target selection, wings input-credit guard and controlling PRD acceptance criteria; no additional scoped production defect was established. The assigned output did not exist before writing.

Only this assigned Markdown cross-review was created. No code, tests, PRD, final plan, original report, configuration or instructions were edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
