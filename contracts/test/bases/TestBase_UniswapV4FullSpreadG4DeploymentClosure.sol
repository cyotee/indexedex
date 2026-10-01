// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadG4ImportClosure} from "contracts/test/bases/TestBase_UniswapV4FullSpreadG4ImportClosure.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {Creation} from "@crane/contracts/utils/Creation.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {IUniswapV4MultiPoolTwapOracle} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultPositionImport as Import} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInTarget.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultLiquidReserve.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultExecutionProtection as Protection} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultExecutionProtection.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultInExecutionBinding as InBinding, IUniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionBinding as OutBinding} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/interfaces/IUniswapV4FullSpreadHooklessStandardExchangeVaultComponentBindings.sol";
import {PoolSeedLib} from "scripts/foundry/anvil_robinhood_testnet/PoolSeedLib.sol";
import {FullSpreadG4OracleCounterparty} from "contracts/test/stubs/FullSpreadG4OracleCounterparty.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg as G4PackageErrors} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/IUniswapV4FullSpreadHooklessStandardExchangeVaultDFPkg.sol";

// tag::TestBase_UniswapV4FullSpreadG4DeploymentClosure[]
/// @notice Exact deployment/launch/oracle predicates, shared only as test infrastructure.
abstract contract TestBase_UniswapV4FullSpreadG4DeploymentClosure is TestBase_UniswapV4FullSpreadG4ImportClosure {
    using PoolIdLibrary for PoolKey;
    IIndexedexManagerProxy internal g4Registry;
    IDiamondFactoryPackage internal g4Package;
    IUniswapV4MultiPoolTwapOracle internal g4Oracle;
    address internal g4Factory;
    address internal g4Weth;
    address[] internal g4ExpectedFacets;
    struct G4MoneyBefore {
        uint256 input;
        uint256 output;
        uint256 supply;
        uint256 callerEth;
        uint256 recipientEth;
    }

    function _g4Prefix() internal pure virtual returns (string memory);
    function _g4SecondVault() internal virtual returns (IStandardExchangeProxy);
    function _g4NativeVault(PoolKey memory key_) internal virtual returns (IStandardExchangeProxy);
    function _g4DeployBadOracle(bool zero_) internal virtual;
    function _g4OraclePackage(IUniswapV4MultiPoolTwapOracle oracle_) internal virtual returns (address);
    function _g4VaultFromPackage(address package_) internal virtual returns (IStandardExchangeProxy);

    function _g4Counterparty() internal returns (FullSpreadG4OracleCounterparty) {
        return FullSpreadG4OracleCounterparty(ICreate3FactoryProxy(g4Factory).create3WithArgs(
            type(FullSpreadG4OracleCounterparty).creationCode, abi.encode(g4Oracle, address(this)),
            keccak256(abi.encode("G4.OracleCounterparty"))));
    }

    /// @notice F-baseline fail-closed oracle updates roll back funded deposit state and genuine oracle writes.
    function test_G4_twapUpdateFaultRollsBackFundedOperation() public {
        FullSpreadG4OracleCounterparty counterparty = _g4Counterparty();
        address package_ = _g4OraclePackage(IUniswapV4MultiPoolTwapOracle(address(counterparty)));
        g4.vault = _g4VaultFromPackage(package_);
        g4.token0.approve(address(g4.vault), 100e18);
        g4.token1.approve(address(g4.vault), 100e18);
        counterparty.configure(address(g4.manager), true);
        address[] memory tokens = new address[](2);
        tokens[0] = address(g4.token0); tokens[1] = address(g4.token1);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18; amounts[1] = 100e18;
        bytes32 beforeState = _g4FaultFingerprint();
        vm.expectRevert(FullSpreadG4OracleCounterparty.UpdateFault.selector);
        IStandardExchangeInMulti(address(g4.vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(g4.vault)), 0, address(this), false, block.timestamp);
        assertEq(_g4FaultFingerprint(), beforeState);
        counterparty.configure(address(g4.manager), false);
        PoolSeedLib.activateStandardExchange(address(g4.vault), g4.key, 100e18, address(this));
        assertEq(g4.vault.balanceOf(address(this)), 100e18 - 1e15);
        assertEq(g4.vault.totalSupply(), 100e18);
        _g4Booked();
    }

    function _g4FaultFingerprint() internal view returns (bytes32) {
        (bytes memory state,) = IStandardExchangeTransitionQuote(address(g4.vault)).quoteState(address(g4.token0), address(this));
        return keccak256(abi.encode(_g4Ledger(), state, _g4PoolCheckpoint(),
            g4.token0.balanceOf(address(g4.manager)), g4.token1.balanceOf(address(g4.manager)),
            g4.token0.allowance(address(this), address(g4.vault)), g4.token1.allowance(address(this), address(g4.vault)),
            g4Oracle.getObservation(g4.key.toId(), 0), address(this).balance, address(g4.vault).balance));
    }

    function _g4PoolCheckpoint() internal view returns (bytes32) {
        bytes32 slot;
        bytes32 fees;
        bytes32 position;
        {
            (uint160 price, int24 tick, uint24 protocolFee, uint24 lpFee) = StateLibrary.getSlot0(g4.manager, g4.key.toId());
            slot = keccak256(abi.encode(price, tick, protocolFee, lpFee));
        }
        {
            (uint256 global0, uint256 global1) = StateLibrary.getFeeGrowthGlobals(g4.manager, g4.key.toId());
            fees = keccak256(abi.encode(global0, global1));
        }
        {
            (uint128 owned, uint256 last0, uint256 last1) = StateLibrary.getPositionInfo(g4.manager, g4.key.toId(),
                address(g4.vault), TickMath.minUsableTick(g4.key.tickSpacing), TickMath.maxUsableTick(g4.key.tickSpacing), bytes32(0));
            position = keccak256(abi.encode(owned, last0, last1));
        }
        return keccak256(abi.encode(slot, fees, position, StateLibrary.getLiquidity(g4.manager, g4.key.toId())));
    }

    /// @notice A changed advertised manager fails processArgs after valid package construction, before registration.
    function test_G4_twapChangedManagerRejectsInstanceWithoutRegistration() public {
        FullSpreadG4OracleCounterparty counterparty = _g4Counterparty();
        address package_ = _g4OraclePackage(IUniswapV4MultiPoolTwapOracle(address(counterparty)));
        uint256 count = g4Registry.vaults().length;
        assertEq(g4Registry.vaultsOfPackage(package_).length, 0);
        counterparty.configure(address(0xBAD), false);
        vm.expectRevert(G4PackageErrors.TwapOraclePoolManagerMismatch.selector);
        _g4VaultFromPackage(package_);
        assertEq(g4Registry.vaults().length, count);
        assertEq(g4Registry.vaultsOfPackage(package_).length, 0);
        counterparty.configure(address(g4.manager), false);
        IStandardExchangeProxy deployed = _g4VaultFromPackage(package_);
        assertTrue(g4Registry.isVault(address(deployed)));
        assertEq(g4Registry.vaultsOfPackage(package_).length, 1);
        assertEq(g4Registry.vaultsOfPackage(package_)[0], address(deployed));
    }

    function _g4Interfaces() internal pure returns (bytes4[] memory ids_) {
        // Both family interfaces have the same signatures; these are ABI controls, not shared execution.
        ids_ = new bytes4[](20);
        ids_[0] = type(IERC20).interfaceId;
        ids_[1] = type(IERC20Metadata).interfaceId;
        ids_[2] = ids_[0] ^ ids_[1];
        ids_[3] = type(IERC5267).interfaceId;
        ids_[4] = type(IERC20Permit).interfaceId;
        ids_[5] = type(IStandardVault).interfaceId;
        ids_[6] = type(IStandardExchangeIn).interfaceId;
        ids_[7] = type(IStandardExchangeOut).interfaceId;
        ids_[8] = type(Import).interfaceId;
        ids_[9] = type(Reserve).interfaceId;
        ids_[10] = type(IStandardExchangeInMulti).interfaceId;
        ids_[11] = type(IStandardExchangeOutMulti).interfaceId;
        ids_[12] = type(IStandardExchangeTransitionQuote).interfaceId;
        ids_[13] = type(IStandardizedYield).interfaceId;
        ids_[14] = type(IStandardExchangeExternalQuote).interfaceId;
        ids_[15] = type(Protection).interfaceId;
        ids_[16] = type(InBinding).interfaceId;
        ids_[17] = type(OutBinding).interfaceId;
        ids_[18] = type(IStandardExchangeUnlockContextQuote).interfaceId;
        ids_[19] = type(IStandardExchangeExactOutputQuantityQuote).interfaceId;
    }

    /// @notice Exact package declaration/order, current optional interfaces, registry membership and token metadata.
    function test_G4_packageRegistryMetadata() public {
        (string memory name, bytes4[] memory ids, address[] memory facets) = g4Package.packageMetadata();
        assertEq(name, string.concat(_g4Prefix(), "DFPkg"));
        assertEq(abi.encode(ids), abi.encode(_g4Interfaces()));
        assertEq(facets, g4ExpectedFacets);
        assertEq(g4Package.packageName(), name);
        assertEq(g4Package.facetAddresses(), facets);
        assertEq(abi.encode(g4Package.facetInterfaces()), abi.encode(ids));
        IDiamondFactoryPackage.DiamondConfig memory config = g4Package.diamondConfig();
        assertEq(abi.encode(config.interfaces), abi.encode(ids));
        assertEq(abi.encode(config.facetCuts), abi.encode(g4Package.facetCuts()));
        assertEq(config.facetCuts.length, facets.length);
        for (uint256 i; i < facets.length; ++i) {
            assertEq(config.facetCuts[i].facetAddress, facets[i]);
            assertEq(uint256(config.facetCuts[i].action), uint256(IDiamond.FacetCutAction.Add));
            assertTrue(Behavior_IFacet.isValid_IFacet_facetMetadata_consistency(IFacet(facets[i])));
            assertEq(abi.encode(config.facetCuts[i].functionSelectors), abi.encode(IFacet(facets[i]).facetFuncs()));
        }
        address[] memory tokens = IBasicVault(address(g4.vault)).vaultTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], address(g4.token0)); assertEq(tokens[1], address(g4.token1));
        IStandardVault.VaultConfig memory vaultConfig = IStandardVault(address(g4.vault)).vaultConfig();
        assertEq(vaultConfig.tokens, tokens);
        assertEq(abi.encode(vaultConfig.vaultTypes), abi.encode(ids));
        assertEq(vaultConfig.contentsId, g4Registry.calcContentsId(tokens));
        assertTrue(g4Registry.isVault(address(g4.vault)));
        address[] memory byPackage = g4Registry.vaultsOfPackage(address(g4Package));
        assertEq(byPackage.length, 1); assertEq(byPackage[0], address(g4.vault));
        for (uint256 i; i < 2; ++i) {
            address[] memory byToken = g4Registry.vaultsOfToken(tokens[i]);
            assertEq(byToken.length, 1); assertEq(byToken[0], address(g4.vault));
        }
        assertEq(IERC20Metadata(address(g4.vault)).symbol(), "UV4X");
        assertEq(IERC20Metadata(address(g4.vault)).decimals(), 18);
        assertEq(IERC20Metadata(address(g4.vault)).name(), string.concat("UniV4 Vault of (",
            IERC20Metadata(tokens[0]).symbol(), " / ", IERC20Metadata(tokens[1]).symbol(), ")"));
    }

    /// @notice Every family component and package resolves to the ABI-name salt, not the raw string hash.
    function test_G4_packageAndComponentAbiNameSalts() public view {
        string[10] memory suffixes = ["InFacet", "InQueryFacet", "PositionImportFacet", "OutFacet", "OutQueryFacet",
            "LiquidReserveFacet", "InMultiFacet", "InMultiQueryFacet", "OutMultiFacet", "OutMultiQueryFacet"];
        for (uint256 i; i < suffixes.length; ++i) {
            _g4Salt(g4ExpectedFacets[i + 5], string.concat(_g4Prefix(), suffixes[i]));
        }
        _g4Salt(InBinding(g4ExpectedFacets[5]).UNISWAP_V4_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE(),
            string.concat(_g4Prefix(), "InExecutionDelegate"));
        _g4Salt(OutBinding(g4ExpectedFacets[8]).UNISWAP_V4_STANDARD_EXCHANGE_OUT_EXECUTION_DELEGATE(),
            string.concat(_g4Prefix(), "OutExecutionDelegate"));
        _g4Salt(address(g4Package), string.concat(_g4Prefix(), "DFPkg"));
    }

    function _g4Salt(address deployed_, string memory name_) internal view {
        bytes32 salt = keccak256(abi.encode(name_));
        assertTrue(salt != keccak256(bytes(name_)));
        assertEq(deployed_, Creation._create3AddressFromOf(g4Factory, salt));
        assertTrue(deployed_ != Creation._create3AddressFromOf(g4Factory, keccak256(bytes(name_))));
        assertGt(deployed_.code.length, 0);
    }

    /// @notice Native PoolKey order survives even when its WETH public face sorts after the pair token.
    function test_G4_nativeRegistryPreservesPoolKeyOrder() public {
        bytes memory args = abi.encode("G4 native pair", "G4N", uint8(18), address(this), uint256(1e24));
        bytes32 initHash = keccak256(bytes.concat(type(ERC20PermitMintableStub).creationCode, args));
        bytes32 salt;
        address predicted;
        for (uint256 i; ; ++i) {
            salt = bytes32(i);
            predicted = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, initHash)))));
            if (predicted < g4Weth) break;
        }
        ERC20PermitMintableStub pair = new ERC20PermitMintableStub{salt: salt}("G4 native pair", "G4N", 18, address(this), 1e24);
        assertEq(address(pair), predicted);
        assertLt(uint160(address(pair)), uint160(g4Weth));
        PoolKey memory nativeKey = g4.key;
        nativeKey.currency0 = Currency.wrap(address(0));
        nativeKey.currency1 = Currency.wrap(address(pair));
        IStandardExchangeProxy nativeVault = _g4NativeVault(nativeKey);
        address[] memory tokens = IBasicVault(address(nativeVault)).vaultTokens();
        assertEq(tokens.length, 2); assertEq(tokens[0], g4Weth); assertEq(tokens[1], address(pair));
        _g4AssertNativeContents(nativeVault, address(pair));
        assertEq(g4Registry.vaultsOfToken(g4Weth).length, 1);
        assertEq(g4Registry.vaultsOfToken(g4Weth)[0], address(nativeVault));
        assertEq(g4Registry.vaultsOfToken(address(pair)).length, 1);
        assertEq(g4Registry.vaultsOfToken(address(pair))[0], address(nativeVault));
        assertEq(IERC20Metadata(address(nativeVault)).name(), "UniV4 Vault of (WETH / G4N)");
        assertEq(IERC20Metadata(address(nativeVault)).symbol(), "UV4X");
        _g4NativeMoneyPaths(nativeVault, nativeKey, IERC20(address(pair)));
    }

    function _g4NativeMoneyPaths(IStandardExchangeProxy vault_, PoolKey memory key_, IERC20 pair_) internal {
        // Genuine WETH funding and real native PoolManager settlement, never a raw-ETH public SE call.
        vm.deal(address(this), address(this).balance + 200 ether);
        IWETH(g4Weth).deposit{value: 200 ether}();
        g4.vault = vault_; g4.key = key_; g4.token0 = IERC20(g4Weth); g4.token1 = pair_;
        g4.token0.approve(address(vault_), type(uint256).max);
        pair_.approve(address(vault_), type(uint256).max);
        address[] memory tokens = new address[](2);
        tokens[0] = g4Weth; tokens[1] = address(pair_);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether; amounts[1] = 100 ether;
        uint256 beforeEth = address(this).balance;
        IStandardExchangeInMulti(address(vault_)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault_)), 100 ether - 1e15, address(this), false, block.timestamp);
        assertEq(address(this).balance, beforeEth);
        _g4Booked();
        for (uint256 mode; mode < 4; ++mode) {
            uint256 snapshot = vm.snapshotState();
            IERC20 input = mode % 2 == 0 ? g4.token0 : g4.token1;
            IERC20 output = mode < 2 ? (mode == 0 ? g4.token1 : g4.token0) : IERC20(address(vault_));
            _g4NativeMoneyCase(input, output);
            assertTrue(vm.revertToStateAndDelete(snapshot));
        }
    }

    function _g4NativeMoneyCase(IERC20 input_, IERC20 output_) internal {
        uint256 amount = 0.001 ether;
        uint256 quoted = g4.vault.previewExchangeIn(input_, amount, output_);
        assertGt(quoted, 0);
        address recipient = address(0xBEEF);
        G4MoneyBefore memory beforeState = G4MoneyBefore(input_.balanceOf(address(this)), output_.balanceOf(recipient),
            g4.vault.totalSupply(), address(this).balance, recipient.balance);
        assertEq(g4.vault.exchangeIn(input_, amount, output_, quoted, recipient, false, block.timestamp), quoted);
        assertEq(input_.balanceOf(address(this)), beforeState.input - amount);
        assertEq(output_.balanceOf(recipient), beforeState.output + quoted);
        assertEq(g4.vault.totalSupply(), beforeState.supply + (address(output_) == address(g4.vault) ? quoted : 0));
        assertEq(address(this).balance, beforeState.callerEth);
        assertEq(recipient.balance, beforeState.recipientEth);
        _g4Booked();
    }

    /// @dev PoolKey-ordered faces and canonical registry contents identity must coexist.
    function _g4AssertNativeContents(IStandardExchangeProxy nativeVault_, address pair_) internal view {
        address[] memory ordered = new address[](2);
        ordered[0] = g4Weth; ordered[1] = pair_;
        IStandardVault.VaultConfig memory config = IStandardVault(address(nativeVault_)).vaultConfig();
        assertEq(config.tokens, ordered, "fresh vault config preserves PoolKey face order");
        address[] memory sorted = new address[](2);
        sorted[0] = pair_; sorted[1] = g4Weth;
        bytes32 sortedId = keccak256(abi.encode(sorted));
        assertEq(config.contentsId, sortedId, "family contentsId hashes sorted copy");
        assertEq(IStandardVault(address(nativeVault_)).contentsId(), sortedId);
        assertEq(g4Registry.calcContentsId(ordered), sortedId, "registry helper sorts faces");
        assertEq(g4Registry.calcContentsId(sorted), sortedId, "registry helper is order independent");
        assertTrue(keccak256(abi.encode(ordered)) != sortedId, "reverse-sorted native fixture distinguishes the two meanings");
        address[] memory registered = g4Registry.vaultsOfContentsId(sortedId);
        assertEq(registered.length, 1);
        assertEq(registered[0], address(nativeVault_), "canonical contents lookup finds actual native vault");
        registered = g4Registry.vaultsOfTokens(ordered);
        assertEq(registered.length, 1);
        assertEq(registered[0], address(nativeVault_), "PoolKey-order lookup finds actual native vault");
        registered = g4Registry.vaultsOfTokens(sorted);
        assertEq(registered.length, 1);
        assertEq(registered[0], address(nativeVault_), "reverse-order lookup finds actual native vault");
    }

    /// @notice Actual registry/CREATE3 construction rejects zero and real foreign-manager oracle bindings.
    /// @dev CREATE3 masks constructor data; exact inner package errors remain source evidence, not asserted payloads.
    function test_G4_twapInvalidConstructorBindingsDoNotRegister() public {
        uint256 count = g4Registry.vaultPackages().length;
        // Each adapter prepares dependencies before arming expectRevert on the actual deployment call.
        _g4DeployBadOracle(true);
        assertEq(g4Registry.vaultPackages().length, count);
        _g4DeployBadOracle(false);
        assertEq(g4Registry.vaultPackages().length, count);
    }

    /// @notice The actual launch helper funds the requested receiver once and clears both approvals.
    function test_G4_launchActivationReplayDoesNotReseed() public {
        address receiver = makeAddr("G4 launch receiver");
        uint256 before0 = g4.token0.balanceOf(address(this));
        uint256 before1 = g4.token1.balanceOf(address(this));
        PoolSeedLib.activateStandardExchange(address(g4.vault), g4.key, 100e18, receiver);
        assertEq(before0 - g4.token0.balanceOf(address(this)), 100e18);
        assertEq(before1 - g4.token1.balanceOf(address(this)), 100e18);
        assertEq(g4.vault.balanceOf(receiver), 100e18 - 1e15);
        assertEq(g4.vault.balanceOf(address(0xdEaD)), 1e15);
        assertEq(g4.token0.allowance(address(this), address(g4.vault)), 0);
        assertEq(g4.token1.allowance(address(this), address(g4.vault)), 0);
        bytes32 beforeReplay = _g4Ledger();
        PoolSeedLib.activateStandardExchange(address(g4.vault), g4.key, 100e18, receiver);
        assertEq(_g4Ledger(), beforeReplay);
        assertEq(g4.vault.balanceOf(receiver), 100e18 - 1e15);
        g4.token0.approve(address(g4.vault), 1e18);
        uint256 quoted = g4.vault.previewExchangeIn(g4.token0, 1e18, IERC20(address(g4.vault)));
        assertGt(quoted, 0);
        uint256 oldShares = g4.vault.balanceOf(receiver);
        assertEq(g4.vault.exchangeIn(g4.token0, 1e18, IERC20(address(g4.vault)), quoted, receiver, false, block.timestamp), quoted);
        assertEq(g4.vault.balanceOf(receiver), oldShares + quoted);
        assertEq(g4.token0.allowance(address(this), address(g4.vault)), 0);
        _g4Booked();
    }

    /// @notice Real bound oracle records the post-operation tick; transfers and foreign keys cannot overwrite it.
    function test_G4_twapBoundPoolObservationAndNonwritingPolicy() public {
        assertEq(address(Reserve(address(g4.vault)).twapOracle()), address(g4Oracle));
        assertEq(g4Oracle.poolManager(), address(g4.manager));
        (, uint16 cardinality,,,) = g4Oracle.getState(g4.key.toId());
        assertEq(cardinality, 0);
        // A direct swap is supported before vault activation and moves the first recorded spot.
        g4.vault.exchangeIn(g4.token0, 100e18, g4.token1, 0, address(this), false, block.timestamp);
        (, int24 spot,,) = StateLibrary.getSlot0(g4.manager, g4.key.toId());
        int24 recorded;
        (, cardinality,, recorded,) = g4Oracle.getState(g4.key.toId());
        assertEq(cardinality, 1); assertEq(recorded, spot);
        IUniswapV4MultiPoolTwapOracle.Observation memory observation = g4Oracle.getObservation(g4.key.toId(), 0);
        assertEq(observation.prevTick, spot); assertEq(observation.tickCumulative, 0);
        assertTrue(observation.initialized);
        assertFalse(g4Oracle.update(g4.key), "same timestamp is a nonwriting result, not a revert");
        // Nonwriting update does not prevent a funded vault operation in the same timestamp.
        PoolSeedLib.activateStandardExchange(address(g4.vault), g4.key, 100e18, address(this));
        bytes32 recordedBefore = keccak256(abi.encode(g4Oracle.getObservation(g4.key.toId(), 0)));
        vm.warp(block.timestamp + 1);
        g4.vault.transfer(address(0xBEEF), 1);
        assertEq(keccak256(abi.encode(g4Oracle.getObservation(g4.key.toId(), 0))), recordedBefore);
        PoolKey memory foreign = g4.key;
        foreign.hooks = IHooks(address(0)); foreign.fee = 10_000;
        assertFalse(g4Oracle.update(foreign), "uninitialized foreign pool returns false");
        g4.manager.initialize(foreign, uint160(1) << 96);
        Reserve(address(g4.vault)).rebalanceLiquidReserve();
        (, uint16 foreignCardinality,,,) = g4Oracle.getState(foreign.toId());
        assertEq(foreignCardinality, 0);
        recordedBefore = keccak256(abi.encode(g4Oracle.getObservation(g4.key.toId(), 0)));
        assertTrue(g4Oracle.update(foreign));
        (, foreignCardinality,,,) = g4Oracle.getState(foreign.toId());
        assertEq(foreignCardinality, 1);
        assertEq(keccak256(abi.encode(g4Oracle.getObservation(g4.key.toId(), 0))), recordedBefore);
        IStandardExchangeProxy other = _g4SecondVault();
        assertEq(address(Reserve(address(other)).twapOracle()), address(g4Oracle));
        assertEq(Reserve(address(other)).twapOracle().poolManager(), address(g4.manager));
    }
}
// end::TestBase_UniswapV4FullSpreadG4DeploymentClosure[]
