// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {WeightedPoolFactory} from
    "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";
import {
    SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";

/// @title TestBase_SingleStandardExchangeDETF
/// @notice Deploys production SingleStandardExchangeDETF against a production SE vault.
/// @dev Default provider: Aerodrome Standard Exchange vault from Balancer SE router TestBase
///      (local production packages — no MockStandardExchange).
abstract contract TestBase_SingleStandardExchangeDETF is TestBase_BalancerV3StandardExchangeRouter {
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using SingleStandardExchangeDETF_Component_FactoryService for ICreate3FactoryProxy;
    using SingleStandardExchangeDETF_Component_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;

    IFacet internal multiAssetBasicVaultFacetDetf;
    IFacet internal multiAssetStandardVaultFacetDetf;
    IFacet internal singleStandardExchangeDetfExchangeInFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal erc721Facet;

    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IDetfSelfNftInventoryDFPkg internal bondNftVaultPkg;
    ISingleStandardExchangeDETDFPkg internal singleStandardExchangeDetfPkg;

    IStandardExchangeProxy internal seVault;
    IERC20 internal seShare;
    IERC20 internal rateTargetToken;

    address internal detf;
    ISingleStandardExchangeDETFInfo internal detfInfo;
    ISingleStandardExchangeDETFBonding internal detfBonding;
    IStandardExchangeIn internal detfExchangeIn;

    function setUp() public virtual override {
        super.setUp();

        // Production SE attachment from router base (Aerodrome dai/usdc vault).
        seVault = daiUsdcVault;
        seShare = IERC20(address(daiUsdcVault));
        rateTargetToken = IERC20(address(dai));

        multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();
        singleStandardExchangeDetfExchangeInFacet = create3Factory.deployExchangeInFacet();

        _deployRateProviderPkg();
        _deployBondNftVaultPkg();
        _deploySingleStandardExchangeDetfPkg();
        detf = _deployDetfInstance();

        detfInfo = ISingleStandardExchangeDETFInfo(detf);
        detfBonding = ISingleStandardExchangeDETFBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
    }

    function _deployRateProviderPkg() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("SingleStandardExchangeDETF_RateProviderFacet")
            )
        );
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(
                        IStandardExchangeRateProviderDFPkg.PkgInit({
                            rateProviderFacet: rateProviderFacet,
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    keccak256("SingleStandardExchangeDETF_RateProviderDFPkg")
                )
            )
        );
        vm.label(address(rateProviderPkg), "SingleStandardExchangeDETF_RateProviderDFPkg");
    }

    function _deployBondNftVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode, keccak256("SingleStandardExchangeDETF_ERC721Facet")
            )
        );

        IDETFNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721Facet,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        bondNftVaultPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployDETFNFTVaultDFPkg(nftPkgInit);
        vm.stopPrank();
        vm.label(address(bondNftVaultPkg), "SingleStandardExchangeDETF_BondNftVaultPkg");
    }

    function _deploySingleStandardExchangeDetfPkg() internal {
        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit = ISingleStandardExchangeDETDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: singleStandardExchangeDetfExchangeInFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            weightedPoolFactory: WeightedPoolFactory(testPoolFactory),
            rateProviderPkg: rateProviderPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            diamondFactory: diamondPackageFactory
        });

        vm.startPrank(owner);
        singleStandardExchangeDetfPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployPkg(pkgInit);
        vm.stopPrank();
        vm.label(address(singleStandardExchangeDetfPkg), "SingleStandardExchangeDETDFPkg");
    }

    function _deployDetfInstance() internal returns (address detf_) {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Single Standard Exchange DETF",
            symbol: "ssxDETF",
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTargetToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
        expansionClosureRatePerSecond: 0,
        expansionCatchUpMaxSeconds: 0,
        expansionCatchUpCapBps: 0
        });

        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        vm.label(detf_, "SingleStandardExchangeDETF");
    }

    /// @dev Fund `to` with production SE vault shares via deposit path.
    function _fundSeShares(address to, uint256 lpAmount) internal returns (uint256 shares_) {
        shares_ = _depositToVault(to, lpAmount);
    }

    /// @dev First-bond bootstrap: fund shares, approve, bond with default min lock.
    function _bootstrapViaFirstBond(address bonder, uint256 lpAmount)
        internal
        returns (uint256 tokenId_, uint256 shares_)
    {
        uint256 seShares_ = _fundSeShares(bonder, lpAmount);
        vm.startPrank(bonder);
        seShare.approve(detf, seShares_);
        (tokenId_, shares_) = detfBonding.bond(
            seShare, seShares_, DEFAULT_MIN_LOCK, bonder, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _assertInert() internal view {
        assertFalse(detfInfo.isReserveLive(), "expected inert (not live)");
    }

    function _assertLive() internal view {
        assertTrue(detfInfo.isReserveLive(), "expected reserve live");
        assertTrue(detfInfo.reservePool() != address(0), "reserve pool missing");
        assertTrue(detfInfo.bondNftVault() != address(0), "bond nft vault missing");
    }

    /// @dev Dual-path always-allow primary market when live (mint + burn math / adversarial suites).
    /// @dev Historical Policy mint=1 / burn=max is **illegal** under PRD §16.3 (`mint > burn`).
    ///      Always-allow is product **Open** (`_deployOpenModeDetf`). Kept name for call-site compatibility.
    function _deployOpenThresholdDetf(string memory name_, string memory symbol_)
        internal
        returns (address detf_)
    {
        return _deployOpenModeDetf(name_, symbol_);
    }

    /// @dev Product Open mode: threshold gates always pass when live; live/inert still enforced.
    ///      Thresholds still resolve/store (defaults for 0,0); gates ignore them.
    function _deployOpenModeDetf(string memory name_, string memory symbol_)
        internal
        returns (address detf_)
    {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTargetToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Open,
        expansionClosureRatePerSecond: 0,
        expansionCatchUpMaxSeconds: 0,
        expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        vm.label(detf_, name_);
    }

    /// @dev Legal extreme Policy pair (mint > burn) for T4b/T18 — mode remains Policy.
    ///      Not both-always-open (impossible under mint>burn + Policy deadband); use Open for that.
    function _deployExtremePolicyPairDetf(string memory name_, string memory symbol_)
        internal
        returns (address detf_)
    {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTargetToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 2,
            burnThreshold: 1,
            thresholdMode: ThresholdMode.Policy,
        expansionClosureRatePerSecond: 0,
        expansionCatchUpMaxSeconds: 0,
        expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        vm.label(detf_, name_);
    }

    /// @dev Policy mode with explicit custom mint/burn band (already resolved; non-zero).
    function _deployPolicyThresholds(uint256 mintThreshold_, uint256 burnThreshold_)
        internal
        returns (address detf_)
    {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Policy Custom Band DETF",
            symbol: "pcDETF",
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTargetToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: mintThreshold_,
            burnThreshold: burnThreshold_,
            thresholdMode: ThresholdMode.Policy,
        expansionClosureRatePerSecond: 0,
        expansionCatchUpMaxSeconds: 0,
        expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        vm.label(detf_, "PolicyCustomBandDETF");
    }

    function _bootstrapDetf(address instance_, address bonder, uint256 lpAmount)
        internal
        returns (uint256 tokenId_)
    {
        uint256 seShares_ = _fundSeShares(bonder, lpAmount);
        vm.startPrank(bonder);
        seShare.approve(instance_, seShares_);
        (tokenId_,) = ISingleStandardExchangeDETFBonding(instance_).bond(
            seShare, seShares_, DEFAULT_MIN_LOCK, bonder, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @dev Free inventory of role tokens on the DETF diamond must be zero after success paths.
    ///      BPT held on the diamond is intentional reserve principal.
    function _assertNoFreeInventory(address instance_) internal view {
        assertEq(seShare.balanceOf(instance_), 0, "residual se vault shares");
        assertEq(IERC20(instance_).balanceOf(instance_), 0, "residual free detf");
        assertEq(IERC20(address(dai)).balanceOf(instance_), 0, "residual dai");
        assertEq(IERC20(address(usdc)).balanceOf(instance_), 0, "residual usdc");
    }

    /* ---------------------------------------------------------------------- */
    /*                     Protocol compound test helpers                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Enable non-zero seigniorage so mint/bond produce inventory DETF on the bond vault.
    function _enableSeigniorageIncentive(address instance_, uint256 incentiveWad_) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(
            instance_, incentiveWad_
        );
        vm.stopPrank();
    }

    function _bondNftVault(address instance_) internal view returns (IDETFNFTVault) {
        return IDETFNFTVault(ISingleStandardExchangeDETFInfo(instance_).bondNftVault());
    }

    function _detfNftId(address instance_) internal view returns (uint256) {
        return _bondNftVault(instance_).detfNFTId();
    }

    /// @dev Protocol NFT principal (BPT share units) — claim rate path depends on this rising after compound.
    function _protocolNftPrincipal(address instance_) internal view returns (uint256) {
        IDETFNFTVault vault_ = _bondNftVault(instance_);
        return vault_.originalSharesOf(vault_.detfNFTId());
    }

    function _protocolPendingRewards(address instance_) internal view returns (uint256) {
        IDETFNFTVault vault_ = _bondNftVault(instance_);
        return vault_.pendingRewards(vault_.detfNFTId());
    }

    function _feeTo() internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    /// @dev Bootstrap open-mode DETF, sell first bond into protocol NFT so it has principal shares,
    ///      then seed inventory DETF rewards via a second mint (seigniorage on).
    /// @return instance_ Open-mode DETF diamond.
    /// @return userBondId_ Second user bond still locked (for C3 claim-while-locked).
    function _setupProtocolRewardsLive(address bonder_, address minter_)
        internal
        returns (address instance_, uint256 userBondId_)
    {
        instance_ = _deployOpenModeDetf("Protocol Compound DETF", "pcDETF");
        // 20% seigniorage incentive → inventory = afterFee * 10% (half of incentive).
        _enableSeigniorageIncentive(instance_, 0.20e18);

        // First bond → live; sell to protocol so detf NFT earns reward share.
        // Keep sizes modest vs pool to avoid Balancer MaxInRatio on subsequent joins.
        uint256 firstId_ = _bootstrapDetf(instance_, bonder_, 1_000e18);
        vm.prank(bonder_);
        ISingleStandardExchangeDETFBonding(instance_).sellPositionToDetfNft(firstId_, bonder_);
        assertGt(_protocolNftPrincipal(instance_), 0, "protocol nft has principal after sell");

        // Second bond: user keeps NFT (for claim-while-locked) and more inventory accrues.
        userBondId_ = _bootstrapDetf(instance_, bonder_, 200e18);

        // Mint seigniorage with inventory DETF into bond vault reward pool.
        uint256 seShares_ = _fundSeShares(minter_, 50e18);
        vm.startPrank(minter_);
        seShare.approve(instance_, seShares_);
        IStandardExchangeIn(instance_).exchangeIn(
            seShare, seShares_, IERC20(instance_), 0, minter_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @dev Seed extra free DETF inventory on the bond vault (forces reward balance without another mint).
    ///      **Adds** to existing vault balance (does not set absolute) so `lastRewardTokenBalance`
    ///      accounting stays consistent with inventory already deposited via production mint/bond.
    function _seedBondVaultRewardDetf(address instance_, uint256 amount_) internal {
        address vault_ = address(_bondNftVault(instance_));
        uint256 before_ = IERC20(instance_).balanceOf(vault_);
        // Non-SUT controllability: forge deal adjusts ERC20 balance + totalSupply.
        deal(instance_, vault_, before_ + amount_, true);
    }

    /* ---------------------------------------------------------------------- */
    /*                  Natural expansion / price-shift helpers               */
    /* ---------------------------------------------------------------------- */

    /// @dev Warp wall-clock for expansion accrual (Foundry cheatcode).
    function _warp(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    /// @dev Real trade on underlying Aerodrome DAI/USDC pool (moves SE share rate provider).
    /// @param buyUsdc_ True = DAI→USDC (skew); false = USDC→DAI.
    function _shiftUnderlyingPrice(bool buyUsdc_, uint256 amountIn_) internal {
        address trader_ = bob;
        address tokenIn_ = buyUsdc_ ? address(dai) : address(usdc);
        address tokenOut_ = buyUsdc_ ? address(usdc) : address(dai);
        if (buyUsdc_) {
            dai.mint(trader_, amountIn_);
        } else {
            usdc.mint(trader_, amountIn_);
        }
        IRouter.Route[] memory routes_ = new IRouter.Route[](1);
        routes_[0] = IRouter.Route({
            from: tokenIn_,
            to: tokenOut_,
            stable: false,
            factory: address(aerodromePoolFactory)
        });
        vm.startPrank(trader_);
        IERC20(tokenIn_).approve(address(aerodromeRouter), amountIn_);
        aerodromeRouter.swapExactTokensForTokens(amountIn_, 0, routes_, trader_, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /// @dev External single-sided vault-share join into the DETF reserve (production Balancer path).
    ///      Increases share leg relative to DETF self-leg → synthetic rises without minting free DETF.
    /// @param lpAmount_ Underlying aero LP amount used to mint SE vault shares for the join.
    function _joinReserveSharesExternal(address instance_, address joiner_, uint256 lpAmount_)
        internal
        returns (uint256 bptOut_)
    {
        address pool_ = ISingleStandardExchangeDETFInfo(instance_).reservePool();
        IVault bal_ = IVault(address(vault));
        uint256 n_ = bal_.getCurrentLiveBalances(pool_).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        (IERC20[] memory tokens_,,,) = bal_.getPoolTokenInfo(pool_);
        uint256 shareIdx_ = address(tokens_[0]) == address(seShare) ? 0 : 1;

        uint256 shares_ = _fundSeShares(joiner_, lpAmount_);
        require(shares_ > 0, "funded se shares");
        amountsIn_[shareIdx_] = shares_;

        vm.startPrank(joiner_);
        seShare.transfer(address(bal_), shares_);
        bptOut_ = IBalancerV3StandardExchangeRouterProxy(address(seRouter)).prepayAddLiquidityUnbalanced(
            pool_, amountsIn_, 0, ""
        );
        vm.stopPrank();
    }

    /// @dev Drive synthetic above mint threshold under **default Policy** via production paths:
    ///      (1) burn free DETF when burn-allowed (reduces supply), (2) real underlying aero trades
    ///      (moves SE rate), (3) modest external share joins. Not Open / extreme-threshold deploys.
    function _pushSyntheticAboveMintThreshold(address instance_) internal {
        ISingleStandardExchangeDETFInfo info_ = ISingleStandardExchangeDETFInfo(instance_);
        require(info_.isReserveLive(), "must be live");
        if (info_.isMintingAllowed()) return;

        // Phase A: burn free DETF while burn-allowed (synthetic low after seigniorage dilution).
        address[] memory holders_ = new address[](3);
        holders_[0] = alice;
        holders_[1] = bob;
        holders_[2] = _feeTo();
        for (uint256 round_; round_ < 8 && !info_.isMintingAllowed() && info_.isBurningAllowed(); ++round_) {
            bool burned_;
            for (uint256 h; h < holders_.length; ++h) {
                address who_ = holders_[h];
                uint256 bal_ = IERC20(instance_).balanceOf(who_);
                if (bal_ == 0) continue;
                // Cap burn size to avoid Balancer MaxInRatio on reserve exit.
                uint256 burnAmt_ = bal_ / 10;
                if (burnAmt_ > 20e18) burnAmt_ = 20e18;
                if (burnAmt_ == 0) burnAmt_ = bal_ > 1e18 ? 1e18 : bal_;
                if (burnAmt_ == 0) continue;
                vm.startPrank(who_);
                IERC20(instance_).approve(instance_, burnAmt_);
                try IStandardExchangeIn(instance_).exchangeIn(
                    IERC20(instance_),
                    burnAmt_,
                    seShare,
                    0,
                    who_,
                    false,
                    block.timestamp + 1 hours
                ) {
                    burned_ = true;
                } catch {}
                vm.stopPrank();
                if (info_.isMintingAllowed()) return;
                if (!info_.isBurningAllowed()) break;
            }
            if (!burned_) break;
        }
        if (info_.isMintingAllowed()) return;

        // Phase B: underlying rate skew + small share joins (avoid MaxInRatio).
        for (uint256 i; i < 20 && !info_.isMintingAllowed(); ++i) {
            _shiftUnderlyingPrice(true, 20_000e18 * (i + 1));
            if (info_.isMintingAllowed()) return;
            _shiftUnderlyingPrice(false, 20_000e18 * (i + 1));
            if (info_.isMintingAllowed()) return;
            // Modest LP amounts — large unbalanced joins hit Balancer MaxInRatio.
            try this.joinReserveSharesExternalExternal(instance_, bob, 50e18 * (i + 1)) {} catch {}
        }
        require(info_.isMintingAllowed(), "could not open mint under default thresholds");
    }

    /// @dev External wrapper so try/catch can absorb MaxInRatio on share joins.
    function joinReserveSharesExternalExternal(address instance_, address joiner_, uint256 lpAmount_)
        external
        returns (uint256)
    {
        return _joinReserveSharesExternal(instance_, joiner_, lpAmount_);
    }

    /// @dev Deploy uniquely named Policy instance (CREATE3 salt includes args).
    function _deployPolicyNamed(string memory name_, string memory symbol_) internal returns (address detf_) {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTargetToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
            expansionClosureRatePerSecond: 0,
            expansionCatchUpMaxSeconds: 0,
            expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleStandardExchangeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
        vm.label(detf_, name_);
    }

    /// @dev Live Policy DETF with at least one locked user bond + protocol NFT principal (for expansion/compound).
    /// @dev Does **not** push synthetic here (caller runs `_pushSyntheticAboveMintThreshold` when needed).
    function _setupPolicyExpansionLive(address bonder_, address helper_)
        internal
        returns (address instance_, uint256 userBondId_)
    {
        instance_ = _deployPolicyNamed("Natural Expansion DETF", "neDETF");
        // Modest seigniorage so protocol NFT can accrue after sell/mint.
        _enableSeigniorageIncentive(instance_, 0.20e18);

        // Keep sizes modest vs pool to avoid Balancer MaxInRatio (same as protocol compound setup).
        uint256 firstId_ = _bootstrapDetf(instance_, bonder_, 1_000e18);
        vm.prank(bonder_);
        ISingleStandardExchangeDETFBonding(instance_).sellPositionToDetfNft(firstId_, bonder_);

        userBondId_ = _bootstrapDetf(instance_, bonder_, 200e18);
        assertGt(
            _bondNftVault(instance_).effectiveSharesOf(userBondId_),
            0,
            "user bond has effective shares"
        );

        // Seed expansion clock at live (first bond already set it); public touch is safe at dt≈0.
        ISingleStandardExchangeDETFInfo(instance_).compoundProtocolRewards();

        helper_; // reserved for multi-actor suites
    }

    /// @dev Expected max expansion mint under resolved defaults for given supply (bps cap).
    function _maxExpansionMintDefault(uint256 totalSupply_) internal pure returns (uint256) {
        return (totalSupply_ * DETFNaturalExpansionLib.DEFAULT_CATCH_UP_CAP_BPS) / 10_000;
    }
}
