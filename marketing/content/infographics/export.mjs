#!/usr/bin/env node
/**
 * Render each 1600x900 board to PNG at 2x, then copy into track-b piece folders.
 * Usage (from repo root):
 *   node marketing/content/infographics/export.mjs
 */
import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const repo = path.resolve(here, '../../..')
const outDir = path.join(here, 'out')
const trackB = path.join(here, '../track-b')
const require = createRequire(path.join(repo, 'frontend/apps/dtf/package.json'))
const { chromium } = require('playwright')

const boards = [
  { html: '01-what-is-detf', dest: '01-definition' },
  { html: '02-spreadsheet-vs-reserve', dest: '02-spreadsheet-vs-reserve' },
  { html: '03-create-your-own', dest: '03-create-your-own' },
  { html: '04-inert-until-first-bond', dest: '04-inert-until-first-bond' },
  { html: '05-two-doors-one-route', dest: '05-two-doors-one-route' },
  { html: '06-bond-vs-buy', dest: '06-bond-vs-buy' },
  { html: '07-three-steps', dest: '07-three-steps' },
  { html: '08-what-you-pick', dest: '08-what-you-pick' },
]

fs.mkdirSync(outDir, { recursive: true })

const browser = await chromium.launch()
const page = await browser.newPage({
  viewport: { width: 1600, height: 900 },
  deviceScaleFactor: 2,
})

for (const item of boards) {
  const html = path.join(here, `${item.html}.html`)
  await page.goto(pathToFileURL(html).href, { waitUntil: 'networkidle' })
  const board = page.locator('#board')
  await board.waitFor({ state: 'visible' })
  const pngName = `${item.html}.png`
  const dest = path.join(outDir, pngName)
  await board.screenshot({ path: dest, type: 'png' })
  const pieceDir = path.join(trackB, item.dest)
  fs.mkdirSync(pieceDir, { recursive: true })
  fs.copyFileSync(dest, path.join(pieceDir, 'board.png'))
  console.log(path.relative(repo, dest))
}

await browser.close()
