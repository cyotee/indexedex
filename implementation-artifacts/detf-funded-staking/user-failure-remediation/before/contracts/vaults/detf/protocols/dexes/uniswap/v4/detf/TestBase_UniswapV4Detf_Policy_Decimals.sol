// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {V4FundedPolicyAssertions} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";


import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
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
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {TestBase_UniswapV4Detf_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol";

/**
 * @title TestBase_UniswapV4Detf_Policy_Decimals
 * @notice Policy / opening helpers for unified Uni V4 DETF. Does not edit TestBase_UniswapV4Detf_Decimals.
 * @dev PRD UNIFIED_DETF_DEPRECATION_TEST_COVERAGE §5.1 / §7.2.
 *      Launch-rich opening starts at 1.1e18, +0.05e18 per step, max 24 (cap 2.25e18).
 *      Recorded mint-open WAD on gold CP: 2.20e18 (synthetic ~1.073e18).
 *      Do not prank(detf) to LP the hook before first bond.
 */
abstract contract TestBase_UniswapV4Detf_Policy_Decimals is TestBase_UniswapV4Detf_Decimals, V4FundedPolicyAssertions {
    uint256 internal constant POLICY_MINT_THRESHOLD = 1.05e18;
    uint256 internal constant POLICY_BURN_THRESHOLD = 0.95e18;
    uint256 internal constant POLICY_EXPANSION_EPOCH = 8 hours;
    uint256 internal constant POLICY_EXPANSION_RATE = 0.05e18;
    uint256 internal constant POLICY_EXPANSION_CATCHUP = 4;
    uint256 internal constant FEE_P = 5e16;
    uint256 internal constant FEE_F = 12e16;
    uint256 internal constant FEE_C = 28e16;
    uint256 internal constant LAUNCH_RICH_START = 1.1e18;
    uint256 internal constant LAUNCH_RICH_STEP = 0.05e18;
    uint256 internal constant LAUNCH_RICH_MAX_STEPS = 24;
    function _firstBondAmt() internal view returns (uint256) { return _uPair(100); }
    function _liveMintAmt() internal view returns (uint256) { return _uPair(10); }
    uint256 internal constant ONE_WAD = 1e18;

    address internal policyCreator;
    address internal policyDetf;
    IUniswapV4Detf internal policyInfo;
    IERC20 internal policyMintToken;
    uint256 internal launchRichOpeningWad;
    uint256 internal _policyDeployNonce;
    mapping(address => uint256) internal _policyInitialBond;

    function setUp() public virtual override {
        super.setUp();
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
        args.expansionClosureRatePerYearWad = 0;
        args.creator = policyCreator;
    }

    /// @notice Annual 5% closure with fixed eight-hour epochs and uncapped aggregate catch-up.
    function _policyD31Args() internal virtual returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _policyArgs();
        args.name = "UniV4 DETF D31";
        args.symbol = "uv4D31";
        args.expansionClosureRatePerYearWad = POLICY_EXPANSION_RATE;
    }

    /// @notice Mandatory-gated at-peg fixture; zero rate argument retains the existing default.
    function _openArgsPolicy() internal virtual returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _baseArgs();
        args.name = "UniV4 DETF OpenPL";
        args.symbol = "uv4Opl";
        args.expansionClosureRatePerYearWad = 0;
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
            if (toks_[i] == address(pairToken)) return IERC20(toks_[i]);
        }
        for (uint256 j; j < toks_.length; ++j) {
            if (toks_[j] != d) return IERC20(toks_[j]);
        }
        revert("no mintToken");
    }

    function _fundToken(address token_, address to_, uint256 amount_) internal virtual {
        IERC20 tok_ = IERC20(token_);
        if (tok_.balanceOf(to_) >= amount_) return;
        try MintableERC20Decimals(token_).mint(to_, amount_) {
            if (tok_.balanceOf(to_) >= amount_) return;
        } catch {}
        uint256 have_ = tok_.balanceOf(to_);
        deal(token_, to_, have_ + amount_, true);
        if (tok_.balanceOf(to_) >= amount_) return;
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
        if (tok_.balanceOf(to_) < amount_) {
            _fundBondLegFallback(token_, to_, amount_);
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
            _fundToken(toks_[i], detfUser, _tokenHumanAmt(toks_[i], 400));
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
        _syncPairDecimals();
        _setFeeOraclePfc(d);
        _setBondTermsOn(d);
        _fundAndApprove(d);
    }

    function _firstBondOn(address d, uint256 amt) internal returns (uint256 tokenId, uint256 shares) {
        IERC20 token_ = _mintTokenOf(d);
        bool first_ = !IUniswapV4Detf(d).isReserveLive();
        if (first_) {
            (address[] memory tokens_, uint256[] memory amounts_) =
                IUniswapV4Detf(d).previewFirstBondPayments(token_, amt);
            for (uint256 i_; i_ < tokens_.length; ++i_) {
                _fundToken(tokens_[i_], detfUser, amounts_[i_]);
                vm.prank(detfUser);
                IERC20(tokens_[i_]).approve(d, amounts_[i_]);
            }
        } else {
            _fundToken(address(token_), detfUser, amt);
            vm.prank(detfUser);
            token_.approve(d, amt);
        }
        vm.prank(detfUser);
        (tokenId, shares) = IUniswapV4Detf(d).bond(token_, amt, DEFAULT_MIN_LOCK, detfUser, false, _deadline());
        if (first_) _policyInitialBond[d] = tokenId;
    }

    function _mintOn(address d, uint256 amt) internal returns (uint256 userDetf) {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        IERC20 tok_ = _mintTokenOf(d);
        if (info.isReserveLive() && info.isMintingAllowed() && !info.isMintingAllowed(tok_)) {
            IUniswapV4Detf.IoRoute[] memory rows_ = info.mintRoutes();
            for (uint256 i; i < rows_.length; ++i) {
                if (info.isMintingAllowed(rows_[i].token)) {
                    tok_ = rows_[i].token;
                    amt = _tokenHumanAmt(address(tok_), 10);
                    break;
                }
            }
        }
        address hook_ = info.hook();
        address[] memory toks_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint8 md_ = 18;
        try MintableERC20Decimals(address(tok_)).decimals() returns (uint8 got_) {
            md_ = got_;
        } catch {}
        uint256 human_ = md_ == 0 ? amt : amt / (10 ** uint256(md_));
        if (human_ == 0) human_ = 1;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == d) continue;
            _fundToken(toks_[i], detfUser, _tokenHumanAmt(toks_[i], human_) * 4);
        }
        vm.startPrank(detfUser);
        tok_.approve(d, type(uint256).max);
        userDetf = IStandardExchangeIn(address(info)).exchangeIn(tok_, amt, IERC20(address(info)), 0, detfUser, false, _deadline());
        vm.stopPrank();
    }

    function _burnOn(address d, uint256 detfIn, IERC20 tokenOut) internal virtual returns (uint256 amountOut) {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        if (!info.isBurningAllowed(tokenOut)) {
            IUniswapV4Detf.IoRoute[] memory rows_ = info.burnRoutes();
            for (uint256 i; i < rows_.length; ++i) {
                if (info.isBurningAllowed(rows_[i].token)) {
                    tokenOut = rows_[i].token;
                    break;
                }
            }
        }
        vm.startPrank(detfUser);
        IERC20(d).approve(d, type(uint256).max);
        amountOut = IStandardExchangeIn(address(info)).exchangeIn(IERC20(address(info)), detfIn, tokenOut, 0, detfUser, false, _deadline());
        vm.stopPrank();
    }

    /// @dev DETF share is always 18. Pair legs use the token's own decimals.
    function _tokenHumanAmt(address token_, uint256 human_) internal view returns (uint256) {
        uint8 d_ = 18;
        try MintableERC20Decimals(token_).decimals() returns (uint8 got_) {
            d_ = got_;
        } catch {}
        return human_ * (10 ** uint256(d_));
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
        // This price already opens the primary gate in the gold fixtures.
        // Keep all original candidates as a fallback for distinct provider bindings.
        for (uint256 i; i <= LAUNCH_RICH_MAX_STEPS; ++i) {
            wad = LAUNCH_RICH_START + i * LAUNCH_RICH_STEP;
            if (d31_) wad = i == 0 ? 2.2e18 : LAUNCH_RICH_START + (i - 1) * LAUNCH_RICH_STEP;
            IUniswapV4Detf.PkgArgs memory args = d31_ ? _policyD31Args() : _policyArgs();
            args = _withOpening(_withTag(args, string.concat("lr", vm.toString(i), _nextTag())), wad);
            d = _deployInstance(args);
            _bindPolicy(d);
            _firstBondOn(d, _firstBondAmt());
            info = IUniswapV4Detf(d);
            assertTrue(info.isReserveLive(), "first bond live");
            emit log_named_uint("launchRichOpeningWad", wad);
            emit log_named_uint("syntheticAfterFirstBond", info.syntheticPrice());
            if (info.isMintingAllowed()) {
                launchRichOpeningWad = wad;
                return d;
            }
        }
        launchRichOpeningWad = wad;
        revert("6.1 launch-rich isMintingAllowed still false after 24 steps");
    }

    function _deployOpenLive() internal returns (address d) {
        // A configured 1:1 opening is not necessarily a no-premium reserve
        // valuation (notably for Orbital). Set an explicit below-peg launch;
        // the shared no-expansion assertion still checks the actual price.
        d = _deployTagged(_withOpening(_openArgsPolicy(), 0.5e18), _nextTag());
        _firstBondOn(d, _firstBondAmt());
        assertTrue(IUniswapV4Detf(d).isReserveLive(), "open live");
        return d;
    }

    function _deployPolicyAtPegLive() internal returns (address d) {
        d = _deployTagged(_policyArgs(), _nextTag());
        _firstBondOn(d, _firstBondAmt());
        assertTrue(IUniswapV4Detf(d).isReserveLive(), "policy peg live");
        return d;
    }

    function _expectedJoinDetf(uint256 pairAmount_, uint256 opening_) internal view returns (uint256) {
        return _pairInToJoinWad(pairAmount_) * 1e9 / opening_;
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



    function _pushSyntheticUp(address d) internal virtual {
        _policyBuyFromReserve(d);
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

    /// @dev Sell actually purchased DETF through public reserve swaps; never fabricate DETF balances.
    function _skewSyntheticDown(address d) internal virtual {
        _skewSyntheticDownAmt(d, 80e9);
    }

    function _skewSyntheticDownAmt(address d, uint256 detfAmt) internal {
        // Claim the funded opening purchase once, even when an ordinary mint
        // already supplied a small raw balance. Never retry a consumed NFT.
        if (_policyInitialBond[d] >= 3) {
            _ensureFreeDetf(d, IERC20(d).balanceOf(detfUser) + 1);
        }
        uint256 available_ = IERC20(d).balanceOf(detfUser) / 2;
        uint256 amount_ = detfAmt < available_ ? detfAmt : available_;
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256 chunk_ = amount_ / (tokens_.length - 1);
        vm.startPrank(detfUser);
        IERC20(d).approve(hook_, amount_);
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] == d) continue;
            IStandardExchangeIn(hook_).exchangeIn(
                IERC20(d), chunk_, IERC20(tokens_[i_]), 0, detfUser, false, _deadline()
            );
        }
        vm.stopPrank();
    }

    function _ensureFreeDetf(address d, uint256 amt) internal {
        if (IERC20(d).balanceOf(detfUser) >= amt) return;
        uint256 id_ = _policyInitialBond[d];
        assertGe(id_, 3, "funded initial bond available");
        IDetfBondNFT nft_ = IDetfBondNFT(IUniswapV4Detf(d).bondNftVault());
        DETFFundedStakingMath.BondPosition memory position_ = nft_.positionOf(id_);
        uint256 unlock_ = position_.startTimestamp + position_.vestingDuration;
        if (block.timestamp < unlock_) vm.warp(unlock_);
        vm.prank(detfUser);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, detfUser);
        delete _policyInitialBond[d];
        IStakedDETF staking_ = IStakedDETF(IUniswapV4Detf(d).rebasingClaimToken());
        uint256 amount_ = principal_ + rewards_;
        vm.prank(detfUser);
        staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(d), amount_, detfUser, false, _deadline());
        assertGe(IERC20(d).balanceOf(detfUser), amt, "only actually purchased DETF can fund fixture");
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

    function _assert_T1_openingZero_storesAsCreation_firstBondGAtPeg(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        uint256[] memory creation_ = info.creationPairPerDetfWad();
        uint256[] memory opening_ = info.openingPairPerDetfWad();
        assertTrue(_openingEq(opening_, creation_), "stored opening == creation");
        assertTrue(_openingAll(creation_, DEFAULT_CREATION_PAIR_PER_DETF), "creation 1e18");
        assertFalse(info.isReserveLive(), "inert");
        _firstBondOn(d, _firstBondAmt());
        assertTrue(info.isReserveLive(), "live");
        uint256 g_ = _expectedJoinDetf(_firstBondAmt(), DEFAULT_CREATION_PAIR_PER_DETF);
        assertApproxEqAbs(_detfReserveInHook(d), g_, 1000, "first-bond G at peg");
    }

    function _assert_T2_openingUsesG_creationViewUnchanged(address d) internal {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        assertTrue(_openingAll(info.creationPairPerDetfWad(), DEFAULT_CREATION_PAIR_PER_DETF), "creation view");
        assertTrue(_openingAll(info.openingPairPerDetfWad(), LAUNCH_RICH_START), "stored opening");
        _firstBondOn(d, _firstBondAmt());
        assertTrue(info.isReserveLive());
        uint256 gOpening_ = _expectedJoinDetf(_firstBondAmt(), LAUNCH_RICH_START);
        uint256 gCreation_ = _expectedJoinDetf(_firstBondAmt(), DEFAULT_CREATION_PAIR_PER_DETF);
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
        _deployCpHookAt(predicted_, args.ownerOnlyLiquidity);
        args.hook = reserveHook;
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }

    function _deployCpHookAt(address predicted_, bool ownerOnlyLiquidity_) internal {
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange: se,
                pairToken: address(pairToken),
                rawToken: predicted_,
                pairTokenDecimals: HookPkgArgsDecimalsLib.tokenDec(address(pairToken)),
                rawTokenDecimals: predicted_.code.length == 0 ? uint8(9) : HookPkgArgsDecimalsLib.tokenDec(predicted_),
                ownerOnlyLiquidity: ownerOnlyLiquidity_,
                owner: predicted_
            });
        uint256 mineNonce = CpHookFactory.findMineNonce(hookFactory, hookPkg, hArgs);
        reserveHook = CpHookFactory.deployHook(hookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(predicted_, address(pairToken));
        require(init.finalizeInitialization(), "finalize");
    }
    function _fundedPolicyUser() internal view override returns (address) { return detfUser; }
    function _fundedPolicyMintToken(address d) internal view override returns (IERC20) { return _mintTokenOf(d); }
    function _fundedPolicyFundToken(address token, address user, uint256 amount) internal override { _fundToken(token, user, amount); }
    function _fundedPolicySkewDown(address d) internal override { _skewSyntheticDown(d); }
    function _fundedPolicyPushUp(address d) internal override { _pushSyntheticUp(d); }
    function _fundedPolicyEnsureRaw(address d, uint256 amount) internal override { _ensureFreeDetf(d, amount); }
    function _fundedPolicyBond(address d, uint256 amount) internal override { _firstBondOn(d, amount); }
    function _fundedPolicyDonate(address d, uint256 amount) internal override { _donateMintToken(d, amount); }
    function _fundedPolicyLock() internal pure override returns (uint256) { return DEFAULT_MIN_LOCK; }
}
