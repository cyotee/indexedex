"use strict";
'use client';
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = require("react");
const wagmi_1 = require("wagmi");
const viem_1 = require("viem");
const addressArtifacts_1 = require("../lib/addressArtifacts");
const browserChain_1 = require("../lib/browserChain");
const deploymentEnvironment_1 = require("../lib/deploymentEnvironment");
const tokenlists_1 = require("../lib/tokenlists");
const runtimeChains_1 = require("../lib/runtimeChains");
const protocolDetfAbi = [
    { type: 'function', name: 'richToken', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
    { type: 'function', name: 'richirToken', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
    { type: 'function', name: 'wethToken', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
    { type: 'function', name: 'protocolNFTVault', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
    { type: 'function', name: 'reservePool', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'address' }] },
    { type: 'function', name: 'syntheticPrice', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'uint256' }] },
    { type: 'function', name: 'mintThreshold', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'uint256' }] },
    { type: 'function', name: 'burnThreshold', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'uint256' }] },
    { type: 'function', name: 'isMintingAllowed', stateMutability: 'view', inputs: [], outputs: [{ name: 'allowed', type: 'bool' }] },
    { type: 'function', name: 'isBurningAllowed', stateMutability: 'view', inputs: [], outputs: [{ name: 'allowed', type: 'bool' }] },
    // IStandardExchangeIn - use exchangeIn with WETH->CHIR to mint
    {
        type: 'function',
        name: 'exchangeIn',
        stateMutability: 'nonpayable',
        inputs: [
            { name: 'tokenIn', type: 'address' },
            { name: 'amountIn', type: 'uint256' },
            { name: 'tokenOut', type: 'address' },
            { name: 'minAmountOut', type: 'uint256' },
            { name: 'recipient', type: 'address' },
            { name: 'pretransferred', type: 'bool' },
            { name: 'deadline', type: 'uint256' },
        ],
        outputs: [{ name: 'amountOut', type: 'uint256' }],
    },
    {
        type: 'function',
        name: 'previewExchangeIn',
        stateMutability: 'view',
        inputs: [
            { name: 'tokenIn', type: 'address' },
            { name: 'amountIn', type: 'uint256' },
            { name: 'tokenOut', type: 'address' },
        ],
        outputs: [{ name: 'amountOut', type: 'uint256' }],
    },
    {
        type: 'function',
        name: 'bondWithWeth',
        stateMutability: 'nonpayable',
        inputs: [
            { name: 'amountIn', type: 'uint256' },
            { name: 'lockDuration', type: 'uint256' },
            { name: 'recipient', type: 'address' },
            { name: 'deadline', type: 'uint256' },
        ],
        outputs: [
            { name: 'tokenId', type: 'uint256' },
            { name: 'shares', type: 'uint256' },
        ],
    },
    {
        type: 'function',
        name: 'bondWithRich',
        stateMutability: 'nonpayable',
        inputs: [
            { name: 'amountIn', type: 'uint256' },
            { name: 'lockDuration', type: 'uint256' },
            { name: 'recipient', type: 'address' },
            { name: 'deadline', type: 'uint256' },
        ],
        outputs: [
            { name: 'tokenId', type: 'uint256' },
            { name: 'shares', type: 'uint256' },
        ],
    },
    {
        type: 'function',
        name: 'sellNFT',
        stateMutability: 'nonpayable',
        inputs: [
            { name: 'tokenId', type: 'uint256' },
            { name: 'recipient', type: 'address' },
        ],
        outputs: [{ name: 'richirMinted', type: 'uint256' }],
    },
];
function clampInt(value, fallback) {
    const n = Number(value);
    if (!Number.isFinite(n))
        return fallback;
    return Math.max(0, Math.floor(n));
}
function StakingPageClient() {
  const configChainId = (0, wagmi_1.useChainId)();
  const { address, chainId: accountChainId, isConnected } = (0, wagmi_1.useAccount)();
  const connection = (0, wagmi_1.useConnection)();
  const connectedWalletChainId = (0, browserChain_1.useConnectedWalletChainId)(isConnected, connection.connector);
  const browserChainId = (0, browserChain_1.useBrowserChainId)(isConnected);
  const { data: connectorClient } = (0, wagmi_1.useConnectorClient)();
  const { data: walletClient } = (0, wagmi_1.useWalletClient)();
  const { environment } = (0, deploymentEnvironment_1.useDeploymentEnvironment)();
  const attachedWalletChainId = isConnected
    ? (accountChainId ?? connection.chainId ?? walletClient?.chain?.id ?? connectorClient?.chain?.id ?? connectedWalletChainId ?? browserChainId)
    : undefined;
  const resolvedConfigChainId = configChainId !== undefined ? (0, addressArtifacts_1.resolveArtifactsChainId)(configChainId, environment) : null;
  const resolvedWalletChainId = attachedWalletChainId !== undefined
    ? (0, addressArtifacts_1.resolveArtifactsChainId)(attachedWalletChainId, environment)
    : null;
  const dataChainId = resolvedWalletChainId ?? resolvedConfigChainId ?? addressArtifacts_1.CHAIN_ID_SEPOLIA;
  const detfs = (0, react_1.useMemo)(() => (0, tokenlists_1.getProtocolDetfsForChain)(dataChainId, environment), [dataChainId, environment]);
  const isUnsupportedChain = isConnected && attachedWalletChainId !== undefined && !(0, addressArtifacts_1.isSupportedChainId)(attachedWalletChainId, environment);
  const artifacts = (0, react_1.useMemo)(() => (0, addressArtifacts_1.getAddressArtifacts)(dataChainId, environment), [dataChainId, environment]);
  const platform = artifacts.platform;
    const targetChain = (0, react_1.useMemo)(() => (0, runtimeChains_1.resolveAppChain)(dataChainId), [dataChainId]);
    const detfOptions = (0, react_1.useMemo)(() => detfs.map((t) => ({ value: t.address, label: t.name || t.symbol })), [detfs]);
    const [selectedDetf, setSelectedDetf] = (0, react_1.useState)(() => (detfs[0]?.address ?? ''));
    const { writeContractAsync, isPending: isWritePending } = (0, wagmi_1.useWriteContract)();
    const [status, setStatus] = (0, react_1.useState)('');
  (0, react_1.useEffect)(() => {
    setSelectedDetf(detfs[0]?.address ?? '');
    setStatus('');
  }, [dataChainId, environment]);
  (0, react_1.useEffect)(() => {
    if (detfs.length === 0) {
      setSelectedDetf('');
      return;
    }
    setSelectedDetf((current) => {
      if (current && detfs.some((detf) => detf.address.toLowerCase() === current.toLowerCase())) {
        return current;
      }
      return detfs[0]?.address ?? '';
    });
  }, [detfs]);
    const detfAddress = selectedDetf ? selectedDetf : undefined;
    const hasDetfAddress = !!detfAddress;
    const { data: richToken } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: detfAddress,
        abi: protocolDetfAbi,
        functionName: 'richToken',
        args: [],
        query: { enabled: !!detfAddress },
    });
    const { data: richirToken } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: detfAddress,
        abi: protocolDetfAbi,
        functionName: 'richirToken',
        args: [],
        query: { enabled: !!detfAddress },
    });
    const { data: wethToken } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: detfAddress,
        abi: protocolDetfAbi,
        functionName: 'wethToken',
        args: [],
        query: { enabled: !!detfAddress },
    });
    const { data: nftVault } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: detfAddress,
        abi: protocolDetfAbi,
        functionName: 'protocolNFTVault',
        args: [],
        query: { enabled: !!detfAddress },
    });
    const { data: reservePool } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: detfAddress,
        abi: protocolDetfAbi,
        functionName: 'reservePool',
        args: [],
        query: { enabled: !!detfAddress },
    });
    const { data: syntheticPrice, error: syntheticPriceError } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: detfAddress,
        abi: protocolDetfAbi,
        functionName: 'syntheticPrice',
        args: [],
        query: { enabled: !!detfAddress },
    });
    const { data: mintThreshold, error: mintThresholdError } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: detfAddress,
        abi: protocolDetfAbi,
        functionName: 'mintThreshold',
        args: [],
        query: { enabled: !!detfAddress },
    });
    const { data: burnThreshold, error: burnThresholdError } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: detfAddress,
        abi: protocolDetfAbi,
        functionName: 'burnThreshold',
        args: [],
        query: { enabled: !!detfAddress },
    });
    const { data: isMintingAllowed } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: detfAddress,
        abi: protocolDetfAbi,
        functionName: 'isMintingAllowed',
        args: [],
        query: { enabled: !!detfAddress },
    });
    const { data: isBurningAllowed } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: detfAddress,
        abi: protocolDetfAbi,
        functionName: 'isBurningAllowed',
        args: [],
        query: { enabled: !!detfAddress },
    });
    const { data: richDecimals } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
        address: richToken && richToken !== viem_1.zeroAddress ? richToken : undefined,
        abi: viem_1.erc20Abi,
        functionName: 'decimals',
        args: [],
        query: { enabled: !!richToken && richToken !== viem_1.zeroAddress },
    });
    const { data: wethDecimals } = (0, wagmi_1.useReadContract)({
        chainId: dataChainId,
      address: (wethToken && wethToken !== viem_1.zeroAddress ? wethToken : undefined)
        ?? ((platform.weth9 ?? platform.weth) && (platform.weth9 ?? platform.weth) !== viem_1.zeroAddress
          ? (platform.weth9 ?? platform.weth)
          : undefined),
        abi: viem_1.erc20Abi,
        functionName: 'decimals',
        args: [],
      query: {
        enabled: !!((wethToken && wethToken !== viem_1.zeroAddress ? wethToken : undefined) ?? (platform.weth9 ?? platform.weth))
          && ((wethToken && wethToken !== viem_1.zeroAddress ? wethToken : (platform.weth9 ?? platform.weth)) !== viem_1.zeroAddress),
      },
    });
    const effectiveRichToken = (richToken && richToken !== viem_1.zeroAddress ? richToken : platform.richToken);
    const effectiveRichirToken = (richirToken && richirToken !== viem_1.zeroAddress ? richirToken : platform.richirToken);
    const platformWethToken = platform.weth9 ?? platform.weth;
    const effectiveWethToken = (wethToken && wethToken !== viem_1.zeroAddress ? wethToken : platformWethToken);
    const richDec = Number(richDecimals ?? 18);
    const wethDec = Number(wethDecimals ?? 18);
    const syntheticPriceDisplay = syntheticPrice !== undefined ? (0, viem_1.formatUnits)(syntheticPrice, 18) : null;
    const mintThresholdDisplay = mintThreshold !== undefined ? (0, viem_1.formatUnits)(mintThreshold, 18) : null;
    const burnThresholdDisplay = burnThreshold !== undefined ? (0, viem_1.formatUnits)(burnThreshold, 18) : null;
    const syntheticPriceStatus = !hasDetfAddress
      ? '—'
      : syntheticPriceError
      ? 'Unavailable: read reverted on current pool state.'
      : syntheticPriceDisplay ?? '—';
    const mintThresholdStatus = !hasDetfAddress
      ? '—'
      : mintThresholdError
      ? 'Unavailable'
      : mintThresholdDisplay ?? '—';
    const burnThresholdStatus = !hasDetfAddress
      ? '—'
      : burnThresholdError
      ? 'Unavailable'
      : burnThresholdDisplay ?? '—';
    const richTokenAddress = hasDetfAddress ? (effectiveRichToken ?? '—') : (platform.richToken ?? '—');
    const richirTokenAddress = hasDetfAddress ? (effectiveRichirToken ?? '—') : (platform.richirToken ?? '—');
    const nftVaultAddress = hasDetfAddress ? (nftVault ?? platform.protocolNftVault ?? '—') : (platform.protocolNftVault ?? '—');
    const reservePoolAddress = hasDetfAddress ? (reservePool ?? platform.reservePool ?? '—') : (platform.reservePool ?? '—');
    const [mintWethAmount, setMintWethAmount] = (0, react_1.useState)('');
    const [bondWethAmount, setBondWethAmount] = (0, react_1.useState)('');
    const [bondRichAmount, setBondRichAmount] = (0, react_1.useState)('');
    const [lockDays, setLockDays] = (0, react_1.useState)('30');
    const [sellTokenId, setSellTokenId] = (0, react_1.useState)('');
    const lockSeconds = (0, react_1.useMemo)(() => BigInt(clampInt(lockDays, 30) * 24 * 60 * 60), [lockDays]);
    const parsedMintWeth = (0, react_1.useMemo)(() => {
        if (!mintWethAmount)
            return undefined;
        try {
            return (0, viem_1.parseUnits)(mintWethAmount, wethDec);
        }
        catch {
            return undefined;
        }
    }, [mintWethAmount, wethDec]);
    const parsedBondWeth = (0, react_1.useMemo)(() => {
        if (!bondWethAmount)
            return undefined;
        try {
            return (0, viem_1.parseUnits)(bondWethAmount, wethDec);
        }
        catch {
            return undefined;
        }
    }, [bondWethAmount, wethDec]);
    const parsedBondRich = (0, react_1.useMemo)(() => {
        if (!bondRichAmount)
            return undefined;
        try {
            return (0, viem_1.parseUnits)(bondRichAmount, richDec);
        }
        catch {
            return undefined;
        }
    }, [bondRichAmount, richDec]);
    async function approveToken(token, spender, amount) {
        setStatus('Submitting approval…');
        const hash = await writeContractAsync({
            chain: targetChain,
            account: address,
            address: token,
            abi: viem_1.erc20Abi,
            functionName: 'approve',
            args: [spender, amount],
        });
        setStatus(`Approval submitted: ${hash}`);
    }
    async function mintWithWeth() {
        if (!detfAddress || !parsedMintWeth || !address || !effectiveWethToken)
            return;
        if (attachedWalletChainId !== dataChainId) {
            setStatus(`Switch wallet network to chainId ${dataChainId} to mint.`);
            return;
        }
        setStatus('Approving WETH…');
        await approveToken(effectiveWethToken, detfAddress, parsedMintWeth);
        setStatus('Minting CHIR via exchangeIn…');
        const deadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60); // 5 minutes
        const hash = await writeContractAsync({
            chain: targetChain,
            account: address,
            address: detfAddress,
            abi: protocolDetfAbi,
            functionName: 'exchangeIn',
            args: [
                effectiveWethToken, // tokenIn: WETH
                parsedMintWeth, // amountIn
                detfAddress, // tokenOut: CHIR (the DETF itself)
                BigInt(0), // minAmountOut (0 for now, could add slippage)
                address, // recipient
                false, // pretransferred
                deadline, // deadline
            ],
        });
        setStatus(`exchangeIn (WETH→CHIR) submitted: ${hash}`);
    }
    async function bondWithWeth() {
        if (!detfAddress || !parsedBondWeth || !address || !effectiveWethToken)
            return;
        if (attachedWalletChainId !== dataChainId) {
            setStatus(`Switch wallet network to chainId ${dataChainId} to bond.`);
            return;
        }
        setStatus('Approving WETH…');
        await approveToken(effectiveWethToken, detfAddress, parsedBondWeth);
        setStatus('Bonding with WETH…');
        const deadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60); // 5 minutes
        const hash = await writeContractAsync({
            chain: targetChain,
            account: address,
            address: detfAddress,
            abi: protocolDetfAbi,
            functionName: 'bondWithWeth',
            args: [parsedBondWeth, lockSeconds, address, deadline],
        });
        setStatus(`bondWithWeth submitted: ${hash}`);
    }
    async function bondWithRich() {
        if (!detfAddress || !parsedBondRich || !address || !effectiveRichToken)
            return;
        if (attachedWalletChainId !== dataChainId) {
            setStatus(`Switch wallet network to chainId ${dataChainId} to bond.`);
            return;
        }
        setStatus('Approving RICH…');
        await approveToken(effectiveRichToken, detfAddress, parsedBondRich);
        setStatus('Bonding with RICH…');
        const deadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60); // 5 minutes
        const hash = await writeContractAsync({
            chain: targetChain,
            account: address,
            address: detfAddress,
            abi: protocolDetfAbi,
            functionName: 'bondWithRich',
            args: [parsedBondRich, lockSeconds, address, deadline],
        });
        setStatus(`bondWithRich submitted: ${hash}`);
    }
    async function sellNft() {
        if (!detfAddress || !address)
            return;
        if (attachedWalletChainId !== dataChainId) {
            setStatus(`Switch wallet network to chainId ${dataChainId} to sell.`);
            return;
        }
        const tokenId = BigInt(clampInt(sellTokenId, 0));
        setStatus('Selling NFT…');
        const hash = await writeContractAsync({
            chain: targetChain,
            account: address,
            address: detfAddress,
            abi: protocolDetfAbi,
            functionName: 'sellNFT',
            args: [tokenId, address],
        });
        setStatus(`sellNFT submitted: ${hash}`);
    }
    return (<div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 text-gray-100">
      <h1 className="text-2xl font-semibold">Staking</h1>
      <p className="mt-2 text-sm text-gray-300">
        Protocol DETF (CHIR): bond with WETH/RICH to mint NFT positions, or mint CHIR directly.
      </p>

      {isUnsupportedChain ? (<div className="mt-4 rounded-lg border border-yellow-700 bg-yellow-950/40 p-4">
          <p className="text-sm text-yellow-100">
            Wallet chainId {String(attachedWalletChainId ?? '(unknown)')} is not mapped for {environment}. Showing staking
            addresses from chainId {dataChainId} instead.
          </p>
        </div>) : null}

      {isConnected && attachedWalletChainId !== undefined && !isUnsupportedChain && attachedWalletChainId !== dataChainId ? (<div className="mt-4 rounded-lg border border-yellow-700 bg-yellow-950/40 p-4">
          <p className="text-sm text-yellow-100">
            Wallet is connected to chainId {attachedWalletChainId}, but this page is showing Protocol DETF deployments for
            chainId {dataChainId}. Switch your wallet network to chainId {dataChainId} to interact.
          </p>
        </div>) : null}

      {detfOptions.length === 0 ? (<div className="mt-6 rounded-lg border border-gray-700 bg-gray-800 p-4">
          <p className="text-sm text-gray-200">
            No Protocol DETF found for this chain. Run Stage 16 and then re-export tokenlists.
          </p>
        </div>) : (<div className="mt-6 rounded-lg border border-gray-700 bg-gray-800 p-4">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <label className="block text-xs text-gray-400">Protocol DETF</label>
              <select value={selectedDetf} onChange={(e) => setSelectedDetf(e.target.value)} className="mt-1 w-full rounded-md bg-gray-900 border border-gray-700 px-3 py-2 text-sm">
                {detfOptions.map((o) => (<option key={o.value} value={o.value}>
                    {o.label}
                  </option>))}
              </select>
            </div>

            <div className="text-xs text-gray-400">
              Wallet: {isConnected && address ? `${address.slice(0, 6)}…${address.slice(-4)}` : 'not connected'}
            </div>
            <div className="text-xs text-gray-400">
              Wallet chain: {attachedWalletChainId ?? '—'} | Display chain: {dataChainId}
            </div>
            <div className="text-xs text-gray-500">
              account {accountChainId ?? '—'} | connection {connection.chainId ?? '—'} | walletClient {walletClient?.chain?.id ?? '—'} | connectorClient {connectorClient?.chain?.id ?? '—'} | connectorHook {connectedWalletChainId ?? '—'} | browser {browserChainId ?? '—'} | config {configChainId ?? '—'}
            </div>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <div className="text-xs text-gray-400">CHIR (Proxy)</div>
              <div className="text-sm break-all">{detfAddress ?? '—'}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400">RICH</div>
              <div className="text-sm break-all">{richTokenAddress}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400">RICHIR</div>
              <div className="text-sm break-all">{richirTokenAddress}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400">NFT Vault</div>
              <div className="text-sm break-all">{nftVaultAddress}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400">Reserve Pool</div>
              <div className="text-sm break-all">{reservePoolAddress}</div>
            </div>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="rounded-md bg-gray-900 border border-gray-700 p-3">
              <div className="text-xs text-gray-400">Synthetic Price (RICH per WETH)</div>
              <div className="text-sm">{syntheticPriceStatus}</div>
              <div className="mt-2 text-xs text-gray-400">Mint threshold</div>
              <div className="text-sm">{mintThresholdStatus}</div>
              <div className="mt-2 text-xs text-gray-400">Burn threshold</div>
              <div className="text-sm">{burnThresholdStatus}</div>
              {syntheticPriceError ? (
                <div className="mt-2 text-xs text-amber-300">
                  The Protocol DETF contract on this chain reverted when calculating the synthetic price.
                </div>
              ) : null}
              <div className="mt-2 text-xs text-gray-400">
                Minting allowed: <span className="text-gray-200">{String(isMintingAllowed ?? '—')}</span>
              </div>
              <div className="text-xs text-gray-400">
                Burning allowed: <span className="text-gray-200">{String(isBurningAllowed ?? '—')}</span>
              </div>
            </div>

            <div className="rounded-md bg-gray-900 border border-gray-700 p-3">
              <div className="text-sm font-medium">Mint CHIR with WETH</div>
              <label className="mt-2 block text-xs text-gray-400">WETH amount</label>
              <input value={mintWethAmount} onChange={(e) => setMintWethAmount(e.target.value)} className="mt-1 w-full rounded-md bg-gray-950 border border-gray-700 px-3 py-2 text-sm" placeholder="1.0"/>
              <button onClick={mintWithWeth} disabled={!isConnected || attachedWalletChainId !== dataChainId || isWritePending || !parsedMintWeth || !effectiveWethToken} className="mt-3 w-full rounded-md bg-green-600 px-3 py-2 text-sm font-medium hover:bg-green-500 disabled:opacity-50">
                Mint
              </button>
            </div>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="rounded-md bg-gray-900 border border-gray-700 p-3">
              <div className="text-sm font-medium">Bond with WETH</div>
              <label className="mt-2 block text-xs text-gray-400">WETH amount</label>
              <input value={bondWethAmount} onChange={(e) => setBondWethAmount(e.target.value)} className="mt-1 w-full rounded-md bg-gray-950 border border-gray-700 px-3 py-2 text-sm" placeholder="0.5"/>
              <label className="mt-2 block text-xs text-gray-400">Lock (days)</label>
              <input value={lockDays} onChange={(e) => setLockDays(e.target.value)} className="mt-1 w-full rounded-md bg-gray-950 border border-gray-700 px-3 py-2 text-sm" placeholder="30"/>
              <button onClick={bondWithWeth} disabled={!isConnected || attachedWalletChainId !== dataChainId || isWritePending || !parsedBondWeth || !effectiveWethToken} className="mt-3 w-full rounded-md bg-blue-600 px-3 py-2 text-sm font-medium hover:bg-blue-500 disabled:opacity-50">
                Bond WETH
              </button>
            </div>

            <div className="rounded-md bg-gray-900 border border-gray-700 p-3">
              <div className="text-sm font-medium">Bond with RICH</div>
              <label className="mt-2 block text-xs text-gray-400">RICH amount</label>
              <input value={bondRichAmount} onChange={(e) => setBondRichAmount(e.target.value)} className="mt-1 w-full rounded-md bg-gray-950 border border-gray-700 px-3 py-2 text-sm" placeholder="100"/>
              <label className="mt-2 block text-xs text-gray-400">Lock (days)</label>
              <input value={lockDays} onChange={(e) => setLockDays(e.target.value)} className="mt-1 w-full rounded-md bg-gray-950 border border-gray-700 px-3 py-2 text-sm" placeholder="30"/>
              <button onClick={bondWithRich} disabled={!isConnected || attachedWalletChainId !== dataChainId || isWritePending || !parsedBondRich || !effectiveRichToken} className="mt-3 w-full rounded-md bg-purple-600 px-3 py-2 text-sm font-medium hover:bg-purple-500 disabled:opacity-50">
                Bond RICH
              </button>
            </div>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="rounded-md bg-gray-900 border border-gray-700 p-3">
              <div className="text-sm font-medium">Sell NFT for RICHIR</div>
              <label className="mt-2 block text-xs text-gray-400">Token ID</label>
              <input value={sellTokenId} onChange={(e) => setSellTokenId(e.target.value)} className="mt-1 w-full rounded-md bg-gray-950 border border-gray-700 px-3 py-2 text-sm" placeholder="1"/>
              <button onClick={sellNft} disabled={!isConnected || attachedWalletChainId !== dataChainId || isWritePending} className="mt-3 w-full rounded-md bg-orange-600 px-3 py-2 text-sm font-medium hover:bg-orange-500 disabled:opacity-50">
                Sell NFT
              </button>
            </div>

            <div className="rounded-md bg-gray-900 border border-gray-700 p-3">
              <div className="text-sm font-medium">Status</div>
              <div className="mt-2 text-sm text-gray-200 break-all">{status || '—'}</div>
            </div>
          </div>
        </div>)}
    </div>);
}
exports.default = StakingPageClient;
