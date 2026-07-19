// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {ISenderGuard} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/ISenderGuard.sol";

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
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {
    IBalancerV3StandardExchangeRouterPrepayHooks
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepayHooks.sol";
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

/**
 * @notice Harness: start production prepay session, push principal, call target, always end session.
 * @dev Uses the same Repo functions production swap hooks use (`_sessionBegin` / `_pushPrepayAuth` / `_sessionEnd`).
 */
interface IPrepaySessionHarness {
    function withPrepaySession(address principal, address target, bytes calldata data)
        external
        returns (bytes memory result);
}

contract PrepaySessionHarnessFacet is IFacet, IPrepaySessionHarness {
    function facetName() public pure returns (string memory) {
        return type(PrepaySessionHarnessFacet).name;
    }

    function facetInterfaces() public pure override returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IPrepaySessionHarness).interfaceId;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](1);
        funcs[0] = IPrepaySessionHarness.withPrepaySession.selector;
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

    /// @inheritdoc IPrepaySessionHarness
    function withPrepaySession(address principal, address target, bytes calldata data)
        external
        returns (bytes memory result)
    {
        BalancerV3StandardExchangeRouterRepo._sessionBegin();
        if (principal != address(0)) {
            BalancerV3StandardExchangeRouterRepo._pushPrepayAuth(principal);
        }
        (bool ok, bytes memory ret) = target.call(data);
        BalancerV3StandardExchangeRouterRepo._sessionEnd();
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        return ret;
    }
}

contract PrepaySessionHarnessDFPkg is IBalancerV3StandardExchangeRouterDFPkg {
    struct PkgInitH {
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

    constructor(PkgInitH memory p) {
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
        return type(PrepaySessionHarnessDFPkg).name;
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

/**
 * @title TestBase_PrepaySessionHarness
 * @notice Production router TestBase + harness facet for mid-session prepay auth probes.
 */
abstract contract TestBase_PrepaySessionHarness is TestBase_BalancerV3StandardExchangeRouter {
    IFacet internal prepaySessionHarnessFacet;
    IPrepaySessionHarness internal prepaySessionHarness;
    IBalancerV3StandardExchangeRouterPrepay internal prepayRouter;

    function _deployRouterFacets() internal virtual override {
        super._deployRouterFacets();
        prepaySessionHarnessFacet = IFacet(
            create3Factory.deployFacet(
                type(PrepaySessionHarnessFacet).creationCode,
                keccak256(abi.encode(type(PrepaySessionHarnessFacet).name))
            )
        );
        vm.label(address(prepaySessionHarnessFacet), "PrepaySessionHarnessFacet");
    }

    function _deployRouterPackage() internal virtual override {
        PrepaySessionHarnessDFPkg.PkgInitH memory p;
        p.senderGuardFacet = senderGuardFacet;
        p.exactInQueryFacet = exactInQueryFacet;
        p.exactOutQueryFacet = exactOutQueryFacet;
        p.exactInSwapFacet = exactInSwapFacet;
        p.exactOutSwapFacet = exactOutSwapFacet;
        p.prepayFacet = prepayFacet;
        p.prepayHooksFacet = prepayHooksFacet;
        p.batchExactInFacet = batchExactInFacet;
        p.batchExactOutFacet = batchExactOutFacet;
        p.harnessFacet = prepaySessionHarnessFacet;
        p.balancerV3Vault = IVault(address(vault));
        p.permit2 = permit2;
        p.weth = IWETH(address(weth));

        bytes32 pkgSalt = keccak256(abi.encode(type(PrepaySessionHarnessDFPkg).name, "prepay-session-auth"));
        seRouterDFPkg = IBalancerV3StandardExchangeRouterDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(PrepaySessionHarnessDFPkg).creationCode, abi.encode(p), pkgSalt
                )
            )
        );
        vm.label(address(seRouterDFPkg), "PrepaySessionHarnessDFPkg");
    }

    function setUp() public virtual override {
        super.setUp();
        prepaySessionHarness = IPrepaySessionHarness(address(seRouter));
        prepayRouter = IBalancerV3StandardExchangeRouterPrepay(address(seRouter));
    }
}
