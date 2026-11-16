// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

interface IMigrationDelegatedClaimFixture {
    function withdrawClaim(uint256 amount_) external returns (uint256);
    function transfer(address to_, uint256 amount_) external returns (bool);
}

/// @notice Local EIP-7702 fixture; only fixed-source claims and NFT receiving.
contract MigrationDelegatedReceiverFixture {
    bool private rejectReceipt;
    address private witness;

    error ReceiverRejected();
    error OnlySelf();

    receive() external payable {}

    modifier sourceCaller() {
        if (msg.sender != address(this) && msg.sender != 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
            && msg.sender != witness) {
            revert OnlySelf();
        }
        _;
    }

    function claim(uint256 amount_) external sourceCaller returns (uint256) {
        return IMigrationDelegatedClaimFixture(0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00).withdrawClaim(amount_);
    }

    function catchClaim(uint256 amount_) external sourceCaller returns (bool, uint256) {
        try IMigrationDelegatedClaimFixture(0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00).withdrawClaim(amount_)
            returns (uint256 received_) { return (true, received_); }
        catch { return (false, 0); }
    }

    function doubleClaim(uint256 first_, uint256 second_) external sourceCaller {
        IMigrationDelegatedClaimFixture source_ =
            IMigrationDelegatedClaimFixture(0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00);
        source_.withdrawClaim(first_);
        source_.withdrawClaim(second_);
    }

    function setWitness(address witness_) external {
        if (msg.sender != address(this)) revert OnlySelf();
        witness = witness_;
    }

    /// @dev Adversarial real effect: source pays this wallet, then it forwards the output away.
    function claimAndForward(uint256 amount_, address recipient_) external sourceCaller returns (uint256 received_) {
        received_ = IMigrationDelegatedClaimFixture(0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00).withdrawClaim(amount_);
        IMigrationDelegatedClaimFixture(0xB55604CF4dcdABB362078e106D20F98512391EdF).transfer(recipient_, received_);
    }

    function setRejectReceipt(bool reject_) external {
        if (msg.sender != address(this)) revert OnlySelf();
        rejectReceipt = reject_;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external view returns (bytes4) {
        if (rejectReceipt) revert ReceiverRejected();
        return 0x150b7a02;
    }
}
