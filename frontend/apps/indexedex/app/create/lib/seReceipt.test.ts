import { describe, expect, it } from 'vitest'
import { encodeAbiParameters, encodeEventTopics, getAddress, type Address, type Hex } from 'viem'

import { NEW_VAULT_EVENT } from './seAbi'
import { vaultFromReceipt } from './seReceipt'

const PKG = '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd' as const
const OTHER_PKG = '0x2222222222222222222222222222222222222222' as const
const VAULT = '0x3333333333333333333333333333333333333333' as const
const OTHER_VAULT = '0x4444444444444444444444444444444444444444' as const
const ZERO_HASH = `0x${'00'.repeat(32)}` as Hex

function vaultLog(pkg: Address, vault: Address) {
  return {
    topics: encodeEventTopics({
      abi: [NEW_VAULT_EVENT],
      eventName: 'NewVault',
      args: { vault, package: pkg, contentsId: ZERO_HASH },
    }) as Hex[],
    data: encodeAbiParameters(
      [{ type: 'bytes32' }, { type: 'bytes4[]' }, { type: 'address[]' }],
      [ZERO_HASH, [], []],
    ),
  }
}

describe('vaultFromReceipt', () => {
  it('returns the vault for the selected package', () => {
    expect(vaultFromReceipt([vaultLog(PKG, VAULT)], PKG)).toBe(VAULT)
  })

  it('rejects a receipt containing only another package', () => {
    expect(vaultFromReceipt([vaultLog(OTHER_PKG, OTHER_VAULT)], PKG)).toBeUndefined()
  })

  it('continues past another package to the selected package', () => {
    expect(vaultFromReceipt([vaultLog(OTHER_PKG, OTHER_VAULT), vaultLog(PKG, VAULT)], PKG)).toBe(VAULT)
  })

  it('skips malformed and unrelated logs before a matching event', () => {
    const malformed = { ...vaultLog(PKG, OTHER_VAULT), data: '0x' as Hex }
    const unrelated = {
      topics: encodeEventTopics({
        abi: [{ type: 'event', name: 'OtherEvent', inputs: [] }] as const,
        eventName: 'OtherEvent',
      }) as Hex[],
      data: '0x' as Hex,
    }
    expect(vaultFromReceipt([malformed, unrelated], PKG)).toBeUndefined()
    expect(vaultFromReceipt([malformed, unrelated, vaultLog(PKG, VAULT)], PKG)).toBe(VAULT)
  })

  it('matches package addresses case-insensitively', () => {
    const uppercase = `0x${PKG.slice(2).toUpperCase()}` as Address
    expect(vaultFromReceipt([vaultLog(PKG, VAULT)], uppercase)).toBe(VAULT)
    expect(vaultFromReceipt([vaultLog(getAddress(PKG), VAULT)], PKG)).toBe(VAULT)
  })

  it('explicitly allows any package when the filter is omitted or undefined', () => {
    const logs = [vaultLog(OTHER_PKG, OTHER_VAULT), vaultLog(PKG, VAULT)]
    expect(vaultFromReceipt(logs)).toBe(OTHER_VAULT)
    expect(vaultFromReceipt(logs, undefined)).toBe(OTHER_VAULT)
  })

  it('returns no vault for absent or empty logs', () => {
    expect(vaultFromReceipt(undefined, PKG)).toBeUndefined()
    expect(vaultFromReceipt([], PKG)).toBeUndefined()
  })
})
