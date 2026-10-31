"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useSession, useOrgRole } from "@/lib/auth/session-context";
import { Button } from "@dco/ui/components/button";
import { ThemeToggle, ThemeCycleButton } from "@dco/ui/components/theme-toggle";
import { orgRoleLabel } from "@/lib/api/types";
import {
  GroupIcon,
  IconChevronsLeft,
  IconChevronsRight,
  IconSignOut,
  type GroupKey,
} from "@dco/ui/nav-icons";

type NavItem = { href: string; label: string; exact: boolean };
type NavGroup = { section: string; icon: GroupKey; items: NavItem[] };

const STORAGE_KEY = "dco.fleet.sidebar.collapsed";

function getNavForRole(role: string | null): NavGroup[] {
  const baseNav: NavGroup[] = [
    {
      section: "Overview",
      icon: "overview",
      items: [{ href: "/", label: "Dashboard", exact: true }, ...(["org_admin", "org_manager"].includes(role ?? "") ? [{ href: "/analytics", label: "Analytics", exact: false }] : [])],
    },
    {
      section: "Fleet",
      icon: "fleet",
      items: [
        { href: "/vehicles", label: "Vehicles", exact: false },
        { href: "/maintenance-templates", label: "Maintenance Catalog", exact: false },
        { href: "/work-orders", label: "Work Orders", exact: false },
        { href: "/inspections", label: "Inspections", exact: false },
        { href: "/assignments", label: "Driver Assignments", exact: false },
      ],
    },
  ];

  const adminNav: NavGroup[] = [
    {
      section: "Submissions",
      icon: "submissions",
      items: [{ href: "/reviews", label: "Submission Review", exact: false }],
    },
    {
      section: "Configuration",
      icon: "configuration",
      items: [
        { href: "/members", label: "Members", exact: false },
        { href: "/workshops", label: "Workshops", exact: false },
        { href: "/warranty-templates", label: "Warranty Templates", exact: false },
        { href: "/settings", label: "Org Settings", exact: false },
      ],
    },
    {
      section: "Data",
      icon: "data",
      items: [
        { href: "/reports", label: "Reports", exact: false },
        { href: "/transferred", label: "Transferred", exact: false },
      ],
    },
  ];

  const managerMechanicNav: NavGroup[] = [
    {
      section: "Configuration",
      icon: "configuration",
      items: [{ href: "/members", label: "Members", exact: false }],
    },
    {
      section: "Data",
      icon: "data",
      items: [
        { href: "/reports", label: "Reports", exact: false },
        { href: "/transferred", label: "Transferred", exact: false },
      ],
    },
  ];

  if (role === "org_admin") return [...baseNav, ...adminNav];
  if (role === "org_manager" || role === "org_mechanic") return [...baseNav, ...managerMechanicNav];
  return baseNav;
}

function isActive(item: NavItem, pathname: string) {
  return item.exact ? pathname === item.href : pathname.startsWith(item.href);
}

function CollapsedGroup({ group, pathname }: { group: NavGroup; pathname: string }) {
  const active = group.items.some((item) => isActive(item, pathname));

  if (group.items.length === 1) {
    const item = group.items[0];
    const itemActive = isActive(item, pathname);
    return (
      <Link
        href={item.href}
        title={item.label}
        aria-label={item.label}
        aria-current={itemActive ? "page" : undefined}
        className={`flex h-10 w-full items-center justify-center rounded-md transition-colors duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-focus ${
          itemActive ? "bg-card text-gold" : "text-ink-muted hover:bg-card hover:text-ink"
        }`}
      >
        <GroupIcon name={group.icon} className="size-5" />
      </Link>
    );
  }

  return (
    <div className="group relative w-full">
      <button
        type="button"
        aria-haspopup="true"
        aria-label={group.section}
        title={group.section}
        className={`flex h-10 w-full items-center justify-center rounded-md transition-colors duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-focus ${
          active ? "bg-card text-gold" : "text-ink-muted hover:bg-card hover:text-ink"
        }`}
      >
        <GroupIcon name={group.icon} className="size-5" />
      </button>
      <div className="invisible absolute left-full top-0 z-50 pl-2 opacity-0 transition-opacity duration-150 group-hover:visible group-hover:opacity-100 focus-within:visible focus-within:opacity-100">
        <div className="w-52 rounded-lg border border-line-subtle bg-card p-2 shadow-xl">
          <p className="flex items-center gap-2 px-2 pb-1.5 pt-1 text-xs font-medium text-ink-caption">
            <GroupIcon name={group.icon} className="size-3.5" />
            {group.section}
          </p>
          <ul className="flex flex-col gap-0.5">
            {group.items.map((item) => {
              const itemActive = isActive(item, pathname);
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    aria-current={itemActive ? "page" : undefined}
                    className={`block rounded-md px-2 py-1.5 text-sm transition-colors duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-focus ${
                      itemActive
                        ? "bg-skeleton font-semibold text-gold"
                        : "text-ink hover:bg-panel"
                    }`}
                  >
                    {item.label}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      </div>
    </div>
  );
}

export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, org, signOut } = useSession();
  const role = useOrgRole();
  const nav = getNavForRole(role);

  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    const mobile = window.matchMedia("(max-width: 767px)");
    const syncCollapsed = () => {
      try { setCollapsed(mobile.matches || window.localStorage.getItem(STORAGE_KEY) === "1"); }
      catch { setCollapsed(mobile.matches); }
    };
    syncCollapsed();
    mobile.addEventListener("change", syncCollapsed);
    return () => mobile.removeEventListener("change", syncCollapsed);
  }, []);

  function toggleCollapsed() {
    setCollapsed((prev) => {
      const next = !prev;
      try {
        window.localStorage.setItem(STORAGE_KEY, next ? "1" : "0");
      } catch {
        // ignore storage access errors
      }
      return next;
    });
  }

  async function onSignOut() {
    await signOut();
    router.replace("/login");
  }

  return (
    <aside
      className={`flex h-full shrink-0 flex-col border-r border-line-subtle bg-panel transition-[width] duration-200 ${
        collapsed ? "relative w-16" : "absolute inset-y-0 left-0 z-40 w-60 shadow-xl md:relative md:shadow-none"
      }`}
    >
      <div
        className={`flex h-16 shrink-0 items-center px-4 ${
          collapsed ? "justify-center" : "gap-2.5"
        }`}
      >
        <Link href="/" className="flex min-w-0 items-center gap-2.5">
          <Image
            src="/autox-logo.png"
            alt=""
            width={32}
            height={32}
            className="size-8 shrink-0 rounded-sm bg-white"
          />
          {!collapsed && (
            <span className="truncate font-display text-lg font-semibold tracking-tight text-gold">
              AutoX Fleet
            </span>
          )}
        </Link>
      </div>

      <button
        type="button"
        onClick={toggleCollapsed}
        aria-expanded={!collapsed}
        title={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        className="absolute -right-3 top-5 z-30 flex size-6 items-center justify-center rounded-md bg-gold text-on-gold shadow-sm transition-colors duration-150 hover:bg-btn-primary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
      >
        {collapsed ? (
          <IconChevronsRight className="size-3.5" />
        ) : (
          <IconChevronsLeft className="size-3.5" />
        )}
      </button>

      {collapsed ? (
        <nav className="flex min-h-0 flex-1 flex-col items-center gap-1 overflow-visible px-2 py-3">
          {nav.map((group) => (
            <CollapsedGroup key={group.section} group={group} pathname={pathname} />
          ))}
        </nav>
      ) : (
        <nav className="flex min-h-0 flex-1 flex-col gap-6 overflow-y-auto px-3 py-4">
          {nav.map((group) => (
            <div key={group.section}>
              <p className="flex items-center gap-2 px-2 pb-2 text-xs font-medium text-ink-caption">
                <GroupIcon name={group.icon} className="size-4" />
                {group.section}
              </p>
              <ul className="flex flex-col gap-1">
                {group.items.map((item) => {
                  const active = isActive(item, pathname);
                  return (
                    <li key={item.href}>
                      <Link
                        href={item.href}
                        aria-current={active ? "page" : undefined}
                        className={`block rounded-md px-3 py-2 text-sm transition-colors duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-focus ${
                          active
                            ? "bg-card font-semibold text-gold"
                            : "text-ink hover:bg-card"
                        }`}
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
      )}

      <div className="shrink-0 border-t border-line-subtle p-3">
        {collapsed ? (
          <div className="flex flex-col items-center gap-2">
            <ThemeCycleButton />
            <div
              title={user?.email ?? ""}
              className="flex size-8 items-center justify-center rounded-full bg-card text-xs font-semibold text-ink"
            >
              {(org?.organization?.name ?? user?.email ?? "?").slice(0, 1).toUpperCase()}
            </div>
            <button
              type="button"
              onClick={onSignOut}
              title="Sign out"
              aria-label="Sign out"
              className="inline-flex size-9 items-center justify-center rounded-md text-danger transition-colors duration-150 hover:bg-btn-destructive-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-focus"
            >
              <IconSignOut className="size-4" />
            </button>
          </div>
        ) : (
          <>
            <p className="pb-1.5 text-xs text-ink-caption">Appearance</p>
            <div className="pb-3">
              <ThemeToggle />
            </div>
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
          </>
        )}
      </div>
    </aside>
  );
}
