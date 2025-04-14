// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {BaseProtocolDETFRepo} from "contracts/vaults/protocol/BaseProtocolDETFRepo.sol";
import {IBaseProtocolDETFDFPkg} from "contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol";
import {IEthereumProtocolDETFDFPkg} from "contracts/vaults/protocol/EthereumProtocolDETFDFPkg.sol";
import {ProtocolDETFIntegrationBase as BaseIntegration} from "./ProtocolDETF_IntegrationBase.t.sol";
import {ProtocolDETFIntegrationBase as EthereumIntegration} from "./EthereumProtocolDETF_IntegrationBase.t.sol";

abstract contract ProtocolDETFBaseCustomFixtureHelpers is BaseIntegration {
    function _deployCustomDetf(uint256 richInitialDeposit, uint256 wethInitialDeposit)
        internal
        returns (IProtocolDETF customDetf)
    {
        _mintWeth(owner, wethInitialDeposit);

        vm.startPrank(owner);

        IBaseProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Protocol DETF Custom";
        pkgArgs.symbol = "CHIR-CUSTOM";
        pkgArgs.funder = owner;
        pkgArgs.owner = owner;
        pkgArgs.protocolConfig = BaseProtocolDETFRepo.ProtocolConfig({
            richToken: address(rich),
            richInitialDepositAmount: richInitialDeposit,
            richMintChirPercent: 1e18,
            wethToken: address(weth9),
            wethInitialDepositAmount: wethInitialDeposit,
            wethMintChirPercent: 1e18
        });

        customDetf = IProtocolDETF(
            IVaultRegistryDeployment(address(indexedexManager)).deployVault(
                IStandardVaultPkg(address(protocolDETFDFPkg)),
                abi.encode(pkgArgs)
            )
        );

        vm.stopPrank();
    }

    function _deployMintEnabledDetf() internal returns (IProtocolDETF customDetf) {
        return _deployCustomDetf(100_000e18, 10_000_000e18);
    }

    function _deployDeadbandDetf() internal returns (IProtocolDETF customDetf) {
        return _deployCustomDetf(250_000e18, 1_000_000e18);
    }

    function _assertMintEnabled(IProtocolDETF detf_) internal view {
        assertLt(detf_.syntheticPrice(), detf_.burnThreshold(), "fixture should be below lower deadband bound");
        assertTrue(detf_.isMintingAllowed(), "minting should be enabled");
        assertFalse(detf_.isBurningAllowed(), "burning should be disabled");
    }

    function _assertDeadband(IProtocolDETF detf_) internal view {
        uint256 price = detf_.syntheticPrice();
        assertGe(price, detf_.burnThreshold(), "fixture should be above lower deadband bound");
        assertLe(price, detf_.mintThreshold(), "fixture should be below upper deadband bound");
        assertFalse(detf_.isMintingAllowed(), "minting should be disabled in deadband");
        assertFalse(detf_.isBurningAllowed(), "burning should be disabled in deadband");
    }
}

abstract contract ProtocolDETFEthereumCustomFixtureHelpers is EthereumIntegration {
    function _deployCustomEthereumDetf(uint256 richInitialDeposit, uint256 wethInitialDeposit)
        internal
        returns (IProtocolDETF customDetf)
    {
        _mintWeth(owner, wethInitialDeposit);

        vm.startPrank(owner);

        IEthereumProtocolDETFDFPkg.PkgArgs memory pkgArgs;
        pkgArgs.name = "Ethereum Protocol DETF Custom";
        pkgArgs.symbol = "eCHIR-CUSTOM";
        pkgArgs.funder = owner;
        pkgArgs.protocolConfig = BaseProtocolDETFRepo.ProtocolConfig({
            richToken: address(rich),
            richInitialDepositAmount: richInitialDeposit,
            richMintChirPercent: 1e18,
            wethToken: address(weth9),
            wethInitialDepositAmount: wethInitialDeposit,
            wethMintChirPercent: 1e18
        });

        customDetf = IProtocolDETF(
            IVaultRegistryDeployment(address(indexedexManager)).deployVault(
                IStandardVaultPkg(address(protocolDETFDFPkg)),
                abi.encode(pkgArgs)
            )
        );

        vm.stopPrank();
    }

    function _deployMintEnabledEthereumDetf() internal returns (IProtocolDETF customDetf) {
        return _deployCustomEthereumDetf(100_000e18, 10_000_000e18);
    }

    function _deployDeadbandEthereumDetf() internal returns (IProtocolDETF customDetf) {
        return _deployCustomEthereumDetf(250_000e18, 1_000_000e18);
    }

    function _assertMintEnabled(IProtocolDETF detf_) internal view {
        assertLt(detf_.syntheticPrice(), detf_.burnThreshold(), "fixture should be below lower deadband bound");
        assertTrue(detf_.isMintingAllowed(), "minting should be enabled");
        assertFalse(detf_.isBurningAllowed(), "burning should be disabled");
    }

    function _assertDeadband(IProtocolDETF detf_) internal view {
        uint256 price = detf_.syntheticPrice();
        assertGe(price, detf_.burnThreshold(), "fixture should be above lower deadband bound");
        assertLe(price, detf_.mintThreshold(), "fixture should be below upper deadband bound");
        assertFalse(detf_.isMintingAllowed(), "minting should be disabled in deadband");
        assertFalse(detf_.isBurningAllowed(), "burning should be disabled in deadband");
    }

    function _driveEthereumToMintEnabled(IProtocolDETF detf_) internal {
        if (detf_.isMintingAllowed()) {
            return;
        }

        _driveEthereumToDeadband(detf_);

        uint256 iterations = 0;
        while (!detf_.isMintingAllowed()) {
            _swapWethToRich(detf_, 25_000e18);
            iterations++;
            require(iterations < 20, "unable to push Ethereum DETF below lower deadband");
        }

        _assertMintEnabled(detf_);
    }

    function _driveEthereumToDeadband(IProtocolDETF detf_) internal {
        if (detf_.syntheticPrice() <= detf_.mintThreshold() && detf_.syntheticPrice() >= detf_.burnThreshold()) {
            _assertDeadband(detf_);
            return;
        }

        _mintWeth(detfAlice, 10_000_000e18);

        uint256[] memory steps = new uint256[](6);
        steps[0] = 1_000_000e18;
        steps[1] = 500_000e18;
        steps[2] = 250_000e18;
        steps[3] = 100_000e18;
        steps[4] = 50_000e18;
        steps[5] = 10_000e18;

        uint256 outerIterations = 0;
        while (detf_.syntheticPrice() > detf_.mintThreshold()) {
            bool applied;

            for (uint256 i = 0; i < steps.length; ++i) {
                uint256 snap = vm.snapshotState();
                _swapWethToRich(detf_, steps[i]);
                uint256 newPrice = detf_.syntheticPrice();

                if (newPrice < detf_.burnThreshold()) {
                    vm.revertToState(snap);
                    continue;
                }

                applied = true;
                break;
            }

            require(applied, "unable to move Ethereum DETF into deadband");
            outerIterations++;
            require(outerIterations < 20, "too many iterations seeking Ethereum deadband");
        }

        _assertDeadband(detf_);
    }

    function _swapWethToRich(IProtocolDETF detf_, uint256 amountIn_) internal returns (uint256 richOut_) {
        vm.startPrank(detfAlice);
        IERC20(address(weth9)).approve(address(detf_), type(uint256).max);
        richOut_ = IStandardExchangeIn(address(detf_)).exchangeIn(
            IERC20(address(weth9)),
            amountIn_,
            rich,
            0,
            detfAlice,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}