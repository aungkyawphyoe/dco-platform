import { AsyncLocalStorage } from 'node:async_hooks';
import { and, eq, isNull } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { users, vehicles } from '../db/schema.js';
import { effectiveSubscription } from './gifts.js';
import { AppError } from './errors.js';
export const billingRequest = new AsyncLocalStorage<{
    write: boolean;
}>();
export async function assertPersonalVehicleWritable(db: Db, vehicleId: string) {
    if (!billingRequest.getStore()?.write)
        return;
    const [v] = await db.select().from(vehicles).where(eq(vehicles.id, vehicleId));
    if (!v)
        return;
    const sub = await effectiveSubscription(db, v.userId);
    if (!sub.user.billingManaged || sub.plan !== 'free')
        return;
    if (sub.user.freeVehicleId === vehicleId)
        return;
    if (!sub.user.freeVehicleId) {
        const owned = await db.select({ id: vehicles.id }).from(vehicles).where(and(eq(vehicles.userId, v.userId), eq(vehicles.archived, false)));
        if (owned.length === 1 && owned[0].id === vehicleId) {
            const updated = await db.update(users).set({ freeVehicleId: vehicleId }).where(and(eq(users.id, v.userId), eq(users.billingManaged, true), isNull(users.freeVehicleId))).returning();
            if (updated.length)
                return;
        }
    }
    throw new AppError(403, 'vehicle_read_only', 'Select your one editable Free vehicle in Plans & subscriptions. Other vehicles remain read-only.');
}
