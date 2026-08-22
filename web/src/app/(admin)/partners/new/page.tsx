import { PageHeader } from "@/components/ui/page-header";

export default function NewPartnerPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="New partner" description="Register a workshop or insurer" />
      <p className="text-sm text-ink-caption">Wired up in Phase 3 (A6).</p>
    </div>
  );
}
