# Astra — RC-08 replacement-session plan cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes my original `astra-plan.md`, preserved unchanged. I read all three supplied plan notes in full as untrusted evidence. MiniMax is the fresh replacement `ses_eaf8a39c8ffe7fWCgGG7aiDLg9`, without continuity with `ses_eb8ab99f3ffe7suGF49ryUzI6t`; its note is not treated as that earlier session's memory. No peer cross-review artifact was read.

## Closed decision

Keep the owner's error **`LPReserveMismatch(uint256 held, uint256 booked)`** in `UniswapV2LpBacking`. Factor the identical equality comparison into one internal pure library helper used by both OutTarget sites, and test that actual production helper in **one new file**:

`test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_LPReserveMismatch.t.sol`

Leave `UniswapV2StandardExchange_SecRemediation.t.sol:425`, its decimals counterpart and InTarget unchanged. No implementation choice remains. The new test is a focused test of the production comparison/error, not a claimed end-to-end mismatch reproduction.

**Revision of Astra's original:** withdraw the alternative filename and the proposed four route tests with unverified route preconditions. Adopt the single-helper design and focused test specified here. The original remains historical, not overwritten. This refinement prevents a diagnostic-only change from depending on speculative route construction while ensuring the tests execute the very predicate used at both production sites.

## Evidence resolving the existing-test dispute

Fresh reads confirm:

- `UniswapV2StandardExchange_SecRemediation.t.sol:425–428` expects blank bytes and calls **exchangeIn**.
- `UniswapV2StandardExchangeInTarget.sol:724–731` contains that route's distinct blank equality guard.
- The current PRD **35–39** names the two **OutTarget** equality guards and preserves the lower-bound helper.

Therefore changing the existing line-425 expectation would demand a different error from an untouched route. This is not an available implementation option. The decimals test also uses exchangeIn and stays unchanged. An existing import of `UniswapV2LpBacking` in SecRemediation does not alter that routing fact.

## Peer assessment

### Grok — adopt the shared production predicate; make test/file selection explicit

Agree with `grok-plan.md:15–39` on adding `requireEqual` in the owner-selected library and using it at both sites. It preserves inequality semantics without altering `requireHeld`. Agree with **43** that the exchangeIn test is not one of these two guards.

Adopt its uppercase-`LP` test basename. The final test below uses one exact expected-error assertion for arbitrary unequal unsigned inputs, plus an equality control. It calls the production helper through a trivial external test wrapper, not a copied predicate.

### Kimi — reject retargeting and route confusion

Reject `kimi-plan.md:36–42`: the old assertion is on exchangeIn and must not be changed. Also, the original SecRemediation file already imports `UniswapV2LpBacking` at line 16; another import is unnecessary.

Its **28,44** label the second equality guard as zap-out, but the source function is `_exchangeOut_passThroughZapIn`. The separate lower-bound zap-out check already has `InsufficientLPBacking`. Do not conflate the two or build tests against an incorrectly named route. Its additional mixed-case filename is not selected.

### Fresh MiniMax replacement — agree on exclusions; reject unresolved plan alternatives

Agree with `minimax-plan.md:74–82` that the exchangeIn assertion and decimals twin remain untouched, and with its owner-selected declaration and argument order.

Reject the unresolved scaffolding in **103–139**: sample amounts, an initial exchangeIn instruction followed by a correction, undefined fixture helpers, and instructions to find another route do not form a closed implementation plan. A successful named-error expectation must not depend on guessed route reachability.

Its **92** filename differs from the command at **185**. Only the single filename selected above is retained. Its **88** also mislabels the existing lower-bound focused test: that test calls an external wrapper around the production `requireHeld` helper; it is not an exchangeIn equality test. Leave it untouched.

## Exact implementation steps

### 1. Preflight

Recheck OutTarget's original **879–881**, **1007**, and `UniswapV2LpBacking` **1011–1020** against the current blank `!=` guards and unchanged `<` helper. Confirm no existing `requireEqual` or `LPReserveMismatch` declaration has appeared and the selected new test file is absent. If any anchor differs, stop and report; do not choose a replacement site or overwrite intervening work.

### 2. Declare the error and actual shared equality helper

In `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`, inside `UniswapV2LpBacking`, immediately after the existing error declaration, add:

```solidity
    /// @notice Held LP differs from the booked LP reserve in either direction.
    /// @custom:signature LPReserveMismatch(uint256,uint256)
    error LPReserveMismatch(uint256 held, uint256 booked);

    /// @dev Require exact LP custody/book equality; report held before booked.
    function requireEqual(uint256 held, uint256 booked) internal pure {
        if (held != booked) revert LPReserveMismatch(held, booked);
    }
```

Keep the existing `InsufficientLPBacking` declaration, its documentation and `requireHeld` body unchanged. This internal helper adds no public facet selector, external dependency or linked runtime library requirement. Do not guess a hexadecimal selector.

### 3. Replace both complete guards in place

Replace the complete original **879–881** block, including its closing brace, with:

```solidity
        UniswapV2LpBacking.requireEqual(indexSource.pool.balanceOf(address(this)), vault.vaultLpReserve);
```

Replace original **1007** with:

```solidity
        UniswapV2LpBacking.requireEqual(indexSource.pool.balanceOf(address(this)), vault2.vaultLpReserve);
```

Each site passes the same held and booked operands at the same execution point. The production predicate in the shared helper stays **`held != booked`**, rejecting both signs of mismatch. The first call stays after fee calculation and before the zap-in quote; the second stays after the existing state reload and payout/refund sequence. Do not reorder money movement or change refunds, comparisons, accounting or payout amounts.

### 4. Exactly one new test file and one expected-error assertion

Create the single selected file with contract `UniswapV2StandardExchange_LPReserveMismatch_Test`, inheriting `Test` from `forge-std/Test.sol`, and importing `UniswapV2LpBacking` from the production OutTarget source. It is a pure production-library comparator test; no vault mock, fabricated vault storage or new SUT implementation is introduced.

Use these exact test bodies:

```solidity
    function testFuzz_RC08_lpReserveMismatch_reportsHeldAndBooked(uint256 held, uint256 booked) public {
        vm.assume(held != booked);
        vm.expectRevert(abi.encodeWithSelector(
            UniswapV2LpBacking.LPReserveMismatch.selector, held, booked
        ));
        this.exposeLpReserveEquality(held, booked);
    }

    function testFuzz_RC08_matchingLpReserve_passes(uint256 amount) public view {
        this.exposeLpReserveEquality(amount, amount);
    }

    function exposeLpReserveEquality(uint256 held, uint256 booked) external pure {
        UniswapV2LpBacking.requireEqual(held, booked);
    }
```

The single encoded-error assertion verifies both values in the owner's order for unequal inputs; the equality control verifies the permitted boundary. The production helper contains no arithmetic capable of confusing the result with a deficit-underflow panic. The external wrapper only creates a call boundary for the test expectation and executes the real production helper.

Do not add a second filename, edit any existing expectation, or claim this unit check proves a supported route naturally reaches either mismatch. Static call-site inspection establishes that both named production guards use this helper. Existing successful route tests provide the surrounding regression controls.

### 5. One validation command for later authorized execution

From IndexedEx root, default hermetic profile:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2 \
  -- -vv
```

The changed source drives artifact refresh; the whole directory includes the selected new test and the untouched exact-input, lower-bound and success controls, including concrete decimal suites. No test-name filter. Preserve `out/` and `cache_forge/`; do not enable `via_ir`, change profiles or deploy anything.

If compilation, expected bytes, or any existing test fails, stop and report. Do not retarget line 425, modify InTarget, weaken `!=`, reuse the lower-bound error or add an alternative production fix. No command is run by this reviewer.

## Attribution and limits

The owner-selected name and library location are fixed; the new internal helper merely centralizes the exact existing predicate for direct testing. This is a diagnostic error improvement, not a demonstrated payment vulnerability or a custody-policy change. Consensus and a focused test would not prove unreviewed routes safe.

The fresh MiniMax report was present despite the PRD's historical plan-round note saying the earlier session had not saved one. That later report's presence does not erase the earlier session failure or confer continuity. No original artifact was rewritten.

Files freshly examined: the three plan notes, controlling PRD in full, the existing exchangeIn test and its InTarget equality guard. The original independent plan preserves the OutTarget guard/context and existing-test search evidence. The out-of-scope exchangeIn guard has no new defect alleged here; its unchanged blank expectation remains correct for that unchanged route.

Only this assigned Markdown cross-review was created. No code, tests, PRD, final plan, original report, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_LPReserveMismatch.t.sol
I did not run Forge.
