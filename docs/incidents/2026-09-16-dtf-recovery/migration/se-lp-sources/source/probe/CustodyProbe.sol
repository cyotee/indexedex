// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.35;

interface ISource {
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
}

/// @notice Disposable source witness, not Migration or a credit issuer.
contract CustodyProbe {
    ISource public constant SOURCE = ISource(0x999DaE02D22E5FEe1c4508430D5196d31d631009);
    address public immutable wallet;
    uint256 public remainingUnits;
    uint256 public remainingCredit = 1001;
    uint256 public booked;

    error WrongWallet();
    error MissingRecord();
    error InvalidQuantity();
    error BadTransfer();
    error LateFailure();

    constructor(address wallet_, uint256 units_) {
        wallet = wallet_;
        remainingUnits = units_;
    }

    function pull(uint256 q, bool configured, bool failLate) external {
        if (!configured) revert MissingRecord();
        if (msg.sender != wallet) revert WrongWallet();
        uint256 units = remainingUnits;
        if (q == 0 || q > units) revert InvalidQuantity();
        uint256 credit = q == units ? remainingCredit : remainingCredit * q / units;
        if (credit == 0) revert InvalidQuantity();
        uint256 beforeWallet = SOURCE.balanceOf(wallet);
        uint256 beforeCustody = SOURCE.balanceOf(address(this));
        if (!SOURCE.transferFrom(wallet, address(this), q)) revert BadTransfer();
        if (beforeWallet - SOURCE.balanceOf(wallet) != q
            || SOURCE.balanceOf(address(this)) - beforeCustody != q) revert BadTransfer();
        remainingUnits = units - q;
        remainingCredit -= credit;
        booked += q;
        if (failLate) revert LateFailure();
    }
}
