// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {TestBase_UniswapV4OrbitalSwapHook} from
    "test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHook_FactoryService.sol";
import {
    IUniswapV4OrbitalSwapHookPackage
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHookPackage.sol";
import {
    IUniswapV4HookFlags
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookFlags.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

contract UniswapV4OrbitalSwapHook_Factory_Test is TestBase_UniswapV4OrbitalSwapHook {
    function test_F1_hookHasRequiredFlags() public view {
        uint160 flags = uint160(hook) & Hooks.ALL_HOOK_MASK;
        assertEq(flags, PkgFactory.requiredFlags());
        assertEq(flags, hookPkg.requiredHookFlags() & Hooks.ALL_HOOK_MASK);
        assertEq(IUniswapV4HookFlags(hook).requiredHookFlags() & Hooks.ALL_HOOK_MASK, flags);
    }

    /// @notice R30: package postDeploy alone leaves all three doors live on PoolManager.
    /// @dev Keys are pure-built in TestBase — no setUp re-ensure. Fails if postDeploy is a no-op.
    function test_F2_threePoolsInitialized() public view {
        _assertThreePoolsLiveFromPostDeploy();
        assertEq(poolKey01.fee, poolKey12.fee);
        assertEq(poolKey12.fee, poolKey02.fee);
        assertEq(poolKey01.fee, LPFeeLibrary.DYNAMIC_FEE_FLAG);
    }

    function test_F3_isVaultRegistered() public view {
        IVaultRegistryVaultQuery reg = _registry();
        assertTrue(reg.isVault(hook));
        address[] memory vaults = reg.vaultsOfPackage(address(hookPkg));
        bool found;
        for (uint256 i; i < vaults.length; ++i) {
            if (vaults[i] == hook) found = true;
        }
        assertTrue(found, "vaultsOfPackage");
    }

    function test_F4_calcAddressMatchesDeploy() public {
        SimpleMintableERC20 a = new SimpleMintableERC20("A", "A");
        SimpleMintableERC20 b = new SimpleMintableERC20("B", "B");
        SimpleMintableERC20 c = new SimpleMintableERC20("C", "C");
        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = IUniswapV4OrbitalSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: address(a),
            token1: address(b),
            token2: address(c),
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address predicted = hookFactory.calcAddress(
            IUniswapV4HookDiamondPackage(address(hookPkg)), abi.encode(args), mineNonce
        );
        address deployed = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertEq(deployed, predicted);
    }

    function test_F5_idempotentSameArgsNonce() public {
        SimpleMintableERC20 a = new SimpleMintableERC20("X", "X");
        SimpleMintableERC20 b = new SimpleMintableERC20("Y", "Y");
        SimpleMintableERC20 c = new SimpleMintableERC20("Z", "Z");
        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = IUniswapV4OrbitalSwapHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            token0: address(a),
            token1: address(b),
            token2: address(c),
            tickSpacing: 0,
            sqrtPriceX96: 0
        });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h1 = PkgFactory.deployHook(hookPkg, args, mineNonce);
        address h2 = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertEq(h1, h2);
    }

    function test_F6_saltIndependentOfPackageAddress() public {
        // Salt uses PRODUCT_ID + bindings only — package address excluded.
        IUniswapV4OrbitalSwapHookPackage.PkgArgs memory args = _defaultPkgArgs();
        bytes memory processed = hookPkg.processArgs(abi.encode(args));
        bytes32 s1 = hookPkg.calcSalt(processed);
        bytes32 expected = keccak256(
            abi.encode(
                hookPkg.PRODUCT_ID(),
                args.poolManager,
                args.feeOracle,
                args.token0,
                args.token1,
                args.token2
            )
        );
        assertEq(s1, expected);
        // tickSpacing / sqrtPrice not in salt: change process fields, salt stable
        args.tickSpacing = 120;
        args.sqrtPriceX96 = 1;
        bytes32 s2 = hookPkg.calcSalt(hookPkg.processArgs(abi.encode(args)));
        assertEq(s1, s2, "tick/sqrt excluded from salt");
    }

    function test_F7_noDiamondCutOnLiveInstance() public view {
        // PostDeploy removes temporary cut surface; diamondCut selector must not be present.
        bytes4 cutSel = bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"));
        address facet = IDiamondLoupe(hook).facetAddress(cutSel);
        assertEq(facet, address(0), "live instance must not expose diamondCut");
    }

    function test_F8_isExpectedInstanceThin() public view {
        assertTrue(hookPkg.isExpectedInstance(hook, ""));
        assertFalse(hookPkg.isExpectedInstance(address(0xdead), ""));
    }
}
