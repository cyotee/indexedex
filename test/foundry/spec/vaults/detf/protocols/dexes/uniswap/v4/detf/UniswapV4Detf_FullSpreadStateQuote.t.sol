// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";
import {UniswapV4DetfProductionSeDeployLib as SeLib} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";

/// @notice The same deployed DETF/CP-hook contract is exercised with either FullSpread engine.
abstract contract FullSpreadDetfStateQuoteBehavior is TestBase_UniswapV4Detf_Decimals {
    function _useV4() internal pure virtual returns (bool);
    function _pairDecimals() internal pure override returns (uint8) { return 18; }

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);
        if (_useV4()) _deployV4();
        else _deployV3();
        detfDecimalsStub = new MintableERC20Decimals("DETF metadata", "META", 18);
        _deployHookFactoryAndPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        IUniswapV4Detf.PkgArgs memory args_ = _defaultDetfArgs();
        args_.mintThreshold = 2e18;
        detf = _deployHookThenDetf(args_);
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        pairToken.mint(detfUser, 10_000_000 ether);
        vm.prank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        SeLib.bondFirstPositionBasket(detfInfo, address(pairToken), 1000 ether, detfUser, DEFAULT_MIN_LOCK);
        assertFalse(detfInfo.isMintingAllowed(IERC20(address(pairToken))), "exercise reserve-swap fallback");
    }

    function _deployV3() private {
        pairToken = new MintableERC20Decimals("Pair", "PAIR", 18);
        MintableERC20Decimals other_ = new MintableERC20Decimals("Other", "OTHER", 18);
        pm = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)), keccak256("FullSpreadStateQuote.DETF.PoolManager")
        ));
        IUniswapV3Factory factory_ = SeLib.newUniv3Factory();
        SeLib.CraneCtx memory ctx_;
        ctx_.create3Factory = create3Factory;
        ctx_.indexedexManager = indexedexManager;
        ctx_.diamondPackageFactory = diamondPackageFactory;
        ctx_.permit2 = permit2;
        ctx_.erc20Facet = erc20Facet;
        ctx_.erc5267Facet = erc5267Facet;
        ctx_.erc2612Facet = erc2612Facet;
        ctx_.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        ctx_.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        ctx_.owner = owner;
        IUniswapV3Pool pool_ = SeLib.createUniv3PoolOneToOne(
            factory_, address(pairToken), address(other_), SeLib.GENERIC_V3_FEE
        );
        SeLib.seedUniv3Pool(pool_);
        se = SeLib.deployUniv3Vault(SeLib.deployUniv3SePkg(ctx_, factory_), pool_);
    }

    function _deployV4() private {
        SeMatrixFixture.Ctx memory ctx_;
        ctx_.create3Factory = create3Factory;
        ctx_.indexedexManager = indexedexManager;
        ctx_.owner = owner;
        ctx_.permit2 = permit2;
        ctx_.erc20Facet = erc20Facet;
        ctx_.erc2612Facet = erc2612Facet;
        ctx_.erc5267Facet = erc5267Facet;
        ctx_.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        ctx_.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        SeMatrix_FullSpreadV4Fixture fixture_ = new SeMatrix_FullSpreadV4Fixture(ctx_, address(0));
        pm = fixture_.poolManager();
        pairToken = MintableERC20Decimals(fixture_.faceToken());
        se = fixture_.se();
    }

    function _paymentShares() private returns (uint256 shares_) {
        shares_ = SeLib.acquirePositionShares(se, address(pairToken), 10 ether, detfUser);
        vm.prank(detfUser);
        IERC20(se).approve(detf, shares_);
        assertFalse(detfInfo.isMintingAllowed(IERC20(se)), "share payment uses the closed mint gate");
    }

    function test_sharePaymentQuoteMatchesRealIntermediateStateAndPayout() public {
        uint256 shares_ = _paymentShares();
        (uint256 expected_, uint256 refund_) =
            detfExchangeIn.previewExchangeIn(IERC20(se), shares_, IERC20(detf));
        assertGt(expected_, 0);
        assertEq(refund_, 0);
        // Independent composition oracle: actually redeem, then ask the ordinary hook preview.
        uint256 snapshot_ = vm.snapshotState();
        vm.prank(detfUser);
        (uint256 pairOut_,) = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), shares_, IERC20(address(pairToken)), 0, detfUser, false, block.timestamp
        );
        (uint256 atIntermediateState_,) = IStandardExchangeIn(reserveHook).previewExchangeIn(
            IERC20(address(pairToken)), pairOut_, IERC20(detf)
        );
        assertEq(expected_, atIntermediateState_, "quote prices the actual post-redemption book");
        assertTrue(vm.revertToState(snapshot_));

        uint256 balance_ = IERC20(detf).balanceOf(detfUser);
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 seBefore_ = IERC20(se).balanceOf(detfUser);
        vm.prank(detfUser);
        (uint256 paid_, uint256 returned_) = detfExchangeIn.exchangeIn(
            IERC20(se), shares_, IERC20(detf), expected_, detfUser, false, block.timestamp
        );
        assertEq(paid_, expected_);
        assertEq(returned_, 0);
        assertEq(IERC20(detf).balanceOf(detfUser) - balance_, expected_);
        assertEq(seBefore_ - IERC20(se).balanceOf(detfUser), shares_);
        assertEq(IERC20(detf).totalSupply(), supply_, "fallback buys existing DETF");
    }

    function test_quotePlusOneRejectsAndRollsBackThePrecedingRedemption() public {
        uint256 shares_ = _paymentShares();
        (uint256 expected_,) = detfExchangeIn.previewExchangeIn(IERC20(se), shares_, IERC20(detf));
        assertGt(expected_, 0);
        bytes memory seState_ = IStandardExchangeStateQuote(se).quoteExchangeState();
        uint256 userShares_ = IERC20(se).balanceOf(detfUser);
        uint256 hookShares_ = IERC20(se).balanceOf(reserveHook);
        uint256 hookPair_ = pairToken.balanceOf(reserveHook);
        uint256 hookDetf_ = IERC20(detf).balanceOf(reserveHook);
        vm.prank(detfUser);
        vm.expectRevert(bytes4(keccak256("InsufficientTokenOut()")));
        detfExchangeIn.exchangeIn(
            IERC20(se), shares_, IERC20(detf), expected_ + 1, detfUser, false, block.timestamp
        );
        assertEq(IStandardExchangeStateQuote(se).quoteExchangeState(), seState_);
        assertEq(IERC20(se).balanceOf(detfUser), userShares_);
        assertEq(IERC20(se).balanceOf(reserveHook), hookShares_);
        assertEq(pairToken.balanceOf(reserveHook), hookPair_);
        assertEq(IERC20(detf).balanceOf(reserveHook), hookDetf_);
    }

    function test_directPairPaymentRetainsOrdinarySwapPricing() public {
        (uint256 expected_,) =
            detfExchangeIn.previewExchangeIn(IERC20(address(pairToken)), 1 ether, IERC20(detf));
        assertGt(expected_, 0);
        uint256 supply_ = IERC20(detf).totalSupply();
        vm.prank(detfUser);
        (uint256 paid_,) = detfExchangeIn.exchangeIn(
            IERC20(address(pairToken)), 1 ether, IERC20(detf), expected_, detfUser, false, block.timestamp
        );
        assertEq(paid_, expected_);
        assertEq(IERC20(detf).totalSupply(), supply_);
    }
}

contract UniswapV3FullSpreadDetfStateQuoteTest is FullSpreadDetfStateQuoteBehavior {
    function _useV4() internal pure override returns (bool) { return false; }
}

contract UniswapV4FullSpreadDetfStateQuoteTest is FullSpreadDetfStateQuoteBehavior {
    function _useV4() internal pure override returns (bool) { return true; }
}
