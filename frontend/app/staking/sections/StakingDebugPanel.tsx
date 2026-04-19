'use client'

import DebugPanel from '../../components/DebugPanel'
import type { ChainSources } from '../../lib/hooks/useChainResolution'

interface StakingDebugPanelProps {
  chainSources: ChainSources
  attachedWalletChainId: number | undefined
  resolvedWalletChainId: number | null
  dataChainId: number
  routerAddress: `0x${string}` | null
  routerHasBytecode: boolean | null
  routerBytecodeError: string
  detfAddress: `0x${string}` | undefined
  richTokenAddress: string
  richirTokenAddress: string
  reservePoolAddress: string
  nftVaultAddress: string
  status: string
}

export default function StakingDebugPanel({
  chainSources,
  attachedWalletChainId,
  resolvedWalletChainId,
  dataChainId,
  routerAddress,
  routerHasBytecode,
  routerBytecodeError,
  detfAddress,
  richTokenAddress,
  richirTokenAddress,
  reservePoolAddress,
  nftVaultAddress,
  status,
}: StakingDebugPanelProps) {
  return (
    <DebugPanel title="🔍 Staking Debug">
      <div className="space-y-2 break-all">
        <div>Wallet chain: {attachedWalletChainId ?? '—'} | Resolved wallet chain: {resolvedWalletChainId ?? '—'} | Display chain: {dataChainId}</div>
        <div>
          Sources: account {chainSources.account ?? '—'} | connection {chainSources.connection ?? '—'} | walletClient {chainSources.walletClient ?? '—'} | connectorClient {chainSources.connectorClient ?? '—'} | connectorHook {chainSources.connectorHook ?? '—'} | browser {chainSources.browser ?? '—'} | config {chainSources.config}
        </div>
        <div>Router: {routerAddress ?? '—'} | bytecode: {String(routerHasBytecode)}</div>
        {routerBytecodeError ? <div>Router error: {routerBytecodeError}</div> : null}
        <div>CHIR: {detfAddress ?? '—'}</div>
        <div>RICH: {richTokenAddress}</div>
        <div>RICHIR: {richirTokenAddress}</div>
        <div>NFT Vault: {nftVaultAddress}</div>
        <div>Reserve Pool: {reservePoolAddress}</div>
        <div>Status: {status || '—'}</div>
      </div>
    </DebugPanel>
  )
}