import { afterEach, beforeEach, expect, it, vi } from 'vitest';
// Run this contract against each portal's real client and token store:
// PORTAL=web npm exec -- vitest run --config portal-auth.config.ts
// PORTAL=fleet-portal npm exec -- vitest run --config portal-auth.config.ts
import { apiGet, apiPost, apiRequest } from '@/lib/api/client';
import { clearToken, ensureFreshToken, getToken, setToken } from '@/lib/auth/token-store';
import { POST as loginRoute } from '@/app/api/auth/login/route';
import { POST as sessionRoute } from '@/app/api/auth/session/route';
const jwt = (seconds: number, id = '') => `header.${Buffer.from(JSON.stringify({ exp: Math.floor(Date.now()/1000)+seconds, id })).toString('base64url')}.signature`;
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
  const loginRequest = {json:async()=>({email:'test@example.com',password:'password'})} as Parameters<typeof loginRoute>[0];
  const sessionRequest = {cookies:{get:()=>({value:'refresh'})}} as unknown as Parameters<typeof sessionRoute>[0];
  for (const response of [await loginRoute(loginRequest), await sessionRoute(sessionRequest)]) {
    expect(response.status).toBe(status);
    expect(response.headers.get('retry-after')).toBe('42');
    expect(response.headers.get('set-cookie')).toBeNull();
    expect(response.headers.get('cache-control')).toBe('no-store');
  }
});
it('refreshes an expired idle-session token before the next API request',async()=>{
  setToken(jwt(-1)); const fresh=jwt(900);
  const fetch=vi.fn().mockResolvedValueOnce(json({access_token:fresh})).mockResolvedValueOnce(json({ok:true})); vi.stubGlobal('fetch',fetch);
  expect(await apiGet('/vehicles')).toEqual({ok:true});
  expect(fetch.mock.calls[0][0]).toBe('/api/auth/session');
  expect(authorization(fetch.mock.calls[1][1])).toBe(`Bearer ${fresh}`);
});
it('keeps a fresh token without rotating the session',async()=>{
  const fresh=jwt(900);setToken(fresh);const fetch=vi.fn().mockResolvedValue(json({ok:true}));vi.stubGlobal('fetch',fetch);
  await apiGet('/vehicles');expect(fetch).toHaveBeenCalledTimes(1);expect(authorization(fetch.mock.calls[0][1])).toBe(`Bearer ${fresh}`);
});
it('forces refresh after a 401 even if the cached JWT has not expired, preserving a mutation body',async()=>{
  const old=jwt(900,'old'),fresh=jwt(900,'new');setToken(old);
  const fetch=vi.fn().mockResolvedValueOnce(unauthorized()).mockResolvedValueOnce(json({access_token:fresh})).mockResolvedValueOnce(json({saved:true}));vi.stubGlobal('fetch',fetch);
  expect(await apiPost('/vehicles',{name:'Car'})).toEqual({saved:true});expect(fetch).toHaveBeenCalledTimes(3);
  expect(fetch.mock.calls[0][1].body).toBe(fetch.mock.calls[2][1].body);expect(authorization(fetch.mock.calls[2][1])).toBe(`Bearer ${fresh}`);
});
it('shares one refresh across concurrent calls after idle expiry',async()=>{
  setToken(jwt(-1));const fresh=jwt(900);
  const fetch=vi.fn(async(path:string)=>path==='/api/auth/session'?json({access_token:fresh}):json({ok:true}));vi.stubGlobal('fetch',fetch);
  await Promise.all([apiGet('/a'),apiGet('/b'),apiGet('/c')]);expect(fetch.mock.calls.filter(([p])=>p==='/api/auth/session')).toHaveLength(1);
});
it('does not rotate again for a late 401 from the already-replaced token',async()=>{
  const old=jwt(900,'old'),fresh=jwt(900,'new');setToken(old);
  let release!: (r:Response)=>void;
  const fetch=vi.fn(async(path:string,init?:RequestInit)=>{
    if(path==='/api/auth/session') return json({access_token:fresh});
    if(authorization(init)===`Bearer ${old}`){if(path.endsWith('/slow'))return new Promise<Response>(r=>{release=r;});return unauthorized();}
    return json({ok:true});
  });vi.stubGlobal('fetch',fetch);
  const slow=apiGet('/slow');await apiGet('/fast');release(unauthorized());expect(await slow).toEqual({ok:true});
  expect(fetch.mock.calls.filter(([p])=>p==='/api/auth/session')).toHaveLength(1);
});
it('stops after one retry when the replacement token is also rejected',async()=>{
  setToken(jwt(900));const fetch=vi.fn().mockResolvedValueOnce(unauthorized()).mockResolvedValueOnce(json({access_token:jwt(900,'new')})).mockResolvedValueOnce(unauthorized());vi.stubGlobal('fetch',fetch);
  await expect(apiGet('/vehicles')).rejects.toMatchObject({status:401});expect(fetch).toHaveBeenCalledTimes(3);
});
it('surfaces expired refresh sessions without a retry loop',async()=>{
  setToken(jwt(-1));const fetch=vi.fn().mockResolvedValue(unauthorized());vi.stubGlobal('fetch',fetch);
  await expect(apiGet('/vehicles')).rejects.toMatchObject({status:401});expect(fetch).toHaveBeenCalledTimes(2);expect(getToken()).toBeNull();
});
it('does not restore the memory token when sign-out happens during refresh',async()=>{
  let release!: (r:Response)=>void;vi.stubGlobal('fetch',vi.fn(()=>new Promise<Response>(r=>{release=r;})));
  const pending=ensureFreshToken();clearToken();release(json({access_token:jwt(900)}));expect(await pending).toBeNull();expect(getToken()).toBeNull();
});
it('refreshes raw upload/download requests while preserving multipart headers',async()=>{
  setToken(jwt(-1));const form=new FormData();form.append('file',new Blob(['a,b']), 'test.csv');
  const fetch=vi.fn().mockResolvedValueOnce(json({access_token:jwt(900)})).mockResolvedValueOnce(new Response('csv'));vi.stubGlobal('fetch',fetch);
  expect(await (await apiRequest('/export',{method:'POST',body:form})).text()).toBe('csv');
  expect(new Headers(fetch.mock.calls[1][1].headers).has('content-type')).toBe(false);
  expect(fetch.mock.calls[1][1].body).toBe(form);
});
