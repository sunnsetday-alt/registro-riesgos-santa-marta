// Genera la huella cifrada de la clave del administrador para public/config.js.
// Uso: node tools/admin-hash.mjs "NuevaClaveSegura"
import { pbkdf2Sync, randomBytes } from 'node:crypto';
const pw = process.argv[2];
if (!pw || pw.length < 12) { console.error('Escribe una clave de al menos 12 caracteres.'); process.exit(1); }
const salt = randomBytes(16).toString('hex');
const iterations = 310000;
const hash = pbkdf2Sync(pw, Buffer.from(salt, 'hex'), iterations, 32, 'sha256').toString('hex');
console.log(JSON.stringify({ salt, iterations, hash }, null, 2));
