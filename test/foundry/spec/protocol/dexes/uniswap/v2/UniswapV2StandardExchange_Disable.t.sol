// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";

/// @notice Uniswap V2 Standard Exchange respects registry kill-switch by address and package.
contract UniswapV2StandardExchange_Disable_Test is TestBase_UniswapV2StandardExchange_MultiPool {
    IVaultRegistryDisableQuery internal disableQuery;
    IVaultRegistryDisableManager internal disableManager;

    function setUp() public virtual override {
        super.setUp();
        disableQuery = IVaultRegistryDisableQuery(address(indexedexManager));
        disableManager = IVaultRegistryDisableManager(address(indexedexManager));
    }

    function test_disableByVaultAddress_blocksExchangeIn() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        address vaultAddr = address(vault);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(vaultAddr);

        vm.prank(owner);
        disableManager.setVaultAddressDisabled(vaultAddr, true);
        assertTrue(disableQuery.isDisabled(vaultAddr));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP");

        // preview still works
        vault.previewExchangeIn(lpToken, lpAmount, vaultToken);

        lpToken.approve(vaultAddr, lpAmount);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, vaultAddr));
        vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());
    }

    function test_reenableVaultAddress_allowsExchangeIn() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        address vaultAddr = address(vault);
        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(vaultAddr);

        vm.startPrank(owner);
        disableManager.setVaultAddressDisabled(vaultAddr, true);
        disableManager.setVaultAddressDisabled(vaultAddr, false);
        vm.stopPrank();

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP");
        lpToken.approve(vaultAddr, lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());
        assertTrue(shares > 0);
    }

    function test_disableByPackage_blocksExchangeIn() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        address vaultAddr = address(vault);
        address pkg = disableQuery.packageOfVault(vaultAddr);
        assertTrue(pkg != address(0));
        assertEq(pkg, address(uniswapV2StandardExchangeDFPkg));

        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(vaultAddr);

        vm.prank(owner);
        disableManager.setPackageDisabled(pkg, true);

        // All vaults of this package disabled
        assertTrue(disableQuery.isDisabled(address(_getVault(PoolConfig.Unbalanced))));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP");
        lpToken.approve(vaultAddr, lpAmount);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, vaultAddr));
        vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());
    }

    function test_reenablePackage_allowsExchangeIn() public {
        IStandardExchangeProxy vault = _getVault(PoolConfig.Balanced);
        address vaultAddr = address(vault);
        address pkg = disableQuery.packageOfVault(vaultAddr);

        vm.startPrank(owner);
        disableManager.setPackageDisabled(pkg, true);
        disableManager.setPackageDisabled(pkg, false);
        vm.stopPrank();

        IUniswapV2Pair pair = _getPool(PoolConfig.Balanced);
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(vaultAddr);
        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP");
        lpToken.approve(vaultAddr, lpAmount);
        uint256 shares = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, address(this), false, _deadline());
        assertTrue(shares > 0);
    }
}
