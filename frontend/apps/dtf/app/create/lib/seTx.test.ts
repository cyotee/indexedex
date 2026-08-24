import { describe, expect, it } from 'vitest'

import {
  bytecodeLooksLikeContract,
  requireContractCode,
  receiptFromUnknown,
  sendWalletWrite,
  waitForCreateReceipt,
  waitForSubmittedReceipt,
} from './seTx'

const HASH = `0x${'11'.repeat(32)}` as const

describe('bytecodeLooksLikeContract', () => {
  it('rejects empty accounts that MetaMask would show as Send ETH', () => {
    expect(bytecodeLooksLikeContract('0x')).toBe(false)
    expect(bytecodeLooksLikeContract('0x0')).toBe(false)
    expect(bytecodeLooksLikeContract('')).toBe(false)
    expect(bytecodeLooksLikeContract(undefined)).toBe(false)
  })

  it('accepts contract bytecode', () => {
    expect(bytecodeLooksLikeContract('0x6080604052')).toBe(true)
  })

  it('refuses to send when the wallet RPC has no code at the factory', async () => {
    await expect(
      requireContractCode({
        walletProvider: {
          request: async () => '0x',
        },
        address: '0x79a92DD1ab0a958AA30002d03D464Dd5C775615D',
        label: 'The strategy vault factory',
      }),
    ).rejects.toThrow(/not on the connected network/)
  })
})

describe('receiptFromUnknown', () => {
  it('returns null when the tx is not mined', () => {
    expect(receiptFromUnknown(HASH, null)).toBeNull()
    expect(receiptFromUnknown(HASH, { status: '0x1' })).toBeNull()
    expect(receiptFromUnknown(HASH, { blockNumber: '0x0', status: '0x1' })).toBeNull()
  })

  it('reads a JSON-RPC success receipt', () => {
    const got = receiptFromUnknown(HASH, {
      blockNumber: '0x1',
      status: '0x1',
      logs: [{ data: '0xabc', topics: ['0xdef'] }],
    })
    expect(got?.status).toBe('success')
    expect(got?.logs).toHaveLength(1)
  })

  it('reads a viem success receipt', () => {
    const got = receiptFromUnknown(HASH, {
      blockNumber: 12n,
      status: 'success',
      logs: [],
    })
    expect(got?.status).toBe('success')
  })

  it('reads a reverted receipt', () => {
    const got = receiptFromUnknown(HASH, { blockNumber: '0x2', status: '0x0', logs: [] })
    expect(got?.status).toBe('reverted')
  })
})

describe('waitForSubmittedReceipt', () => {
  it('returns when the wallet RPC has the receipt', async () => {
    let n = 0
    const mined = await waitForSubmittedReceipt({
      hash: HASH,
      timeoutMs: 2_000,
      pollMs: 10,
      walletProvider: {
        request: async () => {
          n += 1
          if (n < 2) return null
          return { blockNumber: '0x10', status: '0x1', logs: [] }
        },
      },
    })
    expect(mined.status).toBe('success')
    expect(n).toBeGreaterThanOrEqual(2)
  })

  it('times out when the wallet RPC has no receipt', async () => {
    await expect(
      waitForSubmittedReceipt({
        hash: HASH,
        timeoutMs: 40,
        pollMs: 10,
        walletProvider: {
          request: async () => null,
        },
      }),
    ).rejects.toThrow(/Timed out/)
  })
})

describe('sendWalletWrite', () => {
  const target = `0x${'33'.repeat(20)}` as const
  const account = `0x${'22'.repeat(20)}` as const
  const abi = [
    {
      type: 'function',
      name: 'deployVault',
      stateMutability: 'nonpayable',
      inputs: [],
      outputs: [{ type: 'address' }],
    },
  ] as const

  it('submits eth_sendTransaction through the wallet provider', async () => {
    let sent: unknown
    const hash = await sendWalletWrite({
      account,
      address: target,
      abi,
      functionName: 'deployVault',
      args: [],
      walletProvider: {
        request: async (args) => {
          sent = args
          return HASH
        },
      },
    })
    expect(hash).toBe(HASH)
    expect(sent).toMatchObject({
      method: 'eth_sendTransaction',
    })
  })

  it('falls back to walletClient.sendTransaction', async () => {
    let sent: unknown
    const hash = await sendWalletWrite({
      account,
      address: target,
      abi,
      functionName: 'deployVault',
      args: [],
      walletClient: {
        sendTransaction: async (req: unknown) => {
          sent = req
          return HASH
        },
      } as never,
    })
    expect(hash).toBe(HASH)
    expect(sent).toMatchObject({ to: target })
  })
})

describe('waitForCreateReceipt', () => {
  it('uses the wallet-preferred client when it has a mined receipt', async () => {
    const got = await waitForCreateReceipt({
      hash: HASH,
      readClient: {
        waitForTransactionReceipt: async () => ({
          blockNumber: 12n,
          status: 'success',
          logs: [],
        }),
      } as never,
    })
    expect(got.status).toBe('success')
  })

  it('polls the injected provider if the client wait fails', async () => {
    const got = await waitForCreateReceipt({
      hash: HASH,
      timeoutMs: 2_000,
      readClient: {
        waitForTransactionReceipt: async () => {
          throw new Error('wallet client wait failed')
        },
      } as never,
      walletProvider: {
        request: async () => ({ blockNumber: '0x10', status: '0x1', logs: [] }),
      },
    })
    expect(got.status).toBe('success')
  })
})
