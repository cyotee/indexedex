// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";
import {LaunchState} from "./LaunchState.sol";

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC20MintBurnOwnableFacet} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol";
import {
    IERC20MintBurnOwnableOperableDFPkg,
    ERC20MintBurnOwnableOperableDFPkg
} from "@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol";

/// @title Phase_07_Stage_01_CoreTestTokens
/// @notice Token DFPkg if needed. Mintable DTF, TTUSDG, TTUSDE, TTWETH. Authorize facade. Premint.
library Phase_07_Stage_01_CoreTestTokens {
    using BetterEfficientHashLib for bytes;

    function execute(LaunchState storage s, address owner_, address uiWallet_) internal {
        IERC20MintBurnOwnableOperableDFPkg tokenPkg = _ensureTokenPkg(s);
        if (!_live(s.ttUSDG)) s.ttUSDG = tokenPkg.deployToken("Test Token USDG", "TTUSDG", 18, owner_, _salt("TTUSDG"));
        if (!_live(s.ttUSDE)) s.ttUSDE = tokenPkg.deployToken("Test Token USDE", "TTUSDE", 18, owner_, _salt("TTUSDE"));
        if (!_live(s.ttWETH)) s.ttWETH = tokenPkg.deployToken("Test Token WETH", "TTWETH", 18, owner_, _salt("TTWETH"));
        if (!_live(s.ttRICH)) s.ttRICH = tokenPkg.deployToken("Test Token DTF", "DTF", 18, owner_, _salt("DTF"));
        _authorizeAndMint(s, s.ttUSDG, owner_, uiWallet_);
        _authorizeAndMint(s, s.ttUSDE, owner_, uiWallet_);
        _authorizeAndMint(s, s.ttWETH, owner_, uiWallet_);
        _authorizeAndMint(s, s.ttRICH, owner_, uiWallet_);
    }

    function _ensureTokenPkg(LaunchState storage s) private returns (IERC20MintBurnOwnableOperableDFPkg tokenPkg) {
        if (_live(s.tokenPkg)) return IERC20MintBurnOwnableOperableDFPkg(s.tokenPkg);
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
        s.tokenPkg = address(tokenPkg);
    }

    function _authorizeAndMint(LaunchState storage s, address token, address owner_, address uiWallet_) private {
        IOperable(token).setOperatorFor(IERC20MintBurn.mint.selector, s.erc20MinterFacade, true);
        IERC20MintBurn(token).mint(owner_, FixtureEconomics.PREMINT);
        IERC20MintBurn(token).mint(uiWallet_, FixtureEconomics.PREMINT);
    }

    function _live(address a) private view returns (bool) {
        return a != address(0) && a.code.length > 0;
    }

    function _salt(string memory symbol) private pure returns (bytes32) {
        return keccak256(abi.encode(FixtureEconomics.SALT_NS, symbol));
    }
}
