// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {LaunchStageBase} from "./LaunchStageBase.sol";
import {FixtureEconomics} from "./FixtureEconomics.sol";
import {Phase_08_Stage_07_StakingPrincipalMigration as Migration} from "./Phase_08_Stage_07_StakingPrincipalMigration.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IMultiStepOwnable} from "@crane/contracts/access/ERC8023/IMultiStepOwnable.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";

import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

/// @notice Shared input validation and simulated-state exports for the opt-in fee composition.
/// @dev Shared by public deployment and fork rehearsal; the caller selects the RPC and signer.
abstract contract FeeAccrualStageBase is LaunchStageBase {
    string internal feeConfig;
    bytes32 internal feeConfigHash;
    ITokenStaking internal staking;
    address internal stakingOwner;
    address internal manager;
    address internal dtf;
    address internal wethToken;
    address internal targetDetf;
    address internal liquidityVault;
    address internal custodyVault;

    string internal constant FEE_DETF_FILE = "phase08_stage03_fee_accrual_detf.json";
    string internal constant LIQUIDITY_FILE = "phase07_stage01_fee_accrual_liquidity_se.json";
    string internal constant CUSTODY_FILE = "phase07_stage02_fee_accrual_custody_se.json";

    function _startFee(string memory title) internal {
        _start(title);
        feeConfig = vm.readFile(vm.envString("FEE_ACCRUAL_CONFIG"));
        feeConfigHash = keccak256(bytes(feeConfig));
        require(vm.parseJsonUint(feeConfig, ".chainId") == block.chainid, "Fee accrual: config chain");
        require(vm.parseJsonUint(feeConfig, ".version") == 1, "Fee accrual: config version");
        manager = _configAddress(".indexedexManager");
        dtf = _configAddress(".dtf");
        wethToken = _configAddress(".weth");
        staking = ITokenStaking(_configAddress(".tokenStaking"));
        require(address(staking.stakingToken()) == dtf, "Fee accrual: staking asset");
        stakingOwner = IMultiStepOwnable(address(staking)).owner();
        require(stakingOwner == vm.parseJsonAddress(feeConfig, ".stakingOwner"), "Fee accrual: staking owner");
        require(IMultiStepOwnable(manager).owner() == vm.parseJsonAddress(feeConfig, ".managerOwner"), "Fee accrual: manager owner");
        _configAddress(".create3Factory");
        _configAddress(".diamondPackageFactory");
        _configAddress(".hookFactory");
        _configAddress(".feeCollector");
    }

    function _basePoolKey() internal view returns (PoolKey memory key) {
        require(vm.parseJsonAddress(feeConfig, ".basePool.currency0") == address(0), "Liquidity: native ETH required");
        require(vm.parseJsonAddress(feeConfig, ".basePool.currency1") == dtf, "Liquidity: DTF required");
        uint256 fee = vm.parseJsonUint(feeConfig, ".basePool.fee");
        int256 spacing = vm.parseJsonInt(feeConfig, ".basePool.tickSpacing");
        require(fee <= type(uint24).max && spacing > 0 && spacing <= type(int24).max, "Liquidity: invalid key");
        key = PoolKey(Currency.wrap(address(0)), Currency.wrap(dtf), uint24(fee), int24(spacing), IHooks(_configAddress(".basePool.hooks")));
    }

    function _configAddress(string memory key) internal view returns (address value) {
        value = vm.parseJsonAddress(feeConfig, key);
        require(value.code.length > 0, string.concat("Fee accrual: missing contract ", key));
    }

    function _loadProduct(string memory file, string memory key) internal view returns (address value) {
        string memory json = vm.readFile(_artifactPath(file));
        require(vm.parseJsonBytes32(json, ".configHash") == feeConfigHash, "Fee accrual: different config");
        value = vm.parseJsonAddress(json, string.concat(".", key));
        require(value.code.length > 0, string.concat("Fee accrual: undeployed ", key));
        require(value.codehash == vm.parseJsonBytes32(json, ".codeHash"), "Fee accrual: changed bytecode");
    }

    function _loadFeeDetf(bool requireLive) internal {
        targetDetf = _loadProduct(FEE_DETF_FILE, "feeDetf");
        liquidityVault = _loadProduct(LIQUIDITY_FILE, "liquidityVault");
        custodyVault = _loadProduct(CUSTODY_FILE, "custodyVault");
        require(keccak256(bytes(IERC20Metadata(targetDetf).name())) == keccak256(bytes(FixtureEconomics.FEE_ACCRUAL_DETF_NAME)), "Fee accrual: wrong name");
        require(keccak256(bytes(IERC20Metadata(targetDetf).symbol())) == keccak256(bytes(FixtureEconomics.FEE_ACCRUAL_DETF_SYMBOL)), "Fee accrual: wrong symbol");
        require(IERC20Metadata(targetDetf).decimals() == 9, "Fee accrual: DETF decimals");
        IVaultRegistryVaultQuery registry = IVaultRegistryVaultQuery(manager);
        require(registry.isVault(targetDetf) && registry.isVault(liquidityVault) && registry.isVault(custodyVault), "Fee accrual: unregistered product");
        require(IERC4626(custodyVault).asset() == dtf, "Fee accrual: custody asset");
        IUniswapV4Detf info = IUniswapV4Detf(targetDetf);
        IUniswapV4StandardExchangeWeightedBufferHook hook = IUniswapV4StandardExchangeWeightedBufferHook(info.hook());
        require(hook.numTokens() == 3 && hook.pairDoorCount() == 3, "Fee accrual: weighted three-leg reserve required");
        require(address(hook.poolManager()) == _configAddress(".poolManager"), "Fee accrual: PoolManager mismatch");
        address[] memory tokens = hook.tokens();
        uint256[] memory weights = hook.getNormalizedWeights();
        require(weights.length == 3, "Fee accrual: weight count");
        uint256 found;
        for (uint256 i; i < tokens.length; ++i) {
            if (tokens[i] == targetDetf) {
                require(weights[i] == FixtureEconomics.FEE_ACCRUAL_DETF_WEIGHT, "Fee accrual: DETF weight");
                require(hook.standardExchange(i) == address(0) && hook.rateProvider(i) == address(0), "Fee accrual: self leg must be raw");
                found |= 1;
            } else if (tokens[i] == wethToken) {
                require(weights[i] == FixtureEconomics.FEE_ACCRUAL_WETH_WEIGHT, "Fee accrual: WETH weight");
                require(hook.standardExchange(i) == liquidityVault && hook.rateProvider(i) != address(0), "Fee accrual: WETH liquidity binding");
                found |= 2;
            } else if (tokens[i] == dtf) {
                require(weights[i] == FixtureEconomics.FEE_ACCRUAL_DTF_WEIGHT, "Fee accrual: DTF weight");
                require(hook.standardExchange(i) == custodyVault && hook.rateProvider(i) != address(0), "Fee accrual: DTF custody binding");
                found |= 4;
            }
        }
        require(found == 7 && custodyVault != liquidityVault, "Fee accrual: wrong composition");
        _checkRoutes(info.mintRoutes(), false);
        _checkRoutes(info.donateRoutes(), false);
        _checkRoutes(info.burnRoutes(), true);
        _checkRoutes(info.bondRoutes(), false);
        if (requireLive) {
            for (uint256 i; i < tokens.length; ++i) {
                if (tokens[i] != targetDetf) require(IRateProvider(hook.rateProvider(i)).getRate() > 0, "Fee accrual: zero provider rate");
            }
        }
        if (requireLive) Migration.validateTarget(staking, targetDetf);
    }

    function _checkRoutes(IUniswapV4Detf.IoRoute[] memory routes, bool burn) internal view {
        require(routes.length == (burn ? 1 : 2), "Fee accrual: route count");
        uint256 found;
        for (uint256 i; i < routes.length; ++i) {
            if (address(routes[i].token) == dtf && address(routes[i].vault) == custodyVault) found |= 1;
            if (!burn && address(routes[i].token) == wethToken && address(routes[i].vault) == liquidityVault) found |= 2;
        }
        require(found == (burn ? 1 : 3), "Fee accrual: route binding");
    }

    function _exportProduct(string memory file, string memory key, address value) internal {
        string memory obj = string.concat("fee-", key);
        vm.serializeUint(obj, "chainId", block.chainid);
        vm.serializeBytes32(obj, "configHash", feeConfigHash);
        vm.serializeBytes32(obj, "codeHash", value.codehash);
        vm.serializeUint(obj, "observedBlock", block.number);
        // Forge scripts execute in simulation even with --broadcast. Receipts live in the shell journal.
        vm.serializeBool(obj, "receiptVerified", false);
        _writeJson(vm.serializeAddress(obj, key, value), file);
    }

    function _exportSnapshot(string memory file, Migration.Snapshot memory state) internal {
        string memory obj = string.concat("fee-", file);
        vm.serializeUint(obj, "chainId", block.chainid);
        vm.serializeBytes32(obj, "configHash", feeConfigHash);
        vm.serializeAddress(obj, "tokenStaking", address(staking));
        vm.serializeAddress(obj, "targetDetf", address(staking.targetDetf()));
        vm.serializeAddress(obj, "claimVault", state.claimVault);
        vm.serializeUint(obj, "phase", uint256(state.phase));
        vm.serializeUint(obj, "principal", state.principal);
        vm.serializeUint(obj, "reserveRemaining", state.remaining);
        vm.serializeUint(obj, "rewardReserveDiagnostic", state.rewardReserve);
        vm.serializeUint(obj, "rewardRate", state.rewardRate);
        vm.serializeUint(obj, "vaultShares", state.vaultShares);
        _writeJson(vm.serializeBool(obj, "receiptVerified", false), file);
    }
}
