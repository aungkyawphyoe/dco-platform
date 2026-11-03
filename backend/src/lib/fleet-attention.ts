export type AttentionItem = {
  id: string; vehicle_id: string; vehicle: string; plate: string;
  group: 'urgent' | 'overdue' | 'stalled' | 'review' | 'upcoming';
  title: string; detail: string; href: string;
};

export function maintenanceState(today: string, due: string | null, remainingKm: number | null) {
  if ((due !== null && due <= today) || (remainingKm !== null && remainingKm <= 0)) return 'overdue';
  const soon = new Date(`${today}T00:00:00Z`);
  soon.setUTCDate(soon.getUTCDate() + 30);
  if ((due !== null && due <= soon.toISOString().slice(0, 10)) || (remainingKm !== null && remainingKm <= 500)) return 'upcoming';
  return null;
}

export function workOrderStalled(now: Date, updatedAt: Date, promisedDate: string | null = null, today = now.toISOString().slice(0, 10)) {
  return promisedDate !== null ? promisedDate < today : now.getTime() - updatedAt.getTime() >= 3 * 86400000;
}
