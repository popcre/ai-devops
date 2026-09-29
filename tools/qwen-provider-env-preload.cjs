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
}

// Issue #1032: once the key is in the environment this preloader has no work
// left, so drop its own --require from NODE_OPTIONS. Otherwise Qwen's --sandbox
// forwards NODE_OPTIONS into the container, where this host path does not
// exist, and every sandboxed review dies with MODULE_NOT_FOUND before any
// model call. The host re-exec chain keeps working because the key itself is
// an ordinary inherited variable.
if (process.env.NODE_OPTIONS) {
  const self = __filename;
  const kept = process.env.NODE_OPTIONS.split(/\s+/).filter((opt) => opt
    && opt !== `--require=${self}` && opt !== `-r=${self}`);
  if (kept.length) process.env.NODE_OPTIONS = kept.join(' ');
  else delete process.env.NODE_OPTIONS;
}
