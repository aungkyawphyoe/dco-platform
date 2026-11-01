import { afterEach, beforeEach, expect, it, vi } from 'vitest';
// Run this contract against each portal's real client and token store:
// PORTAL=web npm exec -- vitest run --config portal-auth.config.ts
// PORTAL=fleet-portal npm exec -- vitest run --config portal-auth.config.ts
import { apiGet, apiPost, apiRequest } from '@/lib/api/client';
import { clearToken, ensureFreshToken, getToken, setToken } from '@/lib/auth/token-store';
import { POST as loginRoute } from '@/app/api/auth/login/route';
import { POST as sessionRoute } from '@/app/api/auth/session/route';
const jwt = (seconds: number, id = '') => String(Date.now() + seconds * 1000 + (id === 'new' ? 1 : 0));
const json = (body: unknown, status=200) => new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json'}});
const unauthorized = () => json({error:{code:'unauthenticated',message:'Expired'}},401);
const authorization = (init?: RequestInit) => new Headers(init?.headers).get('authorization');
beforeEach(() => clearToken());
afterEach(() => { clearToken(); vi.unstubAllGlobals(); });
it.each([429, 503])('propagates refresh backoff %s without discarding the token or sending an unauthenticated API request', async status => {
  const old = jwt(-1); setToken(old);
  const fetch = vi.fn().mockResolvedValue(json({error:{code:'rate_limited',message:'Try later',details:{retry_after:30}}},status));
  vi.stubGlobal('fetch',fetch);
  await expect(apiGet('/vehicles')).rejects.toMatchObject({status});
  expect(getToken()).toBe(old);
  expect(fetch).toHaveBeenCalledTimes(1);
});
it.each([429, 503])('preserves upstream status %s and Retry-After through login and session routes without clearing cookies', async status => {
  vi.stubGlobal('fetch',vi.fn().mockImplementation(async()=>new Response('{}', {status,headers:{'retry-after':'42'}})));
  const origin = {method:'POST',headers:new Headers({origin:'https://portal.test'}),nextUrl:new URL('https://portal.test')};
  const loginRequest = {...origin,json:async()=>({email:'test@example.com',password:'password'})} as Parameters<typeof loginRoute>[0];
  const sessionRequest = {...origin,cookies:{get:()=>({value:'refresh'})}} as unknown as Parameters<typeof sessionRoute>[0];
  for (const response of [await loginRoute(loginRequest), await sessionRoute(sessionRequest)]) {
    expect(response.status).toBe(status);
    expect(response.headers.get('retry-after')).toBe('42');
    expect(response.headers.get('set-cookie')).toBeNull();
    expect(response.headers.get('cache-control')).toBe('no-store');
  }
});
it('refreshes an expired idle-session token before the next API request',async()=>{
  setToken(jwt(-1)); const fresh=jwt(900);
  const fetch=vi.fn().mockResolvedValueOnce(json({authenticated:true})).mockResolvedValueOnce(json({ok:true})); vi.stubGlobal('fetch',fetch);
  expect(await apiGet('/vehicles')).toEqual({ok:true});
  expect(fetch.mock.calls[0][0]).toBe('/api/auth/session');
  expect(authorization(fetch.mock.calls[1][1])).toBeNull();
});
it('keeps a fresh token without rotating the session',async()=>{
  const fresh=jwt(900);setToken(fresh);const fetch=vi.fn().mockResolvedValue(json({ok:true}));vi.stubGlobal('fetch',fetch);
  await apiGet('/vehicles');expect(fetch).toHaveBeenCalledTimes(1);expect(authorization(fetch.mock.calls[0][1])).toBeNull();
});
it('forces refresh after a 401 even if the cached JWT has not expired, preserving a mutation body',async()=>{
  const old=jwt(900,'old'),fresh=jwt(900,'new');setToken(old);
  const fetch=vi.fn().mockResolvedValueOnce(unauthorized()).mockResolvedValueOnce(json({authenticated:true})).mockResolvedValueOnce(json({saved:true}));vi.stubGlobal('fetch',fetch);
  expect(await apiPost('/vehicles',{name:'Car'})).toEqual({saved:true});expect(fetch).toHaveBeenCalledTimes(3);
  expect(fetch.mock.calls[0][1].body).toBe(fetch.mock.calls[2][1].body);expect(authorization(fetch.mock.calls[2][1])).toBeNull();
});
it('shares one refresh across concurrent calls after idle expiry',async()=>{
  setToken(jwt(-1));const fresh=jwt(900);
  const fetch=vi.fn(async(path:string)=>path==='/api/auth/session'?json({authenticated:true}):json({ok:true}));vi.stubGlobal('fetch',fetch);
  await Promise.all([apiGet('/a'),apiGet('/b'),apiGet('/c')]);expect(fetch.mock.calls.filter(([p])=>p==='/api/auth/session')).toHaveLength(1);
});
it('does not rotate again for a late 401 from an already-replaced session', async () => {
  setToken(jwt(900, 'old'));
  let release!: (r: Response) => void;
  let refreshed = false;
  const fetch = vi.fn(async (path: string) => {
    if (path === '/api/auth/session') { refreshed = true; return json({ authenticated: true }); }
    if (!refreshed) {
      if (path.endsWith('/slow')) return new Promise<Response>(r => { release = r; });
      return unauthorized();
    }
    return json({ ok: true });
  });
  vi.stubGlobal('fetch', fetch);
  const slow = apiGet('/slow'); await apiGet('/fast'); release(unauthorized());
  expect(await slow).toEqual({ ok: true });
  expect(fetch.mock.calls.filter(([p]) => p === '/api/auth/session')).toHaveLength(1);
});
it('stops after one retry when the replacement token is also rejected',async()=>{
  setToken(jwt(900));const fetch=vi.fn().mockResolvedValueOnce(unauthorized()).mockResolvedValueOnce(json({authenticated:true})).mockResolvedValueOnce(unauthorized());vi.stubGlobal('fetch',fetch);
  await expect(apiGet('/vehicles')).rejects.toMatchObject({status:401});expect(fetch).toHaveBeenCalledTimes(3);
});
it('surfaces expired refresh sessions without a retry loop',async()=>{
  setToken(jwt(-1));const fetch=vi.fn().mockResolvedValue(unauthorized());vi.stubGlobal('fetch',fetch);
  await expect(apiGet('/vehicles')).rejects.toMatchObject({status:401});expect(fetch).toHaveBeenCalledTimes(2);expect(getToken()).toBeNull();
});
it('does not restore the memory token when sign-out happens during refresh',async()=>{
  let release!: (r:Response)=>void;vi.stubGlobal('fetch',vi.fn(()=>new Promise<Response>(r=>{release=r;})));
  const pending=ensureFreshToken();clearToken();release(json({authenticated:true}));expect(await pending).toBeNull();expect(getToken()).toBeNull();
});
it('refreshes raw upload/download requests while preserving multipart headers',async()=>{
  setToken(jwt(-1));const form=new FormData();form.append('file',new Blob(['a,b']), 'test.csv');
  const fetch=vi.fn().mockResolvedValueOnce(json({authenticated:true})).mockResolvedValueOnce(new Response('csv'));vi.stubGlobal('fetch',fetch);
  expect(await (await apiRequest('/export',{method:'POST',body:form})).text()).toBe('csv');
  expect(new Headers(fetch.mock.calls[1][1].headers).has('content-type')).toBe(false);
  expect(fetch.mock.calls[1][1].body).toBe(form);
});

it('rejects cross-origin login and never exposes bearer tokens in a successful response', async () => {
  const { NextRequest } = await import('next/server');
  const bad = new NextRequest('https://portal.test/api/auth/login', { method: 'POST', headers: { origin: 'https://evil.test' }, body: '{}' });
  expect((await loginRoute(bad)).status).toBe(403);
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(json({ user: { id: 'test', role: 'owner' }, access_token: 'secret-access', refresh_token: 'secret-refresh' })));
  const good = new NextRequest('https://portal.test/api/auth/login', { method: 'POST', headers: { origin: 'https://portal.test' }, body: JSON.stringify({ email: 'test@example.com', password: 'password' }) });
  const response = await loginRoute(good);
  expect(response.status).toBe(200);
  const body = await response.json();
  expect(body.authenticated).toBe(true);
  expect(body.access_token).toBeUndefined();
  expect(body.refresh_token).toBeUndefined();
  expect(response.headers.get('set-cookie')).toContain('HttpOnly');
});

it('proxies with the HttpOnly credential, preserving revisions and discarding client credentials', async () => {
  const { NextRequest } = await import('next/server');
  const { PATCH: proxy } = await import('@/app/api/proxy/[...path]/route');
  const cookieName = process.env.PORTAL === 'fleet-portal' ? 'dco_fleet_access' : 'dco_admin_access';
  const request = new NextRequest('https://portal.test/api/proxy/vehicles/123', {
    method: 'PATCH', headers: { origin: 'https://portal.test', cookie: `${cookieName}=real-secret`, authorization: 'Bearer injected', 'content-type': 'application/json', 'if-match': '4' }, body: JSON.stringify({ name: 'Car' }),
  });
  const fetch = vi.fn().mockResolvedValue(json({ saved: true })); vi.stubGlobal('fetch', fetch);
  const response = await proxy(request, { params: Promise.resolve({ path: ['vehicles', '123'] }) });
  expect(response.status).toBe(200);
  expect(authorization(fetch.mock.calls[0][1])).toBe('Bearer real-secret');
  expect(new Headers(fetch.mock.calls[0][1].headers).get('cookie')).toBeNull();
  expect(new Headers(fetch.mock.calls[0][1].headers).get('if-match')).toBe('4');
  expect(fetch.mock.calls[0][1].redirect).toBe('manual');
  expect(response.headers.get('cache-control')).toBe('no-store');
});
it('blocks CSRF, path traversal, credential endpoints and oversized proxy bodies', async () => {
  const { NextRequest } = await import('next/server');
  const { POST: proxy } = await import('@/app/api/proxy/[...path]/route');
  const cookieName = process.env.PORTAL === 'fleet-portal' ? 'dco_fleet_access' : 'dco_admin_access';
  const fetch = vi.fn(); vi.stubGlobal('fetch', fetch);
  for (const [path, origin, length, status] of [
    [['vehicles'], 'https://evil.test', '2', 403],
    [['..', 'auth'], 'https://portal.test', '2', 400],
    [['auth', 'login'], 'https://portal.test', '2', 400],
    [['vehicles'], 'https://portal.test', String(17 * 1024 * 1024), 413],
  ] as const) {
    const request = new NextRequest('https://portal.test/api/proxy/vehicles', { method: 'POST', headers: { origin, cookie: `${cookieName}=secret`, 'content-length': length }, body: '{}' });
    expect((await proxy(request, { params: Promise.resolve({ path: [...path] }) })).status).toBe(status);
  }
  expect(fetch).not.toHaveBeenCalled();
});

it.skipIf(process.env.PORTAL === 'fleet-portal')('preserves localhost origins without relaxing CSRF or production HTTPS', async () => {
  const { NextRequest } = await import('next/server');
  const { middleware } = await import('../../web/src/middleware');
  const { rejectCrossOrigin } = await import('../../web/src/lib/auth/request-origin');
  vi.stubEnv('NODE_ENV', 'development');
  try {
    for (const origin of ['http://localhost:3000', 'http://localhost:3100', 'http://127.0.0.1:3000', 'https://localhost:3000']) {
      const headers = { host: new URL(origin).host, origin };
      expect(middleware(new NextRequest(`${origin}/users`, { headers })).headers.get('location')).toBe(`${origin}/login`);
      expect(rejectCrossOrigin(new NextRequest(`${origin}/api/auth/login`, { method: 'POST', headers }))).toBeNull();
    }
    for (const origin of ['', 'http://localhost:3001', 'https://evil.test']) {
      const request = new NextRequest('http://localhost:3000/api/auth/login', { method: 'POST', headers: { host: 'localhost:3000', origin } });
      expect(rejectCrossOrigin(request)?.status).toBe(403);
    }
    expect(rejectCrossOrigin(new NextRequest('http://localhost:3000/api/auth/login', { method: 'POST', headers: { host: 'localhost:3000', origin: 'http://localhost:3000', 'sec-fetch-site': 'cross-site' } }))?.status).toBe(403);
    const localCsp = middleware(new NextRequest('http://localhost:3000/login', { headers: { host: 'localhost:3000' } })).headers.get('content-security-policy');
    expect(localCsp).not.toContain('upgrade-insecure-requests');
    expect(localCsp).toContain("frame-ancestors 'none'");

    vi.stubEnv('NODE_ENV', 'production');
    const headers = { host: 'internal:3000', 'x-forwarded-host': 'portal.test', 'x-forwarded-proto': 'https', origin: 'https://portal.test' };
    expect(middleware(new NextRequest('http://internal:3000/users', { headers })).headers.get('location')).toBe('https://portal.test/login');
    expect(rejectCrossOrigin(new NextRequest('http://internal:3000/api/auth/login', { method: 'POST', headers }))).toBeNull();
    expect(rejectCrossOrigin(new NextRequest('http://internal:3000/api/auth/login', { method: 'POST', headers: { ...headers, origin: 'http://portal.test' } }))?.status).toBe(403);
    const csp = middleware(new NextRequest('http://internal:3000/login', { headers })).headers.get('content-security-policy');
    expect(csp).toContain('upgrade-insecure-requests');
    expect(csp).not.toContain("'unsafe-eval'");
  } finally { vi.unstubAllEnvs(); }
});
