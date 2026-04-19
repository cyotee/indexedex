'use client'

import { useEffect, useState } from 'react'
import { isAddress, type PublicClient } from 'viem'

import { hasBytecode } from '../onchain'

type UseRouterBytecodeParams = {
  publicClient: PublicClient | null | undefined
  routerCandidate: `0x${string}` | string | undefined
}

type UseRouterBytecodeResult = {
  routerAddress: `0x${string}` | null
  routerHasBytecode: boolean | null
  routerBytecodeError: string
}

export function useRouterBytecode({ publicClient, routerCandidate }: UseRouterBytecodeParams): UseRouterBytecodeResult {
  const [routerAddress, setRouterAddress] = useState<`0x${string}` | null>(null)
  const [routerHasBytecode, setRouterHasBytecode] = useState<boolean | null>(null)
  const [routerBytecodeError, setRouterBytecodeError] = useState('')

  useEffect(() => {
    let cancelled = false

    setRouterAddress(null)
    setRouterHasBytecode(null)
    setRouterBytecodeError('')

    if (!publicClient) {
      setRouterHasBytecode(false)
      setRouterBytecodeError('RPC client unavailable')
      return () => {
        cancelled = true
      }
    }

    if (!routerCandidate) {
      setRouterHasBytecode(false)
      setRouterBytecodeError('No router address found in artifacts for this chain')
      return () => {
        cancelled = true
      }
    }

    if (!isAddress(routerCandidate)) {
      setRouterHasBytecode(false)
      setRouterBytecodeError(`Invalid router address in artifacts: ${String(routerCandidate)}`)
      return () => {
        cancelled = true
      }
    }

    void (async () => {
      try {
        const ok = await hasBytecode(publicClient, routerCandidate)
        if (cancelled) return

        if (ok) {
          setRouterAddress(routerCandidate as `0x${string}`)
          setRouterHasBytecode(true)
          return
        }

        setRouterHasBytecode(false)
        setRouterBytecodeError(`Router not deployed at candidate ${String(routerCandidate)}`)
      } catch (error) {
        if (cancelled) return
        setRouterHasBytecode(false)
        setRouterBytecodeError(error instanceof Error ? error.message : String(error))
      }
    })()

    return () => {
      cancelled = true
    }
  }, [publicClient, routerCandidate])

  return {
    routerAddress,
    routerHasBytecode,
    routerBytecodeError,
  }
}

export default useRouterBytecode