import type { Metadata } from "next";
import { cookies } from "next/headers";
import { THEME_COOKIE, THEME_INIT_SCRIPT, themeClassFromCookie } from "@/lib/theme";
import { getSiteCopy } from "@/i18n/dictionary";
import { SiteNav } from "@/components/layout/site-nav";
import { SiteFooter } from "@/components/layout/site-footer";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const { d } = await getSiteCopy();
  return {
    title: {
      default: d.meta.siteTitle,
      template: "%s · AutoX",
    },
    description: d.meta.siteDescription,
  };
}

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const cookieStore = await cookies();
  const theme = themeClassFromCookie(cookieStore.get(THEME_COOKIE)?.value);
  const { locale, d } = await getSiteCopy();

  return (
    <html lang={locale} className={`${theme} scroll-smooth`} suppressHydrationWarning>
      <head>
        <link rel="preload" as="font" type="font/woff2" href="/fonts/IBMPlexSans-var.woff2" crossOrigin="" />
        <link rel="preload" as="font" type="font/woff2" href="/fonts/Barlow-600.woff2" crossOrigin="" />
      </head>
      <body
        suppressHydrationWarning
        className="bg-bg font-sans text-ink antialiased flex min-h-screen flex-col"
      >
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
        <SiteNav locale={locale} labels={d.nav} language={d.language} theme={d.theme} />
        <main className="flex-1">{children}</main>
        <SiteFooter labels={d.footer} navLabels={d.nav.links} />
      </body>
    </html>
  );
}
