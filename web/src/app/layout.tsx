import type { Metadata } from "next";
import { Barlow, IBM_Plex_Mono, IBM_Plex_Sans } from "next/font/google";
import { Providers } from "./providers";
import "./globals.css";

const barlow = Barlow({
  variable: "--font-barlow",
  subsets: ["latin"],
  weight: ["500", "600", "700"],
});

const plexSans = IBM_Plex_Sans({
  variable: "--font-plex-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600"],
});

const plexMono = IBM_Plex_Mono({
  variable: "--font-plex-mono",
  subsets: ["latin"],
  weight: ["400", "500"],
});

export const metadata: Metadata = {
  title: "DCO Admin",
  description: "Digital Car Ownership platform — staff administration portal",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark" suppressHydrationWarning>
      <body
        suppressHydrationWarning
        className={`${barlow.variable} ${plexSans.variable} ${plexMono.variable} bg-bg font-sans text-ink antialiased`}
      >
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
