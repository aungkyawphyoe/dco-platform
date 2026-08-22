import { PageHeader } from "@/components/ui/page-header";

export default function UserProfilePage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="User profile"
        description="Profile, vehicles, documents count, and support actions"
      />
      <p className="text-sm text-ink-caption">Wired up in Phase 3 (A4).</p>
    </div>
  );
}
