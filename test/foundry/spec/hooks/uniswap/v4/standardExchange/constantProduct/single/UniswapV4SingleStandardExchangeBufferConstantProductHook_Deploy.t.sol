// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {
    UniswapV4HookDiamondCreate2Lib as Create2Lib
} from "contracts/hooks/uniswap/v4/factory/libs/UniswapV4HookDiamondCreate2Lib.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4HookFlags
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookFlags.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy_Test
 * @notice Phase 0 + A: ERC-4626 SE preview==exec; Option B deploy/flags/registry.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy_Test is TestBase {
    function test_phase0_sePairPreviewEqualsExec() public {
        _assertSePreviewEqualsExec(100 ether);
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
        assertEq(single.poolManager(), address(pm));
        assertEq(single.feeOracle(), address(indexedexManager));
        assertEq(single.standardExchange(), se);
        assertEq(single.pairToken(), address(pairToken));
        assertEq(single.rawToken(), address(rawToken));

        address c0 = single.currency0();
        address c1 = single.currency1();
        assertTrue(c0 < c1, "currency0 must be lower address");
        assertTrue(
            (c0 == address(rawToken) && c1 == address(pairToken))
                || (c0 == address(pairToken) && c1 == address(rawToken)),
            "currencies are raw/pair"
        );
    }

    function test_deploy_registeredAsVault() public view {
        assertTrue(
            IVaultRegistryVaultQuery(address(indexedexManager)).isVault(hook), "isVault"
        );
    }

    function test_deploy_initPoolAndProportionalDepositSmoke() public {
        _initPool();
        uint256 lp = _depositBoth(100 ether, 100 ether);
        assertGt(lp, 0, "lp minted");
        assertTrue(single.isLive(), "live after deposit");
        assertGt(single.rawReserve(), 0, "raw reserve");
        assertGt(single.seClaimSupply(), 0, "virtual pair reserve");
        // Free pair is not the book
        assertLe(pairToken.balanceOf(hook), DUST, "free pair dust only");
    }

    function test_D3_idempotentRedeploySameBinding() public {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            _defaultPkgArgs();
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address again = PkgFactory.deployHook(hookPkg, args, mineNonce);
        assertEq(again, hook);
    }

    function test_D4_lpSymbolPrefixSSEBCP() public view {
        assertEq(IERC20Metadata(hook).name(), "SE Buffer CP Hook LP");
        assertEq(IERC20Metadata(hook).symbol(), "SSEBCP-LP");
    }

    function test_initAccount_emptyRawToken_usesPkgArgsDecimals() public {
        address emptyRaw = address(uint160(uint256(keccak256("empty-detf"))));
        assertEq(emptyRaw.code.length, 0, "empty self-leg");
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            _defaultPkgArgs();
        args.rawToken = emptyRaw;
        args.rawTokenDecimals = 18;
        args.pairTokenDecimals = IERC20Metadata(address(pairToken)).decimals();
        args.owner = emptyRaw;
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address h = PkgFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(h, emptyRaw, address(pairToken));
        assertTrue(h.code.length > 0, "hook deployed");
        assertEq(IERC20Metadata(h).name(), "SE Buffer CP Hook LP");
        assertEq(IERC20Metadata(h).symbol(), "SSEBCP-LP");
        (uint8 d0, uint8 d1) = _storedCpDecimals(h);
        address c0 = emptyRaw < address(pairToken) ? emptyRaw : address(pairToken);
        if (c0 == emptyRaw) {
            assertEq(d0, 18, "raw decimals");
            assertEq(d1, args.pairTokenDecimals, "pair decimals");
        } else {
            assertEq(d0, args.pairTokenDecimals, "pair decimals");
            assertEq(d1, 18, "raw decimals");
        }
    }

    function test_processArgs_rawTokenDecimalsNot18_reverts() public {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            _defaultPkgArgs();
        args.rawTokenDecimals = 17;
        vm.expectRevert(
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.InvalidDecimals.selector
        );
        hookPkg.processArgs(abi.encode(args));
    }

    function test_processArgs_pairTokenDecimalsOutOfRange_reverts() public {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            _defaultPkgArgs();
        args.pairTokenDecimals = 0;
        vm.expectRevert(
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.InvalidDecimals.selector
        );
        hookPkg.processArgs(abi.encode(args));
        args = _defaultPkgArgs();
        args.pairTokenDecimals = 19;
        vm.expectRevert(
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.InvalidDecimals.selector
        );
        hookPkg.processArgs(abi.encode(args));
    }

    function test_calcSalt_differsWhenPairDecimalsDiffer() public {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            _defaultPkgArgs();
        args.pairTokenDecimals = 6;
        bytes32 salt6 = hookPkg.calcSalt(abi.encode(args));
        args.pairTokenDecimals = 18;
        bytes32 salt18 = hookPkg.calcSalt(abi.encode(args));
        assertTrue(salt6 != salt18, "salt includes pairTokenDecimals");
    }

    function _storedCpDecimals(address hook_) internal view returns (uint8 d0, uint8 d1) {
        bytes32 slot = keccak256(
            abi.encode(uint256(keccak256("indexedex.hooks.uv4.single.se.buffer.constant.product.storage")) - 1)
        ) & ~bytes32(uint256(0xff));
        // currency1 (address) packs with decimalsCurrency0/1 + bindingsInitialized.
        uint256 packed = uint256(vm.load(hook_, bytes32(uint256(slot) + 6)));
        d0 = uint8(packed >> 160);
        d1 = uint8(packed >> 168);
    }

    /// @notice LP = hook diamond: ERC20PermitDFPkg facets (ERC20 + 5267 + 2612) are live.
    function test_D5_lpHasErc20PermitSurfaces() public view {
        assertTrue(IERC20Permit(hook).DOMAIN_SEPARATOR() != bytes32(0), "DOMAIN_SEPARATOR");
        assertEq(IERC20Permit(hook).nonces(user), 0, "nonces start at 0");
        (
            bytes1 fields,
            string memory name_,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            ,
        ) = IERC5267(hook).eip712Domain();
        assertTrue(fields != 0, "eip712Domain fields");
        assertGt(bytes(name_).length, 0, "eip712 name");
        assertEq(version, "1", "eip712 version");
        assertEq(chainId, block.chainid, "eip712 chainId");
        assertEq(verifyingContract, hook, "eip712 verifyingContract is hook");
    }

    /* ------------------------------- D60 rated reserve ------------------------------- */

    /// @notice D60: a buffered pair leg (pairToken != SE) must carry a rate provider.
    function test_D60_processArgs_bufferedLegWithoutRateProvider_reverts() public {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            _defaultPkgArgs();
        args.rateProvider = address(0);
        vm.expectRevert(
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.RateProviderRequired.selector
        );
        hookPkg.processArgs(abi.encode(args));
    }

    /// @notice D60: getters expose the configured provider in pool order and by token.
    function test_D60_rateProviderGetters() public {
        address rp = _defaultPkgArgs().rateProvider; // idempotent CREATE3 fixture: same provider address
        assertTrue(rp != address(0), "fixture provider");
        assertEq(single.rateProvider(address(pairToken)), rp, "by pair token");
        assertEq(single.rateProvider(se), rp, "by SE");
        assertEq(single.rateProvider(address(rawToken)), address(0), "raw leg has none");
        address[] memory rps = single.rateProviders();
        assertEq(rps.length, 2, "pool order length");
        assertEq(rps[single.currency0() == address(pairToken) ? 0 : 1], rp, "pool-order slot");
        assertEq(rps[single.currency0() == address(pairToken) ? 1 : 0], address(0), "raw slot");
    }

    /// @notice D60: the swap reserve of the pair leg is SE shares held x provider rate, never an SE self-quote.
    function test_D60_swapReserveIsSharesTimesRate() public {
        _seedLiveLiquidity();
        _accrueYield(37 ether);
        uint256 shares = IERC20(se).balanceOf(hook);
        uint256 rate = IRateProvider(single.rateProvider(se)).getRate();
        assertGt(rate, 1e18, "yield raised the rate");
        assertEq(single.seClaimSupply(), shares * rate / 1e18, "reserve = shares x rate");
        // The BasicVault reserve is the snapshot written at the last operation; it catches up on the next sync.
        _depositBoth(1 ether, 1 ether);
        assertEq(single.seClaimSupply(), IBasicVault(hook).reserveOfToken(address(pairToken)), "vault reserve view after sync");
    }

    /// @notice D60 liquidity invariant: LP minted for the pair leg follows the raw SE share ratio,
    ///         independent of the provider rate (linear rating), so joins are proportional in raw balances.
    function test_D60_proportionalJoinFollowsShareRatioAfterRateChange() public {
        _seedLiveLiquidity();
        _accrueYield(50 ether);
        uint256 sharesBefore = IERC20(se).balanceOf(hook);
        uint256 pairIn = 10 ether;
        uint256 sharesIn = IStandardExchangeIn(se).previewExchangeIn(IERC20(address(pairToken)), pairIn, IERC20(se));
        // Over-offer raw so the pair leg binds the clamp.
        uint256 lp = _depositBoth(1_000 ether, pairIn);
        // The join accrues the protocol-fee LP for the rate growth first; measure against the supply it joined.
        uint256 supplyJoined = IERC20(hook).totalSupply() - lp;
        uint256 expected = sharesIn * supplyJoined / sharesBefore;
        assertApproxEqRel(lp, expected, 0.0001e18, "LP follows dShares / shares");
        assertEq(IERC20(se).balanceOf(hook), sharesBefore + sharesIn, "shares buffered");
    }

    function _accrueYield(uint256 assets) private {
        pairToken.mint(address(this), assets);
        pairToken.approve(address(pairProtocolVault), assets);
        pairProtocolVault.simulateYield(assets);
    }
}
