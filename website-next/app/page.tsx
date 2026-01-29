import Image from "next/image";
import Link from "next/link";

export default function Home() {
  return (
    <>
      <nav className="fixed top-0 left-0 right-0 z-50 glass-nav transition-all duration-300">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex-shrink-0 flex items-center gap-3 cursor-pointer">
              <Image
                src="/assets/images/icon.png"
                width={40}
                height={40}
                alt="Athkari Logo"
                className="rounded-xl shadow-lg border border-white/10"
              />
              <span className="font-display font-bold text-xl tracking-tight text-white">أذكاري</span>
            </div>
            <div className="hidden md:flex items-center gap-8">
              <Link className="text-sm font-medium text-gray-300 hover:text-white transition-colors" href="#features">
                المميزات
              </Link>
              <Link className="text-sm font-medium text-gray-300 hover:text-white transition-colors" href="#gallery">
                معرض الصور
              </Link>
              <Link className="text-sm font-medium text-gray-300 hover:text-white transition-colors" href="/privacy">
                الخصوصية
              </Link>
            </div>
            <div className="flex items-center gap-4">
              <button className="hidden md:flex items-center justify-center px-4 py-2 text-sm font-bold text-white bg-primary hover:bg-primary-dark rounded-lg transition-all duration-200 shadow-[0_0_15px_rgba(48,110,232,0.3)]">
                جرب التطبيق
              </button>
              <button className="md:hidden p-2 text-gray-300 hover:text-white transition-colors">
                <span className="material-symbols-outlined">menu</span>
              </button>
            </div>
          </div>
        </div>
      </nav>

      <main className="relative min-h-screen flex flex-col pt-24 pb-12 overflow-hidden bg-background-dark">
        <div className="absolute inset-0 bg-gradient-to-b from-[#0a0f16] via-[#111822] to-[#05080c] z-0"></div>
        <div className="absolute inset-0 bg-islamic-pattern opacity-30 z-0 pointer-events-none mix-blend-overlay"></div>
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/3 w-[600px] h-[600px] hero-glow blur-3xl z-0 pointer-events-none"></div>

        <div className="relative z-10 container mx-auto px-4 flex flex-col lg:flex-row items-center justify-center gap-12 lg:gap-20 h-full flex-grow">
          <div className="flex flex-col items-center lg:items-start text-center lg:text-right gap-6 max-w-2xl lg:w-1/2 mt-10 lg:mt-0 order-2 lg:order-1">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/5 border border-white/10 backdrop-blur-sm">
              <span className="material-symbols-outlined text-primary text-sm">star</span>
              <span className="text-xs font-medium text-primary-100">الإصدار الجديد كلياً</span>
            </div>
            <h1 className="font-display font-black text-4xl sm:text-5xl lg:text-7xl leading-[1.2] text-transparent bg-clip-text bg-gradient-to-b from-white to-gray-400 drop-shadow-sm">
              رفيقك اليومي في <br /> <span className="text-primary">طاعة الله وذكره</span>
            </h1>
            <p className="text-gray-400 text-lg sm:text-xl font-light leading-relaxed max-w-lg font-body">
              تجربة روحانية متكاملة تجمع لك الأذكار، مواقيت الصلاة، وتتبع العبادات بتصميم عصري يحترم خصوصيتك ويخلو تماماً من الإعلانات.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 w-full sm:w-auto mt-4">
              <a
                href="#"
                className="flex items-center justify-center gap-3 bg-white/10 hover:bg-white/15 border border-white/10 backdrop-blur-sm px-6 py-3.5 rounded-xl transition-all duration-300 group w-full sm:w-auto"
              >
                <span className="text-right flex flex-col items-end leading-none">
                  <span className="text-[10px] uppercase text-gray-400">Download on the</span>
                  <span className="text-lg font-bold text-white font-sans tracking-wide">App Store</span>
                </span>
                <svg className="w-8 h-8 text-white fill-current" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.21-1.96 1.07-3.11-1.04.05-2.29.69-3.02 1.6-.68.85-1.28 2.09-1.12 3.15 1.15.09 2.33-.79 3.07-1.64z"></path>
                </svg>
              </a>
              <button className="lg:hidden flex items-center justify-center px-6 py-3.5 text-base font-bold text-white bg-primary hover:bg-primary-dark rounded-xl transition-all duration-200 w-full sm:w-auto shadow-[0_4px_14px_rgba(48,110,232,0.4)]">
                جرب التطبيق الآن
              </button>
            </div>
          </div>

          <div className="relative w-full lg:w-1/2 h-[600px] sm:h-[700px] flex items-center justify-center lg:justify-end order-1 lg:order-2 perspective-1000">
            {/* Back Phone (Library View) - Adjusted Visibility */}
            <div className="absolute top-0 left-4 sm:left-6 lg:left-0 w-[280px] sm:w-[300px] h-[580px] sm:h-[620px] bg-[#111] rounded-[40px] border-[6px] border-[#2d2d2d] shadow-2xl transform scale-95 -rotate-3 translate-y-4 opacity-100 z-10 transition-transform duration-500 hover:scale-100 hover:z-30 hover:rotate-0">
              <div className="absolute top-0 left-1/2 -translate-x-1/2 h-[25px] w-[100px] bg-black rounded-b-2xl z-20"></div>
              <div className="w-full h-full bg-[#1e2a3b] rounded-[32px] overflow-hidden relative">
                <img src="/assets/images/screen_library.png" alt="Library Interface" className="w-full h-full object-fill" />
              </div>
            </div>

            {/* Front Phone (Home View) */}
            <div className="absolute top-4 right-4 sm:right-6 lg:right-6 w-[280px] sm:w-[300px] h-[580px] sm:h-[620px] bg-[#111] rounded-[40px] border-[6px] border-[#2d2d2d] shadow-[0_30px_60px_-15px_rgba(0,0,0,0.6)] z-20">
              <div className="absolute top-0 left-1/2 -translate-x-1/2 h-[25px] w-[100px] bg-black rounded-b-2xl z-30"></div>
              <div className="w-full h-full bg-[#1a2538] rounded-[32px] overflow-hidden relative">
                <img src="/assets/images/screenshot_home.png" alt="Home Interface" className="w-full h-full object-fill" />
              </div>
            </div>
          </div>
        </div>
        <div className="absolute bottom-0 left-0 w-full h-24 bg-gradient-to-t from-background-dark to-transparent z-20"></div>
      </main>

      {/* Features Section */}
      <section id="features" className="relative py-24 bg-[#0a0f16] overflow-hidden">
        <div className="absolute inset-0 bg-islamic-pattern opacity-10 pointer-events-none"></div>
        <div className="max-w-7xl mx-auto px-4 relative z-10">
          <div className="text-center mb-16">
            <h2 className="font-display font-bold text-3xl sm:text-4xl text-white mb-4">مميزات صممت لك</h2>
            <p className="text-gray-400 max-w-2xl mx-auto">كل ما يحتاجه المسلم في حياته اليومية، في مكان واحد.</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="bg-white/5 backdrop-blur-sm border border-white/10 p-6 rounded-2xl hover:bg-white/10 transition-colors">
              <div className="w-12 h-12 rounded-xl bg-primary/20 flex items-center justify-center text-primary mb-4">
                <span className="material-symbols-outlined">settings_accessibility</span>
              </div>
              <h3 className="font-display font-bold text-xl text-white mb-2">الأذكار والورد</h3>
              <p className="text-sm text-gray-400">واجهة قراءة مريحة للعين مع عدادات ذكية وتتبع لختمات الأذكار.</p>
            </div>
            <div className="bg-white/5 backdrop-blur-sm border border-white/10 p-6 rounded-2xl hover:bg-white/10 transition-colors">
              <div className="w-12 h-12 rounded-xl bg-cyan-500/20 flex items-center justify-center text-cyan-400 mb-4">
                <span className="material-symbols-outlined">mosque</span>
              </div>
              <h3 className="font-display font-bold text-xl text-white mb-2">دقة المواقيت</h3>
              <p className="text-sm text-gray-400">تنبيهات للأذان بدقة عالية مع دعم لتقويم أم القرى ومختلف المذاهب.</p>
            </div>
            <div className="bg-white/5 backdrop-blur-sm border border-white/10 p-6 rounded-2xl hover:bg-white/10 transition-colors">
              <div className="w-12 h-12 rounded-xl bg-indigo-500/20 flex items-center justify-center text-indigo-400 mb-4">
                <span className="material-symbols-outlined">nights_stay</span>
              </div>
              <h3 className="font-display font-bold text-xl text-white mb-2">مرافق الصيام</h3>
              <p className="text-sm text-gray-400">تتبع صيامك، تعرّف على الأيام البيض، واستقبل تنبيهات السحور والإفطار.</p>
            </div>
            <div className="bg-white/5 backdrop-blur-sm border border-white/10 p-6 rounded-2xl hover:bg-white/10 transition-colors">
              <div className="w-12 h-12 rounded-xl bg-emerald-500/20 flex items-center justify-center text-emerald-400 mb-4">
                <span className="material-symbols-outlined">book_2</span>
              </div>
              <h3 className="font-display font-bold text-xl text-white mb-2">مكتبة شاملة</h3>
              <p className="text-sm text-gray-400">حصن المسلم كاملاً، الرقية الشرعية، وأدعية من الكتاب والسنة.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Gallery Section */}
      <section id="gallery" className="py-24 bg-[#05080c] border-t border-white/5">
        <div className="max-w-7xl mx-auto px-4">
          <div className="text-center mb-16">
            <h2 className="font-display font-bold text-3xl sm:text-4xl text-white mb-4">تجربة استخدام فاخرة</h2>
            <p className="text-gray-400">تصميم يجمع بين الجمال والوظيفة ليمنحك الخشوع الذي تبحث عنه.</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="rounded-3xl overflow-hidden border-4 border-[#2d2d2d] shadow-2xl bg-[#111]">
              <img src="/assets/images/screen_library.png" alt="Library" className="w-full h-auto object-cover hover:scale-105 transition-transform duration-500" />
            </div>
            <div className="rounded-3xl overflow-hidden border-4 border-[#2d2d2d] shadow-2xl bg-[#111]">
              <img src="/assets/images/screen_tools.png" alt="Tools" className="w-full h-auto object-cover hover:scale-105 transition-transform duration-500" />
            </div>
            <div className="rounded-3xl overflow-hidden border-4 border-[#2d2d2d] shadow-2xl bg-[#111]">
              <img src="/assets/images/screen_settings.png" alt="Settings" className="w-full h-auto object-cover hover:scale-105 transition-transform duration-500" />
            </div>
          </div>
        </div>
      </section>

      <footer className="bg-background-dark py-8 border-t border-white/5">
        <div className="max-w-7xl mx-auto px-4 text-center">
          <p className="text-gray-500 text-sm font-body">© 2026 تطبيق أذكاري. جميع الحقوق محفوظة.</p>
        </div>
      </footer>
    </>
  );
}
