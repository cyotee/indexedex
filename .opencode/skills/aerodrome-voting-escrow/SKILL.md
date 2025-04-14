---
name: Aerodrome Voting Escrow
description: This skill should be used when the user asks about "VotingEscrow", "veAERO", "veNFT", "lock", "createLock", "merge", "split", "permanent lock", "managed NFT", or needs to understand Aerodrome's vote-escrow system.
version: 0.1.0
---

# Aerodrome Voting Escrow

The VotingEscrow contract allows users to lock AERO tokens in exchange for veAERO NFTs. These NFTs have voting power that decays linearly over time (unless permanently locked).

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                   VOTING ESCROW                              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Lock AERO ──────────► Mint veAERO NFT                       │
│                              │                               │
│                              ▼                               │
│              ┌───────────────────────────────┐               │
│              │      veAERO NFT States        │               │
│              ├───────────────────────────────┤               │
│              │                               │               │
│              │  NORMAL ─────► Decaying power │               │
│              │     │                         │               │
│              │     ▼                         │               │
│              │  PERMANENT ──► Fixed power    │               │
│              │     │                         │               │
│              │     ▼                         │               │
│              │  MANAGED ────► Aggregated NFT │               │
│              │     │                         │               │
│              │     ▼                         │               │
│              │  LOCKED ─────► Deposited into │               │
│              │               managed NFT     │               │
│              └───────────────────────────────┘               │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## NFT States

| State | Description | Operations Allowed |
|-------|-------------|-------------------|
| **NORMAL** | Standard veNFT with decaying voting power | vote, merge, split, withdraw, increaseUnlockTime |
| **NORMAL_PERMANENT** | Permanently locked, no decay | vote, delegate, split, unlockPermanent |
| **MANAGED** | Aggregator NFT for delegated voting | vote, delegate, receive deposits |
| **LOCKED** | Normal NFT deposited into managed | withdraw from managed |

## Creating Locks

```solidity
/// @notice Create a new veNFT by locking AERO
/// @param _value Amount of AERO to lock
/// @param _lockDuration Duration in seconds (max 4 years)
function createLock(uint256 _value, uint256 _lockDuration)
    external nonReentrant returns (uint256)
{
    return _createLock(_value, _lockDuration, _msgSender());
}

/// @notice Create a lock on behalf of another address
function createLockFor(uint256 _value, uint256 _lockDuration, address _to)
    external nonReentrant returns (uint256)
{
    return _createLock(_value, _lockDuration, _to);
}

function _createLock(uint256 _value, uint256 _lockDuration, address _to)
    internal returns (uint256)
{
    if (_value == 0) revert ZeroAmount();
    uint256 unlockTime = ((block.timestamp + _lockDuration) / WEEK) * WEEK;  // Round to week
    if (unlockTime <= block.timestamp) revert LockDurationNotInFuture();
    if (unlockTime > block.timestamp + MAXTIME) revert LockDurationTooLong();

    ++tokenId;
    uint256 _tokenId = tokenId;
    _mint(_to, _tokenId);

    _depositFor(_tokenId, _value, unlockTime, _locked[_tokenId], DepositType.CREATE_LOCK_TYPE);

    return _tokenId;
}
```

## Voting Power Calculation

Voting power decays linearly from lock time to unlock time:

```solidity
uint256 internal constant MAXTIME = 4 * 365 * 86400;  // 4 years
uint256 internal constant WEEK = 1 weeks;

/// @notice Get voting power of NFT at current time
function balanceOfNFT(uint256 _tokenId) public view returns (uint256) {
    if (ownershipChange[_tokenId] == block.number) return 0;
    return _balanceOfNFT(_tokenId, block.timestamp);
}

function _balanceOfNFT(uint256 _tokenId, uint256 _t) internal view returns (uint256) {
    uint256 _epoch = userPointEpoch[_tokenId];
    if (_epoch == 0) return 0;

    UserPoint memory lastPoint = _userPointHistory[_tokenId][_epoch];

    // Permanent locks don't decay
    if (lastPoint.permanent > 0) {
        return lastPoint.permanent;
    }

    // Calculate decayed balance
    lastPoint.bias -= lastPoint.slope * int128(int256(_t) - int256(lastPoint.ts));
    if (lastPoint.bias < 0) {
        lastPoint.bias = 0;
    }
    return uint256(int256(lastPoint.bias));
}
```

## Lock Management

### Increase Amount

```solidity
/// @notice Add more AERO to existing lock
function increaseAmount(uint256 _tokenId, uint256 _value) external nonReentrant {
    LockedBalance memory oldLocked = _locked[_tokenId];
    if (_value == 0) revert ZeroAmount();
    if (oldLocked.amount == 0) revert NoLockFound();
    if (oldLocked.end <= block.timestamp && !oldLocked.isPermanent) revert LockExpired();
    if (!_isApprovedOrOwner(_msgSender(), _tokenId)) revert NotApprovedOrOwner();

    _depositFor(_tokenId, _value, 0, oldLocked, DepositType.INCREASE_LOCK_AMOUNT);
}

/// @notice Deposit on behalf of a tokenId
function depositFor(uint256 _tokenId, uint256 _value) external nonReentrant {
    LockedBalance memory oldLocked = _locked[_tokenId];
    if (_value == 0) revert ZeroAmount();
    if (oldLocked.amount == 0) revert NoLockFound();
    if (oldLocked.end <= block.timestamp && !oldLocked.isPermanent) revert LockExpired();

    _depositFor(_tokenId, _value, 0, oldLocked, DepositType.DEPOSIT_FOR_TYPE);
}
```

### Increase Lock Duration

```solidity
/// @notice Extend lock duration
function increaseUnlockTime(uint256 _tokenId, uint256 _lockDuration) external nonReentrant {
    LockedBalance memory oldLocked = _locked[_tokenId];
    if (!_isApprovedOrOwner(_msgSender(), _tokenId)) revert NotApprovedOrOwner();
    if (oldLocked.isPermanent) revert PermanentLock();
    if (oldLocked.end <= block.timestamp) revert LockExpired();
    if (oldLocked.amount == 0) revert NoLockFound();

    uint256 unlockTime = ((block.timestamp + _lockDuration) / WEEK) * WEEK;
    if (unlockTime <= oldLocked.end) revert LockDurationNotInFuture();
    if (unlockTime > block.timestamp + MAXTIME) revert LockDurationTooLong();

    _depositFor(_tokenId, 0, unlockTime, oldLocked, DepositType.INCREASE_UNLOCK_TIME);
}
```

### Withdraw

```solidity
/// @notice Withdraw AERO after lock expires
function withdraw(uint256 _tokenId) external nonReentrant {
    address sender = _msgSender();
    if (!_isApprovedOrOwner(sender, _tokenId)) revert NotApprovedOrOwner();
    if (voted[_tokenId]) revert AlreadyVoted();
    if (escrowType[_tokenId] != EscrowType.NORMAL) revert NotNormalNFT();

    LockedBalance memory oldLocked = _locked[_tokenId];
    if (oldLocked.isPermanent) revert PermanentLock();
    if (block.timestamp < oldLocked.end) revert LockNotExpired();

    uint256 value = uint256(int256(oldLocked.amount));
    _locked[_tokenId] = LockedBalance(0, 0, false);

    _checkpoint(_tokenId, oldLocked, LockedBalance(0, 0, false));

    IERC20(token).safeTransfer(sender, value);
    _burn(_tokenId);

    emit Withdraw(sender, _tokenId, value, block.timestamp);
}
```

## Permanent Locks

```solidity
/// @notice Lock NFT permanently (max voting power, no decay)
function lockPermanent(uint256 _tokenId) external {
    if (!_isApprovedOrOwner(_msgSender(), _tokenId)) revert NotApprovedOrOwner();
    if (escrowType[_tokenId] != EscrowType.NORMAL) revert NotNormalNFT();

    LockedBalance memory _newLocked = _locked[_tokenId];
    if (_newLocked.isPermanent) revert PermanentLock();
    if (_newLocked.end <= block.timestamp) revert LockExpired();
    if (_newLocked.amount == 0) revert NoLockFound();

    uint256 _amount = uint256(int256(_newLocked.amount));
    permanentLockBalance += _amount;

    _newLocked.end = 0;
    _newLocked.isPermanent = true;
    _locked[_tokenId] = _newLocked;

    _checkpoint(_tokenId, _locked[_tokenId], _newLocked);

    emit LockPermanent(_msgSender(), _tokenId, _amount, block.timestamp);
}

/// @notice Unlock a permanent lock (starts decay)
function unlockPermanent(uint256 _tokenId) external {
    if (!_isApprovedOrOwner(_msgSender(), _tokenId)) revert NotApprovedOrOwner();
    if (voted[_tokenId]) revert AlreadyVoted();
    if (escrowType[_tokenId] != EscrowType.NORMAL) revert NotNormalNFT();

    LockedBalance memory _newLocked = _locked[_tokenId];
    if (!_newLocked.isPermanent) revert NotPermanentLock();

    uint256 _amount = uint256(int256(_newLocked.amount));
    permanentLockBalance -= _amount;

    _newLocked.end = ((block.timestamp + MAXTIME) / WEEK) * WEEK;
    _newLocked.isPermanent = false;
    _locked[_tokenId] = _newLocked;

    _dedelegateOrRevert(_msgSender(), _tokenId);
    _checkpoint(_tokenId, _locked[_tokenId], _newLocked);

    emit UnlockPermanent(_msgSender(), _tokenId, _amount, block.timestamp);
}
```

## Merge and Split

### Merge

```solidity
/// @notice Merge two NFTs into one
/// @param _from NFT to merge from (will be burned)
/// @param _to NFT to merge into
function merge(uint256 _from, uint256 _to) external nonReentrant {
    address sender = _msgSender();
    if (_from == _to) revert SameNFT();
    if (!_isApprovedOrOwner(sender, _from)) revert NotApprovedOrOwner();
    if (!_isApprovedOrOwner(sender, _to)) revert NotApprovedOrOwner();
    if (voted[_from]) revert AlreadyVoted();
    if (escrowType[_from] != EscrowType.NORMAL) revert NotNormalNFT();
    // _to can be NORMAL or NORMAL with isPermanent

    LockedBalance memory oldLockedTo = _locked[_to];
    if (oldLockedTo.end <= block.timestamp && !oldLockedTo.isPermanent) revert LockExpired();

    LockedBalance memory oldLockedFrom = _locked[_from];
    if (oldLockedFrom.isPermanent) revert PermanentLock();

    uint256 end = oldLockedFrom.end >= oldLockedTo.end ? oldLockedFrom.end : oldLockedTo.end;

    _locked[_from] = LockedBalance(0, 0, false);
    _checkpoint(_from, oldLockedFrom, LockedBalance(0, 0, false));
    _burn(_from);

    LockedBalance memory newLockedTo;
    newLockedTo.amount = oldLockedTo.amount + oldLockedFrom.amount;
    newLockedTo.isPermanent = oldLockedTo.isPermanent;
    newLockedTo.end = oldLockedTo.isPermanent ? 0 : end;

    _checkpoint(_to, oldLockedTo, newLockedTo);
    _locked[_to] = newLockedTo;

    emit Merge(sender, _from, _to, newLockedTo.amount, newLockedTo.end, block.timestamp);
}
```

### Split

```solidity
/// @notice Split one NFT into two
/// @param _from NFT to split (will be burned)
/// @param _amounts Amounts for each new NFT
function split(uint256 _from, uint256[] calldata _amounts)
    external nonReentrant returns (uint256[] memory _tokenIds)
{
    address sender = _msgSender();
    if (!canSplit[sender] && !canSplit[address(0)]) revert SplitNotAllowed();
    if (!_isApprovedOrOwner(sender, _from)) revert NotApprovedOrOwner();
    if (voted[_from]) revert AlreadyVoted();
    if (escrowType[_from] != EscrowType.NORMAL) revert NotNormalNFT();
    if (_amounts.length < 2) revert InvalidSplitAmounts();

    LockedBalance memory locked = _locked[_from];
    if (locked.end <= block.timestamp && !locked.isPermanent) revert LockExpired();

    // Verify amounts sum to total
    uint256 totalAmount;
    for (uint256 i = 0; i < _amounts.length; i++) {
        totalAmount += _amounts[i];
    }
    if (totalAmount != uint256(int256(locked.amount))) revert InvalidSplitAmounts();

    // Burn original
    _locked[_from] = LockedBalance(0, 0, false);
    _checkpoint(_from, locked, LockedBalance(0, 0, false));
    _burn(_from);

    // Create new NFTs
    _tokenIds = new uint256[](_amounts.length);
    for (uint256 i = 0; i < _amounts.length; i++) {
        ++tokenId;
        _tokenIds[i] = tokenId;
        _mint(sender, tokenId);

        LockedBalance memory newLocked = LockedBalance({
            amount: int128(int256(_amounts[i])),
            end: locked.end,
            isPermanent: locked.isPermanent
        });
        _locked[tokenId] = newLocked;
        _checkpoint(tokenId, LockedBalance(0, 0, false), newLocked);
    }

    emit Split(sender, _from, _tokenIds, _amounts, block.timestamp);
}
```

## Managed NFTs

### Creating Managed NFTs

```solidity
/// @notice Create a managed NFT (governance only)
function createManagedLockFor(address _to) external nonReentrant returns (uint256 _mTokenId) {
    address sender = _msgSender();
    if (sender != IVoter(voter).governor() && !isApprovedOrOwner(sender, managedToFree[_to]))
        revert NotGovernorOrManager();

    ++tokenId;
    _mTokenId = tokenId;
    _mint(_to, _mTokenId);

    escrowType[_mTokenId] = EscrowType.MANAGED;
    managedToLocked[_mTokenId] = IVoter(voter).createManagedReward(_mTokenId);
    managedToFree[_mTokenId] = IVoter(voter).createFreeManagedReward(_mTokenId);

    // Managed NFTs are permanent by default
    _locked[_mTokenId] = LockedBalance(0, 0, true);

    emit CreateManaged(_to, _mTokenId, sender, managedToLocked[_mTokenId], managedToFree[_mTokenId]);
}
```

### Depositing into Managed NFT

```solidity
/// @notice Deposit a normal NFT into a managed NFT
function depositManaged(uint256 _tokenId, uint256 _mTokenId) external nonReentrant {
    if (_msgSender() != address(voter)) revert NotVoter();
    if (escrowType[_tokenId] != EscrowType.NORMAL) revert NotNormalNFT();
    if (escrowType[_mTokenId] != EscrowType.MANAGED) revert NotManagedNFT();
    if (deactivated[_mTokenId]) revert ManagedNFTDeactivated();

    LockedBalance memory locked = _locked[_tokenId];
    if (locked.end <= block.timestamp && !locked.isPermanent) revert LockExpired();

    // Convert to locked state
    escrowType[_tokenId] = EscrowType.LOCKED;
    idToManaged[_tokenId] = _mTokenId;

    // Update managed NFT balance
    uint256 _amount = uint256(int256(locked.amount));
    LockedBalance memory managedLocked = _locked[_mTokenId];
    managedLocked.amount += int128(int256(_amount));
    _locked[_mTokenId] = managedLocked;

    // Checkpoint
    _checkpoint(_tokenId, locked, LockedBalance(0, 0, false));
    _checkpoint(_mTokenId, _locked[_mTokenId], managedLocked);

    emit DepositManaged(ownerOf(_tokenId), _tokenId, _mTokenId, _amount, block.timestamp);
}
```

### Withdrawing from Managed NFT

```solidity
/// @notice Withdraw from a managed NFT
function withdrawManaged(uint256 _tokenId) external nonReentrant {
    if (_msgSender() != address(voter)) revert NotVoter();
    if (escrowType[_tokenId] != EscrowType.LOCKED) revert NotLockedNFT();

    uint256 _mTokenId = idToManaged[_tokenId];

    // Calculate locked rewards
    uint256 lockedRewards = IReward(managedToLocked[_mTokenId]).earned(_tokenId);
    IReward(managedToLocked[_mTokenId]).getReward(_tokenId);

    // Convert back to normal with max lock time
    escrowType[_tokenId] = EscrowType.NORMAL;
    delete idToManaged[_tokenId];

    LockedBalance memory lockedOld = _locked[_tokenId];
    LockedBalance memory newLocked = LockedBalance({
        amount: lockedOld.amount + int128(int256(lockedRewards)),
        end: ((block.timestamp + MAXTIME) / WEEK) * WEEK,
        isPermanent: false
    });
    _locked[_tokenId] = newLocked;

    // Update managed NFT
    LockedBalance memory managedLocked = _locked[_mTokenId];
    managedLocked.amount -= lockedOld.amount;
    _locked[_mTokenId] = managedLocked;

    _checkpoint(_tokenId, lockedOld, newLocked);
    _checkpoint(_mTokenId, _locked[_mTokenId], managedLocked);

    emit WithdrawManaged(ownerOf(_tokenId), _tokenId, _mTokenId, uint256(int256(newLocked.amount)), block.timestamp);
}
```

## Delegation

```solidity
/// @notice Delegate voting power to another tokenId
function delegate(uint256 _tokenId, uint256 _delegatee) external {
    if (!_isApprovedOrOwner(_msgSender(), _tokenId)) revert NotApprovedOrOwner();
    if (!_locked[_tokenId].isPermanent) revert NotPermanentLock();
    if (!_locked[_delegatee].isPermanent && escrowType[_delegatee] != EscrowType.MANAGED)
        revert NotPermanentLock();

    // Remove from old delegatee
    uint256 oldDelegatee = delegates[_tokenId];
    if (oldDelegatee != 0) {
        delegatedBalance[oldDelegatee] -= uint256(int256(_locked[_tokenId].amount));
    }

    // Add to new delegatee
    delegates[_tokenId] = _delegatee;
    delegatedBalance[_delegatee] += uint256(int256(_locked[_tokenId].amount));

    emit DelegateChanged(_tokenId, oldDelegatee, _delegatee);
}
```

## Key Events

```solidity
event Deposit(address indexed provider, uint256 indexed tokenId, DepositType indexed depositType, uint256 value, uint256 locktime, uint256 ts);
event Withdraw(address indexed provider, uint256 indexed tokenId, uint256 value, uint256 ts);
event Merge(address indexed sender, uint256 indexed from, uint256 indexed to, uint256 amountFinal, uint256 endFinal, uint256 ts);
event Split(address indexed sender, uint256 indexed from, uint256[] tokenIds, uint256[] amounts, uint256 ts);
event LockPermanent(address indexed sender, uint256 indexed tokenId, uint256 amount, uint256 ts);
event UnlockPermanent(address indexed sender, uint256 indexed tokenId, uint256 amount, uint256 ts);
event CreateManaged(address indexed to, uint256 indexed mTokenId, address indexed creator, address lockedReward, address freeReward);
event DepositManaged(address indexed owner, uint256 indexed tokenId, uint256 indexed mTokenId, uint256 amount, uint256 ts);
event WithdrawManaged(address indexed owner, uint256 indexed tokenId, uint256 indexed mTokenId, uint256 amount, uint256 ts);
```

## Reference Files

- `contracts/VotingEscrow.sol` - Main voting escrow implementation
- `contracts/interfaces/IVotingEscrow.sol` - Interface
- `VOTINGESCROW.md` - State transition documentation
