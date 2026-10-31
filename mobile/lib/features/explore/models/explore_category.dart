import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ExploreCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String starterPrompt;

  const ExploreCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.starterPrompt,
  });

  static const List<ExploreCategory> categories = [
    ExploreCategory(
      id: 'pdf_quiz',
      title: 'PDF -> Test (Quiz)',
      description: 'Ma\'ruza va kitoblardan avtomatik 15-20 ta test tuzish',
      icon: Icons.quiz_outlined,
      color: Color(0xFF10B981),
      starterPrompt: 'Iltimos, ushbu ma\'ruza yoki kitob bo\'limi asosida to\'rtta variantli 15 ta test savoli tuzib ber.',
    ),
    ExploreCategory(
      id: 'contract_scan',
      title: 'Shartnoma Rentgeni',
      description: 'Yashirin xavflar, jarimalar va majburiyatlarni tekshirish',
      icon: Icons.gavel_rounded,
      color: Color(0xFFF59E0B),
      starterPrompt: 'Ushbu shartnoma matnini huquqiy tahlil qilib, men uchun noqulay shartlar, yashirin jarimalar va tavsiyalarni ko\'rsatib ber.',
    ),
    ExploreCategory(
      id: 'presentation',
      title: 'Slayd & Taqdimot',
      description: 'Hujjatdan 10 ta slaydlik taqdimot rejasini tuzish',
      icon: Icons.slideshow_rounded,
      color: Color(0xFF8B5CF6),
      starterPrompt: 'Ushbu mavzu yoki hujjat asosida tinglovchilar uchun 10 ta slaydlik taqdimot rejasini to\'liq yozib ber.',
    ),
    ExploreCategory(
      id: 'summary',
      title: 'Tezkor Xulosa',
      description: 'Katta PDF va kitoblarning asosiy mohiyatini 1 daqiqada olish',
      icon: Icons.summarize_outlined,
      color: Color(0xFF3B82F6),
      starterPrompt: 'Ushbu uzun matn yoki kitobning eng muhim 5 ta asosiy xulosasini va tezkor xulosasini chiqarib ber.',
    ),
    ExploreCategory(
      id: 'legal',
      title: 'Qonun & Huquq',
      description: 'O\'zbekiston qonunchiligi bo\'yicha maslahat va tahlil',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF06B6D4),
      starterPrompt: 'O\'zbekiston Respublikasi Mehnat va Fuqarolik qonunchiligi doirasida ushbu holatga huquqiy baho ber.',
    ),
    ExploreCategory(
      id: 'proofread',
      title: 'Rasmiy & Ilmiy Tahrir',
      description: 'Imlo, uslub va professional grammatikani mukammallashtirish',
      icon: Icons.edit_note_rounded,
      color: Color(0xFFEC4899),
      starterPrompt: 'Ushbu matnni imlo, uslub va mantiqiy bog\'liqlik jihatdan tekshirib, yanada ravon va professional qilib tahrirlab ber: ',
    ),
    ExploreCategory(
      id: 'resume',
      title: 'Rezyume & CV Tahlil',
      description: 'Vakansiyaga moslikni tekshirish va kuchaytirish',
      icon: Icons.badge_outlined,
      color: Color(0xFF14B8A6),
      starterPrompt: 'Ushbu rezyumeni ko\'rib chiqib, uning kuchli va zaif tomonlarini hamda ish beruvchiga ma\'qul kelishi uchun tavsiyalarni yozib ber.',
    ),
    ExploreCategory(
      id: 'finance',
      title: 'Hisobot & Jadvallar',
      description: 'Moliyaviy va statistik jadvallardan faktlarni ajratish',
      icon: Icons.table_chart_outlined,
      color: Color(0xFF6366F1),
      starterPrompt: 'Ushbu jadval yoki hisobot ma\'lumotlarini tahlil qilib, asosiy ko\'rsatkichlar va dinamikani ko\'rsatib ber.',
    ),
  ];
}
