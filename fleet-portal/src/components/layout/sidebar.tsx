"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useSession } from "@/lib/auth/session-context";
import { Button } from "@/components/ui/button";
import { orgRoleLabel } from "@/lib/api/types";

const nav = [
  { section: "Overview", items: [{ href: "/", label: "Dashboard", exact: true }] },
  {
    section: "Fleet",
    items: [
      { href: "/vehicles", label: "Vehicles", exact: false },
      { href: "/work-orders", label: "Work Orders", exact: false },
      { href: "/inspections", label: "Inspections", exact: false },
      { href: "/assignments", label: "Driver Assignments", exact: false },
    ],
  },
  {
    section: "Configuration",
    items: [
      { href: "/members", label: "Members", exact: false },
      { href: "/workshops", label: "Workshops", exact: false },
      { href: "/warranty-templates", label: "Warranty Templates", exact: false },
      { href: "/settings", label: "Org Settings", exact: false },
    ],
  },
  {
    section: "Data",
    items: [
      { href: "/reports", label: "Reports", exact: false },
      { href: "/transferred", label: "Transferred", exact: false },
    ],
  },
];

export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, org, signOut } = useSession();

  async function onSignOut() {
    await signOut();
    router.replace("/login");
  }

  return (
    <aside className="flex w-60 shrink-0 flex-col border-r border-line-subtle bg-panel">
      <div className="flex h-16 items-center gap-2.5 px-5">
        <Image
          src="/dco-logo.png"
          alt=""
          width={32}
          height={32}
          className="size-8 shrink-0 rounded-sm bg-white"
        />
        <span className="font-display text-lg font-semibold tracking-tight text-gold">
          DCO Fleet
        </span>
      </div>

      <nav className="flex flex-1 flex-col gap-6 overflow-y-auto px-3 py-4">
        {nav.map((group) => (
          <div key={group.section}>
            <p className="px-2 pb-2 text-xs font-medium uppercase tracking-wider text-ink-caption">
              {group.section}
            </p>
            <ul className="flex flex-col gap-1">
              {group.items.map((item) => {
                const active = item.exact
                  ? pathname === item.href
                  : pathname.startsWith(item.href);
                return (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      className={`block rounded-md px-3 py-2 text-sm transition-colors duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-focus ${
                        active
                          ? "bg-card font-semibold text-gold"
                          : "text-ink-muted hover:bg-card hover:text-ink"
                      }`}
                      aria-current={active ? "page" : undefined}
                    >
                      {item.label}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>

      <div className="border-t border-line-subtle p-4">
        <p className="truncate text-sm text-ink" title={org?.organization?.name ?? ""}>
          {org?.organization?.name ?? "…"}
        </p>
        <p className="pb-1 text-xs text-ink-caption" title={user?.email ?? ""}>
          {user?.email ?? ""}
        </p>
        <p className="pb-3 text-xs text-ink-caption">
          {orgRoleLabel[org?.organization?.role ?? ""] ?? org?.organization?.role ?? ""}
        </p>
        <Button variant="destructive" size="sm" className="w-full" onClick={onSignOut}>
          Sign out
        </Button>
      </div>
    </aside>
  );
}
