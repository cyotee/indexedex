// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ISource {
    function withdrawClaim(uint256 amount_) external returns (uint256);
}

interface ISy {
    function balanceOf(address wallet_) external view returns (uint256);
    function approve(address spender_, uint256 amount_) external returns (bool);
    function transferFrom(address from_, address to_, uint256 amount_) external returns (bool);
}

/// Source-only custody fixture. No award, loader, arbitrary target, or withdrawal.
contract SourceCustody {
    ISy internal constant SY = ISy(0xB55604CF4dcdABB362078e106D20F98512391EdF);
    address public immutable fullWallet;
    address public immutable splitWallet;
    mapping(address => uint256) public booked;
    error WrongWallet();
    error CustodyMismatch();
    error LateFailure();
    event Received(address indexed wallet, uint256 amount);

    constructor(address full_, address split_) {
        fullWallet = full_;
        splitWallet = split_;
    }

    function take(uint256 amount_, bool failAfterTransfer_) external {
        if (msg.sender != fullWallet && msg.sender != splitWallet) revert WrongWallet();
        uint256 beforeWallet_ = SY.balanceOf(msg.sender);
        uint256 beforeCustody_ = SY.balanceOf(address(this));
        if (!SY.transferFrom(msg.sender, address(this), amount_)) revert CustodyMismatch();
        if (beforeWallet_ - SY.balanceOf(msg.sender) != amount_
            || SY.balanceOf(address(this)) - beforeCustody_ != amount_) revert CustodyMismatch();
        booked[msg.sender] += amount_;
        emit Received(msg.sender, amount_);
        if (failAfterTransfer_) revert LateFailure();
    }
}

/// Narrow owned EIP-7702 delegate, not a Migration executor or historical wallet.
/// Authorization signs code with fixed wallets, relayer, source, SY and custody.
contract DelegatedSourceProbe {
    ISource internal constant SOURCE = ISource(0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00);
    ISy internal constant SY = ISy(0xB55604CF4dcdABB362078e106D20F98512391EdF);
    address public immutable fullWallet;
    address public immutable splitWallet;
    address public immutable relayer;
    SourceCustody public immutable custody;
    error Unauthorized();
    error DeliberateFailure();
    error ApprovalFailed();
    event Attempt(bool success, bytes result);

    constructor(address full_, address split_, address relayer_, SourceCustody custody_) {
        fullWallet = full_;
        splitWallet = split_;
        relayer = relayer_;
        custody = custody_;
    }

    modifier authorized() {
        if ((address(this) != fullWallet && address(this) != splitWallet)
            || (msg.sender != address(this) && msg.sender != relayer)) revert Unauthorized();
        _;
    }

    function ping() external authorized {}

    function fail() external pure {
        revert DeliberateFailure();
    }

    function claim(uint256 weight_) external authorized returns (uint256) {
        return SOURCE.withdrawClaim(weight_);
    }

    function catchClaim(uint256 weight_) external authorized returns (bool, bytes memory) {
        (bool ok_, bytes memory result_) =
            address(SOURCE).call(abi.encodeCall(ISource.withdrawClaim, (weight_)));
        emit Attempt(ok_, result_);
        return (ok_, result_);
    }

    function doubleClaim(uint256 first_, uint256 second_) external authorized {
        SOURCE.withdrawClaim(first_);
        SOURCE.withdrawClaim(second_);
    }

    function claimThenRevert(uint256 weight_) external authorized {
        SOURCE.withdrawClaim(weight_);
        revert DeliberateFailure();
    }

    function approveCustody(uint256 amount_) external authorized {
        if (!SY.approve(address(custody), amount_)) revert ApprovalFailed();
    }

    function take(uint256 amount_, bool failAfterTransfer_) external authorized {
        custody.take(amount_, failAfterTransfer_);
    }
}
