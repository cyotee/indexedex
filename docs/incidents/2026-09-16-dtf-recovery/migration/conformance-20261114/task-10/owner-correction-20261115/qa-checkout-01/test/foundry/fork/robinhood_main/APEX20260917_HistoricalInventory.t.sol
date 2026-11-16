// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";

interface IVaultTokenView {
    function vaultTokens() external view returns (address[] memory);
    function reserveOfToken(address token) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function deployedReserve() external view returns (uint256 amount0, uint256 amount1);
}

/// @dev Read-only historical inventory at chain 4663 / block 64025200. No broadcasts.
contract APEX20260917_HistoricalInventory is Test {
    address internal constant REGISTRY = 0x09682b00D873D913ada0bB69B4D4c9631810d0bc;
    uint256 internal constant PINNED_BLOCK = 64025200;
    uint256 internal constant CHAIN_ID = 4663;
    bytes4 internal constant RESERVE_OF_TOKEN = 0x46f910ac;

    address internal constant UNI_V4_WETH_DTF_OPEN = 0x999DaE02D22E5FEe1c4508430D5196d31d631009;
    address internal constant UNI_V4_WETH_DTF_B = 0xb7D4Bb379D361AD442CddEE53eA71a33957826A7;
    address internal constant UNI_V4_WETH_PONS_A = 0x3E33871A8740b294A48347BFFD8A5004E1578c0D;
    address internal constant UNI_V4_WETH_PONS_B = 0x201d31a56c58a3489beC218c7A899d59A07A35f0;
    address internal constant UNI_V4_WETH_PONS_C = 0xabC9C5B5c8118a15A440Ac59a1C74A718E65681C;
    address internal constant UNI_V4_USDG_MARTIANS = 0x17B5f1045Edf3b6215d0C38eB9FF50649d887D10;
    address internal constant UNI_V4_ETH_PONS = 0x64e0f5A5Cf0F579EFF0981A4fEDEA77964B74531;
    address internal constant CUSTODY = 0x2E9C1F705aB967c5Af59249203d7495bDabb223b;

    function setUp() public {
        string memory rpcAlias = vm.envOr("APEX_ROBINHOOD_RPC_ALIAS", string("robinhood_mainnet_alchemy"));
        vm.createSelectFork(rpcAlias, PINNED_BLOCK);
    }

    function _reported() internal pure returns (address[] memory addrs) {
        addrs = new address[](8);
        addrs[0] = UNI_V4_WETH_DTF_OPEN;
        addrs[1] = UNI_V4_WETH_DTF_B;
        addrs[2] = UNI_V4_WETH_PONS_A;
        addrs[3] = UNI_V4_WETH_PONS_B;
        addrs[4] = UNI_V4_WETH_PONS_C;
        addrs[5] = UNI_V4_USDG_MARTIANS;
        addrs[6] = UNI_V4_ETH_PONS;
        addrs[7] = CUSTODY;
    }

    function test_APEX001M2_chainAndRegistry() public {
        assertEq(block.chainid, CHAIN_ID, "chain 4663");
        assertEq(block.number, PINNED_BLOCK, "pinned historical block");
        assertEq(REGISTRY.code.length > 0, true, "registry code");
        assertTrue(IVaultRegistryVaultQuery(REGISTRY).isVault(UNI_V4_WETH_DTF_OPEN), "primary reported vault in registry");
        assertTrue(IVaultRegistryVaultQuery(REGISTRY).isVault(CUSTODY), "custody in registry");
        address[] memory vaults = IVaultRegistryVaultQuery(REGISTRY).vaults();
        assertGt(vaults.length, 0, "registry enumerates vaults");
        emit log_named_uint("registryVaultCount", vaults.length);
    }

    function test_APEX001M2_reserveOfTokenSelector() public pure {
        assertEq(IVaultTokenView.reserveOfToken.selector, RESERVE_OF_TOKEN);
    }

    function test_APEX001M2_instanceInventoryAndGates() public {
        address[] memory addrs = _reported();
        for (uint256 i; i < addrs.length; ++i) {
            try this.probeExternal(addrs[i], i == 0) {
            } catch (bytes memory err) {
                emit log_named_address("probeFailed", addrs[i]);
                emit log_named_bytes("probeRevert", err);
            }
        }
    }

    function probeExternal(address instance, bool reproducePrimary) external {
        _probe(instance, reproducePrimary);
    }

    function _probe(address instance, bool reproducePrimary) internal {
        uint256 codeLen = instance.code.length;
        bytes32 codehash = instance.codehash;
        emit log_named_address("instance", instance);
        emit log_named_uint("codeLen", codeLen);
        emit log_named_bytes32("codehash", codehash);
        if (codeLen == 0) {
            emit log_string("gate=unavailable (no code)");
            return;
        }
        bool registered = IVaultRegistryVaultQuery(REGISTRY).isVault(instance);
        bool disabled = IVaultRegistryDisableQuery(REGISTRY).isVaultAddressDisabled(instance);
        emit log_named_uint("registered", registered ? 1 : 0);
        emit log_named_uint("disabled", disabled ? 1 : 0);

        try IDiamondLoupe(instance).facets() returns (IDiamondLoupe.Facet[] memory facets) {
            emit log_named_uint("facetCount", facets.length);
            for (uint256 i; i < facets.length; ++i) {
                emit log_named_address("facet", facets[i].facetAddress);
                emit log_named_bytes32("facetRuntimeHash", facets[i].facetAddress.codehash);
                for (uint256 j; j < facets[i].functionSelectors.length; ++j) {
                    emit log_named_bytes32("installedSelector", bytes32(facets[i].functionSelectors[j]));
                }
            }
            try IVaultRegistryDisableQuery(REGISTRY).packageOfVault(instance) returns (address pkg) {
                emit log_named_address("package", pkg);
                emit log_named_bytes32("packageRuntimeHash", pkg.codehash);
            } catch (bytes memory reason) {
                emit log_string("package=unavailable");
                emit log_named_bytes("packageReadFailure", reason);
            }
        } catch {
            emit log_string("loupe=unavailable");
        }

        address[] memory tokens;
        try IVaultTokenView(instance).vaultTokens() returns (address[] memory t) {
            tokens = t;
            emit log_named_uint("tokenCount", t.length);
        } catch {
            emit log_string("vaultTokens=unavailable");
        }

        for (uint256 t; t < tokens.length; ++t) {
            emit log_named_address("token", tokens[t]);
            try IVaultTokenView(instance).reserveOfToken(tokens[t]) returns (uint256 reserved) {
                emit log_named_uint("reserveOfToken", reserved);
            } catch {
                emit log_string("reserveOfToken=unavailable");
            }
            try IERC20(tokens[t]).balanceOf(instance) returns (uint256 held) {
                emit log_named_uint("heldBalance", held);
            } catch {
                emit log_string("balanceOf=unavailable");
            }
        }

        string memory gate = _gateStatus(instance, tokens, disabled, reproducePrimary);
        emit log_string(string.concat("gate=", gate));
    }

    /// @notice Enumerate every registry instance; unknown interfaces and dependency failures remain unavailable.
    function test_APEX_R4_2_enumerateAndClassifyAllRegistryVaults() public {
        address[] memory vaults = IVaultRegistryVaultQuery(REGISTRY).vaults();
        emit log_named_uint("registryVaultCount", vaults.length);
        assertGt(vaults.length, 0);
        uint256 reproduced;
        for (uint256 i; i < vaults.length; ++i) {
            emit log_named_address("classifiedInstance", vaults[i]);
            reproduced += _classifyAndReplay(vaults[i]);
        }
        // This is a vulnerable historical snapshot, not a corrected release assertion.
        assertGt(reproduced, 0, "historical reproduction must reach positive credit without delivery");
    }

    /// @notice Pin the original positive-amount/no-delivery operation on the historical primary instance.
    function test_APEX_R4_3_primaryLiveReproductionAttempt() public {
        assertGt(_classifyAndReplay(UNI_V4_WETH_DTF_OPEN), 0, "primary historical positive-credit reproduction");
    }

    /// @notice Current read-only fork assessment records exposure separately; it never labels arbitrary reverts fixed.
    function test_APEX_R4_5_currentBlockAssessment() public {
        string memory rpcAlias = vm.envOr("APEX_ROBINHOOD_RPC_ALIAS", string("robinhood_mainnet_alchemy"));
        vm.createSelectFork(rpcAlias);
        emit log_named_uint("currentBlock", block.number);
        assertGt(block.number, PINNED_BLOCK);
        assertEq(block.chainid, CHAIN_ID);
        address[] memory instances = _reported();
        for (uint256 i; i < instances.length; ++i) {
            emit log_named_address("currentInstance", instances[i]);
            _classifyAndReplay(instances[i]);
        }
    }

    /// @dev Only two-token historical Uni vaults expose deployedReserve. Other products are explicitly unavailable here.
    function _classifyAndReplay(address instance) internal returns (uint256 reproduced) {
        if (instance.code.length == 0) { emit log_string("gate=unavailable (no code)"); return 0; }
        address[] memory tokens;
        try IVaultTokenView(instance).vaultTokens() returns (address[] memory found) { tokens = found; }
        catch (bytes memory reason) {
            emit log_string("gate=unavailable (token view)"); emit log_named_bytes("reason", reason); return 0;
        }
        if (tokens.length != 2 || tokens[0] >= tokens[1]) {
            emit log_string("gate=unavailable (not a canonical two-token instance)"); return 0;
        }
        uint256 d0;
        uint256 d1;
        try IVaultTokenView(instance).deployedReserve() returns (uint256 a, uint256 b) { d0 = a; d1 = b; }
        catch (bytes memory reason) {
            emit log_string("gate=unavailable (deployed reserve)"); emit log_named_bytes("reason", reason); return 0;
        }
        for (uint256 i; i < 2; ++i) {
            // A failing read is not a safe/closed classification.
            try this.probeLeg(instance, tokens[i], i == 0 ? d0 : d1) returns (uint256 minted) {
                reproduced += minted;
            } catch (bytes memory reason) {
                emit log_string("gate=unavailable (leg probe)"); emit log_named_bytes("reason", reason);
            }
        }
    }

    /// @dev Local-fork state is restored after each probe, so one leg cannot change another's starting state.
    function probeLeg(address instance, address token, uint256 deployed) external returns (uint256 minted) {
        require(msg.sender == address(this), "self only");
        uint256 stored = IVaultTokenView(instance).reserveOfToken(token);
        uint256 held = IERC20(token).balanceOf(instance);
        uint256 faceBooked = stored > deployed ? stored - deployed : 0;
        uint256 available = held > faceBooked ? held - faceBooked : 0;
        emit log_named_address("legToken", token);
        emit log_named_uint("stored", stored);
        emit log_named_uint("deployed", deployed);
        emit log_named_uint("held", held);
        emit log_named_uint("historicalCredit", available);
        if (available == 0) { emit log_string("gate=closed (no positive credit at this block)"); return 0; }
        return _replayDelivery(instance, token, available);
    }

    function _replayDelivery(address instance, address token, uint256 available) internal returns (uint256 minted) {
        uint256 snapshot = vm.snapshotState();
        address caller = address(0xBAD);
        uint256 beforeInput = IERC20(token).balanceOf(caller);
        uint256 beforeShares = IERC20(instance).balanceOf(caller);
        vm.prank(caller);
        (bool ok, bytes memory returned) = instance.call(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(token), available, IERC20(instance), 0, caller, true, block.timestamp)));
        if (ok && returned.length == 32) {
            minted = abi.decode(returned, (uint256));
            assertEq(IERC20(token).balanceOf(caller), beforeInput, "no tokens delivered");
            assertEq(IERC20(instance).balanceOf(caller) - beforeShares, minted, "actual share issuance");
            emit log_string(minted > 0 ? "gate=open (positive issuance without delivery)" : "gate=positive credit but zero issuance");
            emit log_named_uint("unearnedShares", minted);
        } else {
            emit log_string("gate=positive credit; operation rejected (not proven fixed)");
            emit log_named_bytes("operationResult", returned);
        }
        assertTrue(vm.revertToStateAndDelete(snapshot), "probe restores historical state");
    }

    function _gateStatus(address instance, address[] memory, bool disabled, bool reproducePrimary)
        internal returns (string memory)
    {
        if (disabled) emit log_string("registryDisabled=true (not a code fix)");
        uint256 minted = _classifyAndReplay(instance);
        if (reproducePrimary) assertGt(minted, 0, "primary historical reproduction");
        return minted > 0 ? "open (see per-leg evidence)" : "see per-leg classification; no repair inferred";
    }
}
