// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";
import {
    IERC20MintBurnOwnableOperableDFPkg,
    ERC20MintBurnOwnableOperableDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol";
import {IERC20MinterFacade} from "@crane/contracts/tokens/ERC20/IERC20MinterFacade.sol";
import {
    ERC20MinterFacadeFacetDFPkg,
    IERC20MinterFacadeFacetDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20MinterFacadeFacetDFPkg.sol";

/// @title Stage_04_Tokens
/// @notice Required `DTF` plus mintable stand-ins `TTUSDG` / `TTUSDE` / `TTWETH` + facade + 1e12 to #0 and #1.
library Stage_04_Tokens {
    using BetterEfficientHashLib for bytes;

    function execute(LaunchState storage s, address owner_, address uiWallet_) internal {
        IERC20MintBurnOwnableOperableDFPkg tokenPkg = _deployTokenPkg(s);
        s.tokenPkg = address(tokenPkg);

        s.ttUSDG = tokenPkg.deployToken("Test Token USDG", "TTUSDG", 18, owner_, _salt("TTUSDG"));
        s.ttUSDE = tokenPkg.deployToken("Test Token USDE", "TTUSDE", 18, owner_, _salt("TTUSDE"));
        s.ttWETH = tokenPkg.deployToken("Test Token WETH", "TTWETH", 18, owner_, _salt("TTWETH"));

        s.erc20MinterFacade = address(_deployFacade(s));
        deployAndMintTtrich(s, owner_, uiWallet_);
        _authorizeAndMint(s, s.ttUSDG, owner_, uiWallet_);
        _authorizeAndMint(s, s.ttUSDE, owner_, uiWallet_);
        _authorizeAndMint(s, s.ttWETH, owner_, uiWallet_);
    }

    function _deployTokenPkg(LaunchState storage s) private returns (IERC20MintBurnOwnableOperableDFPkg tokenPkg) {
        IFacet mintBurnOwnableFacet = s.create3Factory.deployFacet(
            type(ERC20MintBurnOwnableFacet).creationCode,
            abi.encode(type(ERC20MintBurnOwnableFacet).name, FixtureEconomics.SALT_NS)._hash()
        );
        IERC20MintBurnOwnableOperableDFPkg.PkgInit memory pkgInit;
        pkgInit.erc20Facet = s.erc20Facet;
        pkgInit.erc5267Facet = s.erc5267Facet;
        pkgInit.erc2612Facet = s.erc2612Facet;
        pkgInit.erc20MintBurnOwnableFacet = mintBurnOwnableFacet;
        pkgInit.mutiStepOwnableFacet = s.multiStepOwnableFacet;
        pkgInit.operableFacet = s.operableFacet;
        pkgInit.diamondFactory = s.diamondPackageFactory;
        tokenPkg = IERC20MintBurnOwnableOperableDFPkg(
            address(
                s.create3Factory.deployPackageWithArgs(
                    type(ERC20MintBurnOwnableOperableDFPkg).creationCode,
                    abi.encode(pkgInit),
                    abi.encode(type(ERC20MintBurnOwnableOperableDFPkg).name, FixtureEconomics.SALT_NS)._hash()
                )
            )
        );
    }

    function _deployFacade(LaunchState storage s) private returns (IERC20MinterFacade facade) {
        IERC20MinterFacadeFacetDFPkg facadePkg = IERC20MinterFacadeFacetDFPkg(
            address(
                s.create3Factory.deployPackage(
                    type(ERC20MinterFacadeFacetDFPkg).creationCode,
                    abi.encode(type(ERC20MinterFacadeFacetDFPkg).name, FixtureEconomics.SALT_NS)._hash()
                )
            )
        );
        facade = IERC20MinterFacade(
            s.diamondPackageFactory.deploy(
                facadePkg,
                abi.encode(
                    IERC20MinterFacadeFacetDFPkg.PkgArgs({
                        maxMintAmount: FixtureEconomics.FACADE_MAX_MINT,
                        minMintInterval: FixtureEconomics.FACADE_MIN_INTERVAL
                    })
                )
            )
        );
    }

    function _authorizeAndMint(LaunchState storage s, address token, address owner_, address uiWallet_) private {
        IOperable(token).setOperatorFor(IERC20MintBurn.mint.selector, s.erc20MinterFacade, true);
        // D33 1e12 exceeds facade maxMint (10e6). Owner mints inventory; facade stays on for /mint.
        IERC20MintBurn(token).mint(owner_, FixtureEconomics.PREMINT);
        IERC20MintBurn(token).mint(uiWallet_, FixtureEconomics.PREMINT);
    }

    /// @notice Required architecture token. Resume-safe if `DTF` is missing from an older 04 artifact.
    function deployAndMintTtrich(LaunchState storage s, address owner_, address uiWallet_) internal {
        require(s.tokenPkg != address(0), "Stage_04: tokenPkg missing");
        require(s.erc20MinterFacade != address(0), "Stage_04: facade missing");
        if (s.ttRICH != address(0) && s.ttRICH.code.length > 0) return;
        IERC20MintBurnOwnableOperableDFPkg tokenPkg = IERC20MintBurnOwnableOperableDFPkg(s.tokenPkg);
        s.ttRICH = tokenPkg.deployToken("Test Token DTF", "DTF", 18, owner_, _salt("DTF"));
        _authorizeAndMint(s, s.ttRICH, owner_, uiWallet_);
    }

    /// @notice Mintable ETH stand-in. Public RH testnet faucet ETH is not enough to wrap canonical WETH for pool seed.
    function deployAndMintTtweth(LaunchState storage s, address owner_, address uiWallet_) internal {
        require(s.tokenPkg != address(0), "Stage_04: tokenPkg missing");
        require(s.erc20MinterFacade != address(0), "Stage_04: facade missing");
        if (s.ttWETH != address(0) && s.ttWETH.code.length > 0) return;
        IERC20MintBurnOwnableOperableDFPkg tokenPkg = IERC20MintBurnOwnableOperableDFPkg(s.tokenPkg);
        s.ttWETH = tokenPkg.deployToken("Test Token WETH", "TTWETH", 18, owner_, _salt("TTWETH"));
        _authorizeAndMint(s, s.ttWETH, owner_, uiWallet_);
    }

    function _salt(string memory symbol) private pure returns (bytes32) {
        return keccak256(abi.encode(FixtureEconomics.SALT_NS, symbol));
    }
}
