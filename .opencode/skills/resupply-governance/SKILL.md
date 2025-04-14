---
name: resupply-governance
description: This skill should be used when the user asks about "governance", "Voter contract", "proposals", "DAO voting", "execute proposal", "governance operators", "protocol governance", or needs to understand Resupply's governance system.
---

# Resupply Governance System

The governance system enables RSUP stakers to propose and vote on protocol changes. Located in `/src/dao/Voter.sol` with operators in `/src/dao/operators/`.

## Voter Contract

```solidity
contract Voter {
    // Staking reference
    IGovStaker public staker;

    // Proposal configuration
    uint256 public constant MIN_CREATE_PROPOSAL_PCT = 100;  // 0.01% to create
    uint256 public constant QUORUM_PCT = 2000;               // 20% quorum
    uint256 public constant VOTING_PERIOD = 1 weeks;
    uint256 public constant EXECUTION_DELAY = 1 days;
    uint256 public constant EXECUTION_DEADLINE = 3 weeks;

    // Proposal storage
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    struct Proposal {
        uint256 createdAt;
        uint256 epoch;
        uint256 weightYes;
        uint256 weightNo;
        bool executed;
        bool vetoed;
        bytes32 actionHash;
    }
}
```

## Creating Proposals

Stakers with sufficient weight can create proposals:

```solidity
struct Action {
    address target;
    bytes data;
}

function createProposal(
    Action[] calldata payload,
    string calldata description
) external returns (uint256 proposalId) {
    // Check minimum stake requirement
    uint256 weight = staker.getWeight(msg.sender);
    uint256 totalWeight = staker.getTotalWeight();
    require(
        weight * 10000 >= totalWeight * MIN_CREATE_PROPOSAL_PCT,
        "Insufficient stake to create proposal"
    );

    // Create proposal
    proposalId = ++proposalCount;
    proposals[proposalId] = Proposal({
        createdAt: block.timestamp,
        epoch: getEpoch(),
        weightYes: 0,
        weightNo: 0,
        executed: false,
        vetoed: false,
        actionHash: keccak256(abi.encode(payload))
    });

    emit ProposalCreated(proposalId, msg.sender, description);
}
```

### Minimum Stake Requirement

To create a proposal: `staked_amount >= 0.01% of total_staked`

Example: If 10M RSUP staked, need 1000 RSUP to create proposal.

## Voting

Stakers vote with their epoch-weighted stake:

```solidity
function vote(
    uint256 _proposalId,
    uint256 _weightYes,
    uint256 _weightNo
) external {
    Proposal storage proposal = proposals[_proposalId];

    // Check voting period
    require(block.timestamp <= proposal.createdAt + VOTING_PERIOD, "Voting ended");

    // Get voter's weight at proposal epoch
    uint256 voterWeight = staker.getWeightAt(msg.sender, proposal.epoch);
    require(_weightYes + _weightNo <= voterWeight, "Exceeds voting power");

    // Prevent double voting
    require(!hasVoted[_proposalId][msg.sender], "Already voted");
    hasVoted[_proposalId][msg.sender] = true;

    // Record votes
    proposal.weightYes += _weightYes;
    proposal.weightNo += _weightNo;

    emit Voted(_proposalId, msg.sender, _weightYes, _weightNo);
}
```

### Vote Splitting

Voters can split their weight between yes and no:

```solidity
// Vote 70% yes, 30% no
vote(proposalId, 700, 300);  // Assuming 1000 weight

// Vote 100% yes
vote(proposalId, 1000, 0);

// Vote 100% no
vote(proposalId, 0, 1000);
```

## Proposal Lifecycle

```
Day 0: Proposal created
Day 0-7: Voting period (1 week)
Day 8: Execution delay starts (1 day)
Day 9-21: Execution window (until 3 weeks from creation)
Day 21+: Proposal expires if not executed
```

### Checking Proposal Status

```solidity
function getProposalStatus(uint256 _proposalId) public view returns (ProposalStatus) {
    Proposal memory p = proposals[_proposalId];

    if (p.vetoed) return ProposalStatus.Vetoed;
    if (p.executed) return ProposalStatus.Executed;

    if (block.timestamp <= p.createdAt + VOTING_PERIOD) {
        return ProposalStatus.Voting;
    }

    if (block.timestamp <= p.createdAt + VOTING_PERIOD + EXECUTION_DELAY) {
        return ProposalStatus.Pending;
    }

    if (block.timestamp <= p.createdAt + EXECUTION_DEADLINE) {
        if (_quorumReached(_proposalId) && _votePassed(_proposalId)) {
            return ProposalStatus.Executable;
        }
        return ProposalStatus.Defeated;
    }

    return ProposalStatus.Expired;
}
```

## Executing Proposals

After voting period and execution delay:

```solidity
function executeProposal(
    uint256 _proposalId,
    Action[] calldata payload
) external {
    Proposal storage proposal = proposals[_proposalId];

    // Verify timing
    require(
        block.timestamp > proposal.createdAt + VOTING_PERIOD + EXECUTION_DELAY,
        "Execution delay not passed"
    );
    require(
        block.timestamp <= proposal.createdAt + EXECUTION_DEADLINE,
        "Execution deadline passed"
    );

    // Verify payload matches
    require(
        keccak256(abi.encode(payload)) == proposal.actionHash,
        "Payload mismatch"
    );

    // Verify quorum and majority
    require(_quorumReached(_proposalId), "Quorum not reached");
    require(_votePassed(_proposalId), "Vote did not pass");

    // Mark as executed
    proposal.executed = true;

    // Execute actions through Core
    for (uint256 i = 0; i < payload.length; i++) {
        ICore(core).execute(payload[i].target, payload[i].data);
    }

    emit ProposalExecuted(_proposalId);
}
```

### Quorum Requirement

```solidity
function _quorumReached(uint256 _proposalId) internal view returns (bool) {
    Proposal memory p = proposals[_proposalId];
    uint256 totalVotes = p.weightYes + p.weightNo;
    uint256 totalWeight = staker.getTotalWeightAt(p.epoch);

    // 20% quorum required
    return totalVotes * 10000 >= totalWeight * QUORUM_PCT;
}
```

### Vote Passage

```solidity
function _votePassed(uint256 _proposalId) internal view returns (bool) {
    Proposal memory p = proposals[_proposalId];
    // Simple majority
    return p.weightYes > p.weightNo;
}
```

## Guardian Veto

The Guardian operator can veto malicious proposals:

```solidity
function veto(uint256 _proposalId) external onlyGuardian {
    proposals[_proposalId].vetoed = true;
    emit ProposalVetoed(_proposalId);
}
```

## DAO Operators

Specialized operator contracts for governance actions:

### Guardian (`/src/dao/operators/Guardian.sol`)

```solidity
contract Guardian {
    function pause(address target) external;     // Emergency pause
    function unpause(address target) external;   // Resume operations
    function veto(uint256 proposalId) external;  // Veto proposals
}
```

### TreasuryManager (`/src/dao/operators/TreasuryManager.sol`)

```solidity
contract TreasuryManager {
    function transfer(address token, address to, uint256 amount) external;
    function approve(address token, address spender, uint256 amount) external;
}
```

### BorrowLimitController (`/src/dao/operators/BorrowLimitController.sol`)

```solidity
contract BorrowLimitController {
    function setBorrowLimit(address pair, uint256 newLimit) external;
    function increaseBorrowLimit(address pair, uint256 amount) external;
}
```

### PairAdder (`/src/dao/operators/PairAdder.sol`)

```solidity
contract PairAdder {
    function addPair(address pair) external;
    function removePair(address pair) external;
}
```

## Key Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `MIN_CREATE_PROPOSAL_PCT` | 100 (0.01%) | Min stake to propose |
| `QUORUM_PCT` | 2000 (20%) | Required participation |
| `VOTING_PERIOD` | 1 week | Duration for voting |
| `EXECUTION_DELAY` | 1 day | Delay after voting |
| `EXECUTION_DEADLINE` | 3 weeks | Total time including voting |

## Events

```solidity
event ProposalCreated(uint256 indexed id, address indexed creator, string description);
event Voted(uint256 indexed id, address indexed voter, uint256 yes, uint256 no);
event ProposalExecuted(uint256 indexed id);
event ProposalVetoed(uint256 indexed id);
```

