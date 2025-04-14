"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useSwapState = void 0;
// Swap state management hook
const react_1 = require("react");
const wagmi_1 = require("wagmi");
const viem_1 = require("viem");
const addressArtifacts_1 = require("../../lib/addressArtifacts");
const browserChain_1 = require("../../lib/browserChain");
const tokenlists_1 = require("../../lib/tokenlists");
const buildArgs_1 = require("../../lib/swap/buildArgs");
function useSwapState() {
    const { address, isConnected } = (0, wagmi_1.useAccount)();
    const configChainId = (0, wagmi_1.useChainId)();
    const connection = (0, wagmi_1.useConnection)();
    const connectorId = connection.connector?.id;
    const { data: connectorClient } = (0, wagmi_1.useConnectorClient)();
    const { data: walletClient } = (0, wagmi_1.useWalletClient)();
    const preferredBrowserChainIds = (0, react_1.useMemo)(() => [addressArtifacts_1.CHAIN_ID_BASE_SEPOLIA, addressArtifacts_1.CHAIN_ID_SEPOLIA, addressArtifacts_1.CHAIN_ID_ANVIL, addressArtifacts_1.CHAIN_ID_LOCALHOST, addressArtifacts_1.CHAIN_ID_BASE], []);
    const browserChainId = (0, browserChain_1.usePreferredBrowserChainId)(isConnected, preferredBrowserChainIds, connectorId, address);
    const walletChainId = isConnected ? (browserChainId ?? connectorClient?.chain?.id ?? walletClient?.chain?.id ?? connection.chainId ?? configChainId) : configChainId;
    const resolvedChainId = (0, addressArtifacts_1.resolveArtifactsChainId)(walletChainId ?? 11155111) ?? walletChainId ?? 11155111;
    const isUnsupportedChain = isConnected && walletChainId !== undefined && !(0, addressArtifacts_1.isSupportedChainId)(walletChainId);
    const wagmiPublicClient = (0, wagmi_1.usePublicClient)({ chainId: resolvedChainId });
    const publicClient = (0, react_1.useMemo)(() => (isUnsupportedChain ? null : wagmiPublicClient), [isUnsupportedChain, wagmiPublicClient]);
    const { signTypedDataAsync } = (0, wagmi_1.useSignTypedData)();
    const artifacts = (0, react_1.useMemo)(() => {
        if (isUnsupportedChain)
            return null;
        return (0, addressArtifacts_1.getAddressArtifacts)(resolvedChainId);
    }, [isUnsupportedChain, resolvedChainId]);
    const platform = artifacts?.platform;
    const weth9Address = (0, react_1.useMemo)(() => {
        const addr = (platform?.weth9 ?? '');
        if (!addr || addr === '0x0000000000000000000000000000000000000000')
            return null;
        return addr;
    }, [platform?.weth9]);
    // Pool & token options
    const poolOptions = (0, react_1.useMemo)(() => (0, tokenlists_1.buildPoolOptionsForChain)(resolvedChainId), [resolvedChainId]);
    const tokenOptions = (0, react_1.useMemo)(() => (0, tokenlists_1.buildTokenOptionsForChain)(resolvedChainId), [resolvedChainId]);
    const filteredVaultOptions = (0, react_1.useMemo)(() => {
        return tokenOptions.filter((t) => t.type === 'vault' && t.chainId === resolvedChainId);
    }, [tokenOptions, resolvedChainId]);
    // Local state
    const [selectedPool, setSelectedPool] = (0, react_1.useState)('');
    const [tokenIn, setTokenIn] = (0, react_1.useState)('');
    const [tokenOut, setTokenOut] = (0, react_1.useState)('');
    const [amountIn, setAmountIn] = (0, react_1.useState)('');
    const [amountOut, setAmountOut] = (0, react_1.useState)('');
    const [lastEditedField, setLastEditedField] = (0, react_1.useState)('in');
    const [useEthIn, setUseEthIn] = (0, react_1.useState)(false);
    const [useEthOut, setUseEthOut] = (0, react_1.useState)(false);
    const [slippage, setSlippage] = (0, react_1.useState)(1);
    const [useTokenInVault, setUseTokenInVault] = (0, react_1.useState)(false);
    const [useTokenOutVault, setUseTokenOutVault] = (0, react_1.useState)(false);
    const [selectedVaultIn, setSelectedVaultIn] = (0, react_1.useState)('');
    const [selectedVaultOut, setSelectedVaultOut] = (0, react_1.useState)('');
    const [approvalMode, setApprovalMode] = (0, react_1.useState)('signed');
    const [approvalModeInitialized, setApprovalModeInitialized] = (0, react_1.useState)(false);
    const [showApprovalSettings, setShowApprovalSettings] = (0, react_1.useState)(false);
    const [useMaxApproval, setUseMaxApproval] = (0, react_1.useState)(false);
    // Resolved addresses
    const tokenInAddress = (0, react_1.useMemo)(() => {
        if (useEthIn && weth9Address)
            return weth9Address;
        if (!tokenIn)
            return null;
        return (0, tokenlists_1.resolveTokenAddressFromOptionForChain)(resolvedChainId, tokenIn);
    }, [resolvedChainId, tokenIn, useEthIn, weth9Address]);
    const tokenOutAddress = (0, react_1.useMemo)(() => {
        if (useEthOut && weth9Address)
            return weth9Address;
        if (!tokenOut)
            return null;
        return (0, tokenlists_1.resolveTokenAddressFromOptionForChain)(resolvedChainId, tokenOut);
    }, [resolvedChainId, tokenOut, useEthOut, weth9Address]);
    const rawPoolAddress = (0, react_1.useMemo)(() => {
        if (!selectedPool)
            return null;
        const option = poolOptions.find((p) => p.value === selectedPool);
        return option?.value;
    }, [selectedPool, poolOptions]);
    const isWethSentinelWrapUnwrapFlow = (0, react_1.useMemo)(() => {
        return (useEthIn ||
            useEthOut ||
            (tokenInAddress && tokenInAddress === weth9Address) ||
            (tokenOutAddress && tokenOutAddress === weth9Address));
    }, [useEthIn, useEthOut, tokenInAddress, tokenOutAddress, weth9Address]);
    const effectiveUseTokenInVault = (0, react_1.useMemo)(() => useTokenInVault && !!selectedVaultIn, [useTokenInVault, selectedVaultIn]);
    const effectiveUseTokenOutVault = (0, react_1.useMemo)(() => useTokenOutVault && !!selectedVaultOut, [useTokenOutVault, selectedVaultOut]);
    const poolAddress = (0, react_1.useMemo)(() => rawPoolAddress, [rawPoolAddress]);
    const tokenInVaultAddress = (0, react_1.useMemo)(() => {
        if (!effectiveUseTokenInVault)
            return buildArgs_1.ZERO_ADDR;
        return selectedVaultIn || buildArgs_1.ZERO_ADDR;
    }, [effectiveUseTokenInVault, selectedVaultIn]);
    const tokenOutVaultAddress = (0, react_1.useMemo)(() => {
        if (!effectiveUseTokenOutVault)
            return buildArgs_1.ZERO_ADDR;
        return selectedVaultOut || buildArgs_1.ZERO_ADDR;
    }, [effectiveUseTokenOutVault, selectedVaultOut]);
    const exactAmountInField = (0, react_1.useMemo)(() => {
        if (!amountIn || !tokenInAddress)
            return undefined;
        const decimals = (0, tokenlists_1.getTokenDecimalsByAddressForChain)(resolvedChainId, tokenInAddress);
        return parseFloat(amountIn) > 0 ? (0, viem_1.parseUnits)(amountIn, decimals) : undefined;
    }, [resolvedChainId, amountIn, tokenInAddress]);
    const exactAmountOutField = (0, react_1.useMemo)(() => {
        if (!amountOut || !tokenOutAddress)
            return undefined;
        const decimals = (0, tokenlists_1.getTokenDecimalsByAddressForChain)(resolvedChainId, tokenOutAddress);
        return parseFloat(amountOut) > 0 ? (0, viem_1.parseUnits)(amountOut, decimals) : undefined;
    }, [resolvedChainId, amountOut, tokenOutAddress]);
    const deadline = (0, react_1.useMemo)(() => {
        return BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour
    }, []);
    const poolType = (0, react_1.useMemo)(() => {
        if (!selectedPool)
            return undefined;
        return (0, tokenlists_1.resolvePoolTypeForChain)(resolvedChainId, selectedPool);
    }, [resolvedChainId, selectedPool]);
    // Build swap arguments
    const builtExactIn = (0, react_1.useMemo)(() => {
        if (!address || !poolAddress || !tokenInAddress || !tokenOutAddress) {
            return { route: null, finalPool: null, args: null, valid: false, missing: [] };
        }
        return (0, buildArgs_1.buildExactInArgs)({
            poolType,
            poolAddress,
            tokenInAddress,
            tokenOutAddress,
            tokenInVaultAddress,
            tokenOutVaultAddress,
            exactAmountIn: exactAmountInField,
            sender: address,
            useTokenInVault: effectiveUseTokenInVault,
            useTokenOutVault: effectiveUseTokenOutVault
        });
    }, [address, poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountInField, effectiveUseTokenInVault, effectiveUseTokenOutVault]);
    const builtExactOut = (0, react_1.useMemo)(() => {
        if (!address || !poolAddress || !tokenInAddress || !tokenOutAddress) {
            return { route: null, finalPool: null, args: null, valid: false, missing: [] };
        }
        return (0, buildArgs_1.buildExactOutArgs)({
            poolType,
            poolAddress,
            tokenInAddress,
            tokenOutAddress,
            tokenInVaultAddress,
            tokenOutVaultAddress,
            exactAmountOut: exactAmountOutField,
            sender: address,
            useTokenInVault: effectiveUseTokenInVault,
            useTokenOutVault: effectiveUseTokenOutVault
        });
    }, [address, poolType, poolAddress, tokenInAddress, tokenOutAddress, tokenInVaultAddress, tokenOutVaultAddress, exactAmountOutField, effectiveUseTokenInVault, effectiveUseTokenOutVault]);
    const ready = (0, react_1.useMemo)(() => {
        return (isConnected &&
            !!address &&
            !!poolAddress &&
            !!tokenInAddress &&
            !!tokenOutAddress &&
            !!builtExactIn.valid &&
            !!builtExactOut.valid);
    }, [isConnected, address, poolAddress, tokenInAddress, tokenOutAddress, builtExactIn.valid, builtExactOut.valid]);
    const routePattern = (0, react_1.useMemo)(() => {
        return builtExactIn.route || builtExactOut.route || null;
    }, [builtExactIn.route, builtExactOut.route]);
    // Slippage calculations
    const minOut = (0, react_1.useMemo)(() => {
        if (exactAmountInField === undefined || !builtExactIn.args)
            return undefined;
        return (exactAmountInField * BigInt(10000 - slippage * 100)) / BigInt(10000);
    }, [exactAmountInField, builtExactIn.args, slippage]);
    const maxIn = (0, react_1.useMemo)(() => {
        if (exactAmountOutField === undefined || !builtExactOut.args)
            return undefined;
        return (exactAmountOutField * BigInt(10000 + slippage * 100)) / BigInt(10000);
    }, [exactAmountOutField, builtExactOut.args, slippage]);
    return {
        // Wallet & chain
        address,
        isConnected,
        chainId: walletChainId ?? configChainId,
        resolvedChainId,
        publicClient,
        signTypedDataAsync,
        platform,
        // Token selection
        selectedPool,
        tokenIn,
        tokenOut,
        amountIn,
        amountOut,
        lastEditedField,
        // Vault options
        useEthIn,
        useEthOut,
        useTokenInVault,
        useTokenOutVault,
        selectedVaultIn,
        selectedVaultOut,
        // Approval settings
        approvalMode,
        approvalModeInitialized,
        showApprovalSettings,
        useMaxApproval,
        // Slippage
        slippage,
        // Resolved addresses
        tokenInAddress,
        tokenOutAddress,
        poolAddress,
        tokenInVaultAddress,
        tokenOutVaultAddress,
        // Pool & token options
        poolOptions,
        tokenOptions,
        filteredVaultOptions,
        // Build results
        builtExactIn,
        builtExactOut,
        ready,
        routePattern,
        // Derived values
        exactAmountInField,
        exactAmountOutField,
        deadline,
        poolType,
        minOut,
        maxIn,
        // Setters
        setSelectedPool,
        setTokenIn,
        setTokenOut,
        setAmountIn,
        setAmountOut,
        setLastEditedField,
        setUseEthIn,
        setUseEthOut,
        setUseTokenInVault,
        setUseTokenOutVault,
        setSelectedVaultIn,
        setSelectedVaultOut,
        setApprovalMode,
        setApprovalModeInitialized,
        setShowApprovalSettings,
        setUseMaxApproval,
        setSlippage,
    };
}
exports.useSwapState = useSwapState;
