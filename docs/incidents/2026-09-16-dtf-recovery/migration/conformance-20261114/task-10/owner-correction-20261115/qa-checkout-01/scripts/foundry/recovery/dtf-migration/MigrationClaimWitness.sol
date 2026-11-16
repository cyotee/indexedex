// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

interface IMigrationClaimWitnessToken {
    function balanceOf(address account_) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/// @notice A transaction-local observation router, not an eligibility authority or ERC-4337 implementation.
/// @dev No storage, delegatecall, beneficiary, or asset custody. The selected RPC's call trace
/// authenticates both sets of STATICCALL results around the complete wallet invocation.
contract MigrationClaimWitness {
    address private constant SOURCE = 0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00;
    address private constant VAULT = 0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0;
    address private constant SY = 0xB55604CF4dcdABB362078e106D20F98512391EdF;

    error WalletCallFailed(bytes reason);

    function witness(address wallet_, bytes calldata data_)
        external returns (uint256[7] memory before_, uint256[7] memory after_)
    {
        before_ = _books(wallet_);
        (bool success_, bytes memory result_) = wallet_.call(data_);
        if (!success_) revert WalletCallFailed(result_);
        after_ = _books(wallet_);
    }

    function _books(address wallet_) private view returns (uint256[7] memory values_) {
        values_[0] = IMigrationClaimWitnessToken(SOURCE).balanceOf(wallet_);
        values_[1] = IMigrationClaimWitnessToken(SOURCE).totalSupply();
        values_[2] = IMigrationClaimWitnessToken(VAULT).balanceOf(SOURCE);
        values_[3] = IMigrationClaimWitnessToken(VAULT).totalSupply();
        values_[4] = IMigrationClaimWitnessToken(SY).balanceOf(wallet_);
        values_[5] = IMigrationClaimWitnessToken(SY).balanceOf(VAULT);
        values_[6] = IMigrationClaimWitnessToken(SY).totalSupply();
    }
}
