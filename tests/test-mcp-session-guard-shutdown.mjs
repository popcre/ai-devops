// Execute the actual guard with process/timer mocks: no native processes or kills.
import assert from 'node:assert/strict'
import { EventEmitter } from 'node:events'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'

const source = readFileSync(new URL('../bin/mcp-session-guard.mjs', import.meta.url), 'utf8')
  .replace(/^#!.*\n/, '').replace(/^import .*\n/gm, '')
function fixture({ throwTaskkill = false } = {}) {
  const calls = [], exits = [], diagnostics = [], timers = []
  const helper = new EventEmitter(), killer = new EventEmitter(), process = new EventEmitter()
  Object.assign(helper, { pid: 200, exitCode: null, signalCode: null, stdin: new EventEmitter() })
  Object.assign(killer, { pid: 300, exitCode: null, signalCode: null,
    kill(signal) { calls.push(['owned-killer-stop', signal]); this.signalCode = signal } })
  Object.assign(process, { argv: ['node', 'guard', 'helper.cmd'], platform: 'win32',
    ppid: 100, env: { ComSpec: 'cmd.exe' }, stdin: new EventEmitter(),
    stderr: { write(message) { diagnostics.push(message) } },
    exit(code) { exits.push(code) }, kill() { throw new Error('no PID-based kill permitted') } })
  process.stdin.pipe = () => {}
  vm.runInNewContext(source, { process,
    spawn(command, args) {
      calls.push([command, ...args])
      if (command === 'taskkill' && throwTaskkill) throw new Error('fixture synchronous spawn failure')
      return command === 'taskkill' ? killer : helper
    }, spawnSync() { return { stdout: '' } }, readFileSync() { return '' },
    setTimeout(fn, ms) { const timer = { fn, ms, cleared: false, unref() {} }; timers.push(timer); return timer },
    clearTimeout(timer) { timer.cleared = true }, setInterval() { return { unref() {} } }, clearInterval() {} })
  return { calls, exits, diagnostics, timers, helper, killer, process,
    eof() { process.stdin.emit('end'); timers.find(t => t.ms === 250).fn() },
    childExit(code = 1) { helper.exitCode = code; helper.emit('exit', code, null) },
    taskkillExit(code = 0) { killer.exitCode = code; killer.emit('exit', code, null) } }
}

for (const order of ['child-first', 'taskkill-first']) {
  const f = fixture(); f.eof()
  if (order === 'child-first') f.childExit(); else f.taskkillExit()
  assert.deepEqual(f.exits, [], `${order}: guard must retain cleanup ownership`)
  if (order === 'child-first') f.taskkillExit(); else f.childExit()
  assert.deepEqual(f.exits, [143], `${order}: confirmed EOF keeps its exit status`)
  assert.equal(f.calls.filter(c => c[0] === 'taskkill').length, 1)
  assert.deepEqual(f.calls.find(c => c[0] === 'taskkill').slice(1), ['/PID', '200', '/T', '/F'])
}
for (const mode of ['nonzero', 'spawn-error', 'timeout']) {
  const f = fixture(); f.eof(); f.childExit()
  if (mode === 'nonzero') f.taskkillExit(5)
  if (mode === 'spawn-error') f.killer.emit('error', new Error('fixture taskkill unavailable'))
  if (mode === 'timeout') f.timers.find(t => t.ms === 2000).fn()
  assert.deepEqual(f.exits, [1], `${mode}: unconfirmed cleanup must fail`)
  assert.ok(f.diagnostics.join('').includes('teardown'), `${mode}: failure must be visible`)
  assert.equal(f.calls.filter(c => c[0] === 'taskkill').length, 1,
    `${mode}: never retry against a potentially reused child PID`)
  f.taskkillExit(); f.killer.emit('error', new Error('fixture late failure'))
  f.helper.emit('exit', 1, null); f.timers.find(t => t.ms === 2000).fn()
  assert.deepEqual(f.exits, [1], `${mode}: late events must not finish twice`)
  assert.equal(f.calls.filter(c => c[0] === 'taskkill').length, 1)
}
const spawnThrow = fixture({ throwTaskkill: true }); spawnThrow.eof()
assert.deepEqual(spawnThrow.exits, [1], 'synchronous spawn failure must fail cleanup')
assert.ok(spawnThrow.diagnostics.join('').includes('teardown'))
spawnThrow.childExit(); spawnThrow.timers.find(t => t.ms === 2000).fn()
assert.deepEqual(spawnThrow.exits, [1], 'late child exit and deadline must not finish twice')
assert.equal(spawnThrow.calls.filter(c => c[0] === 'taskkill').length, 1)
for (const [signal, expected] of [['SIGTERM', 143], ['SIGHUP', 143], ['SIGINT', 130]]) {
  const f = fixture(); f.process.emit(signal); f.childExit(); f.taskkillExit()
  assert.deepEqual(f.exits, [expected])
}
const natural = fixture(); natural.childExit(7)
assert.deepEqual(natural.exits, [7]); assert.equal(natural.calls.length, 1)
const alreadyGone = fixture()
alreadyGone.helper.exitCode = 7; alreadyGone.process.emit('SIGTERM')
assert.deepEqual(alreadyGone.exits, [143]); assert.equal(alreadyGone.calls.length, 1)
const late = fixture(); late.eof(); late.childExit(); late.taskkillExit()
assert.ok(late.timers.find(t => t.ms === 2000).cleared)
assert.ok(late.calls.every(c => c[0] !== 'taskkill' || c[2] === '200'), 'foreign PID must never be targeted')
const reused = fixture(); reused.eof(); reused.childExit()
// ChildProcess.pid still names the old PID after exit; a later taskkill retry
// could hit its new owner. Never submit another tree kill on the deadline.
reused.timers.find(t => t.ms === 2000).fn()
assert.deepEqual(reused.exits, [1])
assert.deepEqual(reused.calls.filter(c => c[0] === 'taskkill'), [['taskkill', '/PID', '200', '/T', '/F']])
const rootStillRunning = fixture(); rootStillRunning.eof(); rootStillRunning.taskkillExit()
rootStillRunning.timers.find(t => t.ms === 2000).fn()
assert.deepEqual(rootStillRunning.exits, [1], 'taskkill success alone cannot prove direct child stopped')
console.log('PASS: Windows shutdown waits for native teardown without stale PID retries')
