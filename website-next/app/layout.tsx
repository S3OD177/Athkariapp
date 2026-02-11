import type { Metadata } from "next";
import { Newsreader, Noto_Sans_Arabic } from "next/font/google";
import "./globals.css";

const newsreader = Newsreader({
  variable: "--font-display",
  subsets: ["latin"],
  style: ["italic", "normal"],
  display: 'swap',
});

const notoSansArabic = Noto_Sans_Arabic({
  variable: "--font-body",
  subsets: ["arabic"],
  weight: ["100", "200", "300", "400", "500", "600", "700", "800", "900"],
  display: 'swap',
});

export const metadata: Metadata = {
  metadataBase: new URL('https://athkari.app'),
  title: {
    default: "Athkari | أذكاري",
    template: "%s | Athkari"
  },
  description: "Athkari App: Your daily companion for Adhkar, Prayer Times, and Ibadah tracking. Totally free, no ads, and privacy-focused. | رفيقك اليومي في طاعة الله وذكره. أذكار، مواقيت الصلاة، وتتبع العبادات. تطبيق إسلامي شامل خالي من الإعلانات ويحترم الخصوصية.",
  keywords: [
    "Athkari", "أذكاري",
    "Islamic App", "tessbih", "tasbih", "sibha", "misbaha",
    "Prayer Times", "Salah Times", "Adan", "Athan",
    "Adhkar", "Dhikr", "Morning Adhkar", "Evening Adhkar",
    "Muslim App", "Quran", "Holly Quran",
    "Hisn Al-Muslim", "Fortress of the Muslim",
    "Ramadan", "Fasting", "Ibadah Tracker",
    "حصن المسلم", "مواقيت الصلاة", "تطبيق أذكاري", "القرآن الكريم", "رمضان", "صيام"
  ],
  authors: [{ name: "Ibn Ziad" }],
  creator: "Ibn Ziad",
  publisher: "Ibn Ziad",
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  alternates: {
    canonical: 'https://athkari.app',
    languages: {
      'ar-SA': 'https://athkari.app',
      'en-US': 'https://athkari.app',
    },
  },
  openGraph: {
    title: "Athkari | أذكاري",
    description: "Your daily companion for Adhkar and Prayer Times. | رفيقك اليومي في طاعة الله وذكره.",
    url: 'https://athkari.app',
    siteName: 'Athkari App',
    locale: 'ar_SA',
    alternateLocale: ['en_US'],
    type: 'website',
    images: [
      {
        url: '/assets/images/icon.png',
        width: 800,
        height: 600,
        alt: 'Athkari App Icon',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: "Athkari | أذكاري",
    description: "Your daily companion for Adhkar and Prayer Times. | رفيقك في طريق الذكر والعبادة",
    images: ['/assets/images/icon.png'],
  },
  appleWebApp: {
    title: 'Athkari',
    statusBarStyle: 'black-translucent',
    capable: true,
  },
  applicationName: 'Athkari',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ar" dir="rtl" className="dark">
      <head>
        <link
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap"
          rel="stylesheet"
        />
      </head>
      <body
        className={`${newsreader.variable} ${notoSansArabic.variable} antialiased font-body bg-background-light dark:bg-background-dark text-slate-900 dark:text-white`}
      >
        {children}
      </body>
    </html>
  );
}
