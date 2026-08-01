import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency.dart';
import '../../../core/formatters.dart';
import '../../../core/category_icons.dart';
import '../../../core/haptics.dart';
import '../../../core/motion.dart';
import '../../../core/routes.dart';
import '../../../core/hero.dart';
import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../search/ui/widgets/highlight.dart';
import '../ui/record_form_page.dart';

class RecordTile extends ConsumerWidget {
  const RecordTile({
    super.key,
    required this.record,
    required this.currency,
    this.highlight,
  });
  final RecordRow record;
  final CurrencyOption currency;

  /// When set, occurrences of this query are emphasised in the title and
  /// subline. Optional so every existing call site is unaffected.
  final String? highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider).valueOrNull ?? [];
    final isExpense = record.type == RecordType.expense;
    final isIncome = record.type == RecordType.income;
    final isLoanGiven = record.type == RecordType.loanGiven;
    final isLoanTaken = record.type == RecordType.loanTaken;
    final isLoan = isLoanGiven || isLoanTaken;

    // Loans keep their directional icon — the counterparty is the subject.
    // Categorised money rows get the category's own icon, which is what makes
    // a long list scannable at a glance.
    final heroTag = HeroTags.record(HeroScope.maybeOf(context), record.id);
    final catId = record.categoryId;
    final String? catNameForIcon = (isLoan || catId == null)
        ? null
        : cats.where((c) => c.id == catId).map((c) => c.name).firstOrNull;
    final IconData icon = isLoanTaken
        ? AppIcons.loanTaken
        : isLoanGiven
            ? AppIcons.loanGiven
            : catNameForIcon != null
                ? iconForCategory(catNameForIcon)
                : (isExpense ? AppIcons.expense : AppIcons.income);

    final String title = isLoan
        ? (record.counterparty?.isNotEmpty == true
            ? record.counterparty!
            : (isLoanTaken ? 'Loan taken' : 'Loan given'))
        : record.description?.isNotEmpty == true
            ? record.description!
            : (isExpense ? 'Expense' : 'Income');

    final String subtitle = isLoan
        ? (record.returned
            ? '${isLoanTaken ? 'Repaid' : 'Returned'} · ${formatShortDate(record.occurredAt)}'
            : record.expectedReturnAt != null
                ? 'Due ${formatShortDate(record.expectedReturnAt!)}'
                : formatShortDate(record.occurredAt))
        : formatShortDate(record.occurredAt);

    final String amount = isIncome
        ? formatMoneySigned(record.amountMinor, currency, negative: false)
        : formatMoneySigned(record.amountMinor, currency, negative: true);

    // Category name (expenses/income only) folded into the subline.
    String? catName;
    if (!isLoan && record.categoryId != null) {
      for (final c in cats) {
        if (c.id == record.categoryId) {
          catName = c.name;
          break;
        }
      }
    }
    final String subline =
        catName != null ? '$catName · $subtitle' : subtitle;

    return PressScale(
      scale: AppMotion.pressRow,
      onTap: () {
        AppHaptics.light();
        AppRoute.push(
          context,
          RecordFormPage(
              type: record.type, existing: record, heroTag: heroTag),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            MaybeHero(
              tag: heroTag,
              child: IconBadge(icon, tinted: isIncome || isLoan),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (context) {
                    final titleStyle = AppTextStyles.body.copyWith(
                        color: context.ink, fontWeight: FontWeight.w600);
                    return Text.rich(
                      highlightSpan(title, highlight,
                          base: titleStyle,
                          match: highlightStyle(context, titleStyle)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                  const SizedBox(height: 3),
                  Builder(builder: (context) {
                    final subStyle = AppTextStyles.caption
                        .copyWith(color: context.inkMuted);
                    return Text.rich(
                      highlightSpan(subline, highlight,
                          base: subStyle,
                          match: highlightStyle(context, subStyle)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(amount,
                style: AppTextStyles.body.copyWith(
                    color: isIncome ? context.palette.accent : context.ink,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
