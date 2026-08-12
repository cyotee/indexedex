// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {DeploymentBase} from "./DeploymentBase.sol";
import {RobinhoodCanonicalLib} from "./RobinhoodCanonicalLib.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

import {
    IUniswapV4SingleStandardExchangeDETDFPkg,
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @title Script_09_DeployChirInstance
/// @notice Deploy inert CHIR fee-DETF instance (launch-rich @ 10 WETH/CHIR).
contract Script_09_DeployChirInstance is DeploymentBase {
    string internal constant CORE_FILE = "02_indexedex_core.json";
    string internal constant SE_FILE = "05_univ3_se_rich.json";
    string internal constant PKGS_FILE = "08_fee_detf_packages.json";
    string internal constant ARTIFACT_FILE = "09_chir_instance.json";

    address private indexedexManager;
    address private uniV3Se_rich;
    address private chirDetfPkg;
    address private bondNftVaultPkg;
    address private rebasingClaimTokenPkg;

    address private chir;
    address private reserveHook;
    address private bondNftVault;
    address private rebasingClaim;
    uint256 private creationPairPerDetfWad;

    function run() external {
        _loadConfig();
        _requireRobinhoodChain();
        RobinhoodCanonicalLib.requireCanonicalPins();
        _loadPrior();
        _logHeader("Stage 09: CHIR instance (inert launch-rich)");

        if (_loadExisting()) {
            _exportJson();
            _logResults();
            return;
        }

        creationPairPerDetfWad = FixtureEconomics.creationPairPerDetfWad();

        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args = IUniswapV4SingleStandardExchangeDETDFPkg
            .PkgArgs({
            name: FixtureEconomics.CHIR_NAME,
            symbol: FixtureEconomics.CHIR_SYMBOL,
            standardExchangeVault: IStandardExchangeProxy(uniV3Se_rich),
            standardExchangeVaultShare: IERC20(address(0)),
            pairToken: IERC20(RobinhoodCanonicalLib.weth()),
            creationPairPerDetfWad: creationPairPerDetfWad,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: FixtureEconomics.expansionClosureRatePerYearWad(),
            expansionMaxCatchUpEpochs: 0,
            hookMineNonce: 0
        });

        vm.startBroadcast();
        chir = IIndexedexManagerProxy(indexedexManager).deployVault(
            IStandardVaultPkg(chirDetfPkg), abi.encode(args)
        );
        // Pin vault bond terms after deploy (postDeploy fee NFT path needs global defaults already set in stage 07).
        try IVaultFeeOracleManager(indexedexManager).setVaultBondTerms(
            chir,
            BondTerms({
                minLockDuration: FixtureEconomics.DEFAULT_MIN_LOCK,
                maxLockDuration: FixtureEconomics.DEFAULT_MAX_LOCK,
                minBonusPercentage: 0,
                maxBonusPercentage: 0.5e18
            })
        ) {} catch {}
        vm.stopBroadcast();

        IUniswapV4SingleStandardExchangeDETF detf = IUniswapV4SingleStandardExchangeDETF(chir);
        require(!detf.isReserveLive(), "CHIR unexpectedly live before first bond");
        reserveHook = detf.reserveHook();
        bondNftVault = detf.bondNftVault();
        try detf.rebasingClaimToken() returns (address claim_) {
            rebasingClaim = claim_;
        } catch {
            rebasingClaim = address(0);
        }
        creationPairPerDetfWad = detf.creationPairPerDetfWad();
        require(creationPairPerDetfWad == FixtureEconomics.creationPairPerDetfWad(), "creation rate mismatch");

        vm.label(chir, "CHIR");
        if (reserveHook != address(0)) vm.label(reserveHook, "reserveHook");

        _exportJson();
        _logResults();
    }

    function _loadPrior() internal {
        indexedexManager = _readAddress(CORE_FILE, "indexedexManager");
        uniV3Se_rich = _readAddress(SE_FILE, "uniV3Se_rich");
        chirDetfPkg = _readAddress(PKGS_FILE, "chirDetfPkg");
        bondNftVaultPkg = _readAddress(PKGS_FILE, "bondNftVaultPkg");
        rebasingClaimTokenPkg = _readAddress(PKGS_FILE, "rebasingClaimTokenPkg");
        require(uniV3Se_rich != address(0) && chirDetfPkg != address(0), "missing SE or DETF pkg");
    }

    function _loadExisting() internal returns (bool) {
        if (_force()) return false;
        (address c, bool ok) = _readAddressSafe(ARTIFACT_FILE, "chir");
        if (!ok || c.code.length == 0) return false;
        chir = c;
        (reserveHook,) = _readAddressSafe(ARTIFACT_FILE, "reserveHook");
        (bondNftVault,) = _readAddressSafe(ARTIFACT_FILE, "bondNftVault");
        (rebasingClaim,) = _readAddressSafe(ARTIFACT_FILE, "rebasingClaim");
        (creationPairPerDetfWad,) = _readUintSafe(ARTIFACT_FILE, "creationPairPerDetfWad");
        return true;
    }

    function _exportJson() internal {
        string memory json;
        json = vm.serializeAddress("chir", "chir", chir);
        json = vm.serializeAddress("chir", "feeDetf", chir);
        json = vm.serializeAddress("chir", "reserveHook", reserveHook);
        json = vm.serializeAddress("chir", "bondNftVault", bondNftVault);
        json = vm.serializeAddress("chir", "rebasingClaim", rebasingClaim);
        json = vm.serializeAddress("chir", "uniV3Se_rich", uniV3Se_rich);
        json = vm.serializeAddress("chir", "pairToken", RobinhoodCanonicalLib.weth());
        json = vm.serializeAddress("chir", "chirDetfPkg", chirDetfPkg);
        json = vm.serializeAddress("chir", "bondNftVaultPkg", bondNftVaultPkg);
        json = vm.serializeAddress("chir", "rebasingClaimTokenPkg", rebasingClaimTokenPkg);
        json = vm.serializeUint("chir", "creationPairPerDetfWad", creationPairPerDetfWad);
        json = vm.serializeBool("chir", "isReserveLive", false);
        json = vm.serializeString("chir", "feeDetfTemplate", "launch-rich");
        json = vm.serializeString("chir", "symbol", FixtureEconomics.CHIR_SYMBOL);
        json = vm.serializeUint("chir", "chainId", block.chainid);
        _writeJson(json, ARTIFACT_FILE);
    }

    function _logResults() internal view {
        _logAddress("CHIR:", chir);
        _logAddress("reserveHook:", reserveHook);
        _logUint("creationPairPerDetfWad:", creationPairPerDetfWad);
        _logComplete("Stage 09");
    }
}
