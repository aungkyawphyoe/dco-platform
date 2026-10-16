export const FLEET_HERO = {
  eyebrow: "Fleet management",
  title: "Stop losing money on your fleet",
  subtitle:
    "Get full visibility into fuel, maintenance, work orders and costs across your entire operation — in one system your drivers already use on mobile.",
  bullets: [
    "Vehicle inventory with CSV import",
    "Work orders and inspections",
    "Driver assignments and roles",
    "Cost analytics: TCO and cost per km",
    "Web portal plus mobile Fleet mode",
  ],
} as const;

export const FLEET_CHALLENGES = {
  heading: "Do you recognize any of these problems?",
  intro: "Most fleet managers face these challenges every day.",
  items: [
    {
      title: "Spreadsheet control",
      description: "Scattered data, outdated information and hours wasted consolidating reports by hand.",
    },
    {
      title: "Hidden costs",
      description: "Without visibility, fuel and maintenance expenses go unnoticed and eat into your margin.",
    },
    {
      title: "Delayed maintenance",
      description: "Unexpected breakdowns are costly and reduce your operation's productivity.",
    },
    {
      title: "No cost visibility",
      description: "Without centralized data it is impossible to know what each vehicle truly costs your company.",
    },
  ],
} as const;

export const FLEET_STEPS = [
  {
    title: "Talk to us",
    description: "Tell us about your operation — we provision your organization workspace.",
  },
  {
    title: "Add vehicles and drivers",
    description: "Import your inventory from a spreadsheet and invite drivers with roles.",
  },
  {
    title: "Start managing",
    description: "Report issues, run inspections and track costs from the portal and mobile app.",
  },
] as const;

export const FLEET_MODULES = [
  {
    title: "Work Orders",
    description: "Drivers report issues straight from the dashboard quick actions; managers track them from reported to completed.",
  },
  {
    title: "Inspections",
    description: "Template checklists for pre-trip and post-trip checks — failures auto-create a work order.",
  },
  {
    title: "Driver Assignments",
    description: "Assign vehicles to drivers; maintenance and fuel logged by the driver track against each assignment.",
  },
  {
    title: "Warranty Templates",
    description: "Standard warranty terms per vehicle, with approved workshops attached.",
  },
  {
    title: "Workshop Management",
    description: "Keep your network of service providers and their records in one place.",
  },
  {
    title: "Cost Analytics",
    description: "TCO, cost per km and lemon flags — fleet-wide summaries and per-vehicle drilldown.",
  },
  {
    title: "Reports & CSV",
    description: "Operational reports with CSV export for finance and compliance.",
  },
  {
    title: "Vehicle Lifecycle",
    description: "Showroom, taxi, rental and commercial lifecycles — plus transfer to buyers with full history.",
  },
] as const;

export const FLEET_BENEFITS = [
  {
    title: "Complete fleet control",
    description: "A 360° view of vehicles, drivers, costs and operations in one centralized system.",
  },
  {
    title: "Cost reduction",
    description: "Identify excessive spending, optimize fuel consumption and eliminate waste.",
  },
  {
    title: "Preventive maintenance",
    description: "Automatic reminders prevent surprise breakdowns and extend vehicle lifespan.",
  },
  {
    title: "Management reports",
    description: "Clear, exportable reports for decision-making, compliance and auditing.",
  },
  {
    title: "Standardized processes",
    description: "Inspections, work orders and records keep operations running the same way every day.",
  },
  {
    title: "Web and mobile",
    description: "Managers work from the fleet portal; drivers log from Android and iOS.",
  },
] as const;

export const FLEET_COMPARISON = {
  heading: "Why companies are replacing spreadsheets",
  rows: [
    { manual: "Data scattered across spreadsheets", dco: "Everything centralized in one system" },
    { manual: "Outdated information", dco: "Live data from the field" },
    { manual: "Hours building reports", dco: "Exportable reports in minutes" },
    { manual: "Forgotten maintenance", dco: "Automatic time and mileage reminders" },
    { manual: "No cost visibility", dco: "Cost per vehicle at a glance" },
    { manual: "Hard to scale", dco: "From a handful of vehicles to hundreds" },
  ],
} as const;

export const FLEET_INDUSTRIES = [
  "Carriers",
  "Logistics",
  "Vehicle rental",
  "Field maintenance",
  "Technical services",
  "Field teams",
  "Construction",
  "Agriculture",
] as const;
