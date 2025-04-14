---
name: Aerodrome Rewards
description: This skill should be used when the user asks about "rewards", "bribes", "fees", "VotingReward", "BribeVotingReward", "FeesVotingReward", "ManagedReward", or needs to understand Aerodrome's reward distribution system.
version: 0.1.0
---

# Aerodrome Rewards

Aerodrome has multiple reward contracts that distribute different types of incentives to voters and managed NFT depositors.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                   REWARD CONTRACTS                           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  For veNFT Voters:                                           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ FeesVotingReward   ─ Trading fees from pools            │ │
│  │ BribeVotingReward  ─ External bribes from projects      │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  For Managed NFT Depositors:                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ LockedManagedReward ─ Compounded rewards (locked)       │ │
│  │ FreeManagedReward   ─ Claimable rewards (unlocked)      │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Reward Base Contract

All reward contracts inherit from a common base:

```solidity
abstract contract Reward is IReward {
    uint256 internal constant DURATION = 7 days;
    address public immutable voter;
    address public immutable ve;

    uint256 public totalSupply;
    mapping(uint256 => uint256) public balanceOf;  // tokenId => balance

    uint256 public tokenRewardsPerEpoch;
    uint256 public lastEarn;

    mapping(address => uint256) public rewardRate;
    mapping(address => uint256) public periodFinish;
    mapping(address => mapping(uint256 => uint256)) public lastEarn;  // token => tokenId => timestamp
    mapping(address => mapping(uint256 => uint256)) public userRewardPerTokenStored;

    address[] public rewards;  // Reward tokens
    mapping(address => bool) public isReward;
}
```

## VotingReward Contracts

### FeesVotingReward

Distributes pool trading fees to voters:

```solidity
contract FeesVotingReward is VotingReward {
    constructor(address _forwarder, address _voter, address[] memory _rewards)
        VotingReward(_forwarder, _voter, _rewards) {}
}
```

### BribeVotingReward

Distributes external bribes to voters:

```solidity
contract BribeVotingReward is VotingReward {
    constructor(address _forwarder, address _voter, address[] memory _rewards)
        VotingReward(_forwarder, _voter, _rewards) {}
}
```

### VotingReward Base

```solidity
abstract contract VotingReward is Reward {
    /// @notice Deposit voting power (called by Voter)
    function _deposit(uint256 amount, uint256 tokenId) external {
        if (msg.sender != voter) revert NotVoter();

        totalSupply += amount;
        balanceOf[tokenId] += amount;

        // Checkpoint for reward calculation
        _writeCheckpoint(tokenId, balanceOf[tokenId]);

        emit Deposit(msg.sender, tokenId, amount);
    }

    /// @notice Withdraw voting power (called by Voter)
    function _withdraw(uint256 amount, uint256 tokenId) external {
        if (msg.sender != voter) revert NotVoter();

        totalSupply -= amount;
        balanceOf[tokenId] -= amount;

        _writeCheckpoint(tokenId, balanceOf[tokenId]);

        emit Withdraw(msg.sender, tokenId, amount);
    }

    /// @notice Get reward tokens for a tokenId
    function getReward(uint256 tokenId, address[] memory tokens) external nonReentrant {
        if (!IVotingEscrow(ve).isApprovedOrOwner(msg.sender, tokenId)) revert NotApprovedOrOwner();

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 _reward = earned(tokens[i], tokenId);
            lastEarn[tokens[i]][tokenId] = block.timestamp;
            userRewardPerTokenStored[tokens[i]][tokenId] = rewardPerToken(tokens[i]);

            if (_reward > 0) {
                IERC20(tokens[i]).safeTransfer(msg.sender, _reward);
                emit ClaimRewards(msg.sender, tokens[i], _reward);
            }
        }
    }

    /// @notice Calculate earned rewards
    function earned(address token, uint256 tokenId) public view returns (uint256) {
        uint256 _startTimestamp = lastEarn[token][tokenId];
        if (_startTimestamp == 0) {
            _startTimestamp = ProtocolTimeLibrary.epochStart(block.timestamp);
        }

        uint256 _endTimestamp = ProtocolTimeLibrary.epochStart(block.timestamp);
        uint256 reward = 0;

        // Sum rewards from each epoch
        for (uint256 t = _startTimestamp; t < _endTimestamp; t += DURATION) {
            uint256 _epochStart = t;
            uint256 _balance = balanceOfAt(tokenId, _epochStart);

            if (_balance > 0) {
                uint256 _supply = totalSupplyAt(_epochStart);
                if (_supply > 0) {
                    uint256 _reward = tokenRewardsPerEpoch[token][_epochStart];
                    reward += (_balance * _reward) / _supply;
                }
            }
        }

        return reward;
    }

    /// @notice Notify rewards for distribution
    function notifyRewardAmount(address token, uint256 amount) external nonReentrant {
        if (!isReward[token]) {
            if (!IVoter(voter).isWhitelistedToken(token)) revert NotWhitelisted();
            isReward[token] = true;
            rewards.push(token);
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Rewards go to next epoch
        uint256 epochStart = ProtocolTimeLibrary.epochNext(block.timestamp);
        tokenRewardsPerEpoch[token][epochStart] += amount;

        emit NotifyReward(msg.sender, token, epochStart, amount);
    }
}
```

## ManagedReward Contracts

### LockedManagedReward

Handles compounded rewards that remain locked in the managed NFT:

```solidity
contract LockedManagedReward is ManagedReward {
    /// @notice Deposit (called when normal NFT deposits into managed)
    function _deposit(uint256 amount, uint256 tokenId) external {
        if (msg.sender != ve) revert NotVotingEscrow();

        totalSupply += amount;
        balanceOf[tokenId] += amount;

        emit Deposit(msg.sender, tokenId, amount);
    }

    /// @notice Withdraw (called when normal NFT withdraws from managed)
    function _withdraw(uint256 amount, uint256 tokenId) external {
        if (msg.sender != ve) revert NotVotingEscrow();

        totalSupply -= amount;
        balanceOf[tokenId] -= amount;

        emit Withdraw(msg.sender, tokenId, amount);
    }

    /// @notice Get rewards (returns AERO to VotingEscrow for locked NFT)
    function getReward(uint256 tokenId) external nonReentrant {
        if (msg.sender != ve) revert NotVotingEscrow();

        uint256 _reward = earned(tokenId);
        if (_reward > 0) {
            IERC20(rewardToken).safeTransfer(ve, _reward);
            emit ClaimRewards(tokenId, _reward);
        }
    }

    /// @notice Notify compounded rewards
    function notifyRewardAmount(uint256 amount) external nonReentrant {
        // Can be called by anyone to compound rewards into managed NFT
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);

        // Add to current epoch
        uint256 epochStart = ProtocolTimeLibrary.epochStart(block.timestamp);
        tokenRewardsPerEpoch[epochStart] += amount;

        emit NotifyReward(msg.sender, amount);
    }
}
```

### FreeManagedReward

Handles distributable rewards for managed NFT depositors:

```solidity
contract FreeManagedReward is ManagedReward {
    /// @notice Get rewards for a deposited tokenId
    function getReward(uint256 tokenId, address[] memory tokens) external nonReentrant {
        if (!IVotingEscrow(ve).isApprovedOrOwner(msg.sender, tokenId)) revert NotApprovedOrOwner();
        if (IVotingEscrow(ve).escrowType(tokenId) != IVotingEscrow.EscrowType.LOCKED)
            revert NotLockedNFT();

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 _reward = earned(tokens[i], tokenId);
            if (_reward > 0) {
                IERC20(tokens[i]).safeTransfer(msg.sender, _reward);
                emit ClaimRewards(msg.sender, tokens[i], _reward);
            }
        }
    }

    /// @notice Notify free rewards for distribution
    function notifyRewardAmount(address token, uint256 amount) external nonReentrant {
        if (!isReward[token]) {
            isReward[token] = true;
            rewards.push(token);
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Rewards distributed immediately to current depositors
        uint256 epochStart = ProtocolTimeLibrary.epochStart(block.timestamp);
        tokenRewardsPerEpoch[token][epochStart] += amount;

        emit NotifyReward(msg.sender, token, amount);
    }
}
```

## Reward Flow Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    REWARD FLOWS                              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Trading Fees:                                               │
│  Pool ──► Gauge ──► FeesVotingReward ──► veNFT Voters        │
│                                                              │
│  External Bribes:                                            │
│  Projects ──► BribeVotingReward ──► veNFT Voters             │
│                                                              │
│  Managed NFT Rewards:                                        │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Manager votes with mNFT                                 │ │
│  │     │                                                   │ │
│  │     ▼                                                   │ │
│  │ Earns fees + bribes                                     │ │
│  │     │                                                   │ │
│  │     ├──► LockedManagedReward (compounded)               │ │
│  │     │    └──► Returns to VE on withdraw                 │ │
│  │     │                                                   │ │
│  │     └──► FreeManagedReward (distributable)              │ │
│  │          └──► Depositors can claim                      │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Checkpointing System

Rewards use checkpoints to track balances over time:

```solidity
struct Checkpoint {
    uint256 timestamp;
    uint256 balanceOf;
}

mapping(uint256 => Checkpoint[]) internal checkpoints;  // tokenId => checkpoints

function _writeCheckpoint(uint256 tokenId, uint256 balance) internal {
    uint256 timestamp = block.timestamp;
    uint256 _nCheckPoints = checkpoints[tokenId].length;

    if (_nCheckPoints > 0 &&
        checkpoints[tokenId][_nCheckPoints - 1].timestamp == timestamp) {
        // Update existing checkpoint
        checkpoints[tokenId][_nCheckPoints - 1].balanceOf = balance;
    } else {
        // Create new checkpoint
        checkpoints[tokenId].push(Checkpoint({
            timestamp: timestamp,
            balanceOf: balance
        }));
    }
}

function balanceOfAt(uint256 tokenId, uint256 timestamp) public view returns (uint256) {
    // Binary search for balance at timestamp
    Checkpoint[] storage _checkpoints = checkpoints[tokenId];
    uint256 _len = _checkpoints.length;

    if (_len == 0) return 0;

    // Check bounds
    if (timestamp >= _checkpoints[_len - 1].timestamp) {
        return _checkpoints[_len - 1].balanceOf;
    }
    if (timestamp < _checkpoints[0].timestamp) {
        return 0;
    }

    // Binary search
    uint256 lower = 0;
    uint256 upper = _len - 1;
    while (upper > lower) {
        uint256 center = upper - (upper - lower) / 2;
        Checkpoint memory cp = _checkpoints[center];
        if (cp.timestamp == timestamp) {
            return cp.balanceOf;
        } else if (cp.timestamp < timestamp) {
            lower = center;
        } else {
            upper = center - 1;
        }
    }
    return _checkpoints[lower].balanceOf;
}
```

## Events

```solidity
// VotingReward events
event Deposit(address indexed from, uint256 indexed tokenId, uint256 amount);
event Withdraw(address indexed from, uint256 indexed tokenId, uint256 amount);
event NotifyReward(address indexed from, address indexed reward, uint256 indexed epoch, uint256 amount);
event ClaimRewards(address indexed from, address indexed reward, uint256 amount);

// ManagedReward events
event NotifyReward(address indexed from, uint256 amount);
event ClaimRewards(uint256 indexed tokenId, uint256 amount);
```

## Reference Files

- `contracts/rewards/Reward.sol` - Base reward contract
- `contracts/rewards/VotingReward.sol` - Voting reward base
- `contracts/rewards/FeesVotingReward.sol` - Fee distribution
- `contracts/rewards/BribeVotingReward.sol` - Bribe distribution
- `contracts/rewards/ManagedReward.sol` - Managed NFT reward base
- `contracts/rewards/LockedManagedReward.sol` - Locked rewards
- `contracts/rewards/FreeManagedReward.sol` - Free rewards
