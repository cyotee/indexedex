// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IERC20MinterFacade} from "@crane/contracts/tokens/ERC20/IERC20MinterFacade.sol";
import {
    ERC20MinterFacadeFacetDFPkg,
    IERC20MinterFacadeFacetDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20MinterFacadeFacetDFPkg.sol";

/// @title Phase_04_Stage_02_Erc20MinterFacade
/// @notice Minter Facade diamond/package only. No test tokens.
library Phase_04_Stage_02_Erc20MinterFacade {
    using BetterEfficientHashLib for bytes;

    function execute(LaunchState storage s) internal {
        IERC20MinterFacadeFacetDFPkg facadePkg = IERC20MinterFacadeFacetDFPkg(
            address(
                s.create3Factory.deployPackage(
                    type(ERC20MinterFacadeFacetDFPkg).creationCode,
                    abi.encode(type(ERC20MinterFacadeFacetDFPkg).name, FixtureEconomics.SALT_NS)._hash()
                )
            )
        );
        s.erc20MinterFacade = address(
            IERC20MinterFacade(
                s.diamondPackageFactory.deploy(
                    facadePkg,
                    abi.encode(
                        IERC20MinterFacadeFacetDFPkg.PkgArgs({
                            maxMintAmount: FixtureEconomics.FACADE_MAX_MINT,
                            minMintInterval: FixtureEconomics.FACADE_MIN_INTERVAL
                        })
                    )
                )
            )
        );
    }
}
