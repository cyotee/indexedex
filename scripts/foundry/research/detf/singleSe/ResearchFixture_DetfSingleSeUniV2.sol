// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                 Balancer V3                                */
/* -------------------------------------------------------------------------- */

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {
    WeightedPoolFactory
} from "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {SenderGuardFacet} from "@crane/contracts/protocols/dexes/balancer/v3/vault/SenderGuardFacet.sol";

/* -------------------------------------------------------------------------- */
/*                                   Crane                                    */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    IBalancerV3StandardExchangeRouterDFPkg
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";
import {
    BalancerV3StandardExchangeRouter_FactoryService
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
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
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {
    ResearchFixture_UniswapV2SeRateMatrix
} from "scripts/foundry/research/uniswapV2Se/ResearchFixture_UniswapV2SeRateMatrix.sol";
import {
    TestBase_BalancerV3Vault
} from "@crane/contracts/protocols/dexes/balancer/v3/test/bases/TestBase_BalancerV3Vault.sol";
import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {ResearchTelemetry} from "scripts/foundry/research/harness/ResearchTelemetry.sol";

/**
 * @title ResearchFixture_DetfSingleSeUniV2
 * @notice Hermetic research world: Uni V2 WETH/USDC SE + Single Standard Exchange DETF.
 * @dev Call `bootstrapDetfResearch()` on a *deployed* fixture instance.
 */
contract ResearchFixture_DetfSingleSeUniV2 is ResearchFixture_UniswapV2SeRateMatrix {
    using BetterEfficientHashLib for bytes;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using BalancerV3StandardExchangeRouter_FactoryService for *;
    using SingleStandardExchangeDETF_Component_FactoryService for ICreate3FactoryProxy;
    using SingleStandardExchangeDETF_Component_FactoryService for IVaultRegistryDeployment;

    uint256 public constant DEFAULT_MIN_LOCK = 30 days;
    uint256 public constant RESEARCH_WARP = 30 days;

    IFacet internal senderGuardFacet;
    IFacet internal exactInQueryFacet;
    IFacet internal exactInSwapFacet;
    IFacet internal exactOutQueryFacet;
    IFacet internal exactOutSwapFacet;
    IFacet internal batchExactInFacet;
    IFacet internal batchExactOutFacet;
    IFacet internal prepayFacet;
    IFacet internal prepayHooksFacet;
    IFacet internal permit2WitnessFacet;

    IBalancerV3StandardExchangeRouterDFPkg internal seRouterDFPkg;
    IBalancerV3StandardExchangeRouterProxy public seRouter;
    address public weightedPoolFactory;

    IFacet internal multiAssetBasicVaultFacetDetf;
    IFacet internal multiAssetStandardVaultFacetDetf;
    IFacet internal singleStandardExchangeDetfExchangeInFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal erc721Facet;
    IFacet internal erc4626BasicVaultFacet;
    IFacet internal erc4626StandardVaultFacet;

    IStandardExchangeRateProviderDFPkg public detfRateProviderPkg;
    IDetfSelfNftInventoryDFPkg public bondNftVaultPkg;
    IRebasingClaimTokenDFPkg public rebasingClaimTokenPkg;
    ISingleStandardExchangeDETDFPkg public singleStandardExchangeDetfPkg;

    address public detf;
    ISingleStandardExchangeDETFInfo public detfInfo;
    ISingleStandardExchangeDETFBonding public detfBonding;
    IStandardExchangeIn public detfExchangeIn;

    IERC20 public rateTarget;
    IERC20 public seShare;
    address public researchUser;
    address public researchUser2;

    /// @dev Optional telemetry fields set by mint/burn helpers for sample lines.
    uint256 public lastPreviewOut;
    uint256 public lastExecOut;
    uint256 public lastUserBondId;
    string public lastActorLabel;

    /// @dev BaseTest `lp` is internal; expose for research scripts.
    function liquidityProvider() public view returns (address) {
        return lp;
    }

    function researchOwner() public view returns (address) {
        return owner;
    }

    function bondNftVault() public view returns (IDETFNFTVault) {
        require(address(detfInfo) != address(0), "no detf");
        return IDETFNFTVault(detfInfo.bondNftVault());
    }

    function protocolNftId() public view returns (uint256) {
        return bondNftVault().detfNFTId();
    }

    /// @dev Protocol NFT principal BPT share units (claim-rate proxy).
    function protocolBptBalance() public view returns (uint256) {
        IDETFNFTVault v_ = bondNftVault();
        return v_.originalSharesOf(v_.detfNFTId());
    }

    function protocolPendingRewards() public view returns (uint256) {
        IDETFNFTVault v_ = bondNftVault();
        return v_.pendingRewards(v_.detfNFTId());
    }

    function pendingRewardsOf(uint256 tokenId_) public view returns (uint256) {
        return bondNftVault().pendingRewards(tokenId_);
    }

    /**
     * @notice Bootstrap Uni V2 SE + DETF packages (no Balancer SE rate matrix).
     */
    function bootstrapDetfResearch() public {
        TestBase_BalancerV3Vault.setUp();
        IndexedexTest.setUp();
        bv3Vault = IVault(address(vault));
        tokenWeth = IERC20(address(weth));
        tokenUsdc = IERC20(address(usdc));
        researchUser = users.length > 0 ? users[0] : makeAddr("detfResearchUser");
        researchUser2 = users.length > 1 ? users[1] : makeAddr("detfResearchUser2");

        _deployUniV2AndSeVault();
        seShare = shares;
        rateTarget = tokenWeth;

        _deploySeRouterAndWeightedFactory();
        _deployDetfInfrastructure();
    }

    function deployPolicyDetf(string memory name_, string memory symbol_) public returns (address detf_) {
        detf_ = _deployDetf(name_, symbol_, ThresholdMode.Policy);
        _bindDetf(detf_);
    }

    function deployOpenDetf(string memory name_, string memory symbol_) public returns (address detf_) {
        detf_ = _deployDetf(name_, symbol_, ThresholdMode.Open);
        _bindDetf(detf_);
    }

    function initTelemetry(string memory runId_) public {
        runPaths = ResearchTelemetry.initRun("detf/singleSe", runId_);
        step = 0;
        telemetryReady = true;
        ResearchTelemetry.writeMeta(
            runPaths,
            string.concat(
                '{"campaign":"detf/singleSe","phase":"3","runId":"',
                runId_,
                '","seAttachment":"uniswapV2","product":"detf/singleSe"}'
            )
        );
    }

    function sampleDetf(string memory tag_) public {
        require(telemetryReady, "telemetry not ready");
        ResearchTelemetry.appendLine(runPaths, _sampleJson(tag_));
        unchecked {
            ++step;
        }
    }

    /// @dev Transfer Uni LP from `lp` actor and deposit into SE vault for `to_`.
    function fundSeShares(address to_, uint256 lpAmount_) public returns (uint256 sharesOut_) {
        uint256 lpBal = IERC20(address(uniV2Pair)).balanceOf(lp);
        require(lpBal >= lpAmount_, "insufficient free LP on lp actor");
        // After uni-only bootstrap, all LP still sits on `lp` (no half deposit).
        vm.startPrank(lp);
        IERC20(address(uniV2Pair)).transfer(to_, lpAmount_);
        vm.stopPrank();

        vm.startPrank(to_);
        IERC20(address(uniV2Pair)).approve(address(seVault), lpAmount_);
        (bool ok, bytes memory ret) =
            address(seVault).call(abi.encodeWithSignature("deposit(uint256,address)", lpAmount_, to_));
        require(ok, "se deposit failed");
        sharesOut_ = abi.decode(ret, (uint256));
        vm.stopPrank();
    }

    function firstBond(address bonder_, uint256 seSharesIn_)
        public
        returns (uint256 tokenId_, uint256 sharesUsed_)
    {
        vm.startPrank(bonder_);
        seShare.approve(detf, seSharesIn_);
        (tokenId_, sharesUsed_) = detfBonding.bond(
            seShare, seSharesIn_, DEFAULT_MIN_LOCK, bonder_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        lastUserBondId = tokenId_;
    }

    /// @dev Fund SE shares from free Uni LP then bond (common D1+ path).
    function fundAndBond(address bonder_, uint256 lpAmount_)
        public
        returns (uint256 tokenId_, uint256 seShares_)
    {
        seShares_ = fundSeShares(bonder_, lpAmount_);
        (tokenId_,) = firstBond(bonder_, seShares_);
    }

    function sellBondToProtocol(address bonder_, uint256 tokenId_) public returns (uint256 principal_) {
        vm.prank(bonder_);
        principal_ = detfBonding.sellPositionToDetfNft(tokenId_, 0, bonder_);
    }

    function enableSeigniorage(uint256 incentiveWad_) public {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(
            detf, incentiveWad_
        );
        vm.stopPrank();
    }

    function previewMint(uint256 seSharesIn_) public view returns (uint256) {
        return detfExchangeIn.previewExchangeIn(seShare, seSharesIn_, IERC20(detf));
    }

    function mintSeSharesForDetf(address user_, uint256 seSharesIn_) public returns (uint256 detfOut_) {
        lastPreviewOut = previewMint(seSharesIn_);
        vm.startPrank(user_);
        seShare.approve(detf, seSharesIn_);
        detfOut_ = detfExchangeIn.exchangeIn(
            seShare, seSharesIn_, IERC20(detf), 0, user_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        lastExecOut = detfOut_;
    }

    function previewBurn(uint256 detfIn_) public view returns (uint256) {
        return detfExchangeIn.previewExchangeIn(IERC20(detf), detfIn_, seShare);
    }

    function burnDetfForSeShares(address user_, uint256 detfIn_) public returns (uint256 seOut_) {
        lastPreviewOut = previewBurn(detfIn_);
        vm.startPrank(user_);
        IERC20(detf).approve(detf, detfIn_);
        seOut_ = detfExchangeIn.exchangeIn(
            IERC20(detf), detfIn_, seShare, 0, user_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        lastExecOut = seOut_;
    }

    function compoundProtocol() public returns (uint256 detfIn_, uint256 bptOut_) {
        (detfIn_, bptOut_) = detfInfo.compoundProtocolRewards();
    }

    function claimBondRewards(address claimer_, uint256 tokenId_) public returns (uint256 claimed_) {
        vm.prank(claimer_);
        claimed_ = bondNftVault().claimRewards(tokenId_, claimer_);
    }

    /// @dev Real Uni V2 exact-in trade (both directions). WETH or USDC as tokenIn.
    function tradeUni(address tokenIn_, uint256 amountIn_) public {
        address tokenOut_ = tokenIn_ == address(tokenWeth) ? address(tokenUsdc) : address(tokenWeth);
        swapUniExactIn(tokenIn_, tokenOut_, amountIn_);
    }

    /**
     * @notice Drive synthetic above mintThreshold via production paths only (no deal / Open cheat).
     * @dev Mirrors TestBase Phase A+B (without external joins):
     *      (1) burn free DETF held by production actors while burn-allowed (bond free DETF —
     *          primary-market burn from product mint-split, not a storage hack),
     *      (2) real Uni V2 trades (SE rate providers).
     *      Does **not** use Open thresholds or deal-seed DETF supply.
     * @notice Free-DETF burns reduce totalSupply by design (unwind bond free-DETF dilution).
     *         Uni-trades-alone cannot clear mintThreshold post-bond (RQ5 PARTIAL).
     */
    function driveMintAllowed(uint256 maxSteps_) public returns (uint256 stepsUsed_) {
        require(detfInfo.isReserveLive(), "must be live");
        if (detfInfo.isMintingAllowed()) return 0;

        // Phase A: production free-DETF burns while burn-allowed (proven path from prior green D3).
        for (uint256 round_; round_ < 16 && !detfInfo.isMintingAllowed() && detfInfo.isBurningAllowed(); ++round_)
        {
            bool burned_ = _burnFreeDetfChunk(researchUser) || _burnFreeDetfChunk(researchUser2);
            ++stepsUsed_;
            if (detfInfo.isMintingAllowed()) return stepsUsed_;
            if (!burned_) break;
        }
        if (detfInfo.isMintingAllowed()) return stepsUsed_;

        // Phase B: real Uni V2 trades (rate move).
        for (uint256 i; i < maxSteps_; ++i) {
            uint256 mul_ = (i + 1) * (i + 1);
            tradeUni(address(tokenWeth), 100e18 * mul_);
            ++stepsUsed_;
            if (detfInfo.isMintingAllowed()) return stepsUsed_;
            tradeUni(address(tokenUsdc), 100_000e18 * mul_);
            ++stepsUsed_;
            if (detfInfo.isMintingAllowed()) return stepsUsed_;
            tradeUni(address(tokenWeth), 250e18 * mul_);
            ++stepsUsed_;
            if (detfInfo.isMintingAllowed()) return stepsUsed_;
        }
        revert("driveMintAllowed: cap hit - production paths could not clear mintThreshold");
    }

    function _burnFreeDetfChunk(address who_) internal returns (bool burned_) {
        if (who_ == address(0)) return false;
        uint256 bal_ = IERC20(detf).balanceOf(who_);
        if (bal_ == 0 || !detfInfo.isBurningAllowed()) return false;
        uint256 burnAmt_ = bal_ / 5;
        if (burnAmt_ > 50e18) burnAmt_ = 50e18;
        if (burnAmt_ == 0) burnAmt_ = bal_;
        vm.startPrank(who_);
        IERC20(detf).approve(detf, burnAmt_);
        try detfExchangeIn.exchangeIn(
            IERC20(detf), burnAmt_, seShare, 0, who_, false, block.timestamp + 1 hours
        ) {
            burned_ = true;
        } catch {}
        vm.stopPrank();
    }

    /**
     * @notice Drive synthetic below burnThreshold under default Policy.
     * @dev Uni trades for price + capital seigniorage dilution mints when already mint-allowed
     *      (production primary mint — not natural expansion; not a research storage hack).
     */
    function driveBurnAllowed(uint256 maxSteps_) public returns (uint256 stepsUsed_) {
        require(detfInfo.isReserveLive(), "must be live");
        if (detfInfo.isBurningAllowed()) return 0;

        for (uint256 i; i < maxSteps_; ++i) {
            // Prefer Uni trades first (price path).
            uint256 wethIn_ = 80e18 * (i + 1) + 40e18 * i * i;
            uint256 usdcIn_ = 80_000e18 * (i + 1) + 40_000e18 * i * i;
            if (wethIn_ > 2_000e18) wethIn_ = 2_000e18;
            if (usdcIn_ > 2_000_000e18) usdcIn_ = 2_000_000e18;

            tradeUni(address(tokenUsdc), usdcIn_);
            ++stepsUsed_;
            if (detfInfo.isBurningAllowed()) return stepsUsed_;
            tradeUni(address(tokenWeth), wethIn_);
            ++stepsUsed_;
            if (detfInfo.isBurningAllowed()) return stepsUsed_;

            // Capital seigniorage dilution only when mint already open (product primary mint).
            if (detfInfo.isMintingAllowed()) {
                uint256 seIn_ = 0;
                try this.fundSeSharesExternal(researchUser2, 15e18) returns (uint256 s_) {
                    seIn_ = s_;
                } catch {}
                if (seIn_ > 0) {
                    uint256 chunk_ = seIn_ / 20;
                    if (chunk_ == 0) chunk_ = seIn_;
                    try this.mintSeSharesForDetfExternal(researchUser2, chunk_) {} catch {}
                    ++stepsUsed_;
                    if (detfInfo.isBurningAllowed()) return stepsUsed_;
                }
            }
        }
        revert("driveBurnAllowed: cap hit - could not clear burnThreshold");
    }

    function fundSeSharesExternal(address to_, uint256 lpAmount_) external returns (uint256) {
        return fundSeShares(to_, lpAmount_);
    }

    function mintSeSharesForDetfExternal(address user_, uint256 seSharesIn_) external returns (uint256) {
        return mintSeSharesForDetf(user_, seSharesIn_);
    }

    /// @dev Sample with optional actor label and last preview/exec snapshot.
    function sampleDetfTagged(string memory tag_, string memory actorLabel_) public {
        lastActorLabel = actorLabel_;
        sampleDetf(tag_);
        lastActorLabel = "";
    }

    /* ---------------------------------------------------------------------- */
    /*                         Internal deploy stack                            */
    /* ---------------------------------------------------------------------- */

    function _deploySeRouterAndWeightedFactory() internal {
        senderGuardFacet = IFacet(address(new SenderGuardFacet()));
        exactInQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInQueryFacet();
        exactInSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactInSwapFacet();
        exactOutQueryFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutQueryFacet();
        exactOutSwapFacet = create3Factory.deployBalancerV3StandardExchangeRouterExactOutSwapFacet();
        batchExactInFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactInFacet();
        batchExactOutFacet = create3Factory.deployBalancerV3StandardExchangeBatchRouterExactOutFacet();
        prepayFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayFacet();
        prepayHooksFacet = create3Factory.deployBalancerV3StandardExchangeRouterPrepayHooksFacet();
        permit2WitnessFacet = create3Factory.deployBalancerV3StandardExchangeRouterPermit2WitnessFacet();

        IBalancerV3StandardExchangeRouterDFPkg.PkgInit memory pkgInit;
        pkgInit.senderGuardFacet = senderGuardFacet;
        pkgInit.balancerV3StandardExchangeRouterExactInQueryFacet = exactInQueryFacet;
        pkgInit.balancerV3StandardExchangeRouterExactInSwapFacet = exactInSwapFacet;
        pkgInit.balancerV3StandardExchangeRouterExactOutQueryFacet = exactOutQueryFacet;
        pkgInit.balancerV3StandardExchangeRouterExactOutSwapFacet = exactOutSwapFacet;
        pkgInit.balancerV3StandardExchangeBatchRouterExactInFacet = batchExactInFacet;
        pkgInit.balancerV3StandardExchangeBatchRouterExactOutFacet = batchExactOutFacet;
        pkgInit.balancerV3StandardExchangeRouterPrepayFacet = prepayFacet;
        pkgInit.balancerV3StandardExchangeRouterPrepayHooksFacet = prepayHooksFacet;
        pkgInit.balancerV3StandardExchangePermit2WitnessFacet = permit2WitnessFacet;
        pkgInit.balancerV3Vault = IVault(address(vault));
        pkgInit.permit2 = permit2;
        pkgInit.weth = IWETH(address(weth));

        seRouterDFPkg = create3Factory.deployBalancerV3StandardExchangeRouterDFPkg(pkgInit);
        seRouter = diamondPackageFactory.deployBalancerV3StandardExchangeRouter(seRouterDFPkg);

        bytes32 salt = abi.encodePacked("ResearchDetfSingleSe_WeightedPoolFactory")._hash();
        bytes memory initCode = type(WeightedPoolFactory).creationCode;
        bytes memory initArgs = abi.encode(IVault(address(vault)), uint32(365 days), "Factory v1", "Pool v1");
        weightedPoolFactory = create3Factory.create3WithArgs(initCode, initArgs, salt);
        vm.label(weightedPoolFactory, "Research_WeightedPoolFactory");
    }

    function _deployDetfInfrastructure() internal {
        multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();
        singleStandardExchangeDetfExchangeInFacet = create3Factory.deployExchangeInFacet();
        // Disambiguate DetfFacetFactoryService vs VaultComponentFactoryService.
        erc4626BasicVaultFacet = VaultComponentFactoryService.deployERC4626BasedBasicVaultFacet(create3Factory);
        erc4626StandardVaultFacet = VaultComponentFactoryService.deployERC4626StandardVaultFacet(create3Factory);

        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("ResearchDetfSingleSe_RateProviderFacet")
            )
        );
        detfRateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(
                        IStandardExchangeRateProviderDFPkg.PkgInit({
                            rateProviderFacet: rateProviderFacet,
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    keccak256("ResearchDetfSingleSe_RateProviderDFPkg")
                )
            )
        );

        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode, keccak256("ResearchDetfSingleSe_ERC721Facet")
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

        IFacet claimFacet_ = create3Factory.deployRebasingClaimTokenFacet();
        rebasingClaimTokenPkg = DetfPkgFactoryService.deployRebasingClaimTokenDFPkg(
            create3Factory,
            DetfComponentFactoryService.buildRebasingClaimTokenPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
            )
        );

        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit = ISingleStandardExchangeDETDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: singleStandardExchangeDetfExchangeInFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: seRouter,
            balancerV3Vault: IVault(address(vault)),
            weightedPoolFactory: WeightedPoolFactory(weightedPoolFactory),
            rateProviderPkg: detfRateProviderPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            diamondFactory: diamondPackageFactory
        });

        vm.startPrank(owner);
        singleStandardExchangeDetfPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployPkg(pkgInit);
        vm.stopPrank();
        vm.label(address(singleStandardExchangeDetfPkg), "Research_SingleSeDetfPkg");
    }

    function _deployDetf(string memory name_, string memory symbol_, ThresholdMode mode_)
        internal
        returns (address detf_)
    {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: name_,
            symbol: symbol_,
            standardExchangeVault: seVault,
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateTarget,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: mode_,
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

    function _bindDetf(address detf_) internal {
        detf = detf_;
        detfInfo = ISingleStandardExchangeDETFInfo(detf_);
        detfBonding = ISingleStandardExchangeDETFBonding(detf_);
        detfExchangeIn = IStandardExchangeIn(detf_);
    }

    function _sampleJson(string memory tag_) internal view returns (string memory) {
        return string.concat(_sampleJsonHead(tag_), _sampleJsonTail());
    }

    function _sampleJsonHead(string memory tag_) internal view returns (string memory) {
        bool live = address(detfInfo) != address(0) && detfInfo.isReserveLive();
        uint256 synth = address(detfInfo) != address(0) ? detfInfo.syntheticPrice() : 0;
        uint256 mintTh = address(detfInfo) != address(0) ? detfInfo.mintThreshold() : 0;
        uint256 burnTh = address(detfInfo) != address(0) ? detfInfo.burnThreshold() : 0;
        bool mintOk = address(detfInfo) != address(0) && detfInfo.isMintingAllowed();
        bool burnOk = address(detfInfo) != address(0) && detfInfo.isBurningAllowed();
        uint8 mode = address(detfInfo) != address(0) ? uint8(detfInfo.thresholdMode()) : 0;
        uint256 supply = detf != address(0) ? IERC20(detf).totalSupply() : 0;
        string memory actor_ = bytes(lastActorLabel).length == 0 ? "" : lastActorLabel;

        return string.concat(
            '{"step":',
            ResearchTelemetry.u(step),
            ',"tag":"',
            tag_,
            '","actorLabel":"',
            actor_,
            '","isReserveLive":',
            live ? "true" : "false",
            ',"thresholdMode":',
            ResearchTelemetry.u(mode),
            ',"syntheticPrice":"',
            ResearchTelemetry.u(synth),
            '","mintThreshold":"',
            ResearchTelemetry.u(mintTh),
            '","burnThreshold":"',
            ResearchTelemetry.u(burnTh),
            '","isMintingAllowed":',
            mintOk ? "true" : "false",
            ',"isBurningAllowed":',
            burnOk ? "true" : "false",
            ',"totalSupply":"',
            ResearchTelemetry.u(supply)
        );
    }

    function _sampleJsonTail() internal view returns (string memory) {
        uint256 uniSpot = address(uniV2Pair) != address(0) ? uniSpotUsdcPerWeth() : 0;
        uint256 expRate = address(detfInfo) != address(0) ? detfInfo.expansionClosureRatePerSecond() : 0;
        uint256 lastExp = address(detfInfo) != address(0) ? detfInfo.lastExpansionTimestamp() : 0;
        uint256 pending_ = 0;
        uint256 protocolBpt_ = 0;
        uint256 protocolPending_ = 0;
        if (
            address(detfInfo) != address(0) && detfInfo.isReserveLive()
                && detfInfo.bondNftVault() != address(0)
        ) {
            IDETFNFTVault v_ = IDETFNFTVault(detfInfo.bondNftVault());
            protocolBpt_ = v_.originalSharesOf(v_.detfNFTId());
            protocolPending_ = v_.pendingRewards(v_.detfNFTId());
            if (lastUserBondId != 0) {
                pending_ = v_.pendingRewards(lastUserBondId);
            }
        }

        return string.concat(
            '","uniSpotIndex":"',
            ResearchTelemetry.u(uniSpot),
            '","previewOut":"',
            ResearchTelemetry.u(lastPreviewOut),
            '","execOut":"',
            ResearchTelemetry.u(lastExecOut),
            '","pendingRewards":"',
            ResearchTelemetry.u(pending_),
            '","protocolBpt":"',
            ResearchTelemetry.u(protocolBpt_),
            '","protocolPending":"',
            ResearchTelemetry.u(protocolPending_),
            '","expansionRatePerSecond":"',
            ResearchTelemetry.u(expRate),
            '","lastExpansionTimestamp":"',
            ResearchTelemetry.u(lastExp),
            '","userBondId":"',
            ResearchTelemetry.u(lastUserBondId),
            '"}'
        );
    }
}
