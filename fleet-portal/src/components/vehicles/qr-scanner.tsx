"use client";

import { useEffect, useId, useRef, useState } from "react";
import { Html5Qrcode, Html5QrcodeSupportedFormats } from "html5-qrcode";
import { Button } from "@dco/ui/components/button";

interface QrScannerProps {
  onScan: (code: string) => void;
  onCancel: () => void;
  title?: string;
  hint?: string;
}

export function QrScanner({
  onScan,
  onCancel,
  title = "Scan QR code",
  hint = "Point the camera at the buyer's account code QR",
}: QrScannerProps) {
  const readerId = useId();
  const [scanner, setScanner] = useState<Html5Qrcode | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [scanning, setScanning] = useState(false);
  const scannedRef = useRef(false);

  useEffect(() => {
    const html5Qrcode = new Html5Qrcode(readerId, {
      formatsToSupport: [Html5QrcodeSupportedFormats.QR_CODE],
      verbose: false,
    });

    setScanner(html5Qrcode);

    return () => {
      void html5Qrcode
        .stop()
        .catch(() => {})
        .finally(() => void html5Qrcode.clear());
    };
  }, [readerId]);

  useEffect(() => {
    if (!scanner || scanning || scannedRef.current) return;

    setScanning(true);
    scanner
      .start(
        { facingMode: "environment" },
        {
          fps: 10,
          qrbox: { width: 220, height: 220 },
        },
        (decodedText) => {
          if (scannedRef.current) return;
          scannedRef.current = true;
          setScanning(false);
          onScan(decodedText);
        },
        () => {
          // Ignore scan errors (no QR found in frame)
        },
      )
      .catch((err) => {
        setScanning(false);
        setError(
          err?.message?.includes("permission")
            ? "Camera permission denied. Enter the account ID manually."
            : "Could not start camera. Enter the account ID manually.",
        );
      });

    return () => {
      scannedRef.current = false;
      void scanner.stop().catch(() => {}).finally(() => setScanning(false));
    };
  }, [scanner, scanning, onScan]);

  return (
    <div className="flex flex-col items-center gap-4 rounded-lg border border-line-subtle bg-card p-5">
      <h3 className="text-sm font-semibold text-ink">{title}</h3>
      <p className="text-xs text-ink-caption text-center">{hint}</p>

      <div
        id={readerId}
        className="w-full max-w-xs aspect-square rounded-md bg-black overflow-hidden"
        style={{ width: "100%", maxWidth: 280, height: 280 }}
        aria-hidden="true"
      />

      {error ? (
        <div className="w-full max-w-xs rounded-md bg-danger-dim px-3 py-2 text-center text-sm text-danger">
          {error}
        </div>
      ) : (
        <p className="text-xs text-ink-faint">
          Scanning…{" "}
          <span className="inline-block w-4 h-4 animate-pulse bg-current" />
        </p>
      )}

      <Button type="button" variant="ghost" size="sm" onClick={onCancel}>
        Enter account ID manually
      </Button>
    </div>
  );
}