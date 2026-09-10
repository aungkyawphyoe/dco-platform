"use client";

import QRCodeStyling from "qr-code-styling";
import { useEffect, useRef } from "react";
import { Modal } from "./modal";
import { Button } from "./button";

export function QrCodeModal({
  open,
  onClose,
  data,
  label,
  code,
}: {
  open: boolean;
  onClose: () => void;
  data: string;
  label: string;
  code: string;
}) {
  const qrRef = useRef<HTMLDivElement>(null);
  const qrInstanceRef = useRef<QRCodeStyling | null>(null);

  useEffect(() => {
    if (open && qrRef.current && !qrInstanceRef.current) {
      qrInstanceRef.current = new QRCodeStyling({
        width: 280,
        height: 280,
        data,
        margin: 16,
        qrOptions: { typeNumber: 0, mode: "Byte", errorCorrectionLevel: "M" },
        backgroundOptions: { color: "#fff" },
        dotsOptions: { color: "#101B22", type: "rounded" },
        cornersSquareOptions: { color: "#101B22", type: "extra-rounded" },
        cornersDotOptions: { color: "#101B22", type: "dot" },
        imageOptions: { crossOrigin: "anonymous", margin: 8 },
      });
      qrInstanceRef.current.append(qrRef.current!);
    }
    return () => {
      if (qrInstanceRef.current) {
        qrInstanceRef.current = null;
      }
    };
  }, [open, data]);

  useEffect(() => {
    if (open && qrInstanceRef.current) {
      qrInstanceRef.current.update({ data });
    }
  }, [data, open]);

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={`Invite to ${label}`}
      confirmLabel="Close"
      onConfirm={onClose}
    >
      <div className="flex flex-col items-center gap-4">
        <div ref={qrRef} />
        <div className="text-center">
          <p className="font-mono text-xl tracking-widest text-gold">{code}</p>
          <p className="text-sm text-ink-caption mt-1">Share Code</p>
          <Button variant="secondary" size="sm" className="mt-2" onClick={() => navigator.clipboard.writeText(code)}>
            Copy Code
          </Button>
        </div>
        <p className="text-xs text-ink-caption text-center">
          Expires in 7 days. Scan with DCO mobile app to join.
        </p>
      </div>
    </Modal>
  );
}
