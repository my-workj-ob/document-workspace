import 'package:flutter/material.dart';

import '../../../core/localization/app_locale.dart';

class ExploreCategory {
  final String id;
  final Map<AppLanguage, String> titles;
  final Map<AppLanguage, String> descriptions;
  final IconData icon;
  final Color color;
  final Map<AppLanguage, String> starterPrompts;

  const ExploreCategory({
    required this.id,
    required this.titles,
    required this.descriptions,
    required this.icon,
    required this.color,
    required this.starterPrompts,
  });

  String getTitle(AppLanguage lang) =>
      titles[lang] ?? titles[AppLanguage.uz] ?? '';

  String getDescription(AppLanguage lang) =>
      descriptions[lang] ?? descriptions[AppLanguage.uz] ?? '';

  String getStarterPrompt(AppLanguage lang) =>
      starterPrompts[lang] ?? starterPrompts[AppLanguage.uz] ?? '';

  // Backward-compatibility getters defaulting to Uzbek
  String get title => getTitle(AppLanguage.uz);
  String get description => getDescription(AppLanguage.uz);
  String get starterPrompt => getStarterPrompt(AppLanguage.uz);

  /// 8 Pure Education & Academic Learning Tools (No legal documents)
  static const List<ExploreCategory> categories = [
    ExploreCategory(
      id: 'textbook_study',
      titles: {
        AppLanguage.uz: 'Darslik & Kitoblar Tahlili',
        AppLanguage.ru: 'Глубокий анализ учебников',
        AppLanguage.en: 'Textbook Deep Study',
      },
      descriptions: {
        AppLanguage.uz:
            'Katta hajmdagi darslik va o\'quv qo\'llanmalaridan murakkab mavzularni oddiy tilda tushunish',
        AppLanguage.ru:
            'Понимание сложных тем из объемных учебников и пособий простым и ясным языком',
        AppLanguage.en:
            'Deep breakdown and simple explanations from large textbooks, manuals, and books',
      },
      icon: Icons.menu_book_rounded,
      color: Color(0xFF3B82F6),
      starterPrompts: {
        AppLanguage.uz:
            'Ushbu darslik bobidagi eng murakkab mavzuni qadamma-qadam, hayotiy misollar bilan oddiy va tushunarli qilib yoritib bering.',
        AppLanguage.ru:
            'Объясните самую сложную тему из этой главы учебника пошагово, простым языком с жизненными примерами.',
        AppLanguage.en:
            'Explain the most challenging concept from this textbook chapter step-by-step with practical, intuitive examples.',
      },
    ),
    ExploreCategory(
      id: 'study_notes',
      titles: {
        AppLanguage.uz: 'Konspekt & Qisqacha Mazmun',
        AppLanguage.ru: 'Конспекты и тезисы',
        AppLanguage.en: 'Smart Notes & Summaries',
      },
      descriptions: {
        AppLanguage.uz:
            'Ma\'ruza va kitob boblarini tizimli, ixcham konspekt va asosiy xulosalarga aylantirish',
        AppLanguage.ru:
            'Превращение лекций и глав книг в структурированный конспект с главными тезисами',
        AppLanguage.en:
            'Turn lengthy lectures, chapters, and materials into clear, structured study notes',
      },
      icon: Icons.note_alt_rounded,
      color: Color(0xFF10B981),
      starterPrompts: {
        AppLanguage.uz:
            'Ushbu material asosida imtihonga tayyorlanish uchun qisqa, ammo to\'liq qamrovli konspekt va 5 ta asosiy xulosani tayyorlab bering.',
        AppLanguage.ru:
            'Подготовьте подробный, но компактный конспект для подготовки к экзамену с 5 ключевыми выводами.',
        AppLanguage.en:
            'Generate a concise, highly-structured study sheet with key principles, formulas, and 5 main takeaways for exam review.',
      },
    ),
    ExploreCategory(
      id: 'exam_quiz',
      titles: {
        AppLanguage.uz: 'Imtihon & Test (Quiz)',
        AppLanguage.ru: 'Генератор тестов (Quiz)',
        AppLanguage.en: 'Exam & Quiz Generator',
      },
      descriptions: {
        AppLanguage.uz:
            'Darslik va ma\'ruzalardan 4 variantli 15-20 ta qiyinlik darajasiga ega test tuzish',
        AppLanguage.ru:
            'Создание 15-20 тестовых вопросов с 4 вариантами ответов и разбором ошибок',
        AppLanguage.en:
            'Generate 15-20 multiple-choice test questions with answer explanations and difficulty tiers',
      },
      icon: Icons.quiz_rounded,
      color: Color(0xFF8B5CF6),
      starterPrompts: {
        AppLanguage.uz:
            'Ushbu mavzu yoki kitob bo\'limi asosida 4 ta variantli (A, B, C, D) 15 ta sifatli test savoli tuzib, oxirida to\'g\'ri javoblar va izohlarini taqdim eting.',
        AppLanguage.ru:
            'Составьте 15 качественных тестовых вопросов с 4 вариантами ответов (A, B, C, D) на основе этого материала с правильными ответами и пояснениями.',
        AppLanguage.en:
            'Create 15 high-yield multiple choice questions (A, B, C, D) based on this material, complete with an answer key and detailed rationales.',
      },
    ),
    ExploreCategory(
      id: 'research_paper',
      titles: {
        AppLanguage.uz: 'Referat & Ilmiy Maqolalar',
        AppLanguage.ru: 'Научные статьи и рефераты',
        AppLanguage.en: 'Research & Academic Papers',
      },
      descriptions: {
        AppLanguage.uz:
            'Ilmiy maqola, kurs ishi va referatlar uchun adabiyotlar tahlili va iqtiboslar',
        AppLanguage.ru:
            'Анализ литературы, цитаты и выжимки для курсовых, дипломов и научных статей',
        AppLanguage.en:
            'Literature reviews, methodology summaries, citations, and analysis for coursework and thesis',
      },
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF0EA5E9),
      starterPrompts: {
        AppLanguage.uz:
            'Ushbu ilmiy maqola yoki mavzu bo\'yicha asosiy gipoteza, qo\'llanilgan metodologiya, olingan natijalar va xulosalarni ilmiy tilda bayon qilib bering.',
        AppLanguage.ru:
            'Опишите основную гипотезу, методологию, результаты и научные выводы этой исследовательской работы.',
        AppLanguage.en:
            'Summarize the core hypothesis, research methodology, findings, and academic implications of this research paper.',
      },
    ),
    ExploreCategory(
      id: 'problem_solver',
      titles: {
        AppLanguage.uz: 'Masala & Formulalar',
        AppLanguage.ru: 'Решение задач и формулы',
        AppLanguage.en: 'Step-by-Step Problem Solver',
      },
      descriptions: {
        AppLanguage.uz:
            'Matematika, fizika, kimyo va iqtisod masalalarini qadamma-qadam tushuntirib yechish',
        AppLanguage.ru:
            'Пошаговое объяснение и решение задач по математике, физике, химии и экономике',
        AppLanguage.en:
            'Step-by-step solutions and intuitive explanations for math, physics, chemistry, and STEM problems',
      },
      icon: Icons.calculate_rounded,
      color: Color(0xFFF59E0B),
      starterPrompts: {
        AppLanguage.uz:
            'Ushbu masalani qadamma-qadam yechib, har bir formulaning qanday va nima uchun qo\'llanilganini batafsil tushuntirib bering.',
        AppLanguage.ru:
            'Решите эту задачу пошагово, подробно объясняя смысл каждой формулы и ход логических рассуждений.',
        AppLanguage.en:
            'Solve this problem step-by-step, clearly explaining which formulas are used, why they apply, and each calculation.',
      },
    ),
    ExploreCategory(
      id: 'language_learning',
      titles: {
        AppLanguage.uz: 'Chet Tili & Grammatika',
        AppLanguage.ru: 'Изучение языков и грамматика',
        AppLanguage.en: 'Language Learning & Grammar',
      },
      descriptions: {
        AppLanguage.uz:
            'Matndan yangi so\'zlar lug\'ati, grammatik tahlil va tushunish mashqlari',
        AppLanguage.ru:
            'Словарь новых слов из текста, грамматический разбор и практические упражнения',
        AppLanguage.en:
            'Vocabulary extraction, context definitions, grammar explanations, and comprehension drills',
      },
      icon: Icons.translate_rounded,
      color: Color(0xFFEC4899),
      starterPrompts: {
        AppLanguage.uz:
            'Ushbu xorijiy matndan eng foydali 20 ta so\'z va iborani ajratib, ularning tarjimasi, talaffuzi va misol jumlalari bilan jadval tuzing.',
        AppLanguage.ru:
            'Выделите из этого текста 20 самых полезных слов и идиом, составьте таблицу с переводом и примерами употребления.',
        AppLanguage.en:
            'Extract 20 essential idioms and vocabulary words from this text, displaying them in a table with definitions and sample sentences.',
      },
    ),
    ExploreCategory(
      id: 'lecture_slides',
      titles: {
        AppLanguage.uz: 'Slayd & Taqdimot Rejasi',
        AppLanguage.ru: 'План презентации и слайдов',
        AppLanguage.en: 'Presentation & Slide Deck',
      },
      descriptions: {
        AppLanguage.uz:
            'Mavzu bo\'yicha dars va seminarlar uchun 10 ta slaydlik mukammal reja tuzish',
        AppLanguage.ru:
            'Готовый план из 10 слайдов для урока, семинара или доклада с тезисами',
        AppLanguage.en:
            'Create a compelling 10-slide presentation outline for lectures, seminars, and defenses',
      },
      icon: Icons.slideshow_rounded,
      color: Color(0xFF6366F1),
      starterPrompts: {
        AppLanguage.uz:
            'Ushbu mavzu bo\'yicha o\'quvchilar va talabalar uchun 10 ta slaydlik taqdimot ssenariysini tuzing: har bir slayd sarlavhasi, asosiy tezislar va ko\'rgazmali g\'oyalar.',
        AppLanguage.ru:
            'Создайте сценарий презентации из 10 слайдов по этой теме: заголовок каждого слайда, ключевые тезисы и идеи визуалов.',
        AppLanguage.en:
            'Outline a 10-slide academic presentation structure on this topic: slide titles, bullet points, and visual asset suggestions.',
      },
    ),
    ExploreCategory(
      id: 'flashcards',
      titles: {
        AppLanguage.uz: 'Flashcard & Yodlash',
        AppLanguage.ru: 'Карточки для запоминания',
        AppLanguage.en: 'Flashcards & Memorization',
      },
      descriptions: {
        AppLanguage.uz:
            'Terminlar, sanalar va qoidalarni yodda saqlash uchun savol-javob kartochkalari',
        AppLanguage.ru:
            'Карточки вопрос-ответ для быстрого и долговременного запоминания терминов и дат',
        AppLanguage.en:
            'Active recall question-and-answer flashcards to master terminology, dates, and core rules',
      },
      icon: Icons.style_rounded,
      color: Color(0xFF14B8A6),
      starterPrompts: {
        AppLanguage.uz:
            'Ushbu o\'quv materialidan yodlash oson bo\'lishi uchun 15 ta "Savol - Javob" ko\'rinishidagi flashcard kartochkalarini shakllantirib bering.',
        AppLanguage.ru:
            'Сформируйте 15 карточек формата "Вопрос - Ответ" по этому учебному материалу для быстрого запоминания.',
        AppLanguage.en:
            'Generate 15 active recall flashcards (Question & Answer format) based on this material for spaced repetition study.',
      },
    ),
  ];
}
