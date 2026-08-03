// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";

/**
 * @title TestBase_UniswapV4DualSEBCPHook
 * @notice Hermetic dual SE buffer CP hook: two real ERC-4626 SE legs + PoolManager + fee oracle.
 */
abstract contract TestBase_UniswapV4DualSEBCPHook is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal tokenA;
    SimpleMintableERC20 internal tokenB;
    SimpleYieldERC4626 internal vaultA;
    SimpleYieldERC4626 internal vaultB;
    address internal seA;
    address internal seB;
    IPoolManager internal pm;
    address internal hook;
    IDualHook internal dual;
    PoolKey internal poolKey;
    address internal user = address(0xBEEF);

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint256 internal constant DUST = 10;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();

        tokenA = new SimpleMintableERC20("TokenA", "TKA");
        tokenB = new SimpleMintableERC20("TokenB", "TKB");
        vaultA = new SimpleYieldERC4626(tokenA);
        vaultB = new SimpleYieldERC4626(tokenB);
        seA = _deployERC4626SE(address(vaultA));
        seB = _deployERC4626SE(address(vaultB));

        pm = IPoolManager(
            vm.deployCode(
                "lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:PoolManager",
                abi.encode(address(this))
            )
        );

        hook = DualFactory.deployHook(
            create3Factory,
            pm,
            IVaultFeeOracleQuery(address(indexedexManager)),
            seA,
            address(tokenA),
            seB,
            address(tokenB)
        );
        dual = IDualHook(hook);

        // Non-zero SE buffer usage fees for DoD (D70)
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seA, 0.01e18);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(seB, 0.01e18);
        vm.stopPrank();

        // Fund user
        tokenA.mint(user, 1_000_000 ether);
        tokenB.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        tokenA.approve(hook, type(uint256).max);
        tokenB.approve(hook, type(uint256).max);
        vm.stopPrank();
    }

    function _initPool() internal {
        poolKey = PoolKey({
            currency0: Currency.wrap(dual.currency0()),
            currency1: Currency.wrap(dual.currency1()),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        pm.initialize(poolKey, SQRT_PRICE_1_1);
    }

    function _amountForCurrency(address currency, uint256 amtA, uint256 amtB)
        internal
        view
        returns (uint256)
    {
        if (currency == address(tokenA)) return amtA;
        if (currency == address(tokenB)) return amtB;
        revert("unknown currency");
    }

    function _depositBoth(uint256 amtA, uint256 amtB) internal returns (uint256 lp) {
        uint256 a0 = _amountForCurrency(dual.currency0(), amtA, amtB);
        uint256 a1 = _amountForCurrency(dual.currency1(), amtA, amtB);
        vm.prank(user);
        (lp,,) = dual.deposit(a0, a1, user, 0, block.timestamp + 1 hours);
    }

    function _enableProtocolFee(uint256 feeWad) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(hook, feeWad);
        // feeTo already set on indexedex manager in IndexedexTest
        vm.stopPrank();
    }
}
