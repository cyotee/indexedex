'use client'

interface WalletStatusBannerProps {
  isConnected: boolean
  isUnsupportedChain: boolean
  walletMatchesDataChain: boolean
  attachedWalletChainId: number | undefined
  dataChainId: number
  environment: string
  className?: string
}

export default function WalletStatusBanner({
  isConnected,
  isUnsupportedChain,
  walletMatchesDataChain,
  attachedWalletChainId,
  dataChainId,
  environment,
  className = '',
}: WalletStatusBannerProps) {
  if (!isConnected) {
    return (
      <div className={`rounded-lg border border-amber-500/50 bg-amber-600/20 p-3 ${className}`.trim()}>
        <div className="text-sm font-medium text-amber-200">Wallet not connected</div>
        <div className="mt-1 text-xs text-amber-300">
          You can still inspect pricing and state, but you&apos;ll need to connect a wallet to sign approvals or submit staking transactions.
        </div>
      </div>
    )
  }

  if (isUnsupportedChain) {
    return (
      <div className={`rounded-lg border border-rose-500/50 bg-rose-600/20 p-3 ${className}`.trim()}>
        <div className="text-sm font-medium text-rose-200">Unsupported network</div>
        <div className="mt-1 text-xs text-rose-300">
          Connected wallet chainId {attachedWalletChainId ?? '—'} is not mapped for {environment}. The page is showing deployments for chainId {dataChainId}.
        </div>
      </div>
    )
  }

  if (!walletMatchesDataChain) {
    return (
      <div className={`rounded-lg border border-yellow-700 bg-yellow-950/40 p-3 ${className}`.trim()}>
        <div className="text-sm font-medium text-yellow-100">Wallet network mismatch</div>
        <div className="mt-1 text-xs text-yellow-200">
          Wallet is connected to chainId {attachedWalletChainId ?? '—'}, but this page is showing Protocol DETF deployments for chainId {dataChainId}. Switch your wallet network to interact.
        </div>
      </div>
    )
  }

  return null
}