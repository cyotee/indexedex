// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
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

import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {ITokenTransferRelayer} from "@crane/contracts/interfaces/ITokenTransferRelayer.sol";
import {DetfSuperchainBridgeRepo} from "contracts/vaults/detf/DetfSuperchainBridgeRepo.sol";
import {SingleVaultDetfCommon} from "contracts/vaults/detf/composed/single/SingleVaultDetfCommon.sol";
import {SingleVaultDetfRepo} from "contracts/vaults/detf/composed/single/SingleVaultDetfRepo.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/core/DETFBondLifecycleLib.sol";
import {IUniswapV4StandardExchangePositionImport} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol";

interface ISingleVaultDetfBonding {
    function acceptedBondTokens() external view returns (address[] memory tokens);
    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted);
    function setRebasingClaimToken(IRebasingClaimToken rebasingClaimToken) external;
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, uint256 deadline)
        external
        returns (uint256 tokenId, uint256 shares);
    function bondWithPosition(
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 lockDuration,
        address recipient,
        uint256 deadline
    )
        external
        returns (uint256 tokenId, uint256 shares);
    function captureSeigniorage() external returns (uint256 bptReceived);
    function sellNFT(uint256 tokenId, address recipient) external returns (uint256 rebasingClaimMinted);
    function donate(IERC20 token, uint256 amount, bool pretransferred) external;
    function bridgeRebasingClaim(IDetf.BridgeArgs calldata args)
        external
        returns (uint256 localRebasingClaimOut, uint256 pairOut);
    function receiveBridgedPair(address recipient, uint256 pairAmount, uint256 deadline)
        external
        returns (uint256 rebasingClaimOut);
}

contract SingleVaultDetfBondingTarget is SingleVaultDetfCommon, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using BetterEfficientHashLib for bytes;
    using SingleVaultDetfRepo for SingleVaultDetfRepo.Storage;

    struct BridgeExecution {
        DetfSuperchainBridgeRepo.PeerConfig peer;
        IERC20 remoteDetfToken;
        IERC20 remotePairToken;
        uint256 bridgeMinGasLimit;
        uint256 actualRebasingClaimIn;
        uint256 sharesBurned;
        uint256 reserveSharesBurned;
        uint256 detfAmountOut;
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
        uint256 rebasingClaimAmountIn,
        uint256 sharesBurned,
        uint256 reserveSharesBurned,
        uint256 localRebasingClaimOut,
        uint256 pairOut,
        uint256 nonce
    );

    event BridgeReceived(address indexed relayer, address indexed recipient, uint256 pairAmount, uint256 rebasingClaimOut);

    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        return SingleVaultDetfRepo._acceptedBondTokens();
    }

    function isAcceptedBondToken(IERC20 token) external view returns (bool isAccepted_) {
        return SingleVaultDetfRepo._isAcceptedBondToken(address(token));
    }

    function setRebasingClaimToken(IRebasingClaimToken rebasingClaimToken_) external {
        MultiStepOwnableRepo._onlyOwner();
        SingleVaultDetfRepo._setRebasingClaimToken(rebasingClaimToken_);
    }

    function bond(IERC20 tokenIn, uint256 amountIn, uint256 lockDuration, address recipient, uint256 deadline)
        external
        nonReentrant
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
        uint256 rateAssetAmount = _collectBondInput(layoutStruct, tokenIn, amountIn, deadline);
        (tokenId, shares) = _createBondPositionFromBondAssets(
            layoutStruct, _bondFromRateAsset(layoutStruct, rateAssetAmount, deadline), lockDuration, recipient
        );
    }

    function bondWithPosition(
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 lockDuration,
        address recipient,
        uint256 deadline
    )
        external
        nonReentrant
        returns (uint256 tokenId, uint256 shares)
    {
        if (block.timestamp > deadline) {
            revert DeadlineExceeded(deadline, block.timestamp);
        }

        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        uint256 vaultSharesIn = _collectVaultSharesFromPosition(layoutStruct, positionManager, positionTokenId, deadline);
        if (vaultSharesIn == 0) {
            revert ZeroAmount();
        }

        (tokenId, shares) = _createBondPositionFromBondAssets(
            layoutStruct, _bondFromVaultShares(layoutStruct, vaultSharesIn), lockDuration, recipient
        );
    }

    function _createBondPositionFromBondAssets(
        SingleVaultDetfRepo.Storage storage layoutStruct,
        BondAssets memory assets,
        uint256 lockDuration,
        address recipient
    ) internal returns (uint256 tokenId_, uint256 shares_) {
        shares_ = assets.bptOut;
        tokenId_ = DETFBondLifecycleLib._createBondPosition(layoutStruct.detfNFTVault, shares_, lockDuration, recipient);
        _syncLastTotalAssetsFromReservePool(layoutStruct);
    }

    function _addReservePoolBptToDetfNft(
        SingleVaultDetfRepo.Storage storage layoutStruct,
        uint256 bptAmount
    ) internal {
        if (bptAmount == 0) {
            return;
        }

        DETFBondLifecycleLib._addReservePoolBptToDetfNft(
            IERC20(layoutStruct.reservePool), layoutStruct.detfNFTVault, layoutStruct.detfNFTId, bptAmount
        );
    }

    function _collectVaultSharesFromPosition(
        SingleVaultDetfRepo.Storage storage layoutStruct,
        IPositionManager positionManager,
        uint256 positionTokenId,
        uint256 deadline
    ) internal returns (uint256 vaultSharesIn_) {
        (PoolKey memory poolKey,) = positionManager.getPoolAndPositionInfo(positionTokenId);
        bytes32 poolKeyHash = abi.encode(poolKey)._hash();
        if (poolKeyHash != layoutStruct._underlyingPoolKeyHash()) {
            revert InvalidPositionPool(layoutStruct._underlyingPoolKeyHash(), poolKeyHash);
        }

        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);
        if (token0 == address(0)) {
            revert InvalidPositionCurrency(token0);
        }
        if (token1 == address(0)) {
            revert InvalidPositionCurrency(token1);
        }

        if (IERC20(address(layoutStruct.underlyingVault)).totalSupply() == 0) {
            return IUniswapV4StandardExchangePositionImport(address(layoutStruct.underlyingVault)).importPosition(
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

        token.safeTransfer(address(layoutStruct.underlyingVault), amount);
        vaultSharesOut_ = layoutStruct.underlyingVault.exchangeIn(
            token,
            amount,
            IERC20(address(layoutStruct.underlyingVault)),
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
        uint256 deadline
    ) internal returns (uint256 rateAssetAmount_) {
        if (!layoutStruct._isAcceptedBondToken(address(tokenIn))) {
            revert BondTokenNotSupported(tokenIn);
        }

        if (_isRateAsset(layoutStruct, tokenIn)) {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
            return amountIn;
        }

        if (_isPairToken(layoutStruct, tokenIn)) {
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
            rateAssetAmount_ = _convertPairToRateAsset(layoutStruct, amountIn, deadline);
            return rateAssetAmount_;
        }

        revert BondTokenNotSupported(tokenIn);
    }

    function captureSeigniorage() external nonReentrant returns (uint256 bptReceived_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        uint256 detfAmount = DETFBondLifecycleLib._collectDetfNftRewards(layoutStruct.detfNFTVault);

        bptReceived_ = _addLiquidityToReservePool(layoutStruct, detfAmount, 0);
        _addReservePoolBptToDetfNft(layoutStruct, bptReceived_);
    }

    function sellNFT(uint256 tokenId, address recipient) external nonReentrant returns (uint256 rebasingClaimMinted_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        IRebasingClaimToken richir = layoutStruct._rebasingClaimToken();
        if (address(richir) == address(0)) {
            revert InvalidToken(IERC20(address(0)));
        }

        uint256 principalShares;
        (principalShares, rebasingClaimMinted_) = DETFBondLifecycleLib._sellPositionToRebasingClaim(
            layoutStruct.detfNFTVault,
            richir,
            tokenId,
            msg.sender,
            recipient
        );
        if (principalShares == 0) {
            revert ZeroAmount();
        }
    }

    function donate(IERC20 token, uint256 amount, bool pretransferred) external nonReentrant {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }

        if (!_isRateAsset(layoutStruct, token) && !_isDetfToken(token)) {
            revert InvalidDonationToken(token);
        }

        if (!pretransferred) {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }

        if (_isDetfToken(token)) {
            ERC20Repo._burn(address(this), amount);
            return;
        }

        BondAssets memory assets = _bondFromRateAsset(layoutStruct, amount, block.timestamp);
        _addReservePoolBptToDetfNft(layoutStruct, assets.bptOut);
    }

    function claimLiquidity(uint256 lpAmount, address recipient) external nonReentrant returns (uint256 extractedWeth_) {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }
        if (msg.sender != address(layoutStruct.detfNFTVault)) {
            revert NotNFTVault(msg.sender);
        }
        if (recipient == address(0)) {
            recipient = msg.sender;
        }
        if (lpAmount == 0) {
            return 0;
        }

        (uint256 detfAmountOut, uint256 vaultSharesOut) = _exitReservePoolProportionalForBridge(layoutStruct, lpAmount);
        _redepositDetfToReservePool(layoutStruct, detfAmountOut);
        extractedWeth_ = _redeemVaultSharesToWeth(layoutStruct, vaultSharesOut, recipient, block.timestamp);
        _syncLastTotalAssetsFromReservePool(layoutStruct);
    }

    function bridgeRebasingClaim(IDetf.BridgeArgs calldata args)
        external
        nonReentrant
        returns (uint256 localRebasingClaimOut, uint256 pairOut)
    {
        if (block.timestamp > args.deadline) {
            revert DeadlineExceeded(args.deadline, block.timestamp);
        }
        if (args.rebasingClaimAmount == 0) {
            revert ZeroAmount();
        }

        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        if (!_isInitialized()) {
            revert ReservePoolNotInitialized();
        }

        DetfSuperchainBridgeRepo.Storage storage bridgeLayout = DetfSuperchainBridgeRepo._layoutStruct();
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
            execution.peer = DetfSuperchainBridgeRepo.PeerConfig({relayer: bridgeLayout.defaultPeerRelayer});
        }
        if (execution.peer.relayer == address(0)) {
            revert BridgePeerNotConfigured(args.targetChainId);
        }

        execution.remoteDetfToken = bridgeLayout.bridgeTokenRegistry.getRemoteToken(args.targetChainId, IERC20(address(this)));
        if (address(execution.remoteDetfToken) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(args.targetChainId, IERC20(address(this)));
        }

        (execution.remotePairToken, execution.bridgeMinGasLimit) =
            bridgeLayout.bridgeTokenRegistry.getRemoteTokenAndLimit(args.targetChainId, layoutStruct.pairToken);
        if (address(execution.remotePairToken) == address(0)) {
            revert BridgeRemoteTokenNotConfigured(args.targetChainId, layoutStruct.pairToken);
        }

        uint256 rebasingClaimBalanceBefore = layoutStruct._rebasingClaimToken().balanceOf(address(this));
        IERC20(address(layoutStruct._rebasingClaimToken())).safeTransferFrom(msg.sender, address(this), args.rebasingClaimAmount);
        execution.actualRebasingClaimIn = layoutStruct._rebasingClaimToken().balanceOf(address(this)) - rebasingClaimBalanceBefore;
        if (execution.actualRebasingClaimIn == 0) {
            revert ZeroAmount();
        }

        execution.sharesBurned = layoutStruct._rebasingClaimToken().convertToShares(execution.actualRebasingClaimIn);
        execution.reserveSharesBurned = _previewRebasingClaimRedemptionBptIn(layoutStruct, execution.actualRebasingClaimIn);

        IERC20(address(layoutStruct._rebasingClaimToken())).safeTransfer(address(layoutStruct._rebasingClaimToken()), execution.actualRebasingClaimIn);
        layoutStruct._rebasingClaimToken().burnShares(execution.actualRebasingClaimIn, address(0), true);

        (execution.detfAmountOut, execution.vaultSharesOut) =
            _exitReservePoolProportionalForBridge(layoutStruct, execution.reserveSharesBurned);

        if (execution.detfAmountOut > 0) {
            execution.localBptOut = _addLiquidityToReservePool(layoutStruct, execution.detfAmountOut, 0);
            localRebasingClaimOut = _mintRebasingClaimFromReservePoolBpt(layoutStruct, execution.localBptOut, msg.sender);
        }

        if (localRebasingClaimOut < args.minLocalRebasingClaimOut) {
            revert SlippageExceeded(args.minLocalRebasingClaimOut, localRebasingClaimOut);
        }

        if (execution.vaultSharesOut > 0) {
            IERC20(address(layoutStruct.underlyingVault)).forceApprove(address(layoutStruct.underlyingVault), execution.vaultSharesOut);
            pairOut = layoutStruct.underlyingVault.exchangeIn(
                IERC20(address(layoutStruct.underlyingVault)),
                execution.vaultSharesOut,
                layoutStruct.pairToken,
                0,
                address(this),
                false,
                args.deadline
            );
        }

        if (pairOut < args.minPairOut) {
            revert SlippageExceeded(args.minPairOut, pairOut);
        }

        execution.senderNonce = SuperchainSenderNonceRepo._useNonce(address(this), args.targetChainId);

        layoutStruct.pairToken.forceApprove(address(bridgeLayout.standardBridge), pairOut);
        bridgeLayout.standardBridge.bridgeERC20To(
            address(layoutStruct.pairToken),
            address(execution.remotePairToken),
            execution.peer.relayer,
            pairOut,
            uint32(execution.bridgeMinGasLimit),
            bytes("")
        );

        bytes memory receiveData = abi.encodeCall(
            IDetf.receiveBridgedPair,
            (args.recipient == address(0) ? msg.sender : args.recipient, pairOut, args.deadline)
        );
        bytes memory relayData = abi.encodeCall(
            ITokenTransferRelayer.relayTokenTransfer,
            (
                address(execution.remoteDetfToken),
                execution.remotePairToken,
                pairOut,
                execution.senderNonce,
                false,
                false,
                receiveData
            )
        );
        bridgeLayout.messenger.sendMessage(execution.peer.relayer, relayData, args.messageGasLimit);

        _syncLastTotalAssetsFromReservePool(layoutStruct);

        emit BridgeInitiated(
            msg.sender,
            args.targetChainId,
            args.recipient == address(0) ? msg.sender : args.recipient,
            execution.actualRebasingClaimIn,
            execution.sharesBurned,
            execution.reserveSharesBurned,
            localRebasingClaimOut,
            pairOut,
            execution.senderNonce
        );
    }

    function receiveBridgedPair(address recipient, uint256 pairAmount, uint256 deadline)
        external
        nonReentrant
        returns (uint256 rebasingClaimOut)
    {
        SingleVaultDetfRepo.Storage storage layoutStruct = SingleVaultDetfRepo._layoutStruct();
        address expectedRelayer = DetfSuperchainBridgeRepo._localRelayer();

        if (expectedRelayer == address(0)) {
            revert BridgeConfigNotSet();
        }
        if (msg.sender != expectedRelayer) {
            revert NotBridgeRelayer(msg.sender, expectedRelayer);
        }

        recipient = recipient == address(0) ? msg.sender : recipient;
        rebasingClaimOut = _receiveBridgedPairToRichir(layoutStruct, pairAmount, recipient, deadline);

        emit BridgeReceived(msg.sender, recipient, pairAmount, rebasingClaimOut);
    }

    function _receiveBridgedPairToRichir(
        SingleVaultDetfRepo.Storage storage layoutStruct_,
        uint256 pairAmount_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 rebasingClaimOut_) {
        uint256 actualIn = _secureTokenTransfer(layoutStruct_.pairToken, pairAmount_, false);
        uint256 wethAmount = _convertPairToRateAsset(layoutStruct_, actualIn, deadline_);

        rebasingClaimOut_ = _mintRebasingClaimFromRateAsset(layoutStruct_, wethAmount, recipient_, deadline_);
    }
}