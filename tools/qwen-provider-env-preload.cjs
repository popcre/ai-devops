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
// Shell-like tokenization for NODE_OPTIONS and SANDBOX_FLAGS. Splitting on
// whitespace alone broke any quoted argument that contains spaces: a
// `--require "/path/with spaces/mod.js"` left the fragments `/path/with` and
// `spaces/mod.js"` in NODE_OPTIONS, and a quoted stale `--env NAME="old
// value"` left its fragments in the Docker args. Quotes group; backslashes are
// literal outside quotes (Windows paths) and escape only inside double quotes.
function splitArgs(str) {
  const toks = [];
  let cur = '';
  let started = false;
  let quote = null;
  for (let i = 0; i < str.length; i += 1) {
    const c = str[i];
    if (quote) {
      if (c === quote) { quote = null; continue; }
      if (quote === '"' && c === '\\' && i + 1 < str.length) { cur += str[i + 1]; i += 1; continue; }
      cur += c;
      continue;
    }
    if (c === '"' || c === "'") { quote = c; started = true; continue; }
    if (c === ' ' || c === '\t' || c === '\n' || c === '\r') {
      if (started) { toks.push(cur); cur = ''; started = false; }
      continue;
    }
    cur += c;
    started = true;
  }
  if (started) toks.push(cur);
  return toks;
}
// Re-quote only what needs it, so simple flags round-trip byte-identical and a
// token with spaces survives the next shell-like split as one argument.
function joinArgs(toks) {
  return toks.map((t) => {
    if (t.length > 0 && !/[\s"']/.test(t)) return t;
    return '"' + t.replace(/(\\|")/g, '\\$1') + '"';
  }).join(' ');
}
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
  const toks = splitArgs(process.env.SANDBOX_FLAGS || '');
  const kept = [];
  for (let i = 0; i < toks.length; i += 1) {
    const t = toks[i];
    if ((t === '--env' || t === '-e') && isOurs(toks[i + 1])) { i += 1; continue; }
    const m = /^(?:--env|-e)=(.*)$/.exec(t);
    if (m && isOurs(m[1])) continue;
    kept.push(t);
  }
  kept.push('--env', NAME);
  process.env.SANDBOX_FLAGS = joinArgs(kept);
}

// Issue #1032: once the key is in the environment this preloader has no work
// left, so drop every --require from NODE_OPTIONS. Otherwise Qwen's --sandbox
// forwards NODE_OPTIONS into the container, where a host-only path does not
// exist, and every sandboxed review dies with MODULE_NOT_FOUND before any
// model call. This preloader's own --require is the one the wrapper sets, but
// any other host --require that rides along is the same class of break, so the
// strip is total: a sandboxed child must never be told to require a host path.
// The host re-exec chain keeps working because the key itself is an ordinary
// inherited variable.
if (process.env.NODE_OPTIONS) {
  const opts = splitArgs(process.env.NODE_OPTIONS);
  const kept = [];
  for (let i = 0; i < opts.length; i += 1) {
    const m = /^(?:--require|-r)(?:=(.*))?$/.exec(opts[i]);
    if (m) {
      // `--require=VALUE` is one token; `--require VALUE` is two. A quoted
      // value with spaces is already one token after splitArgs, so the
      // spaced form consumes exactly that next token and leaves no fragments.
      if (m[1] === undefined) i += 1;
      continue;
    }
    kept.push(opts[i]);
  }
  if (kept.length) process.env.NODE_OPTIONS = joinArgs(kept);
  else delete process.env.NODE_OPTIONS;
}
