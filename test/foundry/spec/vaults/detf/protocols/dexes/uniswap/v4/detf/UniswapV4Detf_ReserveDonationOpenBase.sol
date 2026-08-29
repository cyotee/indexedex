// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from
    "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {UniswapV4DetfRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @dev Holds an open PoolManager unlock and calls NFT donate from unlockCallback (DN22).
contract Uv4DetfDonateDuringUnlockHarness is IUnlockCallback {
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

/// @notice Stage 11 Open DN set (PRD §7.0 / §7.5). Shared internals for gold + later Open siblings.
/// @dev No extra deploy `setUp`. Inheritor supplies `TestBase_UniswapV4Detf` (or a Stage 11 fixture).
abstract contract UniswapV4Detf_ReserveDonationOpenBase is TestBase_UniswapV4Detf {
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    address internal dnDonor;
    uint256 internal dnDonorPk;
    uint256 internal dnUserBondId;
    uint256 internal dnUserOriginal;

    struct DnLiveSnap {
        uint256 orig;
        uint256 assets;
        uint256 supply;
        uint256 o;
        uint256 nftLp;
        uint256 id0Orig;
        uint256 userDetf;
    }

    function _nft() internal view virtual returns (IDETFNFTVault) {
        return IDETFNFTVault(detfInfo.bondNftVault());
    }

    function _nftDonate() internal view returns (IDetfNftReserveDonation) {
        return IDetfNftReserveDonation(address(_nft()));
    }

    function _deadline() internal view virtual returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _vaultShare() internal view returns (IERC20) {
        return IERC20(se);
    }

    function _lpToken() internal view returns (IERC20) {
        return _nft().lpToken();
    }

    function _minOut() internal view virtual returns (uint256[] memory m) {
        m = new uint256[](IUniswapV4SeBufferHook(detfInfo.hook()).tokens().length);
    }

    function _dnPreviewTol() internal view returns (uint256) {
        if (address(detfInfo) != address(0)) {
            address hook_ = detfInfo.hook();
            if (hook_ != address(0) && IUniswapV4SeBufferHook(hook_).tokens().length >= 3) {
                return 0.10e18;
            }
        }
        return 0.01e18;
    }

    /// @dev Donate/bond/mint pair. CP/gold: `pairToken`. n-leg/pons override to a live hook token.
    function _openPairToken() internal view virtual returns (IERC20) {
        return IERC20(address(pairToken));
    }

    function _fundOpenPair(address to_, uint256 amount_) internal virtual {
        IERC20 tok_ = _openPairToken();
        try SimpleMintableERC20(address(tok_)).mint(to_, amount_) {
            return;
        } catch {}
        uint256 have_ = tok_.balanceOf(to_);
        if (have_ >= amount_) return;
        deal(address(tok_), to_, have_ + amount_);
    }

    function _ensureDonor() internal {
        if (dnDonor != address(0)) return;
        dnDonorPk = 0xA11CE;
        dnDonor = vm.addr(dnDonorPk);
        IERC20 tok_ = _openPairToken();
        _fundOpenPair(dnDonor, 10_000 ether);
        address hook_ = detfInfo.hook();
        if (hook_ != address(0)) {
            address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
            for (uint256 i; i < toks_.length; ++i) {
                if (toks_[i] == detf) continue;
                try SimpleMintableERC20(toks_[i]).mint(dnDonor, 10_000 ether) {} catch {
                    uint256 have_ = IERC20(toks_[i]).balanceOf(dnDonor);
                    deal(toks_[i], dnDonor, have_ + 10_000 ether);
                }
                vm.prank(dnDonor);
                IERC20(toks_[i]).approve(address(_nft()), type(uint256).max);
                vm.prank(dnDonor);
                IERC20(toks_[i]).approve(detf, type(uint256).max);
            }
        }
        vm.prank(dnDonor);
        tok_.approve(address(_nft()), type(uint256).max);
        vm.prank(dnDonor);
        tok_.approve(detf, type(uint256).max);
    }

    function _ensureLiveBond() internal {
        if (dnUserBondId != 0) return;
        (dnUserBondId,) = _firstBond(80 ether);
        dnUserOriginal = _nft().originalSharesOf(dnUserBondId);
        _ensureDonor();
    }

    /// @dev Morpho wrap markets are thinner than gold SimpleMintable; cap donate size.
    function _dnDonateAmt(uint256 requested_) internal view virtual returns (uint256) {
        return requested_;
    }

    function _donatePair(address from_, uint256 amount_) internal virtual returns (uint256 lpOut_) {
        amount_ = _dnDonateAmt(amount_);
        IDETFNFTVault nft_ = _nft();
        IERC20 tok_ = _openPairToken();
        vm.startPrank(from_);
        tok_.approve(address(nft_), amount_);
        lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(tok_, amount_, 0, false, _deadline());
        vm.stopPrank();
    }

    function _bondAs(address bonder_, uint256 pairAmount_)
        internal
        virtual
        returns (uint256 tokenId_, uint256 shares_)
    {
        IERC20 tok_ = _openPairToken();
        _fundOpenPair(bonder_, pairAmount_);
        vm.startPrank(bonder_);
        tok_.approve(detf, pairAmount_);
        (tokenId_, shares_) = detfInfo.bond(tok_, pairAmount_, DEFAULT_MIN_LOCK, bonder_, false, _deadline());
        vm.stopPrank();
    }

    function _snapLive(uint256 orig_) internal view returns (DnLiveSnap memory s) {
        IDETFNFTVault nft_ = _nft();
        s.orig = orig_;
        s.assets = nft_.convertToAssets(orig_);
        s.supply = IERC20(detf).totalSupply();
        s.o = nft_.totalOriginalShares();
        s.nftLp = _lpToken().balanceOf(address(nft_));
        s.id0Orig = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        s.userDetf = IERC20(detf).balanceOf(detfUser);
    }

    function _assertR12aUnassigned(DnLiveSnap memory before_, uint256 lpOut_) internal view {
        IDETFNFTVault nft_ = _nft();
        assertGt(lpOut_, 0, "lpOut");
        assertGt(_lpToken().balanceOf(address(nft_)), before_.nftLp, "nftLp");
        assertEq(nft_.originalSharesOf(dnUserBondId), dnUserOriginal, "user original");
        assertEq(nft_.originalSharesOf(dnUserBondId), before_.orig, "no originalShares mint");
        assertEq(nft_.totalOriginalShares(), before_.o, "O unchanged");
        assertEq(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), before_.id0Orig, "id0 original");
        assertEq(IERC20(detf).totalSupply(), before_.supply, "no DETF mint");
        assertGt(nft_.convertToAssets(dnUserOriginal), before_.assets, "convertToAssets rises");
    }

    function _weightsFC(address instance_) internal view returns (uint256 f_, uint256 c_) {
        (, f_, c_) = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageSplitOfVault(instance_);
    }

    function _assertD2Identity() internal view {
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

    function _uniqueDetfArgs(string memory tag)
        internal
        view
        virtual
        returns (IUniswapV4Detf.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = string.concat("UniV4 DETF ", tag);
        args.symbol = string.concat("uv4", tag);
    }

    function _lastExpansionTs() internal view returns (uint256 ts) {
        (bool ok_, bytes memory ret_) = detf.staticcall(abi.encodeWithSignature("lastExpansionTimestamp()"));
        if (ok_ && ret_.length >= 32) return abi.decode(ret_, (uint256));
        bytes32 base_ = bytes32(
            uint256(keccak256(abi.encode(uint256(keccak256("vault.detf.uniswap.v4.detf.repo")) - 1)))
                & ~uint256(0xff)
        );
        ts = uint256(vm.load(detf, bytes32(uint256(base_) + 16)));
    }

    function _pairIndex(address[] memory toks_) internal view returns (uint256 idx) {
        address pair_ = address(_openPairToken());
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == pair_) return i;
        }
        revert("pair not in tokens()");
    }

    /// @notice O>0 pairToken donate: unassigned LP; convertToAssets rises; no originalShares mint.
    function test_DN1_donate_pair_Ogt0_unassignedLp() public {
        _ensureLiveBond();
        IDETFNFTVault nft_ = _nft();
        assertGt(nft_.totalOriginalShares(), 0, "O>0");
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 lpOut_ = _donatePair(dnDonor, 10 ether);
        _assertR12aUnassigned(before_, lpOut_);
        assertEq(IERC20(detf).balanceOf(detfUser), before_.userDetf, "user DETF");
        _assertNoJoinableDust();
    }

    /// @notice Same R12a booking for SE vaultShare donate.
    function test_DN2_donate_vaultShare() public {
        _ensureLiveBond();
        IERC20 tok_ = _openPairToken();
        address se_ = IUniswapV4SeBufferHook(detfInfo.hook()).standardExchangeOf(address(tok_));
        if (se_ == address(0)) se_ = se;
        IERC20 share_ = IERC20(se_);
        uint256 pairIn_ = 20 ether;
        _fundOpenPair(dnDonor, pairIn_);
        vm.startPrank(dnDonor);
        tok_.approve(se_, pairIn_);
        uint256 shares_ = IStandardExchangeIn(se_).exchangeIn(
            tok_, pairIn_, share_, 0, dnDonor, false, _deadline()
        );
        vm.stopPrank();
        assertGt(shares_, 0, "DN2 se shares");

        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        vm.startPrank(dnDonor);
        share_.approve(address(_nft()), shares_);
        uint256 lpOut_ = _nftDonate().donate(share_, shares_, 0, false, _deadline());
        vm.stopPrank();
        _assertR12aUnassigned(before_, lpOut_);
        _assertNoJoinableDust();
    }

    /// @notice donate(DETF): no DETF print; self-leg join; R12a unassigned when O>0.
    function test_DN4_donate_detf_selfLeg_noMint() public {
        _ensureLiveBond();
        uint256 userDetf_ = IERC20(detf).balanceOf(detfUser);
        assertGt(userDetf_, 0, "DN4 bond minted DETF");
        uint256 donateAmt_ = userDetf_ / 4;
        if (donateAmt_ == 0) donateAmt_ = userDetf_;

        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 claimBefore_ = IERC20(detfInfo.rebasingClaimToken()).totalSupply();

        vm.startPrank(detfUser);
        IERC20(detf).approve(address(_nft()), donateAmt_);
        uint256 lpOut_ = _nftDonate().donate(IERC20(detf), donateAmt_, 0, false, _deadline());
        vm.stopPrank();

        assertGt(lpOut_, 0, "DN4 lpOut");
        assertEq(IERC20(detf).totalSupply(), before_.supply, "DN4 supply");
        assertEq(IERC20(detf).balanceOf(detfUser), before_.userDetf - donateAmt_, "DN4 donor DETF down");
        assertGt(_lpToken().balanceOf(address(_nft())), before_.nftLp, "DN4 nftLp");
        assertEq(_nft().originalSharesOf(dnUserBondId), dnUserOriginal, "DN4 user original");
        assertEq(_nft().totalOriginalShares(), before_.o, "DN4 O");
        assertEq(_nft().originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), before_.id0Orig, "DN4 no id0 mint");
        assertGt(_nft().convertToAssets(dnUserOriginal), before_.assets, "DN4 NAV rises");
        assertEq(IERC20(detfInfo.rebasingClaimToken()).totalSupply(), claimBefore_, "DN4 no claim mint");
        _assertNoJoinableDust();
    }

    /// @notice Inert donate reverts; previewDonate is 0.
    function test_DN5_inert_reverts() public virtual {
        _ensureDonor();
        address savedHook_ = reserveHook;
        address inert_ = _deployHookThenDetf(_uniqueDetfArgs("dn5"));
        reserveHook = savedHook_;
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

    /// @notice Two bonders: both convertToAssets rise; originalShares unchanged; ids 1–2 still 0 originalShares.
    function test_DN6_twoBonders_navRisesTogether() public {
        _ensureLiveBond();
        address bob = makeAddr("dn6bob");
        (uint256 bobId,) = _bondAs(bob, 80 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 bobOrig_ = nft_.originalSharesOf(bobId);
        uint256 aliceAssets_ = nft_.convertToAssets(dnUserOriginal);
        uint256 bobAssets_ = nft_.convertToAssets(bobOrig_);
        uint256 aliceOrig_ = nft_.originalSharesOf(dnUserBondId);
        uint256 bobOrigBefore_ = bobOrig_;

        _donatePair(dnDonor, 15 ether);

        assertGt(nft_.convertToAssets(dnUserOriginal), aliceAssets_, "DN6 alice NAV");
        assertGt(nft_.convertToAssets(bobOrig_), bobAssets_, "DN6 bob NAV");
        assertEq(nft_.originalSharesOf(dnUserBondId), aliceOrig_, "DN6 alice original");
        assertEq(nft_.originalSharesOf(bobId), bobOrigBefore_, "DN6 bob original");
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "DN6 id1 original");
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "DN6 id2 original");
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID)), 0, "DN6 id1");
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID)), 0, "DN6 id2");
    }

    /// @notice IUniswapV4Detf.donate is required. Pull lands on the NFT. Event donor is the EOA, not the diamond.
    function test_DN7_detf_donate_forwardsToNft() public {
        _ensureLiveBond();
        uint256 amt_ = 8 ether;
        IDETFNFTVault nft_ = _nft();
        uint256 nftLpBefore_ = _lpToken().balanceOf(address(nft_));
        uint256 oBefore_ = nft_.totalOriginalShares();
        uint256 assetsBefore_ = nft_.convertToAssets(dnUserOriginal);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();

        IERC20 tok_ = _openPairToken();
        vm.startPrank(dnDonor);
        tok_.transfer(address(nft_), amt_);
        vm.recordLogs();
        IUniswapV4Detf(detf).donate(tok_, amt_, true);
        vm.stopPrank();

        bytes32 topic0_ = keccak256("ReserveDonated(address,address,uint256,uint256)");
        address donorSeen_;
        bool found_;
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        for (uint256 i; i < logs_.length; ++i) {
            if (logs_[i].emitter == address(nft_) && logs_[i].topics.length >= 3 && logs_[i].topics[0] == topic0_) {
                found_ = true;
                donorSeen_ = address(uint160(uint256(logs_[i].topics[1])));
            }
        }
        assertTrue(found_, "DN7 ReserveDonated");
        assertEq(donorSeen_, dnDonor, "DN7 donor EOA");
        assertTrue(donorSeen_ != detf, "DN7 donor not diamond");
        assertGt(_lpToken().balanceOf(address(nft_)), nftLpBefore_, "DN7 nft LP");
        assertEq(tok_.balanceOf(detf), 0, "DN7 pull not on diamond");
        assertEq(nft_.totalOriginalShares(), oBefore_, "DN7 O");
        assertEq(IERC20(detf).totalSupply(), supplyBefore_, "DN7 no mint");
        assertGt(nft_.convertToAssets(dnUserOriginal), assetsBefore_, "DN7 NAV");
        _assertNoJoinableDust();
    }

    /// @notice EOA joinDonatedCapital reverts NotAuthorized.
    function test_DN8_joinDonatedCapital_eoaReverts() public {
        _ensureLiveBond();
        address attacker = makeAddr("dn8");
        IERC20 tok_ = _openPairToken();
        uint256 deadline_ = _deadline();
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(UniswapV4DetfRepo.NotAuthorized.selector, attacker));
        detfInfo.joinDonatedCapital(tok_, 1 ether, deadline_);
    }

    /// @notice I1: pretransferred with no this-call surplus reverts; no free credit.
    function test_DN9_pretransferred_noSurplus_reverts() public {
        _ensureLiveBond();
        IDETFNFTVault nft_ = _nft();
        IDetfNftReserveDonation nftDonate_ = _nftDonate();
        address attacker = makeAddr("dn9");
        SimpleMintableERC20 junk_ = new SimpleMintableERC20("Junk", "JNK");
        junk_.mint(attacker, 25 ether);
        uint256 attackerBefore_ = junk_.balanceOf(attacker);
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        uint256 lpBefore_ = _lpToken().balanceOf(address(nft_));
        uint256 oBefore_ = nft_.totalOriginalShares();
        IERC20 lpToken_ = nft_.lpToken();
        uint256 deadline_ = _deadline();

        vm.prank(attacker);
        vm.expectRevert();
        nftDonate_.donate(IERC20(address(junk_)), 10 ether, 0, true, deadline_);

        assertEq(junk_.balanceOf(attacker), attackerBefore_, "DN9 junk");
        assertEq(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "DN9 id0");
        assertEq(_lpToken().balanceOf(address(nft_)), lpBefore_, "DN9 lp");
        assertEq(nft_.totalOriginalShares(), oBefore_, "DN9 O");

        vm.prank(attacker);
        vm.expectRevert();
        nftDonate_.donate(lpToken_, 1 ether, 0, true, deadline_);
        assertEq(nft_.totalOriginalShares(), oBefore_, "DN9 lpToken no free credit");
    }

    /// @notice preview donate equals execute lpOut on a closed-form donate route.
    function test_DN10_previewEqualsExecute() public {
        _ensureLiveBond();
        IERC20 token_ = _openPairToken();
        uint256 amt_ = 7 ether;
        uint256 preview_;
        try detfInfo.previewJoinDonatedCapital(token_, amt_) returns (uint256 p_) {
            preview_ = p_;
        } catch {}
        if (preview_ == 0) preview_ = _nftDonate().previewDonate(token_, amt_);
        if (preview_ == 0) {
            token_ = IERC20(detf);
            uint256 userDetf_ = IERC20(detf).balanceOf(detfUser);
            amt_ = userDetf_ / 4;
            if (amt_ == 0) amt_ = userDetf_;
            try detfInfo.previewJoinDonatedCapital(token_, amt_) returns (uint256 p2_) {
                preview_ = p2_;
            } catch {}
            if (preview_ == 0) preview_ = _nftDonate().previewDonate(token_, amt_);
            assertGt(preview_, 0, "DN10 preview");
            vm.startPrank(detfUser);
            IERC20(detf).approve(address(_nft()), amt_);
            uint256 lpOutDetf_ = _nftDonate().donate(token_, amt_, 0, false, _deadline());
            vm.stopPrank();
            // Self-leg previewJoin vs zap execute; pair previewJoinDonatedCapital is 0 / UnsupportedRoute.
            assertApproxEqRel(lpOutDetf_, preview_, 0.12e18, "DN10 preview ~ execute");
            return;
        }
        uint256 lpOut_ = _donatePair(dnDonor, amt_);
        assertApproxEqRel(lpOut_, preview_, _dnPreviewTol(), "DN10 preview ~ execute");
    }

    /// @notice Third-party hook add reverts; donate still succeeds.
    function test_DN11_ownerOnlyLiquidity_donateStillWorks() public {
        _ensureLiveBond();
        address attacker = makeAddr("dn11");
        address hook_ = detfInfo.hook();
        IERC20 tok_ = _openPairToken();
        _fundOpenPair(attacker, 5 ether);
        vm.startPrank(attacker);
        tok_.approve(hook_, 5 ether);
        vm.expectRevert();
        IUniswapV4SeBufferHook(hook_).joinSingleAssetExactIn(
            address(tok_), 5 ether, attacker, 0, _deadline()
        );
        vm.stopPrank();
        uint256 lpOut_ = _donatePair(dnDonor, 5 ether);
        assertGt(lpOut_, 0, "DN11 donate");
        _assertNoJoinableDust();
    }

    /// @notice Donate does not realize expansion: lastExpansionTimestamp / pendingExpansionDetf unchanged.
    function test_DN12_donate_doesNotRealizeExpansion() public {
        _ensureLiveBond();
        vm.warp(block.timestamp + 8 hours * 24);
        uint256 pending_ = detfInfo.pendingExpansionDetf();
        uint256 lastBefore_ = _lastExpansionTs();
        _donatePair(dnDonor, 6 ether);
        assertEq(_lastExpansionTs(), lastBefore_, "DN12 timestamp");
        assertEq(detfInfo.pendingExpansionDetf(), pending_, "DN12 pending");

        if (pending_ > 0) {
            vm.prank(detfUser);
            _nft().claimRewards(dnUserBondId, detfUser);
            assertGt(_lastExpansionTs(), lastBefore_, "DN12 claimRewards realizes");
        }
    }

    /// @notice Burn after donate sizes LP against donated (unassigned) NFT LP.
    function test_DN13_burn_afterDonate_usesDonatedLp() public virtual {
        _ensureLiveBond();
        uint256 userDetf_ = IERC20(detf).balanceOf(detfUser);
        assertGt(userDetf_, 0, "DN13 bond DETF");
        _donatePair(dnDonor, 12 ether);
        IDETFNFTVault nft_ = _nft();
        uint256 nftLp_ = _lpToken().balanceOf(address(nft_));
        uint256 burnAmt_ = userDetf_ / 3;
        if (burnAmt_ == 0) burnAmt_ = userDetf_;
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnAmt_);
        uint256 pairOut_ = detfInfo.burn(burnAmt_, _openPairToken(), 0, detfUser, _deadline());
        vm.stopPrank();
        assertGt(pairOut_, 0, "DN13 burn");
        assertLt(_lpToken().balanceOf(address(nft_)), nftLp_, "DN13 donated LP in D13 formula");
        _assertNoJoinableDust();
    }

    /// @notice Pre-donate bond close: non-DETF basket still paid (DETF slot 0); withdrawn DETF rejoined to id 0.
    function test_DN14_closeAfterDonate_userBasketUnchanged() public virtual {
        _ensureLiveBond();
        address bob = makeAddr("dn14bob");
        (uint256 bobId,) = _bondAs(bob, 60 ether);
        IDETFNFTVault nft_ = _nft();
        address[] memory toks_ = IUniswapV4SeBufferHook(detfInfo.hook()).tokens();
        uint256 detfIdx_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == detf) {
                detfIdx_ = i;
                break;
            }
        }
        uint256[] memory snap_ = detfInfo.previewCloseBondMature(bobId);
        uint256 pairIdx_ = _pairIndex(toks_);
        uint256 pairSnap_ = snap_[pairIdx_];
        assertEq(snap_[detfIdx_], 0, "DN14 snapshot DETF slot unpaid");
        assertGt(pairSnap_, 0, "DN14 snapshot pair");

        _donatePair(dnDonor, 9 ether);

        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 supplyBefore_ = IERC20(detf).totalSupply();
        uint256 id0Before_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(bob);
        uint256[] memory out_ = detfInfo.closeBondMature(bobId, _minOut(), bob, _deadline());
        assertEq(out_[detfIdx_], 0, "DN14 DETF slot not paid");
        assertGt(out_[pairIdx_], 0, "DN14 pair basket");
        assertGe(out_[pairIdx_] + 10, pairSnap_, "DN14 pair >= pre-donate snapshot");
        assertGe(IERC20(detf).totalSupply(), supplyBefore_, "DN14 no DETF burn");
        assertGt(nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID), id0Before_, "DN14 DETF rejoin id0");
        _assertNoJoinableDust();
    }

    /// @notice After last user close, donate, next bond does not capture donated LP via empty-share G.
    function test_DN16_lastClose_thenDonate_nextBondDoesNotCapture() public virtual {
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
        _donatePair(dnDonor, 20 ether);
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

    /// @notice After donate, ids 1 and 2 effectiveShares still f and c of the new total.
    function test_DN17_d2_ids12_effectiveShares() public {
        _ensureLiveBond();
        _donatePair(dnDonor, 8 ether);
        _assertD2Identity();
    }

    /// @notice D10 internals: NFT sell (onlyOwner=DETF) then claim mintFromNFTSale. Unified has no DETF sell selector.
    function _d10SellToClaim(uint256 tokenId_, address seller_) internal returns (uint256 claimMinted_) {
        IDETFNFTVault nft_ = _nft();
        IRebasingClaimToken claim_ = IRebasingClaimToken(detfInfo.rebasingClaimToken());
        uint256 protocolBefore_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(detf);
        (uint256 principal_,) = nft_.sellPositionToDetfNft(tokenId_, seller_, seller_);
        assertGt(principal_, 0, "D10 principal");
        vm.prank(detf);
        claimMinted_ = claim_.mintFromNFTSale(principal_, protocolBefore_, seller_);
        assertGt(claimMinted_, 0, "D10 claim minted");
        assertGt(claim_.balanceOf(seller_), 0, "D10 claim balance");
    }

    function _assertInboundDisabled(address bonder_, bytes memory disabledErr_) internal {
        uint256 deadline_ = _deadline();
        IDetfNftReserveDonation nftDonate_ = _nftDonate();
        IERC20 tok_ = _openPairToken();
        vm.startPrank(dnDonor);
        vm.expectRevert(disabledErr_);
        nftDonate_.donate(tok_, 4 ether, 0, false, deadline_);
        vm.stopPrank();
        vm.startPrank(detfUser);
        vm.expectRevert(disabledErr_);
        detfInfo.mint(tok_, 1 ether, 0, detfUser, false, deadline_);
        vm.stopPrank();
        _fundOpenPair(bonder_, 1 ether);
        vm.startPrank(bonder_);
        tok_.approve(detf, 1 ether);
        vm.expectRevert(disabledErr_);
        detfInfo.bond(tok_, 1 ether, DEFAULT_MIN_LOCK, bonder_, false, deadline_);
        vm.stopPrank();
    }

    function _assertCloseBurnRedeem(uint256 bobId_, address bob_, address carol_, uint256 aliceDetf_)
        internal
    {
        vm.prank(bob_);
        uint256[] memory out_ = detfInfo.closeBondMature(bobId_, _minOut(), bob_, _deadline());
        assertGt(out_[_pairIndex(IUniswapV4SeBufferHook(detfInfo.hook()).tokens())], 0, "DN18 close");
        uint256 burnAmt_ = aliceDetf_ / 4;
        if (burnAmt_ == 0) burnAmt_ = aliceDetf_;
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnAmt_);
        uint256 pairOut_ = detfInfo.burn(burnAmt_, _openPairToken(), 0, detfUser, _deadline());
        vm.stopPrank();
        assertGt(pairOut_, 0, "DN18 burn");
        IRebasingClaimToken claim_ = IRebasingClaimToken(detfInfo.rebasingClaimToken());
        uint256 claimBal_ = claim_.balanceOf(carol_);
        assertGt(claimBal_, 0, "DN18 carol holds claim");
        vm.startPrank(carol_);
        IERC20(address(claim_)).approve(address(claim_), claimBal_);
        uint256 redeemed_ = claim_.redeem(claimBal_, carol_, false);
        vm.stopPrank();
        assertGt(redeemed_, 0, "DN18 redeem");
    }

    /// @notice CROPS: inbound mint/bond/donate revert; mature close, claim redeem, and burn still succeed.
    function test_DN18_disabled_donateReverts_closeWorks() public {
        _ensureLiveBond();
        address bob = makeAddr("dn18bob");
        address carol = makeAddr("dn18carol");
        (uint256 bobId,) = _bondAs(bob, 50 ether);
        (uint256 carolId,) = _bondAs(carol, 40 ether);
        uint256 aliceDetf_ = IERC20(detf).balanceOf(detfUser);
        assertGt(aliceDetf_, 0, "DN18 alice DETF");

        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        assertGt(_d10SellToClaim(carolId, carol), 0, "DN18 pre-disable D10 claim");

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(detf), "DN18 disabled");

        _assertInboundDisabled(
            bob, abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf)
        );
        _assertCloseBurnRedeem(bobId, bob, carol, aliceDetf_);
    }

    /// @notice Donation N15 Permit2 allowance path. R12a: NAV rises, no originalShares mint.
    function test_DN19_permit2_allowance() public {
        _ensureLiveBond();
        IDETFNFTVault nft_ = _nft();
        uint256 amt_ = 5 ether;
        uint256 preview_;
        IERC20 tok_ = _openPairToken();
        try detfInfo.previewJoinDonatedCapital(tok_, amt_) returns (uint256 p_) {
            preview_ = p_;
        } catch {}
        if (preview_ == 0) preview_ = _nftDonate().previewDonate(tok_, amt_);
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        vm.startPrank(dnDonor);
        tok_.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(
            address(tok_), address(nft_), type(uint160).max, type(uint48).max
        );
        uint256 fromPermit_ = _nftDonate().donateWithPermit2Allowance(tok_, amt_, 0, _deadline());
        vm.stopPrank();
        if (preview_ > 0) {
            assertApproxEqRel(fromPermit_, preview_, _dnPreviewTol(), "DN19 permit2 ~ preview");
        }
        _assertR12aUnassigned(before_, fromPermit_);
    }

    /// @notice Donation N15 Permit2 signature path. R12a: NAV rises, no originalShares mint.
    function test_DN20_permit2_signature() public {
        _ensureLiveBond();
        IDETFNFTVault nft_ = _nft();
        uint256 amt_ = 4 ether;
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 nonce_ = 0;
        uint256 deadline_ = _deadline();
        IERC20 tok_ = _openPairToken();
        ISignatureTransfer.PermitTransferFrom memory permit_ = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(tok_), amount: amt_}),
            nonce: nonce_,
            deadline: deadline_
        });
        bytes memory sig_ = _signPermit2(dnDonorPk, address(tok_), amt_, address(nft_), nonce_, deadline_);
        bytes memory data_ = abi.encode(permit_, sig_);

        vm.startPrank(dnDonor);
        tok_.approve(address(permit2), type(uint256).max);
        uint256 lpOut_ = _nftDonate().donateWithPermit2Signature(tok_, amt_, 0, deadline_, data_);
        vm.stopPrank();
        assertGt(lpOut_, 0, "DN20 lpOut");
        _assertR12aUnassigned(before_, lpOut_);
    }

    /// @notice D2 identity after donate: ids 1–2 effectiveShares / zero originalShares. Distinct from DN17.
    function test_DN21_d2_afterDonate() public {
        _ensureLiveBond();
        IDETFNFTVault nft_ = _nft();
        uint256 oBefore_ = nft_.totalOriginalShares();
        _donatePair(dnDonor, 13 ether);
        assertEq(nft_.totalOriginalShares(), oBefore_, "DN21 O unchanged");
        assertEq(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID), 0, "DN21 id1 original");
        assertEq(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID), 0, "DN21 id2 original");
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_FEE_TO_BOND_NFT_ID)), 0, "DN21 id1 assets");
        assertEq(nft_.convertToAssets(nft_.originalSharesOf(DETF_CREATOR_BOND_NFT_ID)), 0, "DN21 id2 assets");
        _assertD2Identity();
        _donatePair(dnDonor, 3 ether);
        _assertD2Identity();
    }

    /// @notice Donate succeeds while PoolManager is unlocked (D30 host LP stays owner-only).
    function test_DN22_donate_whilePoolManagerUnlocked() public {
        _ensureLiveBond();
        IDETFNFTVault nft_ = _nft();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        Uv4DetfDonateDuringUnlockHarness harness = new Uv4DetfDonateDuringUnlockHarness(pm);
        IERC20 tok_ = _openPairToken();
        _fundOpenPair(address(harness), 10 ether);
        vm.prank(address(harness));
        tok_.approve(address(nft_), 10 ether);
        bytes memory ret_ = harness.run(
            address(nft_),
            abi.encodeWithSelector(
                bytes4(keccak256("donate(address,uint256,uint256,bool,uint256)")),
                address(tok_),
                uint256(10 ether),
                uint256(0),
                false,
                _deadline()
            )
        );
        uint256 lpOut_ = abi.decode(ret_, (uint256));
        _assertR12aUnassigned(before_, lpOut_);
    }
}
