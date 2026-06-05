// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                   Foundry                                  */
/* -------------------------------------------------------------------------- */

import { VmSafe } from "forge-std/Vm.sol";

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import "contracts/crane/constants/CraneINITCODE.sol";
import "contracts/crane/constants/Crane_PATHS.sol";
import { WALLET_0_KEY } from "contracts/crane/constants/FoundryConstants.sol";
import { IERC20MintBurn } from "contracts/crane/interfaces/IERC20MintBurn.sol";
import { IERC20MinterFacade } from "contracts/crane/interfaces/IERC20MinterFacade.sol";
import { IOperable } from "contracts/crane/interfaces/IOperable.sol";
import { Script_Crane } from "contracts/crane/script/Script_Crane.sol";

contract Demo_01_Test_Tokens_Script
is
    Script_Crane
{

    VmSafe.Wallet dev0Wallet;

    // string baseDeploymentJson;

    /* ---------------------------------------------------------------------- */
    /*                            Base Test Tokens                            */
    /* ---------------------------------------------------------------------- */

    IERC20MinterFacade erc20MinterFacade_;

    IERC20MintBurn ttA;
    IERC20MintBurn ttB;
    IERC20MintBurn ttC;

    uint256 tokenAInitAmount = 100_000e18;
    uint256 tokenBInitAmount = 100_000e18;
    uint256 tokenCInitAmount = 100_000e18;

    function setUp() public virtual {
        dev0Wallet = vm.createWallet(WALLET_0_KEY);

        // feeCollector(dev0Wallet.addr);
        // uniswapV2FeeTo(feeCollector());
        setOwner(dev0Wallet.addr);
        setDeployer(owner());
        setDeploymentPath(string.concat(LOCAL_DEPLOYMENTS_PATH, DEMO_TOKENS_FILE));
    }

    function run() public virtual
    override(
        Script_Crane
    ) {
        vm.startBroadcast();

        erc20MinterFacade_ = erc20MinterFacade();
        declare("demo", "erc20MinterFacade", address(erc20MinterFacade_));

        /* ------------------------------------------------------------------ */
        /*                          Base Test Tokens                          */
        /* ------------------------------------------------------------------ */

        ttA = erc20MintBurnOperable(owner(), "TestTokenA", "TTA", 18);
        declare("demo", ttA.name(), address(ttA));
        IOperable(address(ttA)).setOperatorFor(
            IERC20MintBurn.mint.selector,
            address(erc20MinterFacade_),
            true
        );

        ttB = erc20MintBurnOperable(owner(), "TestTokenB", "TTB", 18);
        declare("demo", ttB.name(), address(ttB));
        IOperable(address(ttB)).setOperatorFor(
            IERC20MintBurn.mint.selector,
            address(erc20MinterFacade_),
            true
        );


        ttC = erc20MintBurnOperable(owner(), "TestTokenC", "TTC", 18);
        declare("demo", ttC.name(), address(ttC));
        IOperable(address(ttC)).setOperatorFor(
            IERC20MintBurn.mint.selector,
            address(erc20MinterFacade_),
            true
        );
        vm.stopBroadcast();
        writeDeploymentJSON("demo");
    }

}