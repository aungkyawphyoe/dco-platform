export type FaqItem = { q: string; a: string };
export type FaqCategory = { id: string; label: string; items: FaqItem[] };

export const FAQ_CATEGORIES: FaqCategory[] = [
  {
    id: "general",
    label: "General",
    items: [
      {
        q: "What is AutoX?",
        a: "AutoX is a platform for tracking everything about the vehicles you own. You can record fuel and charging entries, expenses, maintenance services, documents and reminders — and see the full history of each vehicle in one place.",
      },
      {
        q: "Who is AutoX designed for?",
        a: "Two audiences: personal use for people who want to track costs and history of their own vehicles, and fleet use for companies that manage vehicles, drivers and workshop operations.",
      },
      {
        q: "Which platforms does AutoX support?",
        a: "AutoX is available on Android and iOS, with a dedicated web fleet portal for organization managers. Your data syncs automatically across devices on the same account.",
      },
      {
        q: "What types of vehicles can I manage?",
        a: "Cars, motorcycles, electric vehicles and hybrid plugin vehicles. Fuel tracking covers petrol refuels and electric charging; maintenance plans adapt suggestions to your fuel type.",
      },
      {
        q: "Is AutoX free?",
        a: "Yes. The Free plan covers one vehicle with fuel logs, maintenance plans, reminders, expenses and documents. Paid plans unlock more vehicles, sharing and storage — see the pricing page for current tiers.",
      },
      {
        q: "What is the difference between personal use and fleet management?",
        a: "Personal use focuses on tracking costs, fuel, maintenance and history for your own vehicles. Fleet management adds an organization workspace with roles, work orders, inspections, driver assignments and fleet reports through the fleet portal.",
      },
    ],
  },
  {
    id: "account",
    label: "Account",
    items: [
      {
        q: "Do I need to create an account?",
        a: "Yes. Your account identifies your profile, stores your information securely and lets you log in on other devices. You can sign up with email or with Google and Apple.",
      },
      {
        q: "I changed my phone. Will I lose my data?",
        a: "No — as long as you log in with the same account. Your data is associated with your account and is restored to your new device after sign-in and sync.",
      },
      {
        q: "Can I use my account on more than one device?",
        a: "Yes. Sign in with the same account on any of your devices; changes sync automatically when each device is online.",
      },
      {
        q: "I forgot my password. How can I recover it?",
        a: "On the login screen use the password recovery option and follow the instructions sent to your email.",
      },
      {
        q: "Can I delete my account?",
        a: "Yes — Settings → Profile → Edit Profile → Delete Account. This deactivates your account and archives all your vehicles; you can't sign in again afterwards. Contact support if you'd like it restored, or permanently erased instead.",
      },
      {
        q: "Can I transfer my records to the buyer of the vehicle?",
        a: "Vehicle sharing lets you grant access to another AutoX user by code or email invite, including a view-only level — useful during a sale so the buyer can see the service history.",
      },
    ],
  },
  {
    id: "personal",
    label: "Personal use",
    items: [
      {
        q: "Can I manage more than one vehicle on the same account?",
        a: "Yes. How many depends on your plan — Free covers 1 vehicle, Lite 3, Standard 10 and Fleet/Pro unlimited. You switch the active vehicle in one tap.",
      },
      {
        q: "Does AutoX work for electric vehicles?",
        a: "Yes. Charge logs track electricity cost and energy for electric vehicles, alongside the same maintenance, expenses and documents as petrol cars.",
      },
      {
        q: "Is AutoX useful for ride share or delivery drivers?",
        a: "Yes. Many drivers use AutoX to log fuel, charging, mileage and expenses to understand the real operating cost of the vehicle they work with.",
      },
      {
        q: "Can I attach documents and receipts to my records?",
        a: "Yes. Service records and expenses support receipt photos, and each vehicle has a documents vault for insurance, registration, invoices and warranty files.",
      },
      {
        q: "Can I share a vehicle with another person?",
        a: "Yes. Vehicle sharing invites by code/QR or email with two access levels: view only, or add and edit your own records. Share counts are limited by plan.",
      },
      {
        q: "Does AutoX work without an internet connection?",
        a: "Yes. The app is offline-first — you can log fuel, expenses and services with no signal. Everything syncs automatically once you reconnect.",
      },
    ],
  },
  {
    id: "fleet",
    label: "Fleet management",
    items: [
      {
        q: "Does AutoX work for companies?",
        a: "Yes. Fleet management adds an organization workspace where managers handle vehicles, drivers, work orders, inspections, workshops and reports — plus the mobile Fleet and Driver modes.",
      },
      {
        q: "How do I get started with fleet management?",
        a: "Fleet onboarding is guided: we provision your organization and Fleet Admin account, then you add vehicles (CSV import supported) and invite drivers with the right roles.",
      },
      {
        q: "Do drivers need their own account?",
        a: "Yes. Drivers sign in with their own credentials in a restricted Driver mode — they see their assigned vehicle and can report issues, while managers see everything centrally.",
      },
      {
        q: "Can I limit a driver to only one vehicle?",
        a: "Yes. Drivers are bound to assigned vehicles, and organization roles (admin, manager, mechanic, driver) control what each person can see and do.",
      },
      {
        q: "Is there a dashboard to monitor the fleet?",
        a: "Yes. The fleet portal is the central hub with dashboards, vehicle inventory, work orders, inspections, assignments, members, workshops and reports.",
      },
      {
        q: "Can I import my vehicle list from a spreadsheet?",
        a: "Yes. Fleet onboarding supports CSV import of your vehicle inventory so you do not have to enter every vehicle manually.",
      },
    ],
  },
  {
    id: "vehicle",
    label: "Vehicle & garage",
    items: [
      {
        q: "How do I add a new vehicle?",
        a: "From the Garage tab, add a vehicle with its name, make, model, plate and fuel type — under a minute. All records you then add belong to the selected vehicle.",
      },
      {
        q: "Are my records separated by vehicle?",
        a: "Yes. Fuel logs, expenses, services, documents and reminders all belong to one specific vehicle, so each vehicle keeps its own history.",
      },
      {
        q: "Can I delete a vehicle?",
        a: "Vehicles are archived rather than deleted, so history is never lost by accident. Archived vehicles also stop counting against your plan limit.",
      },
      {
        q: "How much does my vehicle's mileage go up?",
        a: "Mileage never goes backward: when devices disagree, sync resolves conflicts with max-wins so the highest reading is kept.",
      },
    ],
  },
  {
    id: "maintenance",
    label: "Maintenance & reminders",
    items: [
      {
        q: "How do maintenance plans work?",
        a: "You add plan items — suggested ones filtered by your fuel type, or fully custom — with a due interval in days or distance. When a service is done you mark it complete and the next occurrence is scheduled.",
      },
      {
        q: "Can I set reminders by mileage as well as date?",
        a: "Yes. Reminders trigger on time or distance thresholds (for example within 7 days or 100 km of the due point), and the thresholds are configurable in settings.",
      },
      {
        q: "How are reminder notifications delivered?",
        a: "Notifications are scheduled locally on your device, so they work even without an internet connection.",
      },
      {
        q: "Can I keep receipts for services?",
        a: "Yes. Service records support parts you have fitted and receipt photos, building a verifiable history that helps at resale time.",
      },
    ],
  },
  {
    id: "fuel",
    label: "Fuel & charging",
    items: [
      {
        q: "What can I record in a fuel log?",
        a: "Date, volume, cost and optional odometer for each refuel — plus an owner-defined fuel types catalog if you use more than one fuel.",
      },
      {
        q: "Can I track electricity charging costs?",
        a: "Yes. Electric vehicles get charge logs alongside the same cost summaries as petrol refuels.",
      },
      {
        q: "Can I see how much I spend on fuel per month?",
        a: "Yes. Expense summaries group fuel (and every other category) into monthly and total views per vehicle.",
      },
    ],
  },
  {
    id: "expenses",
    label: "Expenses",
    items: [
      {
        q: "What should I record in Expenses?",
        a: "Anything that is not a maintenance service: fuel, insurance, parking, tolls, parts and other — seven categories in total, each with optional receipt photos.",
      },
      {
        q: "What is the difference between Expenses and Services?",
        a: "Expenses are general vehicle costs; services are maintenance interventions recorded in the maintenance history with parts and reminders.",
      },
      {
        q: "Can I attach receipts to expenses?",
        a: "Yes. Expense entries support receipt photos attached to each record.",
      },
      {
        q: "Can I export my data?",
        a: "Yes. Data export to CSV is available on all plans so you can analyze your records anywhere.",
      },
    ],
  },
  {
    id: "plans",
    label: "Plans & payments",
    items: [
      {
        q: "How many vehicles can I register?",
        a: "It depends on the plan: Free 1, Lite 3, Standard 10, Fleet/Pro unlimited. When you reach a limit the app shows an upgrade prompt.",
      },
      {
        q: "How do upgrades work?",
        a: "Upgrades are applied to your account and increase your limits immediately. Plans and billing are managed for you — contact support to change plan while self-serve billing rolls out.",
      },
      {
        q: "What payment methods are supported?",
        a: "Pricing is listed in Myanmar Kyat (MMK), with local payment methods for Myanmar and USD pricing via card for international users.",
      },
      {
        q: "Is there a money-back guarantee?",
        a: "Yes. Paid plans include a 30-day money-back guarantee.",
      },
      {
        q: "What happens if I downgrade or cancel?",
        a: "You keep your current limits until the end of the paid period, then the account reverts to the Free plan — your data stays intact.",
      },
    ],
  },
];
