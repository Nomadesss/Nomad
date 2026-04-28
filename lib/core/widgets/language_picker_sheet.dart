import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../locale_provider.dart';

const _teal = Color(0xFF0D9488);
const _tealDark = Color(0xFF134E4A);

Future<void> showLanguagePicker(BuildContext context) {
  final provider = context.read<LocaleProvider>();
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: const _LanguagePickerSheet(),
    ),
  );
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocaleProvider>();
    final current = provider.locale?.languageCode;
    final l10n = AppLocalizations.of(context);

    final languages = [
      (code: null,   label: l10n.languageAutomatic,  tag: 'AUTO'),
      (code: 'es',   label: l10n.languageSpanish,    tag: 'ES'),
      (code: 'en',   label: l10n.languageEnglish,    tag: 'EN'),
      (code: 'pt',   label: l10n.languagePortuguese, tag: 'PT'),
      (code: 'fr',   label: l10n.languageFrench,     tag: 'FR'),
      (code: 'de',   label: l10n.languageGerman,     tag: 'DE'),
      (code: 'it',   label: l10n.languageItalian,    tag: 'IT'),
      (code: 'tr',   label: l10n.languageTurkish,    tag: 'TR'),
      (code: 'ru',   label: l10n.languageRussian,    tag: 'RU'),
      (code: 'hi',   label: l10n.languageHindi,      tag: 'HI'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.languageSheetTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _tealDark,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: languages.map((lang) => _LanguageOption(
                  tag: lang.tag,
                  label: lang.label,
                  isSelected: lang.code == null ? current == null : current == lang.code,
                  onTap: () {
                    if (lang.code == null) {
                      provider.clearLocale();
                    } else {
                      provider.setLocale(Locale(lang.code!));
                    }
                    Navigator.pop(context);
                  },
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String tag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.tag,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? _teal.withValues(alpha: 0.15)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: tag == 'AUTO' ? 8 : 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? _teal : const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? _teal : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: _teal, size: 20),
          ],
        ),
      ),
    );
  }
}
