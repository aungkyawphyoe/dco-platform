import { generateKeyPairSync } from "node:crypto";

/**
 * Mint an Ed25519 license-signing keypair (`architecture/feature-gating.md` §5).
 *
 *   npm run license:key
 *
 * Prints the server env vars (private key → Key Vault / local `.env`,
 * never git) and the keyring entry whose `x` goes into the mobile app
 * asset `assets/license_keys.json`. Run once per key; keep the private
 * key offline. To rotate: generate with a fresh `LICENSE_KID`, ship a
 * build containing the new public key first, then switch the env var
 * (old kid stays trusted in existing builds ≥30d).
 */

const { privateKey, publicKey } = generateKeyPairSync("ed25519");
const pkcs8 = privateKey.export({ format: "der", type: "pkcs8" });
const jwk = publicKey.export({ format: "jwk" }) as { x?: string };

if (!jwk.x) throw new Error("Failed to export Ed25519 public key");

const kid = `lic-${new Date().toISOString().slice(0, 10)}`;

console.log("API env (store in Key Vault / .env, chmod 600, never commit):");
console.log(`LICENSE_KID=${kid}`);
console.log(`LICENSE_ED25519_KEY=${Buffer.from(pkcs8).toString("base64url")}`);
console.log("");
console.log('Mobile keyring entry (append to app asset assets/license_keys.json):');
console.log(JSON.stringify({ kid, alg: "EdDSA", kty: "OKP", crv: "Ed25519", x: jwk.x }, null, 2));
