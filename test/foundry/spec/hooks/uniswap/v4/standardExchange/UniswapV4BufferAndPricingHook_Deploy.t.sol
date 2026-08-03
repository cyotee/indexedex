// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMinerCreate3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {IUniswapV4BufferAndPricingHook} from
    "contracts/hooks/uniswap/v4/standardExchange/interfaces/IUniswapV4BufferAndPricingHook.sol";
import {
    UniswapV4BufferAndPricingHook_FactoryService
} from "contracts/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHook_FactoryService.sol";

/**
 * @title UniswapV4BufferAndPricingHook_Deploy_Test
 * @notice Deploy / mine / idempotency / preview passthrough tests (production create3Factory path).
 */
contract UniswapV4BufferAndPricingHook_Deploy_Test is TestBase_ERC4626StandardExchange {
    using UniswapV4BufferAndPricingHook_FactoryService for ICreate3FactoryProxy;

    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal se;
    IPoolManager internal pm;
    address internal hook;

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();

        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new SimpleYieldERC4626(underlying);
        se = _deployERC4626SE(address(protocolVault));

        // Hermetic PoolManager (Crane port) — deployer = this test for owner
        pm = IPoolManager(
            vm.deployCode(
                "lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:PoolManager",
                abi.encode(address(this))
            )
        );

        // create3Factory onlyOwnerOrOperator — test contract is operator via CraneTest
        hook = UniswapV4BufferAndPricingHook_FactoryService.deployHook(
            create3Factory, pm, se, address(underlying)
        );
    }

    function test_HD1_deployedFlagsMatchBaseTokenWrapperPermissions() public view {
        uint160 flags = UniswapV4BufferAndPricingHook_FactoryService.requiredFlags();
        assertEq(uint160(hook) & HookMinerCreate3.FLAG_MASK, flags);
        Hooks.validateHookPermissions(IHooks(hook), _perms());
    }

    function test_HD2_idempotentRedeploySameNamespace() public {
        address again = UniswapV4BufferAndPricingHook_FactoryService.deployHook(
            create3Factory, pm, se, address(underlying)
        );
        assertEq(again, hook);
    }

    function test_HD3_differentNamespace_secondInstance() public {
        address other = UniswapV4BufferAndPricingHook_FactoryService.deployHook(
            create3Factory, pm, se, address(underlying), "uv4-buffer-pricing-hook-test-"
        );
        assertTrue(other != hook);
        assertEq(uint160(other) & HookMinerCreate3.FLAG_MASK, UniswapV4BufferAndPricingHook_FactoryService.requiredFlags());
        assertEq(IUniswapV4BufferAndPricingHook(other).standardExchange(), se);
    }

    function test_HD5_viewsEqualDeployArgs() public view {
        IUniswapV4BufferAndPricingHook h = IUniswapV4BufferAndPricingHook(hook);
        assertEq(address(h.poolManager()), address(pm));
        assertEq(h.standardExchange(), se);
        assertEq(h.underlying(), address(underlying));
        assertEq(h.wrapper(), se);
    }

    function test_HD6_wrongUnderlying_reverts() public {
        SimpleMintableERC20 other = new SimpleMintableERC20("Other", "OTH");
        // Ctor validates underlying ∈ SE.vaultTokens(); CREATE3 may wrap as ErrorCreatingContract.
        bool reverted;
        try this.deployHookExternal(address(other)) {
            reverted = false;
        } catch {
            reverted = true;
        }
        assertTrue(reverted, "wrong underlying must fail deploy");
    }

    function deployHookExternal(address underlying_) external returns (address) {
        return UniswapV4BufferAndPricingHook_FactoryService.deployHook(
            create3Factory, pm, se, underlying_
        );
    }

    function test_HP1_previewWrap_matchesSE() public {
        // Seed liquidity so SE previews work for wrap after first deposit path
        underlying.mint(address(this), 100 ether);
        underlying.approve(se, type(uint256).max);
        IStandardExchangeIn(se).exchangeIn(
            IERC20(address(underlying)),
            50 ether,
            IERC20(se),
            0,
            address(this),
            false,
            block.timestamp
        );

        uint256 amountIn = 10 ether;
        uint256 fromHook = IUniswapV4BufferAndPricingHook(hook).previewWrap(amountIn);
        uint256 fromSE = IStandardExchangeIn(se).previewExchangeIn(
            IERC20(address(underlying)), amountIn, IERC20(se)
        );
        assertEq(fromHook, fromSE);
    }

    function test_HP2_zeroPreview_reverts() public {
        vm.expectRevert();
        IUniswapV4BufferAndPricingHook(hook).previewWrap(0);
        vm.expectRevert();
        IUniswapV4BufferAndPricingHook(hook).previewUnwrap(0);
        vm.expectRevert();
        IUniswapV4BufferAndPricingHook(hook).previewWrapExactOut(0);
        vm.expectRevert();
        IUniswapV4BufferAndPricingHook(hook).previewUnwrapExactOut(0);
    }

    function _perms() internal pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            beforeAddLiquidity: true,
            beforeSwap: true,
            beforeSwapReturnDelta: true,
            afterSwap: false,
            afterInitialize: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeDonate: false,
            afterDonate: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
}
