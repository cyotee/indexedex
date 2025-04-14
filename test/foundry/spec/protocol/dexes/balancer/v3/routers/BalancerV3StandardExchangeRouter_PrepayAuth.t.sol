// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IBalancerV3StandardExchangeRouterPrepayHooks
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepayHooks.sol";
import {
    IBalancerV3StandardExchangeRouterExactInSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwap.sol";
import {
    IBalancerV3StandardExchangeRouterExactInSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactInSwapQuery.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwap
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwap.sol";
import {
    IBalancerV3StandardExchangeRouterExactOutSwapQuery
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterExactOutSwapQuery.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactIn
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactIn.sol";
import {
    IBalancerV3StandardExchangeBatchRouterExactOut
} from "contracts/interfaces/IBalancerV3StandardExchangeBatchRouterExactOut.sol";
import {ISenderGuard} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/ISenderGuard.sol";

import {
    IBalancerV3StandardExchangeRouterDFPkg
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterDFPkg.sol";

import {
    BalancerV3StandardExchangeRouterRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterRepo.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";
import {WETHAwareRepo} from "@crane/contracts/protocols/tokens/wrappers/weth/v9/WETHAwareRepo.sol";

import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";

/* -------------------------------------------------------------------------- */
/*                    Test Harness: Set transient token                         */
/* -------------------------------------------------------------------------- */

interface IPrepayAuthHarness {
    function callWithCurrentSE(IStandardExchangeProxy current, address target, bytes calldata data)
        external
        returns (bytes memory);
}

contract PrepayAuthHarnessFacet is IFacet, IPrepayAuthHarness {
    using BalancerV3StandardExchangeRouterRepo for *;

    function facetName() public pure returns (string memory) {
        return type(PrepayAuthHarnessFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IPrepayAuthHarness).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IPrepayAuthHarness.callWithCurrentSE.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }

    function callWithCurrentSE(IStandardExchangeProxy current, address target, bytes calldata data)
        external
        returns (bytes memory)
    {
        BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(current);

        (bool ok, bytes memory ret) = target.call(data);

        BalancerV3StandardExchangeRouterRepo._setCurrentStandardExchangeToken(IStandardExchangeProxy(address(0)));

        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }

        return ret;
    }
}

/* -------------------------------------------------------------------------- */
/*                       DFPkg with Harness                                    */
/* -------------------------------------------------------------------------- */

contract PrepayAuthDFPkg is IBalancerV3StandardExchangeRouterDFPkg {
    struct PrepayAuthPkgInit {
        IFacet senderGuardFacet;
        IFacet exactInQueryFacet;
        IFacet exactOutQueryFacet;
        IFacet exactInSwapFacet;
        IFacet exactOutSwapFacet;
        IFacet prepayFacet;
        IFacet prepayHooksFacet;
        IFacet batchExactInFacet;
        IFacet batchExactOutFacet;
        IFacet harnessFacet;
        IVault balancerV3Vault;
        IPermit2 permit2;
        IWETH weth;
    }

    IFacet[10] public FACETS;
    IVault public immutable BAL_VAULT;
    IPermit2 public immutable PERMIT2;
    IWETH public immutable WETH;

    constructor(PrepayAuthPkgInit memory p) {
        FACETS[0] = p.senderGuardFacet;
        FACETS[1] = p.exactInQueryFacet;
        FACETS[2] = p.exactOutQueryFacet;
        FACETS[3] = p.exactInSwapFacet;
        FACETS[4] = p.exactOutSwapFacet;
        FACETS[5] = p.prepayFacet;
        FACETS[6] = p.prepayHooksFacet;
        FACETS[7] = p.batchExactInFacet;
        FACETS[8] = p.batchExactOutFacet;
        FACETS[9] = p.harnessFacet;
        BAL_VAULT = p.balancerV3Vault;
        PERMIT2 = p.permit2;
        WETH = p.weth;
    }

    function packageName() public pure returns (string memory) {
        return type(PrepayAuthDFPkg).name;
    }

    function facetAddresses() public view returns (address[] memory f) {
        f = new address[](10);
        for (uint256 i; i < 10; i++) {
            f[i] = address(FACETS[i]);
        }
    }

    function facetInterfaces() public pure returns (bytes4[] memory ifaces) {
        ifaces = new bytes4[](9);
        ifaces[0] = type(ISenderGuard).interfaceId;
        ifaces[1] = type(IBalancerV3StandardExchangeRouterExactInSwap).interfaceId;
        ifaces[2] = type(IBalancerV3StandardExchangeRouterExactInSwapQuery).interfaceId;
        ifaces[3] = type(IBalancerV3StandardExchangeRouterExactOutSwap).interfaceId;
        ifaces[4] = type(IBalancerV3StandardExchangeRouterExactOutSwapQuery).interfaceId;
        ifaces[5] = type(IBalancerV3StandardExchangeBatchRouterExactIn).interfaceId;
        ifaces[6] = type(IBalancerV3StandardExchangeBatchRouterExactOut).interfaceId;
        ifaces[7] = type(IBalancerV3StandardExchangeRouterPrepay).interfaceId;
        ifaces[8] = type(IBalancerV3StandardExchangeRouterPrepayHooks).interfaceId;
    }

    function packageMetadata() public view returns (string memory, bytes4[] memory, address[] memory) {
        return (packageName(), facetInterfaces(), facetAddresses());
    }

    function facetCuts() public view returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](10);
        for (uint256 i; i < 10; i++) {
            cuts[i] = IDiamond.FacetCut({
                facetAddress: address(FACETS[i]),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: FACETS[i].facetFuncs()
            });
        }
    }

    function diamondConfig() public view returns (DiamondConfig memory) {
        return DiamondConfig({facetCuts: facetCuts(), interfaces: facetInterfaces()});
    }

    function calcSalt(bytes memory) public pure returns (bytes32) {
        return keccak256(abi.encode(packageName()));
    }

    function processArgs(bytes memory) public pure returns (bytes memory) {
        return "";
    }

    function updatePkg(address, bytes memory) public pure returns (bool) {
        return true;
    }

    function initAccount(bytes memory) public {
        BalancerV3VaultAwareRepo._initialize(BAL_VAULT);
        Permit2AwareRepo._initialize(PERMIT2);
        WETHAwareRepo._initialize(WETH);
    }

    function postDeploy(address) public pure returns (bool) {
        return true;
    }
}

/* -------------------------------------------------------------------------- */
/*                        Attacker Contracts                                   */
/* -------------------------------------------------------------------------- */

/// @notice EOA-like attacker (deployed at an address but used to simulate unauthorized callers)
contract PrepayAuthAttacker {
    function attack(address router, address pool, uint256[] calldata amounts, uint256 minBpt) external {
        IBalancerV3StandardExchangeRouterPrepay(router).prepayAddLiquidityUnbalanced(pool, amounts, minBpt, "");
    }
}

/* -------------------------------------------------------------------------- */
/*                               Test Contract                                 */
/* -------------------------------------------------------------------------- */

/**
 * @title BalancerV3StandardExchangeRouter_PrepayAuth_Test
 * @notice Tests for the onlyUnlockedOrSEToken modifier on prepay functions.
 * @dev Covers US-IDXEX-037.4:
 *      - When Vault unlocked, any caller can invoke prepay
 *      - When Vault locked + current token set, only that token can call
 *      - When Vault locked + no token, only contracts can call (EOAs blocked)
 */
contract BalancerV3StandardExchangeRouter_PrepayAuth_Test is TestBase_BalancerV3StandardExchangeRouter {
    IFacet internal harnessFacet;
    IPrepayAuthHarness internal harness;
    IBalancerV3StandardExchangeRouterPrepay internal prepayRouter;

    function _deployRouterFacets() internal override {
        super._deployRouterFacets();
        harnessFacet = IFacet(address(new PrepayAuthHarnessFacet()));
    }

    function _deployRouterPackage() internal override {
        PrepayAuthDFPkg.PrepayAuthPkgInit memory p;
        p.senderGuardFacet = senderGuardFacet;
        p.exactInQueryFacet = exactInQueryFacet;
        p.exactOutQueryFacet = exactOutQueryFacet;
        p.exactInSwapFacet = exactInSwapFacet;
        p.exactOutSwapFacet = exactOutSwapFacet;
        p.prepayFacet = prepayFacet;
        p.prepayHooksFacet = prepayHooksFacet;
        p.batchExactInFacet = batchExactInFacet;
        p.batchExactOutFacet = batchExactOutFacet;
        p.harnessFacet = harnessFacet;
        p.balancerV3Vault = IVault(address(vault));
        p.permit2 = permit2;
        p.weth = IWETH(address(weth));

        seRouterDFPkg = IBalancerV3StandardExchangeRouterDFPkg(address(new PrepayAuthDFPkg(p)));
    }

    function setUp() public override {
        super.setUp();
        harness = IPrepayAuthHarness(address(seRouter));
        prepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(seRouter));
    }

    /* ---------------------------------------------------------------------- */
    /*   Test A: Vault unlocked → any caller can invoke prepay                 */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice When the Balancer V3 vault is in an unlocked state (i.e., inside
     *         a vault.unlock() callback), any caller should be able to invoke
     *         prepay functions. This is the normal prepay usage pattern.
     */
    function test_prepayAuth_vaultUnlocked_anyCallerSucceeds() public {
        // Mint tokens and transfer to vault for prepay settlement
        dai.mint(address(this), 100e18);
        usdc.mint(address(this), 100e18);
        dai.transfer(address(vault), 100e18);
        usdc.transfer(address(vault), 100e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 100e18;

        // Call via vault.unlock() which puts vault in unlocked state
        bytes memory result = vault.unlock(abi.encodeCall(this._addLiquidityCallback, (daiUsdcPool, amounts)));

        uint256 bpt = abi.decode(result, (uint256));
        assertGt(bpt, 0, "Should receive BPT when vault is unlocked");
    }

    /* ---------------------------------------------------------------------- */
    /*   Test B: Vault locked + token set → only that token can call           */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice When the vault is locked and currentStandardExchangeToken is set,
     *         only the exact token address can call prepay. Any other address
     *         reverts with NotCurrentStandardExchangeToken.
     */
    function test_prepayAuth_locked_wrongCaller_reverts() public {
        // Vault should be locked in normal context
        assertFalse(vault.isUnlocked(), "Precondition: vault should be locked");

        PrepayAuthAttacker attacker = new PrepayAuthAttacker();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // Set currentStandardExchangeToken to daiUsdcVault, then call from attacker
        vm.expectRevert(
            abi.encodeWithSelector(
                IBalancerV3StandardExchangeRouterPrepay.NotCurrentStandardExchangeToken.selector,
                address(attacker),
                address(daiUsdcVault)
            )
        );

        harness.callWithCurrentSE(
            daiUsdcVault,
            address(attacker),
            abi.encodeCall(attacker.attack, (address(seRouter), daiUsdcPool, amounts, 1))
        );
    }

    /**
     * @notice When the vault is locked and currentStandardExchangeToken is set
     *         to a specific vault, calling from that exact vault address should
     *         be allowed (it won't revert with NotCurrentStandardExchangeToken).
     */
    function test_prepayAuth_locked_correctCaller_noAuthRevert() public {
        assertFalse(vault.isUnlocked(), "Precondition: vault should be locked");

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // The call from the correct token address should not revert with
        // NotCurrentStandardExchangeToken. It may revert for other reasons
        // (e.g., vault locked for actual liquidity ops), but not the auth check.
        // We use low-level call to check the revert reason.
        bytes memory callData = abi.encodeCall(prepayRouter.prepayAddLiquidityUnbalanced, (daiUsdcPool, amounts, 1, ""));

        // Set currentStandardExchangeToken to daiUsdcVault, call from daiUsdcVault
        try harness.callWithCurrentSE(
            daiUsdcVault,
            address(daiUsdcVault),
            abi.encodeWithSignature("proxyCallRouter(address,bytes)", address(seRouter), callData)
        ) {
        // If it succeeds, great
        }
        catch (bytes memory reason) {
            // If it reverts, it should NOT be NotCurrentStandardExchangeToken
            if (reason.length >= 4) {
                bytes4 errorSelector = bytes4(reason);
                assertTrue(
                    errorSelector != IBalancerV3StandardExchangeRouterPrepay.NotCurrentStandardExchangeToken.selector,
                    "Should not revert with NotCurrentStandardExchangeToken when caller matches"
                );
            }
        }
    }

    /* ---------------------------------------------------------------------- */
    /*   Test C: Vault locked + no token → EOAs blocked                        */
    /* ---------------------------------------------------------------------- */

    /**
     * @notice When the vault is locked and no currentStandardExchangeToken is set,
     *         EOA callers are blocked. msg.sender.code.length == 0 for EOAs.
     */
    function test_prepayAuth_locked_noToken_eoaBlocked() public {
        assertFalse(vault.isUnlocked(), "Precondition: vault should be locked");

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // Alice is an EOA (no code)
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBalancerV3StandardExchangeRouterPrepay.NotCurrentStandardExchangeToken.selector, alice, address(0)
            )
        );
        prepayRouter.prepayAddLiquidityUnbalanced(daiUsdcPool, amounts, 1, "");
        vm.stopPrank();
    }

    /**
     * @notice When the vault is locked and no currentStandardExchangeToken is set,
     *         contract callers are allowed (msg.sender.code.length > 0).
     *         This supports trusted vault→router interactions.
     */
    function test_prepayAuth_locked_noToken_contractAllowed() public {
        assertFalse(vault.isUnlocked(), "Precondition: vault should be locked");

        // Create an attacker contract (has code)
        PrepayAuthAttacker contractCaller = new PrepayAuthAttacker();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // Contract caller with no current SE token set should NOT revert with
        // NotCurrentStandardExchangeToken (it's allowed past the auth check).
        // It will likely revert for other reasons (vault locked for liquidity ops).
        try contractCaller.attack(address(seRouter), daiUsdcPool, amounts, 1) {
        // If it succeeds, the auth check passed
        }
        catch (bytes memory reason) {
            // If it reverts, verify it's NOT NotCurrentStandardExchangeToken
            if (reason.length >= 4) {
                bytes4 errorSelector = bytes4(reason);
                assertTrue(
                    errorSelector != IBalancerV3StandardExchangeRouterPrepay.NotCurrentStandardExchangeToken.selector,
                    "Contract caller should pass auth check even without current SE token"
                );
            }
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         Callback Functions                              */
    /* ---------------------------------------------------------------------- */

    function _addLiquidityCallback(address pool, uint256[] memory amounts) external returns (uint256 bptAmountOut) {
        return prepayRouter.prepayAddLiquidityUnbalanced(pool, amounts, 1, "");
    }
}
