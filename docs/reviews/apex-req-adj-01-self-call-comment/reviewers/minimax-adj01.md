# MiniMax M3 — REQ-ADJ-01 first pass (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** REQ-ADJ-01 only. Controlling text: `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` section "REQ-ADJ-01 — Rebasing SY comment still teaches a vault self-call" (lines 152–161). Production target: `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41-44`.
- **Inputs read:** the PRD section; the production file in full (151 lines). No peer review files read.
- **No code edit. No PRD/plan write. No Forge. No exploit procedures.**

---

## Headline — No blocking question

The PRD's three acceptance bullets, combined with the current production body at `RebasingAwareStandardYieldTarget.sol:45-67`, determine the exact replacement NatSpec for lines 41-44. The implementer has no choice. The replacement is below.

---

## 1. The current state (facts)

### 1.1 Current NatSpec at `RebasingAwareStandardYieldTarget.sol:41-44`

```solidity
    /// @param burnFromInternalBalance Integrating-contract flag only when true and `msg.sender != address(this)`.
    ///        Transfer-and-consume must be atomic; staged use is at integrator risk. Callers with no bytecode
    ///        revert `EOAPretransferNotAllowed()`. Burns exactly `amountSharesToRedeem` from vault-held shares
    ///        and refunds nothing (API-12). The vault's own self-call path is unaffected.
```

The last clause — "The vault's own self-call path is unaffected." — is the broken comment per the PRD `:157`: "The NatSpec says the vault's own self-call path is unaffected. The caller check is skipped when `msg.sender == address(this)`. No production self-call into this function was established." The comment tells a later agent that `address(this)` calls this function via a self-call, but the production code never self-calls.

### 1.2 Current production body at `RebasingAwareStandardYieldTarget.sol:45-67` (relevant lines)

- `:60-62` — `ShareSource` selection by flag:
  ```solidity
  RebasingAwareERC4626Common.ShareSource source = burnFromInternalBalance
      ? RebasingAwareERC4626Common.ShareSource.PublicBalanceExactBurn
      : RebasingAwareERC4626Common.ShareSource.CallerOrApprovedOwner;
  ```
- `:63` — explicit holder selection by flag:
  ```solidity
  address owner = burnFromInternalBalance ? address(this) : msg.sender;
  ```
- `:57-58` — exemption for the pretransfer-caller check:
  ```solidity
  if (burnFromInternalBalance && msg.sender != address(this)) {
      LocalCreditLib.requirePretransferCaller(msg.sender);
  }
  ```
- `:64-66` — the burn is delegated to `executeRedeem` with the chosen `owner` and `source`.

The function selects an explicit holder (`address(this)` or `msg.sender`) based on `burnFromInternalBalance`; it does NOT call `address(this)` to invoke itself. The exemption at `:57` skips the pretransfer-caller check when the caller is the vault and the flag is set; the PRD `:159` notes this exemption is preserved.

---

## 2. The exact replacement NatSpec for lines 41-44

Replace the current 4-line NatSpec at `RebasingAwareStandardYieldTarget.sol:41-44` with the following 6-line NatSpec (line count is not constrained; the content is):

```solidity
    /// @param burnFromInternalBalance When true, `owner` is `address(this)` and `amountSharesToRedeem` is burned
    ///        from vault-held shares; when false, `owner` is `msg.sender` and the burn is from the caller's
    ///        balance via allowance or ownership. The pretransfer-caller check is skipped only when
    ///        `burnFromInternalBalance == true` and `msg.sender == address(this)`. Callers with no bytecode
    ///        revert `EOAPretransferNotAllowed()`. Transfer-and-consume must be atomic; staged use is at
    ///        integrator risk. Burns exactly `amountSharesToRedeem` and refunds nothing (API-12).
```

Nothing else in the file changes. The function body, the `address(this)` exemption at `:57-58`, and every other line in the contract are unchanged.

### 2.1 How the replacement satisfies each PRD bullet

- **PRD `:159` "The comment describes explicit-holder redemption, not a current self-call path."** — The first sentence of the replacement names the two flag cases and the holder each case produces (`address(this)` vs `msg.sender`). It does not use the phrase "self-call path" or imply that `address(this)` invokes this function.
- **PRD `:160` "No self-call is added to make the old sentence true."** — The production body is unchanged. The exemption at `:57-58` is preserved. No `address(this).redeem(...)` is added.
- **PRD non-goal `:161` "Do not delete the `msg.sender == address(this)` exemption in this item."** — The replacement explicitly states "The pretransfer-caller check is skipped only when `burnFromInternalBalance == true` and `msg.sender == address(this)`." This documents the exemption's reachability condition without claiming a self-call. The exemption is unchanged in code.
- **PRD non-goal `:161` "Do not redesign custody SY."** — The replacement does not propose a new `ShareSource`, a new holder selection, or a custody path. It documents the current explicit-holder selection as it exists in the body at `:60-63`.

### 2.2 Why this is the only legal replacement

Every clause in the replacement is pinned by current source:

- "When true, `owner` is `address(this)`" — pinned at `:63`.
- "burned from vault-held shares" — pinned at `:61` (`ShareSource.PublicBalanceExactBurn`).
- "when false, `owner` is `msg.sender`" — pinned at `:63`.
- "the burn is from the caller's balance via allowance or ownership" — pinned at `:62` (`ShareSource.CallerOrApprovedOwner`).
- "The pretransfer-caller check is skipped only when `burnFromInternalBalance == true` and `msg.sender == address(this)`" — pinned at `:57-58` (the `&&` guard; the negation makes the skip the complementary case).
- "Callers with no bytecode revert `EOAPretransferNotAllowed()`" — pinned at `:58` (`LocalCreditLib.requirePretransferCaller(msg.sender)`).
- "Transfer-and-consume must be atomic" — pinned by the `nonReentrant` modifier on the function at `:51` and the locked-burn-and-pay pattern at `:64-66`.
- "Burns exactly `amountSharesToRedeem`" — pinned by the `executeRedeem` call at `:64-66` passing `amountSharesToRedeem` unchanged.
- "refunds nothing (API-12)" — pinned by the absence of any refund branch in the function body.

The implementer cannot choose any clause differently. The replacement is the only shape that satisfies the PRD's three bullets and matches the production body byte-for-byte.

---

## 3. What this answer does not include

- No code change outside the four lines of NatSpec. The function body, the `address(this)` exemption, the other exemption-free paths (`deposit`, `previewDeposit`, `previewRedeem`, `assetInfo`, `getTokensIn`, `getTokensOut`, `isValidTokenIn`, `isValidTokenOut`, `claimRewards`, `getRewardTokens`, `accruedRewards`, `rewardIndexesCurrent`, `rewardIndexesStored`, `yieldToken`, `exchangeRate`) are unchanged.
- No change to `RebasingAwareERC4626Common` or `RebasingAwareERC4626Repo`. The custody flow is not redesigned.
- No self-call. `address(this).redeem(...)` is not added.
- No removal of the `msg.sender == address(this)` exemption. The exemption is preserved and documented as a condition, not as a self-call path.

---

## 4. What would change this answer

This is "No blocking question" only if the replacement is fully determined by the PRD + the current production body. The answer flips to "one blocking question" if any of the following is true; I checked all four and none is true:

1. The PRD leaves the comment content open. — Not true. PRD `:159` says "The comment describes explicit-holder redemption, not a current self-call path." That is the closed shape.
2. The production body has a third flag case or a different holder-selection rule I did not capture. — Not true. `:60-63` has exactly two cases.
3. The exemption reachability or wording is contested. — Not true. PRD `:161` says do not delete the exemption; my replacement documents its condition.
4. The implementer is asked to add or remove code beyond the four lines of NatSpec. — Not true. The PRD is a documentation item; PRD `:160` forbids adding a self-call.

None of these is true. The answer stands.

---

## 5. Files examined (this answer)

- `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` — re-read for the REQ-ADJ-01 section (lines 152–161).
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol` — read in full (151 lines).

No other reviewer files were read. No Forge / build / test was executed. No code was edited.

---

I did not run Forge.