// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {UniswapV4DetfRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpHookFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {DETF_PROTOCOL_BOND_NFT_ID} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";

/// @dev Same-tx helper for I2 short under durable U. Non-SUT harness only.
contract UniV4DetfPretransferHelper {
    function mintPretransfer(
        address detf_,
        IERC20 token_,
        uint256 transferAmt_,
        uint256 claimAmt_,
        address recipient_
    ) external returns (uint256 out_) {
        if (transferAmt_ > 0) {
            token_.transferFrom(msg.sender, detf_, transferAmt_);
        }
        out_ = IUniswapV4Detf(detf_).mint(
            token_, claimAmt_, 0, recipient_, true, block.timestamp + 1 hours
        );
    }

    function bondPretransfer(
        address detf_,
        IERC20 token_,
        uint256 transferAmt_,
        uint256 claimAmt_,
        uint256 lockDuration_,
        address recipient_
    ) external returns (uint256 tokenId_, uint256 shares_) {
        if (transferAmt_ > 0) {
            token_.transferFrom(msg.sender, detf_, transferAmt_);
        }
        (tokenId_, shares_) = IUniswapV4Detf(detf_).bond(
            token_, claimAmt_, lockDuration_, recipient_, true, block.timestamp + 1 hours
        );
    }

    function donatePretransfer(
        address detf_,
        address dest_,
        IERC20 token_,
        uint256 transferAmt_,
        uint256 claimAmt_
    ) external {
        if (transferAmt_ > 0) {
            token_.transferFrom(msg.sender, dest_, transferAmt_);
        }
        IUniswapV4Detf(detf_).donate(token_, claimAmt_, true);
    }
}

/**
 * @title TestBase_UniswapV4Detf_Adversarial
 * @notice Gold adversarial helpers. Extends `TestBase_UniswapV4Detf`; does not edit the parent.
 * @dev E6 N/A no residual-return. Deferred T-NEST-4..8. D18 not tested. M* N/A no calldata forwarder.
 */
abstract contract TestBase_UniswapV4Detf_Adversarial is TestBase_UniswapV4Detf {
    address internal attacker;
    address internal victim;
    address internal aliceAdv;
    UniV4DetfPretransferHelper internal preHelper;

    function _fundPair(address to_, uint256 amount_) internal virtual {
        IERC20 tok_ = IERC20(address(pairToken));
        if (tok_.balanceOf(to_) >= amount_) return;
        try pairToken.mint(to_, amount_) {
            if (tok_.balanceOf(to_) >= amount_) return;
        } catch {}
        uint256 have_ = tok_.balanceOf(to_);
        deal(address(tok_), to_, have_ + amount_);
        if (tok_.balanceOf(to_) >= amount_) return;
        uint256 need_ = amount_ - tok_.balanceOf(to_);
        if (detfUser != to_) {
            uint256 userBal_ = tok_.balanceOf(detfUser);
            uint256 send_ = userBal_ < need_ ? userBal_ : need_;
            if (send_ > 0) {
                vm.prank(detfUser);
                tok_.transfer(to_, send_);
            }
        }
    }

    function setUp() public virtual override {
        TestBase_UniswapV4Detf.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        aliceAdv = makeAddr("aliceAdv");
        preHelper = new UniV4DetfPretransferHelper();
    }

    function _deadline() internal view virtual returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _uniqueDetfArgs(string memory tag_)
        internal
        view
        virtual
        returns (IUniswapV4Detf.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = string.concat("UniV4 DETF ", tag_);
        args.symbol = string.concat("uv4", tag_);
    }

    function _approveUserForDetf(address detf_) internal virtual {
        vm.startPrank(detfUser);
        pairToken.approve(detf_, type(uint256).max);
        IERC20(se).approve(detf_, type(uint256).max);
        vm.stopPrank();
    }

    function _setBondTermsOn(address vault_, uint256 minLock_, uint256 maxLock_) internal {
        vm.startPrank(owner);
        try IVaultFeeOracleManager(address(indexedexManager)).setVaultBondTerms(
            vault_,
            BondTerms({
                minLockDuration: minLock_,
                maxLockDuration: maxLock_,
                minBonusPercentage: 0,
                maxBonusPercentage: 0.5e18
            })
        ) {} catch {}
        vm.stopPrank();
    }

    function _zeroMins(address instance_) internal view returns (uint256[] memory minOut_) {
        address hook_ = IUniswapV4Detf(instance_).hook();
        minOut_ = new uint256[](IUniswapV4SeBufferHook(hook_).tokens().length);
    }

    function _goLive(uint256 pairAmount_) internal returns (uint256 tokenId_, uint256 shares_) {
        (tokenId_, shares_) = _firstBond(pairAmount_);
        assertTrue(detfInfo.isReserveLive(), "live");
    }

    function _mintPairTo(address instance_, address user_, uint256 pairIn_)
        internal
        returns (uint256 out_)
    {
        _fundPair(user_, pairIn_);
        vm.startPrank(user_);
        pairToken.approve(instance_, pairIn_);
        out_ = IUniswapV4Detf(instance_).mint(
            IERC20(address(pairToken)), pairIn_, 0, user_, false, _deadline()
        );
        vm.stopPrank();
    }

    function _bondAs(address instance_, address user_, uint256 pairIn_)
        internal
        virtual
        returns (uint256 tokenId_, uint256 shares_)
    {
        _fundPair(user_, pairIn_);
        vm.startPrank(user_);
        pairToken.approve(instance_, pairIn_);
        (tokenId_, shares_) = IUniswapV4Detf(instance_).bond(
            IERC20(address(pairToken)),
            pairIn_,
            DEFAULT_MIN_LOCK,
            user_,
            false,
            _deadline()
        );
        vm.stopPrank();
    }

    /// @dev Sit pair on the diamond then sync R==B without joining (mint sweep would consume leftover).
    function _bookPairResidual(address instance_, uint256 residual_) internal {
        _fundPair(aliceAdv, residual_);
        vm.prank(aliceAdv);
        pairToken.transfer(instance_, residual_);
        IUniswapV4Detf(instance_).compoundProtocolRewards();
        assertGe(pairToken.balanceOf(instance_), residual_, "booked residual present");
    }

    function _d10SellToClaim(address instance_, uint256 tokenId_, address seller_)
        internal
        returns (uint256 claimMinted_)
    {
        IUniswapV4Detf info_ = IUniswapV4Detf(instance_);
        IDETFNFTVault nft_ = IDETFNFTVault(info_.bondNftVault());
        IRebasingClaimToken claim_ = IRebasingClaimToken(info_.rebasingClaimToken());
        uint256 protocolBefore_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(instance_);
        (uint256 principal_,) = nft_.sellPositionToDetfNft(tokenId_, seller_, seller_);
        assertGt(principal_, 0, "D10 principal");
        vm.prank(instance_);
        claimMinted_ = claim_.mintFromNFTSale(principal_, protocolBefore_, seller_);
        assertGt(claimMinted_, 0, "D10 claim minted");
    }

    function _deltaRevert(uint256 claimed_, uint256 observed_) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, observed_
        );
    }

    function _deployHookThenDetfForPair(
        IUniswapV4Detf.PkgArgs memory args,
        address pair_,
        address se_
    ) internal virtual returns (address detf_) {
        address predicted_ = _predictDetf(args);
        vm.etch(predicted_, address(pairToken).code);
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange: se_,
                pairToken: pair_,
                rawToken: predicted_,
                ownerOnlyLiquidity: true,
                owner: predicted_
            });
        uint256 mineNonce = CpHookFactory.findMineNonce(hookFactory, hookPkg, hArgs);
        address hook_ = CpHookFactory.deployHook(hookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(hook_);
        init.deployPair(predicted_, pair_);
        require(init.finalizeInitialization(), "finalize hostile");
        vm.etch(predicted_, "");
        args.hook = hook_;
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "hostile detf != predicted");
        _setBondTermsOn(detf_, DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        vm.label(detf_, args.symbol);
        vm.label(hook_, "hostileHook");
    }

    /* ------------------------------------------------------------------ */
    /*                         Catalog assert bodies                      */
    /* ------------------------------------------------------------------ */

    function _assertA0_donateBeforeFirstBond_cannotFreeMint() internal {
        address instance_ = detf;
        IUniswapV4Detf info_ = IUniswapV4Detf(instance_);
        uint256 donate_ = 80 ether;
        _fundPair(attacker, donate_);
        vm.prank(attacker);
        IERC20(address(pairToken)).transfer(instance_, donate_);
        assertEq(IERC20(address(pairToken)).balanceOf(instance_), donate_, "donation sitting");
        assertFalse(info_.isReserveLive(), "inert");

        _fundPair(attacker, 1 ether);
        vm.startPrank(attacker);
        IERC20(address(pairToken)).approve(instance_, 1 ether);
        vm.expectRevert(UniswapV4DetfRepo.ReserveNotLive.selector);
        info_.mint(IERC20(address(pairToken)), 1 ether, 0, attacker, false, _deadline());
        vm.stopPrank();

        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(donate_, 0));
        info_.bond(
            IERC20(address(pairToken)),
            donate_,
            DEFAULT_MIN_LOCK,
            attacker,
            true,
            _deadline()
        );

        assertFalse(info_.isReserveLive(), "still inert");
        assertEq(IERC20(address(pairToken)).balanceOf(instance_), donate_, "donation unmoved");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "no free detfToken");

        _goLive(200 ether);
        assertTrue(info_.isReserveLive(), "honest pull first bond live");
        assertEq(IERC20(instance_).balanceOf(attacker), 0, "attacker still unminted");
    }

    function _assertCROPS_disable_inboundGated_matureCloseRedeemBurnWork() internal {
        IUniswapV4Detf info_ = detfInfo;
        (uint256 firstId_,) = _goLive(400 ether);
        (uint256 sellId_,) = _bondAs(detf, detfUser, 80 ether);
        uint256 minted_ = _mintPairTo(detf, detfUser, 40 ether);
        assertGt(minted_, 0, "mint for burn");

        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 claimMinted_ = _d10SellToClaim(detf, sellId_, detfUser);
        assertGt(claimMinted_, 0, "sold to claim");

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(detf));

        bytes memory disabledErr_ =
            abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf);

        vm.startPrank(detfUser);
        vm.expectRevert(disabledErr_);
        info_.mint(IERC20(address(pairToken)), 1 ether, 0, detfUser, false, _deadline());
        vm.expectRevert(disabledErr_);
        info_.bond(
            IERC20(address(pairToken)), 1 ether, DEFAULT_MIN_LOCK, detfUser, false, _deadline()
        );
        vm.expectRevert(disabledErr_);
        info_.donate(IERC20(address(pairToken)), 1 ether, false);
        vm.stopPrank();

        IRebasingClaimToken claim_ = IRebasingClaimToken(info_.rebasingClaimToken());
        uint256 claimBal_ = claim_.balanceOf(detfUser);
        uint256 redeemAmt_ = claimBal_ / 2;
        if (redeemAmt_ == 0) redeemAmt_ = claimBal_;
        vm.startPrank(detfUser);
        IERC20(address(claim_)).approve(address(claim_), redeemAmt_);
        uint256 redeemOut_ = claim_.redeem(redeemAmt_, detfUser, false);
        vm.stopPrank();
        assertGt(redeemOut_, 0, "redeem after disable");

        vm.prank(detfUser);
        uint256[] memory closed_ = info_.closeBondMature(firstId_, _zeroMins(detf), detfUser, _deadline());
        uint256 pairPaid_;
        address[] memory toks_ = IUniswapV4SeBufferHook(info_.hook()).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == address(pairToken)) pairPaid_ = closed_[i];
        }
        assertGt(pairPaid_, 0, "closeBondMature after disable");

        uint256 burnAmt_ = minted_ / 2;
        if (burnAmt_ == 0) burnAmt_ = minted_;
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, burnAmt_);
        uint256 burned_ = info_.burn(burnAmt_, IERC20(address(pairToken)), 0, detfUser, _deadline());
        vm.stopPrank();
        assertGt(burned_, 0, "burn exit after disable");
    }

    function _assertI1_mint() internal {
        _goLive(500 ether);
        uint256 residual_ = 80 ether;
        _bookPairResidual(detf, residual_);

        uint256 invBefore_ = pairToken.balanceOf(detf);
        assertGe(invBefore_, residual_, "absolute inventory present (anti-theater)");
        uint256 claimed_ = residual_;
        uint256 attDetfBefore_ = IERC20(detf).balanceOf(attacker);
        assertEq(pairToken.balanceOf(attacker), 0, "attacker drained");
        assertEq(pairToken.allowance(attacker, detf), 0, "no allowance");

        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(claimed_, 0));
        detfInfo.mint(IERC20(address(pairToken)), claimed_, 0, attacker, true, _deadline());

        assertEq(IERC20(detf).balanceOf(attacker), attDetfBefore_, "I1: no free detfToken mint");
        assertEq(pairToken.balanceOf(detf), invBefore_, "I1: inventory unchanged");
    }

    function _assertI1_bond() internal {
        _goLive(500 ether);
        uint256 residual_ = 60 ether;
        _bookPairResidual(detf, residual_);
        uint256 claimed_ = residual_;
        uint256 invBefore_ = pairToken.balanceOf(detf);

        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(claimed_, 0));
        detfInfo.bond(
            IERC20(address(pairToken)), claimed_, DEFAULT_MIN_LOCK, attacker, true, _deadline()
        );
        assertEq(pairToken.balanceOf(detf), invBefore_, "bond I1: inventory unchanged");
        assertEq(IERC20(detf).balanceOf(attacker), 0, "bond I1: no free detfToken");
    }

    /// @dev I1 donate: pretransferred cannot consume DETF-booked pair. Honest same-caller
    ///      NFT pretransfer is DN7. Leftover after an honest donate is I3.
    function _assertI1_donate() internal {
        _goLive(500 ether);
        address nft_ = detfInfo.bondNftVault();
        uint256 residual_ = 10 ether;
        _bookPairResidual(detf, residual_);
        uint256 detfInvBefore_ = pairToken.balanceOf(detf);
        uint256 nftInvBefore_ = pairToken.balanceOf(nft_);
        assertGe(detfInvBefore_, residual_, "DETF pair inventory present (anti-theater)");
        uint256 attDetfBefore_ = IERC20(detf).balanceOf(attacker);
        assertEq(pairToken.allowance(attacker, nft_), 0, "no nft allowance");
        assertEq(pairToken.allowance(attacker, detf), 0, "no detf allowance");

        vm.prank(attacker);
        vm.expectRevert();
        detfInfo.donate(IERC20(address(pairToken)), residual_, true);

        assertEq(pairToken.balanceOf(detf), detfInvBefore_, "donate I1: DETF pair unchanged");
        assertEq(pairToken.balanceOf(nft_), nftInvBefore_, "donate I1: NFT pair unchanged");
        assertEq(IERC20(detf).balanceOf(attacker), attDetfBefore_, "donate I1: no free detfToken");
    }

    function _assertI2_mint() internal {
        _goLive(500 ether);
        _bookPairResidual(detf, 30 ether);
        uint256 claimed_ = 50 ether;
        _fundPair(attacker, claimed_);
        uint256 shortDelta_ = claimed_ / 2;
        vm.startPrank(attacker);
        pairToken.approve(address(preHelper), shortDelta_);
        vm.expectRevert(_deltaRevert(claimed_, shortDelta_));
        preHelper.mintPretransfer(
            detf, IERC20(address(pairToken)), shortDelta_, claimed_, attacker
        );
        vm.stopPrank();
        assertEq(IERC20(detf).balanceOf(attacker), 0, "I2: no mint on short");
    }

    function _assertI2_bond() internal {
        _goLive(500 ether);
        _bookPairResidual(detf, 30 ether);
        uint256 claimed_ = 40 ether;
        _fundPair(attacker, claimed_);
        uint256 shortDelta_ = claimed_ / 2;
        vm.startPrank(attacker);
        pairToken.approve(address(preHelper), shortDelta_);
        vm.expectRevert(_deltaRevert(claimed_, shortDelta_));
        preHelper.bondPretransfer(
            detf, IERC20(address(pairToken)), shortDelta_, claimed_, DEFAULT_MIN_LOCK, attacker
        );
        vm.stopPrank();
    }

    function _assertI2_donate() internal {
        _goLive(500 ether);
        address nft_ = detfInfo.bondNftVault();
        uint256 claimed_ = 20 ether;
        _fundPair(attacker, claimed_);
        uint256 shortDelta_ = claimed_ / 2;
        vm.startPrank(attacker);
        pairToken.approve(address(preHelper), shortDelta_);
        vm.expectRevert(_deltaRevert(claimed_, shortDelta_));
        preHelper.donatePretransfer(
            detf, nft_, IERC20(address(pairToken)), shortDelta_, claimed_
        );
        vm.stopPrank();
    }

    function _assertI3_mint() internal {
        _goLive(500 ether);
        uint256 residual_ = 30 ether;
        _fundPair(aliceAdv, residual_);
        vm.prank(aliceAdv);
        pairToken.transfer(detf, residual_);
        uint256 victimIn_ = 20 ether;
        uint256 out_ = _mintPairTo(detf, victim, victimIn_);
        assertGt(out_, 0, "honest mint ok");
        uint256 residualAfter_ = pairToken.balanceOf(detf);
        if (residualAfter_ < residual_) {
            // Mint sweep joined leftover pair. Re-book sitting residual so the second
            // pretransfer faces booked inventory, not an empty-U claim-1 escape.
            _bookPairResidual(detf, residual_);
            residualAfter_ = pairToken.balanceOf(detf);
        }
        assertGe(residualAfter_, residual_, "residual still on diamond after honest mint");
        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(residualAfter_, 0));
        detfInfo.mint(
            IERC20(address(pairToken)),
            residualAfter_,
            0,
            attacker,
            true,
            _deadline()
        );
        assertEq(IERC20(detf).balanceOf(attacker), 0, "I3: no free mint");
        assertEq(pairToken.balanceOf(detf), residualAfter_, "I3: residual not free-credited");
    }

    function _assertI3_bond() internal {
        _goLive(500 ether);
        _bookPairResidual(detf, 25 ether);
        uint256 claimed_ = 1 ether;
        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(claimed_, 0));
        detfInfo.bond(
            IERC20(address(pairToken)), claimed_, DEFAULT_MIN_LOCK, attacker, true, _deadline()
        );
        assertEq(IERC20(detf).balanceOf(attacker), 0, "I3 bond: no free");
    }

    function _assertI3_donate() internal {
        _goLive(500 ether);
        _fundPair(aliceAdv, 8 ether);
        address nft_ = detfInfo.bondNftVault();
        vm.startPrank(aliceAdv);
        pairToken.approve(nft_, 8 ether);
        detfInfo.donate(IERC20(address(pairToken)), 8 ether, false);
        vm.stopPrank();
        vm.prank(attacker);
        vm.expectRevert(IDetfErrors.ZeroAmount.selector);
        detfInfo.donate(IERC20(address(pairToken)), 1 ether, true);
        assertEq(IERC20(detf).balanceOf(attacker), 0, "I3 donate: no free");
    }

    function _assertK1_donationNotMintCredit() internal {
        _goLive(500 ether);
        uint256 donate_ = 40 ether;
        _fundPair(attacker, donate_);
        vm.prank(attacker);
        pairToken.transfer(detf, donate_);
        uint256 victimOut_ = _mintPairTo(detf, victim, 20 ether);
        assertGt(victimOut_, 0, "victim honest mint");
        uint256 attBefore_ = IERC20(detf).balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(_deltaRevert(donate_, 0));
        detfInfo.mint(IERC20(address(pairToken)), donate_, 0, attacker, true, _deadline());
        assertEq(IERC20(detf).balanceOf(attacker), attBefore_, "K1: donation not mint credit");
    }

    function _assertT_NEST_1() internal {
        _goLive(500 ether);
        uint256 out_ = _mintPairTo(detf, detfUser, 50 ether);
        assertGt(out_, 0, "T-NEST-1");
        assertEq(IERC20(address(pairToken)).allowance(detf, se), 0, "no nested fund approve");
    }

    function _assertT_NEST_2() internal {
        _goLive(500 ether);
        uint256 dust_ = 10 ether;
        _fundPair(detfUser, dust_ * 2);
        vm.prank(detfUser);
        pairToken.transfer(se, dust_);
        uint256 Rh = IBasicVault(se).reserveOfToken(address(pairToken));
        uint256 Bh = IERC20(address(pairToken)).balanceOf(se);
        uint256 U = Bh >= Rh ? Bh - Rh : 0;
        assertTrue(U > 0, "need surplus");
        uint256 claimOver_ = U + 1;
        vm.expectRevert();
        IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)),
            claimOver_,
            IERC20(se),
            0,
            detfUser,
            true,
            _deadline()
        );
    }

    function _assertT_NEST_3() internal {
        _goLive(500 ether);
        _mintPairTo(detf, detfUser, 40 ether);
        IERC20 tokenIn_ = IERC20(address(pairToken));
        uint256 Rh = IBasicVault(se).reserveOfToken(address(tokenIn_));
        uint256 Bh = tokenIn_.balanceOf(se);
        uint256 U = Bh >= Rh ? Bh - Rh : 0;
        uint256 claim_ = U >= 1 ? U + 1 : uint256(1);
        vm.expectRevert();
        IStandardExchangeIn(se).exchangeIn(
            tokenIn_, claim_, IERC20(se), 0, detfUser, true, _deadline()
        );
    }

    function _assertT_LOCAL_I1() internal {
        _goLive(500 ether);
        _mintPairTo(detf, detfUser, 35 ether);
        uint256 R = IBasicVault(detf).reserveOfToken(address(pairToken));
        uint256 B = IERC20(address(pairToken)).balanceOf(detf);
        uint256 U = B >= R ? B - R : 0;
        if (U == 0) {
            vm.expectRevert();
            vm.prank(detfUser);
            detfInfo.mint(IERC20(address(pairToken)), 1, 0, detfUser, true, _deadline());
        } else {
            vm.prank(detfUser);
            detfInfo.mint(IERC20(address(pairToken)), U, 0, detfUser, true, _deadline());
            vm.expectRevert();
            vm.prank(detfUser);
            detfInfo.mint(IERC20(address(pairToken)), 1, 0, detfUser, true, _deadline());
        }
    }
}
