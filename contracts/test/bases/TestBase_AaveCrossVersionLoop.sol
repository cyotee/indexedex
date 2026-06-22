// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {OperableFacet} from "@crane/contracts/access/operable/OperableFacet.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";
import {
    IERC20MintBurnOwnableOperableDFPkg,
    ERC20MintBurnOwnableOperableDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";

/**
 * @title TestBase_AaveCrossVersionLoop
 * @author cyotee doge <doge.cyotee>
 * @notice Test base for the Aave V3.6 / V4 cross-version carry loop vault. Deploys the two pair
 *         test tokens via `ERC20MintBurnOwnableOperableDFPkg` (per project direction) so tests can
 *         mint freely to seed Aave liquidity and fund users.
 * @dev Local Aave V3.6 + V4 markets are wired by subclasses (see plan: Crane V4 setup/Base +
 *      V3 AaveV3BatchOrchestration), enabling deterministic profitable-loop tests with tunable rates.
 */
contract TestBase_AaveCrossVersionLoop is TestBase_VaultComponents {
    IFacet internal operableFacet;
    IFacet internal erc20MintBurnOwnableFacet;

    IERC20MintBurnOwnableOperableDFPkg internal testTokenPkg;

    IERC20 internal tokenA;
    IERC20 internal tokenB;

    function setUp() public virtual override {
        TestBase_VaultComponents.setUp();
        _deployTestTokenPkg();

        // tokenA 18dp (e.g. a WETH-like), tokenB 6dp (e.g. a USDC-like) to exercise decimal handling.
        tokenA = IERC20(
            testTokenPkg.deployToken("Cross Loop Token A", "CLTA", 18, address(this), keccak256("CLTA"))
        );
        tokenB = IERC20(
            testTokenPkg.deployToken("Cross Loop Token B", "CLTB", 6, address(this), keccak256("CLTB"))
        );
    }

    /// @dev Wires the mint/burn/ownable/operable test-token package from shared + local facets.
    function _deployTestTokenPkg() internal {
        operableFacet = IFacet(
            create3Factory.deployFacet(
                type(OperableFacet).creationCode, keccak256("AaveCrossVersionLoop_OperableFacet")
            )
        );
        erc20MintBurnOwnableFacet = IFacet(
            create3Factory.deployFacet(
                type(ERC20MintBurnOwnableFacet).creationCode,
                keccak256("AaveCrossVersionLoop_ERC20MintBurnOwnableFacet")
            )
        );

        IERC20MintBurnOwnableOperableDFPkg.PkgInit memory pkgInit = IERC20MintBurnOwnableOperableDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            erc20MintBurnOwnableFacet: erc20MintBurnOwnableFacet,
            mutiStepOwnableFacet: multiStepOwnableFacet,
            operableFacet: operableFacet,
            diamondFactory: diamondPackageFactory
        });

        testTokenPkg = IERC20MintBurnOwnableOperableDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(ERC20MintBurnOwnableOperableDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256("AaveCrossVersionLoop_TestTokenPkg")
                )
            )
        );
    }

    /// @dev Mint helper (test contract is the token owner).
    function _mint(IERC20 token, address to, uint256 amount) internal {
        IERC20MintBurn(address(token)).mint(to, amount);
    }
}
