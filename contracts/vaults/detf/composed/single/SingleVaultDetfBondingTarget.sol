// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPositionManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPositionManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {Actions} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Actions.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {SuperchainSenderNonceRepo} from "@crane/contracts/protocols/l2s/superchain/senders/SuperchainSenderNonceRepo.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
import {IRICHIR} from "contracts/interfaces/IRICHIR.sol";
import {ITokenTransferRelayer} from "@crane/contracts/interfaces/ITokenTransferRelayer.sol";
import {SingleVaultDetfCommon} from "contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/core/DETFBondLifecycleLib.sol";
import {ProtocolDETFSuperchainBridgeRepo} from "contracts/vaults/protocol/ProtocolDETFSuperchainBridgeRepo.sol";
import {IUniswapV4StandardExchangePositionImport} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";

interface ISingleVaultDetfBonding {
    function acceptedBondTokens() external view returns (address[] memory tokens);
    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted);
    function setRichirToken(IRICHIR richirToken) external;
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool wethAsEth, uint256 deadline)
        external
        payable
        returns (uint256 tokenId, uint256 shares);
    function bondWithPosition(
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 lockDuration,
        address recipient,
        uint256 deadline
    )
        external
        payable
        returns (uint256 tokenId, uint256 shares);
    function captureSeigniorage() external returns (uint256 bptReceived);
    function sellNFT(uint256 tokenId, address recipient) external returns (uint256 richirMinted);
    function donate(IERC20 token, uint256 amount, bool pretransferred) external;
    function bridgeRichir(IProtocolDETF.BridgeArgs calldata args)
        external
        returns (uint256 localRichirOut, uint256 richOut);
    function receiveBridgedRich(address recipient, uint256 richAmount, uint256 deadline)
        external
        returns (uint256 richirOut);
}

contract SingleVaultDetfBondingTarget is SingleVaultDetfCommon, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using BetterEfficientHashLib for bytes;
    using SingleVaultDetfRepo for SingleVaultDetfRepo.Storage;

    struct BridgeExecution {
        ProtocolDETFSuperchainBridgeRepo.PeerConfig peer;
        IERC20 remoteDetfToken;
        IERC20 remoteRichToken;
        uint256 bridgeMinGasLimit;
        uint256 actualRichirIn;
        uint256 sharesBurned;
        uint256 reserveSharesBurned;
        uint256 chirAmountOut;
        uint256 vaultSharesOut;
        uint256 localBptOut;
        uint256 senderNonce;
    }

    error EthRefundFailed(address recipient, uint256 amount);
    error InvalidPositionPool(bytes32 expectedPoolKeyHash, bytes32 actualPoolKeyHash);
    error InvalidPositionCurrency(address currency);

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

    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        return SingleVaultDetfRepo._acceptedBondTokens();
    }

    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted_) {
        return SingleVaultDetfRepo._isAcceptedBondToken(address(token));
    }

    function setRichirToken(IRICHIR richirToken_) external {
        MultiStepOwnableRepo._onlyOwner();
        SingleVaultDetfRepo._setRichirToken(richirToken_);
    }

    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, bool wethAsEth, uint256 deadline)
        external
        payable
        lock
        returns (uint256 tokenId, uint256 shares)
    {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }
        if (amountIn == 0) {
            revert ZeroAmount();
        }

        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        uint256 wethAmount = _collectBondInput(layoutStruct, tokenIn, amountIn, wethAsEth, deadline);
        BondAssets memory assets = _bondFromWeth(layoutStruct, wethAmount, deadline);
        shares = assets.bptOut;
        tokenId = DETFBondLifecycleLib._createBondPosition(layoutStruct.protocolNFTVault, shares, lockDuration, recipient);
        ERC4626Repo._setLastTotalAssets(IERC20(layoutStruct.reservePool).balanceOf(address(this)));
    }

    function bondWithPosition(
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 lockDuration,
        address recipient,
        uint256 deadline
    )
        external
        payable
        lock
        returns (uint256 tokenId, uint256 shares)
    {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (msg.value != 0) {
            revert IncorrectEthValue(0, msg.value);
        }

        uint256 vaultSharesIn = _collectVaultSharesFromPosition(layoutStruct, positionManager, positionTokenId, deadline);
        if (vaultSharesIn == 0) {
            revert ZeroAmount();
        }

        BondAssets memory assets = _bondFromVaultShares(layoutStruct, vaultSharesIn);
        shares = assets.bptOut;
        tokenId = DETFBondLifecycleLib._createBondPosition(layoutStruct.protocolNFTVault, shares, lockDuration, recipient);
        ERC4626Repo._setLastTotalAssets(IERC20(layoutStruct.reservePool).balanceOf(address(this)));
    }

    function _collectVaultSharesFromPosition(
        SingleVaultDetfRepo.Storage storage layoutStruct,
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 deadline
    ) internal returns (uint256 vaultSharesIn_) {
        (PoolKey memory poolKey,) = positionManager.getPoolAndPositionInfo(positionTokenId);
        bytes32 poolKeyHash = abi.encode(poolKey)._hash();
        if (poolKeyHash != layoutStruct._wethRichPoolKeyHash()) {
            revert InvalidPositionPool(layoutStruct._wethRichPoolKeyHash(), poolKeyHash);
        }

        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        if (token0 == address(0)) {
            revert InvalidPositionCurrency(token0);
        }
        if (token1 == address(0)) {
            revert InvalidPositionCurrency(token1);
        }

        if (IERC20(address(layoutStruct.wethRichVault)).totalSupply() == 0) {
            return IUniswapV4StandardExchangePositionImport(address(layoutStruct.wethRichVault)).importPosition(
                positionManager, positionTokenId, 0, msg.sender, address(this), deadline
            );
        }

        IERC20 token0Contract = IERC20(token0);
        IERC20 token1Contract = IERC20(token1);
        uint256 token0Before = token0Contract.balanceOf(address(this));
        uint256 token1Before = token1Contract.balanceOf(address(this));

        IERC721(address(positionManager)).transferFrom(msg.sender, address(this), positionTokenId);
        _burnPositionToContract(positionManager, positionTokenId, poolKey, deadline);

        uint256 token0Amount = token0Contract.balanceOf(address(this)) - token0Before;
        uint256 token1Amount = token1Contract.balanceOf(address(this)) - token1Before;

        vaultSharesIn_ += _depositPositionTokenToVault(layoutStruct, token0Contract, token0Amount, deadline);
        vaultSharesIn_ += _depositPositionTokenToVault(layoutStruct, token1Contract, token1Amount, deadline);
    }

    function _burnPositionToContract(
        IPositionManager positionManager,
        uint256 positionTokenId,
        PoolKey memory poolKey,
        uint256 deadline
    ) internal {
        bytes memory actions = abi.encodePacked(uint8(Actions.BURN_POSITION), uint8(Actions.TAKE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(positionTokenId, uint128(0), uint128(0), bytes(""));
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1, address(this));
        positionManager.modifyLiquidities(abi.encode(actions, params), deadline);
    }

    function _depositPositionTokenToVault(
        SingleVaultDetfRepo.Storage storage layoutStruct,
        IERC20 token,
        uint256 amount,
        uint256 deadline
    ) internal returns (uint256 vaultSharesOut_) {
        if (amount == 0) {
            return 0;
        }

        token.safeTransfer(address(layoutStruct.wethRichVault), amount);
        vaultSharesOut_ = layoutStruct.wethRichVault.exchangeIn(
            token,
            amount,
            IERC20(address(layoutStruct.wethRichVault)),
            0,
            address(this),
            true,
            deadline
        );
    }

    function _collectBondInput(
        SingleVaultDetfRepo.Storage storage layoutStruct,
        IERC20 tokenIn,
        uint256 amountIn,
        bool wethAsEth,
        uint256 deadline
    ) internal returns (uint256 wethAmount_) {
        if (!layoutStruct._isAcceptedBondToken(address(tokenIn))) {
            revert BondTokenNotSupported(tokenIn);
        }

        if (_isWethToken(layoutStruct, tokenIn)) {
            if (wethAsEth) {
                if (msg.value != amountIn) {
                    revert IncorrectEthValue(amountIn, msg.value);
                }
                IWETH(address(layoutStruct.wethToken)).deposit{value: amountIn}();
            } else {
                if (msg.value != 0) {
                    revert IncorrectEthValue(0, msg.value);
                }
                tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
            }
            return amountIn;
        }

        if (_isRichToken(layoutStruct, tokenIn)) {
            if (msg.value != 0) {
                revert IncorrectEthValue(0, msg.value);
            }

            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
            tokenIn.safeTransfer(address(layoutStruct.wethRichVault), amountIn);
            wethAmount_ = layoutStruct.wethRichVault.exchangeIn(
                tokenIn,
                amountIn,
                layoutStruct.wethToken,
                0,
                address(this),
                true,
                deadline
            );
            return wethAmount_;
        }

        revert BondTokenNotSupported(tokenIn);
    }

    function captureSeigniorage() external lock returns (uint256 bptReceived_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        uint256 chirAmount = DETFBondLifecycleLib._collectProtocolRewards(layoutStruct.protocolNFTVault);

        bptReceived_ = _addLiquidityToReservePool(layoutStruct, chirAmount, 0);
        IERC20 reservePoolToken = IERC20(layoutStruct.reservePool);
        DETFBondLifecycleLib._addReservePoolBptToProtocolNft(
            reservePoolToken, layoutStruct.protocolNFTVault, layoutStruct.protocolNFTId, bptReceived_
        );
    }

    function sellNFT(uint256 tokenId, address recipient) external lock returns (uint256 richirMinted_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        IRICHIR richir = layoutStruct._richirToken();
        if (address(richir) == address(0)) {
            revert InvalidToken(IERC20(address(0)));
        }

        uint256 principalShares;
        (principalShares, richirMinted_) = DETFBondLifecycleLib._sellPositionToRichir(
            layoutStruct.protocolNFTVault,
            richir,
            tokenId,
            msg.sender,
            recipient
        );
        if (principalShares == 0) {
            revert ZeroAmount();
        }
    }

    function donate(IERC20 token, uint256 amount, bool pretransferred) external lock {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        if (!_isWethToken(layoutStruct, token) && !_isChirToken(token)) {
            revert InvalidDonationToken(token);
        }

        if (!pretransferred) {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }

        if (_isChirToken(token)) {
            ERC20Repo._burn(address(this), amount);
            return;
        }

        BondAssets memory assets = _bondFromWeth(layoutStruct, amount, block.timestamp);
        IERC20 reservePoolToken = IERC20(layoutStruct.reservePool);
        DETFBondLifecycleLib._addReservePoolBptToProtocolNft(
            reservePoolToken, layoutStruct.protocolNFTVault, layoutStruct.protocolNFTId, assets.bptOut
        );
    }

    function claimLiquidity(uint256 lpAmount, address recipient) external lock returns (uint256 extractedWeth_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (msg.sender != address(layoutStruct.protocolNFTVault)) {
            revert NotNFTVault(msg.sender);
        }
        if (recipient == address(0)) {
            recipient = msg.sender;
        }
        if (lpAmount == 0) {
            return 0;
        }

        (uint256 chirAmountOut, uint256 vaultSharesOut) = _exitReservePoolProportionalForBridge(layoutStruct, lpAmount);
        _redepositChirToReservePool(layoutStruct, chirAmountOut);
        extractedWeth_ = _redeemVaultSharesToWeth(layoutStruct, vaultSharesOut, recipient, block.timestamp);
        ERC4626Repo._setLastTotalAssets(IERC20(layoutStruct.reservePool).balanceOf(address(this)));
    }

    function bridgeRichir(IProtocolDETF.BridgeArgs calldata args)
        external
        lock
        returns (uint256 localRichirOut, uint256 richOut)
    {
        if (block.timestamp > args.deadline) {
            revert DeadlineExceeded(args.deadline, block.timestamp);
        }
        if (args.richirAmount == 0) {
            revert ZeroAmount();
        }

        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        ProtocolDETFSuperchainBridgeRepo.Storage storage bridgeLayout = ProtocolDETFSuperchainBridgeRepo._layoutStruct();
        if (
            address(bridgeLayout.messenger) == address(0)
                || address(bridgeLayout.standardBridge) == address(0)
                || address(bridgeLayout.bridgeTokenRegistry) == address(0)
        ) {
            revert BridgeConfigNotSet();
        }

        BridgeExecution memory execution;

        execution.peer = bridgeLayout.peers[args.targetChainId];
        if (execution.peer.relayer == address(0)) {
            execution.peer = ProtocolDETFSuperchainBridgeRepo.PeerConfig({relayer: bridgeLayout.defaultPeerRelayer});
        }
        if (execution.peer.relayer == address(0)) {
            revert BridgePeerNotConfigured(args.targetChainId);
        }

        execution.remoteDetfToken = bridgeLayout.bridgeTokenRegistry.getRemoteToken(args.targetChainId, IERC20(address(this)));
        if (address(execution.remoteDetfToken) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(args.targetChainId, IERC20(address(this)));
        }

        (execution.remoteRichToken, execution.bridgeMinGasLimit) =
            bridgeLayout.bridgeTokenRegistry.getRemoteTokenAndLimit(args.targetChainId, layoutStruct.richToken);
        if (address(execution.remoteRichToken) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(args.targetChainId, layoutStruct.richToken);
        }

        uint256 richirBalanceBefore = layoutStruct._richirToken().balanceOf(address(this));
        IERC20(address(layoutStruct._richirToken())).safeTransferFrom(msg.sender, address(this), args.richirAmount);
        execution.actualRichirIn = layoutStruct._richirToken().balanceOf(address(this)) - richirBalanceBefore;
        if (execution.actualRichirIn == 0) {
            revert ZeroAmount();
        }

        execution.sharesBurned = layoutStruct._richirToken().convertToShares(execution.actualRichirIn);
        execution.reserveSharesBurned = _previewRichirRedemptionBptIn(layoutStruct, execution.actualRichirIn);

        IERC20(address(layoutStruct._richirToken())).safeTransfer(address(layoutStruct._richirToken()), execution.actualRichirIn);
        layoutStruct._richirToken().burnShares(execution.actualRichirIn, address(0), true);

        (execution.chirAmountOut, execution.vaultSharesOut) =
            _exitReservePoolProportionalForBridge(layoutStruct, execution.reserveSharesBurned);

        if (execution.chirAmountOut > 0) {
            execution.localBptOut = _addLiquidityToReservePool(layoutStruct, execution.chirAmountOut, 0);
            if (execution.localBptOut > 0) {
                IERC20 reservePoolToken = IERC20(layoutStruct.reservePool);
                DETFBondLifecycleLib._addReservePoolBptToProtocolNft(
                    reservePoolToken, layoutStruct.protocolNFTVault, layoutStruct.protocolNFTId, execution.localBptOut
                );
                localRichirOut = layoutStruct._richirToken().mintFromNFTSale(execution.localBptOut, msg.sender);
            }
        }

        if (localRichirOut < args.minLocalRichirOut) {
            revert SlippageExceeded(args.minLocalRichirOut, localRichirOut);
        }

        if (execution.vaultSharesOut > 0) {
            IERC20(address(layoutStruct.wethRichVault)).forceApprove(address(layoutStruct.wethRichVault), execution.vaultSharesOut);
            richOut = layoutStruct.wethRichVault.exchangeIn(
                IERC20(address(layoutStruct.wethRichVault)),
                execution.vaultSharesOut,
                layoutStruct.richToken,
                0,
                address(this),
                false,
                args.deadline
            );
        }

        if (richOut < args.minRichOut) {
            revert SlippageExceeded(args.minRichOut, richOut);
        }

        execution.senderNonce = SuperchainSenderNonceRepo._useNonce(address(this), args.targetChainId);

        layoutStruct.richToken.forceApprove(address(bridgeLayout.standardBridge), richOut);
        bridgeLayout.standardBridge.bridgeERC20To(
            address(layoutStruct.richToken),
            address(execution.remoteRichToken),
            execution.peer.relayer,
            richOut,
            uint32(execution.bridgeMinGasLimit),
            bytes("")
        );

        bytes memory receiveData = abi.encodeCall(
            IProtocolDETF.receiveBridgedRich,
            (args.recipient == address(0) ? msg.sender : args.recipient, richOut, args.deadline)
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

        ERC4626Repo._setLastTotalAssets(IERC20(layoutStruct.reservePool).balanceOf(address(this)));

        emit BridgeInitiated(
            msg.sender,
            args.targetChainId,
            args.recipient == address(0) ? msg.sender : args.recipient,
            execution.actualRichirIn,
            execution.sharesBurned,
            execution.reserveSharesBurned,
            localRichirOut,
            richOut,
            execution.senderNonce
        );
    }

    function receiveBridgedRich(address recipient, uint256 richAmount, uint256 deadline)
        external
        lock
        returns (uint256 richirOut)
    {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        address expectedRelayer = ProtocolDETFSuperchainBridgeRepo._localRelayer();

        if (expectedRelayer == address(0)) {
            revert BridgeConfigNotSet();
        }
        if (msg.sender != expectedRelayer) {
            revert NotBridgeRelayer(msg.sender, expectedRelayer);
        }

        recipient = recipient == address(0) ? msg.sender : recipient;
        richirOut = _receiveBridgedRichToRichir(layoutStruct, richAmount, recipient, deadline);

        emit BridgeReceived(msg.sender, recipient, richAmount, richirOut);
    }

    function _receiveBridgedRichToRichir(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 richAmount_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 richirOut_) {
        uint256 actualIn = _secureTokenTransfer(layoutStruct_.richToken, richAmount_, false);
        layoutStruct_.richToken.safeTransfer(address(layoutStruct_.wethRichVault), actualIn);
        uint256 wethAmount = layoutStruct_.wethRichVault.exchangeIn(
            layoutStruct_.richToken,
            actualIn,
            layoutStruct_.wethToken,
            0,
            address(this),
            true,
            deadline_
        );

        richirOut_ = _mintRichirFromWeth(layoutStruct_, wethAmount, recipient_, deadline_);
    }
}