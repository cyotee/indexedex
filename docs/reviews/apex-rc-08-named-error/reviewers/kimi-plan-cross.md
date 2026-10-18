# Kimi K3 — cross-review: RC-08 named-error plan notes

- **Label:** Replacement-session cross-review, resuming my plan review (`kimi-plan.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is a fresh replacement `ses_eaf8a39c8ffe7fWCgGG7aiDLg9` (does not recall `ses_eb8ab99f3ffe7suGF49ryUzI6t`). The three peer notes were read in full as untrusted output; the coordinator's routing note was verified against current source before acceptance. Nothing was edited.
- **Date:** 2026-10-18. I did not run Forge.

## The coordinator's note is confirmed; my Step 4 is withdrawn

Verified this round: `UniswapV2StandardExchangeInTarget.sol:730-731` carries a **third** blank revert of the same equality law on the `exchangeIn` path, and the `SecRemediation.t.sol:425` test's `vm.expectRevert(bytes(""))` follows a `vault_.exchangeIn(...)` call (`:426-428`) — so that expectation belongs to the InTarget guard, which is outside this PRD. My Step 4 (retargeting `:425` to `LPReserveMismatch`) would have broken that test against current routing. **Withdrawn in full.** Astra (`:57-67`) and MiniMax (`:74-82`) both got this right; MiniMax also verified the existing lower-bound test at `SecRemediation.t.sol:608-609` already expects `InsufficientLPBacking` and stays green. Recorded for a future item, not this one: the InTarget `:730-731` blank revert remains, out of scope here — the PRD names only the two OutTarget sites.

## The closed plan (one of each, no implementer choice)

- **Declaration (Astra/MiniMax agree, PRD `:35`):** one new error inside the existing `UniswapV2LpBacking` library, immediately after `InsufficientLPBacking`:
  ```solidity
      /// @notice Held LP differs from the booked LP reserve, in either direction.
      /// @custom:signature LPReserveMismatch(uint256,uint256)
      error LPReserveMismatch(uint256 held, uint256 booked);
  ```
  The owner's name is not reopened. **No helper function**: Grok's added `requireEqual` helper is declined — the PRD pins inline reverts at the two sites, and his test exercised the helper rather than the production guards, which is weaker evidence than the September evidence law requires.
- **The two sites (inline, `!=` preserved):** `OutTarget.sol:879-881` and `:1007` each become `if (held != booked) revert UniswapV2LpBacking.LPReserveMismatch(held, booked);` with the held value read once and `vaultLpReserve`/`vault2.vaultLpReserve` second (Astra's scoped-local form `:34-38, :47-52` and MiniMax's `:44-49, :65-69` are equivalent; either inline shape is the same edit). No weakening, no reuse of `InsufficientLPBacking`, no moved checks.
- **No existing test changes:** `:425` and the decimals twin's `:100` stay untouched (both are `exchangeIn` negatives). Verified, not assumed.

## The one new test file

`test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol`

(Astra's name, chosen over my draft's and MiniMax's shorter form: the sites are both `exchangeOut` routes and the sibling suite is `UniswapV2StandardExchangeOut_PassThrough.t.sol`; the "Out" keeps the routing family visible.) On the existing `TestBase_UniswapV2StandardExchange_MultiPool` fixture, covering both OutTarget guards with production calls plus matched-book success controls.

## The one assertion

```solidity
        vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, heldBefore_, bookedBefore_));
```

with `heldBefore_` captured as the vault's actual pool-token balance immediately before the call and `bookedBefore_` as the fixture's booked checkpoint (`0` on the fresh-vault fixture) — computed in-test, never hardcoded (my draft's `(donate_, 0)` literal is withdrawn in favor of the computed form; Grok's `(3, 2)`/`(1, 2)` literals against a self-exposed helper are rejected with the helper). If a run shows different bytes, stop and report them; do not weaken `!=` and do not pick another error.

## Command

MiniMax's targeted form with the settled filename: production positional `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`, test-roots for the new file, `UniswapV2StandardExchange_SecRemediation.t.sol`, and its decimals twin (both must stay green unchanged); `-- -vv`, hermetic profile, no cache changes.

## Unresolved dissent

None surviving. The one real catch this round was the InTarget/OutTarget routing confusion; all three peers avoided or caught it, and my draft is corrected. Consensus is not proof — the named-error behavior is verified against current source, and runtime evidence belongs to the later authorized run.

test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol

I did not run Forge.
