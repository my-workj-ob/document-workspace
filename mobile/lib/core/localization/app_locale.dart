import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    switch (code) {
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
  static const _key = 'selected_app_language';

  AppLanguageNotifier(this._storage) : super(AppLanguage.uz) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final code = await _storage.read(_key);
    if (code != null) {
      state = AppLanguage.fromCode(code);
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    await _storage.write(_key, language.code);
  }
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier(StorageService());
});

/// Centralized 3-language translations dictionary for Education AI Super-App
class AppStrings {
  static String tr(String key, AppLanguage lang) {
    final map = _strings[key];
    if (map == null) return key;
    return map[lang] ?? map[AppLanguage.uz] ?? key;
  }

  static const Map<String, Map<AppLanguage, String>> _strings = {
    // Navigation
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

    // Header & Titles
    'app_title': {
      AppLanguage.uz: 'EduAI • Ta\'lim & Kitoblar',
      AppLanguage.ru: 'EduAI • Образование и Книги',
      AppLanguage.en: 'EduAI • Education & Books',
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

    // Education Sample Chips
    'sample_physics': {
      AppLanguage.uz: '📚 Fizika va Matematika darsligi',
      AppLanguage.ru: '📚 Учебник по физике и математике',
      AppLanguage.en: '📚 Physics & Math Textbook',
    },
    'sample_physics_prompt': {
      AppLanguage.uz:
          'Darslikdagi Nyuton qonunlari va asosiy formulalarni amaliy misollar bilan sodda tilda tushuntirib bering.',
      AppLanguage.ru:
          'Объясните законы Ньютона и основные формулы простым языком с практическими примерами.',
      AppLanguage.en:
          'Explain Newton\'s laws and main formulas in simple terms with practical everyday examples.',
    },
    'sample_quiz': {
      AppLanguage.uz: '🎓 Imtihon uchun Test (15 ta)',
      AppLanguage.ru: '🎓 Тест для экзамена (15 вопросов)',
      AppLanguage.en: '🎓 Exam Prep Quiz (15 Qs)',
    },
    'sample_quiz_prompt': {
      AppLanguage.uz:
          'Ushbu mavzu bo\'yicha talaba va o\'quvchilar uchun to\'rtta variantli 15 ta qiziqarli test savoli tuzib bering.',
      AppLanguage.ru:
          'Составьте 15 интересных тестовых вопросов с 4 вариантами ответов и пояснениями.',
      AppLanguage.en:
          'Generate 15 challenging multiple-choice test questions with 4 options and answer explanations.',
    },
    'sample_summary': {
      AppLanguage.uz: '📝 Qisqa Konspekt & Formulalar',
      AppLanguage.ru: '📝 Краткий конспект и формулы',
      AppLanguage.en: '📝 Smart Study Notes & Formulas',
    },
    'sample_summary_prompt': {
      AppLanguage.uz:
          'Ushbu kitob bobidan eng muhim tushunchalar, formulalar va 5 ta kalit xulosadan iborat konspekt tayyorlab bering.',
      AppLanguage.ru:
          'Подготовьте структурированный конспект с ключевыми формулами, терминами и 5 главными выводами.',
      AppLanguage.en:
          'Create a structured study sheet with key concepts, core formulas, and 5 essential takeaways.',
    },
    'sample_language': {
      AppLanguage.uz: '🌍 Ingliz tili: Lug\'at va Grammatika',
      AppLanguage.ru: '🌍 Изучение языка: Словарь и грамматика',
      AppLanguage.en: '🌍 Language: Vocab & Grammar',
    },
    'sample_language_prompt': {
      AppLanguage.uz:
          'Ushbu matndan eng muhim C1/B2 darajadagi 20 ta so\'z va iboralarni ajratib, tarjimasi va misollari bilan jadval qilib bering.',
      AppLanguage.ru:
          'Выделите из текста 20 продвинутых слов и идиом уровня B2/C1 с переводом и примерами в виде таблицы.',
      AppLanguage.en:
          'Extract 20 advanced B2/C1 vocabulary words and phrases from this text with definitions, examples, and translations.',
    },

    // Categories Section
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

    // Settings
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
    'settings_language_desc': {
      AppLanguage.uz: 'O\'zbekcha, Русский, English',
      AppLanguage.ru: 'O\'zbekcha, Русский, English',
      AppLanguage.en: 'O\'zbekcha, Русский, English',
    },
    'theme_dark': {
      AppLanguage.uz: 'Tungi rejim',
      AppLanguage.ru: 'Темная тема',
      AppLanguage.en: 'Dark Mode',
    },
    'logout': {
      AppLanguage.uz: 'Chiqish',
      AppLanguage.ru: 'Выйти',
      AppLanguage.en: 'Log Out',
    },
    'cancel': {
      AppLanguage.uz: 'Bekor qilish',
      AppLanguage.ru: 'Отмена',
      AppLanguage.en: 'Cancel',
    },
    'plans_and_subs': {
      AppLanguage.uz: 'TARIF VA OBUNA',
      AppLanguage.ru: 'ТАРИФ И ПОДПИСКА',
      AppLanguage.en: 'PLAN & SUBSCRIPTION',
    },
    'new_chat': {
      AppLanguage.uz: 'Yangi chat',
      AppLanguage.ru: 'Новый чат',
      AppLanguage.en: 'New Chat',
    },
  };
}
