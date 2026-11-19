import Image from "next/image";

export type DetailSubject = "dashboard" | "fuel" | "maintenance";

export function ScreenDetail({ subject, alt }: { subject: DetailSubject; alt: string }) {
  return (
    <div className="screen-detail">
      {(["dark", "light"] as const).map(mode => (
        <Image key={mode} className={`capture-${mode}`} width={500} height={472}
          src={`/screenshots/detail-${subject}-${mode}.webp`} alt={alt} sizes="(max-width: 640px) 85vw, 380px" />
      ))}
    </div>
  );
}
