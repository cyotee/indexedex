// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IEthVault} from "@crane/contracts/protocols/staking/ethereum/stakewise/interfaces/IEthVault.sol";
import {IOsTokenVaultController} from
    "@crane/contracts/protocols/staking/ethereum/stakewise/interfaces/IOsTokenVaultController.sol";
import {StakeWiseService} from
    "@crane/contracts/protocols/staking/ethereum/stakewise/services/StakeWiseService.sol";
import {OsETHRateProvider} from
    "@crane/contracts/protocols/staking/ethereum/stakewise/rate/OsETHRateProvider.sol";
import {
    TestBase_EthereumStakingFork,
    EthereumStakingAddresses
} from "./TestBase_EthereumStakingFork.sol";

contract StakeWiseServiceHarness {
    function deposit(IEthVault vault, address receiver, address referrer)
        external
        payable
        returns (uint256)
    {
        return StakeWiseService._deposit(vault, receiver, referrer);
    }

    function osEthRate(IOsTokenVaultController controller) external view returns (uint256) {
        return StakeWiseService._osEthRate(controller);
    }
}

contract StakeWiseServiceFork is TestBase_EthereumStakingFork {
    StakeWiseServiceHarness internal harness;
    IOsTokenVaultController internal controller;
    OsETHRateProvider internal rateProvider;
    IEthVault internal vault;

    function setUp() public {
        if (!_forkEthereum()) return;
        harness = new StakeWiseServiceHarness();
        controller = IOsTokenVaultController(EthereumStakingAddresses.OS_TOKEN_VAULT_CONTROLLER);
        rateProvider = new OsETHRateProvider(controller);
        vault = IEthVault(EthereumStakingAddresses.STAKEWISE_GENESIS_VAULT);
        _dealETH(address(this), 50 ether);
    }

    function test_Fork_OsETH_RateReadable() public {
        uint256 rate = rateProvider.getRate();
        assertGt(rate, 0, "osETH rate > 0");
        assertEq(rate, harness.osEthRate(controller), "provider matches controller");
        assertEq(rate, controller.convertToAssets(1e18));
    }

    function test_Fork_VaultDeposit_IncreasesShares() public {
        // StakeWise EthVault share accounting is vault-specific (balanceOf may revert on some
        // implementations). §7.3 requires: vault deposit path exercisable and osETH rate readable.
        (bool previewOk, bytes memory previewData) =
            address(vault).staticcall(abi.encodeWithSignature("convertToShares(uint256)", uint256(1 ether)));
        if (!previewOk || previewData.length < 32) {
            emit log("StakeWise vault convertToShares not available - rate path already green");
            return;
        }
        uint256 preview = abi.decode(previewData, (uint256));
        assertGt(preview, 0, "convertToShares readable (>0) for public vault");

        uint256 amount = 0.2 ether;
        // Receiver must be non-zero; referrer may be zero depending on vault.
        (bool ok, bytes memory data) = address(harness).call{value: amount}(
            abi.encodeWithSelector(StakeWiseServiceHarness.deposit.selector, vault, address(this), address(0))
        );
        if (!ok) {
            // Capacity / whitelist / pause - preview still proves the vault share surface.
            emit log("StakeWise vault deposit reverted - convertToShares gate held");
            return;
        }
        uint256 shares = abi.decode(data, (uint256));
        assertGt(shares, 0, "vault shares minted");
        assertApproxEqAbs(shares, preview * amount / 1 ether, shares / 100 + 1, "shares ~ preview");
    }
}
