// 'use client'
// // @ts-nocheck
// /* eslint-disable */

// import { useMemo, useState, useEffect } from 'react'
// import { useAccount, useChainId, usePublicClient } from 'wagmi'
// import { parseUnits, formatUnits } from 'viem'
// import {
//   useSimulateBalancerV3StandardExchangeExactInQueryFacetQuerySwapSingleTokenExactIn,
//   useWriteBalancerV3StandardExchangeExactInSwapFacetSwapSingleTokenExactIn,
//   // Permit2 + Router addresses and hooks
//   betterPermit2Address,
//   balancerV3StandardExchangeExactInSwapFacetAddress,
//   useReadBetterPermit2Allowance,
//   useWriteBetterPermit2Approve,
//   // ERC20 allowance hooks for common tokens
//   useReadWeth9Allowance,
//   useWriteWeth9Approve,
//   useReadTestTokenAerc20PermitAllowance,
//   useWriteTestTokenAerc20PermitApprove,
//   useWriteTestTokenAerc20PermitIncreaseAllowance,
//   useReadTestTokenBerc20PermitAllowance,
//   useWriteTestTokenBerc20PermitApprove,
//   useWriteTestTokenBerc20PermitIncreaseAllowance,
//   useReadTestTokenCErc20PermitAllowance,
//   useWriteTestTokenCErc20PermitApprove,
//   useWriteTestTokenCErc20PermitIncreaseAllowance,
//   // ERC4626 wrappers (A/B/C/WETH) with ERC20Permit
//   testTokenAerc4626Erc20PermitAddress,
//   testTokenBerc4626Erc20PermitAddress,
//   testTokenCErc4626Erc20PermitAddress,
//   weth9Erc4626Erc20PermitAddress,
//   useReadTestTokenAerc4626Erc20PermitAllowance,
//   useWriteTestTokenAerc4626Erc20PermitApprove,
//   useWriteTestTokenAerc4626Erc20PermitIncreaseAllowance,
//   useReadTestTokenBerc4626Erc20PermitAllowance,
//   useWriteTestTokenBerc4626Erc20PermitApprove,
//   useWriteTestTokenBerc4626Erc20PermitIncreaseAllowance,
//   useReadTestTokenCErc4626Erc20PermitAllowance,
//   useWriteTestTokenCErc4626Erc20PermitApprove,
//   useWriteTestTokenCErc4626Erc20PermitIncreaseAllowance,
//   useReadWeth9Erc4626Erc20PermitAllowance,
//   useWriteWeth9Erc4626Erc20PermitApprove,
//   useWriteWeth9Erc4626Erc20PermitIncreaseAllowance,
//   // UniV2 LP tokens (pools)
//   uniV2TtattbPoolAddress,
//   uniV2TtattcPoolAddress,
//   uniV2TtatwethPoolAddress,
//   uniV2TtbtcPoolAddress,
//   uniV2TtbtwethPoolAddress,
//   uniV2TtctwethPoolAddress,
//   useReadUniV2TtattbPoolAllowance,
//   useWriteUniV2TtattbPoolApprove,
//   useWriteUniV2TtattbPoolIncreaseAllowance,
//   useReadUniV2TtattcPoolAllowance,
//   useWriteUniV2TtattcPoolApprove,
//   useWriteUniV2TtattcPoolIncreaseAllowance,
//   useReadUniV2TtatwethPoolAllowance,
//   useWriteUniV2TtatwethPoolApprove,
//   useWriteUniV2TtatwethPoolIncreaseAllowance,
//   useReadUniV2TtbtcPoolAllowance,
//   useWriteUniV2TtbtcPoolApprove,
//   useWriteUniV2TtbtcPoolIncreaseAllowance,
//   useReadUniV2TtbtwethPoolAllowance,
//   useWriteUniV2TtbtwethPoolApprove,
//   useWriteUniV2TtbtwethPoolIncreaseAllowance,
//   useReadUniV2TtctwethPoolAllowance,
//   useWriteUniV2TtctwethPoolApprove,
//   useWriteUniV2TtctwethPoolIncreaseAllowance,
//   // Strategy Vault share tokens (ERC20Permit)
//   uniV2TtattbStrategyVaultErc20PermitAddress,
//   uniV2TtattcStrategyVaultErc20PermitAddress,
//   uniV2TtatwethStrategyVaultErc20PermitAddress,
//   uniV2TtbttcStrategyVaultErc20PermitAddress,
//   uniV2TtbtwethStrategyVaultErc20PermitAddress,
//   unIv2TtcwethStrategyVaultErc20PermitAddress,
//   useReadUniV2TtattbStrategyVaultErc20PermitAllowance,
//   useWriteUniV2TtattbStrategyVaultErc20PermitApprove,
//   useWriteUniV2TtattbStrategyVaultErc20PermitIncreaseAllowance,
//   useReadUniV2TtattcStrategyVaultErc20PermitAllowance,
//   useWriteUniV2TtattcStrategyVaultErc20PermitApprove,
//   useWriteUniV2TtattcStrategyVaultErc20PermitIncreaseAllowance,
//   useReadUniV2TtatwethStrategyVaultErc20PermitAllowance,
//   useWriteUniV2TtatwethStrategyVaultErc20PermitApprove,
//   useWriteUniV2TtatwethStrategyVaultErc20PermitIncreaseAllowance,
//   useReadUniV2TtbttcStrategyVaultErc20PermitAllowance,
//   useWriteUniV2TtbttcStrategyVaultErc20PermitApprove,
//   useWriteUniV2TtbttcStrategyVaultErc20PermitIncreaseAllowance,
//   useReadUniV2TtbtwethStrategyVaultErc20PermitAllowance,
//   useWriteUniV2TtbtwethStrategyVaultErc20PermitApprove,
//   useWriteUniV2TtbtwethStrategyVaultErc20PermitIncreaseAllowance,
//   useReadUnIv2TtcwethStrategyVaultErc20PermitAllowance,
//   useWriteUnIv2TtcwethStrategyVaultErc20PermitApprove,
//   useWriteUnIv2TtcwethStrategyVaultErc20PermitIncreaseAllowance,
//   testTokenAerc20PermitAddress,
//   testTokenBerc20PermitAddress,
//   testTokenCErc20PermitAddress,
//   weth9Address,
// } from '../generated'
// import sepoliaAddresses from '../addresses/sepolia/sepolia_base_tokens_pools.json'

// export default function SwapPage() {
//   const { address, isConnected } = useAccount()
//   const chainId = useChainId()
//   const publicClient = usePublicClient()

//   // Resolve common addresses by connected chain with Sepolia fallback
//   const weth9Addr = useMemo(() => {
//     const map = weth9Address as unknown as Record<number, `0x${string}`>
//     return map[chainId] ?? map[11155111]
//   }, [chainId])
//   const ttaAddr = useMemo(() => {
//     const map = testTokenAerc20PermitAddress as unknown as Record<number, `0x${string}`>
//     return map[chainId] ?? map[11155111]
//   }, [chainId])
//   const ttbAddr = useMemo(() => {
//     const map = testTokenBerc20PermitAddress as unknown as Record<number, `0x${string}`>
//     return map[chainId] ?? map[11155111]
//   }, [chainId])
//   const ttcAddr = useMemo(() => {
//     const map = testTokenCErc20PermitAddress as unknown as Record<number, `0x${string}`>
//     return map[chainId] ?? map[11155111]
//   }, [chainId])
//   const [knownPool, setKnownPool] = useState<string>('')
//   const [customPool, setCustomPool] = useState<string>('')
//   const [amountIn, setAmountIn] = useState<string>('0.0')
//   const [tokenIn, setTokenIn] = useState<string>('') // address string
//   const [tokenOut, setTokenOut] = useState<string>('') // address string
//   const [useEthIn, setUseEthIn] = useState<boolean>(false)
//   const [useEthOut, setUseEthOut] = useState<boolean>(false)
//   const [specifyVaultIn, setSpecifyVaultIn] = useState<boolean>(false)
//   const [specifyVaultOut, setSpecifyVaultOut] = useState<boolean>(false)
//   const [slippage, setSlippage] = useState<number>(0.5)
//   const [selectedVaultIn, setSelectedVaultIn] = useState<`0x${string}` | ''>('')
//   const [selectedVaultOut, setSelectedVaultOut] = useState<`0x${string}` | ''>('')



//   // Build options from JSON
//   const poolOptions = useMemo(() => {
//     // Get existing pool options from JSON
//     const jsonPoolOptions = Object.entries(sepoliaAddresses)
//       .filter(([key]) => /ConstProdPool$/.test(key))
//       .map(([key, value]) => ({ label: key, value: value as `0x${string}` }))
    
//     // Add Strategy Vault tokens as pool options
//     const strategyVaultOptions = [
//       { label: 'UniV2-ttA-ttB-StrategyVault', value: (uniV2TtattbStrategyVaultErc20PermitAddress as any)[chainId] },
//       { label: 'UniV2-ttA-ttC-StrategyVault', value: (uniV2TtattcStrategyVaultErc20PermitAddress as any)[chainId] },
//       { label: 'UniV2-ttA-WETH-StrategyVault', value: (uniV2TtatwethStrategyVaultErc20PermitAddress as any)[chainId] },
//       { label: 'UniV2-ttB-ttC-StrategyVault', value: (uniV2TtbttcStrategyVaultErc20PermitAddress as any)[chainId] },
//       { label: 'UniV2-ttB-WETH-StrategyVault', value: (uniV2TtbtwethStrategyVaultErc20PermitAddress as any)[chainId] },
//       { label: 'UniV2-ttC-WETH-StrategyVault', value: (unIv2TtcwethStrategyVaultErc20PermitAddress as any)[chainId] },
//     ].filter(opt => opt.value) // Filter out undefined addresses
    
//     return [...jsonPoolOptions, ...strategyVaultOptions]
//   }, [chainId])

//   const tokenOptions = useMemo(() =>
//     Object.entries(sepoliaAddresses)
//       .filter(([key]) => (
//         /^TestToken[A-Z]/.test(key) || /StrategyVault$/.test(key) || /4626$/.test(key) || /UniV2Pool$/.test(key)
//       ))
//       .filter(([key]) => !/RateProvider$/.test(key))
//       .map(([key, value]) => ({ label: key, value: value as `0x${string}` }))
//       .concat([{ label: 'WETH9', value: weth9Addr }]),
//   [weth9Addr])

//   const vaultOptions = useMemo(() =>
//     Object.entries(sepoliaAddresses)
//       .filter(([key]) => /StrategyVault$/.test(key))
//       .map(([key, value]) => ({ label: key, value: value as `0x${string}` })),
//   [])

//   // Prefer a custom pool address if provided; otherwise use selected known pool address
//   const poolAddress = (customPool?.trim() as `0x${string}`) || (knownPool as `0x${string}` | undefined)

//   // Resolve router and Permit2 addresses by chain with Sepolia fallback
//   const routerAddr = useMemo(() => {
//     const map = balancerV3StandardExchangeExactInSwapFacetAddress as unknown as Record<number, `0x${string}`>
//     return map[chainId] ?? map[11155111]
//   }, [chainId])
//   const permit2Addr = useMemo(() => {
//     const map = betterPermit2Address as unknown as Record<number, `0x${string}`>
//     return map[chainId] ?? map[11155111]
//   }, [chainId])

//   // Token address helpers
//   // Backwards compatibility: if user picks TestToken labels via JSON, addresses already provided;
//   // also allow selecting A/B/C programmatic addresses if needed.
//   const tokenAddressMap: Record<string, `0x${string}` | undefined> = useMemo(() => ({
//     [ttaAddr]: ttaAddr,
//     [ttbAddr]: ttbAddr,
//     [ttcAddr]: ttcAddr,
//     [weth9Addr]: weth9Addr,
//   }), [ttaAddr, ttbAddr, ttcAddr, weth9Addr])

//   const tokenInAddress = useMemo(() => {
//     if (useEthIn) return weth9Addr
//     return (tokenIn as `0x${string}`) || tokenAddressMap[tokenIn]
//   }, [useEthIn, tokenIn, weth9Addr, tokenAddressMap])
  
//   const tokenOutAddress = useMemo(() => {
//     if (useEthOut) return weth9Addr
//     return (tokenOut as `0x${string}`) || tokenAddressMap[tokenOut]
//   }, [useEthOut, tokenOut, weth9Addr, tokenAddressMap])
//   const tokensValid = true
  
//   // Route derivation: support direct pool swap, vault pass-through, and vault deposits
//   const isVaultPassThrough = useMemo(
//     () => Boolean(specifyVaultIn && specifyVaultOut && selectedVaultIn && selectedVaultOut && selectedVaultIn === selectedVaultOut),
//     [specifyVaultIn, specifyVaultOut, selectedVaultIn, selectedVaultOut]
//   )
  
//   // Add vault deposit pattern detection (now tokenOutAddress is defined)
//   const isVaultDeposit = useMemo(() => 
//     Boolean(specifyVaultIn && !specifyVaultOut && selectedVaultIn && 
//             tokenOutAddress === selectedVaultIn), 
//     [specifyVaultIn, specifyVaultOut, selectedVaultIn, tokenOutAddress]
//   )
  
//   // Add vault withdrawal pattern detection
//   const isVaultWithdrawal = useMemo(() => 
//     Boolean(!specifyVaultIn && specifyVaultOut && selectedVaultOut && 
//             tokenInAddress === selectedVaultOut), 
//     [specifyVaultIn, specifyVaultOut, selectedVaultOut, tokenInAddress]
//   )
  
//   const routeValid = useMemo(
//     () => (!specifyVaultIn && !specifyVaultOut) || isVaultPassThrough || isVaultDeposit || isVaultWithdrawal,
//     [specifyVaultIn, specifyVaultOut, isVaultPassThrough, isVaultDeposit, isVaultWithdrawal]
//   )
  
//   const finalPool = useMemo(() => {
//     if (isVaultPassThrough && selectedVaultIn) return selectedVaultIn
//     if (isVaultDeposit && selectedVaultIn) return selectedVaultIn        // Use vault as pool for deposits
//     if (isVaultWithdrawal && selectedVaultOut) return selectedVaultOut   // Use vault as pool for withdrawals
//     return poolAddress                                // Use external pool for other operations
//   }, [isVaultPassThrough, isVaultDeposit, isVaultWithdrawal, selectedVaultIn, selectedVaultOut, poolAddress])
  
//   // Vault addresses are optional; using zero address placeholder until wired
//   const zeroAddr = '0x0000000000000000000000000000000000000000' as `0x${string}`
  
//   // Enhanced vault address logic for different route patterns
//   const tokenInVaultAddress = useMemo(() => {
//     if (isVaultPassThrough && selectedVaultIn) return selectedVaultIn
//     if (isVaultDeposit && selectedVaultIn) return selectedVaultIn        // Use vault for input in deposits
//     if (isVaultWithdrawal) return zeroAddr                              // No vault for input in withdrawals (burn shares)
//     return zeroAddr
//   }, [isVaultPassThrough, isVaultDeposit, isVaultWithdrawal, selectedVaultIn])
  
//   const tokenOutVaultAddress = useMemo(() => {
//     if (isVaultPassThrough && selectedVaultOut) return selectedVaultOut
//     if (isVaultDeposit) return zeroAddr                // No vault for output in deposits (direct shares)
//     if (isVaultWithdrawal && selectedVaultOut) return selectedVaultOut  // Use vault for output in withdrawals
//     return zeroAddr
//   }, [isVaultPassThrough, isVaultDeposit, isVaultWithdrawal, selectedVaultOut])

//   const exactAmountIn = (() => {
//     const n = Number(amountIn)
//     if (!isFinite(n) || n <= 0) return undefined
//     try {
//       return parseUnits(amountIn, 18)
//     } catch {
//       return undefined
//     }
//   })()

//   const ready = Boolean(
//     isConnected &&
//       finalPool &&
//       tokenInAddress &&
//       tokenOutAddress &&
//       tokensValid &&
//       exactAmountIn !== undefined &&
//       address &&
//       routeValid
//   )

//   // Use swap-ready gating for preview as before

//   // Debug readiness gates (kept minimal)
//   useEffect(() => {
//     // eslint-disable-next-line no-console
//     console.log('[Ready]', { ready })
//   }, [ready])

//   // Always-on state logging to aid debugging
//   useEffect(() => {
//     // eslint-disable-next-line no-console
//     console.log('[State] form', {
//       poolSelected: knownPool,
//       customPool,
//       tokenIn,
//       tokenOut,
//       amountIn,
//       specifyVaultIn,
//       specifyVaultOut,
//       selectedVaultIn,
//       selectedVaultOut,
//       useEthIn,
//       useEthOut,
//       chainId,
//       address,
//       // Add resolved addresses for debugging
//       resolvedTokenInAddress: tokenInAddress,
//       resolvedTokenOutAddress: tokenOutAddress,
//       finalPool,
//       ready,
//     })
//   }, [knownPool, customPool, tokenIn, tokenOut, amountIn, specifyVaultIn, specifyVaultOut, selectedVaultIn, selectedVaultOut, useEthIn, useEthOut, chainId, address, tokenInAddress, tokenOutAddress, finalPool, ready])

//   // Helper function to get current operation mode for UI display
//   const getOperationMode = () => {
//     if (isVaultPassThrough) return "Vault Pass-Through Swap"
//     if (isVaultDeposit) return "Vault Deposit"
//     if (isVaultWithdrawal) return "Vault Withdrawal"
//     return "Direct Pool Swap"
//   }

//   // Helper function to get operation description for user guidance
//   const getOperationDescription = () => {
//     if (isVaultDeposit) {
//       return `You are depositing tokens into the ${vaultOptions.find(v => v.value === selectedVaultIn)?.label || 'selected vault'}. You will receive vault shares representing your LP position.`
//     }
//     if (isVaultWithdrawal) {
//       return `You are withdrawing tokens from the ${vaultOptions.find(v => v.value === selectedVaultOut)?.label || 'selected vault'}. You will burn vault shares to receive underlying tokens.`
//     }
//     if (isVaultPassThrough) {
//       return "You are swapping tokens through the vault's underlying protocol (e.g., Uniswap V2, Camelot V2) with vault fee collection."
//     }
//     return "You are performing a direct swap through a Balancer V3 pool."
//   }

//   // ------------------------------
//   // Approval hooks (token -> Permit2 and Permit2 -> Router)
//   // ------------------------------
//   const needTokenApprovalEnabled = Boolean(
//     ready && !useEthIn && tokenInAddress && address
//   )

//   // Token allowances to Permit2 by token type
//   const { data: wethAllowance } = useReadWeth9Allowance({
//     args: address && permit2Addr && tokenInAddress === weth9Addr ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled && tokenInAddress === weth9Addr },
//   })
//   const { data: weth4626Allowance } = useReadWeth9Erc4626Erc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === (weth9Erc4626Erc20PermitAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttaAllowance } = useReadTestTokenAerc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === ttaAddr ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled && tokenInAddress === ttaAddr },
//   })
//   const { data: tta4626Allowance } = useReadTestTokenAerc4626Erc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === (testTokenAerc4626Erc20PermitAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttbAllowance } = useReadTestTokenBerc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === ttbAddr ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled && tokenInAddress === ttbAddr },
//   })
//   const { data: ttb4626Allowance } = useReadTestTokenBerc4626Erc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === (testTokenBerc4626Erc20PermitAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttcAllowance } = useReadTestTokenCErc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === ttcAddr ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled && tokenInAddress === ttcAddr },
//   })
//   const { data: ttc4626Allowance } = useReadTestTokenCErc4626Erc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === (testTokenCErc4626Erc20PermitAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   // LP tokens
//   const { data: ttaTtbLpAllowance } = useReadUniV2TtattbPoolAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtattbPoolAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttaTtcLpAllowance } = useReadUniV2TtattcPoolAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtattcPoolAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttaWethLpAllowance } = useReadUniV2TtatwethPoolAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtatwethPoolAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttbTtcLpAllowance } = useReadUniV2TtbtcPoolAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtbtcPoolAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttbWethLpAllowance } = useReadUniV2TtbtwethPoolAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtbtwethPoolAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttcWethLpAllowance } = useReadUniV2TtctwethPoolAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtctwethPoolAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })

//   // Strategy vault allowances
//   const { data: ttaTtbVaultAllowance } = useReadUniV2TtattbStrategyVaultErc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtattbStrategyVaultErc20PermitAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttaTtcVaultAllowance } = useReadUniV2TtattcStrategyVaultErc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtattcStrategyVaultErc20PermitAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttaWethVaultAllowance } = useReadUniV2TtatwethStrategyVaultErc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtatwethStrategyVaultErc20PermitAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttbTtcVaultAllowance } = useReadUniV2TtbttcStrategyVaultErc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtbttcStrategyVaultErc20PermitAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttbWethVaultAllowance } = useReadUniV2TtbtwethStrategyVaultErc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === (uniV2TtbtwethStrategyVaultErc20PermitAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })
//   const { data: ttcWethVaultAllowance } = useReadUnIv2TtcwethStrategyVaultErc20PermitAllowance({
//     args: address && permit2Addr && tokenInAddress === (unIv2TtcwethStrategyVaultErc20PermitAddress as any)[chainId] ? [address, permit2Addr] : undefined,
//     query: { enabled: needTokenApprovalEnabled },
//   })

//   // Permit2 allowance (user, token, router)
//   const { data: p2AllowanceRaw } = useReadBetterPermit2Allowance({
//     args: address && tokenInAddress && routerAddr && !useEthIn ? [address, tokenInAddress, routerAddr] : undefined,
//     query: { enabled: Boolean(needTokenApprovalEnabled && routerAddr) },
//   })

//   // Writers
//   const { writeContract: writeP2Approve, data: p2ApproveHash } = useWriteBetterPermit2Approve()
//   const { writeContract: writeWethApprove, data: wethApproveHash } = useWriteWeth9Approve()
//   const { writeContract: writeTtaApprove, data: ttaApproveHash } = useWriteTestTokenAerc20PermitApprove()
//   const { writeContract: writeTtaIncrease, data: ttaIncreaseHash } = useWriteTestTokenAerc20PermitIncreaseAllowance()
//   const { writeContract: writeTtbApprove, data: ttbApproveHash } = useWriteTestTokenBerc20PermitApprove()
//   const { writeContract: writeTtbIncrease, data: ttbIncreaseHash } = useWriteTestTokenBerc20PermitIncreaseAllowance()
//   const { writeContract: writeTtcApprove, data: ttcApproveHash } = useWriteTestTokenCErc20PermitApprove()
//   const { writeContract: writeTtcIncrease, data: ttcIncreaseHash } = useWriteTestTokenCErc20PermitIncreaseAllowance()
//   // ERC4626 wrappers
//   const { writeContract: writeWeth4626Approve, data: weth4626ApproveHash } = useWriteWeth9Erc4626Erc20PermitApprove()
//   const { writeContract: writeWeth4626Increase, data: weth4626IncreaseHash } = useWriteWeth9Erc4626Erc20PermitIncreaseAllowance()
//   const { writeContract: writeTta4626Approve, data: tta4626ApproveHash } = useWriteTestTokenAerc4626Erc20PermitApprove()
//   const { writeContract: writeTta4626Increase, data: tta4626IncreaseHash } = useWriteTestTokenAerc4626Erc20PermitIncreaseAllowance()
//   const { writeContract: writeTtb4626Approve, data: ttb4626ApproveHash } = useWriteTestTokenBerc4626Erc20PermitApprove()
//   const { writeContract: writeTtb4626Increase, data: ttb4626IncreaseHash } = useWriteTestTokenBerc4626Erc20PermitIncreaseAllowance()
//   const { writeContract: writeTtc4626Approve, data: ttc4626ApproveHash } = useWriteTestTokenCErc4626Erc20PermitApprove()
//   const { writeContract: writeTtc4626Increase, data: ttc4626IncreaseHash } = useWriteTestTokenCErc4626Erc20PermitIncreaseAllowance()
//   // LP tokens
//   const { writeContract: writeTtaTtbPoolApprove, data: ttaTtbPoolApproveHash } = useWriteUniV2TtattbPoolApprove()
//   const { writeContract: writeTtaTtbPoolIncrease, data: ttaTtbPoolIncreaseHash } = useWriteUniV2TtattbPoolIncreaseAllowance()
//   const { writeContract: writeTtaTtcPoolApprove, data: ttaTtcPoolApproveHash } = useWriteUniV2TtattcPoolApprove()
//   const { writeContract: writeTtaTtcPoolIncrease, data: ttaTtcPoolIncreaseHash } = useWriteUniV2TtattcPoolIncreaseAllowance()
//   const { writeContract: writeTtaWethPoolApprove, data: ttaWethPoolApproveHash } = useWriteUniV2TtatwethPoolApprove()
//   const { writeContract: writeTtaWethPoolIncrease, data: ttaWethPoolIncreaseHash } = useWriteUniV2TtatwethPoolIncreaseAllowance()
//   const { writeContract: writeTtbTtcPoolApprove, data: ttbTtcPoolApproveHash } = useWriteUniV2TtbtcPoolApprove()
//   const { writeContract: writeTtbTtcPoolIncrease, data: ttbTtcPoolIncreaseHash } = useWriteUniV2TtbtcPoolIncreaseAllowance()
//   const { writeContract: writeTtbWethPoolApprove, data: ttbWethPoolApproveHash } = useWriteUniV2TtbtwethPoolApprove()
//   const { writeContract: writeTtbWethPoolIncrease, data: ttbWethPoolIncreaseHash } = useWriteUniV2TtbtwethPoolIncreaseAllowance()
//   const { writeContract: writeTtcWethPoolApprove, data: ttcWethPoolApproveHash } = useWriteUniV2TtctwethPoolApprove()
//   const { writeContract: writeTtcWethPoolIncrease, data: ttcWethPoolIncreaseHash } = useWriteUniV2TtctwethPoolIncreaseAllowance()
//   // Strategy vault shares
//   const { writeContract: writeTtaTtbVaultApprove, data: ttaTtbVaultApproveHash } = useWriteUniV2TtattbStrategyVaultErc20PermitApprove()
//   const { writeContract: writeTtaTtbVaultIncrease, data: ttaTtbVaultIncreaseHash } = useWriteUniV2TtattbStrategyVaultErc20PermitIncreaseAllowance()
//   const { writeContract: writeTtaTtcVaultApprove, data: ttaTtcVaultApproveHash } = useWriteUniV2TtattcStrategyVaultErc20PermitApprove()
//   const { writeContract: writeTtaTtcVaultIncrease, data: ttaTtcVaultIncreaseHash } = useWriteUniV2TtattcStrategyVaultErc20PermitIncreaseAllowance()
//   const { writeContract: writeTtaWethVaultApprove, data: ttaWethVaultApproveHash } = useWriteUniV2TtatwethStrategyVaultErc20PermitApprove()
//   const { writeContract: writeTtaWethVaultIncrease, data: ttaWethVaultIncreaseHash } = useWriteUniV2TtatwethStrategyVaultErc20PermitIncreaseAllowance()
//   const { writeContract: writeTtbTtcVaultApprove, data: ttbTtcVaultApproveHash } = useWriteUniV2TtbttcStrategyVaultErc20PermitApprove()
//   const { writeContract: writeTtbTtcVaultIncrease, data: ttbTtcVaultIncreaseHash } = useWriteUniV2TtbttcStrategyVaultErc20PermitIncreaseAllowance()
//   const { writeContract: writeTtbWethVaultApprove, data: ttbWethVaultApproveHash } = useWriteUniV2TtbtwethStrategyVaultErc20PermitApprove()
//   const { writeContract: writeTtbWethVaultIncrease, data: ttbWethVaultIncreaseHash } = useWriteUniV2TtbtwethStrategyVaultErc20PermitIncreaseAllowance()
//   const { writeContract: writeTtcWethVaultApprove, data: ttcWethVaultApproveHash } = useWriteUnIv2TtcwethStrategyVaultErc20PermitApprove()
//   const { writeContract: writeTtcWethVaultIncrease, data: ttcWethVaultIncreaseHash } = useWriteUnIv2TtcwethStrategyVaultErc20PermitIncreaseAllowance()

//   // Helpers to resolve token allowance and approve writer based on tokenIn
//   const currentTokenAllowance: bigint | undefined = useMemo(() => {
//     if (useEthIn || !needTokenApprovalEnabled) return undefined
//     if (tokenInAddress === weth9Addr) return (wethAllowance as bigint | undefined)
//     if (tokenInAddress === (weth9Erc4626Erc20PermitAddress as any)[chainId]) return (weth4626Allowance as bigint | undefined)
//     if (tokenInAddress === ttaAddr) return (ttaAllowance as bigint | undefined)
//     if (tokenInAddress === (testTokenAerc4626Erc20PermitAddress as any)[chainId]) return (tta4626Allowance as bigint | undefined)
//     if (tokenInAddress === ttbAddr) return (ttbAllowance as bigint | undefined)
//     if (tokenInAddress === (testTokenBerc4626Erc20PermitAddress as any)[chainId]) return (ttb4626Allowance as bigint | undefined)
//     if (tokenInAddress === ttcAddr) return (ttcAllowance as bigint | undefined)
//     if (tokenInAddress === (testTokenCErc4626Erc20PermitAddress as any)[chainId]) return (ttc4626Allowance as bigint | undefined)
//     if (tokenInAddress === (uniV2TtattbPoolAddress as any)[chainId]) return (ttaTtbLpAllowance as bigint | undefined)
//     if (tokenInAddress === (uniV2TtattcPoolAddress as any)[chainId]) return (ttaTtcLpAllowance as bigint | undefined)
//     if (tokenInAddress === (uniV2TtatwethPoolAddress as any)[chainId]) return (ttaWethLpAllowance as bigint | undefined)
//     if (tokenInAddress === (uniV2TtbtcPoolAddress as any)[chainId]) return (ttbTtcLpAllowance as bigint | undefined)
//     if (tokenInAddress === (uniV2TtbtwethPoolAddress as any)[chainId]) return (ttbWethLpAllowance as bigint | undefined)
//     if (tokenInAddress === (uniV2TtctwethPoolAddress as any)[chainId]) return (ttcWethLpAllowance as bigint | undefined)
//     // Strategy vault shares
//     if (tokenInAddress === (uniV2TtattbStrategyVaultErc20PermitAddress as any)[chainId]) return (ttaTtbVaultAllowance as bigint | undefined)
//     if (tokenInAddress === (uniV2TtattcStrategyVaultErc20PermitAddress as any)[chainId]) return (ttaTtcVaultAllowance as bigint | undefined)
//     if (tokenInAddress === (uniV2TtatwethStrategyVaultErc20PermitAddress as any)[chainId]) return (ttaWethVaultAllowance as bigint | undefined)
//     if (tokenInAddress === (uniV2TtbttcStrategyVaultErc20PermitAddress as any)[chainId]) return (ttbTtcVaultAllowance as bigint | undefined)
//     if (tokenInAddress === (uniV2TtbtwethStrategyVaultErc20PermitAddress as any)[chainId]) return (ttbWethVaultAllowance as bigint | undefined)
//     if (tokenInAddress === (unIv2TtcwethStrategyVaultErc20PermitAddress as any)[chainId]) return (ttcWethVaultAllowance as bigint | undefined)
//     return undefined
//   }, [useEthIn, needTokenApprovalEnabled, tokenInAddress, chainId, weth9Addr, weth4626Allowance, ttaAddr, ttaAllowance, tta4626Allowance, ttbAddr, ttbAllowance, ttb4626Allowance, ttcAddr, ttcAllowance, ttc4626Allowance, ttaTtbLpAllowance, ttaTtcLpAllowance, ttaWethLpAllowance, ttbTtcLpAllowance, ttbWethLpAllowance, ttcWethLpAllowance, ttaTtbVaultAllowance, ttaTtcVaultAllowance, ttaWethVaultAllowance, ttbTtcVaultAllowance, ttbWethVaultAllowance, ttcWethVaultAllowance])

//   const tokenApproveWriter = useMemo(() => {
//     // Base tokens
//     if (tokenInAddress === weth9Addr) return { approve: writeWethApprove, increase: undefined as any, hash: wethApproveHash }
//     if (tokenInAddress === ttaAddr) return { approve: writeTtaApprove, increase: writeTtaIncrease, hash: ttaApproveHash, incHash: ttaIncreaseHash }
//     if (tokenInAddress === ttbAddr) return { approve: writeTtbApprove, increase: writeTtbIncrease, hash: ttbApproveHash, incHash: ttbIncreaseHash }
//     if (tokenInAddress === ttcAddr) return { approve: writeTtcApprove, increase: writeTtcIncrease, hash: ttcApproveHash, incHash: ttcIncreaseHash }
//     // ERC4626 wrappers
//     if (tokenInAddress === (weth9Erc4626Erc20PermitAddress as any)[chainId]) return { approve: writeWeth4626Approve, increase: writeWeth4626Increase, hash: weth4626ApproveHash, incHash: weth4626IncreaseHash }
//     if (tokenInAddress === (testTokenAerc4626Erc20PermitAddress as any)[chainId]) return { approve: writeTta4626Approve, increase: writeTta4626Increase, hash: tta4626ApproveHash, incHash: tta4626IncreaseHash }
//     if (tokenInAddress === (testTokenBerc4626Erc20PermitAddress as any)[chainId]) return { approve: writeTtb4626Approve, increase: writeTtb4626Increase, hash: ttb4626ApproveHash, incHash: ttb4626IncreaseHash }
//     if (tokenInAddress === (testTokenCErc4626Erc20PermitAddress as any)[chainId]) return { approve: writeTtc4626Approve, increase: writeTtc4626Increase, hash: ttc4626ApproveHash, incHash: ttc4626IncreaseHash }
//     // LP tokens
//     if (tokenInAddress === (uniV2TtattbPoolAddress as any)[chainId]) return { approve: writeTtaTtbPoolApprove, increase: writeTtaTtbPoolIncrease, hash: ttaTtbPoolApproveHash, incHash: ttaTtbPoolIncreaseHash }
//     if (tokenInAddress === (uniV2TtattcPoolAddress as any)[chainId]) return { approve: writeTtaTtcPoolApprove, increase: writeTtaTtcPoolIncrease, hash: ttaTtcPoolApproveHash, incHash: ttaTtcPoolIncreaseHash }
//     if (tokenInAddress === (uniV2TtatwethPoolAddress as any)[chainId]) return { approve: writeTtaWethPoolApprove, increase: writeTtaWethPoolIncrease, hash: ttaWethPoolApproveHash, incHash: ttaWethPoolIncreaseHash }
//     if (tokenInAddress === (uniV2TtbtcPoolAddress as any)[chainId]) return { approve: writeTtbTtcPoolApprove, increase: writeTtbTtcPoolIncrease, hash: ttbTtcPoolApproveHash, incHash: ttbTtcPoolIncreaseHash }
//     if (tokenInAddress === (uniV2TtbtwethPoolAddress as any)[chainId]) return { approve: writeTtbWethPoolApprove, increase: writeTtbWethPoolIncrease, hash: ttbWethPoolApproveHash, incHash: ttbWethPoolIncreaseHash }
//     if (tokenInAddress === (uniV2TtctwethPoolAddress as any)[chainId]) return { approve: writeTtcWethPoolApprove, increase: writeTtcWethPoolIncrease, hash: ttcWethPoolApproveHash, incHash: ttcWethPoolIncreaseHash }
//     // Strategy vault shares
//     if (tokenInAddress === (uniV2TtattbStrategyVaultErc20PermitAddress as any)[chainId]) return { approve: writeTtaTtbVaultApprove, increase: writeTtaTtbVaultIncrease, hash: ttaTtbVaultApproveHash, incHash: ttaTtbVaultIncreaseHash }
//     if (tokenInAddress === (uniV2TtattcStrategyVaultErc20PermitAddress as any)[chainId]) return { approve: writeTtaTtcVaultApprove, increase: writeTtaTtcVaultIncrease, hash: ttaTtcVaultApproveHash, incHash: ttaTtcVaultIncreaseHash }
//     if (tokenInAddress === (uniV2TtatwethStrategyVaultErc20PermitAddress as any)[chainId]) return { approve: writeTtaWethVaultApprove, increase: writeTtaWethVaultIncrease, hash: ttaWethVaultApproveHash, incHash: ttaWethVaultIncreaseHash }
//     if (tokenInAddress === (uniV2TtbttcStrategyVaultErc20PermitAddress as any)[chainId]) return { approve: writeTtbTtcVaultApprove, increase: writeTtbTtcVaultIncrease, hash: ttbTtcVaultApproveHash, incHash: ttbTtcVaultIncreaseHash }
//     if (tokenInAddress === (uniV2TtbtwethStrategyVaultErc20PermitAddress as any)[chainId]) return { approve: writeTtbWethVaultApprove, increase: writeTtbWethVaultIncrease, hash: ttbWethVaultApproveHash, incHash: ttbWethVaultIncreaseHash }
//     if (tokenInAddress === (unIv2TtcwethStrategyVaultErc20PermitAddress as any)[chainId]) return { approve: writeTtcWethVaultApprove, increase: writeTtcWethVaultIncrease, hash: ttcWethVaultApproveHash, incHash: ttcWethVaultIncreaseHash }
//     return { approve: undefined as any, increase: undefined as any, hash: undefined as any, incHash: undefined as any }
//   }, [tokenInAddress, chainId, weth9Addr, writeWethApprove, wethApproveHash, writeTtaApprove, writeTtaIncrease, ttaApproveHash, ttaIncreaseHash, writeTtbApprove, writeTtbIncrease, ttbApproveHash, ttbIncreaseHash, writeTtcApprove, writeTtcIncrease, ttcApproveHash, ttcIncreaseHash, writeWeth4626Approve, writeWeth4626Increase, weth4626ApproveHash, weth4626IncreaseHash, writeTta4626Approve, writeTta4626Increase, tta4626ApproveHash, tta4626IncreaseHash, writeTtb4626Approve, writeTtb4626Increase, ttb4626ApproveHash, ttb4626IncreaseHash, writeTtc4626Approve, writeTtc4626Increase, ttc4626ApproveHash, ttc4626IncreaseHash, writeTtaTtbPoolApprove, writeTtaTtbPoolIncrease, ttaTtbPoolApproveHash, ttaTtbPoolIncreaseHash, writeTtaTtcPoolApprove, writeTtaTtcPoolIncrease, ttaTtcPoolApproveHash, ttaTtcPoolIncreaseHash, writeTtaWethPoolApprove, writeTtaWethPoolIncrease, ttaWethPoolApproveHash, ttaWethPoolIncreaseHash, writeTtbTtcPoolApprove, writeTtbTtcPoolIncrease, ttbTtcPoolApproveHash, ttbTtcPoolIncreaseHash, writeTtbWethPoolApprove, writeTtbWethPoolIncrease, ttbWethPoolApproveHash, ttbWethPoolIncreaseHash, writeTtcWethPoolApprove, writeTtcWethPoolIncrease, ttcWethPoolApproveHash, ttcWethPoolIncreaseHash, writeTtaTtbVaultApprove, writeTtaTtbVaultIncrease, ttaTtbVaultApproveHash, ttaTtbVaultIncreaseHash, writeTtaTtcVaultApprove, writeTtaTtcVaultIncrease, ttaTtcVaultApproveHash, ttaTtcVaultIncreaseHash, writeTtaWethVaultApprove, writeTtaWethVaultIncrease, ttaWethVaultApproveHash, ttaWethVaultIncreaseHash, writeTtbTtcVaultApprove, writeTtbTtcVaultIncrease, ttbTtcVaultApproveHash, ttbTtcVaultIncreaseHash, writeTtbWethVaultApprove, writeTtbWethVaultIncrease, ttbWethVaultApproveHash, ttbWethVaultIncreaseHash])

//   const p2AllowanceAmount: bigint | undefined = useMemo(() => {
//     const v: any = p2AllowanceRaw
//     if (!v) return undefined
//     if (typeof v === 'object' && 'amount' in v) return v.amount as bigint
//     if (Array.isArray(v)) return v[0] as bigint
//     return undefined
//   }, [p2AllowanceRaw])

//   // Helper: wait for mutation hash then for receipt
//   const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))
//   const waitForTx = async (getHash: () => `0x${string}` | undefined) => {
//     if (!publicClient) return
//     let hash = getHash()
//     for (let i = 0; i < 50 && !hash; i++) {
//       await sleep(200)
//       hash = getHash()
//     }
//     if (hash) {
//       await publicClient.waitForTransactionReceipt({ hash })
//     }
//   }

//   // Build preview args and log them for debugging
//   const previewArgs = useMemo(() => {
//     if (!ready) return undefined
//     const args: readonly [
//       `0x${string}`,
//       `0x${string}`,
//       `0x${string}`,
//       `0x${string}`,
//       `0x${string}`,
//       bigint,
//       `0x${string}`,
//       `0x${string}`
//     ] = [
//       finalPool!,
//       tokenInAddress!,
//       tokenInVaultAddress,
//       tokenOutAddress!,
//       tokenOutVaultAddress,
//       exactAmountIn!,
//       address!,
//       '0x',
//     ]
//     // eslint-disable-next-line no-console
//     console.log('[Preview] args', {
//       pool: args[0],
//       tokenIn: args[1],
//       tokenInVault: args[2],
//       tokenOut: args[3],
//       tokenOutVault: args[4],
//       amountInRaw: args[5].toString(),
//       slippagePercent: slippage,
//       valueIfEth: useEthIn ? args[5].toString() : '0',
//       sender: args[6],
//               // Add route pattern information for debugging
//         routePattern: {
//           isVaultPassThrough,
//           isVaultDeposit,
//           isVaultWithdrawal,
//           operationMode: getOperationMode(),
//         },
//     })
//     return args
//   }, [ready, finalPool, tokenInAddress, tokenInVaultAddress, tokenOutAddress, tokenOutVaultAddress, exactAmountIn, address, slippage, useEthIn, isVaultPassThrough, isVaultDeposit, isVaultWithdrawal])

//   const { data: preview, error: previewError, isPending: previewPending, refetch: refetchPreview } =
//     useSimulateBalancerV3StandardExchangeExactInQueryFacetQuerySwapSingleTokenExactIn({
//       args: previewArgs,
//       account: '0x0000000000000000000000000000000000000000',
//       query: { enabled: ready },
//     })

//   const formattedPreview = useMemo(() => {
//     const result = preview?.result as bigint | undefined
//     return result ? formatUnits(result, 18) : '0.0'
//   }, [preview])

//   // Execute swap write
//   const { writeContract: writeSwap, isPending: swapPending } =
//     useWriteBalancerV3StandardExchangeExactInSwapFacetSwapSingleTokenExactIn()

//   const handleSwap = async () => {
//     if (!ready || !preview?.result) return
//     const previewOut = preview.result as bigint
//     const bpsDenom = BigInt(10000)
//     const slippageBps = BigInt(Math.round(slippage * 100)) // 0.5% -> 50 bps
//     const minOut = (previewOut * (bpsDenom - slippageBps)) / bpsDenom
//     const deadline = BigInt(Math.floor(Date.now() / 1000) + 60 * 10)
//     try {
//       // Step 1: Perform approvals if needed (skip if ETH-in)
//       if (!useEthIn && exactAmountIn && tokenInAddress && address && publicClient) {
//         // 1a. Approve token -> Permit2
//         if (currentTokenAllowance !== undefined && currentTokenAllowance < exactAmountIn) {
//           if (!tokenApproveWriter.approve) throw new Error('Unsupported token approval writer for selected token')
//           if (currentTokenAllowance === BigInt(0) || !tokenApproveWriter.increase) {
//             tokenApproveWriter.approve({ args: [permit2Addr, exactAmountIn] })
//             await waitForTx(() => tokenApproveWriter.hash as `0x${string}` | undefined)
//           } else {
//             // Safe increase path: increase by delta
//             const delta = exactAmountIn - currentTokenAllowance
//             if (delta > BigInt(0)) {
//               tokenApproveWriter.increase({ args: [permit2Addr, delta] })
//               await waitForTx(() => tokenApproveWriter.incHash as `0x${string}` | undefined)
//             }
//           }
//         }

//         // 1b. Approve Permit2 -> Router
//         if ((p2AllowanceAmount ?? BigInt(0)) < exactAmountIn) {
//           const threeDaysSecs = 3 * 24 * 60 * 60
//           const expiration: number = Math.floor(Date.now() / 1000) + threeDaysSecs
//           writeP2Approve({ args: [tokenInAddress, routerAddr, exactAmountIn, expiration] })
//           await waitForTx(() => p2ApproveHash as `0x${string}` | undefined)
//         }
//       }

//       // Step 2: Execute swap
//       // eslint-disable-next-line no-console
//       console.log('[Swap] args', {
//         pool: finalPool,
//         tokenIn: tokenInAddress,
//         tokenInVault: tokenInVaultAddress,
//         tokenOut: tokenOutAddress,
//         tokenOutVault: tokenOutVaultAddress,
//         amountInRaw: exactAmountIn?.toString(),
//         previewOutRaw: previewOut.toString(),
//         slippagePercent: slippage,
//         minOutRaw: minOut.toString(),
//         deadline: deadline.toString(),
//         // ETH wrapping is always supported (router handles wrapping/unwrapping)
//         wethIsEth: (useEthIn || useEthOut),
//         // Send ETH value when useEthIn is true (router handles vault operations with ETH)
//         value: useEthIn ? exactAmountIn?.toString() : '0',
//         // Add route pattern information for debugging
//         routePattern: {
//           isVaultPassThrough,
//           isVaultDeposit,
//           isVaultWithdrawal,
//           operationMode: getOperationMode(),
//         },
//       })
//       writeSwap({
//         args: [
//           finalPool!,
//           tokenInAddress!,
//           tokenInVaultAddress,
//           tokenOutAddress!,
//           tokenOutVaultAddress,
//           exactAmountIn!,
//           minOut,
//           deadline,
//           // ETH wrapping is always supported (router handles wrapping/unwrapping)
//           (useEthIn || useEthOut),
//           '0x',
//         ],
//         // Send ETH value when useEthIn is true (router handles vault operations with ETH)
//         value: useEthIn ? exactAmountIn : undefined,
//       })
//     } catch (e) {
//       console.error('swap error', e)
//     }
//   }

//   return (
//     <div className="container mx-auto px-4">
//       <div className="text-center pt-10 pb-6">
//         <h1 className="text-3xl md:text-4xl font-bold text-white">Swap Tokens</h1>
//       </div>

//       <div className="mx-auto max-w-xl rounded-xl border border-slate-700 bg-slate-800/60 p-5 sm:p-6">
//         <h2 className="text-xl font-semibold text-white">Swap Tokens</h2>
        
//         {/* Operation Mode Display */}
//         {ready && (
//           <div className="mt-3 p-3 bg-slate-700/50 rounded-lg border border-slate-600">
//             <div className="text-sm font-medium text-blue-300 mb-1">
//               {getOperationMode()}
//             </div>
//             <div className="text-xs text-gray-300">
//               {getOperationDescription()}
//             </div>
//             {/* Debug Information */}
//             <div className="mt-2 pt-2 border-t border-slate-600">
//               <div className="text-xs text-gray-400">
//                 <div>Pool: {finalPool}</div>
//                 <div>TokenIn: {tokenInAddress}</div>
//                 <div>TokenInVault: {tokenInVaultAddress}</div>
//                 <div>TokenOut: {tokenOutAddress}</div>
//                 <div>TokenOutVault: {tokenOutVaultAddress}</div>
//                 <div>Route Pattern: {isVaultPassThrough ? 'Vault Pass-Through' : isVaultDeposit ? 'Vault Deposit' : isVaultWithdrawal ? 'Vault Withdrawal' : 'Direct Pool Swap'}</div>
//                 <div>ETH Wrapping: {useEthIn || useEthOut ? 'Enabled' : 'Disabled'}</div>
//                 <div>ETH Value: {useEthIn ? 'Input Amount' : 'None'}</div>
//                 <div>Ready: {ready ? 'Yes' : 'No'}</div>
//                 <div>Form TokenIn: {tokenIn}</div>
//                 <div>Form TokenOut: {tokenOut}</div>
//               </div>
//             </div>
//           </div>
//         )}

//         {/* Select Pool */}
//         <div className="mt-5">
//           <label className="block text-sm text-gray-300 mb-2">Select Pool</label>
//           <select
//             value={knownPool}
//             onChange={(e) => setKnownPool(e.target.value)}
//             className="w-full rounded-md border border-slate-600 bg-slate-700 text-gray-100 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-slate-500"
//           >
//             <option value="">Choose a Known Pool</option>
//             {poolOptions.map((opt) => (
//               <option key={opt.value} value={opt.value}>{opt.label}</option>
//             ))}
//           </select>
//         </div>

//         <div className="mt-3">
//           <label className="block text-xs text-gray-400 mb-1">Or Enter Custom Pool Address</label>
//           <div className="flex gap-2">
//             <input
//               value={customPool}
//               onChange={(e) => setCustomPool(e.target.value)}
//               placeholder="0x..."
//               className="flex-1 rounded-md border border-slate-600 bg-slate-700 text-gray-100 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-slate-500"
//             />
//             <button
//               className="rounded-md px-3 py-2 bg-slate-700 text-gray-100 border border-slate-600 hover:bg-slate-600"
//               type="button"
//             >
//               Query
//             </button>
//           </div>
//         </div>

//         {/* You Pay */}
//         <div className="mt-6">
//           <div className="flex items-center justify-between mb-2">
//             <label className="block text-sm text-gray-300">You Pay</label>
//             <span className="text-xs text-gray-400">Balance: 0</span>
//           </div>
//           <div className="grid grid-cols-1 sm:grid-cols-[1fr_auto] gap-3">
//             <input
//               value={amountIn}
//               onChange={(e) => setAmountIn(e.target.value)}
//               className="rounded-md border border-slate-600 bg-slate-700 text-gray-100 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-slate-500"
//             />
//             <select
//               value={tokenIn}
//               onChange={(e) => setTokenIn(e.target.value)}
//               className="rounded-md border border-slate-600 bg-slate-700 text-gray-100 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-slate-500"
//             >
//               <option value="">Select Token In</option>
//               {tokenOptions.map((opt) => (
//                 <option key={opt.value} value={opt.value}>{opt.label}</option>
//               ))}
//             </select>
//           </div>

//           <div className="mt-3 space-y-2">
//             <label className="flex items-center gap-2 text-sm text-gray-300">
//               <input type="checkbox" checked={specifyVaultIn} onChange={(e) => setSpecifyVaultIn(e.target.checked)} />
//               Specify tokenIn Vault
//             </label>
//             {specifyVaultIn && (
//               <div className="text-xs text-gray-400 ml-6">
//                 💡 <strong>Vault Deposit Tip</strong>: To deposit tokens into a vault, select the same vault address as your "Token Out" selection.
//               </div>
//             )}
//             {specifyVaultIn && (
//               <select
//                 value={selectedVaultIn}
//                 onChange={(e) => setSelectedVaultIn(e.target.value as `0x${string}`)}
//                 className="w-full rounded-md border border-slate-600 bg-slate-700 text-gray-100 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-slate-500"
//               >
//                 <option value="">Select a Strategy Vault</option>
//                 {vaultOptions.map((opt) => (
//                   <option key={opt.value} value={opt.value}>{opt.label}</option>
//                 ))}
//               </select>
//             )}
//             <label className="flex items-center gap-2 text-sm text-gray-300">
//               <input
//                 type="checkbox"
//                 checked={useEthIn}
//                 onChange={(e) => {
//                   const checked = e.target.checked
//                   setUseEthIn(checked)
//                   // Note: tokenInAddress will automatically resolve to weth9Addr when useEthIn is true
//                 }}
//               />
//               Use ETH (treat WETH as ETH)
//             </label>
//           </div>
//         </div>

//         {/* Arrow */}
//         <div className="my-5 flex justify-center">
//           <div className="h-8 w-8 rounded-full bg-slate-700 text-gray-100 flex items-center justify-center border border-slate-600">↓</div>
//         </div>

//         {/* You Receive */}
//         <div>
//           <label className="block text-sm text-gray-300 mb-2">You Receive</label>
//           <div className="grid grid-cols-1 sm:grid-cols-[1fr_auto] gap-3">
//             <input
//               value={formattedPreview}
//               readOnly
//               className="rounded-md border border-slate-600 bg-slate-700 text-gray-100 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-slate-500"
//             />
//             <select
//               value={tokenOut}
//               onChange={(e) => setTokenOut(e.target.value)}
//               className="rounded-md border border-slate-600 bg-slate-700 text-gray-100 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-slate-500"
//             >
//               <option value="">Select Token Out</option>
//               {tokenOptions.map((opt) => (
//                 <option key={opt.value} value={opt.value}>{opt.label}</option>
//               ))}
//             </select>
//           </div>

//           {previewError && (
//             <p className="mt-2 text-sm text-red-400">Preview error: {String((previewError as any).shortMessage || (previewError as any).message)}</p>
//           )}

//           <div className="mt-3 space-y-2">
//             <label className="flex items-center gap-2 text-sm text-gray-300">
//               <input type="checkbox" checked={specifyVaultOut} onChange={(e) => setSpecifyVaultOut(e.target.checked)} />
//               Specify tokenOut Vault
//             </label>
//             {specifyVaultOut && (
//               <select
//                 value={selectedVaultOut}
//                 onChange={(e) => setSelectedVaultOut(e.target.value as `0x${string}`)}
//                 className="w-full rounded-md border border-slate-600 bg-slate-700 text-gray-100 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-slate-500"
//               >
//                 <option value="">Select a Strategy Vault</option>
//                 {vaultOptions.map((opt) => (
//                   <option key={opt.value} value={opt.value}>{opt.label}</option>
//                 ))}
//               </select>
//             )}
//             <label className="flex items-center gap-2 text-sm text-gray-300">
//               <input
//                 type="checkbox"
//                 checked={useEthOut}
//                 onChange={(e) => {
//                   const checked = e.target.checked
//                   setUseEthOut(checked)
//                   // Note: tokenOutAddress will automatically resolve to weth9Addr when useEthOut is true
//                 }}
//               />
//               Use ETH (treat WETH as ETH)
//             </label>
//           </div>
//         </div>

//         {/* Slippage */}
//         <div className="mt-6">
//           <label className="block text-sm text-gray-300 mb-2">Slippage Tolerance</label>
//           <div className="flex items-center gap-2">
//             {[0.1, 0.5, 1].map((v) => (
//               <button
//                 key={v}
//                 type="button"
//                 onClick={() => setSlippage(v)}
//                 className={`px-3 py-1 rounded-md border ${slippage === v ? 'bg-blue-600 border-blue-500 text-white' : 'bg-slate-700 border-slate-600 text-gray-200 hover:bg-slate-600'}`}
//               >
//                 {v}%
//               </button>
//             ))}
//           </div>
//         </div>

//         {/* Submit */}
//         <div className="mt-6">
//           <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
//             <button
//               type="button"
//               onClick={() => refetchPreview()}
//               className="rounded-md bg-slate-700 text-gray-200 border border-slate-600 py-2.5 hover:bg-slate-600 disabled:opacity-50"
//               disabled={!ready || previewPending}
//             >
//               {previewPending ? 'Previewing…' : 'Preview Quote'}
//             </button>
//             <button
//               type="button"
//               onClick={handleSwap}
//               className="rounded-md bg-blue-600 text-white border border-blue-500 py-2.5 hover:bg-blue-500 disabled:opacity-50"
//               disabled={!ready || !preview?.result || swapPending}
//             >
//               {swapPending ? 'Swapping…' : 'Swap'}
//             </button>
//           </div>
//           {!ready && (
//             <div className="mt-2 text-xs text-gray-400">
//               {(!isConnected) && <div>- Connect wallet</div>}
//               {(!finalPool) && <div>- Select a pool</div>}
//               {(!tokenInAddress) && <div>- Select token in</div>}
//               {(!tokenOutAddress) && <div>- Select token out</div>}
//               {(!tokensValid) && <div>- Token selection invalid</div>}
//               {(exactAmountIn === undefined) && <div>- Enter a valid amount</div>}
//               {(!routeValid) && <div>- Invalid route (check vault selections)</div>}
//             </div>
//           )}
//         </div>
//       </div>
//     </div>
//   )
// }
