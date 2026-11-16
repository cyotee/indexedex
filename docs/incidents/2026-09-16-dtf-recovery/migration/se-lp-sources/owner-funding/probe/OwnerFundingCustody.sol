// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.35;

interface ISource {
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
}

/// @notice Disposable synthetic custody witness, not Migration or a credit issuer.
abstract contract OwnerFundingCustody {
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

    function source() public pure virtual returns (ISource);

    function pull(uint256 q, bool configured, bool failLate) external {
        if (!configured) revert MissingRecord();
        if (msg.sender != wallet) revert WrongWallet();
        uint256 units = remainingUnits;
        if (q == 0 || q > units) revert InvalidQuantity();
        uint256 credit = q == units ? remainingCredit : remainingCredit * q / units;
        if (credit == 0) revert InvalidQuantity();
        ISource token = source();
        uint256 beforeWallet = token.balanceOf(wallet);
        uint256 beforeCustody = token.balanceOf(address(this));
        if (!token.transferFrom(wallet, address(this), q)) revert BadTransfer();
        if (beforeWallet - token.balanceOf(wallet) != q
            || token.balanceOf(address(this)) - beforeCustody != q) revert BadTransfer();
        remainingUnits = units - q;
        remainingCredit -= credit;
        booked += q;
        if (failLate) revert LateFailure();
    }
}

contract EarlierLpCustody is OwnerFundingCustody {
    constructor(address wallet_, uint256 units_) OwnerFundingCustody(wallet_, units_) {}

    function source() public pure override returns (ISource) {
        return ISource(0x923877336b14662cFb5B3A60b14e7d716d54A888);
    }
}

contract WeightedLpCustody is OwnerFundingCustody {
    constructor(address wallet_, uint256 units_) OwnerFundingCustody(wallet_, units_) {}

    function source() public pure override returns (ISource) {
        return ISource(0x46E068c2393e189Fbc86632f67210aF253a42Aa8);
    }
}
