// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {V4FundedDonationAssertions} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationOpenBase.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";

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
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
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
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";

/// @dev Holds an open PoolManager unlock and calls NFT donate from unlockCallback (DN22).
contract Uv4DetfDonateDuringUnlockHarness_DexUniV4Det is IUnlockCallback {
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
/// @dev No extra deploy `setUp`. Inheritor supplies `TestBase_UniswapV4Detf_Decimals` (or a Stage 11 fixture).
abstract contract UniswapV4Detf_ReserveDonationOpenBase_Decimals is TestBase_UniswapV4Detf_Decimals, V4FundedDonationAssertions {
    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    address internal dnDonor;
    uint256 internal dnDonorPk;
    uint256 internal dnUserBondId;
    uint256 internal dnUserOriginal;


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
        try MintableERC20Decimals(address(tok_)).mint(to_, amount_) {
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
        _fundOpenPair(dnDonor, _uPair(10_000));
        address hook_ = detfInfo.hook();
        if (hook_ != address(0)) {
            address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
            for (uint256 i; i < toks_.length; ++i) {
                if (toks_[i] == detf) continue;
                try SimpleMintableERC20(toks_[i]).mint(dnDonor, _uPair(10_000)) {} catch {
                    uint256 have_ = IERC20(toks_[i]).balanceOf(dnDonor);
                    deal(toks_[i], dnDonor, have_ + _uPair(10_000));
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
        (dnUserBondId,) = _firstBond(_uPair(80));
        dnUserOriginal = IDetfBondNFT(address(_nft())).positionOf(dnUserBondId).principal;
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
        orig_;
        return _fundedDonationSnapshot(detfInfo, dnUserBondId, detfUser);
    }

    function _assertR12aUnassigned(DnLiveSnap memory before_, uint256 lpOut_) internal view {
        _assertFundedDonationOnly(detfInfo, dnUserBondId, detfUser, before_, lpOut_);
    }

    function _weightsFC(address instance_) internal view returns (uint256 f_, uint256 c_) {
        (, f_, c_) = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageSplitOfVault(instance_);
    }

    function _assertD2Identity() internal view {
        _assertDonationStanding(detfInfo, address(indexedexManager));
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

    /// @notice Pair donation increases protocol LP without changing funded positions.
    function test_DN1_donate_pair_Ogt0_unassignedLp() public {
        _ensureLiveBond();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 lp_ = _donatePair(dnDonor, _uPair(10));
        _assertR12aUnassigned(before_, lp_);
        assertEq(IERC20(detf).balanceOf(detfUser), before_.userDetf, "gift cannot pay raw DETF to bonder");
        _assertNoJoinableDust();
    }

    /// @notice Actual SE shares become protocol LP while funded staking remains separate.
    function test_DN2_donate_vaultShare() public {
        _ensureLiveBond();
        IERC20 payment_ = _openPairToken();
        address se_ = IUniswapV4SeBufferHook(detfInfo.hook()).standardExchangeOf(address(payment_));
        _fundOpenPair(dnDonor, _uPair(20));
        vm.startPrank(dnDonor);
        payment_.approve(se_, _uPair(20));
        uint256 shares_ = IStandardExchangeIn(se_).exchangeIn(payment_, _uPair(20), IERC20(se_), 1, dnDonor, false, _deadline());
        vm.stopPrank();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 quote_ = _nftDonate().previewDonate(IERC20(se_), shares_);
        assertGt(quote_, 0, "SE-share donation quote");
        vm.startPrank(dnDonor);
        IERC20(se_).approve(address(_nft()), shares_);
        uint256 lp_ = _nftDonate().donate(IERC20(se_), shares_, quote_, false, _deadline());
        vm.stopPrank();
        assertEq(lp_, quote_, "actual SE-share donation preview");
        _assertR12aUnassigned(before_, lp_);
        _assertNoJoinableDust();
    }

    /// @notice Existing raw DETF can fund the reserve self-leg without new issuance.
    function test_DN4_donate_detf_selfLeg_noMint() public {
        _ensureLiveBond();
        uint256 raw_ = _buyDonationRaw(_uPair(10));
        uint256 amount_ = raw_ / 4;
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 quote_ = _nftDonate().previewDonate(IERC20(detf), amount_);
        assertGt(quote_, 0, "self-leg donation preview");
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(_nft()), amount_);
        uint256 lp_ = _nftDonate().donate(IERC20(detf), amount_, quote_, false, _deadline());
        vm.stopPrank();
        assertEq(lp_, quote_, "self-leg donation preview equals execution");
        _assertR12aUnassigned(before_, lp_);
        assertEq(IERC20(detf).balanceOf(detfUser), before_.userDetf - amount_, "donor supplies existing DETF self-leg");
    }

    /// @notice Inert donate reverts; previewDonate is 0.
    function test_DN5_inert_reverts() public virtual {
        _ensureDonor();
        address savedHook_ = reserveHook;
        address inert_ = _deployHookThenDetf(_uniqueDetfArgs("dn5"));
        reserveHook = savedHook_;
        IDETFNFTVault nft_ = IDETFNFTVault(IUniswapV4Detf(inert_).bondNftVault());
        IERC20 tok_ = _openPairToken();
        _fundOpenPair(dnDonor, _uPair(1));
        vm.startPrank(dnDonor);
        tok_.approve(address(nft_), _uPair(1));
        vm.expectRevert(abi.encodeWithSignature("ReserveNotLive()"));
        IDetfNftReserveDonation(address(nft_)).donate(tok_, _uPair(1), 0, false, _deadline());
        vm.stopPrank();
        assertEq(IDetfNftReserveDonation(address(nft_)).previewDonate(tok_, _uPair(1)), 0, "DN5 preview inert");
    }

    /// @notice Reserve gifts preserve both funded positions and standing rewards.
    function test_DN6_twoBonders_navRisesTogether() public {
        _ensureLiveBond();
        address bob_ = makeAddr("donation second bonder");
        (uint256 bobId_,) = _bondAs(bob_, _uPair(80));
        bytes32 bobBefore_ = keccak256(abi.encode(IDetfBondNFT(address(_nft())).positionOf(bobId_)));
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 lp_ = _donatePair(dnDonor, _uPair(15));
        _assertR12aUnassigned(before_, lp_);
        assertEq(keccak256(abi.encode(IDetfBondNFT(address(_nft())).positionOf(bobId_))), bobBefore_, "gift preserves each funded position independently");
        _assertD2Identity();
    }

    /// @notice Forwarded donation identifies the original EOA and exact received LP.
    function test_DN7_detf_donate_forwardsToNft() public {
        _ensureLiveBond();
        IERC20 token_ = _openPairToken();
        uint256 amount_ = _uPair(8);
        _fundOpenPair(dnDonor, amount_);
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 quote_ = _nftDonate().previewDonate(token_, amount_);
        vm.startPrank(dnDonor);
        token_.transfer(address(_nft()), amount_);
        vm.recordLogs();
        detfInfo.donate(token_, amount_, true);
        vm.stopPrank();
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        bool found_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != address(_nft()) || logs_[i_].topics.length != 3 || logs_[i_].topics[0] != keccak256("ReserveDonated(address,address,uint256,uint256)")) continue;
            assertEq(address(uint160(uint256(logs_[i_].topics[1]))), dnDonor, "forwarded event preserves actual donor");
            assertEq(address(uint160(uint256(logs_[i_].topics[2]))), address(token_), "event payment token");
            (uint256 paid_, uint256 lp_) = abi.decode(logs_[i_].data, (uint256,uint256));
            assertEq(paid_, amount_, "whole forwarded payment");
            assertEq(lp_, quote_, "forwarded donation preview");
            _assertR12aUnassigned(before_, lp_);
            found_ = true;
        }
        assertTrue(found_, "canonical NFT donation event emitted");
    }

    /// @notice EOA joinDonatedCapital reverts NotAuthorized.
    function test_DN8_joinDonatedCapital_eoaReverts() public {
        _ensureLiveBond();
        address attacker = makeAddr("dn8");
        IERC20 tok_ = _openPairToken();
        uint256 deadline_ = _deadline();
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(UniswapV4DetfRepo.NotAuthorized.selector, attacker));
        detfInfo.joinDonatedCapital(tok_, _uPair(1), deadline_);
    }

    /// @notice Unsupported and unreceived LP payments cannot create credit.
    function test_DN9_pretransferred_noSurplus_reverts() public {
        _ensureLiveBond();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        IDetfNftReserveDonation receiver_ = _nftDonate();
        IERC20 lp_ = _lpToken();
        SimpleMintableERC20 junk_ = new SimpleMintableERC20("Junk", "JNK");
        uint256 deadline_ = _deadline();
        address attacker_ = makeAddr("donation no payment");
        vm.expectRevert();
        vm.prank(attacker_);
        receiver_.donate(IERC20(address(junk_)), 1, 0, true, deadline_);
        vm.expectRevert();
        vm.prank(attacker_);
        receiver_.donate(lp_, 1, 0, true, deadline_);
        assertEq(keccak256(abi.encode(_snapLive(dnUserOriginal))), keccak256(abi.encode(before_)), "failed unsupported/pretransferred LP payment cannot change custody or principal");
    }

    /// @notice Supported donation preview equals the actual issued LP.
    function test_DN10_previewEqualsExecute() public {
        _ensureLiveBond();
        uint256 amount_ = _dnDonateAmt(_uPair(7));
        IERC20 token_ = _openPairToken();
        uint256 quote_ = _nftDonate().previewDonate(token_, amount_);
        assertGt(quote_, 0, "supported donation must preview");
        assertEq(quote_, detfInfo.previewJoinDonatedCapital(token_, amount_), "NFT and DETF donation previews agree");
        uint256 lp_ = _donatePair(dnDonor, amount_);
        assertEq(lp_, quote_, "donation preview equals execution");
    }

    /// @notice Third-party hook add reverts; donate still succeeds.
    function test_DN11_ownerOnlyLiquidity_donateStillWorks() public {
        _ensureLiveBond();
        address attacker = makeAddr("dn11");
        address hook_ = detfInfo.hook();
        IERC20 tok_ = _openPairToken();
        _fundOpenPair(attacker, _uPair(5));
        vm.startPrank(attacker);
        tok_.approve(hook_, _uPair(5));
        vm.expectRevert();
        IUniswapV4SeBufferHook(hook_).joinSingleAssetExactIn(
            address(tok_), _uPair(5), attacker, 0, _deadline()
        );
        vm.stopPrank();
        uint256 lpOut_ = _donatePair(dnDonor, _uPair(5));
        assertGt(lpOut_, 0, "DN11 donate");
        _assertNoJoinableDust();
    }

    /// @notice Reserve gifts preserve funded stake; catch-up distributes only newly minted DETF.
    function test_DN12_donate_doesNotRealizeExpansion() public {
        _ensureLiveBond();
        vm.warp(block.timestamp + 24 * 8 hours);
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 lp_ = _donatePair(dnDonor, _uPair(6));
        _assertR12aUnassigned(before_, lp_);
        uint256 pending_ = detfInfo.pendingExpansionDetf();
        uint256 backing_ = IERC20(detf).balanceOf(detfInfo.rebasingClaimToken());
        uint256 issued_ = IDETFFundedRewards(detf).synchronizeRewards();
        assertEq(issued_, pending_, "one catch-up mints the pending funded amount");
        assertEq(IERC20(detf).balanceOf(detfInfo.rebasingClaimToken()) - backing_, issued_, "only minted expansion funds staking");
        assertEq(IDETFFundedRewards(detf).synchronizeRewards(), 0, "same boundary cannot mint twice");
    }

    /// @notice Standard reserve exit still executes after donated liquidity.
    function test_DN13_burn_afterDonate_usesDonatedLp() public virtual {
        _ensureLiveBond();
        uint256 raw_ = _buyDonationRaw(_uPair(10));
        _donatePair(dnDonor, _uPair(12));
        IDETFFundedRewards(detf).synchronizeRewards();
        uint256 amount_ = raw_ / 3;
        IERC20 payment_ = _openPairToken();
        bool primary_ = detfInfo.isBurningAllowed(payment_);
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 quote_ = IStandardExchangeIn(detf).previewExchangeIn(IERC20(detf), amount_, payment_);
        uint256 before_ = payment_.balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, amount_);
        uint256 actual_ = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), amount_, payment_, quote_, detfUser, false, _deadline());
        vm.stopPrank();
        assertGt(actual_, 0, "exit after donated capital");
        assertEq(actual_, quote_, "post-donation burn preview equals execution");
        assertEq(payment_.balanceOf(detfUser) - before_, actual_, "post-donation actual settlement");
        assertEq(IERC20(detf).totalSupply(), primary_ ? supply_ - amount_ : supply_, "primary burn or existing-inventory swap supply");
    }

    /// @notice Mature funded bond claims retain donated protocol LP.
    function test_DN14_closeAfterDonate_userBasketUnchanged() public virtual {
        _ensureLiveBond();
        address bob_ = makeAddr("donation funded claim");
        (uint256 id_,) = _bondAs(bob_, _uPair(60));
        IDetfBondNFT nft_ = IDetfBondNFT(address(_nft()));
        uint256 principal_ = nft_.positionOf(id_).principal;
        _donatePair(dnDonor, _uPair(9));
        assertEq(nft_.positionOf(id_).principal, principal_, "reserve gift does not requote principal");
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 paid_ = _claimFundedDonationPosition(detfInfo, id_, bob_);
        assertGe(paid_, principal_, "mature funded principal plus actual rewards");
        assertEq(nft_.ownerOf(id_), address(0), "final claim retires purchased NFT");
    }

    /// @notice After all prior claims, a new bond receives only its funded purchase.
    function test_DN16_lastClose_thenDonate_nextBondDoesNotCapture() public virtual {
        _ensureLiveBond();
        address bob_ = makeAddr("donation last prior holder");
        address carol_ = makeAddr("donation next holder");
        (uint256 bobId_,) = _bondAs(bob_, _uPair(40));
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        _claimFundedDonationPosition(detfInfo, dnUserBondId, detfUser);
        _claimFundedDonationPosition(detfInfo, bobId_, bob_);
        _donatePair(dnDonor, _uPair(20));
        uint256 lp_ = _lpToken().balanceOf(address(_nft())) + _lpToken().balanceOf(detf);
        assertGt(lp_, 0, "all prior claims preserve donated protocol liquidity");
        (, uint256 principal_,,) = detfInfo.previewBond(_openPairToken(), _uPair(30), DEFAULT_MIN_LOCK);
        (uint256 nextId_,) = _bondAs(carol_, _uPair(30));
        assertEq(IDetfBondNFT(address(_nft())).positionOf(nextId_).principal, principal_, "next bond only receives its quoted funded purchase");
        assertGe(_lpToken().balanceOf(address(_nft())) + _lpToken().balanceOf(detf), lp_, "new bond cannot capture old LP");
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        _claimFundedDonationPosition(detfInfo, nextId_, carol_);
    }

    /// @notice Donations preserve standing weights and actual backing.
    function test_DN17_d2_ids12_effectiveShares() public {
        _ensureLiveBond();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 lp_ = _donatePair(dnDonor, _uPair(8));
        _assertR12aUnassigned(before_, lp_);
        _assertD2Identity();
    }

    /// @notice D10 internals: NFT sell (onlyOwner=DETF) then claim mintFromNFTSale. Unified has no DETF sell selector.
    function _d10SellToClaim(uint256 tokenId_, address seller_) internal returns (uint256 claimMinted_) {
        return _claimFundedDonationPosition(detfInfo, tokenId_, seller_);
    }

    function _assertInboundDisabled(address bonder_, bytes memory disabledErr_) internal {
        uint256 deadline_ = _deadline();
        IDetfNftReserveDonation nftDonate_ = _nftDonate();
        IERC20 tok_ = _openPairToken();
        vm.startPrank(dnDonor);
        vm.expectRevert(disabledErr_);
        nftDonate_.donate(tok_, _uPair(4), 0, false, deadline_);
        vm.stopPrank();
        vm.startPrank(detfUser);
        vm.expectRevert(disabledErr_);
        IStandardExchangeIn(address(detfInfo)).exchangeIn(tok_, _uPair(1), IERC20(address(detfInfo)), 0, detfUser, false, deadline_);
        vm.stopPrank();
        _fundOpenPair(bonder_, _uPair(1));
        vm.startPrank(bonder_);
        tok_.approve(detf, _uPair(1));
        vm.expectRevert(disabledErr_);
        detfInfo.bond(tok_, _uPair(1), DEFAULT_MIN_LOCK, bonder_, false, deadline_);
        vm.stopPrank();
    }

    function _assertCloseBurnRedeem(uint256 bobId_, address bob_, address carol_, uint256 aliceDetf_)
        internal
    {
        _claimFundedDonationPosition(detfInfo, bobId_, bob_);
        _donationUnstake(detfInfo, carol_);
        IERC20 token_ = _openPairToken();
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, aliceDetf_ / 4);
        uint256 paid_ = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), aliceDetf_ / 4, token_, 1, detfUser, false, _deadline());
        vm.stopPrank();
        assertGt(paid_, 0, "reserve exit while disabled");
    }

    /// @notice Disabled instances reject funding but retain funded claims and reserve exits.
    function test_DN18_disabled_donateReverts_closeWorks() public {
        _ensureLiveBond();
        uint256 raw_ = _buyDonationRaw(_uPair(10));
        address bob_ = makeAddr("disabled bond owner");
        address carol_ = makeAddr("disabled staking holder");
        (uint256 bobId_,) = _bondAs(bob_, _uPair(50));
        (uint256 carolId_,) = _bondAs(carol_, _uPair(40));
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        _claimFundedDonationPosition(detfInfo, carolId_, carol_);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(detf));
        IERC20 token_ = _openPairToken();
        bytes memory error_ = abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf);
        uint256 deadline_ = _deadline();
        vm.startPrank(detfUser);
        vm.expectRevert(error_);
        detfInfo.donate(token_, _uPair(1), false);
        vm.expectRevert(error_);
        IStandardExchangeIn(detf).exchangeIn(token_, _uPair(1), IERC20(detf), 0, detfUser, false, deadline_);
        vm.expectRevert(error_);
        detfInfo.bond(token_, _uPair(1), DEFAULT_MIN_LOCK, detfUser, false, deadline_);
        vm.stopPrank();
        _claimFundedDonationPosition(detfInfo, bobId_, bob_);
        assertGt(_donationUnstake(detfInfo, carol_), 0, "disabled instance retains funded unstaking");
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, raw_ / 4);
        uint256 out_ = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), raw_ / 4, token_, 1, detfUser, false, deadline_);
        vm.stopPrank();
        assertGt(out_, 0, "disabled instance retains reserve exit");
    }

    /// @notice Actual Permit2 allowance donation with exact preview and custody.
    function test_DN19_permit2_allowance() public {
        _ensureLiveBond();
        IERC20 token_ = _openPairToken();
        uint256 amount_ = _uPair(5);
        uint256 quote_ = _nftDonate().previewDonate(token_, amount_);
        assertGt(quote_, 0, "Permit2 donation preview");
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        vm.startPrank(dnDonor);
        token_.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(address(token_), address(_nft()), type(uint160).max, type(uint48).max);
        uint256 lp_ = _nftDonate().donateWithPermit2Allowance(token_, amount_, quote_, _deadline());
        vm.stopPrank();
        assertEq(lp_, quote_, "allowance donation preview equals execution");
        _assertR12aUnassigned(before_, lp_);
    }

    /// @notice Actual Permit2 signature donation, exact preview, and replay rejection.
    function test_DN20_permit2_signature() public {
        _ensureLiveBond();
        IERC20 token_ = _openPairToken();
        uint256 amount_ = _uPair(4);
        uint256 deadline_ = _deadline();
        uint256 quote_ = _nftDonate().previewDonate(token_, amount_);
        assertGt(quote_, 0, "signature donation preview");
        ISignatureTransfer.PermitTransferFrom memory signed_ = ISignatureTransfer.PermitTransferFrom({permitted: ISignatureTransfer.TokenPermissions({token: address(token_), amount: amount_}), nonce: 0, deadline: deadline_});
        bytes memory data_ = abi.encode(signed_, _signPermit2(dnDonorPk, address(token_), amount_, address(_nft()), 0, deadline_));
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        vm.startPrank(dnDonor);
        token_.approve(address(permit2), type(uint256).max);
        uint256 lp_ = _nftDonate().donateWithPermit2Signature(token_, amount_, quote_, deadline_, data_);
        vm.stopPrank();
        assertEq(lp_, quote_, "signature donation preview equals execution");
        _assertR12aUnassigned(before_, lp_);
        IDetfNftReserveDonation receiver_ = _nftDonate();
        bytes32 afterFirst_ = keccak256(abi.encode(_snapLive(dnUserOriginal)));
        vm.expectRevert();
        vm.prank(dnDonor);
        receiver_.donateWithPermit2Signature(token_, amount_, quote_, deadline_, data_);
        assertEq(keccak256(abi.encode(_snapLive(dnUserOriginal))), afterFirst_, "used signature cannot receive another LP credit");
    }

    /// @notice Repeated reserve gifts leave standing staking rights unchanged.
    function test_DN21_d2_afterDonate() public {
        _ensureLiveBond();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 first_ = _donatePair(dnDonor, _uPair(13));
        _assertD2Identity();
        uint256 second_ = _donatePair(dnDonor, _uPair(3));
        _assertR12aUnassigned(before_, first_ + second_);
        _assertD2Identity();
    }

    /// @notice Donate succeeds while PoolManager is unlocked (D30 host LP stays owner-only).
    function test_DN22_donate_whilePoolManagerUnlocked() public {
        _ensureLiveBond();
        IDETFNFTVault nft_ = _nft();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        Uv4DetfDonateDuringUnlockHarness_DexUniV4Det harness = new Uv4DetfDonateDuringUnlockHarness_DexUniV4Det(pm);
        IERC20 tok_ = _openPairToken();
        _fundOpenPair(address(harness), _uPair(10));
        vm.prank(address(harness));
        tok_.approve(address(nft_), _uPair(10));
        bytes memory ret_ = harness.run(
            address(nft_),
            abi.encodeWithSelector(
                bytes4(keccak256("donate(address,uint256,uint256,bool,uint256)")),
                address(tok_),
                uint256(_uPair(10)),
                uint256(0),
                false,
                _deadline()
            )
        );
        uint256 lpOut_ = abi.decode(ret_, (uint256));
        _assertR12aUnassigned(before_, lpOut_);
    }

    function _buyDonationRaw(uint256 amount_) internal returns (uint256 out_) {
        IERC20 token_ = _openPairToken();
        _fundOpenPair(detfUser, amount_);
        uint256 quote_ = IStandardExchangeIn(detf).previewExchangeIn(token_, amount_, IERC20(detf));
        vm.startPrank(detfUser);
        token_.approve(detf, amount_);
        out_ = IStandardExchangeIn(detf).exchangeIn(token_, amount_, IERC20(detf), quote_, detfUser, false, _deadline());
        vm.stopPrank();
        assertEq(out_, quote_, "actual standard acquisition for self-leg or burn");
        assertGt(out_, 0, "actual acquired DETF");
    }
}
