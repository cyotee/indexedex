// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {DETF_PROTOCOL_BOND_NFT_ID} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {
    TestBase_UniswapV4Detf_Adversarial,
    UniV4DetfPretransferHelper
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol";
import {UniswapV4Detf_ClaimBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ClaimBase.sol";
import {UniswapV4Detf_Alignment_CloseD25Base} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25Base.sol";
import {UniswapV4Detf_IoTablesOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_IoTablesOpenBase.sol";
import {UniswapV4Detf_OwnerOnlyLiquidityOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OwnerOnlyLiquidityOpenBase.sol";
import {UniswapV4Detf_ReserveDonationOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationOpenBase.sol";
import {UniswapV4Detf_Alignment_CloseD25OpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25OpenBase.sol";
import {UniswapV4Detf_Alignment_RedeemD15OpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_RedeemD15OpenBase.sol";
import {UniswapV4Detf_ClaimOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ClaimOpenBase.sol";
import {UniswapV4Detf_AdversarialOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_AdversarialOpenBase.sol";

/// @notice Stage 11 Open layer IDs plus diamond-helper overrides (R-24). Fixture supplies setUp/_firstBond.
abstract contract UniswapV4Detf_Stage11OpenSuite is
    UniswapV4Detf_IoTablesOpenBase,
    UniswapV4Detf_OwnerOnlyLiquidityOpenBase,
    UniswapV4Detf_ReserveDonationOpenBase,
    UniswapV4Detf_Alignment_CloseD25OpenBase,
    UniswapV4Detf_Alignment_RedeemD15OpenBase,
    UniswapV4Detf_ClaimOpenBase,
    UniswapV4Detf_AdversarialOpenBase
{
    function setUp()
        public
        virtual
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Adversarial)
    {
        TestBase_UniswapV4Detf.setUp();
        _bindStage11OpenActors();
    }

    function _bindStage11OpenActors() internal {
        policyCreator = makeAddr("creator");
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        aliceAdv = makeAddr("aliceAdv");
        preHelper = new UniV4DetfPretransferHelper();
        _rebindPairTokenToHook();
    }

    function _rebindPairTokenToHook() internal {
        if (address(detfInfo) == address(0)) return;
        address hook_ = detfInfo.hook();
        if (hook_ == address(0)) return;
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        address firstPair_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == detf) continue;
            if (firstPair_ == address(0)) firstPair_ = toks_[i];
            if (toks_[i] == address(pairToken)) return;
        }
        if (firstPair_ != address(0)) pairToken = SimpleMintableERC20(firstPair_);
    }

    function _nft()
        internal
        view
        virtual
        override(UniswapV4Detf_ClaimBase, UniswapV4Detf_Alignment_CloseD25Base, UniswapV4Detf_ReserveDonationOpenBase)
        returns (IDETFNFTVault)
    {
        return IDETFNFTVault(detfInfo.bondNftVault());
    }

    function _deadline()
        internal
        view
        virtual
        override(
            TestBase_UniswapV4Detf_Adversarial,
            TestBase_UniswapV4Detf_Policy,
            UniswapV4Detf_Alignment_CloseD25Base,
            UniswapV4Detf_ReserveDonationOpenBase
        )
        returns (uint256)
    {
        return block.timestamp + 1 hours;
    }

    function _minOut()
        internal
        view
        virtual
        override(UniswapV4Detf_Alignment_CloseD25Base, UniswapV4Detf_ReserveDonationOpenBase)
        returns (uint256[] memory m)
    {
        m = new uint256[](IUniswapV4SeBufferHook(detfInfo.hook()).tokens().length);
    }

    function _openPairToken()
        internal
        view
        virtual
        override
        returns (IERC20)
    {
        if (address(detfInfo) == address(0)) return IERC20(address(pairToken));
        address hook_ = detfInfo.hook();
        if (hook_ == address(0)) return IERC20(address(pairToken));
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        address pt_ = address(pairToken);
        address firstPair_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == detf) continue;
            if (firstPair_ == address(0)) firstPair_ = toks_[i];
            if (toks_[i] == pt_) return IERC20(pt_);
        }
        if (firstPair_ != address(0)) return IERC20(firstPair_);
        return IERC20(pt_);
    }

    function _uniqueDetfArgs(string memory tag_)
        internal
        view
        virtual
        override(TestBase_UniswapV4Detf_Adversarial, UniswapV4Detf_ReserveDonationOpenBase)
        returns (IUniswapV4Detf.PkgArgs memory args)
    {
        uint256 pairCount_ = 1;
        if (address(detfInfo) != address(0)) {
            address hook_ = detfInfo.hook();
            if (hook_ != address(0)) {
                uint256 n_ = IUniswapV4SeBufferHook(hook_).tokens().length;
                if (n_ > 1) pairCount_ = n_ - 1;
            }
        }
        args = _nLegDetfArgs(pairCount_);
        args.name = string.concat("UniV4 DETF ", tag_);
        args.symbol = string.concat("uv4", tag_);
    }

    function _fundPair(address to_, uint256 amount_)
        internal
        virtual
        override(TestBase_UniswapV4Detf_Adversarial, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Policy._fundPair(to_, amount_);
    }

    function _fundHookToken(address token_, address to_, uint256 amount_) internal {
        _fundToken(token_, to_, amount_);
    }

    function _fundOpenPair(address to_, uint256 amount_) internal virtual override {
        _fundToken(address(_openPairToken()), to_, amount_);
    }

    function _bondAs(address bonder_, uint256 pairAmount_)
        internal
        virtual
        override(UniswapV4Detf_Alignment_CloseD25Base, UniswapV4Detf_ReserveDonationOpenBase)
        returns (uint256 tokenId_, uint256 shares_)
    {
        address[] memory toks_ = IUniswapV4SeBufferHook(detfInfo.hook()).tokens();
        IERC20 bondTok_ = _openPairToken();
        bool bondOk_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == detf) continue;
            _fundHookToken(toks_[i], bonder_, pairAmount_ * 4);
            vm.prank(bonder_);
            IERC20(toks_[i]).approve(detf, type(uint256).max);
            if (toks_[i] == address(bondTok_)) bondOk_ = true;
        }
        if (!bondOk_) {
            for (uint256 j; j < toks_.length; ++j) {
                if (toks_[j] == detf) continue;
                bondTok_ = IERC20(toks_[j]);
                break;
            }
        }
        vm.startPrank(bonder_);
        (tokenId_, shares_) = detfInfo.bond(
            bondTok_, pairAmount_, DEFAULT_MIN_LOCK, bonder_, false, _deadline()
        );
        vm.stopPrank();
    }

    function test_DN5_inert_reverts() public virtual override {
        _ensureDonor();
        address inert_ = _deployInstance(_uniqueDetfArgs("dn5"));
        IDETFNFTVault nft_ = IDETFNFTVault(IUniswapV4Detf(inert_).bondNftVault());
        IERC20 tok_ = _openPairToken();
        _fundOpenPair(dnDonor, 1 ether);
        vm.startPrank(dnDonor);
        tok_.approve(address(nft_), 1 ether);
        vm.expectRevert(abi.encodeWithSignature("ReserveNotLive()"));
        IDetfNftReserveDonation(address(nft_)).donate(tok_, 1 ether, 0, false, _deadline());
        vm.stopPrank();
        assertEq(IDetfNftReserveDonation(address(nft_)).previewDonate(tok_, 1 ether), 0, "DN5 preview inert");
    }

    function test_reserveHook_thirdPartyAddReverts() public virtual override {
        IERC20 tok_ = _openPairToken();
        vm.prank(detfUser);
        vm.expectRevert();
        IUniswapV4SeBufferHook(reserveHook).joinSingleAssetExactIn(
            address(tok_), 1 ether, detfUser, 0, _deadline()
        );
    }

    /// @dev After last user close, Univ3/n-leg pair wrap can be thinner than 20 ether.
    ///      Donate DETF self-leg (mint leftover) so the LP booking still runs.
    function test_DN16_lastClose_thenDonate_nextBondDoesNotCapture() public override {
        _ensureLiveBond();
        address bob = makeAddr("dn16bob");
        address carol = makeAddr("dn16carol");
        (uint256 bobId,) = _bondAs(bob, 40 ether);

        vm.startPrank(detfUser);
        detfInfo.mint(_openPairToken(), 20 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();

        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(detfUser);
        detfInfo.closeBondMature(dnUserBondId, _minOut(), detfUser, _deadline());
        vm.prank(bob);
        detfInfo.closeBondMature(bobId, _minOut(), bob, _deadline());

        IDETFNFTVault nft_ = _nft();
        uint256 donateAmt_ = IERC20(detf).balanceOf(detfUser) / 4;
        if (donateAmt_ == 0) donateAmt_ = IERC20(detf).balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(nft_), donateAmt_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(
            IERC20(detf), donateAmt_, 0, false, _deadline()
        );
        vm.stopPrank();
        assertGt(lpOut_, 0, "DN16 donated LP");
        uint256 id0AfterDonate_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 lpAfterDonate_ = _lpToken().balanceOf(address(nft_));
        assertGt(lpAfterDonate_, 0, "DN16 donated LP");

        (uint256 carolId,) = _bondAs(carol, 30 ether);
        assertGe(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0AfterDonate_, "DN16 next bond leaves id0");
        uint256 carolOrig_ = nft_.originalSharesOf(carolId);
        uint256 carolAssets_ = nft_.convertToAssets(carolOrig_);
        uint256 totalLp_ = _lpToken().balanceOf(address(nft_));
        assertLt(carolAssets_, totalLp_, "DN16 carol does not swallow donated LP");
        _assertNoJoinableDust();
    }

    function test_compound_raises_protocolLp() public {
        address d = _deployOpenLive();
        _assert_compound_raises_protocolLp(d);
    }

    function test_open_never_expands() public {
        address d = _deployOpenLive();
        _assert_open_never_expands(d);
    }
}
