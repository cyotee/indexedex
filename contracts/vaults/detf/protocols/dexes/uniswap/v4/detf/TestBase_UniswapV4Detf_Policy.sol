// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
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
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/**
 * @title TestBase_UniswapV4Detf_Policy
 * @notice Policy / opening helpers for unified Uni V4 DETF. Does not edit TestBase_UniswapV4Detf.
 * @dev PRD UNIFIED_DETF_DEPRECATION_TEST_COVERAGE §5.1 / §7.2.
 *      Launch-rich opening starts at 1.1e18, +0.05e18 per step, max 24 (cap 2.25e18).
 *      Recorded mint-open WAD on gold CP: 2.20e18 (synthetic ~1.073e18).
 *      Do not prank(detf) to LP the hook before first bond.
 */
abstract contract TestBase_UniswapV4Detf_Policy is TestBase_UniswapV4Detf {
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

    address internal policyCreator;
    address internal policyDetf;
    IUniswapV4Detf internal policyInfo;
    IERC20 internal policyMintToken;
    uint256 internal launchRichOpeningWad;
    uint256 internal _policyDeployNonce;

    function setUp() public virtual override {
        TestBase_UniswapV4Detf.setUp();
        policyCreator = makeAddr("creator");
    }

    /// @dev n-leg gold overrides to `_nLegDetfArgs(pairCount)`.
    function _baseArgs() internal virtual returns (IUniswapV4Detf.PkgArgs memory) {
        return _defaultDetfArgs();
    }

    /// @notice Policy PkgArgs: ThresholdMode.Policy, mint 1.05e18, burn 0.95e18, expansion 0.
    function _policyArgs() internal virtual returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _baseArgs();
        args.name = "UniV4 DETF Policy";
        args.symbol = "uv4P";
        args.mintThreshold = POLICY_MINT_THRESHOLD;
        args.burnThreshold = POLICY_BURN_THRESHOLD;
        args.thresholdMode = ThresholdMode.Policy;
        args.expansionEpochLength = 0;
        args.expansionClosureRatePerYearWad = 0;
        args.expansionMaxCatchUpEpochs = 0;
        args.creator = policyCreator;
    }

    /// @notice D31 Policy rows only: expansion 1 days / 0.05e18 / 4.
    function _policyD31Args() internal virtual returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _policyArgs();
        args.name = "UniV4 DETF D31";
        args.symbol = "uv4D31";
        args.expansionEpochLength = POLICY_EXPANSION_EPOCH;
        args.expansionClosureRatePerYearWad = POLICY_EXPANSION_RATE;
        args.expansionMaxCatchUpEpochs = POLICY_EXPANSION_CATCHUP;
    }

    /// @notice Open mode, expansion fields 0.
    function _openArgsPolicy() internal virtual returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _baseArgs();
        args.name = "UniV4 DETF OpenPL";
        args.symbol = "uv4Opl";
        args.thresholdMode = ThresholdMode.Open;
        args.expansionEpochLength = 0;
        args.expansionClosureRatePerYearWad = 0;
        args.expansionMaxCatchUpEpochs = 0;
        args.creator = policyCreator;
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

    function _nextTag() internal returns (string memory) {
        unchecked {
            ++_policyDeployNonce;
        }
        return vm.toString(_policyDeployNonce);
    }

    function _deadline() internal view virtual returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _setFeeOraclePfc(address vault_) internal {
        vm.startPrank(owner);
        try IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(
            vault_, FEE_P
        ) {} catch {}
        try IVaultFeeOracleManager(address(indexedexManager)).setSeignioragePotSharesOfVault(
            vault_, FEE_F, FEE_C
        ) {} catch {}
        vm.stopPrank();
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

    function _mintTokenOf(address d) internal view virtual returns (IERC20 tok) {
        address[] memory toks_ = IUniswapV4SeBufferHook(IUniswapV4Detf(d).hook()).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] != d) return IERC20(toks_[i]);
        }
        revert("no mintToken");
    }

    function _fundToken(address token_, address to_, uint256 amount_) internal virtual {
        IERC20 tok_ = IERC20(token_);
        if (tok_.balanceOf(to_) >= amount_) return;
        try SimpleMintableERC20(token_).mint(to_, amount_) {
            if (tok_.balanceOf(to_) >= amount_) return;
        } catch {}
        uint256 have_ = tok_.balanceOf(to_);
        deal(token_, to_, have_ + amount_);
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
        if (tok_.balanceOf(to_) < amount_) {
            _fundTokenFallback(token_, to_, amount_);
        }
    }

    /// @dev Pons/Morpho TestBases buy or seed when mint/deal cannot fund the token.
    function _fundTokenFallback(address, address, uint256) internal virtual {}

    function _fundPair(address to_, uint256 amount_) internal virtual {
        _fundToken(address(pairToken), to_, amount_);
    }

    function _fundAndApprove(address d) internal {
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == d) continue;
            _fundToken(toks_[i], detfUser, FIRST_BOND_AMT * 4);
        }
        vm.startPrank(detfUser);
        for (uint256 j; j < toks_.length; ++j) {
            if (toks_[j] == d) continue;
            IERC20(toks_[j]).approve(d, type(uint256).max);
            IERC20(toks_[j]).approve(hook_, type(uint256).max);
            address nft_ = IUniswapV4Detf(d).bondNftVault();
            if (nft_ != address(0)) IERC20(toks_[j]).approve(nft_, type(uint256).max);
        }
        IERC20(d).approve(d, type(uint256).max);
        IERC20(se).approve(d, type(uint256).max);
        vm.stopPrank();
    }

    function _bindPolicy(address d) internal {
        policyDetf = d;
        policyInfo = IUniswapV4Detf(d);
        policyMintToken = _mintTokenOf(d);
        _setFeeOraclePfc(d);
        _setBondTermsOn(d);
        _fundAndApprove(d);
    }

    function _firstBondOn(address d, uint256 amt) internal returns (uint256 tokenId, uint256 shares) {
        IERC20 tok_ = _mintTokenOf(d);
        _fundToken(address(tok_), detfUser, amt);
        vm.startPrank(detfUser);
        tok_.approve(d, type(uint256).max);
        (tokenId, shares) = IUniswapV4Detf(d).bond(
            tok_, amt, DEFAULT_MIN_LOCK, detfUser, false, _deadline()
        );
        vm.stopPrank();
    }

    function _mintOn(address d, uint256 amt) internal returns (uint256 userDetf) {
        IERC20 tok_ = _mintTokenOf(d);
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == d) continue;
            _fundToken(toks_[i], detfUser, amt * 4);
        }
        vm.startPrank(detfUser);
        tok_.approve(d, type(uint256).max);
        userDetf = IUniswapV4Detf(d).mint(tok_, amt, 0, detfUser, false, _deadline());
        vm.stopPrank();
    }

    function _burnOn(address d, uint256 detfIn, IERC20 tokenOut) internal virtual returns (uint256 amountOut) {
        vm.startPrank(detfUser);
        IERC20(d).approve(d, type(uint256).max);
        amountOut = IUniswapV4Detf(d).burn(detfIn, tokenOut, 0, detfUser, _deadline());
        vm.stopPrank();
    }

    /// @dev Hook-specific TestBases override to deploy orbital/weighted/quad instead of CP.
    function _deployInstance(IUniswapV4Detf.PkgArgs memory args) internal virtual returns (address) {
        return _deployHookThenDetf(args);
    }

    function _deployTagged(IUniswapV4Detf.PkgArgs memory args, string memory tag)
        internal
        returns (address d)
    {
        d = _deployInstance(_withTag(args, tag));
        _bindPolicy(d);
    }

    /// @notice Launch-rich Policy: opening 1.1e18 then +0.05e18 until isMintingAllowed after first bond.
    /// @dev Max 24 steps (final 2.25e18). Still false is §6.1. Never prank(detf) LP before first bond.
    function _deployPolicyLaunchRichLive() internal returns (address d) {
        return _deployLaunchRichLive(false);
    }

    function _deployD31LaunchRichLive() internal returns (address d) {
        return _deployLaunchRichLive(true);
    }

    function _deployLaunchRichLive(bool d31_) internal returns (address d) {
        uint256 wad = LAUNCH_RICH_START;
        IUniswapV4Detf info;
        for (uint256 i; i < LAUNCH_RICH_MAX_STEPS; ++i) {
            IUniswapV4Detf.PkgArgs memory args = d31_ ? _policyD31Args() : _policyArgs();
            args = _withOpening(_withTag(args, string.concat("lr", vm.toString(i), _nextTag())), wad);
            d = _deployInstance(args);
            _bindPolicy(d);
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

    function _deployOpenLive() internal returns (address d) {
        d = _deployTagged(_openArgsPolicy(), _nextTag());
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(IUniswapV4Detf(d).isReserveLive(), "open live");
        return d;
    }

    function _deployPolicyAtPegLive() internal returns (address d) {
        d = _deployTagged(_policyArgs(), _nextTag());
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(IUniswapV4Detf(d).isReserveLive(), "policy peg live");
        return d;
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

    function _donateMintToken(address d, uint256 amount) internal {
        IERC20 tok_ = _mintTokenOf(d);
        _fundToken(address(tok_), detfUser, amount);
        address nft_ = IUniswapV4Detf(d).bondNftVault();
        vm.startPrank(detfUser);
        tok_.approve(nft_, amount);
        tok_.approve(d, amount);
        IUniswapV4Detf(d).donate(tok_, amount, false);
        vm.stopPrank();
    }

    /// @dev D30: prank(detf) ownerSwapExactIn only after first bond. Pulls tokenIn from the DETF.
    ///      Chunked: n-leg owner swaps revert on large exact-in.
    function _ownerSwap(address d, address tokenIn, address tokenOut, uint256 amount) internal virtual {
        address hook_ = IUniswapV4Detf(d).hook();
        uint256 left_ = amount;
        for (uint256 i; i < 16 && left_ > 0; ++i) {
            uint256 chunk_ = left_ > 8 ether ? 8 ether : left_;
            if (tokenIn != d) {
                _fundToken(tokenIn, d, chunk_);
            }
            vm.startPrank(d);
            IERC20(tokenIn).approve(hook_, chunk_);
            try IUniswapV4SeBufferHook(hook_).ownerSwapExactIn(tokenIn, tokenOut, chunk_, 0, _deadline()) {
                left_ -= chunk_;
            } catch {
                vm.stopPrank();
                if (chunk_ <= 1 ether) break;
                left_ = chunk_ / 2;
                continue;
            }
            vm.stopPrank();
        }
    }

    function _pushSyntheticUp(address d) internal virtual {
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == d) continue;
            try this.donateTokenExternal(d, toks_[i], 200 ether) {} catch {}
            if (IUniswapV4Detf(d).isMintingAllowed()) return;
        }
        IERC20 tok_ = _mintTokenOf(d);
        try this.ownerSwapExternal(d, address(tok_), d, 8 ether) {} catch {}
    }

    function ownerSwapExternal(address d, address tokenIn, address tokenOut, uint256 amount) external {
        _ownerSwap(d, tokenIn, tokenOut, amount);
    }

    function donateExternal(address d, uint256 amt) external {
        _donateMintToken(d, amt);
    }

    function donateTokenExternal(address d, address token, uint256 amt) external {
        _donateToken(d, token, amt);
    }

    /// @dev Donate DETF self-leg into Bond NFT. Joins DETF reserve and lowers S on every pair.
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

    function _donateToken(address d, address token, uint256 amount) internal {
        if (token != d) {
            _fundToken(token, detfUser, amount);
        }
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

    /// @dev Close mint / open burn by joining free DETF as the self-leg. Do not mint first:
    ///      mint joins pair and raises S, which cancels the donate. Deal DETF (adjust supply) then donate.
    function _skewSyntheticDown(address d) internal virtual {
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

    function mintExternal(address d, uint256 amt) external {
        _mintOn(d, amt);
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

    /* ------------------------------------------------------------------ */
    /*                         Shared assert bodies                         */
    /* ------------------------------------------------------------------ */

    function _assert_T7_8_policy_isMintingAllowed_token(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Policy), "Policy");
        assertEq(info.mintThreshold(), POLICY_MINT_THRESHOLD);
        assertEq(info.burnThreshold(), POLICY_BURN_THRESHOLD);
        assertTrue(info.isReserveLive(), "live");
        IUniswapV4Detf.IoRoute[] memory routes_ = info.mintRoutes();
        assertGt(routes_.length, 0, "mintRoutes");
        bool any_;
        uint256 syn_ = info.syntheticPrice();
        bool expectedGate_ = syn_ > info.mintThreshold();
        for (uint256 i; i < routes_.length; ++i) {
            bool tok_ = info.isMintingAllowed(routes_[i].token);
            assertEq(tok_, expectedGate_, "H8 token gate");
            if (tok_) any_ = true;
        }
        assertEq(info.isMintingAllowed(), any_, "no-arg iff some mintRoutes token");
        assertFalse(info.isMintingAllowed(IERC20(address(this))), "unknown token");
    }

    function _assert_policy_mint_blocked_in_deadband_then_allowed_after_push(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 tok_ = _mintTokenOf(d);
        assertTrue(info.isMintingAllowed(), "launch-rich mint can pass");
        uint256 opened_ = _mintOn(d, LIVE_MINT_AMT);
        assertGt(opened_, 0, "mint while allowed");

        for (uint256 i; i < 24 && info.isMintingAllowed(); ++i) {
            _skewSyntheticDown(d);
        }
        assertFalse(info.isMintingAllowed(), "skewed into mint-blocked");
        uint256 synBlocked_ = info.syntheticPrice();
        uint256 mintTh_ = info.mintThreshold();
        vm.startPrank(detfUser);
        vm.expectRevert(
            abi.encodeWithSelector(UniswapV4DetfRepo.MintingNotAllowed.selector, synBlocked_, mintTh_)
        );
        info.mint(tok_, 1 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();

        for (uint256 j; j < 24 && !info.isMintingAllowed(); ++j) {
            _pushSyntheticUp(d);
        }
        assertTrue(info.isMintingAllowed(), "mint allowed after push");
        assertGt(info.syntheticPrice(), info.mintThreshold(), "S > mintThreshold");
        (uint256 grossPred, uint256 userPred,) = info.previewMint(tok_, LIVE_MINT_AMT);
        grossPred;
        uint256 userOut_ = _mintOn(d, LIVE_MINT_AMT);
        assertEq(userOut_, userPred, "preview==exec after push");
        assertGt(userOut_, 0);
    }

    function _assert_policy_burn_allowed_when_synthetic_below_burnThreshold(address d) internal virtual {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 tok_ = _mintTokenOf(d);
        if (info.isMintingAllowed()) {
            _mintOn(d, LIVE_MINT_AMT);
        }
        for (uint256 i; i < 40 && !info.isBurningAllowed(); ++i) {
            _skewSyntheticDownAmt(d, 400 ether);
        }
        assertTrue(info.isBurningAllowed(), "burn allowed");
        assertLt(info.syntheticPrice(), info.burnThreshold(), "S < burnThreshold");
        _ensureFreeDetf(d, LIVE_MINT_AMT);
        uint256 bal_ = IERC20(d).balanceOf(detfUser);
        require(bal_ > 0, "need free DETF to burn");
        uint256 burnAmt_ = bal_ / 10;
        if (burnAmt_ == 0) burnAmt_ = bal_;
        info.compoundProtocolRewards();
        assertTrue(info.isBurningAllowed(), "burn still allowed after realize");
        uint256 out_ = _burnOn(d, burnAmt_, tok_);
        assertGt(out_, 0, "burn succeeds below burnThreshold");
    }

    function _assert_open_never_expands(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Open), "Open");
        if (!info.isReserveLive()) _firstBondOn(d, FIRST_BOND_AMT);
        info.compoundProtocolRewards();
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * 50);
        assertEq(info.pendingExpansionDetf(), 0, "Open never pending");
        uint256 supplyBefore_ = IERC20(d).totalSupply();
        _mintOn(d, LIVE_MINT_AMT);
        assertEq(info.pendingExpansionDetf(), 0, "Open mint no expansion");
        assertGt(IERC20(d).totalSupply(), supplyBefore_, "open mint minted");
    }

    function _assert_D31_1_policyMint_realizesThenGates(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Policy));
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * POLICY_EXPANSION_CATCHUP);
        uint256 pending_ = info.pendingExpansionDetf();
        uint256 nftBefore_ = IERC20(d).balanceOf(info.bondNftVault());
        uint256 supplyBefore_ = IERC20(d).totalSupply();
        if (!info.isMintingAllowed()) {
            vm.startPrank(detfUser);
            vm.expectRevert();
            info.mint(_mintTokenOf(d), LIVE_MINT_AMT, 0, detfUser, false, _deadline());
            vm.stopPrank();
            assertEq(IERC20(d).totalSupply(), supplyBefore_, "D31-1 fail: supply");
            assertEq(info.pendingExpansionDetf(), pending_, "D31-1 fail: pending stuck");
            return;
        }
        _mintOn(d, LIVE_MINT_AMT);
        if (pending_ > 0) {
            assertGe(IERC20(d).balanceOf(info.bondNftVault()), nftBefore_ + pending_ - 1, "D31-1 realized");
        }
    }

    function _assert_D31_2_realizeWouldCloseMint_revertsUnchanged(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 tok_ = _mintTokenOf(d);
        for (uint256 i; i < 30; ++i) {
            vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * POLICY_EXPANSION_CATCHUP);
            if (!info.isMintingAllowed()) {
                uint256 supplyBefore_ = IERC20(d).totalSupply();
                uint256 pendingBefore_ = info.pendingExpansionDetf();
                uint256 nftBefore_ = IERC20(d).balanceOf(info.bondNftVault());
                vm.startPrank(detfUser);
                vm.expectRevert();
                info.mint(tok_, 5 ether, 0, detfUser, false, _deadline());
                vm.stopPrank();
                assertEq(IERC20(d).totalSupply(), supplyBefore_, "D31-2 supply");
                assertEq(info.pendingExpansionDetf(), pendingBefore_, "D31-2 pending");
                assertEq(IERC20(d).balanceOf(info.bondNftVault()), nftBefore_, "D31-2 nft");
                return;
            }
            _skewSyntheticDown(d);
        }
        // Last resort: deal DETF and donate self-leg. Do not mint (mint joins pair and keeps S high).
        for (uint256 j; j < 20 && info.isMintingAllowed(); ++j) {
            uint256 dump_ = IERC20(d).balanceOf(detfUser);
            if (dump_ < 20 ether) {
                deal(d, detfUser, dump_ + 80 ether, true);
                dump_ = IERC20(d).balanceOf(detfUser);
            }
            if (dump_ == 0) break;
            _donateDetfSelf(d, dump_);
        }
        assertFalse(info.isMintingAllowed(), "D31-2 need mint closed");
        uint256 supply2_ = IERC20(d).totalSupply();
        uint256 pending2_ = info.pendingExpansionDetf();
        vm.startPrank(detfUser);
        vm.expectRevert();
        info.mint(tok_, 5 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();
        assertEq(IERC20(d).totalSupply(), supply2_, "D31-2 supply fallback");
        assertEq(info.pendingExpansionDetf(), pending2_, "D31-2 pending fallback");
    }

    function _assert_D31_3_policyBurn_realizesThenGates(address d) internal virtual {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 tok_ = _mintTokenOf(d);
        if (info.isMintingAllowed()) _mintOn(d, LIVE_MINT_AMT);
        for (uint256 i; i < 40 && !info.isBurningAllowed(); ++i) {
            _skewSyntheticDownAmt(d, 400 ether);
        }
        assertTrue(info.isBurningAllowed(), "D31-3 burn allowed");
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * 2);
        uint256 pending_ = info.pendingExpansionDetf();
        uint256 supplyBefore_ = IERC20(d).totalSupply();
        uint256 nftBefore_ = IERC20(d).balanceOf(info.bondNftVault());
        _ensureFreeDetf(d, LIVE_MINT_AMT);
        uint256 bal_ = IERC20(d).balanceOf(detfUser);
        require(bal_ > 0, "D31-3 need DETF");
        uint256 burnAmt_ = bal_ / 10;
        if (burnAmt_ == 0) burnAmt_ = bal_;
        if (!info.isBurningAllowed()) {
            vm.startPrank(detfUser);
            IERC20(d).approve(d, type(uint256).max);
            vm.expectRevert();
            info.burn(burnAmt_, tok_, 0, detfUser, _deadline());
            vm.stopPrank();
            assertEq(IERC20(d).totalSupply(), supplyBefore_, "D31-3 fail supply");
            assertEq(info.pendingExpansionDetf(), pending_, "D31-3 fail pending");
            return;
        }
        _burnOn(d, burnAmt_, tok_);
        if (pending_ > 0) {
            assertGe(IERC20(d).balanceOf(info.bondNftVault()), nftBefore_, "D31-3 realized or held");
        }
    }

    function _assert_D31_4_openMintDoesNotExpand(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Open));
        if (!info.isReserveLive()) _firstBondOn(d, FIRST_BOND_AMT);
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * 40);
        uint256 pending_ = info.pendingExpansionDetf();
        assertEq(pending_, 0, "D31-4 Open pending");
        _mintOn(d, LIVE_MINT_AMT);
        assertEq(info.pendingExpansionDetf(), 0, "D31-4 Open mint no expand");
    }

    function _assert_compound_raises_protocolLp(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        if (!info.isReserveLive()) _firstBondOn(d, FIRST_BOND_AMT);
        _mintOn(d, LIVE_MINT_AMT);
        uint256 nftLpBefore_ = _nftLpOf(d);
        (uint256 detfIn_, uint256 lpOut_) = info.compoundProtocolRewards();
        detfIn_;
        if (lpOut_ > 0) {
            assertGt(_nftLpOf(d), nftLpBefore_, "Bond NFT hook-LP rises when lpOut>0");
        }
    }

    function _assert_donate_doesNotRealizeExpansion(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * 24);
        uint256 pending_ = info.pendingExpansionDetf();
        uint256 supply_ = IERC20(d).totalSupply();
        _donateMintToken(d, 6 ether);
        assertEq(IERC20(d).totalSupply(), supply_, "DN12 supply (no realize mint)");
        uint256 pendingAfter_ = info.pendingExpansionDetf();
        // Donate changes spot S so the pending *view* can move; realize would mint and consume it.
        if (pending_ > 0) {
            assertGt(pendingAfter_, 0, "DN12 pending not consumed");
        }
    }

    function _assert_T1_openingZero_storesAsCreation_firstBondGAtPeg(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        uint256[] memory creation_ = info.creationPairPerDetfWad();
        uint256[] memory opening_ = info.openingPairPerDetfWad();
        assertTrue(_openingEq(opening_, creation_), "stored opening == creation");
        assertTrue(_openingAll(creation_, DEFAULT_CREATION_PAIR_PER_DETF), "creation 1e18");
        assertFalse(info.isReserveLive(), "inert");
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(info.isReserveLive(), "live");
        uint256 g_ = _expectedJoinDetf(FIRST_BOND_AMT, DEFAULT_CREATION_PAIR_PER_DETF);
        assertApproxEqAbs(_detfReserveInHook(d), g_, 1000, "first-bond G at peg");
    }

    function _assert_T2_openingUsesG_creationViewUnchanged(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        assertTrue(_openingAll(info.creationPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF), "creation view");
        assertTrue(_openingAll(info.openingPairPerDetfWad(), LAUNCH_RICH_START), "stored opening");
        _firstBondOn(d, FIRST_BOND_AMT);
        assertTrue(info.isReserveLive());
        uint256 gOpening_ = _expectedJoinDetf(FIRST_BOND_AMT, LAUNCH_RICH_START);
        uint256 gCreation_ = _expectedJoinDetf(FIRST_BOND_AMT, DEFAULT_CREATION_PAIR_PER_DETF);
        uint256 raw_ = _detfReserveInHook(d);
        assertApproxEqAbs(raw_, gOpening_, 1000, "first-bond G uses opening");
        assertTrue(raw_ != gCreation_, "G is not creation-rate join");
        assertTrue(_openingAll(info.creationPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF), "creation unchanged");
    }

    function _assert_T5_creationZero_revertsInvalidCreationRate() internal {
        IUniswapV4Detf.PkgArgs memory args = _policyArgs();
        args = _withTag(args, string.concat("zcr", _nextTag()));
        uint256[] memory creation_ = new uint256[](args.creationPairPerDetfWad.length);
        args.creationPairPerDetfWad = creation_;
        args = _withOpening(args, LAUNCH_RICH_START);
        _expectInvalidCreationRate(args);
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args) internal virtual {
        address predicted_ = _predictDetf(args);
        _deployCpHookAt(predicted_);
        vm.etch(predicted_, "");
        args.hook = reserveHook;
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function _deployCpHookAt(address predicted_) internal {
        vm.etch(predicted_, address(pairToken).code);
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange: se,
                pairToken: address(pairToken),
                rawToken: predicted_,
                ownerOnlyLiquidity: true,
                owner: predicted_
            });
        uint256 mineNonce = CpHookFactory.findMineNonce(hookFactory, hookPkg, hArgs);
        reserveHook = CpHookFactory.deployHook(hookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(predicted_, address(pairToken));
        require(init.finalizeInitialization(), "finalize");
    }
}
