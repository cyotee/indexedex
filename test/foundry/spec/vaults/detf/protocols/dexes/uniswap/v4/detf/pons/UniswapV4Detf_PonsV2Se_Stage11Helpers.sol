// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {DETFNFTVaultCommon} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultCommon.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {UniV4DetfPretransferHelper} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol";
import {Uv4DetfDonateDuringUnlockHarness} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationOpenBase.sol";
import {TestBase_UniswapV4Detf_PonsV2Se} from
    "contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol";

/// @notice Pons v2 Stage 11 helpers. Inherits only TestBase_UniswapV4Detf_PonsV2Se (R-5).
/// @dev Pair / mintToken is launchToken. No TestBase_UniswapV4Detf inherit.
abstract contract UniswapV4Detf_PonsV2Se_Stage11Helpers is TestBase_UniswapV4Detf_PonsV2Se {
    uint256 internal constant POLICY_MINT_THRESHOLD = 1.05e18;
    uint256 internal constant POLICY_BURN_THRESHOLD = 0.95e18;
    uint256 internal constant POLICY_EXPANSION_EPOCH = 1 days;
    uint256 internal constant POLICY_EXPANSION_RATE = 0.05e18;
    uint256 internal constant POLICY_EXPANSION_CATCHUP = 4;
    uint256 internal constant FEE_P = 5e16;
    uint256 internal constant FEE_F = 12e16;
    uint256 internal constant FEE_C = 28e16;
    uint256 internal constant LAUNCH_RICH_START = 1.1e18;
    uint256 internal constant LAUNCH_RICH_STEP = 0.05e18;
    uint256 internal constant LAUNCH_RICH_MAX_STEPS = 24;
    uint256 internal constant FIRST_BOND_AMT = 100 ether;
    uint256 internal constant LIVE_MINT_AMT = 10 ether;
    uint256 internal constant ONE_WAD = 1e18;

    bytes32 internal constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 internal constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    address internal policyCreator;
    uint256 internal _policyDeployNonce;
    uint256 internal launchRichOpeningWad;

    address internal dnDonor;
    uint256 internal dnDonorPk;
    uint256 internal dnUserBondId;
    uint256 internal dnUserOriginal;

    address internal d25Alice;
    address internal d25Bob;
    address internal alice;
    address internal bob;
    address internal attacker;
    address internal victim;
    address internal aliceAdv;
    UniV4DetfPretransferHelper internal preHelper;

    struct DnLiveSnap {
        uint256 orig;
        uint256 assets;
        uint256 supply;
        uint256 o;
        uint256 nftLp;
        uint256 id0Orig;
        uint256 userDetf;
    }

    function _bindStage11Actors() internal {
        policyCreator = makeAddr("creator");
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        aliceAdv = makeAddr("aliceAdv");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        preHelper = new UniV4DetfPretransferHelper();
        address canonP2_ = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        vm.etch(canonP2_, address(permit2).code);
        permit2 = IPermit2(canonP2_);
    }

    function _nft() internal view returns (IDETFNFTVault) {
        return IDETFNFTVault(detfInfo.bondNftVault());
    }

    function _nftOf(address d) internal view returns (IDETFNFTVault) {
        return IDETFNFTVault(IUniswapV4Detf(d).bondNftVault());
    }

    function _claimTok() internal view returns (IRebasingClaimToken) {
        return IRebasingClaimToken(detfInfo.rebasingClaimToken());
    }

    function _claimTokOf(address d) internal view returns (IRebasingClaimToken) {
        return IRebasingClaimToken(IUniswapV4Detf(d).rebasingClaimToken());
    }

    function _lpToken() internal view returns (IERC20) {
        return IERC20(detfInfo.hook());
    }

    function _minOut() internal view returns (uint256[] memory m) {
        m = new uint256[](IUniswapV4SeBufferHook(detfInfo.hook()).tokens().length);
    }

    function _minOutOf(address d) internal view returns (uint256[] memory m) {
        m = new uint256[](IUniswapV4SeBufferHook(IUniswapV4Detf(d).hook()).tokens().length);
    }

    function _openPairToken() internal view returns (IERC20) {
        return IERC20(launchToken);
    }

    function _assertNoJoinableDust() internal view {
        address hook_ = detfInfo.hook();
        assertEq(IERC20(hook_).balanceOf(detf), 0, "no hook LP on diamond");
        assertLe(IERC20(launchToken).balanceOf(detf), 10, "no launch on diamond");
        assertLe(IERC20(address(ponsSe)).balanceOf(detf), 10, "no SE share on diamond");
    }

    function _fundLaunch(address to_, uint256 amount_) internal {
        IERC20 tok_ = IERC20(launchToken);
        if (tok_.balanceOf(to_) >= amount_) return;
        uint256 need_ = amount_ - tok_.balanceOf(to_);
        uint256 fromThis_ = tok_.balanceOf(address(this));
        if (fromThis_ > 0 && to_ != address(this)) {
            uint256 send_ = fromThis_ < need_ ? fromThis_ : need_;
            tok_.transfer(to_, send_);
            if (tok_.balanceOf(to_) >= amount_) return;
            need_ = amount_ - tok_.balanceOf(to_);
        }
        _wrapWeth(to_, need_ + 2 ether);
        vm.startPrank(to_);
        IERC20(address(weth)).approve(address(ponsSe), type(uint256).max);
        try IStandardExchangeIn(address(ponsSe)).exchangeIn(
            IERC20(address(weth)), need_, tok_, 0, to_, false, _deadline()
        ) {} catch {}
        vm.stopPrank();
        if (tok_.balanceOf(to_) >= amount_) return;
        uint256 have_ = tok_.balanceOf(to_);
        deal(launchToken, to_, have_ + amount_, true);
    }

    function _fundOpenPair(address to_, uint256 amount_) internal {
        _fundLaunch(to_, amount_);
    }

    function _setFeeOraclePfc(address vault_) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(
            vault_, FEE_P
        );
        IVaultFeeOracleManager(address(indexedexManager)).setSeignioragePotSharesOfVault(
            vault_, FEE_F, FEE_C
        );
        vm.stopPrank();
    }

    function _setPfc(address d) internal {
        _setFeeOraclePfc(d);
    }

    function _setBondTermsOn(address vault_) internal {
        vm.startPrank(owner);
        try IVaultFeeOracleManager(address(indexedexManager)).setVaultBondTerms(
            vault_,
            BondTerms({
                minLockDuration: DEFAULT_MIN_LOCK,
                maxLockDuration: DEFAULT_MAX_LOCK,
                minBonusPercentage: 0,
                maxBonusPercentage: 0.5e18
            })
        ) {} catch {}
        vm.stopPrank();
    }

    function _nextTag() internal returns (string memory) {
        unchecked {
            ++_policyDeployNonce;
        }
        return vm.toString(_policyDeployNonce);
    }

    function _withTag(IUniswapV4Detf.PkgArgs memory args, string memory tag)
        internal
        pure
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        args.name = string.concat(args.name, " ", tag);
        args.symbol = string.concat(args.symbol, tag);
        return args;
    }

    function _withOpening(IUniswapV4Detf.PkgArgs memory args, uint256 wad)
        internal
        pure
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        uint256 n = args.creationPairPerDetfWad.length;
        uint256[] memory opening_ = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            opening_[i] = wad;
        }
        args.openingPairPerDetfWad = opening_;
        return args;
    }

    function _policyArgs() internal view returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _defaultDetfArgs();
        args.name = "PonsV2 Policy";
        args.symbol = "p2P";
        args.mintThreshold = POLICY_MINT_THRESHOLD;
        args.burnThreshold = POLICY_BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.creator = policyCreator;
    }

    function _policyD31Args() internal view returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _policyArgs();
        args.name = "PonsV2 D31";
        args.symbol = "p2D31";
        args.expansionEpochLength = POLICY_EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = POLICY_EXPANSION_RATE;
        args.expansionMaxCatchUpEpochs = POLICY_EXPANSION_CATCHUP;
    }

    function _openArgsPolicy() internal view returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _defaultDetfArgs();
        args.name = "PonsV2 OpenPL";
        args.symbol = "p2Opl";
        args.thresholdMode = ThresholdMode.Open;
        args.creator = policyCreator;
    }

    function _uniqueDetfArgs(string memory tag) internal view returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _defaultDetfArgs();
        args.name = string.concat("PonsV2 ", tag);
        args.symbol = string.concat("p2", tag);
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args) internal returns (address d) {
        address savedHook_ = reserveHook;
        d = _deployHookThenDetf(args);
        reserveHook = savedHook_;
        _setFeeOraclePfc(d);
        _setBondTermsOn(d);
    }

    function _deployTagged(IUniswapV4Detf.PkgArgs memory args, string memory tag) internal returns (address d) {
        return _deployInstance(_withTag(args, tag));
    }

    function _firstBondOn(address d, uint256 amt) internal returns (uint256 tokenId, uint256 shares) {
        _fundLaunch(detfUser, amt);
        vm.startPrank(detfUser);
        IERC20(launchToken).approve(d, type(uint256).max);
        (tokenId, shares) = IUniswapV4Detf(d).bond(
            IERC20(launchToken), amt, DEFAULT_MIN_LOCK, detfUser, false, _deadline()
        );
        vm.stopPrank();
    }

    function _mintOn(address d, uint256 amt) internal returns (uint256 userDetf) {
        _fundLaunch(detfUser, amt * 4);
        vm.startPrank(detfUser);
        IERC20(launchToken).approve(d, type(uint256).max);
        userDetf = IUniswapV4Detf(d).mint(IERC20(launchToken), amt, 0, detfUser, false, _deadline());
        vm.stopPrank();
    }

    function _burnOn(address d, uint256 detfIn, IERC20 tokenOut) internal returns (uint256 amountOut) {
        vm.startPrank(detfUser);
        IERC20(d).approve(d, type(uint256).max);
        amountOut = IUniswapV4Detf(d).burn(detfIn, tokenOut, 0, detfUser, _deadline());
        vm.stopPrank();
    }

    function _bondOn(address d, address who, uint256 amt) internal returns (uint256 tokenId, uint256 shares) {
        _fundLaunch(who, amt * 4);
        vm.startPrank(who);
        IERC20(launchToken).approve(d, type(uint256).max);
        (tokenId, shares) = IUniswapV4Detf(d).bond(
            IERC20(launchToken), amt, DEFAULT_MIN_LOCK, who, false, _deadline()
        );
        vm.stopPrank();
    }

    function _liveMintOn(address d, address who, uint256 amt) internal returns (uint256 userDetf) {
        _fundLaunch(who, amt * 4);
        vm.startPrank(who);
        IERC20(launchToken).approve(d, type(uint256).max);
        userDetf = IUniswapV4Detf(d).mint(IERC20(launchToken), amt, 0, who, false, _deadline());
        vm.stopPrank();
    }

    function _bondAs(address bonder_, uint256 pairAmount_)
        internal
        returns (uint256 tokenId_, uint256 shares_)
    {
        return _bondOn(detf, bonder_, pairAmount_);
    }

    function _goLive(uint256 pairAmount_) internal returns (uint256 tokenId_, uint256 shares_) {
        if (!detfInfo.isReserveLive()) {
            (tokenId_, shares_) = _firstBond(pairAmount_);
        }
        assertTrue(detfInfo.isReserveLive(), "live");
    }

    function _mintPairTo(address, address user_, uint256 pairIn_) internal returns (uint256 out_) {
        return _liveMintOn(detf, user_, pairIn_);
    }

    function _bookPairResidual(address instance_, uint256 residual_) internal {
        _fundLaunch(aliceAdv, residual_);
        vm.prank(aliceAdv);
        IERC20(launchToken).transfer(instance_, residual_);
        IUniswapV4Detf(instance_).compoundProtocolRewards();
        assertGe(IERC20(launchToken).balanceOf(instance_), residual_, "booked residual present");
    }

    function _deltaRevert(uint256 claimed_, uint256 observed_) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, observed_
        );
    }

    function _ensureDonor() internal {
        if (dnDonor != address(0)) return;
        dnDonorPk = 0xA11CE;
        dnDonor = vm.addr(dnDonorPk);
        _fundLaunch(dnDonor, 50_000 ether);
        vm.prank(dnDonor);
        IERC20(launchToken).approve(address(_nft()), type(uint256).max);
        vm.prank(dnDonor);
        IERC20(launchToken).approve(detf, type(uint256).max);
    }

    function _ensureLiveBond() internal {
        if (dnUserBondId != 0) return;
        if (!detfInfo.isReserveLive()) {
            (dnUserBondId,) = _firstBond(80 ether);
        } else {
            (dnUserBondId,) = _firstBond(80 ether);
        }
        dnUserOriginal = _nft().originalSharesOf(dnUserBondId);
        _ensureDonor();
    }

    function _donatePair(address from_, uint256 amount_) internal returns (uint256 lpOut_) {
        _fundLaunch(from_, amount_);
        IDETFNFTVault nft_ = _nft();
        vm.startPrank(from_);
        IERC20(launchToken).approve(address(nft_), amount_);
        lpOut_ = IDetfNftReserveDonation(address(nft_)).donate(
            IERC20(launchToken), amount_, 0, false, _deadline()
        );
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

    function _nftDonate() internal view returns (IDetfNftReserveDonation) {
        return IDetfNftReserveDonation(address(_nft()));
    }

    function _pairIndex(address[] memory toks_) internal view returns (uint256 idx) {
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == launchToken) return i;
        }
        revert("pair not in tokens()");
    }

    function _detfTokenIndex(address[] memory toks_) internal view returns (uint256 idx) {
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == detf) return i;
        }
        revert("DETF not in tokens()");
    }

    function _lastExpansionTs() internal view returns (uint256 ts) {
        (bool ok_, bytes memory ret_) = detf.staticcall(abi.encodeWithSignature("lastExpansionTimestamp()"));
        if (ok_ && ret_.length >= 32) return abi.decode(ret_, (uint256));
    }

    function _d10SellToClaimOn(address d, uint256 tokenId, address seller)
        internal
        returns (uint256 principal, uint256 claimMinted)
    {
        IDETFNFTVault nft_ = _nftOf(d);
        IRebasingClaimToken claim_ = _claimTokOf(d);
        uint256 protocolBefore_ = nft_.originalSharesOf(DETF_PROTOCOL_BOND_NFT_ID);
        vm.prank(d);
        (principal,) = nft_.sellPositionToDetfNft(tokenId, seller, seller);
        vm.prank(d);
        claimMinted = claim_.mintFromNFTSale(principal, protocolBefore_, seller);
    }

    function _d10SellToClaim(uint256 tokenId_, address seller_) internal returns (uint256 claimMinted_) {
        (, claimMinted_) = _d10SellToClaimOn(detf, tokenId_, seller_);
    }

    function _warpMature(uint256 tokenId) internal {
        uint256 unlock_ = _nft().unlockTimeOf(tokenId);
        if (block.timestamp <= unlock_) vm.warp(unlock_ + 1);
    }

    function _warpMatureOf(address d, uint256 tokenId) internal {
        uint256 unlock_ = _nftOf(d).unlockTimeOf(tokenId);
        if (block.timestamp <= unlock_) vm.warp(unlock_ + 1);
    }

    function _redeemOn(address d, address who, uint256 amt) internal returns (uint256 detfOut) {
        IRebasingClaimToken claim_ = _claimTokOf(d);
        vm.prank(who);
        detfOut = claim_.redeem(amt, who, false);
    }

    function _sellAndClaimOn(address d, address seller, uint256 firstAmt, uint256 sellAmt)
        internal
        returns (uint256 claimBal)
    {
        _bondOn(d, seller, firstAmt);
        (uint256 tokenId,) = _bondOn(d, seller, sellAmt);
        _warpMatureOf(d, tokenId);
        _d10SellToClaimOn(d, tokenId, seller);
        claimBal = _claimTokOf(d).balanceOf(seller);
        assertGt(claimBal, 0, "claim minted");
    }

    function _assertRedeemPaysDetfOnly(address d, address who, uint256 amt) internal {
        IERC20 detfTok_ = IERC20(d);
        IERC20 pair_ = IERC20(launchToken);
        IERC20 share_ = IERC20(address(ponsSe));
        IERC20 lp_ = IERC20(IUniswapV4Detf(d).hook());
        uint256 detfBefore_ = detfTok_.balanceOf(who);
        uint256 pairBefore_ = pair_.balanceOf(who);
        uint256 shareBefore_ = share_.balanceOf(who);
        uint256 lpBefore_ = lp_.balanceOf(who);
        uint256 out_ = _redeemOn(d, who, amt);
        assertGt(out_, 0, "DETF out");
        assertEq(detfTok_.balanceOf(who) - detfBefore_, out_, "recipient DETF");
        assertEq(pair_.balanceOf(who), pairBefore_, "pair unchanged");
        assertEq(share_.balanceOf(who), shareBefore_, "SE share unchanged");
        assertEq(lp_.balanceOf(who), lpBefore_, "hook LP unchanged");
    }

    function _ensureActors() internal {
        if (d25Alice != address(0)) return;
        d25Alice = makeAddr("d25alice");
        d25Bob = makeAddr("d25bob");
    }

    function _closeAs(address holder_, uint256 tokenId_) internal returns (uint256[] memory out_) {
        vm.prank(holder_);
        out_ = detfInfo.closeBondMature(tokenId_, _minOut(), holder_, _deadline());
    }

    function _claimRewardsAs(address holder_, uint256 tokenId_) internal returns (uint256 claimed_) {
        IDETFNFTVault nft_ = _nft();
        vm.prank(holder_);
        claimed_ = nft_.claimRewards(tokenId_, holder_);
    }

    function _liveAliceBob() internal returns (uint256 aliceId_, uint256 bobId_) {
        _ensureActors();
        if (!detfInfo.isReserveLive()) _firstBond(80 ether);
        (aliceId_,) = _bondAs(d25Alice, 40 ether);
        (bobId_,) = _bondAs(d25Bob, 20 ether);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
    }

    function _liveAliceOnly() internal returns (uint256 aliceId_) {
        _ensureActors();
        if (!detfInfo.isReserveLive()) _firstBond(80 ether);
        (aliceId_,) = _bondAs(d25Alice, 40 ether);
        _fundLaunch(detfUser, 30 ether);
        vm.startPrank(detfUser);
        IERC20(launchToken).approve(detf, type(uint256).max);
        detfInfo.mint(IERC20(launchToken), 10 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
    }

    function _donateDetfSelf(address d, uint256 amount) internal {
        uint256 bal_ = IERC20(d).balanceOf(detfUser);
        if (amount > bal_) amount = bal_;
        if (amount == 0) return;
        address nft_ = IUniswapV4Detf(d).bondNftVault();
        vm.startPrank(detfUser);
        IERC20(d).approve(nft_, amount);
        IDetfNftReserveDonation(nft_).donate(IERC20(d), amount, 0, false, _deadline());
        vm.stopPrank();
    }

    function _skewSyntheticDown(address d) internal {
        _skewSyntheticDownAmt(d, 80 ether);
    }

    function _skewSyntheticDownAmt(address d, uint256 detfAmt) internal {
        uint256 have_ = IERC20(d).balanceOf(detfUser);
        if (have_ < detfAmt) {
            deal(d, detfUser, have_ + detfAmt, true);
            have_ = IERC20(d).balanceOf(detfUser);
        }
        if (have_ > 0) _donateDetfSelf(d, have_);
    }

    function _ensureFreeDetf(address d, uint256 amt) internal {
        uint256 have_ = IERC20(d).balanceOf(detfUser);
        if (have_ < amt) deal(d, detfUser, amt, true);
    }

    function _donateToken(address d, address token, uint256 amount) internal {
        if (token != d) _fundLaunch(detfUser, amount);
        uint256 have_ = IERC20(token).balanceOf(detfUser);
        if (have_ == 0) return;
        if (amount > have_) amount = have_;
        address nft_ = IUniswapV4Detf(d).bondNftVault();
        vm.startPrank(detfUser);
        IERC20(token).approve(nft_, amount);
        IERC20(token).approve(d, amount);
        try IUniswapV4Detf(d).donate(IERC20(token), amount, false) {} catch {}
        vm.stopPrank();
    }

    function donateTokenExternal(address d, address token, uint256 amt) external {
        _donateToken(d, token, amt);
    }

    function _pushSyntheticUp(address d) internal {
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == d) continue;
            try this.donateTokenExternal(d, toks_[i], 200 ether) {} catch {}
            if (IUniswapV4Detf(d).isMintingAllowed()) return;
        }
    }

    function _deployLaunchRichLive(bool d31_) internal returns (address d) {
        uint256 wad = LAUNCH_RICH_START;
        IUniswapV4Detf info;
        for (uint256 i; i < LAUNCH_RICH_MAX_STEPS; ++i) {
            IUniswapV4Detf.PkgArgs memory args = d31_ ? _policyD31Args() : _policyArgs();
            args = _withOpening(_withTag(args, string.concat("lr", vm.toString(i), _nextTag())), wad);
            d = _deployInstance(args);
            _firstBondOn(d, FIRST_BOND_AMT);
            info = IUniswapV4Detf(d);
            assertTrue(info.isReserveLive(), "first bond live");
            emit log_named_uint("launchRichOpeningWad", wad);
            emit log_named_uint("syntheticAfterFirstBond", info.syntheticPrice());
            if (info.isMintingAllowed()) {
                launchRichOpeningWad = wad;
                return d;
            }
            wad += LAUNCH_RICH_STEP;
        }
        launchRichOpeningWad = wad - LAUNCH_RICH_STEP;
        revert("6.1 launch-rich isMintingAllowed still false after 24 steps");
    }

    function _deployPolicyLaunchRichLive() internal returns (address d) {
        return _deployLaunchRichLive(false);
    }

    function _deployD31LaunchRichLive() internal returns (address d) {
        return _deployLaunchRichLive(true);
    }

    function _deployOpenLive() internal returns (address d) {
        d = _deployTagged(_openArgsPolicy(), _nextTag());
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(IUniswapV4Detf(d).isReserveLive(), "open live");
    }

    function _nftLpOf(address d) internal view returns (uint256) {
        address hook_ = IUniswapV4Detf(d).hook();
        return IERC20(hook_).balanceOf(IUniswapV4Detf(d).bondNftVault());
    }

    function _openingEq(uint256[] memory a, uint256[] memory b) internal pure returns (bool) {
        if (a.length != b.length) return false;
        for (uint256 i; i < a.length; ++i) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }

    function _openingAll(uint256[] memory a, uint256 wad) internal pure returns (bool) {
        if (a.length == 0) return false;
        for (uint256 i; i < a.length; ++i) {
            if (a[i] != wad) return false;
        }
        return true;
    }

    function _expectedJoinDetf(uint256 pairAmount_, uint256 opening_) internal pure returns (uint256) {
        return pairAmount_ * ONE_WAD / opening_;
    }

    function _detfReserveInHook(address d) internal view returns (uint256) {
        address hook_ = IUniswapV4Detf(d).hook();
        uint256 supply_ = IERC20(hook_).totalSupply();
        if (supply_ == 0) return 0;
        uint256[] memory amts_ = IUniswapV4SeBufferHook(hook_).previewExitProportional(supply_);
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256 n_ = toks_.length < amts_.length ? toks_.length : amts_.length;
        for (uint256 i; i < n_; ++i) {
            if (toks_[i] == d) return amts_[i];
        }
        return 0;
    }

    function _feeToOf(address) internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _nftClaim(address d, uint256 tokenId, address to) internal returns (uint256 claimed) {
        IDETFNFTVault nft_ = _nftOf(d);
        vm.prank(to);
        claimed = nft_.claimRewards(tokenId, to);
    }

    function _fcActors() internal {
        if (alice == address(0)) {
            alice = makeAddr("alice");
            bob = makeAddr("bob");
        }
        _setPfc(detf);
        _setBondTermsOn(detf);
    }

    function _bootAlice(uint256 amt) internal returns (uint256 tokenId, uint256 shares) {
        _fcActors();
        return _bondOn(detf, alice, amt);
    }

    function _isHookPair(address[] memory hookToks_, address token_) internal view returns (bool) {
        if (token_ == detf) return false;
        for (uint256 i; i < hookToks_.length; ++i) {
            if (hookToks_[i] == token_) return true;
        }
        return false;
    }

    function _assertDefaultInbound(
        IUniswapV4Detf.IoRoute[] memory rows_,
        address[] memory hookToks_,
        string memory label_
    ) internal view {
        uint256 pairCount_;
        for (uint256 i; i < hookToks_.length; ++i) {
            if (hookToks_[i] == detf) continue;
            unchecked {
                ++pairCount_;
            }
        }
        assertEq(rows_.length, pairCount_ * 2, string.concat(label_, " pair+share"));
        for (uint256 r; r < rows_.length; ++r) {
            address t_ = address(rows_[r].token);
            address v_ = address(rows_[r].vault);
            assertTrue(t_ != detf, string.concat(label_, " no DETF token"));
            bool isPair_ = _isHookPair(hookToks_, t_);
            bool isShare_ = t_ == v_;
            assertTrue(isPair_ || isShare_, string.concat(label_, " pair or share only"));
            if (isPair_) {
                assertEq(v_, IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(t_), "vault=SE of pair");
            }
        }
    }

    function _unboostedBondG(address pair_, uint256 pairEq_) internal view returns (uint256 g_) {
        uint256 supply_ = IERC20(reserveHook).totalSupply();
        uint256[] memory amounts_ = IUniswapV4SeBufferHook(reserveHook).previewExitProportional(supply_);
        address[] memory tokens_ = IUniswapV4SeBufferHook(reserveHook).tokens();
        uint256 reserveDetf_;
        uint256 reservePair_;
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == detf) reserveDetf_ = amounts_[i];
            if (tokens_[i] == pair_) reservePair_ = amounts_[i];
        }
        assertGt(reserveDetf_, 0, "reserve DETF");
        assertGt(reservePair_, 0, "reserve pair");
        g_ = (reserveDetf_ * pairEq_) / reservePair_;
    }
}
