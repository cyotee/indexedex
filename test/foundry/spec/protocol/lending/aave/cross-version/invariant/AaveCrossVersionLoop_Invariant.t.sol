// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    StandardExchangeAccountingHandler
} from "test/foundry/spec/vaults/standard/exchange/invariant/StandardExchangeAccountingHandler.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {
    IPoolAddressesProvider
} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {
    IAaveOracle as IAaveOracleV4
} from "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {TestBase_AaveCrossVersionLoopV3Market} from "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";
import {
    IAaveCrossVersionLoopDFPkg
} from "contracts/protocols/lending/aave/cross-version/IAaveCrossVersionLoopDFPkg.sol";
import {
    AaveCrossVersionLoop_Component_FactoryService
} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoop_Component_FactoryService.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IAaveCrossVersionLoopVault} from "contracts/interfaces/IAaveCrossVersionLoopVault.sol";
import {
    AaveCrossVersionLoopRebalanceTarget
} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceTarget.sol";

interface ILoopTokenObserver {
    function observeTransfer(address from_, address to_) external;
}

interface ILoopInvHost {
    function prepareCallback(bool incoming_) external;
    function completeCallback() external;
    function maintain() external;
    function assertExternalAccounting() external view;
    function positionState() external view returns (bytes32);
    function mintTokenA(address to, uint256 amt) external;
}

contract Handler_AaveCrossVersionLoop is StandardExchangeAccountingHandler {
    ILoopInvHost public immutable host;

    constructor(IStandardExchangeIn se_, IERC20 base_, ILoopInvHost host_, address a0_, address a1_)
        StandardExchangeAccountingHandler(se_, base_, IERC20(address(se_)), false, a0_, a1_, address(0xBAD))
    {
        host = host_;
    }

    function cycle(uint256 amount_, uint256 seed_) public override {
        host.prepareCallback(cycles % 2 == 0);
        super.cycle(amount_, seed_);
        host.completeCallback();
        host.assertExternalAccounting();
    }

    function _additionalActions(address, uint256) internal override {
        host.maintain();
    }

    function _state() internal view override returns (bytes32) {
        return keccak256(abi.encode(super._state(), host.positionState()));
    }

    function _fund(address actor_, uint256 amount_) internal override {
        host.mintTokenA(actor_, amount_);
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract AaveCrossVersionLoop_Invariant is TestBase_AaveCrossVersionLoopV3Market, ILoopInvHost, ILoopTokenObserver {
    using AaveCrossVersionLoop_Component_FactoryService for ICreate3FactoryProxy;
    using AaveCrossVersionLoop_Component_FactoryService for IIndexedexManagerProxy;

    Handler_AaveCrossVersionLoop internal handler;
    address internal vault;
    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);

    uint256 internal fundedA;
    uint256 internal initialA;
    uint256 internal initialB;
    uint256 public callbackAttempts;
    uint256 public callbackRejects;
    uint256 public maintenanceAttempts;
    uint256 public maintenanceCalls;
    uint256 public accrualAttempts;
    uint256 public rebalanceRejectAttempts;
    uint256 public accruedCalls;
    uint256 public rebalanceRejects;
    bool internal callbackArmed;
    bool internal callbackIncoming;
    uint256 internal cycleCallbackBefore;

    function mintTokenA(address to, uint256 amt) external {
        require(msg.sender == address(handler), "only accounting handler funds");
        fundedA += amt;
        _mint(tokenA, to, amt);
    }

    function setUp() public override {
        // Only the external token dependency gains an observer. Its storage and all
        // ERC20 operations remain the canonical token package and ERC20 facet.
        TestBase_VaultComponents.setUp();
        IFacet canonicalTokenFacet = erc20Facet;
        erc20Facet = IFacet(
            create3Factory.deployFacet(
                abi.encodePacked(
                    type(LoopObservedTokenFacet).creationCode, abi.encode(address(canonicalTokenFacet), address(this))
                ),
                keccak256("APEX.loop.observed.token")
            )
        );
        _deployTestTokenPkg();
        tokenA = IERC20(testTokenPkg.deployToken("Cross Loop Token A", "CLTA", 18, address(this), keccak256("CLTA")));
        tokenB = IERC20(testTokenPkg.deployToken("Cross Loop Token B", "CLTB", 6, address(this), keccak256("CLTB")));
        erc20Facet = canonicalTokenFacet;
        _setUpV4Market();
        _setUpV3Market();
        IFacet inFacet = create3Factory.deployExchangeInFacet();
        IFacet outFacet = create3Factory.deployExchangeOutFacet();
        IFacet rebalFacet = create3Factory.deployRebalanceFacet();
        IFacet markerFacet = create3Factory.deployMarkerFacet();
        IFacet transitionQuoteFacet = create3Factory.deployTransitionQuoteFacet();
        IAaveCrossVersionLoopDFPkg.PkgInit memory pkgInit = IAaveCrossVersionLoopDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: inFacet,
            exchangeOutFacet: outFacet,
            rebalanceFacet: rebalFacet,
            markerFacet: markerFacet,
            transitionQuoteFacet: transitionQuoteFacet,
            v36Pool: v36Pool,
            v36AddressesProvider: IPoolAddressesProvider(v36AddressesProvider),
            v36Oracle: IAaveOracle(v36Oracle),
            v4Spoke: v4Spoke,
            v4Hub: v4Hub,
            v4Oracle: IAaveOracleV4(address(v4Oracle)),
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            permit2: IPermit2(address(0))
        });
        vm.prank(owner);
        IAaveCrossVersionLoopDFPkg dfpkg = indexedexManager.deployCrossVersionLoopDFPkg(pkgInit);
        vm.prank(owner);
        vault = dfpkg.deployVault(tokenA, tokenB);

        _mint(tokenB, v3lp, 2_000_000e6);
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), 2_000_000e6);
        v36Pool.supply(address(tokenB), 2_000_000e6, v3lp, 0);
        vm.stopPrank();
        _mint(tokenA, v4lp, 1_000e18);
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), 1_000e18);
        v4Spoke.supply(v4ReserveIdA, 1_000e18, v4lp);
        vm.stopPrank();

        initialA = tokenA.totalSupply();
        initialB = tokenB.totalSupply();
        address a0 = makeAddr("loopInv0");
        address a1 = makeAddr("loopInv1");
        handler =
            new Handler_AaveCrossVersionLoop(IStandardExchangeIn(vault), tokenA, ILoopInvHost(address(this)), a0, a1);
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function invariant_APEX_accounting() public view {
        handler.assertAccounting();
        assertExternalAccounting();
    }

    function afterInvariant() public view {
        assertGe(handler.cycles(), 4, "randomized campaign reaches funded actions");
        for (uint256 i; i < 3; ++i) {
            assertGt(handler.actorCycles(handler.actors(i)), 0, "each honest actor participated");
        }
        assertEq(callbackAttempts, handler.cycles(), "one live transfer callback per funded cycle");
        assertEq(callbackRejects, callbackAttempts, "every nested call reaches the lock");
        assertEq(maintenanceAttempts, maintenanceCalls, "every maintenance succeeds");
        assertEq(accrualAttempts, accruedCalls, "every scheduled accrual succeeds");
        assertEq(rebalanceRejectAttempts, rebalanceRejects, "each rejection is classified");
        assertEq(maintenanceCalls, handler.cycles() / 4, "maintenance was scheduled");
        assertEq(accruedCalls, maintenanceCalls, "real protocol interest accrues");
        assertEq(rebalanceRejects, maintenanceCalls, "anti-churn check is reached");
        invariant_APEX_accounting();
    }

    function test_APEX_loopAccruedFiveCycleRegression() public {
        handler.cycle(34992671583163494363455106144985157567792, 9399805980165072338939153894800);
        handler.cycle(3587565057295926860012254003854516492666001928109060535046186118629560448595, 157768911484524019891477194324799211817269);
        handler.cycle(4434512, 6121);
        handler.cycle(23204, 15147);
        handler.cycle(402803216502618925660182688237803773123, 857057432363144361446020143014725016417556522564692897611943556231691);
        assertEq(handler.cycles(), 5, "all funded cycles complete after accrual/rebalance");
        afterInvariant();
    }

    function test_APEX_deterministicLifecycle() public {
        for (uint256 i; i < 4; ++i) {
            handler.cycle(1 ether + i, 1e14 + i);
        }
        assertEq(handler.ghost_out(), 4, "four nonzero exits");
        afterInvariant();
    }

    function prepareCallback(bool incoming_) external {
        require(msg.sender == address(handler), "only handler");
        assertFalse(callbackArmed, "prior callback completed");
        callbackArmed = true;
        callbackIncoming = incoming_;
        cycleCallbackBefore = callbackAttempts;
    }

    function completeCallback() external {
        require(msg.sender == address(handler), "only handler");
        assertFalse(callbackArmed, "funded operation reached token transfer");
        assertEq(callbackAttempts, cycleCallbackBefore + 1, "callback count");
    }

    function observeTransfer(address from_, address to_) external {
        require(msg.sender == address(tokenA) || msg.sender == address(tokenB), "real test-token proxy only");
        if (!callbackArmed || msg.sender != address(tokenA)) return;
        if (callbackIncoming ? to_ != vault : from_ != vault) return;
        callbackArmed = false;
        ++callbackAttempts;
        (bool success, bytes memory result) = vault.call(
            abi.encodeCall(
                IStandardExchangeIn.exchangeIn, (tokenA, 1, IERC20(vault), 0, address(0xBAD), false, block.timestamp)
            )
        );
        assertFalse(success, "nested call rejected");
        assertEq(
            result, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector), "production lock rejects token callback"
        );
        ++callbackRejects;
    }

    function maintain() external {
        require(msg.sender == address(handler), "only handler");
        uint256 issued = IERC20(vault).totalSupply();
        ++accrualAttempts;
        uint256 beforeDebt = _debts();
        assertGt(beforeDebt, 0, "funded loop holds live debt");
        vm.warp(block.timestamp + 1 hours + 1);
        assertGt(_debts(), beforeDebt, "real debt indices accrue with time");
        ++accruedCalls;
        ++maintenanceAttempts;
        AaveCrossVersionLoopRebalanceTarget(vault).rebalance();
        ++maintenanceCalls;
        assertEq(IERC20(vault).totalSupply(), issued, "maintenance creates no shares");
        bytes32 state = positionState();
        ++rebalanceRejectAttempts;
        vm.expectRevert(
            abi.encodeWithSelector(
                AaveCrossVersionLoopRebalanceTarget.RebalanceTooSoon.selector, block.timestamp + 1 hours
            )
        );
        AaveCrossVersionLoopRebalanceTarget(vault).rebalance();
        assertEq(positionState(), state, "rejected rebalance rolls back positions and allowances");
        ++rebalanceRejects;
    }

    function _debts() internal view returns (uint256 result) {
        result = IERC20(v36Pool.getReserveVariableDebtToken(address(tokenB))).balanceOf(vault);
        (uint256 drawn, uint256 premium) = v4Spoke.getUserDebt(v4ReserveIdA, vault);
        result += drawn + premium;
    }

    function _nativePosition(IERC20 token_, uint256 reserve_) internal view returns (uint256 supplied, uint256 debt) {
        supplied = IERC20(v36Pool.getReserveAToken(address(token_))).balanceOf(vault)
            + v4Spoke.getUserSuppliedAssets(reserve_, vault);
        (uint256 drawn, uint256 premium) = v4Spoke.getUserDebt(reserve_, vault);
        debt = IERC20(v36Pool.getReserveVariableDebtToken(address(token_))).balanceOf(vault) + drawn + premium;
    }

    function _allCustody(IERC20 token_) internal view returns (uint256 held) {
        held = token_.balanceOf(vault) + token_.balanceOf(address(this)) + token_.balanceOf(address(handler))
            + token_.balanceOf(address(handler.integrator())) + token_.balanceOf(v3lp) + token_.balanceOf(v4lp)
            + token_.balanceOf(address(v4Hub)) + token_.balanceOf(address(v4Spoke))
            + token_.balanceOf(v36Pool.getReserveAToken(address(token_)));
        for (uint256 i; i < 3; ++i) {
            held += token_.balanceOf(handler.actors(i));
        }
    }

    function assertExternalAccounting() public view {
        assertEq(tokenA.totalSupply(), initialA + fundedA, "independent native funding ledger");
        assertEq(tokenB.totalSupply(), initialB, "loop never creates borrowed underlying");
        assertEq(_allCustody(tokenA), initialA + fundedA, "all A inputs retained in actors, local custody or protocols");
        assertEq(_allCustody(tokenB), initialB, "all borrowed B retained in actual protocol custody");
        (uint256 suppliedA, uint256 debtA) = _nativePosition(tokenA, v4ReserveIdA);
        (uint256 suppliedB, uint256 debtB) = _nativePosition(tokenB, v4ReserveIdB);
        assertEq(
            IAaveCrossVersionLoopVault(vault).netBalanceOf(tokenA),
            suppliedA > debtA ? suppliedA - debtA : 0,
            "A receipt/debt ledger matches external positions"
        );
        assertEq(
            IAaveCrossVersionLoopVault(vault).netBalanceOf(tokenB),
            suppliedB > debtB ? suppliedB - debtB : 0,
            "B receipt/debt ledger matches external positions"
        );
        int256 netUsd = int256((suppliedA + tokenA.balanceOf(vault)) / 5e6) - int256(debtA / 5e6)
            + int256((suppliedB + tokenB.balanceOf(vault)) * 100) - int256(debtB * 100);
        if (IERC20(vault).totalSupply() != 0) assertGt(netUsd, 0, "aggregate debt cannot exceed actual backing");
        assertEq(tokenA.balanceOf(address(0xBAD)), 0, "nested recipient never receives assets");
        assertEq(IERC20(vault).balanceOf(address(0xBAD)), 0, "nested recipient never receives shares");
    }

    function positionState() public view returns (bytes32) {
        uint256[12] memory values;
        (values[0], values[1]) = _nativePosition(tokenA, v4ReserveIdA);
        (values[2], values[3]) = _nativePosition(tokenB, v4ReserveIdB);
        values[4] = tokenA.balanceOf(vault);
        values[5] = tokenB.balanceOf(vault);
        values[6] = tokenA.allowance(vault, address(v36Pool));
        values[7] = tokenB.allowance(vault, address(v36Pool));
        values[8] = tokenA.allowance(vault, address(v4Spoke));
        values[9] = tokenB.allowance(vault, address(v4Spoke));
        values[10] = IERC20(vault).totalSupply();
        values[11] = _allCustody(tokenA);
        return keccak256(abi.encode(values));
    }
}

/// @dev External token dependency only. Registry vault facets remain byte-identical.
contract LoopObservedTokenFacet is IFacet {
    address internal immutable implementation;
    ILoopTokenObserver internal immutable observer;

    constructor(address implementation_, address observer_) {
        implementation = implementation_;
        observer = ILoopTokenObserver(observer_);
    }

    function facetName() public pure returns (string memory) {
        return "LoopObservedTokenFacet";
    }

    function facetInterfaces() public view returns (bytes4[] memory) {
        return IFacet(implementation).facetInterfaces();
    }

    function facetFuncs() public view returns (bytes4[] memory) {
        return IFacet(implementation).facetFuncs();
    }

    function facetMetadata() external view returns (string memory, bytes4[] memory, bytes4[] memory) {
        return (facetName(), facetInterfaces(), facetFuncs());
    }

    fallback() external {
        (bool success, bytes memory result) = implementation.delegatecall(msg.data);
        if (!success) assembly { revert(add(result, 32), mload(result)) }
        if (msg.sig == IERC20.transfer.selector) {
            (address to_,) = abi.decode(msg.data[4:], (address, uint256));
            observer.observeTransfer(msg.sender, to_);
        } else if (msg.sig == IERC20.transferFrom.selector) {
            (address from_, address to_,) = abi.decode(msg.data[4:], (address, address, uint256));
            observer.observeTransfer(from_, to_);
        }
        assembly { return(add(result, 32), mload(result)) }
    }
}
