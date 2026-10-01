// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// tag::FullSpreadG5GuardToken[]
/// @notice Hostile underlying only; the vault, registry and manager remain production contracts.
contract FullSpreadG5GuardToken {
    string public constant name = "G5 guard asset";
    string public constant symbol = "G5";
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public metadataFails;
    bool public chargeFee;
    bool public propagate;
    address public callbackTarget;
    bytes public callbackData;
    bytes public callbackError;
    uint256 public callbackAttempts;
    error G5MetadataUnavailable();

    /// @notice Seed the external test asset before production pool initialization.
    constructor() { totalSupply = 1e32; balanceOf[msg.sender] = totalSupply; }
    /// @notice Exercise a real dependency revert without replacing the vault's metadata call.
    function decimals() external view returns (uint8) {
        if (metadataFails) revert G5MetadataUnavailable();
        return 18;
    }
    /// @notice Arm metadata failure after the real pool and vault have been deployed.
    function setMetadataFailure(bool value_) external { metadataFails = value_; }
    /// @notice Arm a one-percent short-delivery failure.
    function setFee(bool value_) external { chargeFee = value_; }
    /// @notice Configure a money-path callback and whether its exact error propagates.
    function setCallback(address target_, bytes memory data_, bool propagate_) external {
        callbackTarget = target_; callbackData = data_; propagate = propagate_;
        callbackAttempts = 0; delete callbackError;
    }
    /// @notice Standard approval with real allowance accounting.
    function approve(address spender_, uint256 value_) external returns (bool) {
        allowance[msg.sender][spender_] = value_; return true;
    }
    /// @notice Transfer real units; transfers alone do not invoke the callback.
    function transfer(address to_, uint256 value_) external returns (bool) {
        _move(msg.sender, to_, value_); return true;
    }
    /// @notice Pull real units and attempt the armed callback after delivery.
    function transferFrom(address from_, address to_, uint256 value_) external returns (bool) {
        uint256 approved = allowance[from_][msg.sender];
        if (approved != type(uint256).max) allowance[from_][msg.sender] = approved - value_;
        _move(from_, to_, value_);
        if (callbackTarget != address(0)) {
            ++callbackAttempts;
            (bool ok, bytes memory reason) = callbackTarget.call(callbackData);
            require(!ok, "G5 nested money path succeeded");
            if (propagate) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
            callbackError = reason;
        }
        return true;
    }
    function _move(address from_, address to_, uint256 value_) private {
        balanceOf[from_] -= value_;
        uint256 fee = chargeFee ? value_ / 100 : 0;
        balanceOf[to_] += value_ - fee; totalSupply -= fee;
    }
}
// end::FullSpreadG5GuardToken[]
