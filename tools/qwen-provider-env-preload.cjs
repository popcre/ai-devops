'use strict';
// Hand the Coding Plan key to Qwen without ever putting it on a command line.
//
// The wrapper writes the key to a private, self-deleting file and points
// AI_QWEN_SECRET_FILE at it. This preloader reads that file once, deletes it,
// and moves the key into the one environment variable Qwen itself strips from
// every tool child (sanitizeChildEnv). Qwen re-execs itself during startup
// (cli-entry -> cli -> cli), so the key has to survive that chain; an ordinary
// inherited variable does, while the deleted handoff file cannot be read by
// anything that starts later.
const fs = require('node:fs');
// Node children started later do not carry AI_QWEN_SECRET_FILE (it is deleted
// below), so an unset variable means "not the credentialed process". A NAMED but
// missing handoff is a real failure and must not degrade into a silent
// unauthenticated run.
const secretFile = process.env.AI_QWEN_SECRET_FILE;
if (secretFile) {
  if (!fs.existsSync(secretFile)) throw new Error('Qwen secret handoff file is missing');
  const secret = fs.readFileSync(secretFile, 'utf8').replace(/[\r\n]+$/, '');
  fs.unlinkSync(secretFile);
  delete process.env.AI_QWEN_SECRET_FILE;
  if (!secret) throw new Error('empty Qwen secret file');
  process.env.BAILIAN_CODING_PLAN_API_KEY = secret;
  // Qwen's --sandbox starts a container that forwards only a fixed list of
  // provider variables (OPENAI_API_KEY, GEMINI_API_KEY, ...), so the Coding
  // Plan key never reached the sandboxed CLI and every review failed with
  // "Missing API key". A bare `--env NAME` makes docker copy the value from
  // its own inherited environment, so the key is never written into the
  // docker command line (unlike SANDBOX_ENV=NAME=value or OPENAI_API_KEY).
  // Tokenize SANDBOX_FLAGS: drop every existing --env for this exact name
  // (bare or NAME=value, spaced or --env=), then add one bare forward so a stale
  // value can never win and a similarly named variable never counts as present.
  const NAME = 'BAILIAN_CODING_PLAN_API_KEY';
  const isOurs = (v) => v === NAME || (typeof v === 'string' && v.startsWith(NAME + '='));
  const toks = (process.env.SANDBOX_FLAGS || '').split(/\s+/).filter(Boolean);
  const kept = [];
  for (let i = 0; i < toks.length; i += 1) {
    const t = toks[i];
    if ((t === '--env' || t === '-e') && isOurs(toks[i + 1])) { i += 1; continue; }
    const m = /^(?:--env|-e)=(.*)$/.exec(t);
    if (m && isOurs(m[1])) continue;
    kept.push(t);
  }
  kept.push('--env', NAME);
  process.env.SANDBOX_FLAGS = kept.join(' ');
}

// Issue #1032: once the key is in the environment this preloader has no work
// left, so drop its own --require from NODE_OPTIONS. Otherwise Qwen's --sandbox
// forwards NODE_OPTIONS into the container, where this host path does not
// exist, and every sandboxed review dies with MODULE_NOT_FOUND before any
// model call. The host re-exec chain keeps working because the key itself is
// an ordinary inherited variable.
if (process.env.NODE_OPTIONS) {
  // Compare real paths: on Windows the wrapper may spell this file as an MSYS
  // path (/d/...) or with different case/separators than __filename.
  const path = require('node:path');
  const canon = (p) => {
    let v = String(p).replace(/^["']|["']$/g, '');
    if (process.platform === 'win32') {
      v = v.replace(/^\/([a-zA-Z])\//, '$1:/');
    }
    try { v = fs.realpathSync.native(v); } catch { v = path.resolve(v); }
    return process.platform === 'win32' ? v.replace(/\//g, '\\').toLowerCase() : v;
  };
  const self = canon(__filename);
  const opts = process.env.NODE_OPTIONS.split(/\s+/).filter(Boolean);
  const kept = [];
  for (let i = 0; i < opts.length; i += 1) {
    const m = /^(?:--require|-r)(?:=(.*))?$/.exec(opts[i]);
    if (m) {
      const target = m[1] !== undefined ? m[1] : opts[i + 1];
      if (target !== undefined && canon(target) === self) {
        if (m[1] === undefined) i += 1;
        continue;
      }
    }
    kept.push(opts[i]);
  }
  if (kept.length) process.env.NODE_OPTIONS = kept.join(' ');
  else delete process.env.NODE_OPTIONS;
}
