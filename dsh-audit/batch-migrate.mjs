#!/usr/bin/env node
/**
 * Batch session migration driver.
 *
 * For every session.jsonl[.zstd] under ~/.dsh/sessions, run the manual
 * migrator and create session.v2.jsonl[.zstd] as a sibling. The original
 * v0 file is never touched.
 *
 * Pre/post sha256 of the v0 file is recorded per session so we can confirm
 * byte preservation at the end.
 *
 * Usage: node batch-migrate.mjs [--root ~/.dsh/sessions]
 */

import { readFileSync, writeFileSync, statSync, readdirSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { resolve, join } from 'node:path'
import { createHash } from 'node:crypto'

const args = process.argv.slice(2)
let root = '/home/fares/.dsh/sessions'
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--root' && args[i + 1]) { root = resolve(args[i + 1]); i++ }
}

function sha256File(path) {
  const h = createHash('sha256')
  h.update(readFileSync(path))
  return h.digest('hex')
}

function findSessionFiles(dir) {
  const out = []
  function walk(d) {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, e.name)
      if (e.isDirectory()) walk(p)
      else if (e.name === 'session.jsonl' || e.name === 'session.jsonl.zstd') out.push(p)
    }
  }
  walk(dir)
  return out
}

const sessions = findSessionFiles(root)
console.log(`found ${sessions.length} session logs under ${root}`)

const manifest = []
let ok = 0
let skip = 0
let fail = 0
const t0 = Date.now()

for (const s of sessions) {
  const v2 = s.replace(/session\.jsonl(\.zstd)?$/, 'session.v2.jsonl$1')
  if (statSync(v2, { throwIfNoEntry: false })) {
    skip++
    continue
  }
  const before = sha256File(s)
  const r = spawnSync('node', [
    '/home/fares/local/dsh-audit/manual-migrate.mjs',
    s,
  ], { encoding: 'utf8', maxBuffer: 1024 * 1024 })
  if (r.status !== 0) {
    fail++
    manifest.push({ session: s, status: 'failed', error: r.stderr })
    continue
  }
  const after = sha256File(s)
  if (before !== after) {
    fail++
    manifest.push({ session: s, status: 'corrupted', before, after })
    continue
  }
  ok++
  manifest.push({ session: s, status: 'ok', v2, v0sha256: before, outputSize: statSync(v2).size })
}

const t1 = Date.now()
const report = {
  root,
  total: sessions.length,
  ok,
  skip,
  fail,
  duration_ms: t1 - t0,
  manifest,
}
writeFileSync(
  '/home/fares/local/dsh-audit/migration-report.json',
  JSON.stringify(report, null, 2),
  'utf8',
)
console.log(JSON.stringify({ ok, skip, fail, duration_ms: t1 - t0, total: sessions.length }))
