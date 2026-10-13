export const HERO = {
  eyebrow: "Digital Car Ownership",
  title: "Every vehicle deserves a digital identity",
  subtitle:
    "A complete digital record for every vehicle you own — every maintenance entry, every cost, every receipt, in one place that works offline and syncs the moment you reconnect.",
} as const;

export const VALUE_CHIPS = [
  {
    title: "Offline-First",
    description: "Writes never block on a signal.",
  },
  {
    title: "Smart Reminders",
    description: "Time and mileage thresholds.",
  },
  {
    title: "Resale Ready",
    description: "A documented service history.",
  },
  {
    title: "Multi-Vehicle",
    description: "One garage, many cars.",
  },
] as const;

export const PATHS = [
  {
    href: "/personal",
    badge: "Free forever",
    title: "Personal Use",
    description: "Track fuel, expenses, maintenance and costs of your own vehicles.",
    bullets: ["Fuel and charging logs", "Expense tracking", "Maintenance reminders", "Complete history"],
    cta: "Explore personal use",
  },
  {
    href: "/fleet",
    badge: "For business",
    title: "Fleet Management",
    description: "Organize your company's vehicles, drivers and workshops in one system.",
    bullets: ["Work orders and inspections", "Driver assignments", "Cost analytics", "Fleet reports"],
    cta: "Explore fleet management",
  },
] as const;

export const FEATURES = [
  {
    title: "Maintenance",
    description:
      "Plan items by time or mileage. Suggested items filtered by fuel type. Register services with parts and receipts in seconds.",
    chips: ["Plan items", "Service records", "Receipts"],
  },
  {
    title: "Fuel or Charging",
    description:
      "Refuel logs for petrol and hybrid plugin, charge logs for electric. Volume, cost and date — never lose a fill-up again.",
    chips: ["Refuel", "Charge", "Per-vehicle"],
  },
  {
    title: "Mileage",
    description:
      "Mileage that never goes backward. Sync resolves conflicts with max-wins, so the highest odometer reading always wins.",
    chips: ["Monotonic", "km/mi", "Sync-safe"],
  },
  {
    title: "Costs",
    description:
      "Track fuel, maintenance, insurance, parking, tolls, parts and other. Monthly and total summaries per vehicle — your real cost of ownership.",
    chips: ["Categories", "Summaries", "Receipts"],
  },
  {
    title: "Reminders",
    description:
      "Local notifications when a plan item comes due by time or distance. Mark done, dismiss or snooze — nothing falls through the cracks.",
    chips: ["Local notifications", "Smart thresholds"],
  },
  {
    title: "Multiple Vehicles",
    description:
      "One garage, many cars. Switch the active vehicle in one tap and keep separate plans, services and expenses for each.",
    chips: ["Active switch", "Per-vehicle data"],
  },
] as const;

export const AUDIENCES = [
  {
    title: "Electric Vehicle Owners",
    bullets: ["Charging costs", "Energy use", "Real cost per km"],
  },
  {
    title: "Petrol & Diesel Drivers",
    bullets: ["Track fuel usage", "Monitor service history", "Organized maintenance"],
  },
  {
    title: "Families With Multiple Cars",
    bullets: ["Manage multiple vehicles", "Share records", "Stay organized"],
  },
  {
    title: "Fleet Owners",
    bullets: ["Track multiple vehicles", "Monitor usage and costs", "Centralize vehicle data"],
  },
  {
    title: "Ride Share & Delivery",
    bullets: ["Fuel and earnings costs", "Mileage records", "High-mileage maintenance"],
  },
] as const;

export const STEPS = [
  {
    title: "Create your account",
    description: "Download the app and sign up free with email, Google or Apple.",
  },
  {
    title: "Add your vehicles",
    description: "Register your car, motorcycle or EV in less than a minute.",
  },
  {
    title: "Start logging",
    description: "Record fuel, expenses and maintenance — your history builds itself.",
  },
] as const;
