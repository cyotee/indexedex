---
name: battlechain-safe-harbor
description: Use this skill when evaluating attack legality, agreement scope, bounty eligibility, or Binding Agreement resolution on BattleChain.
---

# BattleChain Safe Harbor and Binding Agreement

This skill prevents the most dangerous mistake: reading terms from the wrong agreement.

## What Safe Harbor Covers

Protected only when both are true:

1. Target is attackable (`UNDER_ATTACK` or `PROMOTION_REQUESTED`).
2. Target is in scope under the Binding Agreement.

Safe Harbor does not cover attacks on `PRODUCTION`, out-of-scope contracts, or violations of bounty and identity terms.

## Binding Agreement Resolution (Critical)

Do not trust `BattleChainSafeHarborRegistry.getAgreement(adopter)` for exploit terms.

Use Binding Agreement resolution:

- For top-level contracts: `AttackRegistry.getAgreementForContract(target)`.
- For child contracts: resolve by deployer lineage and child-scope rules.

Prefer API or BCQuery instead of manual resolution.

## Preferred Verification Paths

### Option 1: Explorer API (recommended)

```text
GET https://block-explorer-api.testnet.battlechain.com/battlechain/agreement/by-contract/{contractAddress}
```

### Option 2: BCQuery helper

```solidity
bool attackable = isAttackable(contractAddress); // requires --ffi
```

### Option 3: On-chain only (top-level only)

```solidity
address binding = attackRegistry.getAgreementForContract(contractAddress);
require(binding != address(0), "not registered top-level");
require(attackRegistry.isTopLevelContractUnderAttack(contractAddress), "not attackable");
BountyTerms memory terms = IAgreement(binding).getBountyTerms();
```

## Commitment Window Rules

During commitment window (`getCantChangeUntil()`), protocol cannot make whitehat-unfavorable changes:

- cannot reduce bounty/caps
- cannot remove scope
- cannot tighten identity
- cannot switch to return-all unfavorably

## Agreement URI Rule

Legal source of truth is `agreementURI` from the Binding Agreement itself.

```solidity
string memory uri = IAgreement(bindingAgreement).getAgreementURI();
```

## Pre-Attack Checklist

- Resolve Binding Agreement.
- Confirm attackable state.
- Confirm in-scope contract coverage.
- Read bounty percentage and cap.
- Read retainable behavior.
- Read identity requirements.
- Capture evidence snapshot (state, agreement address, tx context).

## Bounty Terms Essentials

```solidity
struct BountyTerms {
    uint256 bountyPercentage;
    uint256 bountyCapUsd;
    bool retainable;
    IdentityRequirements identity;
    string diligenceRequirements;
    uint256 aggregateBountyCapUsd;
}
```

Bounty formula:

```text
bounty = min(recoveredValue * bountyPercentage, bountyCapUsd)
```

Aggregate cap constraints apply when set. `aggregateBountyCapUsd` is incompatible with `retainable = true`.

## Mainnet Safety Rule

If exploit likely affects mainnet deployments:

- do not publicly disclose exploit details
- notify protocol privately
- use normal bug bounty path for mainnet scope

## References

- `https://docs.battlechain.com/battlechain/explanation/safe-harbor`
- `https://docs.battlechain.com/battlechain/how-to/find-attackable-contracts`
- `https://docs.battlechain.com/battlechain/how-to/claim-bounties`
- `https://docs.battlechain.com/battlechain/reference/bounty-terms`
