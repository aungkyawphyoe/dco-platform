import type { Metadata } from "next";
import { Barlow, IBM_Plex_Mono, IBM_Plex_Sans } from "next/font/google";
import { cookies } from "next/headers";
import { THEME_COOKIE, THEME_INIT_SCRIPT, themeClassFromCookie } from "@/lib/theme";
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
  title: "DCO Fleet",
  description: "Digital Car Ownership platform — Fleet management portal",
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
        className={`${barlow.variable} ${plexSans.variable} ${plexMono.variable} bg-bg font-sans text-ink antialiased`}
      >
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
