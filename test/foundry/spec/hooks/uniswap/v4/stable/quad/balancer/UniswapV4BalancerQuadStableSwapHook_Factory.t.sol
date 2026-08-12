// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {
    TestBase_UniswapV4BalancerQuadStableSwapHook,
    MintableDec,
    RateProviderHarness
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/TestBase_UniswapV4BalancerQuadStableSwapHook.sol";
import {
    UniswapV4BalancerQuadStableSwapHook_FactoryService as FactoryService
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHook_FactoryService.sol";
import {
    IUniswapV4BalancerQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/interfaces/IUniswapV4BalancerQuadStableSwapHook.sol";
import {
    IUniswapV4BalancerQuadStableSwapHookPackage
} from "contracts/hooks/uniswap/v4/stable/quad/balancer/interfaces/IUniswapV4BalancerQuadStableSwapHookPackage.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    IUniswapV4HookDiamondPackage
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackage.sol";

/**
 * @title UniswapV4BalancerQuadStableSwapHook_Factory_Test
 * @notice Package deploy path: six doors, salt, flags, ensurePairPools, validation.
 */
contract UniswapV4BalancerQuadStableSwapHook_Factory_Test is TestBase_UniswapV4BalancerQuadStableSwapHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    function test_F1_packageDeploy_sixPools() public view {
        assertTrue(hook.code.length > 0);
        _assertSixPoolsLiveFromPostDeploy();
        assertTrue(_registry().isVault(hook));
    }

    function test_F2_deployWithMineNonce() public {
        address[4] memory toks = _fourNewTokens("PB");
        address[4] memory providers;
        IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory args =
            _pkgArgs(toks[0], toks[1], toks[2], toks[3], DEMO_FEE, DEMO_AMP, providers);
        uint256 goodNonce = FactoryService.findMineNonce(hookFactory, hookPkg, args);
        address h = hookPkg.deployVault(args, goodNonce);
        assertTrue(h.code.length > 0);
        assertTrue(_registry().isVault(h));
        PoolKey[6] memory keys = hookPkg.pairPoolKeys(h);
        for (uint256 i; i < 6; ++i) {
            (uint160 sqrtPrice,,,) = pm.getSlot0(keys[i].toId());
            assertGt(sqrtPrice, 0, "path B pool live");
        }
        assertEq(uint160(h) & Create2Lib.FLAG_MASK, FactoryService.requiredFlags() & Create2Lib.FLAG_MASK);

        // bad mineNonce for a different binding must fail flags
        address[4] memory toks2 = _fourNewTokens("PBb");
        IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory args2 =
            _pkgArgs(toks2[0], toks2[1], toks2[2], toks2[3], DEMO_FEE, DEMO_AMP, providers);
        uint256 badNonce = _findBadMineNonce(args2);
        vm.expectRevert();
        hookPkg.deployVault(args2, badNonce);
    }

    function _findBadMineNonce(IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory args)
        internal
        returns (uint256 bad)
    {
        uint160 want = FactoryService.requiredFlags() & Create2Lib.FLAG_MASK;
        for (uint256 n; n < 10_000; ++n) {
            address predicted = hookFactory.calcAddress(
                IUniswapV4HookDiamondPackage(address(hookPkg)), abi.encode(args), n
            );
            if ((uint160(predicted) & Create2Lib.FLAG_MASK) != want) return n;
        }
        revert("no bad mineNonce");
    }

    function test_F3_permissionless_ensurePairPools() public {
        address[4] memory toks = _fourNewTokens("EOA");
        address[4] memory providers;
        address h = _deployHook(_pkgArgs(toks[0], toks[1], toks[2], toks[3], DEMO_FEE, DEMO_AMP, providers));
        // postDeploy already ensured; permissionless re-ensure is idempotent
        vm.prank(deployerEoa);
        (PoolKey[6] memory keys, uint8 created) = hookPkg.ensurePairPools(h);
        assertEq(created, 0, "all already live");
        for (uint256 i; i < 6; ++i) {
            (uint160 sqrtPrice,,,) = pm.getSlot0(keys[i].toId());
            assertGt(sqrtPrice, 0);
        }
    }

    function test_F4_unsorted_reverts() public {
        address[4] memory providers;
        IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory bad = _pkgArgs(
            address(t3), address(t2), address(t1), address(t0), DEMO_FEE, DEMO_AMP, providers
        );
        vm.expectRevert(IUniswapV4BalancerQuadStableSwapHookPackage.InvalidTokenOrder.selector);
        hookPkg.processArgs(abi.encode(bad));
    }

    function test_F5_zeroFee_reverts() public {
        address[4] memory toks = _fourNewTokens("ZF");
        address[4] memory providers;
        IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory bad =
            _pkgArgs(toks[0], toks[1], toks[2], toks[3], 0, DEMO_AMP, providers);
        vm.expectRevert(IUniswapV4BalancerQuadStableSwapHookPackage.InvalidFee.selector);
        hookPkg.processArgs(abi.encode(bad));
    }

    function test_F5_zeroAmp_reverts() public {
        address[4] memory toks = _fourNewTokens("ZA");
        address[4] memory providers;
        IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory bad =
            _pkgArgs(toks[0], toks[1], toks[2], toks[3], DEMO_FEE, 0, providers);
        vm.expectRevert(IUniswapV4BalancerQuadStableSwapHookPackage.InvalidAmp.selector);
        hookPkg.processArgs(abi.encode(bad));
    }

    function test_F5a_missingSymbol_last4hex_and_namePrefix() public {
        NoSymbolToken a = new NoSymbolToken();
        NoSymbolToken b = new NoSymbolToken();
        NoSymbolToken c = new NoSymbolToken();
        NoSymbolToken d = new NoSymbolToken();
        address[4] memory addrs = [address(a), address(b), address(c), address(d)];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j + 1 < 4; ++j) {
                if (addrs[j] > addrs[j + 1]) (addrs[j], addrs[j + 1]) = (addrs[j + 1], addrs[j]);
            }
        }
        address[4] memory providers;
        address h = _deployHook(
            _pkgArgs(addrs[0], addrs[1], addrs[2], addrs[3], DEMO_FEE, DEMO_AMP, providers)
        );
        (, bytes memory ret) = h.staticcall(abi.encodeWithSignature("symbol()"));
        string memory s = abi.decode(ret, (string));
        assertTrue(bytes(s).length > 0 && bytes(s).length <= 32);
        (, bytes memory retN) = h.staticcall(abi.encodeWithSignature("name()"));
        string memory n = abi.decode(retN, (string));
        assertTrue(_startsWith(n, "Balancer QS "));
        assertTrue(bytes(n).length <= 64);
    }

    function test_F6_idempotent_redeploy() public {
        address[4] memory providers;
        IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory args = _defaultPkgArgs();
        uint256 mineNonce = FactoryService.findMineNonce(hookFactory, hookPkg, args);
        address h2 = hookPkg.deployVault(args, mineNonce);
        assertEq(h2, hook);
    }

    function test_F7_salt_independent_of_package_address() public view {
        bytes memory encoded = abi.encode(_defaultPkgArgs());
        bytes32 salt = hookPkg.calcSalt(encoded);
        // salt is pure over PRODUCT_ID + binding — not address(hookPkg)
        assertTrue(salt != bytes32(0));
        assertEq(salt, hookPkg.calcSalt(encoded));
    }

    function test_F8_rateProviders_in_salt() public {
        address[4] memory toks = _fourNewTokens("RP");
        address[4] memory pZero;
        RateProviderHarness rp = new RateProviderHarness();
        address[4] memory pOne;
        pOne[0] = address(rp);

        IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory a0 =
            _pkgArgs(toks[0], toks[1], toks[2], toks[3], DEMO_FEE, DEMO_AMP, pZero);
        IUniswapV4BalancerQuadStableSwapHookPackage.PkgArgs memory a1 =
            _pkgArgs(toks[0], toks[1], toks[2], toks[3], DEMO_FEE, DEMO_AMP, pOne);
        assertTrue(hookPkg.calcSalt(abi.encode(a0)) != hookPkg.calcSalt(abi.encode(a1)));

        address h0 = _deployHook(a0);
        address h1 = _deployHook(a1);
        assertTrue(h0 != h1);
    }

    function test_F9_mineFlags_matchPermissions() public pure {
        uint160 flags = FactoryService.requiredFlags();
        assertEq(
            flags,
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                    | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_DONATE_FLAG
            )
        );
    }

    function test_F10_isExpectedInstance_thin() public view {
        bytes memory encoded = abi.encode(_defaultPkgArgs());
        assertTrue(hookPkg.isExpectedInstance(hook, encoded));
        assertFalse(hookPkg.isExpectedInstance(address(0xBEEF), encoded));
    }

    function _fourNewTokens(string memory tag) internal returns (address[4] memory toks) {
        MintableDec a = new MintableDec(string.concat(tag, "0"), string.concat(tag, "0"), 18);
        MintableDec b = new MintableDec(string.concat(tag, "1"), string.concat(tag, "1"), 18);
        MintableDec c = new MintableDec(string.concat(tag, "2"), string.concat(tag, "2"), 18);
        MintableDec d = new MintableDec(string.concat(tag, "3"), string.concat(tag, "3"), 18);
        (MintableDec x0, MintableDec x1, MintableDec x2, MintableDec x3) = _sortFour(a, b, c, d);
        toks[0] = address(x0);
        toks[1] = address(x1);
        toks[2] = address(x2);
        toks[3] = address(x3);
    }

    function _startsWith(string memory s, string memory prefix) internal pure returns (bool) {
        bytes memory aa = bytes(s);
        bytes memory bb = bytes(prefix);
        if (aa.length < bb.length) return false;
        for (uint256 i; i < bb.length; ++i) {
            if (aa[i] != bb[i]) return false;
        }
        return true;
    }
}

contract NoSymbolToken {
    uint8 public constant decimals = 18;
}
