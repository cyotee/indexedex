// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from
    "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF,
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol";

/// @dev Holds an open PoolManager unlock and calls NFT donate from unlockCallback (DN22).
contract CpDonateDuringUnlockHarness is IUnlockCallback {
    IPoolManager public immutable pm;

    constructor(IPoolManager pm_) {
        pm = pm_;
    }

    function run(address target, bytes calldata data) external returns (bytes memory) {
        return pm.unlock(abi.encode(target, data));
    }

    function unlockCallback(bytes calldata raw) external returns (bytes memory) {
        require(msg.sender == address(pm), "not pm");
        (address target, bytes memory data) = abi.decode(raw, (address, bytes));
        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        return ret;
    }
}

/// @notice D29 / donation PRD v0.3 DN1–DN22 on the production Uni V4 CP DETF proxy.
contract UniswapV4SingleStandardExchangeDETF_ReserveDonation is
    TestBase_UniswapV4SingleStandardExchangeDETF
{
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    address internal donor;
    uint256 internal donorPk;
    uint256 internal userBondId;
    uint256 internal userOriginal;

    function setUp() public override {
        super.setUp();
        donorPk = 0xA11CE;
        donor = vm.addr(donorPk);
        (userBondId,) = _firstBond(400 ether);
        userOriginal = _nft().originalSharesOf(userBondId);
        pairToken.mint(donor, 10_000 ether);
        vm.prank(donor);
        pairToken.approve(address(_nft()), type(uint256).max);
        vm.prank(donor);
        pairToken.approve(detf, type(uint256).max);
    }

    function _nft() internal view returns (IDETFNFTVault) {
        return _bondNftVault(detf);
    }

    function _nftDonate() internal view returns (IDetfNftReserveDonation) {
        return IDetfNftReserveDonation(address(_nft()));
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _donatePair(address from_, uint256 amount_) internal returns (uint256 lpOut_) {
        IDETFNFTVault nft_ = _nft();
        vm.startPrank(from_);
        pairToken.approve(address(nft_), amount_);
        lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(
            IERC20(address(pairToken)), amount_, 0, false, _deadline()
        );
        vm.stopPrank();
    }

    function _vaultShare() internal view returns (IERC20) {
        address share_ = detfInfo.standardExchangeVaultShare();
        return IERC20(share_ == address(0) ? se : share_);
    }

    function _minOut() internal pure returns (uint256[] memory m) {
        m = new uint256[](2);
    }

    function test_N1_donate_pairToken_credits_id0() public {
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 lpBefore_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 userDetfBefore_ = IERC20(detf).balanceOf(detfUser);
        uint256 userAssetsBefore_ = nft_.convertToAssets(userOriginal);

        uint256 lpOut_ = _donatePair(donor, 10 ether);
        assertGt(lpOut_, 0, "N1 lpOut");
        assertGt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), lpBefore_, "N1 nftLp");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N1 id0");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "N1 no DETF mint");
        assertEq(IERC20(detf).balanceOf(detfUser), userDetfBefore_, "N1 user DETF");
        assertEq(nft_.originalSharesOf(userBondId), userOriginal, "N1 user original");
        assertEq(nft_.convertToAssets(userOriginal), userAssetsBefore_, "N1 NAV");
    }

    function test_N2_donate_vaultShare_credits_id0() public {
        IERC20 share_ = _vaultShare();
        uint256 pairIn_ = 20 ether;
        pairToken.mint(donor, pairIn_);
        vm.startPrank(donor);
        pairToken.approve(se, pairIn_);
        uint256 shares_ = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)), pairIn_, share_, 0, donor, false, _deadline()
        );
        vm.stopPrank();
        assertGt(shares_, 0, "N2 se shares");

        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        vm.startPrank(donor);
        share_.approve(address(nft_), shares_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(share_, shares_, 0, false, _deadline());
        vm.stopPrank();
        assertGt(lpOut_, 0, "N2 lpOut");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N2 id0");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "N2 no mint");
    }

    function test_N3_donate_lpToken_thisCallInboundOnly() public {
        IDETFNFTVault nft_ = _nft();
        IERC20 lp_ = nft_.lpToken();
        uint256 booked_ = lp_.balanceOf(address(nft_));
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);

        address hook_ = detfInfo.reserveHook();
        pairToken.mint(detf, 40 ether);
        vm.startPrank(detf);
        pairToken.approve(hook_, 40 ether);
        uint256 mintedLp_ = IHook(hook_).depositSingle(address(pairToken), 40 ether, donor, 0, _deadline());
        vm.stopPrank();
        assertGt(mintedLp_, 0, "N3 donor LP");
        assertEq(lp_.balanceOf(address(nft_)), booked_, "N3 booked LP unchanged by extra mint to donor");

        vm.startPrank(donor);
        lp_.approve(address(nft_), mintedLp_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(lp_, mintedLp_, 0, false, _deadline());
        vm.stopPrank();
        assertEq(lpOut_, mintedLp_, "N3 inbound delta");
        assertEq(lp_.balanceOf(address(nft_)), booked_ + mintedLp_, "N3 no double credit of booked");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N3 id0");
    }

    function test_N4_donate_detf_selfLeg_noMint() public {
        uint256 userDetf_ = IERC20(detf).balanceOf(detfUser);
        assertGt(userDetf_, 0, "N4 bond minted DETF");
        uint256 donateAmt_ = userDetf_ / 4;
        if (donateAmt_ == 0) donateAmt_ = userDetf_;

        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 lpBefore_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 claimBefore_ = IERC20(detfInfo.rebasingClaimToken()).totalSupply();
        uint256 userDetfBefore_ = IERC20(detf).balanceOf(detfUser);

        vm.startPrank(detfUser);
        IERC20(detf).approve(address(nft_), donateAmt_);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(IERC20(detf), donateAmt_, 0, false, _deadline());
        vm.stopPrank();

        assertGt(lpOut_, 0, "N4 lpOut");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "N4 supply");
        assertEq(IERC20(detf).balanceOf(detfUser), userDetfBefore_ - donateAmt_, "N4 donor DETF down");
        assertGt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), lpBefore_, "N4 nftLp");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N4 id0");
        assertEq(IERC20(detfInfo.rebasingClaimToken()).totalSupply(), claimBefore_, "N4 no claim mint");
    }

    function test_N5_inert_reverts() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _policyArgsUnique("dn5");
        address inert_ = _deployDetfWired(args_);
        IDETFNFTVault nft_ = _bondNftVault(inert_);
        pairToken.mint(donor, 1 ether);
        vm.startPrank(donor);
        pairToken.approve(address(nft_), 1 ether);
        vm.expectRevert(abi.encodeWithSignature("ReserveNotLive()"));
        IDetfNftReserveDonation(address(nft_)).donate(
            IERC20(address(pairToken)), 1 ether, 0, false, _deadline()
        );
        vm.stopPrank();
        assertEq(
            IDetfNftReserveDonation(address(nft_)).previewDonate(IERC20(address(pairToken)), 1 ether),
            0,
            "N5 preview inert"
        );
    }

    function test_N6_twoBonders_navUnchanged() public {
        address bob = makeAddr("dn6bob");
        (uint256 bobId,) = _bootstrapViaFirstBond(bob, 80 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 bobOrig_ = nft_.originalSharesOf(bobId);
        uint256 aliceAssets_ = nft_.convertToAssets(userOriginal);
        uint256 bobAssets_ = nft_.convertToAssets(bobOrig_);
        uint256 id0AssetsBefore_ = nft_.convertToAssets(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID));

        _donatePair(donor, 15 ether);

        assertEq(nft_.convertToAssets(userOriginal), aliceAssets_, "N6 alice NAV");
        assertEq(nft_.convertToAssets(bobOrig_), bobAssets_, "N6 bob NAV");
        assertGt(
            nft_.convertToAssets(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID)),
            id0AssetsBefore_,
            "N6 id0 assets"
        );
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID)), 0, "N6 id1");
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID)), 0, "N6 id2");
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "N6 id1 original");
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "N6 id2 original");
    }

    function test_N7_idetf_forwarder_donorIsCollector() public {
        address collector = makeAddr("collector");
        uint256 amt_ = 8 ether;
        pairToken.mint(collector, amt_);
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(collector);
        pairToken.transfer(address(nft_), amt_);

        vm.expectEmit(true, true, false, false, address(nft_));
        emit IDetfNftReserveDonation.ReserveDonated(collector, address(pairToken), amt_, 0);
        vm.prank(collector);
        IDetf(detf).donate(IERC20(address(pairToken)), amt_, true);

        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N7 id0");
    }

    function test_N8_joinDonatedCapital_eoaReverts() public {
        address attacker = makeAddr("dn8");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(UniswapV4SingleStandardExchangeDETFRepo.NotAuthorized.selector, attacker)
        );
        detfInfo.joinDonatedCapital(IERC20(address(pairToken)), 1 ether, _deadline());
    }

    function test_N9_pretransferred_noSurplus_reverts() public {
        IDETFNFTVault nft_ = _nft();
        IDetfNftReserveDonation nftDonate_ = IDetfNftReserveDonation(address(nft_));
        address attacker = makeAddr("dn9");
        SimpleMintableERC20 junk_ = new SimpleMintableERC20("Junk", "JNK");
        junk_.mint(attacker, 25 ether);
        uint256 attackerBefore_ = junk_.balanceOf(attacker);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 lpBefore_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        IERC20 lpToken_ = nft_.lpToken();
        uint256 deadline_ = _deadline();

        vm.prank(attacker);
        vm.expectRevert();
        nftDonate_.donate(IERC20(address(junk_)), 10 ether, 0, true, deadline_);

        assertEq(junk_.balanceOf(attacker), attackerBefore_, "N9 junk");
        assertEq(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N9 id0");
        assertEq(IERC20(nft_.lpToken()).balanceOf(address(nft_)), lpBefore_, "N9 lp");

        vm.prank(attacker);
        vm.expectRevert();
        nftDonate_.donate(lpToken_, 1 ether, 0, true, deadline_);
        assertEq(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N9 lpToken no free credit");
    }

    function test_N9_pretransferred_bookedDetfRewards_reverts() public {
        IDETFNFTVault nft_ = _nft();
        uint256 extra_ = 5 ether;
        deal(detf, address(nft_), IERC20(detf).balanceOf(address(nft_)) + extra_);
        _donatePair(donor, 1 ether);
        uint256 bookedDetf_ = IERC20(detf).balanceOf(address(nft_));
        assertGt(bookedDetf_, 0, "N9 booked DETF");
        uint256 pendingUser_ = nft_.pendingRewards(userBondId);
        uint256 pendingFee_ = nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID);
        uint256 pendingCreator_ = nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        address attacker = makeAddr("dn9detf");
        uint256 deadline_ = _deadline();
        vm.prank(attacker);
        vm.expectRevert();
        IDetfNftReserveDonation(address(nft_)).donate(IERC20(detf), bookedDetf_, 0, true, deadline_);
        vm.prank(attacker);
        vm.expectRevert();
        IDetfNftReserveDonation(address(nft_)).donate(IERC20(detf), 1 ether, 0, true, deadline_);
        assertEq(nft_.pendingRewards(userBondId), pendingUser_, "N9 user pending");
        assertEq(nft_.pendingRewards(DETF_FEE_TO_BOND_NFT_ID), pendingFee_, "N9 fee pending");
        assertEq(nft_.pendingRewards(DETF_CREATOR_BOND_NFT_ID), pendingCreator_, "N9 creator pending");
        assertEq(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N9 id0");
        assertEq(IERC20(detf).balanceOf(address(nft_)), bookedDetf_, "N9 DETF stays booked");
    }

    function test_N10_previewEqualsExecute() public {
        IDETFNFTVault nft_ = _nft();
        uint256 amt_ = 7 ether;
        uint256 preview_ = IDetfNftReserveDonation(address(nft_)).previewDonate(IERC20(address(pairToken)), amt_);
        uint256 lpOut_ = _donatePair(donor, amt_);
        // Single-sided zap join: previewDepositSingle vs execute can differ by zap sale rounding.
        assertApproxEqRel(lpOut_, preview_, 0.01e18, "N10 preview ~ execute");
    }

    function test_N11_ownerOnlyLiquidity_donateStillWorks() public {
        address attacker = makeAddr("dn11");
        address hook_ = detfInfo.reserveHook();
        pairToken.mint(attacker, 5 ether);
        vm.startPrank(attacker);
        pairToken.approve(hook_, 5 ether);
        vm.expectRevert();
        IHook(hook_).depositSingle(address(pairToken), 5 ether, attacker, 0, _deadline());
        vm.stopPrank();
        uint256 lpOut_ = _donatePair(donor, 5 ether);
        assertGt(lpOut_, 0, "N11 donate");
    }

    function test_N12_donate_doesNotRealizeExpansion() public {
        vm.warp(block.timestamp + 8 hours * 24);
        uint256 pending_ = detfInfo.pendingExpansionDetf();
        uint256 lastBefore_ = detfInfo.lastExpansionTimestamp();
        _donatePair(donor, 6 ether);
        assertEq(detfInfo.lastExpansionTimestamp(), lastBefore_, "N12 timestamp");
        assertEq(detfInfo.pendingExpansionDetf(), pending_, "N12 pending");

        if (pending_ > 0) {
            vm.prank(detfUser);
            detfInfo.claimRewards(userBondId, detfUser);
            assertGt(detfInfo.lastExpansionTimestamp(), lastBefore_, "N12 claimRewards realizes");
        }
    }

    function test_N13_burn_afterDonate_usesDonatedLp() public {
        uint256 userDetf_ = IERC20(detf).balanceOf(detfUser);
        assertGt(userDetf_, 0, "N13 bond DETF");
        _donatePair(donor, 12 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 nftLp_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        uint256 burnAmt_ = userDetf_ / 3;
        if (burnAmt_ == 0) burnAmt_ = userDetf_;
        uint256 pairOut_ = _burnToPair(burnAmt_);
        assertGt(pairOut_, 0, "N13 burn");
        assertLt(IERC20(nft_.lpToken()).balanceOf(address(nft_)), nftLp_, "N13 donated LP in D13 formula");
    }

    function test_N14_close_afterDonate() public {
        address bob = makeAddr("dn14bob");
        (uint256 bobId,) = _bootstrapViaFirstBond(bob, 60 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 bobOrig_ = nft_.originalSharesOf(bobId);
        uint256 bobAssetsBefore_ = nft_.convertToAssets(bobOrig_);
        _donatePair(donor, 9 ether);
        assertEq(nft_.convertToAssets(bobOrig_), bobAssetsBefore_, "N14 NAV");

        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(bob);
        uint256[] memory out_ = detfInfo.closeBondMature(bobId, _minOut(), bob, _deadline());
        assertGt(out_[1], 0, "N14 pair basket");
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "N14 no DETF burn");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N14 DETF rejoin id0");
    }

    function test_N15_n10_userConvertUnchanged() public {
        IDETFNFTVault nft_ = _nft();
        uint256 assetsBefore_ = nft_.convertToAssets(userOriginal);
        _donatePair(donor, 11 ether);
        assertEq(nft_.convertToAssets(userOriginal), assetsBefore_, "N15 N10");
        assertGt(nft_.convertToShares(1 ether), 0, "N15 decimalOffset path");
    }

    function test_N16_lastClose_thenDonate_nextBondDoesNotCapture() public {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args_ = _openArgs();
        args_.name = "DN16 Open CP";
        args_.symbol = "dn16cp";
        address instance_ = _deployDetfWired(args_);
        detf = instance_;
        detfInfo = IUniswapV4SingleStandardExchangeDETF(instance_);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        address alice = makeAddr("dn16alice");
        address bob = makeAddr("dn16bob");
        address carol = makeAddr("dn16carol");
        (uint256 aliceId,) = _bootstrapViaFirstBond(alice, 80 ether);
        (uint256 bobId,) = _bootstrapViaFirstBond(bob, 40 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(alice);
        detfInfo.closeBondMature(aliceId, _minOut(), alice, _deadline());
        vm.prank(bob);
        detfInfo.closeBondMature(bobId, _minOut(), bob, _deadline());

        IDETFNFTVault nft_ = _bondNftVault(instance_);
        pairToken.mint(donor, 20 ether);
        vm.startPrank(donor);
        pairToken.approve(address(nft_), 20 ether);
        IDetfNftReserveDonation(address(nft_)).donate(
            IERC20(address(pairToken)), 20 ether, 0, false, _deadline()
        );
        vm.stopPrank();

        uint256 id0AfterDonate_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        assertGt(id0AfterDonate_, 0, "N16 gift on id0");

        (uint256 carolId,) = _bootstrapViaFirstBond(carol, 30 ether);
        // Next bond may compound pending onto id 0; it must not reset id 0 to empty-share G.
        assertGe(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0AfterDonate_, "N16 next bond leaves id0");
        uint256 carolOrig_ = nft_.originalSharesOf(carolId);
        uint256 carolAssets_ = nft_.convertToAssets(carolOrig_);
        uint256 totalLp_ = IERC20(nft_.lpToken()).balanceOf(address(nft_));
        assertLt(carolAssets_, totalLp_, "N16 carol does not swallow donated LP");
    }

    function test_N17_d2_ids12_effectiveShares() public {
        _assertD2();
    }

    function test_N18_disabled_donateReverts_closeWorks() public {
        address bob = makeAddr("dn18bob");
        (uint256 bobId,) = _bootstrapViaFirstBond(bob, 50 ether);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(detf), "N18 disabled");

        IDetfNftReserveDonation nftDonate_ = IDetfNftReserveDonation(address(_nft()));
        uint256 deadline_ = _deadline();
        vm.prank(donor);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf));
        nftDonate_.donate(IERC20(address(pairToken)), 4 ether, 0, false, deadline_);

        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        vm.prank(bob);
        uint256[] memory out_ = detfInfo.closeBondMature(bobId, _minOut(), bob, _deadline());
        assertGt(out_[1], 0, "N18 close after disable");
    }

    function test_N19_permit2_allowance() public {
        IDETFNFTVault nft_ = _nft();
        uint256 amt_ = 5 ether;
        uint256 preview_ = IDetfNftReserveDonation(address(nft_)).previewDonate(IERC20(address(pairToken)), amt_);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.startPrank(donor);
        pairToken.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            address(pairToken), address(nft_), type(uint160).max, type(uint48).max
        );
        uint256 fromPermit_ = IDetfNftReserveDonation(address(nft_)).donateWithPermit2Allowance(
            IERC20(address(pairToken)), amt_, 0, _deadline()
        );
        vm.stopPrank();
        assertApproxEqRel(fromPermit_, preview_, 0.01e18, "N19 permit2 ~ preview");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N19 id0");
    }

    function test_N20_permit2_signature() public {
        IDETFNFTVault nft_ = _nft();
        uint256 amt_ = 4 ether;
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 nonce_ = 0;
        uint256 deadline_ = _deadline();
        ISignatureTransfer.PermitTransferFrom memory permit_ = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(pairToken), amount: amt_}),
            nonce: nonce_,
            deadline: deadline_
        });
        bytes memory sig_ = _signPermit2(donorPk, address(pairToken), amt_, address(nft_), nonce_, deadline_);
        bytes memory data_ = abi.encode(permit_, sig_);

        vm.startPrank(donor);
        pairToken.approve(address(permit2), type(uint256).max);
        uint256 lpOut_ = IDetfNftReserveDonation(address(nft_)).donateWithPermit2Signature(
            IERC20(address(pairToken)), amt_, 0, deadline_, data_
        );
        vm.stopPrank();
        assertGt(lpOut_, 0, "N20 lpOut");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N20 id0");
    }

    function test_N21_d2_afterDonate() public {
        _donatePair(donor, 13 ether);
        _assertD2();
    }

    function test_N22_donate_whilePoolManagerUnlocked() public {
        IDETFNFTVault nft_ = _nft();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        CpDonateDuringUnlockHarness harness = new CpDonateDuringUnlockHarness(pm);
        pairToken.mint(address(harness), 10 ether);
        vm.prank(address(harness));
        pairToken.approve(address(nft_), 10 ether);
        bytes memory ret_ = harness.run(
            address(nft_),
            abi.encodeWithSelector(
                bytes4(keccak256("donate(address,uint256,uint256,bool,uint256)")),
                address(pairToken),
                uint256(10 ether),
                uint256(0),
                false,
                _deadline()
            )
        );
        uint256 lpOut_ = abi.decode(ret_, (uint256));
        assertGt(lpOut_, 0, "N22 lpOut");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "N22 id0");
    }

    function _assertD2() internal view {
        IDETFNFTVault nft_ = _nft();
        (uint256 f_, uint256 c_) = _weightsFC(detf);
        uint256 feeEff_ = nft_.effectiveSharesOf(DETF_FEE_TO_BOND_NFT_ID);
        uint256 creatorEff_ = nft_.effectiveSharesOf(DETF_CREATOR_BOND_NFT_ID);
        uint256 others_ = nft_.totalShares() - feeEff_ - creatorEff_;
        uint256 implied_ = others_ * 1e18 / (1e18 - f_ - c_);
        assertApproxEqAbs(feeEff_, implied_ * f_ / 1e18, 1, "D2 id1");
        assertApproxEqAbs(creatorEff_, implied_ * c_ / 1e18, 1, "D2 id2");
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "id1 original");
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "id2 original");
    }

    function _signPermit2(
        uint256 pk_,
        address token_,
        uint256 amount_,
        address spender_,
        uint256 nonce_,
        uint256 deadline_
    ) internal view returns (bytes memory sig_) {
        bytes32 tokenHash_ = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, token_, amount_));
        bytes32 structHash_ =
            keccak256(abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, tokenHash_, spender_, nonce_, deadline_));
        bytes32 digest_ = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), structHash_));
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(pk_, digest_);
        sig_ = abi.encodePacked(r_, s_, v_);
    }
}
