// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/ISwapRouter.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService as QuadFactory
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol";
import {
    IUniswapV4Detf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Quad_ProdSe
 * @notice Shared production-SE setUp for Quad n=4 fixtures. Does not diamond-inherit
 *         Morpho / pons / Univ4Se TestBases. Dual is not bound.
 */
abstract contract TestBase_UniswapV4Detf_Quad_ProdSe is TestBase_UniswapV4Detf_Quad {
    address internal hookPair0;
    address internal hookPair1;
    address internal hookPair2;
    address internal hookSe0;
    address internal hookSe1;
    address internal hookSe2;
    address internal mintToken;

    IUniswapV3Factory internal univ3Factory;
    IWETH internal weth;
    SeLib.Univ3SePkg internal univ3SePkg;
    SeLib.Univ4SePkg internal univ4SePkg;
    SeLib.PonsV1Stack internal ponsV1;
    SeLib.PonsV2Stack internal ponsV2;
    SeLib.MorphoStack internal morphoStack;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pair0 = new SimpleMintableERC20("Pair0", "P0");
        pairToken = pair0;
        pm = IPoolManager(address(new PoolManager(address(this))));

        _deployProductionSes();

        _deployHookFactory();
        _deployQuadHookPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        detf = _deployQuadHookThenDetf(_nLegDetfArgs(3));
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        mintToken = _readMintToken();
        if (mintToken != address(0)) pairToken = SimpleMintableERC20(mintToken);
        se = hookSe0;
        se0 = hookSe0;
        se1 = hookSe1;
        se2 = hookSe2;

        _fundAndApprove();
    }

    function _deployProductionSes() internal virtual;

    function _craneCtx() internal view returns (SeLib.CraneCtx memory ctx) {
        ctx.create3Factory = create3Factory;
        ctx.indexedexManager = indexedexManager;
        ctx.diamondPackageFactory = diamondPackageFactory;
        ctx.permit2 = permit2;
        ctx.erc20Facet = erc20Facet;
        ctx.erc5267Facet = erc5267Facet;
        ctx.erc2612Facet = erc2612Facet;
        ctx.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        ctx.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        ctx.owner = owner;
    }

    function _ensureUniv3SePkg() internal {
        if (address(univ3Factory) == address(0)) {
            univ3Factory = SeLib.newUniv3Factory();
        }
        if (address(univ3SePkg.pkg) == address(0)) {
            univ3SePkg.factory = univ3Factory;
            univ3SePkg.pkg = SeLib.deployUniv3SePkg(_craneCtx(), univ3Factory);
        }
    }

    function _ensureUniv4SePkg() internal {
        if (address(weth) == address(0)) weth = SeLib.newWeth();
        if (address(univ4SePkg.pkg) == address(0)) {
            univ4SePkg = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        }
    }

    function _ensureWeth() internal {
        if (address(weth) == address(0)) weth = SeLib.newWeth();
    }

    function _deployVanillaUniv3Se(address pair) internal returns (address vault) {
        _ensureUniv3SePkg();
        SimpleMintableERC20 rate = new SimpleMintableERC20("Rate", "RATE");
        IUniswapV3Pool pool = SeLib.createUniv3PoolOneToOne(
            univ3Factory, pair, address(rate), SeLib.GENERIC_V3_FEE
        );
        SeLib.seedUniv3Pool(pool);
        vault = SeLib.deployUniv3Vault(univ3SePkg.pkg, pool);
    }

    function _deployVanillaUniv4Se(address pair) internal returns (address vault) {
        _ensureUniv4SePkg();
        SimpleMintableERC20 rate = new SimpleMintableERC20("Rate", "RATE");
        PoolKey memory key = SeLib.initAndSeedUniv4Pool(pm, pair, address(rate));
        vault = SeLib.deployUniv4Vault(univ4SePkg.pkg, key);
    }

    function _deployPonsV1Univ3Se(address launchToken) internal returns (address vault) {
        _ensureUniv3SePkg();
        vault = SeLib.deployUniv3Vault(univ3SePkg.pkg, SeLib.ponsV1Pool(launchToken));
    }

    function _deployPonsV2Univ4Se(PoolKey memory key) internal returns (address vault) {
        _ensureUniv4SePkg();
        vault = SeLib.deployUniv4Vault(univ4SePkg.pkg, key);
    }

    function tryLaunchPonsV1(bytes32 saltStart) external returns (address token) {
        require(msg.sender == address(this), "only self");
        return SeLib.launchPonsV1(ponsV1, saltStart);
    }

    function _launchPonsV1Salted(bytes32 tag) internal returns (address token) {
        for (uint256 i; i < 64; ++i) {
            bytes32 saltStart = bytes32(uint256(keccak256(abi.encodePacked(tag, i))));
            (bool ok, bytes memory ret) =
                address(this).call(abi.encodeCall(this.tryLaunchPonsV1, (saltStart)));
            if (ok) return abi.decode(ret, (address));
        }
        revert("pons v1 vanity salt not found");
    }

    function _launchPonsV1MinAddr(bytes32 tag, address floorExclusive) internal returns (address token) {
        for (uint256 i; i < 128; ++i) {
            bytes32 saltStart = bytes32(uint256(keccak256(abi.encodePacked(tag, i, floorExclusive))));
            (bool ok, bytes memory ret) =
                address(this).call(abi.encodeCall(this.tryLaunchPonsV1, (saltStart)));
            if (!ok) continue;
            token = abi.decode(ret, (address));
            if (token > floorExclusive) return token;
        }
        revert("pons v1 min-address not found");
    }

    function _launchPonsV1MaxAddr(bytes32 tag, address capExclusive) internal returns (address token) {
        for (uint256 i; i < 128; ++i) {
            bytes32 saltStart = bytes32(uint256(keccak256(abi.encodePacked(tag, i, capExclusive))));
            (bool ok, bytes memory ret) =
                address(this).call(abi.encodeCall(this.tryLaunchPonsV1, (saltStart)));
            if (!ok) continue;
            token = abi.decode(ret, (address));
            if (capExclusive == address(0) || token < capExclusive) return token;
        }
        revert("pons v1 max-address not found");
    }

    function _mintableAbove(address floor, string memory n, string memory sy)
        internal
        returns (SimpleMintableERC20 t)
    {
        for (uint256 i; i < 256; ++i) {
            t = new SimpleMintableERC20(n, sy);
            if (address(t) > floor) return t;
        }
        revert("mintable above not found");
    }

    function _mintableBelow(address cap, string memory n, string memory sy)
        internal
        returns (SimpleMintableERC20 t)
    {
        for (uint256 i; i < 256; ++i) {
            t = new SimpleMintableERC20(n, sy);
            if (cap == address(0) || address(t) < cap) return t;
        }
        revert("mintable below not found");
    }

    function _buyPonsV1(address launchToken, address buyer, uint256 ethIn) internal {
        vm.deal(buyer, buyer.balance + ethIn);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: launchToken,
            fee: SeLib.PONS_V1_POOL_FEE,
            recipient: buyer,
            deadline: block.timestamp + 1 hours,
            amountIn: ethIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        vm.prank(buyer);
        ponsV1.swapRouter.exactInputSingle{value: ethIn}(params);
        require(IERC20(launchToken).balanceOf(buyer) >= 110 ether, "need launch tokens");
    }

    function _approvePair(address pair, address seVault) internal {
        vm.startPrank(detfUser);
        IERC20(pair).approve(detf, type(uint256).max);
        if (seVault != address(0)) {
            IERC20(pair).approve(seVault, type(uint256).max);
            IERC20(seVault).approve(detf, type(uint256).max);
        }
        vm.stopPrank();
    }

    function _fundMintablePair(address pair, address seVault) internal {
        SimpleMintableERC20(pair).mint(detfUser, 10_000_000 ether);
        _approvePair(pair, seVault);
    }

    function _fundAndApprove() internal virtual {
        _fundMintablePair(hookPair0, hookSe0);
        _fundMintablePair(hookPair1, hookSe1);
        _fundMintablePair(hookPair2, hookSe2);
    }

    function _deployQuadHookThenDetf(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address detf_)
    {
        address predicted_ = _predictDetf(args);
        vm.etch(predicted_, address(pair0).code);
        address[4] memory toks;
        toks[0] = predicted_;
        toks[1] = hookPair0;
        toks[2] = hookPair1;
        toks[3] = hookPair2;
        _sort4(toks);
        address[4] memory ses;
        address[4] memory rps;
        for (uint256 i; i < 4; ++i) {
            if (toks[i] == predicted_) ses[i] = address(0);
            else if (toks[i] == hookPair0) ses[i] = hookSe0;
            else if (toks[i] == hookPair1) ses[i] = hookSe1;
            else ses[i] = hookSe2;
        }
        IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                tokens: toks,
                standardExchanges: ses,
                rateProviders: rps,
                baseAmp: QUAD_BASE_AMP,
                ownerOnlyLiquidity: true,
                owner: predicted_
            });
        uint256 mineNonce = QuadFactory.findMineNonce(hookFactory, quadHookPkg, hArgs);
        reserveHook = QuadFactory.deployHook(quadHookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[0], toks[3]);
        init.deployPair(toks[1], toks[2]);
        init.deployPair(toks[1], toks[3]);
        init.deployPair(toks[2], toks[3]);
        require(init.finalizeInitialization(), "finalize");
        vm.etch(predicted_, "");
        args.hook = reserveHook;
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "detf != predicted");
        vm.label(detf_, args.symbol);
        vm.label(reserveHook, "quadReserveHook");
    }

    function _readMintToken() internal view returns (address t) {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf) return toks[i];
        }
        revert("no mintToken");
    }

    function _extPairs() internal view returns (address[] memory pairs) {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        pairs = new address[](3);
        uint256 n;
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf) {
                pairs[n] = toks[i];
                unchecked {
                    ++n;
                }
            }
        }
        require(n == 3, "quad external pairs");
    }

    function _firstBond(uint256 pairAmount_) internal virtual override returns (uint256 tokenId, uint256 shares) {
        vm.startPrank(detfUser);
        (tokenId, shares) = detfInfo.bond(
            IERC20(mintToken), pairAmount_, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _assertSeAllowancesZero() internal view {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            address se_ = IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(toks[i]);
            if (se_ != address(0)) {
                assertEq(IERC20(se_).allowance(reserveHook, se_), 0, "SE allowance(hook, se)==0");
            }
        }
    }

    function _assertR19() internal {
        address hook_ = detfInfo.hook();
        address[] memory toks = IUniswapV4SeBufferHook(hook_).tokens();
        bool needSweep = IERC20(hook_).balanceOf(detf) > 0;
        for (uint256 i; i < toks.length; ++i) {
            if (IERC20(toks[i]).balanceOf(detf) > 0) needSweep = true;
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(toks[i]);
            if (se_ != address(0) && IERC20(se_).balanceOf(detf) > 0) needSweep = true;
        }
        if (needSweep) detfInfo.sweepDust();
        assertEq(IERC20(hook_).balanceOf(detf), 0, "R19 hook LP");
        for (uint256 i; i < toks.length; ++i) {
            uint256 bal = IERC20(toks[i]).balanceOf(detf);
            if (bal > 10) {
                _logR19JoinFailure(hook_, toks[i], bal);
                assertLe(bal, 10, string.concat("R19 token after sweep ", vm.toString(toks[i])));
            }
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(toks[i]);
            if (se_ != address(0)) {
                uint256 seBal = IERC20(se_).balanceOf(detf);
                if (seBal > 10) {
                    emit log_named_address("R19 leftover SE", se_);
                    emit log_named_uint("R19 leftover SE bal", seBal);
                }
                assertLe(seBal, 10, "R19 SE share");
            }
        }
    }

    function _logR19JoinFailure(address hook_, address token_, uint256 bal_) internal {
        emit log_named_address("R19 leftover token", token_);
        emit log_named_uint("R19 leftover bal", bal_);
        try IUniswapV4SeBufferHook(hook_).previewJoinSingleAssetExactIn(token_, bal_) returns (uint256 p) {
            emit log_named_uint("R19 previewJoin", p);
        } catch (bytes memory err) {
            if (err.length >= 4) emit log_named_bytes32("R19 join revert", bytes32(err));
        }
        address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(token_);
        if (se_ != address(0)) {
            try IStandardExchangeIn(se_).previewExchangeIn(IERC20(token_), bal_, IERC20(se_)) returns (uint256 w) {
                emit log_named_uint("R19 sePreview wrap", w);
            } catch (bytes memory err2) {
                if (err2.length >= 4) emit log_named_bytes32("R19 wrap revert", bytes32(err2));
            }
        }
    }

    function _assertNoJoinableDust() internal view virtual override {
        address hook_ = detfInfo.hook();
        assertEq(IERC20(hook_).balanceOf(detf), 0, "no hook LP on diamond");
        address[] memory toks = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] == detf) continue;
            assertLe(IERC20(toks[i]).balanceOf(detf), 10, "no token on diamond");
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(toks[i]);
            if (se_ != address(0)) {
                assertLe(IERC20(se_).balanceOf(detf), 10, "no SE share on diamond");
            }
        }
    }
}
