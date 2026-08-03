// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

/**
 * @title SimpleYieldERC4626
 * @notice Minimal ERC-4626 with controllable yield for hermetic SE tests (non-SUT harness).
 * @dev Interest is modeled by increasing totalAssets via `simulateYield` without minting shares
 *      — real pro-rata growth path for convertToAssets / previewRedeem.
 */
contract SimpleYieldERC4626 is SimpleMintableERC20 {
    SimpleMintableERC20 public immutable assetToken;
    uint256 public totalAssetsStored;

    constructor(SimpleMintableERC20 asset_) SimpleMintableERC20("Simple Yield Vault", "sYLD") {
        assetToken = asset_;
    }

    function asset() external view returns (address) {
        return address(assetToken);
    }

    function totalAssets() public view returns (uint256) {
        return totalAssetsStored;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0 || totalAssetsStored == 0) return assets;
        return (assets * supply) / totalAssetsStored;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) return shares;
        return (shares * totalAssetsStored) / supply;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0 || totalAssetsStored == 0) return shares;
        return (shares * totalAssetsStored + supply - 1) / supply;
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0 || totalAssetsStored == 0) return assets;
        return (assets * supply + totalAssetsStored - 1) / totalAssetsStored;
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver) external virtual returns (uint256 shares) {
        shares = convertToShares(assets);
        require(assetToken.transferFrom(msg.sender, address(this), assets), "pull");
        totalAssetsStored += assets;
        _mintShares(receiver, shares);
    }

    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        assets = previewMint(shares);
        require(assetToken.transferFrom(msg.sender, address(this), assets), "pull");
        totalAssetsStored += assets;
        _mintShares(receiver, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner_)
        external
        returns (uint256 shares)
    {
        shares = previewWithdraw(assets);
        _burnShares(owner_, shares);
        totalAssetsStored -= assets;
        require(assetToken.transfer(receiver, assets), "pay");
    }

    function redeem(uint256 shares, address receiver, address owner_)
        external
        virtual
        returns (uint256 assets)
    {
        assets = convertToAssets(shares);
        _burnShares(owner_, shares);
        totalAssetsStored -= assets;
        require(assetToken.transfer(receiver, assets), "pay");
    }

    /// @notice Accrue yield by transferring extra underlying into the vault and raising totalAssets.
    function simulateYield(uint256 assets) external {
        require(assetToken.transferFrom(msg.sender, address(this), assets), "yield pull");
        totalAssetsStored += assets;
    }

    function _mintShares(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burnShares(address from, uint256 amount) internal {
        require(balanceOf[from] >= amount, "shares");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}
