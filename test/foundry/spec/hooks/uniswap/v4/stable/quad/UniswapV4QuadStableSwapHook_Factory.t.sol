// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {HookMinerCreate3} from
    "@crane/contracts/protocols/dexes/uniswap/v4/hooks/public/utils/HookMinerCreate3.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolId, PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {
    TestBase_UniswapV4QuadStableSwapHook,
    MintableDec
} from "contracts/hooks/uniswap/v4/stable/quad/TestBase_UniswapV4QuadStableSwapHook.sol";
import {
    UniswapV4QuadStableSwapHook_FactoryService as FactoryService
} from "contracts/hooks/uniswap/v4/stable/quad/UniswapV4QuadStableSwapHook_FactoryService.sol";
import {
    IUniswapV4QuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/interfaces/IUniswapV4QuadStableSwapHook.sol";

/**
 * @title UniswapV4QuadStableSwapHook_Factory_Test
 * @notice Path A/B deploy, six doors, metadata, non-operator EOA, ensurePairPools.
 */
contract UniswapV4QuadStableSwapHook_Factory_Test is TestBase_UniswapV4QuadStableSwapHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    function test_F1_pathA_sixPools() public view {
        assertTrue(hook.code.length > 0);
        PoolKey[6] memory keys = _poolKeys();
        for (uint256 i; i < 6; ++i) {
            (uint160 sqrtPrice,,,) = pm.getSlot0(keys[i].toId());
            assertGt(sqrtPrice, 0, "pool live");
        }
        assertTrue(factory.isDeployedByFactory(hook));
    }

    /// @notice F2: Path B deployWithMineNonce — valid nonce deploys; bad nonce reverts InvalidMineNonce.
    function test_F2_pathB_deployWithMineNonce() public {
        address[4] memory toks = _fourNewTokens("PB");
        address[4] memory providers;
        string memory ns = "path-b-ns";

        (uint256 goodNonce, uint256 badNonce) =
            _findMineNonces(toks, DEMO_FEE, DEMO_AMP, providers, ns);

        (address h, PoolKey[6] memory keys) = _pathBDeploy(toks, providers, ns, goodNonce);
        assertTrue(h.code.length > 0);
        assertTrue(factory.isDeployedByFactory(h));
        for (uint256 i; i < 6; ++i) {
            (uint160 sqrtPrice,,,) = pm.getSlot0(keys[i].toId());
            assertGt(sqrtPrice, 0, "path B pool live");
        }
        assertEq(uint160(h) & HookMinerCreate3.FLAG_MASK, FactoryService.requiredFlags());

        address[4] memory toks2 = _fourNewTokens("PBb");
        vm.expectRevert(FactoryService.InvalidMineNonce.selector);
        _pathBDeploy(toks2, providers, "path-b-bad", badNonce);
    }

    function _pathBDeploy(
        address[4] memory toks,
        address[4] memory providers,
        string memory ns,
        uint256 mineNonce
    ) internal returns (address h, PoolKey[6] memory keys) {
        return factory.deployWithMineNonce(
            toks[0], toks[1], toks[2], toks[3], DEMO_FEE, DEMO_AMP, providers, ns, mineNonce
        );
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

    function test_F3_nonOperatorEoa_canDeploy() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        MintableDec c = new MintableDec("C", "C", 18);
        MintableDec d = new MintableDec("D", "D", 18);
        (MintableDec x0, MintableDec x1, MintableDec x2, MintableDec x3) = _sortFour(a, b, c, d);
        address[4] memory providers;
        vm.prank(deployerEoa);
        (address h,) = factory.deploy(
            address(x0), address(x1), address(x2), address(x3), DEMO_FEE, DEMO_AMP, providers, "eoa-ns-"
        );
        assertTrue(h.code.length > 0);
        assertTrue(factory.isDeployedByFactory(h));
    }

    function test_F4_unsorted_reverts() public {
        address[4] memory providers;
        vm.expectRevert();
        factory.deploy(
            address(t3), address(t2), address(t1), address(t0), DEMO_FEE, DEMO_AMP, providers, "bad-order"
        );
    }

    function test_F5_zeroFee_reverts() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        MintableDec c = new MintableDec("C", "C", 18);
        MintableDec d = new MintableDec("D", "D", 18);
        (MintableDec x0, MintableDec x1, MintableDec x2, MintableDec x3) = _sortFour(a, b, c, d);
        address[4] memory providers;
        vm.expectRevert();
        factory.deploy(address(x0), address(x1), address(x2), address(x3), 0, DEMO_AMP, providers, "zf");
    }

    function test_F5_zeroAmp_reverts() public {
        MintableDec a = new MintableDec("A", "A", 18);
        MintableDec b = new MintableDec("B", "B", 18);
        MintableDec c = new MintableDec("C", "C", 18);
        MintableDec d = new MintableDec("D", "D", 18);
        (MintableDec x0, MintableDec x1, MintableDec x2, MintableDec x3) = _sortFour(a, b, c, d);
        address[4] memory providers;
        vm.expectRevert();
        factory.deploy(address(x0), address(x1), address(x2), address(x3), DEMO_FEE, 0, providers, "za");
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
        (address h,) = factory.deploy(
            addrs[0], addrs[1], addrs[2], addrs[3], DEMO_FEE, DEMO_AMP, providers, "nosym"
        );
        (, bytes memory ret) = h.staticcall(abi.encodeWithSignature("symbol()"));
        string memory s = abi.decode(ret, (string));
        assertTrue(bytes(s).length > 0 && bytes(s).length <= 32);
        (, bytes memory retN) = h.staticcall(abi.encodeWithSignature("name()"));
        string memory n = abi.decode(retN, (string));
        assertTrue(_startsWith(n, "Quad Stable "));
        assertTrue(bytes(n).length <= 64);
    }

    function test_F6_idempotent_redeploy() public {
        address[4] memory providers;
        (address h2,) = factory.deploy(
            address(t0), address(t1), address(t2), address(t3), DEMO_FEE, DEMO_AMP, providers, ""
        );
        assertEq(h2, hook);
    }

    function test_F7_ensurePairPools_foreign_reverts() public {
        vm.expectRevert();
        factory.ensurePairPools(address(0xDEAD));
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
        assertEq(HookMinerCreate3.MAX_LOOP, 160_444);
    }

    function _findMineNonces(
        address[4] memory toks,
        uint24 fee,
        uint256 amp,
        address[4] memory providers,
        string memory ns
    ) internal view returns (uint256 good, uint256 bad) {
        uint160 flags = FactoryService.requiredFlags();
        bytes32 rateFp = FactoryService.rateProviderFingerprint(providers);
        bool foundGood;
        bool foundBad;
        for (uint256 n; n < 50_000; ++n) {
            bool match_ = _flagsMatch(toks, fee, amp, rateFp, ns, n, flags);
            if (match_ && !foundGood) {
                good = n;
                foundGood = true;
            }
            if (!match_ && !foundBad) {
                bad = n;
                foundBad = true;
            }
            if (foundGood && foundBad) return (good, bad);
        }
        revert("mine nonces not found in 50k");
    }

    function _flagsMatch(
        address[4] memory toks,
        uint24 fee,
        uint256 amp,
        bytes32 rateFp,
        string memory ns,
        uint256 n,
        uint160 flags
    ) internal view returns (bool) {
        bytes32 salt =
            FactoryService.hookSalt(ns, address(pm), toks[0], toks[1], toks[2], toks[3], fee, amp, rateFp, n);
        address predicted = HookMinerCreate3.computeAddress(address(create3Factory), uint256(salt));
        return uint160(predicted) & HookMinerCreate3.FLAG_MASK == flags;
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
