# Astra — RC-06 orbital unwrap workflow

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes were read, including the prohibited RC-06 unwrap reviewer directory. The controlling RC-06 section in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:146–157` was freshly read successfully. No guard denial occurred.

## Plain-English answer

**No remaining defect** was established on the inspected RC-06 path.

The orbital hook holds some of its trading inventory as **Standard Exchange shares**, rather than as immediately spendable output tokens. When a trade owes the user a specified amount of output tokens, the hook must first convert enough of its own SE shares into those output tokens. `_unwrapExactTokenOut` performs that conversion into the hook's custody. Its caller then pays the recipient or settles with PoolManager.

**“Returns nothing” means no Solidity return value. It does not mean no operation occurs.** This helper grants a bounded allowance, calls the SE to obtain output tokens, resets the allowance and verifies delivery. The SE-share balance and output-token balance change through those calls. A helper can perform that work without returning a numeric receipt to its caller.

The old RC-06 problem concerned a misleading numeric receipt: the helper purported to report shares spent but returned the approval ceiling instead. Current source has **no such return value**, and callers do not request one. That specific defect is closed; there is no need to invent a replacement share ledger or returned spend count.

## What the unwrap does now

File: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711–727`.

1. **No unnecessary conversion:** if requested output is zero, return; if the configured SE is the output token itself, return because no separate share-to-token conversion is needed (**712–714**).
2. **Determine what inventory is spendable:** obtain the hook's SE-share allowance budget from `_spendableSeShares` (**715**). That helper at **649–654** reads the hook's actual SE balance and leaves the configured one-native-share-unit liveness remainder. Zero spendable inventory is rejected.
3. **Ask how many shares the exact output requires:** `ClaimLib.invertUnwrapExactTokenOut` at **717** calls the SE's `previewExchangeOut` for the specified output amount (`UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:524–531`). The unwrap rejects a zero quote or a quote above spendable inventory (**718**).
4. **Approve only that quoted share amount:** `maxIn` equals the quote, and the SE receives that bounded approval (**719–720**). This is an input ceiling, not a reported actual spend.
5. **Request the specified output:** the SE `exchangeOut` at **722–724** is called with the hook's SE shares as input, the quoted maximum, the requested output token/amount, the hook itself as recipient, and the false pretransfer flag. The SE pulls/consumes the shares required by its exact-output route.
6. **Clear approval and verify received tokens:** approval is set back to zero (**725**); the new output-token balance minus the opening balance must be at least the requested output (**726**), otherwise the call reverts.

The output check measures the operation's new delivery, so an already-resting output balance is not counted as satisfying the unwrap. It is a lower-bound check, not an equality assertion. Exact-output semantics come from the supported SE operation; the quoted input ceiling alone is not a proof that an arbitrary dependency cannot over-deliver. No non-compliant dependency or new surplus defect was demonstrated here.

The SE's return value is ignored. That is consistent with a void settlement helper: callers depend on the token movement and delivery check, not on a fabricated share-spend number. Unused approval does not become a refund, and the helper does not pay its unused share ceiling to anyone.

## Who calls it and where the tokens go next

A contracts-wide reference search, followed by reading the orbital call paths, found three direct orbital callers.

### 1. PoolManager swap callback

`UniswapV4StandardExchangeOrbitalBufferHookHooksTarget.sol:278–325` is the hook's `beforeSwap` entry. It verifies PoolManager identity and locks the operation at **283–284**. In its exact-output branch, **308** calls `_swapExactOutExecute`.

Common **750–764** computes the trade's input requirement and calls `_unwrapExactTokenOut` at **758** if the output leg is SE-backed. Raw unbuffered output instead uses the raw reserve branch.

After the unwrap has supplied the output tokens to the hook, the callback:

- takes the input from PoolManager at **312**;
- buffers that input into its SE or updates raw inventory at **314–318**;
- settles the requested output to PoolManager at **319**;
- recomputes and synchronizes accounting at **320–321**, then unlocks at **324**.

Common `_settle` at **528–532** synchronizes the currency with PoolManager, transfers the specified amount to it and settles. The unwrap is therefore **not** the final user payout on this route; it supplies the inventory needed for PoolManager settlement.

### 2. Public SE exact-output swap

`UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol` exposes the exchangeOut wrapper at **259–262**, which dispatches through `_entryExchangeOut` at **115–117**. Liquidity routes are separate; the swap route enters `_swapExchangeOut` at **120–157**.

That function is nonReentrant, validates the route/deadline/recipient, quotes and bounds the user's input, then pulls or credits it (**128–139**). For SE-backed output it calls the unwrap at **144**. It then buffers the input leg, recomputes reserves, transfers exactly the specified output to the recipient and synchronizes at **148–155**.

The caller's `amountIn` return describes the **hook trade's input**, not SE shares consumed internally by the output unwrap. No return from `_unwrapExactTokenOut` is assigned or reported.

### 3. Owner exact-output swap

SeTarget's public owner wrapper at **268** reaches `_entryOwnerSwapExactOut` at **184–200**, which checks ownership, deadline, route and the maximum, then securely pulls the quoted input. `_payOwnerSwap` calls the unwrap at **213**.

`_finishOwnerSwap` and `_finishSwap` at **220–234** buffer/update the input, recompute accounting, transfer the specified output to `msg.sender` and synchronize. Again, the owner entry returns the separately quoted trade input, not a supposed output-leg share spend.

All three direct unwrap invocations are statement-form calls without assignment. No caller expects a deleted return value.

## Is the workflow executed correctly?

**By source inspection, the workflow is connected and performs the required settlement; I did not execute it.**

- Buffered output is obtained before the outer route pays or settles it.
- The requested SE share quote must fit actual spendable inventory before approval.
- Approval is bounded and reset on success.
- Short delivery reverts, and no catch in the inspected unwrap/caller sequence converts that failure into success. Transaction rollback applies to the operation's state changes.
- The enclosing swap paths retain their reentrancy protection and complete reserve synchronization after settlement. Common **569–578** refreshes the vault-facing reserve entries; it does not depend on a returned share count from the unwrap.
- No approval-cap value is assigned to a returned share-spend variable.

This establishes source-level conformance to RC-06. It is not a fresh passing-run claim, nor a complete audit of every possible token, SE implementation or pool state.

## Existing production-route tests inspected

`test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol:224–274` includes:

- **224–234:** funded capped unwrap checks exact recipient output and no leftover buffered face; its share-decrease assertion alone is not an exact-spend oracle.
- **236–251:** stronger recurrence control checks the SE-share balance decrease against the SE's exact-output quote, exact recipient output, exact user input debit and zero remaining SE allowance.
- **254–273:** an above-cap request expects the exact nested guard error, requires no SE execution call, and verifies balances and allowance remain unchanged.

These are meaningful executable assertions supporting the described path. The last test is a pre-execution cap rejection, not a fabricated short-delivery test; I do not claim it tests every failure stage. No test was run in this review, and no additional test or source repair is invented to revive the closed return-value issue.

## Why the earlier descriptions sounded inconsistent

Three different quantities/functions must not be merged:

- `_unwrapExactTokenOut` is **void** and performs exact-output settlement into the hook.
- Adjacent `_unwrapSeShares` at Common **699–708** performs an exact-input operation and returns `pairOut`, the tokens received—not an approval cap reported as share spend.
- Enclosing exact-output swap functions return `amountIn`, the input required for the hook trade—not the output SE's share debit.

Removing the first helper's return removes the misleading report without removing its token movement. The historical defect description is not an accurate description of today's function signature. The historical source at filing and timing of changes were not independently verified here.

## Disposition and limits

No remaining RC-06 path defect was found. The allowed return-removal resolution is implemented, the helper still does real settlement work, and its callers use that work correctly at the source level. No production change, new return value, second ledger or unused-cap refund is recommended.

Files freshly examined: controlling RC-06 section; orbital Common unwrap, spendable-share, settlement and synchronization ranges; HooksTarget callback; SeTarget public/owner swap dispatch and settlement; ClaimLib quote bridge; and the cited Apex008 regression range. All inputs were present. The assigned output was absent before writing. No prohibited reviewer artifact was opened.

Only this assigned Markdown report was created. No code, tests, PRD, original review, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

No remaining defect
I did not run Forge.
