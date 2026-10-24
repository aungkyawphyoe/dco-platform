import { expect, it } from 'vitest';
import { loadEnv } from '../src/config/env.js';
const base = {
  APP_ENV: 'prod', JWT_ACCESS_SECRET: 'a'.repeat(32), JWT_REFRESH_SECRET: 'b'.repeat(32),
  MEDIA_SIGNING_KEY: 'c'.repeat(32), PUBLIC_API_URL: 'https://api.example.com/v1',
  MAIL_PROVIDER: 'acs', CORS_ORIGINS: 'https://admin.example.com,https://fleet.example.com',
};
it('rejects unsafe production configuration without including secret values in errors', () => {
  expect(loadEnv(base).APP_ENV).toBe('prod');
  for (const change of [
    { JWT_ACCESS_SECRET: 'short-secret-value' }, { JWT_REFRESH_SECRET: base.JWT_ACCESS_SECRET },
    { MAIL_PROVIDER: 'stdout' }, { PUBLIC_API_URL: 'http://api.example.com/v1' },
    { CORS_ORIGINS: '*' }, { CORS_ORIGINS: 'https://admin.example.com/path' },
    { JWT_ADMIN_AUD: 'dco-owner' }, { MEDIA_SIGNING_KEY: 'short-key' },
  ]) expect(() => loadEnv({ ...base, ...change })).toThrow();
});
