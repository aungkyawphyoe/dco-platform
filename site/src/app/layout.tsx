import type { Metadata } from "next";
import { cookies } from "next/headers";
import { THEME_COOKIE, THEME_INIT_SCRIPT, themeClassFromCookie } from "@/lib/theme";
import { SiteNav } from "@/components/layout/site-nav";
import { SiteFooter } from "@/components/layout/site-footer";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "AutoX — Your Digital Garage",
    template: "%s · AutoX",
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
    <html lang="en" className={`${theme} scroll-smooth`} suppressHydrationWarning>
      <head>
        <link rel="preload" as="font" type="font/woff2" href="/fonts/IBMPlexSans-var.woff2" crossOrigin="" />
        <link rel="preload" as="font" type="font/woff2" href="/fonts/Barlow-600.woff2" crossOrigin="" />
      </head>
      <body
        suppressHydrationWarning
        className="bg-bg font-sans text-ink antialiased flex min-h-screen flex-col"
      >
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
        <SiteNav />
        <main className="flex-1">{children}</main>
        <SiteFooter />
      </body>
    </html>
  );
}
