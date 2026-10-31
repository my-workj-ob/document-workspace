import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../storage/storage_service.dart';

enum AppLanguage {
  uz('uz', 'O\'zbekcha', '🇺🇿'),
  ru('ru', 'Русский', '🇷🇺'),
  en('en', 'English', '🇬🇧');

  final String code;
  final String label;
  final String flag;

  const AppLanguage(this.code, this.label, this.flag);

  static AppLanguage fromCode(String code) {
    final clean = code.toLowerCase().trim();
    switch (clean) {
      case 'ru':
        return AppLanguage.ru;
      case 'en':
        return AppLanguage.en;
      case 'uz':
      default:
        return AppLanguage.uz;
    }
  }
}

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  final StorageService _storage;
  final String Function() _getBaseUrl;
  static const _key = 'selected_app_language';

  AppLanguageNotifier(this._storage, this._getBaseUrl) : super(AppLanguage.uz) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final code = await _storage.read(_key);
    if (code != null && code.isNotEmpty) {
      state = AppLanguage.fromCode(code);
    }
  }

  Future<void> setLanguage(AppLanguage language, {String? userToken}) async {
    state = language;
    await _storage.write(_key, language.code);

    // Sync to backend if token is available or stored
    final token = userToken ?? await _storage.read('jwt_access_token');
    if (token != null && token.isNotEmpty) {
      _syncToBackend(language.code, token);
    }
  }

  void setLanguageFromBackend(String code) {
    final lang = AppLanguage.fromCode(code);
    state = lang;
    _storage.write(_key, lang.code);
  }

  Future<void> _syncToBackend(String langCode, String token) async {
    try {
      final base = _getBaseUrl().replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/v1/me/locale');
      await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept-Language': langCode,
        },
        body: jsonEncode({'locale': langCode}),
      );
    } catch (_) {}
  }
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  final storage = StorageService();
  return AppLanguageNotifier(storage, () => ref.read(apiBaseUrlProvider));
});

/// Comprehensive Trilingual Dictionary for Cognidoc AI
class AppStrings {
  static String tr(String key, AppLanguage lang) {
    final map = _strings[key];
    if (map == null) return key;
    return map[lang] ?? map[AppLanguage.uz] ?? key;
  }

  static const Map<String, Map<AppLanguage, String>> _strings = {
    // -------------------------------------------------------------
    // NAVIGATION
    // -------------------------------------------------------------
    'nav_tools': {
      AppLanguage.uz: 'Asboblar',
      AppLanguage.ru: 'Инструменты',
      AppLanguage.en: 'Tools',
    },
    'nav_chat': {
      AppLanguage.uz: 'Chat',
      AppLanguage.ru: 'Чат',
      AppLanguage.en: 'Chat',
    },
    'nav_profile': {
      AppLanguage.uz: 'Profil',
      AppLanguage.ru: 'Профиль',
      AppLanguage.en: 'Profile',
    },

    // -------------------------------------------------------------
    // ONBOARDING (3 PAGES)
    // -------------------------------------------------------------
    'onb_page1_title': {
      AppLanguage.uz: 'Cognidoc AI — Ilm va Hujjatlar Uchun Mukammal AI',
      AppLanguage.ru: 'Cognidoc AI — Интеллектуальный анализ книг и документов',
      AppLanguage.en: 'Cognidoc AI — Intelligent Document & Study Assistant',
    },
    'onb_page1_subtitle': {
      AppLanguage.uz:
          'Katta hajmdagi darslik, kitob va ilmiy tadqiqotlarni bir necha soniyada tahlil qiling. AI sizga kerakli boblarni saralab beradi.',
      AppLanguage.ru:
          'Мгновенный разбор объемных учебников, книг и научных статей. Искусственный интеллект выделит суть за считанные секунды.',
      AppLanguage.en:
          'Instantly analyze heavy textbooks, research papers, and complex documents. AI distills key concepts in seconds.',
    },
    'onb_page2_title': {
      AppLanguage.uz: 'Tezkor Konspekt, Testlar va Flesh-kartalar',
      AppLanguage.ru: 'Умные конспекты, тесты и интерактивные карточки',
      AppLanguage.en: 'Smart Notes, Exam Quizzes & Flashcards',
    },
    'onb_page2_subtitle': {
      AppLanguage.uz:
          'Imtihon va darslarga tayyorlanish uchun matndan avtomatik ravishda 4 variantli testlar va interaktiv kartochkalar yarating.',
      AppLanguage.ru:
          'Автоматическая генерация экзаменационных тестов с 4 вариантами ответов и флеш-карточек для эффективного запоминания.',
      AppLanguage.en:
          'Generate 4-option exam-ready quizzes and active recall flashcards directly from any textbook chapter.',
    },
    'onb_page3_title': {
      AppLanguage.uz: 'Sahifama-sahifa 100% Aniq Manbalar (Citations)',
      AppLanguage.ru: 'Постраничные точные цитаты без выдумок',
      AppLanguage.en: '100% Reliable Answers with Page Citations',
    },
    'onb_page3_subtitle': {
      AppLanguage.uz:
          'Bizning AI yolg\'on ma\'lumot to\'qimaydi. Har bir javob kitobning aynan qaysi sahifasidan olinganini ko\'rsatib beradi.',
      AppLanguage.ru:
          'Никаких галлюцинаций ИИ. Каждый ответ подкреплен точной ссылкой на страницу исходного учебника или документа.',
      AppLanguage.en:
          'Zero AI hallucinations. Every single answer is grounded with verifiable page-level citations from your source files.',
    },
    'onb_btn_continue': {
      AppLanguage.uz: 'Davom etish',
      AppLanguage.ru: 'Продолжить',
      AppLanguage.en: 'Continue',
    },
    'onb_btn_back': {
      AppLanguage.uz: 'Orqaga',
      AppLanguage.ru: 'Назад',
      AppLanguage.en: 'Back',
    },
    'onb_btn_skip': {
      AppLanguage.uz: 'O\'tkazib yuborish',
      AppLanguage.ru: 'Пропустить',
      AppLanguage.en: 'Skip',
    },

    // -------------------------------------------------------------
    // LANGUAGE SELECTION SCREEN
    // -------------------------------------------------------------
    'lang_screen_title': {
      AppLanguage.uz: 'Ilova tilini tanlang',
      AppLanguage.ru: 'Выберите язык приложения',
      AppLanguage.en: 'Choose App Language',
    },
    'lang_screen_subtitle': {
      AppLanguage.uz:
          'Cognidoc AI interfeysi va barcha sun\'iy intellekt tahlillari tanlangan tilda ishlaydi.',
      AppLanguage.ru:
          'Интерфейс Cognidoc AI и все аналитические ответы искусственного интеллекта адаптируются под выбранный язык.',
      AppLanguage.en:
          'Cognidoc AI interface and all generative study outputs will seamlessly adapt to your selected language.',
    },
    'lang_uz_title': {
      AppLanguage.uz: 'O\'zbekcha',
      AppLanguage.ru: 'Узбекский (O\'zbekcha)',
      AppLanguage.en: 'Uzbek (O\'zbekcha)',
    },
    'lang_uz_desc': {
      AppLanguage.uz: 'To\'liq o\'zbek tilidagi interfeys va AI javoblari',
      AppLanguage.ru: 'Полный узбекский интерфейс и ответы ИИ',
      AppLanguage.en: 'Full Uzbek UI & AI generation',
    },
    'lang_ru_title': {
      AppLanguage.uz: 'Русский',
      AppLanguage.ru: 'Русский',
      AppLanguage.en: 'Russian (Русский)',
    },
    'lang_ru_desc': {
      AppLanguage.uz: 'Rus tilidagi akademik interfeys va tahlillar',
      AppLanguage.ru: 'Академический русский интерфейс и глубокая аналитика',
      AppLanguage.en: 'Academic Russian interface & in-depth analysis',
    },
    'lang_en_title': {
      AppLanguage.uz: 'English',
      AppLanguage.ru: 'Английский (English)',
      AppLanguage.en: 'English',
    },
    'lang_en_desc': {
      AppLanguage.uz: 'Xalqaro ilmiy darajadagi ingliz tili',
      AppLanguage.ru: 'Международный научный и академический английский',
      AppLanguage.en: 'Global academic & research standard',
    },
    'lang_btn_confirm': {
      AppLanguage.uz: 'Tasdiqlash va Boshlash',
      AppLanguage.ru: 'Подтвердить и начать',
      AppLanguage.en: 'Confirm & Continue',
    },

    // -------------------------------------------------------------
    // AUTHENTICATION (LOGIN / REGISTER)
    // -------------------------------------------------------------
    'auth_login_title': {
      AppLanguage.uz: 'Tizimga kirish',
      AppLanguage.ru: 'Вход в аккаунт',
      AppLanguage.en: 'Sign In',
    },
    'auth_login_subtitle': {
      AppLanguage.uz: 'O\'qish va tadqiqotlaringizni davom ettirish uchun kiring',
      AppLanguage.ru: 'Войдите, чтобы продолжить учебу и анализ материалов',
      AppLanguage.en: 'Log in to continue your academic research and studies',
    },
    'auth_register_title': {
      AppLanguage.uz: 'Ro\'yxatdan o\'tish',
      AppLanguage.ru: 'Регистрация',
      AppLanguage.en: 'Create Account',
    },
    'auth_register_subtitle': {
      AppLanguage.uz: 'Cognidoc AI platformasida bepul hisob oching',
      AppLanguage.ru: 'Создайте бесплатный аккаунт в системе Cognidoc AI',
      AppLanguage.en: 'Create your free account on Cognidoc AI',
    },
    'auth_email_label': {
      AppLanguage.uz: 'Email manzili',
      AppLanguage.ru: 'Электронная почта',
      AppLanguage.en: 'Email Address',
    },
    'auth_email_hint': {
      AppLanguage.uz: 'misol@student.edu',
      AppLanguage.ru: 'example@university.edu',
      AppLanguage.en: 'example@university.edu',
    },
    'auth_password_label': {
      AppLanguage.uz: 'Parol',
      AppLanguage.ru: 'Пароль',
      AppLanguage.en: 'Password',
    },
    'auth_password_hint': {
      AppLanguage.uz: 'Kamida 8 ta belgi',
      AppLanguage.ru: 'Минимум 8 символов',
      AppLanguage.en: 'At least 8 characters',
    },
    'auth_fullname_label': {
      AppLanguage.uz: 'Ism va familiya',
      AppLanguage.ru: 'Имя и фамилия',
      AppLanguage.en: 'Full Name',
    },
    'auth_fullname_hint': {
      AppLanguage.uz: 'Ali Valiyev',
      AppLanguage.ru: 'Иван Иванов',
      AppLanguage.en: 'John Doe',
    },
    'auth_login_btn': {
      AppLanguage.uz: 'Kirish',
      AppLanguage.ru: 'Войти',
      AppLanguage.en: 'Sign In',
    },
    'auth_register_btn': {
      AppLanguage.uz: 'Ro\'yxatdan o\'tish',
      AppLanguage.ru: 'Зарегистрироваться',
      AppLanguage.en: 'Create Account',
    },
    'auth_no_account': {
      AppLanguage.uz: 'Hali hisobingiz yo\'qmi? ',
      AppLanguage.ru: 'Еще нет аккаунта? ',
      AppLanguage.en: 'Don\'t have an account? ',
    },
    'auth_have_account': {
      AppLanguage.uz: 'Allaqachon hisobingiz bormi? ',
      AppLanguage.ru: 'Уже зарегистрированы? ',
      AppLanguage.en: 'Already have an account? ',
    },
    'auth_sign_up_link': {
      AppLanguage.uz: 'Ro\'yxatdan o\'ting',
      AppLanguage.ru: 'Создать аккаунт',
      AppLanguage.en: 'Sign Up',
    },
    'auth_sign_in_link': {
      AppLanguage.uz: 'Kirish',
      AppLanguage.ru: 'Войти',
      AppLanguage.en: 'Sign In',
    },
    'auth_val_email_empty': {
      AppLanguage.uz: 'Iltimos, email manzilini kiriting',
      AppLanguage.ru: 'Пожалуйста, укажите адрес электронной почты',
      AppLanguage.en: 'Please enter your email address',
    },
    'auth_val_email_invalid': {
      AppLanguage.uz: 'Yaroqli email manzilini kiriting',
      AppLanguage.ru: 'Введите корректный адрес электронной почты',
      AppLanguage.en: 'Please enter a valid email address',
    },
    'auth_val_pwd_short': {
      AppLanguage.uz: 'Parol kamida 8 ta belgidan iborat bo\'lishi shart',
      AppLanguage.ru: 'Пароль должен содержать не менее 8 символов',
      AppLanguage.en: 'Password must be at least 8 characters long',
    },
    'auth_val_name_empty': {
      AppLanguage.uz: 'Iltimos, ismingizni kiriting',
      AppLanguage.ru: 'Пожалуйста, введите ваше имя',
      AppLanguage.en: 'Please enter your full name',
    },

    // -------------------------------------------------------------
    // EXPLORE / EDUCATION TOOLS
    // -------------------------------------------------------------
    'app_title': {
      AppLanguage.uz: 'Cognidoc AI • Ta\'lim & Kitoblar',
      AppLanguage.ru: 'Cognidoc AI • Образование и Книги',
      AppLanguage.en: 'Cognidoc AI • Education & Books',
    },
    'hero_title': {
      AppLanguage.uz: 'Ta\'lim va Ilm-fan uchun Sun\'iy Intellekt',
      AppLanguage.ru: 'Искусственный интеллект для учебы и науки',
      AppLanguage.en: 'Artificial Intelligence for Education & Study',
    },
    'hero_subtitle': {
      AppLanguage.uz:
          'Darslik, kitob va ilmiy maqolalarni bir zumda tahlil qiling, testlar tuzing va konspekt oling',
      AppLanguage.ru:
          'Мгновенный анализ учебников и научных статей, генерация тестов и умные конспекты',
      AppLanguage.en:
          'Instantly analyze textbooks, research papers, generate quizzes, and create smart notes',
    },
    'search_placeholder': {
      AppLanguage.uz: 'Darslik, fan yoki mavzuni qidiring...',
      AppLanguage.ru: 'Поиск учебников, предметов или тем...',
      AppLanguage.en: 'Search textbooks, subjects, or topics...',
    },
    'ready_sample': {
      AppLanguage.uz: 'Tayyor namunalar bilan sinab ko\'ring:',
      AppLanguage.ru: 'Попробуйте с готовыми примерами:',
      AppLanguage.en: 'Try with ready-to-use samples:',
    },
    'sample_physics': {
      AppLanguage.uz: '📚 Fizika va Matematika darsligi',
      AppLanguage.ru: '📚 Учебник по физике и математике',
      AppLanguage.en: '📚 Physics & Math Textbook',
    },
    'sample_quiz': {
      AppLanguage.uz: '🎓 Imtihon uchun Test (15 ta)',
      AppLanguage.ru: '🎓 Тест для экзамена (15 вопросов)',
      AppLanguage.en: '🎓 Exam Prep Quiz (15 Qs)',
    },
    'sample_summary': {
      AppLanguage.uz: '📝 Qisqa Konspekt & Formulalar',
      AppLanguage.ru: '📝 Краткий конспект и формулы',
      AppLanguage.en: '📝 Smart Study Notes & Formulas',
    },
    'sample_language': {
      AppLanguage.uz: '🌍 Ingliz tili: Lug\'at va Grammatika',
      AppLanguage.ru: '🌍 Изучение языка: Словарь и грамматика',
      AppLanguage.en: '🌍 Language: Vocab & Grammar',
    },
    'education_tools': {
      AppLanguage.uz: 'Ta\'lim Asboblari',
      AppLanguage.ru: 'Инструменты обучения',
      AppLanguage.en: 'Education Tools',
    },
    'all_count': {
      AppLanguage.uz: '8 ta rejim',
      AppLanguage.ru: '8 режимов',
      AppLanguage.en: '8 modes',
    },

    // -------------------------------------------------------------
    // CHAT & AI INTERFACE
    // -------------------------------------------------------------
    'chat_empty_title': {
      AppLanguage.uz: 'Darslik yoki kitobni tahlil qilishni boshlang',
      AppLanguage.ru: 'Начните анализ учебника или документа',
      AppLanguage.en: 'Start analyzing your textbook or document',
    },
    'chat_empty_subtitle': {
      AppLanguage.uz:
          'Fayl yuklang (PDF, Word, rasm) yoki savolingizni yozing. AI darslik asosida aniq tahlil beradi.',
      AppLanguage.ru:
          'Загрузите файл (PDF, Word, фото) или задайте вопрос. ИИ предоставит точный ответ со ссылками на страницы.',
      AppLanguage.en:
          'Upload a file (PDF, Word, photo) or ask a question. AI provides structured answers with page citations.',
    },
    'chat_input_placeholder': {
      AppLanguage.uz: 'Savolingizni yozing yoki kitob bo\'limini so\'rang...',
      AppLanguage.ru: 'Задайте вопрос или запросите главу из книги...',
      AppLanguage.en: 'Ask a question or request a chapter review...',
    },
    'chat_attach_file': {
      AppLanguage.uz: 'Hujjat biriktirish (PDF/Word/Rasm)',
      AppLanguage.ru: 'Прикрепить документ (PDF/Word/Фото)',
      AppLanguage.en: 'Attach Document (PDF/Word/Photo)',
    },
    'chat_copied': {
      AppLanguage.uz: 'Matn nusxalandi',
      AppLanguage.ru: 'Текст скопирован',
      AppLanguage.en: 'Text copied to clipboard',
    },
    'chat_citation_sources': {
      AppLanguage.uz: 'Hujjatdan aniq manbalar:',
      AppLanguage.ru: 'Источники из документа:',
      AppLanguage.en: 'Citations from document:',
    },
    'chat_stop_generating': {
      AppLanguage.uz: 'To\'xtatish',
      AppLanguage.ru: 'Остановить',
      AppLanguage.en: 'Stop generating',
    },
    'chat_new_dialog': {
      AppLanguage.uz: 'Yangi suhbat',
      AppLanguage.ru: 'Новый диалог',
      AppLanguage.en: 'New Conversation',
    },
    'chat_clear_confirm': {
      AppLanguage.uz: 'Barcha suhbatlar tarixini tozalashni xohlaysizmi?',
      AppLanguage.ru: 'Вы уверены, что хотите очистить историю чатов?',
      AppLanguage.en: 'Are you sure you want to clear chat history?',
    },

    // -------------------------------------------------------------
    // PROFILE & SETTINGS
    // -------------------------------------------------------------
    'profile_title': {
      AppLanguage.uz: 'Mening Profilim',
      AppLanguage.ru: 'Мой Профиль',
      AppLanguage.en: 'My Profile',
    },
    'profile_active_plan': {
      AppLanguage.uz: 'FAOL TARIF REJASI',
      AppLanguage.ru: 'АКТИВНЫЙ ТАРИФ',
      AppLanguage.en: 'ACTIVE SUBSCRIPTION',
    },
    'profile_daily_remaining': {
      AppLanguage.uz: 'Bugungi qolgan so\'rovlar:',
      AppLanguage.ru: 'Оставшиеся запросы на сегодня:',
      AppLanguage.en: 'Remaining requests today:',
    },
    'profile_plans_table': {
      AppLanguage.uz: 'Tariflar jadvali',
      AppLanguage.ru: 'Таблица тарифов',
      AppLanguage.en: 'Pricing Plans',
    },
    'profile_upgrade_pro': {
      AppLanguage.uz: 'Pro Tarifga O\'tish',
      AppLanguage.ru: 'Перейти на Pro тариф',
      AppLanguage.en: 'Upgrade to Pro',
    },
    'profile_app_presentation': {
      AppLanguage.uz: 'Ilova taqdimoti va qo\'llanma',
      AppLanguage.ru: 'Презентация и руководство',
      AppLanguage.en: 'App Presentation & Guide',
    },
    'profile_app_presentation_desc': {
      AppLanguage.uz: 'Cognidoc AI imkoniyatlari va tezkor qo\'llanma',
      AppLanguage.ru: 'Возможности Cognidoc AI и быстрый тур',
      AppLanguage.en: 'Cognidoc AI capabilities & quick tour',
    },
    'profile_settings_tile': {
      AppLanguage.uz: 'Sozlamalar va Konfiguratsiya',
      AppLanguage.ru: 'Настройки и Конфигурация',
      AppLanguage.en: 'Settings & Configuration',
    },
    'profile_settings_desc': {
      AppLanguage.uz: 'Ilova tili, mavzu va ovoz effektlari',
      AppLanguage.ru: 'Язык приложения, тема и звуки',
      AppLanguage.en: 'App language, theme, and sounds',
    },
    'profile_delete_account': {
      AppLanguage.uz: 'Hisobni butunlay o\'chirish',
      AppLanguage.ru: 'Удалить аккаунт навсегда',
      AppLanguage.en: 'Delete Account Permanently',
    },
    'profile_delete_desc': {
      AppLanguage.uz: 'Hisobingiz va barcha fayllar butunlay o\'chiriladi',
      AppLanguage.ru: 'Ваш аккаунт и все файлы будут безвозвратно удалены',
      AppLanguage.en: 'All your account data and files will be wiped',
    },
    'settings_title': {
      AppLanguage.uz: 'Sozlamalar',
      AppLanguage.ru: 'Настройки',
      AppLanguage.en: 'Settings',
    },
    'settings_language': {
      AppLanguage.uz: 'Ilova tili',
      AppLanguage.ru: 'Язык приложения',
      AppLanguage.en: 'App Language',
    },
    'theme_dark': {
      AppLanguage.uz: 'Tungi rejim',
      AppLanguage.ru: 'Темная тема',
      AppLanguage.en: 'Dark Mode',
    },
    'theme_dark_desc': {
      AppLanguage.uz: 'Ko\'zga qulay qora mavzuni yoqish',
      AppLanguage.ru: 'Включить комфортную темную тему',
      AppLanguage.en: 'Enable eye-friendly dark theme',
    },
    'sound_effects': {
      AppLanguage.uz: 'Ovozli effektlar (Haptic)',
      AppLanguage.ru: 'Звуковые эффекты и тактильный отклик',
      AppLanguage.en: 'Sound Effects & Haptics',
    },
    'logout': {
      AppLanguage.uz: 'Hisobdan chiqish',
      AppLanguage.ru: 'Выйти из аккаунта',
      AppLanguage.en: 'Log Out',
    },
    'logout_confirm': {
      AppLanguage.uz: 'Haqiqatan ham hisobingizdan chiqmoqchimisiz?',
      AppLanguage.ru: 'Вы уверены, что хотите выйти из аккаунта?',
      AppLanguage.en: 'Are you sure you want to log out?',
    },

    // -------------------------------------------------------------
    // PRICING & SUBSCRIPTION
    // -------------------------------------------------------------
    'plans_title': {
      AppLanguage.uz: 'Tarif Rejalari',
      AppLanguage.ru: 'Тарифные Планы',
      AppLanguage.en: 'Subscription Plans',
    },
    'plans_subtitle': {
      AppLanguage.uz: 'Ta\'lim va ilmiy ishlaringiz uchun eng mos rejani tanlang',
      AppLanguage.ru: 'Выберите оптимальный план для эффективной учебы и исследований',
      AppLanguage.en: 'Choose the ideal plan for your academic workflow and studies',
    },
    'plan_free': {
      AppLanguage.uz: 'Bepul (Free)',
      AppLanguage.ru: 'Бесплатный (Free)',
      AppLanguage.en: 'Free Plan',
    },
    'plan_pro': {
      AppLanguage.uz: 'Pro Obuna',
      AppLanguage.ru: 'Тариф Pro',
      AppLanguage.en: 'Pro Plan',
    },
    'plan_ultra': {
      AppLanguage.uz: 'Ultra Tadqiqotchi',
      AppLanguage.ru: 'Тариф Ultra',
      AppLanguage.en: 'Ultra Plan',
    },
    'plan_subscribe_btn': {
      AppLanguage.uz: 'Obunani faollashtirish',
      AppLanguage.ru: 'Оформить подписку',
      AppLanguage.en: 'Subscribe Now',
    },
    'plan_current': {
      AppLanguage.uz: 'Faol reja',
      AppLanguage.ru: 'Текущий план',
      AppLanguage.en: 'Current Plan',
    },

    // -------------------------------------------------------------
    // COMMON DIALOG ACTIONS
    // -------------------------------------------------------------
    'confirm': {
      AppLanguage.uz: 'Tasdiqlash',
      AppLanguage.ru: 'Подтвердить',
      AppLanguage.en: 'Confirm',
    },
    'cancel': {
      AppLanguage.uz: 'Bekor qilish',
      AppLanguage.ru: 'Отмена',
      AppLanguage.en: 'Cancel',
    },
    'close': {
      AppLanguage.uz: 'Yopish',
      AppLanguage.ru: 'Закрыть',
      AppLanguage.en: 'Close',
    },
    'save': {
      AppLanguage.uz: 'Saqlash',
      AppLanguage.ru: 'Сохранить',
      AppLanguage.en: 'Save',
    },
    'delete': {
      AppLanguage.uz: 'O\'chirish',
      AppLanguage.ru: 'Удалить',
      AppLanguage.en: 'Delete',
    },

    // -------------------------------------------------------------
    // PROFILE EXTENDED
    // -------------------------------------------------------------
    'profile_section_plan': {
      AppLanguage.uz: 'TARIF VA OBUNA',
      AppLanguage.ru: 'ТАРИФ И ПОДПИСКА',
      AppLanguage.en: 'PLAN & SUBSCRIPTION',
    },
    'profile_section_settings': {
      AppLanguage.uz: 'ILOVA SOZLAMALARI',
      AppLanguage.ru: 'НАСТРОЙКИ ПРИЛОЖЕНИЯ',
      AppLanguage.en: 'APP SETTINGS',
    },
    'profile_section_security': {
      AppLanguage.uz: 'XAVFSIZLIK VA HISOB AMALLARI',
      AppLanguage.ru: 'БЕЗОПАСНОСТЬ И АККАУНТ',
      AppLanguage.en: 'SECURITY & ACCOUNT',
    },
    'profile_privacy_policy': {
      AppLanguage.uz: 'Maxfiylik siyosati (Privacy Policy)',
      AppLanguage.ru: 'Политика конфиденциальности (Privacy Policy)',
      AppLanguage.en: 'Privacy Policy',
    },
    'profile_terms_service': {
      AppLanguage.uz: 'Foydalanish shartlari (Terms of Service)',
      AppLanguage.ru: 'Условия использования (Terms of Service)',
      AppLanguage.en: 'Terms of Service',
    },
    'profile_copied_link': {
      AppLanguage.uz: 'Havola buferga nusxalandi',
      AppLanguage.ru: 'Ссылка скопирована в буфер',
      AppLanguage.en: 'Link copied to clipboard',
    },
    'profile_delete_dialog_title': {
      AppLanguage.uz: 'Hisobni butunlay o\'chirish',
      AppLanguage.ru: 'Удаление аккаунта навсегда',
      AppLanguage.en: 'Permanently Delete Account',
    },
    'profile_delete_dialog_content': {
      AppLanguage.uz:
          'Hisobingiz, barcha suhbatlaringiz, yuklangan fayllaringiz va ma\'lumotlaringiz butunlay o\'chiriladi. Bu amalni ortga qaytarib bo\'lmaydi.',
      AppLanguage.ru:
          'Ваш аккаунт, все диалоги, загруженные документы и данные будут безвозвратно удалены. Это действие необратимо.',
      AppLanguage.en:
          'Your account, conversations, uploaded files, and all associated data will be permanently wiped. This action cannot be undone.',
    },
    'profile_delete_confirm_btn': {
      AppLanguage.uz: 'Ha, o\'chirilsin',
      AppLanguage.ru: 'Да, удалить навсегда',
      AppLanguage.en: 'Yes, Delete Permanently',
    },
    'profile_delete_success': {
      AppLanguage.uz: 'Hisobingiz va barcha ma\'lumotlaringiz muvaffaqiyatli o\'chirildi.',
      AppLanguage.ru: 'Ваш аккаунт и все данные успешно удалены.',
      AppLanguage.en: 'Your account and data were successfully deleted.',
    },
    'profile_delete_error': {
      AppLanguage.uz: 'Hisobni o\'chirishda xatolik yuz berdi.',
      AppLanguage.ru: 'Ошибка при удалении аккаунта.',
      AppLanguage.en: 'Failed to delete account.',
    },
    'profile_default_user': {
      AppLanguage.uz: 'Foydalanuvchi',
      AppLanguage.ru: 'Пользователь',
      AppLanguage.en: 'User',
    },
    'profile_language_tile': {
      AppLanguage.uz: 'Tilni tanlash / Language',
      AppLanguage.ru: 'Выбор языка / Language',
      AppLanguage.en: 'Choose Language',
    },
    'profile_language_desc': {
      AppLanguage.uz: 'Joriy tanlangan til: ',
      AppLanguage.ru: 'Текущий язык интерфейса: ',
      AppLanguage.en: 'Current app language: ',
    },

    // -------------------------------------------------------------
    // SETTINGS EXTENDED
    // -------------------------------------------------------------
    'settings_appearance_section': {
      AppLanguage.uz: 'KO\'RINISh VA MAVZU',
      AppLanguage.ru: 'ВНЕШНИЙ ВИД И ТЕМА',
      AppLanguage.en: 'APPEARANCE & THEME',
    },
    'settings_theme_dark_title': {
      AppLanguage.uz: 'Tungi mavzu (Dark mode)',
      AppLanguage.ru: 'Темная тема (Dark mode)',
      AppLanguage.en: 'Dark Mode',
    },
    'settings_theme_dark_desc': {
      AppLanguage.uz: 'Cognidoc AI uslubidagi quyuq qora ranglar',
      AppLanguage.ru: 'Глубокие темные тона в стиле Cognidoc AI',
      AppLanguage.en: 'Sleek dark colors for high focus',
    },
    'settings_theme_light_title': {
      AppLanguage.uz: 'Kunduzgi mavzu (Light mode)',
      AppLanguage.ru: 'Светлая тема (Light mode)',
      AppLanguage.en: 'Light Mode',
    },
    'settings_theme_light_desc': {
      AppLanguage.uz: 'Yorqin oq va toza interfeys',
      AppLanguage.ru: 'Светлый чистый интерфейс',
      AppLanguage.en: 'Clean and bright interface',
    },
    'settings_theme_system_title': {
      AppLanguage.uz: 'Tizim sozlamalari (System)',
      AppLanguage.ru: 'Системная тема (System)',
      AppLanguage.en: 'System Default',
    },
    'settings_theme_system_desc': {
      AppLanguage.uz: 'Qurilma sozlamalariga moslashish',
      AppLanguage.ru: 'Следовать настройкам устройства',
      AppLanguage.en: 'Match device system settings',
    },
    'settings_network_section': {
      AppLanguage.uz: 'SERVER TARMOQ SOZLAMALARI',
      AppLanguage.ru: 'СЕТЕВЫЕ НАСТРОЙКИ СЕРВЕРА',
      AppLanguage.en: 'SERVER NETWORK SETTINGS',
    },
    'settings_api_saved': {
      AppLanguage.uz: 'Server manzili muvaffaqiyatli saqlandi',
      AppLanguage.ru: 'Адрес сервера успешно сохранен',
      AppLanguage.en: 'Server address successfully saved',
    },
    'settings_api_reset': {
      AppLanguage.uz: 'Standart manzil qaytarildi',
      AppLanguage.ru: 'Восстановлен стандартный адрес',
      AppLanguage.en: 'Reset to default address',
    },
    'settings_default_btn': {
      AppLanguage.uz: 'Standart',
      AppLanguage.ru: 'По умолчанию',
      AppLanguage.en: 'Default',
    },
    'settings_account_section': {
      AppLanguage.uz: 'FOYDALANUVCHI HISOBI',
      AppLanguage.ru: 'АККАУНТ ПОЛЬЗОВАТЕЛЯ',
      AppLanguage.en: 'USER ACCOUNT',
    },
    'settings_pro_active': {
      AppLanguage.uz: 'PRO FAOL',
      AppLanguage.ru: 'PRO АКТИВЕН',
      AppLanguage.en: 'PRO ACTIVE',
    },
    'settings_free_badge': {
      AppLanguage.uz: 'BEPUL',
      AppLanguage.ru: 'БЕСПЛАТНО',
      AppLanguage.en: 'FREE',
    },
    'settings_upgrade_play_btn': {
      AppLanguage.uz: 'Pro tarifiga o\'tish (Google Play / Karta)',
      AppLanguage.ru: 'Перейти на Pro (Google Play / Карта)',
      AppLanguage.en: 'Upgrade to Pro (Google Play / Card)',
    },
    'settings_manage_sub_btn': {
      AppLanguage.uz: 'Obunani boshqarish / Tarifni o\'zgartirish',
      AppLanguage.ru: 'Управление подпиской / Сменить тариф',
      AppLanguage.en: 'Manage Subscription / Change Plan',
    },
    'settings_view_all_plans': {
      AppLanguage.uz: 'Barcha tariflarni ko\'rish va tanlash',
      AppLanguage.ru: 'Посмотреть все тарифные планы',
      AppLanguage.en: 'View all pricing plans',
    },

    // -------------------------------------------------------------
    // PLANS & PAYMENTS
    // -------------------------------------------------------------
    'plans_header_label': {
      AppLanguage.uz: 'AI IMKONIYATLARINI OCHING',
      AppLanguage.ru: 'ОТКРОЙТЕ ВСЕ ВОЗМОЖНОСТИ ИИ',
      AppLanguage.en: 'UNLOCK ADVANCED AI CAPABILITIES',
    },
    'plans_header_desc': {
      AppLanguage.uz:
          'O\'zingizga mos tarifni tanlang. Istalgan vaqtda Google Play orqali yangilash yoki bekor qilish mumkin.',
      AppLanguage.ru:
          'Выберите подходящий тариф. Обновление или отмена подписки доступны в любой момент через Google Play.',
      AppLanguage.en:
          'Choose the right plan for you. Upgrade or cancel anytime via Google Play.',
    },
    'plans_restore_btn': {
      AppLanguage.uz: 'Tiklash',
      AppLanguage.ru: 'Восстановить',
      AppLanguage.en: 'Restore',
    },
    'plans_restore_success': {
      AppLanguage.uz: 'Xaridlar muvaffaqiyatli tiklandi!',
      AppLanguage.ru: 'Покупки успешно восстановлены!',
      AppLanguage.en: 'Purchases successfully restored!',
    },
    'plans_restore_not_found': {
      AppLanguage.uz: 'Faol xaridlar topilmadi.',
      AppLanguage.ru: 'Активные покупки не найдены.',
      AppLanguage.en: 'No active purchases found.',
    },
    'plans_current_prefix': {
      AppLanguage.uz: 'Sizning tarifingiz: ',
      AppLanguage.ru: 'Ваш тариф: ',
      AppLanguage.en: 'Your plan: ',
    },
    'plans_recommended_badge': {
      AppLanguage.uz: 'ENG TAVSIYA ETILADI',
      AppLanguage.ru: 'РЕКОМЕНДУЕМЫЙ',
      AppLanguage.en: 'MOST POPULAR',
    },
    'plans_professional_badge': {
      AppLanguage.uz: 'PROFESSIONAL',
      AppLanguage.ru: 'ПРОФЕССИОНАЛЬНЫЙ',
      AppLanguage.en: 'PROFESSIONAL',
    },
    'plans_choose_pro_btn': {
      AppLanguage.uz: 'Pro Tarifini Tanlash (\$9.99 / oy)',
      AppLanguage.ru: 'Выбрать тариф Pro (\$9.99 / мес)',
      AppLanguage.en: 'Select Pro Plan (\$9.99 / mo)',
    },
    'plans_choose_ultra_btn': {
      AppLanguage.uz: 'Ultra Tarifini Tanlash (\$24.99 / oy)',
      AppLanguage.ru: 'Выбрать тариф Ultra (\$24.99 / мес)',
      AppLanguage.en: 'Select Ultra Plan (\$24.99 / mo)',
    },

    // -------------------------------------------------------------
    // CHAT EXTENDED
    // -------------------------------------------------------------
    'chat_rename_dialog_title': {
      AppLanguage.uz: 'Suhbat nomini o\'zgartirish',
      AppLanguage.ru: 'Переименовать диалог',
      AppLanguage.en: 'Rename Conversation',
    },
    'chat_rename_hint': {
      AppLanguage.uz: 'Yangi nom kiriting...',
      AppLanguage.ru: 'Новое название...',
      AppLanguage.en: 'Enter new title...',
    },
    'chat_history_tooltip': {
      AppLanguage.uz: 'Suhbatlar tarixi',
      AppLanguage.ru: 'История диалогов',
      AppLanguage.en: 'Conversation History',
    },
    'chat_actions_tooltip': {
      AppLanguage.uz: 'Suhbat amallari',
      AppLanguage.ru: 'Действия с диалогом',
      AppLanguage.en: 'Chat Actions',
    },
    'chat_copy_full': {
      AppLanguage.uz: 'Suhbatni nusxalash',
      AppLanguage.ru: 'Скопировать весь чат',
      AppLanguage.en: 'Copy Full Chat',
    },
    'chat_copy_full_done': {
      AppLanguage.uz: '📋 Butun suhbat xotiraga nusxalandi!',
      AppLanguage.ru: '📋 Весь диалог скопирован в буфер!',
      AppLanguage.en: '📋 Entire conversation copied to clipboard!',
    },
    'chat_clear_start': {
      AppLanguage.uz: 'Toza suhbat boshlash',
      AppLanguage.ru: 'Начать чистый диалог',
      AppLanguage.en: 'Start Fresh Chat',
    },
    'chat_how_can_help': {
      AppLanguage.uz: 'Qanday yordam bera olaman?',
      AppLanguage.ru: 'Чем я могу помочь вам?',
      AppLanguage.en: 'How can I assist your study today?',
    },
    'chat_help_desc': {
      AppLanguage.uz:
          'Darslik, tahlil, formulalar yoki referat mavzusini yuborib savol bering.',
      AppLanguage.ru:
          'Загрузите учебник, задачу, формулы или тему реферата для детального разбора.',
      AppLanguage.en:
          'Upload textbooks, lecture notes, complex formulas, or research papers to analyze.',
    },
    'chat_new_messages_badge': {
      AppLanguage.uz: 'Yangi xabarlar',
      AppLanguage.ru: 'Новые сообщения',
      AppLanguage.en: 'New messages',
    },
    'chat_files_uploading': {
      AppLanguage.uz: '⏳ Fayllar serverga yuklanmoqda, kuting...',
      AppLanguage.ru: '⏳ Файлы загружаются на сервер, подождите...',
      AppLanguage.en: '⏳ Files are uploading to server, please wait...',
    },
    'chat_file_upload_limit': {
      AppLanguage.uz: 'Bitta xabarga ko\'pi bilan 5 ta fayl biriktirish mumkin.',
      AppLanguage.ru: 'К одному сообщению можно прикрепить максимум 5 файлов.',
      AppLanguage.en: 'You can attach a maximum of 5 files per message.',
    },
    'chat_magic_prompt_title': {
      AppLanguage.uz: 'Sehrli Prompt Yordamchisi',
      AppLanguage.ru: 'Умный генератор промптов',
      AppLanguage.en: 'Smart Prompt Enhancer',
    },
    'chat_magic_prompt_desc': {
      AppLanguage.uz: 'Bir marta bosish bilan tayyor va samarali ta\'limiy promptni kiriting:',
      AppLanguage.ru: 'Вставьте готовый академический промпт в один клик:',
      AppLanguage.en: 'Insert a high-yield academic study prompt with one tap:',
    },
    'chat_magic_enhanced_done': {
      AppLanguage.uz: '✨ Savolingiz professional shaklga boyitildi!',
      AppLanguage.ru: '✨ Ваш запрос дополнен до профессионального уровня!',
      AppLanguage.en: '✨ Your prompt has been professionally enhanced!',
    },
  };
}
