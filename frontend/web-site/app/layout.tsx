import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Cognidoc AI — Hujjatlaringiz bilan aqlli suhbat",
    template: "%s | Cognidoc AI",
  },
  description:
    "Cognidoc AI yordamida hujjatlarni tahlil qiling, kerakli ma’lumotni toping va murakkab savollarga aniq javob oling.",
  applicationName: "Cognidoc AI",
  keywords: [
    "Cognidoc AI",
    "AI hujjat tahlili",
    "sun’iy intellekt",
    "PDF tahlil",
    "AI assistant",
    "hujjatlar bilan suhbat",
  ],
  openGraph: {
    type: "website",
    locale: "uz_UZ",
    siteName: "Cognidoc AI",
    title: "Cognidoc AI — Hujjatlaringiz bilan aqlli suhbat",
    description:
      "Hujjatlaringizni tushunishga yordam beradigan AI yordamchi. Savol bering, mazmunli javob oling.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Cognidoc AI — Hujjatlaringiz bilan aqlli suhbat",
    description: "Hujjatlaringizni tahlil qiling va muhim ma’lumotni tez toping.",
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="uz">
      <body>{children}</body>
    </html>
  );
}
