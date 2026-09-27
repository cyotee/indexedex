// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IERC4626StandardExchangeDFPkg} from "contracts/vaults/standard/erc4626/IERC4626StandardExchangeDFPkg.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {CappedPausableERC4626} from "contracts/test/stubs/CappedPausableERC4626.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @title SeMatrix_ERC4626Fixture
 * @notice ERC-4626 SE row fixture: an 18-decimal (or configured) mintable underlying wrapped by
 *         the D46 `CappedPausableERC4626` protocol stub and the production ERC-4626 SE package
 *         already deployed by `TestBase_ERC4626StandardExchange`. The partial case caps the stub.
 */
contract SeMatrix_ERC4626Fixture is SeMatrixFixture {
    MintableERC20Decimals public immutable underlying;
    CappedPausableERC4626 public immutable protocolVault;
    address internal immutable seVault;

    constructor(Ctx memory c, IERC4626StandardExchangeDFPkg pkg, uint8 decimals_) SeMatrixFixture(c) {
        underlying = new MintableERC20Decimals("Matrix Underlying", "mUND", decimals_);
        protocolVault = new CappedPausableERC4626(underlying);
        vm.prank(c.owner);
        seVault = pkg.deployVault(IERC4626(address(protocolVault)));
        _seedSe();
    }

    /// @dev One whole underlying deposited by the fixture so share->underlying quotes are defined
    ///      before the hook binds (an empty SE quotes 0 for a share input; M6 `seedLiquidity`).
    function _seedSe() internal {
        uint256 one = 10 ** uint256(underlying.decimals());
        underlying.mint(address(this), one);
        underlying.approve(seVault, one);
        IStandardExchangeIn(seVault).exchangeIn(IERC20(address(underlying)), one, IERC20(seVault), 0, address(this), false, block.timestamp + 1 hours);
    }

    function familyName() external pure override returns (string memory) {
        return "ERC4626StandardExchange";
    }

    function faceToken() public view override returns (address) {
        return address(underlying);
    }

    function se() public view override returns (address) {
        return seVault;
    }

    function fund(address to, uint256 amount) external override {
        underlying.mint(to, amount);
    }

    function hasPartialCase() external pure override returns (bool) {
        return true;
    }

    function limitCapacity(uint256 allowFace) external override {
        protocolVault.setDepositCap(protocolVault.totalAssets() + allowFace);
    }

    function openCapacity() external override {
        protocolVault.setDepositCap(0);
        protocolVault.setPaused(false);
    }

    function seBooked() external view override returns (uint256) {
        return IBasicVault(seVault).reserveOfToken(address(underlying));
    }

    function armOperativeRevert() external override {
        vm.mockCallRevert(
            address(protocolVault), abi.encodeWithSelector(bytes4(keccak256("deposit(uint256,address)"))), rejectBytes()
        );
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    function isAmm() external pure override returns (bool) {
        return false;
    }
}

/// @notice Control row: the plain `SimpleYieldERC4626` stub with no capacity gate (rounding control).
contract SeMatrix_SimpleYieldERC4626ControlFixture is SeMatrixFixture {
    MintableERC20Decimals public immutable underlying;
    SimpleYieldERC4626 public immutable protocolVault;
    address internal immutable seVault;

    constructor(Ctx memory c, IERC4626StandardExchangeDFPkg pkg, uint8 decimals_) SeMatrixFixture(c) {
        underlying = new MintableERC20Decimals("Control Underlying", "cUND", decimals_);
        protocolVault = new SimpleYieldERC4626(underlying);
        vm.prank(c.owner);
        seVault = pkg.deployVault(IERC4626(address(protocolVault)));
        uint256 one = 10 ** uint256(underlying.decimals());
        underlying.mint(address(this), one);
        underlying.approve(seVault, one);
        IStandardExchangeIn(seVault).exchangeIn(IERC20(address(underlying)), one, IERC20(seVault), 0, address(this), false, block.timestamp + 1 hours);
    }

    function familyName() external pure override returns (string memory) {
        return "SimpleYieldERC4626Control";
    }

    function faceToken() public view override returns (address) {
        return address(underlying);
    }

    function se() public view override returns (address) {
        return seVault;
    }

    function fund(address to, uint256 amount) external override {
        underlying.mint(to, amount);
    }

    function hasPartialCase() external pure override returns (bool) {
        return false;
    }

    function limitCapacity(uint256) external pure override {
        revert("control: no partial case");
    }

    function openCapacity() external override {}

    function seBooked() external view override returns (uint256) {
        return IBasicVault(seVault).reserveOfToken(address(underlying));
    }

    function armOperativeRevert() external override {
        vm.mockCallRevert(
            address(protocolVault), abi.encodeWithSelector(bytes4(keccak256("deposit(uint256,address)"))), rejectBytes()
        );
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    function isAmm() external pure override returns (bool) {
        return false;
    }
}
