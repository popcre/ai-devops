'use strict';
// Make the Coding Plan key visible to Qwen's direct process.env lookup without
// placing it in the OS environment inherited by shell or tool children.
const fs = require('node:fs');
const secretFile = process.env.AI_QWEN_SECRET_FILE;
delete process.env.AI_QWEN_SECRET_FILE;
if (secretFile) {
  const secret = fs.readFileSync(secretFile, 'utf8').replace(/[\r\n]+$/, '');
  fs.unlinkSync(secretFile);
  if (!secret) throw new Error('empty Qwen secret file');
  delete process.env.BAILIAN_CODING_PLAN_API_KEY;
  const original = process.env;
  process.env = new Proxy(original, {
    get(target, property, receiver) {
      if (property === 'BAILIAN_CODING_PLAN_API_KEY') return secret;
      return Reflect.get(target, property, receiver);
    },
    has(target, property) {
      return property === 'BAILIAN_CODING_PLAN_API_KEY' || Reflect.has(target, property);
    },
    getOwnPropertyDescriptor(target, property) {
      if (property === 'BAILIAN_CODING_PLAN_API_KEY') {
        return { value: secret, enumerable: false, configurable: true, writable: false };
      }
      return Reflect.getOwnPropertyDescriptor(target, property);
    },
    set(target, property, value, receiver) {
      if (property === 'BAILIAN_CODING_PLAN_API_KEY') return false;
      return Reflect.set(target, property, value, receiver);
    }
  });
}
