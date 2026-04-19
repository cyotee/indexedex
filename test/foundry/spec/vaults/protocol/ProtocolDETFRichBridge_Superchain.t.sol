// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IApprovedMessageSenderRegistry} from "@crane/contracts/interfaces/IApprovedMessageSenderRegistry.sol";
import {ITokenTransferRelayer} from "@crane/contracts/interfaces/ITokenTransferRelayer.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IFacetRegistry} from "@crane/contracts/registries/facet/IFacetRegistry.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ICrossDomainMessenger} from "@crane/contracts/interfaces/protocols/l2s/superchain/ICrossDomainMessenger.sol";
import {IStandardBridge} from "@crane/contracts/interfaces/protocols/l2s/superchain/IStandardBridge.sol";
import {InitDevService} from "@crane/contracts/InitDevService.sol";
import {
    ApprovedMessageSenderRegistryFactoryService
} from "@crane/contracts/protocols/l2s/superchain/registries/message/sender/ApprovedMessageSenderRegistryFactoryService.sol";
import {
    ISuperChainBridgeTokenRegistry
} from "@crane/contracts/interfaces/ISuperChainBridgeTokenRegistry.sol";
import {
    SuperChainBridgeTokenRegistryFactoryService
} from "@crane/contracts/protocols/l2s/superchain/registries/token/bridge/SuperChainBridgeTokenRegistryFactoryService.sol";
import {
    TokenTransferRelayerFactoryService
} from "@crane/contracts/protocols/l2s/superchain/relayers/token/TokenTransferRelayerFactoryService.sol";
import {SuperchainSenderNonceRepo} from "@crane/contracts/protocols/l2s/superchain/senders/SuperchainSenderNonceRepo.sol";

import {ETHEREUM_MAIN} from "@crane/contracts/constants/networks/ETHEREUM_MAIN.sol";
import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";
import {ETHEREUM_SEPOLIA} from "@crane/contracts/constants/networks/ETHEREUM_SEPOLIA.sol";
import {BASE_SEPOLIA} from "@crane/contracts/constants/networks/BASE_SEPOLIA.sol";

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";

interface IOptimismMintableERC20Factory {
    function createOptimismMintableERC20(address remoteToken, string memory name, string memory symbol)
        external
        returns (address);
}

contract TestERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract TestRichir is TestERC20 {
    constructor(string memory name_, string memory symbol_) TestERC20(name_, symbol_) {}

    function totalShares() external view returns (uint256) {
        return totalSupply;
    }

    function convertToShares(uint256 richirAmount) external pure returns (uint256) {
        return richirAmount;
    }

    function mintFromNFTSale(uint256 amount, address recipient) external returns (uint256) {
        this.mint(recipient, amount);
        return amount;
    }

    function burnShares(uint256 richirAmount, address, bool) external returns (uint256) {
        this.burn(address(this), richirAmount);
        return richirAmount;
    }
}

contract TestProtocolDETFBridgeHarness {
    uint256 internal constant _LOCAL_COMP_BPS = 2_000;
    uint256 internal constant _BPS_DENOMINATOR = 10_000;

    IERC20 public immutable richToken;
    TestRichir public immutable richirToken;
    address public immutable feeTo;

    struct BridgeExecution {
        ProtocolDETFSuperchainBridgeRepo.PeerConfig peer;
        IERC20 remoteDetfToken;
        IERC20 remoteRichToken;
        IProtocolDETF.BridgeQuote quote;
        address recipient;
        uint256 bridgeMinGasLimit;
        uint256 senderNonce;
    }

    event BridgeInitiated(
        address indexed sender,
        uint256 indexed targetChainId,
        address indexed recipient,
        uint256 richirAmountIn,
        uint256 sharesBurned,
        uint256 reserveSharesBurned,
        uint256 localRichirOut,
        uint256 richOut,
        uint256 nonce
    );

    event BridgeReceived(address indexed relayer, address indexed recipient, uint256 richAmount, uint256 richirOut);

    constructor(IERC20 richToken_, TestRichir richirToken_, address feeTo_) {
        richToken = richToken_;
        richirToken = richirToken_;
        feeTo = feeTo_;
    }

    function initBridgeConfig(ProtocolDETFSuperchainBridgeRepo.BridgeConfig calldata bridgeConfig_) external {
        ProtocolDETFSuperchainBridgeRepo._initialize(bridgeConfig_);
    }

    function previewBridgeRichir(uint256 targetChainId, uint256 richirAmount)
        external
        view
        returns (IProtocolDETF.BridgeQuote memory quote)
    {
        ProtocolDETFSuperchainBridgeRepo.Storage storage bridgeLayout = ProtocolDETFSuperchainBridgeRepo._layout();

        if (
            address(bridgeLayout.messenger) == address(0)
                || address(bridgeLayout.standardBridge) == address(0)
                || address(bridgeLayout.bridgeTokenRegistry) == address(0)
        ) {
            revert IProtocolDETFErrors.BridgeConfigNotSet();
        }

        ProtocolDETFSuperchainBridgeRepo.PeerConfig memory peer = bridgeLayout.peers[targetChainId];
        if (peer.relayer == address(0)) {
            peer.relayer = bridgeLayout.defaultPeerRelayer;
        }
        if (peer.relayer == address(0)) {
            revert IProtocolDETFErrors.BridgePeerNotConfigured(targetChainId);
        }

        IERC20 remoteDetfToken = bridgeLayout.bridgeTokenRegistry.getRemoteToken(targetChainId, IERC20(address(this)));
        if (address(remoteDetfToken) == address(0)) {
            revert IProtocolDETFErrors.BridgeRemoteTokenNotConfigured(targetChainId, IERC20(address(this)));
        }

        (IERC20 remoteRichToken,) = bridgeLayout.bridgeTokenRegistry.getRemoteTokenAndLimit(targetChainId, richToken);
        if (address(remoteRichToken) == address(0)) {
            revert IProtocolDETFErrors.BridgeRemoteTokenNotConfigured(targetChainId, richToken);
        }

        quote.richirAmountIn = richirAmount;
        quote.sharesBurned = richirAmount;
        quote.reserveSharesBurned = richirAmount;
        quote.localRichirOut = richirAmount * _LOCAL_COMP_BPS / _BPS_DENOMINATOR;
        quote.richOut = richirAmount - quote.localRichirOut;
    }

    function bridgeRichir(IProtocolDETF.BridgeArgs calldata args)
        external
        returns (uint256 localRichirOut, uint256 richOut)
    {
        if (block.timestamp > args.deadline) {
            revert IStandardExchangeErrors.DeadlineExceeded(args.deadline, block.timestamp);
        }

        if (args.richirAmount == 0) {
            revert IProtocolDETFErrors.ZeroAmount();
        }

        ProtocolDETFSuperchainBridgeRepo.Storage storage bridgeLayout = ProtocolDETFSuperchainBridgeRepo._layout();
        if (
            address(bridgeLayout.messenger) == address(0)
                || address(bridgeLayout.standardBridge) == address(0)
                || address(bridgeLayout.bridgeTokenRegistry) == address(0)
        ) {
            revert IProtocolDETFErrors.BridgeConfigNotSet();
        }

        BridgeExecution memory execution;
        execution.peer = bridgeLayout.peers[args.targetChainId];
        if (execution.peer.relayer == address(0)) {
            execution.peer.relayer = bridgeLayout.defaultPeerRelayer;
        }
        if (execution.peer.relayer == address(0)) {
            revert IProtocolDETFErrors.BridgePeerNotConfigured(args.targetChainId);
        }

        execution.remoteDetfToken = bridgeLayout.bridgeTokenRegistry.getRemoteToken(
            args.targetChainId, IERC20(address(this))
        );
        if (address(execution.remoteDetfToken) == address(0)) {
            revert IProtocolDETFErrors.BridgeRemoteTokenNotConfigured(args.targetChainId, IERC20(address(this)));
        }

        (execution.remoteRichToken, execution.bridgeMinGasLimit) =
            bridgeLayout.bridgeTokenRegistry.getRemoteTokenAndLimit(args.targetChainId, richToken);
        if (address(execution.remoteRichToken) == address(0)) {
            revert IProtocolDETFErrors.BridgeRemoteTokenNotConfigured(args.targetChainId, richToken);
        }

        execution.quote = this.previewBridgeRichir(args.targetChainId, args.richirAmount);
        execution.recipient = args.recipient == address(0) ? msg.sender : args.recipient;

        richirToken.transferFrom(msg.sender, address(this), args.richirAmount);
        richirToken.transfer(address(richirToken), args.richirAmount);
        richirToken.burnShares(args.richirAmount, address(0), true);

        localRichirOut = execution.quote.localRichirOut;
        richOut = execution.quote.richOut;

        if (localRichirOut < args.minLocalRichirOut) {
            revert IProtocolDETFErrors.SlippageExceeded(args.minLocalRichirOut, localRichirOut);
        }

        if (richOut < args.minRichOut) {
            revert IProtocolDETFErrors.SlippageExceeded(args.minRichOut, richOut);
        }

        if (localRichirOut > 0) {
            richirToken.mintFromNFTSale(localRichirOut, msg.sender);
        }

        execution.senderNonce = SuperchainSenderNonceRepo._useNonce(address(this), args.targetChainId);
        richToken.approve(address(bridgeLayout.standardBridge), richOut);
        bridgeLayout.standardBridge.bridgeERC20To(
            address(richToken),
            address(execution.remoteRichToken),
            execution.peer.relayer,
            richOut,
            uint32(execution.bridgeMinGasLimit),
            bytes("")
        );

        bytes memory receiveData = abi.encodeCall(
            TestProtocolDETFBridgeHarness.receiveBridgedRich,
            (execution.recipient, richOut, args.deadline)
        );
        bytes memory relayData = abi.encodeCall(
            ITokenTransferRelayer.relayTokenTransfer,
            (
                address(execution.remoteDetfToken),
                execution.remoteRichToken,
                richOut,
                execution.senderNonce,
                false,
                false,
                receiveData
            )
        );
        bridgeLayout.messenger.sendMessage(execution.peer.relayer, relayData, args.messageGasLimit);

        uint256 richDust = richToken.balanceOf(address(this));
        if (richDust > execution.quote.richOut) {
            richToken.transfer(feeTo, richDust - execution.quote.richOut);
        }

        emit BridgeInitiated(
            msg.sender,
            args.targetChainId,
            execution.recipient,
            args.richirAmount,
            execution.quote.sharesBurned,
            execution.quote.reserveSharesBurned,
            localRichirOut,
            richOut,
            execution.senderNonce
        );
    }

    function receiveBridgedRich(address recipient, uint256 richAmount, uint256 deadline)
        external
        returns (uint256 richirOut)
    {
        if (block.timestamp > deadline) {
            revert IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp);
        }

        address expectedRelayer = ProtocolDETFSuperchainBridgeRepo._localRelayer();
        if (expectedRelayer == address(0)) {
            revert IProtocolDETFErrors.BridgeConfigNotSet();
        }

        if (msg.sender != expectedRelayer) {
            revert IProtocolDETFErrors.NotBridgeRelayer(msg.sender, expectedRelayer);
        }

        recipient = recipient == address(0) ? msg.sender : recipient;
        richToken.transferFrom(msg.sender, address(this), richAmount);
        richirOut = richAmount;

        richirToken.mintFromNFTSale(richAmount, recipient);
        emit BridgeReceived(msg.sender, recipient, richAmount, richirOut);
    }
}

abstract contract ProtocolDETFRichBridgeSuperchainTestBase is Test {
    uint32 internal constant _BRIDGE_MIN_GAS_LIMIT = 250_000;
    uint32 internal constant _PROCESSOR_MIN_GAS_LIMIT = 500_000;

    uint160 internal constant _L1_TO_L2_ALIAS_OFFSET = uint160(0x1111000000000000000000000000000000001111);

    bytes32 internal constant _RELAYED_MESSAGE_TOPIC0 = keccak256("RelayedMessage(bytes32)");
    bytes32 internal constant _FAILED_RELAYED_MESSAGE_TOPIC0 = keccak256("FailedRelayedMessage(bytes32)");
    bytes32 internal constant _TOKEN_TRANSFER_RELAYED_TOPIC0 =
        keccak256("TokenTransferRelayed(address,address,address,uint256,uint256,bytes)");

    uint256 internal _ethereumFork;
    uint256 internal _baseFork;

    address internal _feeTo = makeAddr("feeTo");
    address internal _alice = makeAddr("alice");

    ICreate3FactoryProxy internal _ethereumCreate3Factory;
    IDiamondPackageCallBackFactory internal _ethereumDiamondFactory;
    ICreate3FactoryProxy internal _baseCreate3Factory;
    IDiamondPackageCallBackFactory internal _baseDiamondFactory;

    TestERC20 internal _ethereumRich;
    IERC20 internal _baseRich;
    TestRichir internal _ethereumRichir;
    TestRichir internal _baseRichir;
    TestProtocolDETFBridgeHarness internal _ethereumDetf;
    TestProtocolDETFBridgeHarness internal _baseDetf;

    ISuperChainBridgeTokenRegistry internal _ethereumBridgeRegistry;
    ISuperChainBridgeTokenRegistry internal _baseBridgeRegistry;
    IApprovedMessageSenderRegistry internal _ethereumApprovedRegistry;
    IApprovedMessageSenderRegistry internal _baseApprovedRegistry;
    ITokenTransferRelayer internal _ethereumRelayer;
    ITokenTransferRelayer internal _baseRelayer;

    function _ethereumRpcAlias() internal pure virtual returns (string memory);
    function _baseRpcAlias() internal pure virtual returns (string memory);
    function _ethereumForkBlock() internal pure virtual returns (uint256);
    function _baseForkBlock() internal pure virtual returns (uint256);
    function _ethereumCrossDomainMessenger() internal pure virtual returns (address);
    function _ethereumStandardBridge() internal pure virtual returns (address);
    function _baseCrossDomainMessenger() internal pure virtual returns (address);
    function _baseStandardBridge() internal pure virtual returns (address);
    function _baseMintableFactory() internal pure virtual returns (address);
    function _baseChainId() internal pure virtual returns (uint256);
    function _ethereumChainId() internal pure virtual returns (uint256);

    function setUp() public virtual {
        _ethereumFork = vm.createFork(_ethereumRpcAlias(), _ethereumForkBlock());
        _baseFork = vm.createFork(_baseRpcAlias(), _baseForkBlock());

        _setUpEthereum();
        _setUpBase();
        _configureBridge();
    }

    function _setUpEthereum() internal {
        vm.selectFork(_ethereumFork);

        (_ethereumCreate3Factory, _ethereumDiamondFactory) = InitDevService.initEnv(address(this));
        _ethereumRich = new TestERC20("RICH", "RICH");
        _ethereumRichir = new TestRichir("RICHIR", "RICHIR");
        _ethereumDetf = new TestProtocolDETFBridgeHarness(IERC20(address(_ethereumRich)), _ethereumRichir, _feeTo);

        _ethereumBridgeRegistry = _deployBridgeRegistry(_ethereumCreate3Factory, _ethereumDiamondFactory);
        _ethereumApprovedRegistry = _deployApprovedRegistry(_ethereumCreate3Factory, _ethereumDiamondFactory);
        _ethereumRelayer = _deployRelayer(_ethereumCreate3Factory, _ethereumDiamondFactory, _ethereumApprovedRegistry);

        _ethereumRich.mint(address(_ethereumDetf), 1_000_000e18);
        _ethereumRichir.mint(_alice, 1_000e18);
    }

    function _setUpBase() internal {
        vm.selectFork(_baseFork);

        (_baseCreate3Factory, _baseDiamondFactory) = InitDevService.initEnv(address(this));
        _baseRich = IERC20(
            IOptimismMintableERC20Factory(_baseMintableFactory()).createOptimismMintableERC20(
                address(_ethereumRich), "RICH Base", "RICH.base"
            )
        );
        _baseRichir = new TestRichir("RICHIR Base", "RICHIR.base");
        _baseDetf = new TestProtocolDETFBridgeHarness(_baseRich, _baseRichir, _feeTo);

        _baseBridgeRegistry = _deployBridgeRegistry(_baseCreate3Factory, _baseDiamondFactory);
        _baseApprovedRegistry = _deployApprovedRegistry(_baseCreate3Factory, _baseDiamondFactory);
        _baseRelayer = _deployRelayer(_baseCreate3Factory, _baseDiamondFactory, _baseApprovedRegistry);
    }

    function _configureBridge() internal {
        vm.selectFork(_ethereumFork);
        _ethereumBridgeRegistry.setRemoteToken(_baseChainId(), IERC20(address(_ethereumDetf)), IERC20(address(_baseDetf)), 0);
        _ethereumBridgeRegistry.setRemoteToken(_baseChainId(), IERC20(address(_ethereumRich)), _baseRich, _BRIDGE_MIN_GAS_LIMIT);
        _ethereumApprovedRegistry.approveSender(address(_ethereumDetf), address(_baseDetf));
        _ethereumDetf.initBridgeConfig(
            _buildBridgeConfig(
                _ethereumBridgeRegistry,
                _ethereumStandardBridge(),
                _ethereumCrossDomainMessenger(),
                address(_ethereumRelayer),
                address(_baseRelayer)
            )
        );

        vm.selectFork(_baseFork);
    _baseBridgeRegistry.setRemoteToken(_ethereumChainId(), IERC20(address(_baseDetf)), IERC20(address(_ethereumDetf)), 0);
        _baseBridgeRegistry.setRemoteToken(_ethereumChainId(), _baseRich, IERC20(address(_ethereumRich)), _BRIDGE_MIN_GAS_LIMIT);
        _baseApprovedRegistry.approveSender(address(_baseDetf), address(_ethereumDetf));
        _baseDetf.initBridgeConfig(
            _buildBridgeConfig(
                _baseBridgeRegistry,
                _baseStandardBridge(),
                _baseCrossDomainMessenger(),
                address(_baseRelayer),
                address(_ethereumRelayer)
            )
        );
    }

    function _deployApprovedRegistry(ICreate3FactoryProxy create3Factory_, IDiamondPackageCallBackFactory diamondFactory_)
        internal
        returns (IApprovedMessageSenderRegistry registry)
    {
        IFacet registryFacet = ApprovedMessageSenderRegistryFactoryService.deployApprovedMessageSenderRegistryFacet(create3Factory_);
        IFacet ownableFacet = IFacetRegistry(address(create3Factory_)).canonicalFacet(type(IMultiStepOwnable).interfaceId);
        IFacet operableFacet = IFacetRegistry(address(create3Factory_)).canonicalFacet(type(IOperable).interfaceId);

        registry = ApprovedMessageSenderRegistryFactoryService.deployApprovedMessageSenderRegistry(
            diamondFactory_,
            ApprovedMessageSenderRegistryFactoryService.deployApprovedMessageSenderRegistryDFPkg(
                create3Factory_,
                ownableFacet,
                operableFacet,
                registryFacet
            ),
            address(this)
        );
    }

    function _deployBridgeRegistry(ICreate3FactoryProxy create3Factory_, IDiamondPackageCallBackFactory diamondFactory_)
        internal
        returns (ISuperChainBridgeTokenRegistry registry)
    {
        IFacet ownableFacet = IFacetRegistry(address(create3Factory_)).canonicalFacet(type(IMultiStepOwnable).interfaceId);
        IFacet operableFacet = IFacetRegistry(address(create3Factory_)).canonicalFacet(type(IOperable).interfaceId);

        registry = SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistry(
            diamondFactory_,
            SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryDFPkg(
                create3Factory_,
                ownableFacet,
                operableFacet,
                SuperChainBridgeTokenRegistryFactoryService.deploySuperChainBridgeTokenRegistryFacet(create3Factory_)
            ),
            address(this)
        );
    }

    function _deployRelayer(
        ICreate3FactoryProxy create3Factory_,
        IDiamondPackageCallBackFactory diamondFactory_,
        IApprovedMessageSenderRegistry registry_
    ) internal returns (ITokenTransferRelayer relayer) {
        relayer = TokenTransferRelayerFactoryService.deployTokenTransferRelayer(
            diamondFactory_,
            TokenTransferRelayerFactoryService.deployTokenTransferRelayerDFPkg(
                create3Factory_,
                IFacetRegistry(address(create3Factory_)).canonicalFacet(type(IMultiStepOwnable).interfaceId),
                TokenTransferRelayerFactoryService.deployTokenTransferRelayerFacet(create3Factory_),
                IPermit2(_permit2())
            ),
            address(this),
            registry_
        );
    }

    function _buildBridgeConfig(
        ISuperChainBridgeTokenRegistry registry,
        address standardBridge,
        address messenger,
        address localRelayer,
        address peerRelayer
    ) internal pure returns (ProtocolDETFSuperchainBridgeRepo.BridgeConfig memory bridgeConfig) {
        bridgeConfig = ProtocolDETFSuperchainBridgeRepo.BridgeConfig({
            bridgeTokenRegistry: registry,
            standardBridge: IStandardBridge(payable(standardBridge)),
            messenger: ICrossDomainMessenger(messenger),
            localRelayer: localRelayer,
            peerRelayer: peerRelayer
        });
    }

    function _ethereumMessenger() internal view returns (ICrossDomainMessenger) {
        return ICrossDomainMessenger(_ethereumCrossDomainMessenger());
    }

    function _baseMessenger() internal view returns (ICrossDomainMessenger) {
        return ICrossDomainMessenger(_baseCrossDomainMessenger());
    }

    function _computeAlias(address l1Address) internal pure returns (address) {
        return address(uint160(l1Address) + _L1_TO_L2_ALIAS_OFFSET);
    }

    function _encodeVersionedNonce(uint240 nonce, uint16 version) internal pure returns (uint256 encodedNonce) {
        encodedNonce = (uint256(version) << 240) | uint256(nonce);
    }

    function _decodeVersionedNonce(uint256 encodedNonce) internal pure returns (uint240 nonce, uint16 version) {
        nonce = uint240(encodedNonce);
        version = uint16(encodedNonce >> 240);
    }

    function _incrementVersionedNonce(uint256 encodedNonce) internal pure returns (uint256) {
        (uint240 nonce, uint16 version) = _decodeVersionedNonce(encodedNonce);
        return _encodeVersionedNonce(nonce + 1, version);
    }

    function _hashCrossDomainMessageV1(
        uint256 nonce,
        address sender,
        address target,
        uint256 value,
        uint256 gasLimit,
        bytes memory data
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodeWithSignature(
                "relayMessage(uint256,address,address,uint256,uint256,bytes)",
                nonce,
                sender,
                target,
                value,
                gasLimit,
                data
            )
        );
    }

    function _buildBridgeFinalizeMessage(address from, uint256 amount) internal view returns (bytes memory) {
        return abi.encodeCall(
            IStandardBridge.finalizeBridgeERC20,
            (address(_baseRich), address(_ethereumRich), from, address(_baseRelayer), amount, bytes(""))
        );
    }

    function _buildReceiveRelayMessage(address recipient, uint256 amount, uint256 senderNonce)
        internal
        view
        returns (bytes memory)
    {
        bytes memory receiveData = abi.encodeCall(
            TestProtocolDETFBridgeHarness.receiveBridgedRich,
            (recipient, amount, type(uint256).max)
        );

        return abi.encodeCall(
            ITokenTransferRelayer.relayTokenTransfer,
            (address(_baseDetf), _baseRich, amount, senderNonce, false, false, receiveData)
        );
    }

    function _relayBridgeFinalize(uint256 nonce, address from, uint256 amount) internal {
        vm.selectFork(_baseFork);
        vm.prank(_computeAlias(_ethereumCrossDomainMessenger()));
        _baseMessenger().relayMessage(
            nonce,
            _ethereumStandardBridge(),
            _baseStandardBridge(),
            0,
            _BRIDGE_MIN_GAS_LIMIT,
            _buildBridgeFinalizeMessage(from, amount)
        );
    }

    function _relayReceiveMessage(uint256 nonce, address sourceDetf, address recipient, uint256 amount, uint256 senderNonce)
        internal
        returns (bytes32 messageHash)
    {
        bytes memory message = _buildReceiveRelayMessage(recipient, amount, senderNonce);
        messageHash = _hashCrossDomainMessageV1(
            nonce,
            sourceDetf,
            address(_baseRelayer),
            0,
            _PROCESSOR_MIN_GAS_LIMIT,
            message
        );

        vm.selectFork(_baseFork);
        vm.prank(_computeAlias(_ethereumCrossDomainMessenger()));
        _baseMessenger().relayMessage(
            nonce,
            sourceDetf,
            address(_baseRelayer),
            0,
            _PROCESSOR_MIN_GAS_LIMIT,
            message
        );
    }

    function _logExists(Vm.Log[] memory entries, address emitter, bytes32 topic0) internal pure returns (bool) {
        for (uint256 i = 0; i < entries.length; ++i) {
            if (entries[i].emitter == emitter && entries[i].topics.length > 0 && entries[i].topics[0] == topic0) {
                return true;
            }
        }
        return false;
    }

    function _relayedMessageLogExists(Vm.Log[] memory entries, address messenger, bytes32 messageHash)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < entries.length; ++i) {
            if (
                entries[i].emitter == messenger && entries[i].topics.length > 1
                    && entries[i].topics[0] == _RELAYED_MESSAGE_TOPIC0 && entries[i].topics[1] == messageHash
            ) {
                return true;
            }
        }
        return false;
    }

    function _failedMessageLogExists(Vm.Log[] memory entries, address messenger, bytes32 messageHash)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < entries.length; ++i) {
            if (
                entries[i].emitter == messenger && entries[i].topics.length > 1
                    && entries[i].topics[0] == _FAILED_RELAYED_MESSAGE_TOPIC0 && entries[i].topics[1] == messageHash
            ) {
                return true;
            }
        }
        return false;
    }

    function _permit2() internal pure returns (address) {
        return 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    }

    function test_bridgeRichir_ethereum_to_base_success() public {
        vm.selectFork(_ethereumFork);
        uint256 richirAmount = 1_000e18;
        uint256 bridgeNonce = _ethereumMessenger().messageNonce();
        uint256 processorNonce = _incrementVersionedNonce(bridgeNonce);

        uint256 sourceRichirBefore = _ethereumRichir.balanceOf(_alice);
        IProtocolDETF.BridgeQuote memory quote = _ethereumDetf.previewBridgeRichir(_baseChainId(), richirAmount);

        vm.startPrank(_alice);
        _ethereumRichir.approve(address(_ethereumDetf), richirAmount);
        (uint256 localRichirOut, uint256 richOut) = _ethereumDetf.bridgeRichir(
            IProtocolDETF.BridgeArgs({
                targetChainId: _baseChainId(),
                richirAmount: richirAmount,
                recipient: _alice,
                minLocalRichirOut: quote.localRichirOut,
                minRichOut: quote.richOut,
                messageGasLimit: _PROCESSOR_MIN_GAS_LIMIT,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();

        assertEq(localRichirOut, quote.localRichirOut, "local RICHIR compensation mismatch");
        assertEq(richOut, quote.richOut, "bridged RICH preview mismatch");
        assertEq(_ethereumRichir.balanceOf(_alice), sourceRichirBefore - richirAmount + localRichirOut);

        vm.selectFork(_baseFork);
        uint256 destinationRichBalanceBefore = _baseRich.balanceOf(_alice);
        uint256 destinationRichirBefore = _baseRichir.balanceOf(_alice);

        vm.recordLogs();
        _relayBridgeFinalize(bridgeNonce, address(_ethereumDetf), richOut);
        assertEq(_baseRich.balanceOf(address(_baseRelayer)), richOut, "relayer should hold bridged rich");

        bytes32 messageHash = _relayReceiveMessage(processorNonce, address(_ethereumDetf), _alice, richOut, 0);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(_baseRich.balanceOf(address(_baseRelayer)), 0, "relayer should drain on success");
        assertEq(_baseRich.balanceOf(_alice), destinationRichBalanceBefore, "user should not receive raw rich");
        assertEq(_baseRichir.balanceOf(_alice), destinationRichirBefore + richOut, "destination richir mismatch");
        assertEq(_baseRelayer.nextNonce(address(_ethereumDetf)), 1, "destination relayer nonce mismatch");
        assertTrue(_baseMessenger().successfulMessages(messageHash), "destination message not marked successful");
        assertTrue(_logExists(entries, address(_baseRelayer), _TOKEN_TRANSFER_RELAYED_TOPIC0), "missing relayer event");
        assertTrue(
            _relayedMessageLogExists(entries, _baseCrossDomainMessenger(), messageHash),
            "missing messenger relayed event"
        );
    }

    function test_bridgeRichir_reverts_when_remote_token_missing() public {
        vm.selectFork(_ethereumFork);
        TestProtocolDETFBridgeHarness detfWithoutRemote =
            new TestProtocolDETFBridgeHarness(IERC20(address(_ethereumRich)), _ethereumRichir, _feeTo);
        _ethereumBridgeRegistry.setRemoteToken(999_999, IERC20(address(detfWithoutRemote)), IERC20(address(_baseDetf)), 0);
        detfWithoutRemote.initBridgeConfig(
            _buildBridgeConfig(
                _ethereumBridgeRegistry,
                _ethereumStandardBridge(),
                _ethereumCrossDomainMessenger(),
                address(_ethereumRelayer),
                address(_baseRelayer)
            )
        );

        vm.startPrank(_alice);
        _ethereumRichir.approve(address(detfWithoutRemote), 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                IProtocolDETFErrors.BridgeRemoteTokenNotConfigured.selector,
                999_999,
                IERC20(address(_ethereumRich))
            )
        );
        detfWithoutRemote.bridgeRichir(
            IProtocolDETF.BridgeArgs({
                targetChainId: 999_999,
                richirAmount: 100e18,
                recipient: _alice,
                minLocalRichirOut: 0,
                minRichOut: 0,
                messageGasLimit: _PROCESSOR_MIN_GAS_LIMIT,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();
    }

    function test_receiveBridgedRich_reverts_for_unauthorized_relayer() public {
        vm.selectFork(_baseFork);
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IProtocolDETFErrors.NotBridgeRelayer.selector, attacker, address(_baseRelayer))
        );
        _baseDetf.receiveBridgedRich(attacker, 1e18, type(uint256).max);
    }

    function test_relayer_recoverToken_owner_can_recover() public {
        vm.selectFork(_baseFork);
        address recipient = makeAddr("recoveryRecipient");
        uint256 amount = 15e18;

        _baseRichir.mint(address(_baseRelayer), amount);
        _baseRelayer.recoverToken(IERC20(address(_baseRichir)), recipient, amount);

        assertEq(_baseRichir.balanceOf(address(_baseRelayer)), 0, "relayer should be emptied");
        assertEq(_baseRichir.balanceOf(recipient), amount, "recipient did not receive recovered token");
    }

    function test_relayer_recoverToken_non_owner_reverts() public {
        vm.selectFork(_baseFork);
        address recipient = makeAddr("recoveryRecipient");
        uint256 amount = 5e18;

        _baseRichir.mint(address(_baseRelayer), amount);
        vm.prank(makeAddr("notOwner"));
        vm.expectRevert();
        _baseRelayer.recoverToken(IERC20(address(_baseRichir)), recipient, amount);
    }

    function test_unauthorized_sender_marks_message_failed() public {
        vm.selectFork(_baseFork);
        uint256 amount = 3e18;
        uint256 bridgeNonce = _encodeVersionedNonce(120, 1);
        uint256 processorNonce = _encodeVersionedNonce(121, 1);
        address unauthorizedSourceDetf = makeAddr("unauthorizedSourceDetf");

        _relayBridgeFinalize(bridgeNonce, unauthorizedSourceDetf, amount);

        vm.recordLogs();
        bytes32 messageHash = _relayReceiveMessage(processorNonce, unauthorizedSourceDetf, _alice, amount, 0);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertTrue(_baseMessenger().failedMessages(messageHash), "unauthorized relay should fail");
        assertFalse(_baseMessenger().successfulMessages(messageHash), "unauthorized relay should not succeed");
        assertEq(_baseRelayer.nextNonce(unauthorizedSourceDetf), 0, "unauthorized sender nonce should remain zero");
        assertTrue(
            _failedMessageLogExists(entries, _baseCrossDomainMessenger(), messageHash),
            "missing failed relay event"
        );
    }
}

contract ProtocolDETFRichBridge_Superchain_MainnetFork_Test is ProtocolDETFRichBridgeSuperchainTestBase {
    function _ethereumRpcAlias() internal pure override returns (string memory) {
        return "ethereum_mainnet_alchemy";
    }

    function _baseRpcAlias() internal pure override returns (string memory) {
        return "base_mainnet_alchemy";
    }

    function _ethereumForkBlock() internal pure override returns (uint256) {
        return ETHEREUM_MAIN.DEFAULT_FORK_BLOCK;
    }

    function _baseForkBlock() internal pure override returns (uint256) {
        return BASE_MAIN.DEFAULT_FORK_BLOCK;
    }

    function _ethereumCrossDomainMessenger() internal pure override returns (address) {
        return ETHEREUM_MAIN.BASE_L1_CROSS_DOMAIN_MESSENGER;
    }

    function _ethereumStandardBridge() internal pure override returns (address) {
        return ETHEREUM_MAIN.BASE_L1_STANDARD_BRIDGE;
    }

    function _baseCrossDomainMessenger() internal pure override returns (address) {
        return BASE_MAIN.L2_CROSSDOMAIN_MESSENGER;
    }

    function _baseStandardBridge() internal pure override returns (address) {
        return BASE_MAIN.L2_STANDARD_BRIDGE;
    }

    function _baseMintableFactory() internal pure override returns (address) {
        return BASE_MAIN.OPTIMISM_MINTABLE_ERC20_FACTORY;
    }

    function _baseChainId() internal pure override returns (uint256) {
        return BASE_MAIN.CHAIN_ID;
    }

    function _ethereumChainId() internal pure override returns (uint256) {
        return ETHEREUM_MAIN.CHAIN_ID;
    }
}

contract ProtocolDETFRichBridge_Superchain_SepoliaFork_Test is ProtocolDETFRichBridgeSuperchainTestBase {
    function _ethereumRpcAlias() internal pure override returns (string memory) {
        return "ethereum_sepolia_alchemy";
    }

    function _baseRpcAlias() internal pure override returns (string memory) {
        return "base_sepolia_alchemy";
    }

    function _ethereumForkBlock() internal pure override returns (uint256) {
        return ETHEREUM_SEPOLIA.DEFAULT_FORK_BLOCK;
    }

    function _baseForkBlock() internal pure override returns (uint256) {
        return BASE_SEPOLIA.DEFAULT_FORK_BLOCK;
    }

    function _ethereumCrossDomainMessenger() internal pure override returns (address) {
        return ETHEREUM_SEPOLIA.BASE_L1_CROSS_DOMAIN_MESSENGER;
    }

    function _ethereumStandardBridge() internal pure override returns (address) {
        return ETHEREUM_SEPOLIA.BASE_L1_STANDARD_BRIDGE;
    }

    function _baseCrossDomainMessenger() internal pure override returns (address) {
        return BASE_SEPOLIA.L2_CROSSDOMAIN_MESSENGER;
    }

    function _baseStandardBridge() internal pure override returns (address) {
        return BASE_SEPOLIA.L2_STANDARD_BRIDGE;
    }

    function _baseMintableFactory() internal pure override returns (address) {
        return BASE_SEPOLIA.OPTIMISM_MINTABLE_ERC20_FACTORY;
    }

    function _baseChainId() internal pure override returns (uint256) {
        return BASE_SEPOLIA.CHAIN_ID;
    }

    function _ethereumChainId() internal pure override returns (uint256) {
        return ETHEREUM_SEPOLIA.CHAIN_ID;
    }
}