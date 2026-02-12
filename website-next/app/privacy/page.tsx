import Link from "next/link";

export default function Privacy() {
    return (
        <>
            <nav className="fixed top-0 left-0 right-0 z-50 glass-nav transition-all duration-300">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="flex items-center justify-between h-16">
                        <div className="flex-shrink-0 flex items-center gap-2 cursor-pointer">
                            <span className="material-symbols-outlined text-primary text-3xl">mosque</span>
                            <span className="font-display font-bold text-xl tracking-tight text-white">اذكاري</span>
                        </div>
                        <div className="flex items-center gap-8">
                            <Link className="text-sm font-medium text-gray-300 hover:text-white transition-colors" href="/">
                                الرئيسية
                            </Link>

                        </div>
                    </div>
                </div>
            </nav>

            <main className="relative min-h-screen container mx-auto px-4 pt-32 pb-24">
                <div className="absolute inset-0 bg-islamic-pattern opacity-10 z-0 pointer-events-none fixed"></div>

                <div className="max-w-3xl mx-auto relative z-10 glass-nav rounded-2xl p-8 border border-white/5">
                    <h1 className="font-display font-black text-3xl text-white mb-8 border-b border-white/10 pb-4">سياسة الخصوصية</h1>

                    <div className="space-y-8 text-gray-300 leading-relaxed">
                        <div>
                            <h2 className="text-xl font-bold text-white mb-3">١. نظرة عامة</h2>
                            <p>خصوصيتك أهم أولوياتنا. تطبيق «أذكاري» مصمم ليحترم خصوصية بياناتك بالكامل. نحن لا نجمع، ولا نخزن، ولا نشارك أي معلومات شخصية عنك.</p>
                        </div>

                        <div>
                            <h2 className="text-xl font-bold text-white mb-3">٢. البيانات التي نجمعها</h2>
                            <ul className="list-disc list-inside space-y-2 marker:text-primary">
                                <li>
                                    <strong className="text-white">الموقع الجغرافي:</strong> نطلب إذن الوصول للموقع فقط لحساب مواقيت الصلاة واتجاه القبلة بدقة. تتم هذه العملية محلياً على جهازك ولا تغادره أبداً.
                                </li>
                                <li>
                                    <strong className="text-white">التفضيلات والإعدادات:</strong> جميع إعداداتك وعدادات الأذكار تحفظ محلياً باستخدام تقنيات آبل الآمنة (UserDefaults/SwiftData).
                                </li>
                            </ul>
                        </div>

                        <div>
                            <h2 className="text-xl font-bold text-white mb-3">٣. خدمات الطرف الثالث</h2>
                            <p>نحن لا نستخدم أي أدوات تحليل أو إعلانات خارجية تقوم بتتبعك. التطبيق خالٍ تماماً من الإعلانات.</p>
                        </div>



                        <div className="pt-8 text-sm text-gray-500 border-t border-white/10">
                            آخر تحديث: ٣٠ يناير ٢٠٢٦
                        </div>
                    </div>
                </div>
            </main>

            <footer className="bg-background-dark py-8 border-t border-white/5 relative z-10">
                <div className="max-w-7xl mx-auto px-4 text-center">
                    <p className="text-gray-400 text-sm font-body">© 2026 تطبيق أذكاري. جميع الحقوق محفوظة.</p>
                </div>
            </footer>
        </>
    );
}
