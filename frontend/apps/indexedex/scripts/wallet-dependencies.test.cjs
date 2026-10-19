const assert = require('node:assert/strict')
const { test } = require('node:test')
const { createRequire } = require('node:module')
const { parseUri } = require('@walletconnect/utils')

const walletRequire = createRequire(require.resolve('@walletconnect/utils'))
const queryString = walletRequire('query-string')

test('WalletConnect pairing URIs retain their relay and key parameters', () => {
  const topic = 'ab'.repeat(32)
  const symKey = 'cd'.repeat(32)
  const uri = `wc:${topic}@2?relay-protocol=irn&symKey=${symKey}`

  const parsed = parseUri(uri)

  // WalletConnect 2.21.1 strips "wc:" before populating this field.
  assert.equal(parsed.protocol, '')
  assert.equal(parsed.version, 2)
  assert.equal(parsed.topic, topic)
  assert.equal(parsed.symKey, symKey)
  assert.equal(parsed.relay.protocol, 'irn')
})

test('wallet deep links decode nested URIs and Unicode without losing repeated values', () => {
  const uri = 'wc:topic@2?relay-protocol=irn&symKey=abc'
  const query = `uri=${encodeURIComponent(uri)}&name=hello+world&label=%F0%9F%91%8B&chain=1&chain=8453`

  const parsed = queryString.parse(query)

  assert.deepEqual({ ...parsed }, {
    chain: ['1', '8453'],
    label: '\u{1f44b}',
    name: 'hello world',
    uri,
  })
})
