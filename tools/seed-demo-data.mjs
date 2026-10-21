#!/usr/bin/env node
/**
 * Demo data seeder for the two screenshot accounts.
 *
 *   Personal garage  → customer1@example.com / password123  (mobile app screenshots)
 *   Fleet workspace  → acmemotors@gmail.com  / password123  (fleet portal screenshots)
 *
 * Everything is written through the public REST API (no DB access needed), so it
 * works against any environment. Rows use deterministic ids derived from stable
 * keys and every write is guarded by an existence check — re-running is safe and
 * only fills what is missing.
 *
 *   node tools/seed-demo-data.mjs                       # seed both accounts
 *   node tools/seed-demo-data.mjs --only customer
 *   node tools/seed-demo-data.mjs --only fleet
 *   node tools/seed-demo-data.mjs --base http://localhost:8080/v1
 */
import { createHash } from "node:crypto";

const argv = process.argv.slice(2);
const arg = (name, fallback) => {
  const index = argv.indexOf(`--${name}`);
  return index >= 0 && argv[index + 1] && !argv[index + 1].startsWith("--") ? argv[index + 1] : fallback;
};

const BASE = arg("base", process.env.API_BASE ?? "https://api.autoxmm.com/v1");
const ONLY = arg("only", "both");
const PASSWORD = arg("password", "password123");
const CUSTOMER_EMAIL = arg("customer", "customer1@example.com");
const FLEET_EMAIL = arg("fleet", "acmemotors@gmail.com");

const ORG = "97e4e37e-acc8-4c79-b5cc-befc40a66d3a"; // ACME Motors
const TODAY = new Date().toISOString().slice(0, 10);

let calls = 0;
const failures = [];

function detId(key) {
  const hex = createHash("md5").update(`autox-demo:${key}`).digest("hex");
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    `5${hex.slice(13, 16)}`,
    `8${hex.slice(17, 20)}`,
    hex.slice(20, 32),
  ].join("-");
}

async function api(method, path, { token, body, form } = {}) {
  calls += 1;
  const headers = {};
  if (token) headers.authorization = `Bearer ${token}`;
  let payload;
  if (form) {
    payload = form;
  } else if (body !== undefined) {
    headers["content-type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const response = await fetch(BASE + path, { method, headers, body: payload });
  const text = await response.text();
  let json = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = { raw: text.slice(0, 300) };
    }
  }
  return { status: response.status, json };
}

async function login(email, surface = "owner", password = PASSWORD) {
  const { status, json } = await api("POST", "/auth/login", {
    body: { email, password, surface },
  });
  if (status !== 200) throw new Error(`login ${email} (${surface}) → ${status} ${JSON.stringify(json)}`);
  return json.access_token;
}

function fail(scope, what, result) {
  const detail = JSON.stringify(result.json).slice(0, 220);
  failures.push(`[${scope}] ${what} → ${result.status} ${detail}`);
  console.log(`   ✗ ${what} → ${result.status} ${detail}`);
}

function ok(result, statuses = [200, 201, 204]) {
  return statuses.includes(result.status);
}

async function ensure(method, path, body, what, scope, token, statuses) {
  const result = await api(method, path, { token, body });
  if (!ok(result, statuses)) {
    fail(scope, what, result);
    return null;
  }
  return result.json;
}

// ── Personal garage (customer1@example.com) ────────────────────────────────

const CUSTOMER_VEHICLES = [
  {
    key: "swift",
    id: "47bcbc6c-ba34-4f9f-be08-9136b7299708", // existing
    spec: null,
    fuel: "Petrol",
    plan: [
      { key: "oil_change", name: "Oil Change", interval_days: 365, interval_distance: 10000, next_due_on: "2026-10-10", next_due_mileage: 74000, notes: "Synthetic 5W-30, OEM filter" },
      { key: "rotate_tires", name: "Rotate Tires", interval_days: 365, interval_distance: 8000, next_due_on: "2026-10-28", next_due_mileage: 83000, notes: null },
      { key: "air_filter_cabin", name: "Air Filter (Cabin)", interval_days: 365, interval_distance: 24000, next_due_on: "2026-11-20", next_due_mileage: 86000, notes: null },
      { key: "brake_fluid", name: "Brake Fluid", interval_days: 730, interval_distance: 50000, next_due_on: "2027-04-15", next_due_mileage: 110000, notes: null },
      { key: "new_tires", name: "New Tires", interval_days: 1825, interval_distance: 80000, next_due_on: "2028-06-01", next_due_mileage: 150000, notes: null },
    ],
    fuelLogs: [
      { d: "2026-02-08", odo: 74610, amount: 34.2, cost: 86500, fill: "full" },
      { d: "2026-03-14", odo: 76040, amount: 35.8, cost: 90400, fill: "partial" },
      { d: "2026-04-22", odo: 77520, amount: 33.5, cost: 84600, fill: "full" },
      { d: "2026-06-05", odo: 79010, amount: 36.1, cost: 91100, fill: "full" },
      { d: "2026-07-18", odo: 80480, amount: 34.9, cost: 88000, fill: "partial" },
      { d: "2026-09-02", odo: 81750, amount: 35.4, cost: 89300, fill: "full" },
      { d: "2026-10-12", odo: 82450, amount: 31.2, cost: 78700, fill: "full" },
    ],
    services: [
      { key: "swift-svc-1", d: "2026-01-24", odo: 74600, cost: 165000, shop: "City Auto Service", notes: "Full synthetic oil, OEM filter", items: [["Oil & filter change", 95000], ["Air filter", 70000]] },
      { key: "swift-svc-2", d: "2026-05-09", odo: 78950, cost: 420000, shop: "City Auto Service", notes: "Front axle brake job", items: [["Front brake pads", 260000], ["Brake disc skim", 160000]] },
      { key: "swift-svc-3", d: "2026-08-16", odo: 81200, cost: 145000, shop: "SM Auto Garage", notes: null, items: [["Wheel rotation & alignment", 65000], ["Cabin filter", 80000]] },
      { key: "swift-svc-4", d: "2026-10-05", odo: 82300, cost: 520000, shop: "City Auto Service", notes: "90,000 km major service", items: [["Major service", 380000], ["Battery test & terminals", 140000]] },
    ],
    expenses: [
      ["insurance", 890000, "2026-01-15", "Annual comprehensive — NGF Insurance"],
      ["parking", 3500, "2026-02-03", "City Mall underground parking"],
      ["tolls", 6000, "2026-03-21", "Yangon–Bago expressway tolls"],
      ["maintenance", 420000, "2026-05-09", "Brake job — City Auto Service"],
      ["fuel", 88500, "2026-06-14", "Shell Pyay Road — 38 L"],
      ["parking", 2500, "2026-07-02", "Airport short stay"],
      ["maintenance", 145000, "2026-08-16", "Alignment + cabin filter"],
      ["parts", 260000, "2026-09-06", "Wiper blades + bulbs"],
      ["fuel", 92000, "2026-10-04", "Total station — 40 L"],
      ["parking", 4000, "2026-10-11", "MegaCity parking"],
    ],
    documents: [
      ["Vehicle insurance policy 2026", "insurance", "2027-01-31", "Comprehensive, NGF Insurance"],
      ["Registration book (grey book)", "registration", null, "Original stored at home"],
      ["Purchase invoice", "invoice", null, "Auto Link Motors"],
      ["Service warranty card", "warranty", "2027-08-16", "12 months from last major service"],
    ],
  },
  {
    key: "b10",
    id: "ef785515-b5ba-4900-ab65-efb7f8b1358a", // existing
    spec: null,
    fuel: "Electricity",
    plan: [
      { key: "rotate_tires", name: "Rotate Tires", interval_days: 365, interval_distance: 8000, next_due_on: "2026-10-24", next_due_mileage: 73000, notes: null },
      { key: "wash", name: "Wash", interval_days: 14, interval_distance: null, next_due_on: "2026-10-26", next_due_mileage: null, notes: null },
      { key: "air_filter_cabin", name: "Air Filter (Cabin)", interval_days: 365, interval_distance: 24000, next_due_on: "2026-12-05", next_due_mileage: 78000, notes: null },
      { key: "brake_fluid", name: "Brake Fluid", interval_days: 730, interval_distance: 50000, next_due_on: "2027-07-01", next_due_mileage: 110000, notes: null },
      { key: "new_tires", name: "New Tires", interval_days: 1825, interval_distance: 80000, next_due_on: "2029-01-15", next_due_mileage: 145000, notes: null },
    ],
    fuelLogs: [
      { d: "2026-02-11", odo: 63620, amount: 42.5, cost: 24800 },
      { d: "2026-03-19", odo: 65240, amount: 38.2, cost: 22300 },
      { d: "2026-04-27", odo: 66900, amount: 45.0, cost: 26300 },
      { d: "2026-06-16", odo: 68450, amount: 40.6, cost: 23700 },
      { d: "2026-08-05", odo: 70100, amount: 43.8, cost: 25600 },
      { d: "2026-09-25", odo: 71550, amount: 39.4, cost: 23000 },
      { d: "2026-10-15", odo: 72300, amount: 35.1, cost: 20500 },
    ],
    services: [
      { key: "b10-svc-1", d: "2026-03-02", odo: 65200, cost: 180000, shop: "Leap Service Center", notes: "First scheduled check", items: [["Tyre rotation", 60000], ["Cabin filter", 120000]] },
      { key: "b10-svc-2", d: "2026-07-12", odo: 69300, cost: 240000, shop: "Leap Service Center", notes: null, items: [["Brake fluid replacement", 140000], ["Wheel alignment", 100000]] },
      { key: "b10-svc-3", d: "2026-10-01", odo: 72150, cost: 96000, shop: "Leap Service Center", notes: "Battery health 96%", items: [["Battery health check", 96000]] },
    ],
    expenses: [
      ["insurance", 960000, "2026-01-08", "Annual comprehensive — Grant Insurance"],
      ["fuel", 24800, "2026-02-11", "DC fast charge — 42.5 kWh"],
      ["maintenance", 180000, "2026-03-02", "Leap service — tyres + filter"],
      ["parking", 5000, "2026-04-19", "MegaCity EV bay"],
      ["fuel", 23700, "2026-06-16", "Office charger — 40.6 kWh"],
      ["fuel", 25600, "2026-08-05", "ABC charging hub"],
      ["tolls", 6000, "2026-09-12", "Expressway tolls"],
      ["parking", 3500, "2026-10-06", "City Mall"],
      ["fuel", 20500, "2026-10-15", "Home wallbox — 35.1 kWh"],
    ],
    documents: [
      ["Battery warranty (8 years)", "warranty", "2033-05-20", "8 years / 160,000 km"],
      ["Insurance policy 2026", "insurance", "2026-12-31", "Renewal due in December"],
      ["EV charging agreement", "other", null, "Home wallbox plan"],
    ],
  },
  {
    key: "cx5",
    id: detId("vehicle:customer:cx5"),
    spec: {
      id: detId("vehicle:customer:cx5"),
      name: "CX-5",
      nickname: "Weekend car",
      make: "Mazda",
      model: "CX-5 Maxx",
      year: 2021,
      license_plate: "YGN-21 MX-7788",
      vin: detId("vin:customer:cx5").replaceAll("-", "").slice(0, 17).toUpperCase(),
      color: "Soul Red Crystal",
      fuel_type: "petrol",
      mileage: 41200,
      mileage_unit: "km",
      purchase_date: "2023-06-14",
      purchase_price: 82000000,
    },
    fuel: "Petrol",
    plan: [
      { key: "oil_change", name: "Oil Change", interval_days: 365, interval_distance: 10000, next_due_on: "2026-10-18", next_due_mileage: 49000, notes: null },
      { key: "rotate_tires", name: "Rotate Tires", interval_days: 365, interval_distance: 8000, next_due_on: "2026-11-15", next_due_mileage: 54000, notes: null },
      { key: "air_filter_cabin", name: "Air Filter (Cabin)", interval_days: 365, interval_distance: 24000, next_due_on: "2027-01-10", next_due_mileage: 60000, notes: null },
      { key: "brake_change", name: "Brake Change", interval_days: null, interval_distance: 60000, next_due_on: "2027-05-01", next_due_mileage: 100000, notes: null },
      { key: "new_tires", name: "New Tires", interval_days: 1825, interval_distance: 80000, next_due_on: "2028-06-30", next_due_mileage: 120000, notes: null },
    ],
    fuelLogs: [
      { d: "2026-02-14", odo: 41350, amount: 48.2, cost: 118000, fill: "full" },
      { d: "2026-03-28", odo: 43100, amount: 52.4, cost: 128500, fill: "full" },
      { d: "2026-05-10", odo: 44800, amount: 47.6, cost: 116500, fill: "partial" },
      { d: "2026-06-29", odo: 46500, amount: 50.1, cost: 122700, fill: "full" },
      { d: "2026-08-24", odo: 48200, amount: 49.3, cost: 120800, fill: "full" },
      { d: "2026-10-08", odo: 49750, amount: 46.8, cost: 114600, fill: "partial" },
    ],
    services: [
      { key: "cx5-svc-1", d: "2026-01-30", odo: 41300, cost: 210000, shop: "Mazda Service Yangon", notes: null, items: [["Oil & filter change", 120000], ["Tyre rotation", 90000]] },
      { key: "cx5-svc-2", d: "2026-07-05", odo: 46600, cost: 200000, shop: "Mazda Service Yangon", notes: null, items: [["Brake fluid change", 140000], ["Battery test", 60000]] },
      { key: "cx5-svc-3", d: "2026-10-05", odo: 49700, cost: 480000, shop: "Mazda Service Yangon", notes: "40,000 km service", items: [["Oil, plugs & filters", 320000], ["AC service", 160000]] },
    ],
    expenses: [
      ["insurance", 920000, "2026-01-12", "Annual comprehensive"],
      ["fuel", 118000, "2026-02-14", "Total station — 48 L"],
      ["parking", 4500, "2026-03-30", "City Mall"],
      ["tolls", 7500, "2026-05-10", "Expressway tolls"],
      ["maintenance", 200000, "2026-07-05", "Brake fluid + battery"],
      ["fuel", 120800, "2026-08-24", "Shell — 49 L"],
      ["parts", 175000, "2026-09-18", "Front parking sensors"],
      ["fuel", 114600, "2026-10-08", "Caltex — 47 L"],
      ["parking", 3000, "2026-10-16", "Underground parking"],
    ],
    documents: [
      ["Insurance policy (expiring)", "insurance", "2026-11-30", "Renew before 30 Nov"],
      ["Registration book", "registration", null, null],
      ["Warranty booklet", "warranty", "2026-12-31", "Manufacturer warranty ends"],
    ],
  },
  {
    key: "prius",
    id: detId("vehicle:customer:prius"),
    spec: {
      id: detId("vehicle:customer:prius"),
      name: "Prius",
      nickname: "Hybrid runabout",
      make: "Toyota",
      model: "Prius S-Touring",
      year: 2018,
      license_plate: "YGN-18 PR-4455",
      vin: detId("vin:customer:prius").replaceAll("-", "").slice(0, 17).toUpperCase(),
      color: "White Pearl",
      fuel_type: "hybrid_plugin",
      mileage: 96400,
      mileage_unit: "km",
      purchase_date: "2021-11-03",
      purchase_price: 46000000,
    },
    fuel: "Petrol",
    plan: [
      { key: "oil_change", name: "Oil Change", interval_days: 365, interval_distance: 10000, next_due_on: "2026-11-05", next_due_mileage: 110000, notes: null },
      { key: "rotate_tires", name: "Rotate Tires", interval_days: 365, interval_distance: 8000, next_due_on: "2026-10-30", next_due_mileage: 108000, notes: null },
      { key: "air_filter_cabin", name: "Air Filter (Cabin)", interval_days: 365, interval_distance: 24000, next_due_on: "2027-03-20", next_due_mileage: 122000, notes: null },
      { key: "brake_change", name: "Brake Change", interval_days: null, interval_distance: 60000, next_due_on: "2027-02-01", next_due_mileage: 145000, notes: null },
      { key: "new_tires", name: "New Tires", interval_days: 1825, interval_distance: 80000, next_due_on: "2028-09-01", next_due_mileage: 170000, notes: null },
    ],
    fuelLogs: [
      { d: "2026-02-20", odo: 96520, amount: 40.1, cost: 99000, fill: "full" },
      { d: "2026-04-04", odo: 98600, amount: 42.3, cost: 104500, fill: "full" },
      { d: "2026-05-21", odo: 100700, amount: 39.8, cost: 98500, fill: "partial" },
      { d: "2026-07-14", odo: 102800, amount: 41.5, cost: 102600, fill: "full" },
      { d: "2026-09-01", odo: 104900, amount: 40.7, cost: 100700, fill: "full" },
      { d: "2026-10-13", odo: 106200, amount: 38.9, cost: 96200, fill: "partial" },
    ],
    services: [
      { key: "prius-svc-1", d: "2026-03-15", odo: 97900, cost: 155000, shop: "Toyota Repair House", notes: null, items: [["Oil change", 85000], ["Hybrid battery diagnostic", 70000]] },
      { key: "prius-svc-2", d: "2026-08-02", odo: 103900, cost: 390000, shop: "Toyota Repair House", notes: "Front axle work", items: [["Front brake pads", 250000], ["Coolant flush", 140000]] },
    ],
    expenses: [
      ["insurance", 870000, "2026-02-01", "Annual comprehensive"],
      ["fuel", 99000, "2026-02-20", "Caltex — 40 L"],
      ["maintenance", 155000, "2026-03-15", "Oil + hybrid diagnostic"],
      ["parking", 2000, "2026-04-11", "Street parking"],
      ["tolls", 5500, "2026-06-08", "Expressway tolls"],
      ["fuel", 102600, "2026-07-14", "Shell — 41 L"],
      ["maintenance", 390000, "2026-08-02", "Brake pads + coolant"],
      ["other", 45000, "2026-09-20", "Dash camera memory card + install"],
      ["fuel", 96200, "2026-10-13", "Total — 39 L"],
      ["parking", 3500, "2026-10-17", "MegaCity parking"],
    ],
    documents: [
      ["Insurance policy 2026", "insurance", "2027-02-01", "Comprehensive"],
      ["Registration book", "registration", null, null],
      ["Hybrid battery certificate", "warranty", "2029-11-03", "8-year hybrid battery cover"],
    ],
  },
];

async function seedCustomer() {
  console.log(`\n── Personal garage · ${CUSTOMER_EMAIL} ──`);
  const token = await login(CUSTOMER_EMAIL);

  const fuelTypes = (await api("GET", "/fuel-types", { token })).json?.items ?? [];
  const fuelTypeId = (name) => {
    const row = fuelTypes.find((item) => item.name.toLowerCase() === name.toLowerCase());
    return row?.id ?? null;
  };

  for (const vehicle of CUSTOMER_VEHICLES) {
    const scope = vehicle.key;
    let vehicleId = vehicle.id;
    if (vehicle.spec) {
      const created = await ensure("POST", "/vehicles", vehicle.spec, `vehicle ${vehicle.spec.name}`, scope, token);
      if (created?.id) vehicleId = created.id;
      else if (!created) continue;
    }

    const petrol = fuelTypeId(vehicle.fuel);
    if (!petrol) {
      failures.push(`[${scope}] fuel type "${vehicle.fuel}" missing for account`);
      continue;
    }

    // Odometer-bearing rows must be written in ascending order (the API rejects
    // regressions and bumps the vehicle mileage as it goes).
    const timeline = [
      ...vehicle.fuelLogs.map((row) => ({ type: "fuel", ...row })),
      ...vehicle.services.map((row) => ({ type: "service", ...row })),
    ].sort((a, b) => a.odo - b.odo);

    for (const entry of timeline) {
      if (entry.type === "fuel") {
        await ensure(
          "POST",
          `/vehicles/${vehicleId}/fuel-logs`,
          {
            id: detId(`fuel:${vehicle.key}:${entry.d}:${entry.odo}`),
            fuel_type_id: petrol,
            logged_on: entry.d,
            amount: entry.amount,
            cost: entry.cost,
            fill_status: entry.fill ?? "full",
            odometer: entry.odo,
          },
          `fuel ${entry.d} @${entry.odo}`,
          scope,
          token,
        );
      } else {
        await ensure(
          "POST",
          `/vehicles/${vehicleId}/service-records`,
          {
            id: detId(`service:${vehicle.key}:${entry.key}`),
            serviced_on: entry.d,
            odometer: entry.odo,
            total_cost: entry.cost,
            workshop_name: entry.shop,
            notes: entry.notes,
            items: entry.items.map(([name, line_cost]) => ({ name, line_cost })),
          },
          `service ${entry.d} @${entry.odo}`,
          scope,
          token,
        );
      }
    }

    for (const item of vehicle.plan) {
      await ensure(
        "POST",
        `/vehicles/${vehicleId}/plan-items`,
        {
          id: detId(`plan:${vehicle.key}:${item.key}`),
          name: item.name,
          interval_days: item.interval_days,
          interval_distance: item.interval_distance,
          next_due_on: item.next_due_on,
          next_due_mileage: item.next_due_mileage,
          notes: item.notes,
          catalog_key: item.key,
          enabled: true,
        },
        `plan ${item.name}`,
        scope,
        token,
      );
    }

    for (const [category, amount, incurred_on, notes] of vehicle.expenses) {
      if (incurred_on > TODAY) continue;
      await ensure(
        "POST",
        `/vehicles/${vehicleId}/expenses`,
        { id: detId(`expense:${vehicle.key}:${category}:${incurred_on}:${amount}`), category, amount, incurred_on, notes },
        `expense ${category} ${incurred_on}`,
        scope,
        token,
      );
    }

    for (const [name, category, expires_on, notes] of vehicle.documents) {
      await ensure(
        "POST",
        `/vehicles/${vehicleId}/documents`,
        { id: detId(`doc:${vehicle.key}:${name}`), name, category, expires_on, notes },
        `document ${name}`,
        scope,
        token,
      );
    }
    console.log(` ✓ ${vehicle.key} (${vehicleId})`);
  }

  const vehicles = await api("GET", "/vehicles", { token });
  console.log(` → ${(vehicles.json?.items ?? []).length} vehicles in the garage`);
}

// ── Fleet workspace (acmemotors@gmail.com / ACME Motors) ───────────────────

const FLEET_VEHICLES = [
  { key: "aqua", id: detId("fleet:vehicle:aqua"), name: "Toyota Aqua", make: "Toyota", model: "Aqua G", year: 2014, plate: "YGN-14 AQ-2201", vin: "JTDKN3DU5A0410021", fuel: "petrol", mileage: 118400, lifecycle: "showroom", target: "inventory", label: "Showroom floor A3" },
  { key: "fit", id: detId("fleet:vehicle:fit"), name: "Honda Fit", make: "Honda", model: "Fit Hybrid", year: 2013, plate: "YGN-13 HF-3312", vin: "JHGE8185000120331", fuel: "petrol", mileage: 142750, lifecycle: "showroom", target: "listed", label: "Listed online · MMK 24.5M" },
  { key: "vitz", id: detId("fleet:vehicle:vitz"), name: "Toyota Vitz", make: "Toyota", model: "Vitz F", year: 2017, plate: "YGN-17 VZ-4423", vin: "NMTK3DX3J70440442", fuel: "petrol", mileage: 96300, lifecycle: "showroom", target: "sold", label: "Sold · 14 Oct 2026" },
  { key: "xtrail", id: detId("fleet:vehicle:xtrail"), name: "Nissan X-Trail", make: "Nissan", model: "X-Trail 2.0", year: 2016, plate: "YGN-16 XT-5534", vin: "JN8TBNT51Z0055534", fuel: "petrol", mileage: 88200, lifecycle: "showroom", target: "listed", label: "Listed online · MMK 38M" },
  { key: "wagonr", id: detId("fleet:vehicle:wagonr"), name: "Suzuki Wagon R", make: "Suzuki", model: "Wagon R Stingray", year: 2018, plate: "YGN-18 WR-6645", vin: "MHGS2211000666450", fuel: "petrol", mileage: 76500, lifecycle: "taxi_fleet", target: "available", label: "Daily hire · MMK 45,000/day" },
  { key: "demio", id: detId("fleet:vehicle:demio"), name: "Mazda Demio", make: "Mazda", model: "Demio XD", year: 2015, plate: "YGN-15 DM-7756", vin: "JMZDE121500177756", fuel: "petrol", mileage: 131900, lifecycle: "taxi_fleet", target: "leased", label: "Leased · 12 months" },
  { key: "axio", id: detId("fleet:vehicle:axio"), name: "Toyota Corolla Axio", make: "Toyota", model: "Axio 1.5X", year: 2013, plate: "YGN-13 CA-8867", vin: "NTEKN3J2700888670", fuel: "petrol", mileage: 154300, lifecycle: "taxi_fleet", target: "available", label: "Daily hire · MMK 55,000/day" },
  { key: "h1", id: detId("fleet:vehicle:h1"), name: "Hyundai H-1", make: "Hyundai", model: "H-1 Travel", year: 2015, plate: "YGN-15 H1-9978", vin: "KMHFC117FF0099781", fuel: "petrol", mileage: 167800, lifecycle: "taxi_fleet", target: "maintenance", label: "Shuttle contract" },
];

const MEMBERS = [
  { key: "manager", email: "kaung.myint@acmemotors.demo", role: "org_manager", password: "DemoManager123!" },
  { key: "mechanic", email: "workshop.team@acmemotors.demo", role: "org_mechanic", password: "DemoMechanic123!" },
  { key: "driver1", email: "aung.ko@acmemotors.demo", role: "org_driver", password: "DemoDriver123!" },
  { key: "driver2", email: "sanda.tun@acmemotors.demo", role: "org_driver", password: "DemoDriver123!" },
];

const SHOWROOM_PATH = { inventory: ["listed", "reserved", "sold"], listed: ["reserved", "sold"] };
const TAXI_PATH = { available: ["leased", "maintenance"], leased: ["maintenance"] };

async function seedFleet() {
  console.log(`\n── Fleet workspace · ${FLEET_EMAIL} · ACME Motors ──`);
  const adminToken = await login(FLEET_EMAIL, "fleet");

  // 1. Vehicles (skip any plate that already exists in the org)
  const existingVehicles = (await api("GET", `/organizations/${ORG}/vehicles`, { token: adminToken })).json?.items ?? [];
  const byPlate = new Map(existingVehicles.map((row) => [row.license_plate.trim(), row]));
  const vehicleIdByKey = new Map(existingVehicles.map((row) => [row.name, row.id]));

  for (const vehicle of FLEET_VEHICLES) {
    if (byPlate.has(vehicle.plate)) {
      vehicleIdByKey.set(vehicle.name, byPlate.get(vehicle.plate).id);
      continue;
    }
    const created = await ensure(
      "POST",
      `/organizations/${ORG}/vehicles`,
      {
        id: vehicle.id,
        name: vehicle.name,
        make: vehicle.make,
        model: vehicle.model,
        year: vehicle.year,
        license_plate: vehicle.plate,
        vin: vehicle.vin,
        fuel_type: vehicle.fuel,
        vehicle_class: "car",
        mileage: vehicle.mileage,
        lifecycle_template: vehicle.lifecycle,
        revenue_label: vehicle.label,
      },
      `vehicle ${vehicle.name}`,
      "fleet:vehicles",
      adminToken,
    );
    if (created?.id) vehicleIdByKey.set(vehicle.name, created.id);
  }

  // 2. Lifecycle status walk (inventory → listed → reserved → sold, etc.)
  const transitions = {
    showroom: { inventory: ["listed"], listed: ["inventory", "reserved"], reserved: ["listed", "sold"], sold: [] },
    taxi_fleet: { available: ["leased", "maintenance"], leased: ["maintenance", "available"], maintenance: ["available"] },
  };
  const walk = (from, to, edges) => {
    if (from === to) return [];
    const queue = [[from]];
    const seen = new Set([from]);
    while (queue.length) {
      const path = queue.shift();
      const tail = path[path.length - 1];
      for (const next of edges[tail] ?? []) {
        if (seen.has(next)) continue;
        if (next === to) return path.slice(1).concat(next);
        seen.add(next);
        queue.push(path.concat(next));
      }
    }
    return null;
  };
  const allVehicles = (await api("GET", `/organizations/${ORG}/vehicles`, { token: adminToken })).json?.items ?? [];
  for (const vehicle of FLEET_VEHICLES) {
    const id = vehicleIdByKey.get(vehicle.name);
    const row = allVehicles.find((item) => item.id === id);
    if (!row || row.status === vehicle.target) continue;
    const hops = walk(row.status, vehicle.target, transitions[vehicle.lifecycle]);
    if (!hops) {
      failures.push(`[fleet:vehicles] no status path ${row.status} → ${vehicle.target} for ${vehicle.name}`);
      continue;
    }
    for (const next of hops) {
      const result = await api("PATCH", `/organizations/${ORG}/vehicles/${id}`, {
        token: adminToken,
        body: { status: next },
      });
      if (!ok(result)) {
        fail("fleet:vehicles", `status → ${next} (${vehicle.name})`, result);
        break;
      }
    }
    console.log(` ✓ ${vehicle.name}: status → ${vehicle.target}`);
  }

  // 3. Members with known passwords (provision → clear forced password change)
  const members = (await api("GET", `/organizations/${ORG}/members`, { token: adminToken })).json?.items ?? [];
  const userIdByEmail = new Map(members.map((row) => [row.email, row.user_id]));
  for (const member of MEMBERS) {
    if (!userIdByEmail.has(member.email)) {
      const created = await ensure(
        "POST",
        `/organizations/${ORG}/members`,
        { email: member.email, role: member.role, temporary_password: member.password },
        `member ${member.email} (${member.role})`,
        "fleet:members",
        adminToken,
      );
      if (created?.user_id) userIdByEmail.set(member.email, created.user_id);
      if (!created) continue;
    }
    // Provisioned accounts must clear the forced password change before any
    // fleet endpoint accepts them; re-running simply re-clears the flag.
    let token = null;
    try {
      token = await login(member.email, "owner", member.password);
    } catch {
      failures.push(`[fleet:members] ${member.email}: cannot sign in with the scripted password`);
      continue;
    }
    const changed = await api("POST", "/auth/change-password", {
      token,
      body: { current_password: member.password, new_password: member.password },
    });
    if (!ok(changed, [204, 200])) fail("fleet:members", `clear password change ${member.email}`, changed);
    else console.log(` ✓ member ${member.email} (${member.role}) ready`);
  }

  // 4. Assignments
  const vehicleId = (key) => vehicleIdByKey.get(FLEET_VEHICLES.find((v) => v.key === key).name);
  const assignments = [
    ["driver1", "aqua"],
    ["driver1", "wagonr"],
    ["driver2", "demio"],
    ["driver2", "axio"],
  ];
  const existingAssignments = (await api("GET", `/organizations/${ORG}/assignments`, { token: adminToken })).json?.items ?? [];
  for (const [driverKey, vehicleKey] of assignments) {
    const driverId = userIdByEmail.get(MEMBERS.find((m) => m.key === driverKey).email);
    const target = vehicleId(vehicleKey);
    if (!driverId || !target) continue;
    const duplicate = existingAssignments.some((row) => row.driver_id === driverId && row.vehicle_id === target && row.status === "active");
    if (duplicate) continue;
    const result = await api("POST", `/organizations/${ORG}/assignments`, {
      token: adminToken,
      body: { vehicle_id: target, driver_id: driverId },
    });
    if (ok(result, [201])) console.log(` ✓ assignment ${driverKey} → ${vehicleKey}`);
    else if (result.status !== 409) fail("fleet:assignments", `${driverKey} → ${vehicleKey}`, result);
  }

  // 5. Service records + driver fuel logs in ascending odometer order
  const servicePlan = [
    { key: "aqua", d: "2026-05-12", odo: 119800, cost: 620000, shop: "Yangon Auto Care", notes: "Scheduled service", items: [["Oil & filter change", 180000], ["Front brake pads", 440000]] },
    { key: "wagonr", d: "2026-07-03", odo: 78200, cost: 340000, shop: "Yangon Auto Care", notes: null, items: [["Oil change", 150000], ["Air filter", 90000], ["Wiper blades", 100000]] },
    { key: "axio", d: "2026-03-19", odo: 155600, cost: 890000, shop: "DTM Auto Workshop", notes: "Preventive replace", items: [["Timing belt", 560000], ["Water pump", 330000]] },
    { key: "demio", d: "2026-08-22", odo: 133500, cost: 1250000, shop: "DTM Auto Workshop", notes: "Tyre replacement", items: [["4 tyres", 1050000], ["Alignment", 200000]] },
    { key: "probox", id: "20646c98-abde-4c46-84d5-6d1bb292ff68", d: "2026-06-12", odo: 135400, cost: 310000, shop: "Yangon Auto Care", notes: null, items: [["Oil change", 140000], ["Clutch adjustment", 170000]] },
    { key: "caldina", id: "62d0b374-d562-4908-a205-ea5b95c86b74", d: "2026-09-10", odo: 211800, cost: 450000, shop: "DTM Auto Workshop", notes: null, items: [["Turbo hose", 280000], ["Oil & filter", 170000]] },
  ];
  const driverTokens = {};
  for (const member of MEMBERS.filter((m) => m.role === "org_driver")) {
    try {
      driverTokens[member.key] = await login(member.email, "owner", member.password); // owner surface = driver mode
    } catch (error) {
      failures.push(`[fleet:drivers] ${member.email}: ${error.message}`);
    }
  }

  const driverFuel = [
    { driver: "driver1", key: "aqua", logs: [["2026-02-18", 118450, 46, 112000], ["2026-06-30", 120600, 44, 107000], ["2026-09-15", 122300, 45, 109500]] },
    { driver: "driver1", key: "wagonr", logs: [["2026-03-05", 76550, 30, 73500], ["2026-08-20", 79400, 31, 75900], ["2026-10-06", 80650, 30, 73500]] },
    { driver: "driver2", key: "demio", logs: [["2026-04-08", 131950, 40, 98000], ["2026-09-28", 134800, 41, 100400]] },
    { driver: "driver2", key: "axio", logs: [["2026-05-14", 156400, 42, 102900], ["2026-08-30", 157900, 43, 105300]] },
  ];
  // Timeline posting: services (admin) and fuel logs (driver) interleave in
  // ascending odometer order. Odometers are clamped above each vehicle's
  // current mileage so re-runs never regress.
  const fleetEvents = [
    ...servicePlan.map((row) => ({ kind: "service", ...row })),
    ...driverFuel.flatMap((entry) =>
      entry.logs.map(([d, odo, amount, cost]) => ({ kind: "fuel", key: entry.key, driver: entry.driver, d, odo, amount, cost })),
    ),
  ];

  const mileageById = new Map(
    (await api("GET", `/organizations/${ORG}/vehicles`, { token: adminToken })).json?.items
      .map((row) => [row.id, Number(row.mileage)]) ?? [],
  );
  const driverFuelTypeId = {};
  const fuelTypeIdFor = async (driverKey) => {
    if (driverFuelTypeId[driverKey]) return driverFuelTypeId[driverKey];
    const token = driverTokens[driverKey];
    const existing = (await api("GET", "/drivers/fuel-types", { token })).json?.items ?? [];
    const own = existing.find((row) => row.name === "Special Petrol");
    if (own) {
      driverFuelTypeId[driverKey] = own.id;
      return own.id;
    }
    const created = await ensure("POST", "/drivers/fuel-types", { id: detId(`fleet-fuel-type:${driverKey}`), name: "Special Petrol", kind: "liquid", unit: "L" }, "fuel type", "fleet:fuel", token, [201, 200]);
    driverFuelTypeId[driverKey] = created?.id ?? null;
    return created?.id ?? null;
  };

  const targetFor = (key) => servicePlan.find((row) => row.key === key)?.id ?? vehicleId(key);
  for (const key of [...new Set(fleetEvents.map((event) => event.key))]) {
    const target = targetFor(key);
    if (!target) continue;
    const seenServices = new Set(
      ((await api("GET", `/organizations/${ORG}/vehicles/${target}/service-records`, { token: adminToken })).json?.items ?? [])
        .map((row) => row.serviced_on),
    );
    const seenFuel = new Map();
    const seenFor = async (driverKey, token) => {
      if (!seenFuel.has(driverKey)) {
        seenFuel.set(driverKey, new Set(
          ((await api("GET", `/drivers/vehicles/${target}/fuel-logs`, { token })).json?.items ?? [])
            .map((row) => row.logged_on),
        ));
      }
      return seenFuel.get(driverKey);
    };

    let cursor = Number(mileageById.get(target) ?? 0);
    const events = fleetEvents.filter((event) => event.key === key).sort((a, b) => a.odo - b.odo);
    for (const event of events) {
      const odometer = Math.max(event.odo, cursor + 50);
      cursor = odometer;
      if (event.kind === "service") {
        if (seenServices.has(event.d)) continue;
        const result = await api("POST", `/organizations/${ORG}/vehicles/${target}/service-records`, {
          token: adminToken,
          body: {
            serviced_on: event.d,
            odometer,
            total_cost: event.cost,
            workshop_name: event.shop,
            notes: event.notes,
            items: event.items.map(([name, line_cost]) => ({ name, line_cost })),
          },
        });
        if (ok(result, [201, 200])) {
          seenServices.add(event.d);
          console.log(` ✓ service ${key} ${event.d}`);
        } else if (result.status !== 409) fail("fleet:service", `service ${key} ${event.d}`, result);
      } else {
        const token = driverTokens[event.driver];
        if (!token || !(await fuelTypeIdFor(event.driver))) continue;
        if ((await seenFor(event.driver, token)).has(event.d)) continue;
        const result = await api("POST", `/organizations/${ORG}/fuel-logs`, {
          token,
          body: {
            vehicle_id: target,
            fuel_type_id: driverFuelTypeId[event.driver],
            logged_on: event.d,
            amount: event.amount,
            cost: event.cost,
            odometer_km: odometer,
          },
        });
        if (ok(result, [201, 200])) {
          (await seenFor(event.driver, token)).add(event.d);
          console.log(` ✓ fuel ${key} ${event.d}`);
        } else if (result.status !== 409) fail("fleet:fuel", `fuel ${key} ${event.d}`, result);
      }
    }
  }

  // 6. Maintenance plans for the new vehicles (template class → generate).
  // "wash" runs every 14 days, so every vehicle lands inside the 30-day
  // "upcoming maintenance" bucket on the fleet dashboard.
  const wantedKeys = ["oil_change", "rotate_tires", "brake_change", "air_filter_cabin", "brake_fluid", "new_tires", "wash"];
  let generatedPlans = 0;
  for (const vehicle of FLEET_VEHICLES) {
    const id = vehicleIdByKey.get(vehicle.name);
    if (!id) continue;
    await ensure("PUT", `/organizations/${ORG}/vehicles/${id}/maintenance-template`, { vehicle_class: "car" }, `template class ${vehicle.name}`, "fleet:plan", adminToken, [200, 201]);
    // Catalog rows carry a null lifecycle (they match every set) and the link
    // supplies the lifecycle — filter it out of the query or null rows vanish.
    const query = `?vehicle_class=car&fuel_type=${vehicle.fuel}`;
    const templates = (await api("GET", `/organizations/${ORG}/maintenance-templates${query}`, { token: adminToken })).json?.items ?? [];
    const scoped = templates.filter((row) => wantedKeys.includes(row.catalog_key));
    if (!scoped.length) continue;
    const result = await ensure(
      "POST",
      `/organizations/${ORG}/vehicles/${id}/maintenance-template/generate`,
      { item_ids: scoped.map((row) => row.id) },
      `generate plan ${vehicle.name}`,
      "fleet:plan",
      adminToken,
      [200, 201],
    );
    if (result) generatedPlans += 1;
  }
  console.log(` ✓ maintenance plans generated for ${generatedPlans} vehicles`);

  // 7. Inspection templates
  const inspectionTemplates = [
    { key: "pre-delivery", name: "Pre-Delivery Check", items: [["Exterior & paint", true], ["Tyre condition", true], ["Lights & indicators", true], ["Brakes & fluid", true], ["Odometer & fuel level", true], ["Documents & keys", true]] },
    { key: "daily", name: "Daily Driver Check", items: [["Tyres & pressure", true], ["Lights", true], ["Brakes", true], ["Engine bay leaks", true], ["Fuel level", true]] },
    { key: "monthly", name: "Monthly Safety Audit", items: [["Tyres", true], ["Brakes", true], ["Seatbelts", true], ["Horn", true], ["Wipers", true], ["Exhaust", false], ["Battery", true]] },
  ];
  const existingTemplates = (await api("GET", `/organizations/${ORG}/inspection-templates`, { token: adminToken })).json?.items ?? [];
  const templateIdByKey = new Map(existingTemplates.map((row) => [row.name, row.id]));
  for (const template of inspectionTemplates) {
    if (templateIdByKey.has(template.name)) continue;
    const created = await ensure(
      "POST",
      `/organizations/${ORG}/inspection-templates`,
      { name: template.name, items: template.items.map(([item_name, required]) => ({ item_name, required })) },
      `inspection template ${template.name}`,
      "fleet:inspections",
      adminToken,
      [201, 200],
    );
    if (created?.id) templateIdByKey.set(template.name, created.id);
  }

  // 8. Inspections (drivers create and complete; one left in progress, one failed)
  const existingInspections = (await api("GET", `/organizations/${ORG}/inspections`, { token: adminToken })).json?.items ?? [];
  const inspectionRuns = [
    { driver: "driver1", key: "aqua", template: "Daily Driver Check", type: "pre_trip", results: null },
    { driver: "driver2", key: "demio", template: "Monthly Safety Audit", type: "pre_trip", results: { Brakes: "not_ok" }, notes: "Front pads below 3 mm — work order raised." },
    { driver: "driver1", key: "wagonr", template: "Daily Driver Check", type: "post_trip", results: null },
    { driver: "driver2", key: "axio", template: "Daily Driver Check", type: "pre_trip", results: null, open: true },
  ];
  for (const run of inspectionRuns) {
    const token = driverTokens[run.driver];
    const target = vehicleId(run.key);
    const templateId = templateIdByKey.get(run.template);
    if (!token || !target || !templateId) continue;
    const already = existingInspections.some((row) => row.vehicle_id === target && row.template_id === templateId && row.inspection_type === run.type);
    if (already) continue;
    const created = await ensure(
      "POST",
      `/organizations/${ORG}/inspections`,
      { vehicle_id: target, template_id: templateId, inspection_type: run.type },
      `inspection ${run.key} (${run.type})`,
      "fleet:inspections",
      token,
      [201, 200],
    );
    if (!created?.id || run.open) {
      if (created?.id) console.log(` ✓ inspection ${run.key} left in progress`);
      continue;
    }
    const definitions = (await api("GET", `/organizations/${ORG}/inspection-templates`, { token })).json?.items
      ?.find((row) => row.id === templateId)?.items ?? [];
    const patched = await api("PATCH", `/organizations/${ORG}/inspections/${created.id}`, {
      token,
      body: {
        items: definitions.map((definition) => ({
          item_name: definition.item_name,
          result: run.results?.[definition.item_name] ?? "ok",
        })),
        notes: run.notes ?? "All checks passed.",
      },
    });
    if (ok(patched, [200, 201])) console.log(` ✓ inspection ${run.key} → ${patched.json?.status}`);
    else fail("fleet:inspections", `complete ${run.key}`, patched);
  }

  // 9. Work orders (drivers report, admin progresses to completion)
  const existingOrders = (await api("GET", `/organizations/${ORG}/work-orders`, { token: adminToken })).json?.items ?? [];
  const workOrders = [
    {
      driver: "driver1", key: "aqua", issue: "breakdown", urgency: "high",
      description: "Engine overheating in heavy traffic — temperature warning light came on twice this week.",
      odo: 122400, flow: [["in_progress", { assigned_to: "mechanic", }], ["completed", { completion_cost: 480000, resolution_notes: "Replaced thermostat, coolant flush and pressure-tested the radiator. Road tested for 15 km." }]],
    },
    {
      driver: "driver1", key: "wagonr", issue: "wear_tear", urgency: "medium",
      description: "Front brake pads squealing at low speed; inspection recommended before the next rental handover.",
      odo: 80700, flow: [],
    },
    {
      driver: "driver2", key: "demio", issue: "scheduled_service", urgency: "medium",
      description: "135,000 km scheduled service — oil, filters and wheel alignment before the lease renewal.",
      odo: 134900, flow: [["in_progress", { assigned_to: "mechanic" }]],
    },
    {
      driver: "driver2", key: "axio", issue: "other", urgency: "low",
      description: "Air conditioning not cooling after overnight parking; possible gas leak in the front line.",
      odo: 158000, flow: [],
    },
  ];
  for (const order of workOrders) {
    const token = driverTokens[order.driver];
    const target = vehicleId(order.key);
    if (!token || !target) continue;
    const duplicate = existingOrders.find((row) => row.vehicle_id === target && row.description === order.description);
    let orderId = duplicate?.id;
    if (!orderId) {
      const created = await ensure(
        "POST",
        `/organizations/${ORG}/work-orders`,
        { vehicle_id: target, odometer_km: order.odo, issue_type: order.issue, description: order.description, urgency: order.urgency },
        `work order ${order.key} (${order.issue})`,
        "fleet:work-orders",
        token,
        [201, 200],
      );
      orderId = created?.id;
    }
    if (!orderId) continue;
    let status = duplicate?.status ?? "reported";
    for (const [next, patch] of order.flow) {
      if (status !== (next === "in_progress" ? "reported" : "in_progress")) continue;
      const body = { status: next };
      if (patch.assigned_to) body.assigned_to = userIdByEmail.get(MEMBERS.find((m) => m.key === patch.assigned_to).email);
      if (patch.completion_cost !== undefined) {
        body.completion_cost = patch.completion_cost;
        body.resolution_notes = patch.resolution_notes;
        body.parts = [{ name: "Workshop parts & consumables" }];
      }
      const result = await api("PATCH", `/organizations/${ORG}/work-orders/${orderId}`, { token: adminToken, body });
      if (ok(result, [200, 201])) {
        status = next;
        console.log(` ✓ work order ${order.key} → ${next}`);
      } else fail("fleet:work-orders", `${order.key} → ${next}`, result);
    }
  }

  // 10. Warranty templates
  const warranties = [
    { name: "ACME Standard Warranty", duration_years: 3, mileage_limit_km: 60000, coverage: ["engine", "transmission", "electrical"], exclusions: "Wear items (pads, discs, tyres) and accident damage." },
    { name: "ACME Powertrain Plus", duration_years: 5, mileage_limit_km: 150000, coverage: ["engine", "transmission", "drivetrain", "turbo"], exclusions: "Cosmetic damage, fluids and filters." },
  ];
  const existingWarrantyTemplates = (await api("GET", `/organizations/${ORG}/warranty-templates`, { token: adminToken })).json?.items ?? [];
  for (const template of warranties) {
    if (existingWarrantyTemplates.some((row) => row.name === template.name)) continue;
    const created = await ensure(
      "POST",
      `/organizations/${ORG}/warranty-templates`,
      { name: template.name, duration_years: template.duration_years, mileage_limit_km: template.mileage_limit_km, coverage_categories: template.coverage, exclusions: template.exclusions, approved_workshop_ids: [] },
      `warranty template ${template.name}`,
      "fleet:warranty",
      adminToken,
      [201, 200],
    );
    if (created) console.log(` ✓ warranty template ${template.name}`);
  }

  // 11. Reporting currency (unlocks the Analytics page)
  const currency = await api("PUT", `/organizations/${ORG}/analytics/settings`, {
    token: adminToken,
    body: { currency: "MMK", timezone: "Asia/Yangon", confirm_existing_amounts: true },
  });
  if (ok(currency, [200])) console.log(" ✓ analytics currency MMK / Asia/Yangon");
  else if (currency.status !== 409) fail("fleet:analytics", "currency settings", currency);
  else console.log(" · analytics currency already locked");

  const lemon = await api("POST", `/organizations/${ORG}/analytics/lemon-threshold`, {
    token: adminToken,
    body: { multiplier: 1.15 },
  });
  if (ok(lemon, [200])) console.log(" ✓ lemon threshold multiplier 1.15");
  else fail("fleet:analytics", "lemon threshold", lemon);

  const summary = await api("GET", `/organizations/${ORG}/analytics/fleet`, { token: adminToken });
  const a = summary.json ?? {};
  console.log(` → vehicles ${a.vehicle_count} · open WOs ${a.open_work_orders} · assignments ${a.active_assignments} · upcoming maintenance ${a.upcoming_maintenance_count} · fleet spend ${Math.round(a.total_fleet_spend ?? 0)} MMK`);
}

async function main() {
  console.log(`seed-demo-data → ${BASE}`);
  if (ONLY === "both" || ONLY === "customer") await seedCustomer();
  if (ONLY === "both" || ONLY === "fleet") await seedFleet();
  console.log(`\n${calls} API calls · ${failures.length} failures`);
  if (failures.length) {
    for (const line of failures) console.log(` ${line}`);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error("seed-demo-data failed:", error);
  process.exit(1);
});
