#!/usr/bin/env node
// Behaviorally prove that the installed Qwen child-process sanitizer removes
// the Coding Plan credential. This evaluates only the sanitizer declaration
// and function extracted from the vendor bundle, never the whole bundle.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const root = process.argv[2];
if (!root) throw new Error('usage: verify-qwen-child-env-sanitizer.mjs QWEN_ROOT');
const chunks = path.join(root, 'lib', 'chunks');
const files = fs.readdirSync(chunks).filter((name) => name.endsWith('.js'));
const candidates = files.map((name) => path.join(chunks, name)).filter((file) => {
  const text = fs.readFileSync(file, 'utf8');
  return text.includes('var INTERNAL_SECRET_ENV_VARS') && text.includes('function sanitizeChildEnv');
});
if (candidates.length !== 1) throw new Error(`expected one sanitizer bundle, found ${candidates.length}`);
const source = fs.readFileSync(candidates[0], 'utf8');
const declaration = source.match(/var INTERNAL_SECRET_ENV_VARS\s*=\s*\[[\s\S]*?\];/);
const fn = source.match(/function sanitizeChildEnv\([^)]*\)\s*\{[\s\S]*?return sanitized;\s*\n\}/);
if (!declaration || !fn) throw new Error('could not extract the known sanitizer implementation');
let helperProgram = '';
if (fn[0].includes('isInternalSecretEnvVar')) {
  const nameSet = source.match(/var INTERNAL_SECRET_ENV_VAR_NAMES\s*=\s*new Set\([\s\S]*?\);/);
  const helper = source.match(/function isInternalSecretEnvVar\([^)]*\)\s*\{[\s\S]*?\n\}/);
  if (!nameSet || !helper) throw new Error('could not extract the known case-insensitive sanitizer helper');
  helperProgram = `${nameSet[0]}\n${helper[0]}`;
}
const program = `
const PRIVATE_ACP_CAPABILITY_ENV = "QWEN_PRIVATE_ACP_CAPABILITY";
${declaration[0]}
${helperProgram}
${fn[0]}
sanitizeChildEnv({
  BAILIAN_CODING_PLAN_API_KEY: "must-be-removed",
  QWEN_SERVER_TOKEN: "must-be-removed",
  KEEP_ME: "preserved"
});`;
const result = vm.runInNewContext(program, Object.create(null), { timeout: 1000 });
if (!result || result.KEEP_ME !== 'preserved' ||
    Object.hasOwn(result, 'BAILIAN_CODING_PLAN_API_KEY') ||
    Object.hasOwn(result, 'QWEN_SERVER_TOKEN')) {
  throw new Error('installed sanitizer did not remove protected variables while preserving ordinary environment');
}
process.stdout.write(`${candidates[0]}\n`);
