import { expect, it } from 'vitest';
import { DEFAULT_FUEL_TYPES, defaultFuelTypeId } from '../src/lib/catalog.js';
import { createTestApp, uuid } from './helpers.js';

it('shares stable default IDs with the offline mobile catalog', () => {
  expect(DEFAULT_FUEL_TYPES).toHaveLength(8);
  expect(defaultFuelTypeId('10000000-0000-0000-0000-000000000001', 'Electric (Fast)'))
    .toBe('30414785-9519-5e35-8ad8-671d7375fce3');
});

it('accepts offline-seeded defaults with the same IDs and round-trips battery level', async () => {
  const { app } = await createTestApp();
  try {
    const signup = await app.inject({method:'POST',url:'/v1/auth/signup',payload:{email:`fuel-${uuid()}@test.local`,password:'password1'}});
    const { user, access_token } = signup.json();
    const headers = {authorization:`Bearer ${access_token}`};
    const operations = DEFAULT_FUEL_TYPES.map(type => ({entity_type:'fuel_type',entity_id:defaultFuelTypeId(user.id,type.name),op:'upsert',payload:type,client_ts:new Date().toISOString()}));
    const push = await app.inject({method:'POST',url:'/v1/sync/push',headers,payload:{operations}});
    expect(push.json().results.every((result: {status:string}) => result.status === 'applied')).toBe(true);
    const vehicleId = uuid();
    const vehicle = await app.inject({method:'POST',url:'/v1/vehicles',headers,payload:{id:vehicleId,name:'EV',make:'Tesla',model:'3',year:2024,license_plate:vehicleId.slice(0,8),fuel_type:'electric',mileage:100}});
    expect(vehicle.statusCode).toBe(201);
    const body = {id:uuid(),fuel_type_id:defaultFuelTypeId(user.id,'Electric (Fast)'),logged_on:'2026-01-01',amount:10,cost:7500,currency:'MMK',odometer:101,battery_level:85,battery_level_before:33};
    const created = await app.inject({method:'POST',url:`/v1/vehicles/${vehicleId}/fuel-logs`,headers,payload:body});
    expect(created.statusCode, created.body).toBe(201);
    expect(created.json()).toMatchObject({battery_level:85,battery_level_before:33});
    const inverted = await app.inject({method:'PATCH',url:`/v1/fuel-logs/${body.id}`,headers,payload:{battery_level:32}});
    expect(inverted.statusCode).toBe(422);
    const invalid = await app.inject({method:'PATCH',url:`/v1/fuel-logs/${body.id}`,headers,payload:{battery_level:101}});
    expect(invalid.statusCode).toBe(422);
    const updated = await app.inject({method:'PATCH',url:`/v1/fuel-logs/${body.id}`,headers,payload:{battery_level:95}});
    expect(updated.json()).toMatchObject({battery_level:95,battery_level_before:33});
  } finally { await app.close(); }
});
