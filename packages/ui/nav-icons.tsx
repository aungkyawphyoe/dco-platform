export type GroupKey =
  | "overview"
  | "directory"
  | "fleet"
  | "submissions"
  | "configuration"
  | "data";

const groupPaths: Record<GroupKey, React.ReactNode> = {
  overview: (
    <>
      <rect x="3" y="3" width="7.5" height="7.5" rx="1.5" />
      <rect x="13.5" y="3" width="7.5" height="7.5" rx="1.5" />
      <rect x="3" y="13.5" width="7.5" height="7.5" rx="1.5" />
      <rect x="13.5" y="13.5" width="7.5" height="7.5" rx="1.5" />
    </>
  ),
  directory: (
    <>
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </>
  ),
  fleet: (
    <>
      <path d="M2 6h11v9H2z" />
      <path d="M13 9h4l3 3v3h-7z" />
      <circle cx="6" cy="17.5" r="2" />
      <circle cx="17" cy="17.5" r="2" />
      <path d="M8 17.5h7" />
    </>
  ),
  submissions: (
    <>
      <path d="M22 12h-6l-2 3h-4l-2-3H2" />
      <path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z" />
    </>
  ),
  configuration: (
    <>
      <path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3" />
      <path d="M1 14h6M9 8h6M17 16h6" />
    </>
  ),
  data: (
    <>
      <path d="M3 3v18h18" />
      <path d="M8 17v-5M13 17V8M18 17v-8" />
    </>
  ),
};

function Svg({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

export function GroupIcon({ name, className }: { name: GroupKey; className?: string }) {
  return <Svg className={className}>{groupPaths[name]}</Svg>;
}

export function IconChevronsLeft({ className }: { className?: string }) {
  return (
    <Svg className={className}>
      <path d="m11 17-5-5 5-5" />
      <path d="m18 17-5-5 5-5" />
    </Svg>
  );
}

export function IconChevronsRight({ className }: { className?: string }) {
  return (
    <Svg className={className}>
      <path d="m13 17 5-5-5-5" />
      <path d="m6 17 5-5-5-5" />
    </Svg>
  );
}

export function IconSignOut({ className }: { className?: string }) {
  return (
    <Svg className={className}>
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <path d="m16 17 5-5-5-5" />
      <path d="M21 12H9" />
    </Svg>
  );
}
