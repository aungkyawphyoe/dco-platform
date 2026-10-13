import type { Metadata } from "next";
import { Barlow, IBM_Plex_Mono, IBM_Plex_Sans } from "next/font/google";
import { cookies } from "next/headers";
import { THEME_COOKIE, THEME_INIT_SCRIPT, themeClassFromCookie } from "@/lib/theme";
import { SiteNav } from "@/components/layout/site-nav";
import { SiteFooter } from "@/components/layout/site-footer";
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
  title: {
    default: "DCO — Your Digital Garage",
    template: "%s · DCO",
  },
  description:
    "Track fuel, charging, maintenance, expenses and documents for every vehicle you own. Offline-first mobile app for personal vehicles and fleets.",
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const cookieStore = await cookies();
  const theme = themeClassFromCookie(cookieStore.get(THEME_COOKIE)?.value);

  return (
    <html lang="en" className={theme} suppressHydrationWarning>
      <body
        suppressHydrationWarning
        className={`${barlow.variable} ${plexSans.variable} ${plexMono.variable} bg-bg font-sans text-ink antialiased flex min-h-screen flex-col`}
      >
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
        <SiteNav />
        <main className="flex-1">{children}</main>
        <SiteFooter />
      </body>
    </html>
  );
}
