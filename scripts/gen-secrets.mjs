#!/usr/bin/env node
// Generate fresh secrets for the stack and print them as .env lines.
//   node scripts/gen-secrets.mjs
import crypto from 'node:crypto';

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const secret = crypto.randomBytes(48).toString('base64url');
const header = { alg: 'HS256', typ: 'JWT' };
const payload = { role: 'anon', iss: 'stars-rewards', iat: Math.floor(Date.now() / 1000) };
const data = `${b64(header)}.${b64(payload)}`;
const sig = crypto.createHmac('sha256', secret).update(data).digest('base64url');

console.log(`POSTGRES_PASSWORD=${crypto.randomBytes(18).toString('base64url')}`);
console.log(`AUTHENTICATOR_PASSWORD=${crypto.randomBytes(18).toString('base64url')}`);
console.log(`JWT_SECRET=${secret}`);
console.log(`ANON_JWT=${data}.${sig}`);
console.log('TRMNL_PROFILE_ID=1');
console.log('\n# Also paste the ANON_JWT into config.js (SUPABASE_KEY) and trmnl.html.');
