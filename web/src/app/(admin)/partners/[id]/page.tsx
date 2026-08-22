import { PageHeader } from "@/components/ui/page-header";

export default function EditPartnerPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Edit partner" description="Update record and verification status" />
      <p className="text-sm text-ink-caption">Wired up in Phase 3 (A6).</p>
    </div>
  );
}
