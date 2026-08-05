// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    IUniswapV4HookFlags
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookFlags.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/single/TestBase_UniswapV4SingleStandardExchangeBufferHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/single/interfaces/IUniswapV4SingleStandardExchangeBufferHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHook_FactoryService.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

/**
 * @title UniswapV4SingleSEBufferHook_Deploy_Test
 * @notice Phase 0 + A + E: SE gate, flags, registry, salt, auto-mine.
 */
contract UniswapV4SingleSEBufferHook_Deploy_Test is TestBase {
    function test_phase0_sePairPreviewEqualsExec() public {
        _assertSePreviewEqualsExec(50 ether);
    }

    function test_deploy_hookAddressHasRequiredFlags() public view {
        uint160 want = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
        assertEq(uint160(hook) & Create2Lib.FLAG_MASK, want & Create2Lib.FLAG_MASK, "flags");
        assertEq(IUniswapV4HookFlags(hook).requiredHookFlags(), want & Create2Lib.FLAG_MASK, "flags view");
    }

    function test_deploy_bindingsAndCurrencyOrder() public view {
        assertEq(address(buffer.poolManager()), address(pm));
        assertEq(buffer.standardExchange(), se);
        assertEq(buffer.pairToken(), address(pairToken));
        assertEq(buffer.wrapper(), se);

        address c0 = buffer.currency0();
        address c1 = buffer.currency1();
        assertTrue(c0 < c1, "currency0 must be lower address");
        assertTrue(
            (c0 == address(pairToken) && c1 == se) || (c0 == se && c1 == address(pairToken)),
            "currencies are pair/SE"
        );
        assertEq(buffer.poolFee(), 0);
        assertEq(buffer.tickSpacingHint(), int24(60));
        assertEq(buffer.sqrtPriceX96Hint(), SQRT_PRICE_1_1);
    }

    function test_deploy_registeredAsVault() public view {
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(hook), "isVault");
    }

    function test_D3_idempotentRedeploySameBinding() public {
        IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory args = _defaultPkgArgs();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address again = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertEq(again, hook);
    }

    function test_D_differentPairToken_differentAddress() public {
        SimpleMintableERC20 otherPair = new SimpleMintableERC20("Other", "OTH");
        IERC4626 otherPv = _deployCraneErc4626(address(otherPair));
        address otherSe = _deployERC4626SE(address(otherPv));

        IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory args = IUniswapV4SingleStandardExchangeBufferHookPackage
            .PkgArgs({poolManager: address(pm), standardExchange: otherSe, pairToken: address(otherPair)});
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address other = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertTrue(other != hook, "different binding different address");
        assertEq(uint160(other) & Create2Lib.FLAG_MASK, uint160(hook) & Create2Lib.FLAG_MASK);
    }

    /// @notice O16: at least one Deploy test exercises deployVaultAutoMine.
    function test_D_deployVaultAutoMine() public {
        SimpleMintableERC20 autoPair = new SimpleMintableERC20("Auto", "AUTO");
        IERC4626 autoPv = _deployCraneErc4626(address(autoPair));
        address autoSe = _deployERC4626SE(address(autoPv));

        IUniswapV4SingleStandardExchangeBufferHookPackage.PkgArgs memory args = IUniswapV4SingleStandardExchangeBufferHookPackage
            .PkgArgs({poolManager: address(pm), standardExchange: autoSe, pairToken: address(autoPair)});
        address autoHook = hookPkg.deployVaultAutoMine(args);
        assertTrue(autoHook.code.length > 0, "auto-mine deploys code");
        assertEq(uint160(autoHook) & Create2Lib.FLAG_MASK, uint160(hook) & Create2Lib.FLAG_MASK, "auto flags");
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(autoHook), "auto isVault");
    }

    function test_D_isExpectedInstance() public view {
        assertTrue(hookPkg.isExpectedInstance(hook, ""), "expected");
        assertFalse(hookPkg.isExpectedInstance(address(0x1234), ""), "no code");
    }
}
