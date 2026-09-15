const assert = require('node:assert/strict')
const { test } = require('node:test')
const { PHASE_DEVELOPMENT_SERVER, PHASE_PRODUCTION_BUILD, PHASE_PRODUCTION_SERVER } = require('next/constants')
const config = require('../next.config')

test('deployment flag defaults safely, validates values, and isolates dev outputs', () => {
  const original = process.env.NEXT_PUBLIC_SITE_DEPLOYMENT
  try {
    delete process.env.NEXT_PUBLIC_SITE_DEPLOYMENT
    assert.equal(config(PHASE_PRODUCTION_BUILD).env.NEXT_PUBLIC_SITE_DEPLOYMENT, 'indexedex')
    for (const site of ['indexedex', 'dtf']) {
      process.env.NEXT_PUBLIC_SITE_DEPLOYMENT = site
      const dev = config(PHASE_DEVELOPMENT_SERVER)
      assert.equal(dev.env.NEXT_PUBLIC_SITE_DEPLOYMENT, site)
      assert.equal(dev.distDir, `.next-${site}`)
      for (const phase of [PHASE_PRODUCTION_BUILD, PHASE_PRODUCTION_SERVER]) {
        assert.equal(config(phase).distDir, '.next')
        assert.equal(config(phase).env.NEXT_PUBLIC_SITE_DEPLOYMENT, site)
      }
    }
    for (const invalid of ['', 'DTF', 'true', 'unknown']) {
      process.env.NEXT_PUBLIC_SITE_DEPLOYMENT = invalid
      assert.throws(() => config(PHASE_PRODUCTION_BUILD), /must be indexedex or dtf/)
    }
  } finally {
    if (original === undefined) delete process.env.NEXT_PUBLIC_SITE_DEPLOYMENT
    else process.env.NEXT_PUBLIC_SITE_DEPLOYMENT = original
  }
})
