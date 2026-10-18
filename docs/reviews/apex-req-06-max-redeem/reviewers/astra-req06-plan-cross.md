# Astra — REQ-06 replacement-session plan cross-review

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This resumes my original `astra-req06-plan.md`, preserved unchanged. I read all three supplied original drafts in full. Peer drafts and the coordinator note are untrusted evidence; no peer cross-review artifact was read.

## Decision

**No blocking question. Close the plan to the share-balance return, deletion of both search helpers, and balance-equality assertions in the named tests. No shortfall expectation.** Retain the bounded implementation in Astra's original, restated below with exact edits and one validation command.

## Coordinator note checked against source

Fresh read of `ReceiptBackedERC4626_SharedFacet.t.sol:167–190` confirms the fixture funds `u`, approves the vault, and executes the token-input deposit at **179** before the maxRedeem assertion at **183**. The zero receipt balance at **181** is not the owner's vault-share balance.

MiniMax's claim that this user deposited zero shares and must still have zero maxRedeem is unsupported. The controlling PRD **39–44** expressly requires the assertion to compare with the actual owner's share balance, not zero. No hardcoded share quantity is needed: read `IERC20(se2).balanceOf(u)`.

## Peer assessment

### Grok — agree on policy and SharedFacet; correct dangling reference

Agree with `grok-req06-plan.md:15–25,43–51`: exact return after family validation, both helpers removed, SharedFacet balance equality, deleted obsolete redeem rejection, and preserved exclusions.

Reject the incomplete behavior deletion at **29**: replacing only original **202–211** leaves original **212** referring to the deleted `paid` local. Fresh source confirms that dependent receipt-debit assertion. Remove the full obsolete tail through 212 and its no-longer-needed held-receipt premise, as specified below. This is a closed deletion, not an implementer choice.

### MiniMax replacement — reject zero-balance claim, retained capped redemption and incomplete command

- **235–243:** retaining zero maxRedeem with a new “user holds zero shares” message contradicts the owner-selected rule and does not follow from the fixture. Use actual balance equality.
- **195,277,302:** retaining the former capped-redemption/payout leg while admitting it may fail leaves the withdrawn cap scenario in the plan. Remove that obsolete leg and dependent assertions. Do not replace it with a new shortfall rejection or ask the implementer to decide the expected outcome.
- **62–65,172:** the cited test name `test_maxRedeem_paymentIsCappedByHeldReceipts` is not the current name; fresh source uses `test_maxRedeem_capsWhenHeldReceiptsCannotPayFullBalance` at **190**. Use the verified anchor, not the invented name.
- **272–277:** a SharedFacet-only command neither explicitly refreshes the changed production source nor selects the concrete CrossInterface consumers. The concrete Generic/Stata host file was directly read in Astra's original pass. Use the fixed command below.

Agree with MiniMax's production return and helper deletion. The rejected test instructions are not grounds to weaken that production change.

### Kimi replacement — agree on dependent deletion; remove obsolete teaching

Agree with `kimi-req06-plan.md:27–34` that original **212** must be removed with the `paid` declaration and redemption leg, and with its SharedFacet balance assertion at **45–47**.

Do not retain the production NatSpec's conditional receipt-cap description as instructed at **23**, or the obsolete behavior names/comments at **52**. They would describe the policy being removed. Use the exact directly associated comment/name updates below, without unrelated cleanup.

Do not retain the held-receipt shortfall premise at original behavior **199–201** as a new obligation. The closed test now checks the balance result after the existing setup, not a smaller payable prefix or an expected shortfall. Its broad directory command is unnecessary for this closed selection; use the exact roots below. “Compile-safe” and “runs green” are predictions, not results established by this review.

## One closed implementation plan

Only three files may change: `ReceiptBackedERC4626Target.sol`, `Behavior_ReceiptBackedERC4626_CrossInterface.sol`, and `ReceiptBackedERC4626_SharedFacet.t.sol`, at the paths named by the controlling PRD. Before editing, verify the original search/helper ranges and named test blocks still match the inspected source. If they have drifted, stop and report; do not relocate the work or choose another policy.

### Production

In `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol`, replace original **72–81** with exactly:

```solidity
    /// @dev Returns the owner's full share balance for a supported accounting family.
    function maxRedeem(address owner) public view virtual returns (uint256) {
        _requireFamily();
        return ERC20Repo._balanceOf(owner);
    }
```

Delete `_redeemFitsReceipts` at **173–176** and `_largestRedeemableShares`, including its comment, at **178–196**. Leave imports and all other production functions unchanged. In particular, do not modify `previewRedeem`, `maxWithdraw`, `redeem`, `withdraw` or `_requireFamily`; do not add a selector, receipt check, smaller-share search, shortfall branch or new error.

### Behavior test: former reduced-cap case

In `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol`:

- Rename the original test at **190** to `test_maxRedeem_returnsBalanceAfterBackingChange`.
- Replace its comment at **189** with `/// @dev maxRedeem returns the owner's share balance; maxWithdraw follows its preview.`
- Keep original setup **191–198**, including the existing owner-balance snapshot.
- Replace the entire original tail **199–212** with exactly:

```solidity
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the owner share balance");
        assertEq(IERC4626(_se()).maxWithdraw(_actor()), IERC4626(_se()).previewRedeem(balance));
```

This removes `held`, `fullPreview`, their shortfall-premise assertion, `cap`, `capPreview`, the reduced-cap inequalities, the obsolete redeem call and every dependent payout assertion. No dangling `paid` reference remains. No replacement shortfall expectation is added.

### Behavior test: existing zero-preview case

- Rename original **216** to `test_maxRedeem_returnsBalanceWhenPreviewIsZero`.
- Replace its comment at **215** with `/// @dev A zero asset preview does not reduce the owner's advertised share balance.`
- Keep original setup/preview assertion **217–232** unchanged; no new fixture scenario is introduced.
- Replace **233–234** with:

```solidity
        assertEq(IERC4626(_se()).maxRedeem(_actor()), balance, "maxRedeem is the owner share balance");
        assertEq(IERC4626(_se()).maxWithdraw(_actor()), 0, "asset preview remains zero");
```

Leave `test_maxRedeem_fullBalancePayableAtNonIntegralRate` at **171–187** and every other behavior test unchanged.

### SharedFacet

In `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol`:

- Rename original **168** to `test_R14_18_localOnlyBacking_maxRedeemEqualsBalance`.
- Replace its comment at **167** with `/// @dev maxRedeem advertises the owner's shares independently of the asset preview.`
- Replace **183** with:

```solidity
        assertEq(IERC4626(se2).maxRedeem(u), IERC20(se2).balanceOf(u), "maxRedeem is the owner share balance");
```

- Delete **187–188**, both the zero-maximum `ERC4626ExceededMaxRedeem` expectation and its `redeem(1, u, u)` call.
- Keep the existing setup, receipt-balance assertion, maxWithdraw assertion, withdraw rejection and `vm.stopPrank()` unchanged. Do not insert a shortfall expectation or another redemption call.

Keep `APEX_D46_CapacityFixtures.t.sol:83` and `ShortRedeemERC4626` unchanged. They concern another contract. Add no test file or imports.

### One later validation command

From IndexedEx root, default hermetic profile:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/behaviors/ReceiptBackedERC4626_CrossInterface.t.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol \
  --test-root test/foundry/spec/vaults/standard/erc4626/APEX_D46_CapacityFixtures.t.sol \
  -- -vv
```

The edited target is the artifact-refresh input. The concrete behavior host selects both Generic and Stata implementations; the unchanged capacity fixture is a preservation check, not an edit target. Run whole files without a test-name filter. Preserve `out/` and `cache_forge/`; do not enable `via_ir` or change profiles/source paths.

If compilation or any retained/new assertion fails, stop and report the site and observed result. Do not restore search/cap logic, reinterpret the ruling, change the excluded production functions or introduce shortfall expectations to make the run pass. This command is prescribed for a later authorized implementation, not run here.

## Astra plan findings

| Finding | Severity / impact | File and line | Requirement and fixed direction | Confidence |
|---|---|---|---|---|
| SharedFacet zero expectation contradicts the balance rule | Low / incorrect regression oracle | `minimax-req06-plan.md:235–243` | Compare maxRedeem with the actual owner's share balance, not a presumed zero | High from current fixture and PRD |
| Partial deletion leaves undefined `paid` reference | Low / proposed compilation failure | `grok-req06-plan.md:29`, current behavior line 212 | Delete the whole obsolete redemption tail through 212 with its dependencies | High from direct source |
| Retained obsolete capped-redemption leg leaves the plan unresolved | Low / stale-policy test and validation failure risk | `minimax-req06-plan.md:195,277,302` | Remove the withdrawn leg; add no alternate shortfall expectation | High on scope conflict; runtime unverified |

No production defect beyond the PRD's specified behavior mismatch is alleged. Originals remain attributed and preserved; no peer is represented as having revised its draft. My original already specified these complete deletions and balance assertions, so its implementation recommendation is retained rather than silently rewritten.

Fresh reads covered SharedFacet **167–190**, behavior **189–235**, the controlling PRD **25–47**, and all three original drafts. All requested inputs were present. The assigned output did not exist before writing. No runtime or compilation outcome is claimed.

Only this assigned Markdown cross-review was created. No code, tests, PRD, final implementation plan, original report, configuration or instructions were edited. No delegation, shell, build, test or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.
