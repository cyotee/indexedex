---
name: Aerodrome Emissions
description: This skill should be used when the user asks about "Minter", "emissions", "rebases", "RewardsDistributor", "tail emissions", "nudge", "weekly decay", or needs to understand Aerodrome's emission schedule.
version: 0.1.0
---

# Aerodrome Emissions

The Minter contract controls AERO token emissions and distributes them to the Voter (for LPs) and RewardsDistributor (for veNFT holders as rebases).

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                   EMISSION SYSTEM                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐                                             │
│  │   Minter    │◄───────── EpochGovernor (tail rate)        │
│  └──────┬──────┘                                             │
│         │ updatePeriod()                                     │
│         │                                                    │
│         ├──────────────────────────────────────────────┐     │
│         ▼                                              ▼     │
│  ┌─────────────┐                              ┌─────────────┐│
│  │   Voter     │                              │  Rewards    ││
│  │ (Emissions) │                              │ Distributor ││
│  └──────┬──────┘                              │  (Rebases)  ││
│         │                                     └──────┬──────┘│
│         ▼                                            ▼       │
│  ┌─────────────┐                              ┌─────────────┐│
│  │   Gauges    │                              │   veNFT     ││
│  │ (LP Rewards)│                              │  Holders    ││
│  └─────────────┘                              └─────────────┘│
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Minter Contract

```solidity
contract Minter is IMinter {
    IAero public immutable aero;
    IVoter public immutable voter;
    IVotingEscrow public immutable ve;
    IRewardsDistributor public immutable rewardsDistributor;

    uint256 public constant WEEK = 1 weeks;
    uint256 public constant WEEKLY_DECAY = 9_900;     // 99% (1% decay)
    uint256 public constant WEEKLY_GROWTH = 10_300;   // 103% (3% growth)
    uint256 public constant MAX_BPS = 10_000;

    // Tail emission parameters
    uint256 public constant MAXIMUM_TAIL_RATE = 100;  // 1%
    uint256 public constant MINIMUM_TAIL_RATE = 1;    // 0.01%
    uint256 public constant NUDGE = 1;                // 0.01% per nudge
    uint256 public constant TAIL_START = 8_969_150 * 1e18;  // ~8.97M threshold

    uint256 public tailEmissionRate = 67;  // 0.67% (67 basis points)
    uint256 public teamRate = 500;         // 5%
    uint256 public weekly = 10_000_000 * 1e18;  // Starting 10M/week

    uint256 public activePeriod;
    uint256 public epochCount;
    address public team;
}
```

## Emission Schedule

```
┌──────────────────────────────────────────────────────────────┐
│                 EMISSION PHASES                              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Phase 1: Growth (Epochs 1-14)                               │
│  ────────────────────────────                                │
│  • Weekly emissions INCREASE by 3% per epoch                 │
│  • 10M → 10.3M → 10.61M → ... → ~14.6M                       │
│                                                              │
│  Phase 2: Decay (Epochs 15+)                                 │
│  ────────────────────────────                                │
│  • Weekly emissions DECREASE by 1% per epoch                 │
│  • Continues until reaching TAIL_START threshold             │
│                                                              │
│  Phase 3: Tail Emissions                                     │
│  ────────────────────────────                                │
│  • When weekly < 8.97M AERO                                  │
│  • Emission = totalSupply × tailEmissionRate / 10000         │
│  • Rate adjustable via EpochGovernor (0.01% - 1%)            │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Update Period (Weekly Emission)

```solidity
function updatePeriod() external returns (uint256 _period) {
    _period = activePeriod;

    if (block.timestamp >= _period + WEEK) {
        epochCount++;
        _period = (block.timestamp / WEEK) * WEEK;
        activePeriod = _period;

        uint256 _weekly = weekly;
        uint256 _emission;
        uint256 _totalSupply = aero.totalSupply();
        bool _tail = _weekly < TAIL_START;

        if (_tail) {
            // Tail emissions: percentage of total supply
            _emission = (_totalSupply * tailEmissionRate) / MAX_BPS;
        } else {
            // Normal emissions
            _emission = _weekly;

            if (epochCount < 15) {
                // Growth phase: +3% per epoch
                _weekly = (_weekly * WEEKLY_GROWTH) / MAX_BPS;
            } else {
                // Decay phase: -1% per epoch
                _weekly = (_weekly * WEEKLY_DECAY) / MAX_BPS;
            }
            weekly = _weekly;
        }

        // Calculate rebase (anti-dilution for veNFT holders)
        uint256 _growth = calculateGrowth(_emission);

        // Team allocation
        uint256 _rate = teamRate;
        uint256 _teamEmissions = (_rate * (_growth + _weekly)) / (MAX_BPS - _rate);

        // Mint required tokens
        uint256 _required = _growth + _emission + _teamEmissions;
        uint256 _balanceOf = aero.balanceOf(address(this));
        if (_balanceOf < _required) {
            aero.mint(address(this), _required - _balanceOf);
        }

        // Distribute
        aero.safeTransfer(address(team), _teamEmissions);
        aero.safeTransfer(address(rewardsDistributor), _growth);
        rewardsDistributor.checkpointToken();

        aero.safeApprove(address(voter), _emission);
        voter.notifyRewardAmount(_emission);

        emit Mint(msg.sender, _emission, aero.totalSupply(), _tail);
    }
}
```

## Rebase Calculation

Rebases compensate veNFT holders for dilution:

```solidity
/// @notice Calculate rebase amount (anti-dilution for lockers)
function calculateGrowth(uint256 _minted) public view returns (uint256 _growth) {
    uint256 _veTotal = ve.totalSupplyAt(activePeriod - 1);
    uint256 _aeroTotal = aero.totalSupply();

    // Formula: (minted * (total - locked) / total)^2 / total / 2
    // This gives more rebase when less is locked
    return (((_minted * (_aeroTotal - _veTotal)) / _aeroTotal) *
            ((_aeroTotal - _veTotal)) / _aeroTotal) / 2;
}
```

## Tail Emission Rate Adjustment

### EpochGovernor Nudge

```solidity
/// @notice Adjust tail emission rate based on governance vote
function nudge() external {
    address _epochGovernor = voter.epochGovernor();
    if (msg.sender != _epochGovernor) revert NotEpochGovernor();

    IEpochGovernor.ProposalState _state = IEpochGovernor(_epochGovernor).result();
    if (weekly >= TAIL_START) revert TailEmissionsInactive();

    uint256 _period = activePeriod;
    if (proposals[_period]) revert AlreadyNudged();

    uint256 _newRate = tailEmissionRate;
    uint256 _oldRate = _newRate;

    if (_state != IEpochGovernor.ProposalState.Expired) {
        if (_state == IEpochGovernor.ProposalState.Succeeded) {
            // Increase rate (more emissions)
            _newRate = _oldRate + NUDGE > MAXIMUM_TAIL_RATE
                ? MAXIMUM_TAIL_RATE
                : _oldRate + NUDGE;
        } else {
            // Decrease rate (less emissions)
            _newRate = _oldRate - NUDGE < MINIMUM_TAIL_RATE
                ? MINIMUM_TAIL_RATE
                : _oldRate - NUDGE;
        }
        tailEmissionRate = _newRate;
    }

    proposals[_period] = true;
    emit Nudge(_period, _oldRate, _newRate);
}
```

## RewardsDistributor

Distributes rebases to veNFT holders:

```solidity
contract RewardsDistributor is IRewardsDistributor {
    uint256 public constant WEEK = 7 days;
    address public immutable ve;
    address public immutable token;  // AERO

    uint256 public startTime;
    uint256 public timeCursor;
    mapping(uint256 => uint256) public timeCursorOf;  // tokenId => cursor
    mapping(uint256 => uint256) public userEpochOf;   // tokenId => epoch

    uint256 public lastTokenTime;
    uint256[10000000000000] public tokensPerWeek;
    uint256 public tokenLastBalance;

    /// @notice Checkpoint token balance
    function checkpointToken() external {
        assert(msg.sender == depositor);
        _checkpointToken();
    }

    function _checkpointToken() internal {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        uint256 toDistribute = tokenBalance - tokenLastBalance;
        tokenLastBalance = tokenBalance;

        uint256 t = lastTokenTime;
        uint256 sinceLast = block.timestamp - t;
        lastTokenTime = block.timestamp;

        uint256 thisWeek = (t / WEEK) * WEEK;
        uint256 nextWeek = 0;

        for (uint256 i = 0; i < 20; i++) {
            nextWeek = thisWeek + WEEK;
            if (block.timestamp < nextWeek) {
                tokensPerWeek[thisWeek] += toDistribute;
                break;
            } else {
                tokensPerWeek[thisWeek] += toDistribute;
                toDistribute = 0;
            }
            thisWeek = nextWeek;
        }
    }

    /// @notice Claim rebase for a veNFT
    function claim(uint256 _tokenId) external returns (uint256) {
        uint256 _lastTokenTime = lastTokenTime;
        if (block.timestamp > _lastTokenTime) {
            _checkpointTotalSupply();
        }

        uint256 amount = _claim(_tokenId, ve, _lastTokenTime);
        if (amount != 0) {
            IVotingEscrow(ve).depositFor(_tokenId, amount);
            tokenLastBalance -= amount;
        }

        return amount;
    }

    /// @notice Claim for multiple tokenIds
    function claimMany(uint256[] memory _tokenIds) external returns (bool) {
        uint256 _lastTokenTime = lastTokenTime;
        if (block.timestamp > _lastTokenTime) {
            _checkpointTotalSupply();
        }

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 amount = _claim(_tokenIds[i], ve, _lastTokenTime);
            if (amount != 0) {
                IVotingEscrow(ve).depositFor(_tokenIds[i], amount);
                tokenLastBalance -= amount;
            }
        }
        return true;
    }
}
```

## Emission Distribution Summary

```
┌──────────────────────────────────────────────────────────────┐
│                WEEKLY DISTRIBUTION                           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Total Minted = Emission + Growth + TeamEmission             │
│                                                              │
│  Where:                                                      │
│  • Emission = weekly (or tailRate × totalSupply)             │
│  • Growth = Rebase for veNFT holders                         │
│  • TeamEmission = teamRate × (Growth + Weekly) / (1 - rate)  │
│                                                              │
│  Distribution:                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                                                         │ │
│  │  Team ◄──────────── teamEmissions                       │ │
│  │                                                         │ │
│  │  RewardsDistributor ◄──── growth (rebases)              │ │
│  │                                                         │ │
│  │  Voter ◄──────────── emission (LP rewards)              │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Configuration Functions

```solidity
/// @notice Set team address
function setTeam(address _team) external {
    if (msg.sender != team) revert NotTeam();
    if (_team == address(0)) revert ZeroAddress();
    pendingTeam = _team;
}

function acceptTeam() external {
    if (msg.sender != pendingTeam) revert NotPendingTeam();
    team = pendingTeam;
    delete pendingTeam;
    emit AcceptTeam(team);
}

/// @notice Set team emission rate (max 5%)
function setTeamRate(uint256 _rate) external {
    if (msg.sender != team) revert NotTeam();
    if (_rate > MAXIMUM_TEAM_RATE) revert RateTooHigh();
    teamRate = _rate;
}
```

## Events

```solidity
// Minter events
event Mint(address indexed sender, uint256 weekly, uint256 circulating, bool isTail);
event Nudge(uint256 indexed period, uint256 oldRate, uint256 newRate);
event AcceptTeam(address indexed team);
event DistributeLiquid(address indexed to, uint256 amount);
event DistributeLocked(address indexed to, uint256 amount, uint256 tokenId);

// RewardsDistributor events
event CheckpointToken(uint256 time, uint256 tokens);
event Claimed(uint256 indexed tokenId, uint256 amount, uint256 claimEpoch, uint256 maxEpoch);
```

## Reference Files

- `contracts/Minter.sol` - Emission controller
- `contracts/RewardsDistributor.sol` - Rebase distribution
- `contracts/EpochGovernor.sol` - Tail rate governance
- `contracts/interfaces/IMinter.sol` - Minter interface
