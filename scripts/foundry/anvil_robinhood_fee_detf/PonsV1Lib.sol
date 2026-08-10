// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {FixtureEconomics} from "./FixtureEconomics.sol";

/// @title IPonsLaunchFactoryV1
/// @notice Minimal ABI surface for pons v1 active factory on Robinhood mainnet.
interface IPonsLaunchFactoryV1 {
    struct Socials {
        string twitter;
        string telegram;
        string discord;
        string website;
        string farcaster;
    }

    struct TokenParams {
        string name;
        string symbol;
        string logo;
        string description;
        Socials socials;
        address feeWallet;
    }

    struct LaunchedToken {
        address token;
        address deployer;
        address pairedToken;
        address positionManager;
        uint256 positionId;
        uint256 dexId;
        uint256 launchConfigId;
        uint256 restrictionsEndBlock;
        uint256 supply;
        bool isToken0;
        uint24 poolFee;
        bool exists;
        uint256 initialBuyAmount;
    }

    event TokenLaunched(
        address indexed token,
        address indexed deployer,
        address indexed dexFactory,
        address pairToken,
        address pool,
        uint256 dexId,
        uint256 launchConfigId,
        uint256 positionId,
        uint256 restrictionsEndBlock,
        uint256 initialBuyAmount
    );

    function launchFee() external view returns (uint256);
    function launchEnabled() external view returns (bool);
    function launchToken(TokenParams calldata params, uint256 launchConfigId, uint256 dexId, bytes32 salt)
        external
        payable
        returns (address token);
    function getLaunchedToken(address token) external view returns (LaunchedToken memory);
}

/// @title IPonsLauncherTokenV1
interface IPonsLauncherTokenV1 {
    function liquidityPool() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

/// @title PonsV1Lib
/// @notice Factory address + launch helpers for stage 04.
library PonsV1Lib {
    function factory() internal pure returns (IPonsLaunchFactoryV1) {
        return IPonsLaunchFactoryV1(FixtureEconomics.PONS_FACTORY);
    }

    function emptySocials() internal pure returns (IPonsLaunchFactoryV1.Socials memory s) {
        s = IPonsLaunchFactoryV1.Socials({
            twitter: "",
            telegram: "",
            discord: "",
            website: "",
            farcaster: ""
        });
    }

    function richParams(address feeWallet)
        internal
        pure
        returns (IPonsLaunchFactoryV1.TokenParams memory params)
    {
        params = IPonsLaunchFactoryV1.TokenParams({
            name: FixtureEconomics.RICH_NAME,
            symbol: FixtureEconomics.RICH_SYMBOL,
            logo: "",
            description: "IndexedEx fee-DETF launch pair token (pons v1)",
            socials: emptySocials(),
            feeWallet: feeWallet
        });
    }
}
