import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Cognidoc AI — Admin",
  description: "Cognidoc AI SaaS boshqaruv paneli",
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="uz">
      <body>{children}</body>
    </html>
  );
}
