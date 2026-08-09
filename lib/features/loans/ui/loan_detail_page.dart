import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/currency.dart';
import '../../../core/formatters.dart';
import '../../../core/haptics.dart';
import '../../../core/icons.dart';
import '../../../core/routes.dart';
import '../../../core/theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../data/settings_repo.dart';
import '../../shared/app_dialogs.dart';
import '../../shared/app_sheet.dart';
import '../../records/ui/record_form_page.dart';

/// A loan and everything repaid against it.
///
/// Deliberately the same shape as `ProjectDetailPage`: a summary card with a
/// progress bar over Total / Repaid / Remaining, then a numbered timeline. A
/// loan repaid in instalments and a project paid in milestones are the same
/// shape of problem, so they get the same shape of screen.
///
/// Works in both directions. For money you lent, instalments are what comes
/// back; for money you borrowed, they are what you pay off. Only the wording
/// changes — the arithmetic is identical.
class LoanDetailPage extends ConsumerWidget {
  const LoanDetailPage({super.key, required this.initialLoan});

  /// Rendered immediately so the page never flashes a spinner; the live watch
  /// takes over on its first emission.
  final RecordRow initialLoan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loan =
        ref.watch(loanByIdProvider(initialLoan.id)).valueOrNull ?? initialLoan;
    final payments =
        ref.watch(loanPaymentsProvider(loan.id)).valueOrNull ?? const [];
    final currency = ref.watch(currencyProvider);

    final repaid = payments.fold<int>(0, (sum, p) => sum + p.amountMinor);
    final remaining = loan.amountMinor - repaid;
    final lent = loan.type == RecordType.loanGiven;

    return Scaffold(
      backgroundColor: context.surface,
      appBar: AppBar(
        title: Text(loan.counterparty ?? (lent ? 'Loan' : 'Borrowed')),
        actions: [
          IconButton(
            tooltip: 'Edit loan',
            icon: const Icon(AppIcons.edit),
            // Reachable here because the loans list now opens this page
            // instead of the form.
            onPressed: () => AppRoute.push(
              context,
              RecordFormPage(type: loan.type, existing: loan),
            ),
          ),
          IconButton(
            tooltip: loan.returned ? 'Re-open' : 'Mark settled',
            icon: Icon(loan.returned
                ? Icons.lock_open_rounded
                : Icons.check_circle_outline_rounded),
            onPressed: () => _toggleSettled(context, ref, loan),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
        children: [
          _SummaryCard(
            loan: loan,
            currency: currency,
            repaid: repaid,
            remaining: remaining,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: Text(
                  lent ? 'Repayments received' : 'Repayments made',
                  style: AppTextStyles.headline.copyWith(color: context.ink),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddPaymentSheet(context, ref, loan),
                icon: Icon(AppIcons.add,
                    size: AppIconSize.md, color: context.palette.accent),
                label: Text('Add',
                    style: TextStyle(color: context.palette.accent)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (payments.isEmpty)
            _NoPaymentsYet(lent: lent)
          else
            for (var i = 0; i < payments.length; i++)
              _TimelineStep(
                payment: payments[i],
                currency: currency,
                stepNumber: i + 1,
                isLast: i == payments.length - 1 && remaining <= 0,
                onDelete: () => _confirmDeletePayment(context, ref, payments[i]),
              ),
          if (payments.isNotEmpty && remaining > 0)
            _RemainingStep(remaining: remaining, currency: currency, lent: lent),
        ],
      ),
    );
  }

  Future<void> _toggleSettled(
      BuildContext context, WidgetRef ref, RecordRow loan) async {
    // Settling early is a real decision — you forgave the rest, or agreed a
    // smaller final figure — so it is confirmed rather than a silent toggle.
    if (!loan.returned) {
      final ok = await confirmDestructive(
        context,
        title: 'Mark as settled?',
        message: 'This closes the loan even if the full amount '
            "hasn't been repaid.",
        confirmLabel: 'Mark settled',
      );
      if (!ok) return;
    }
    await ref
        .read(databaseProvider)
        .markLoanReturned(loan.id, returned: !loan.returned);
    AppHaptics.success();
  }

  Future<void> _confirmDeletePayment(
      BuildContext context, WidgetRef ref, LoanPayment payment) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete this repayment?',
      message: 'The outstanding amount goes back up by this much.',
    );
    if (!ok) return;
    await ref.read(databaseProvider).deleteLoanPayment(payment.id);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.loan,
    required this.currency,
    required this.repaid,
    required this.remaining,
  });

  final RecordRow loan;
  final CurrencyOption currency;
  final int repaid;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lent = loan.type == RecordType.loanGiven;
    // Clamped so an overpayment doesn't overflow the bar; the surplus is
    // reported in the stats row instead.
    final progress = loan.amountMinor == 0
        ? 0.0
        : (repaid / loan.amountMinor).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: p.bgCard,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: p.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(
                  lent ? 'Lent out' : 'Borrowed',
                  style:
                      AppTextStyles.caption.copyWith(color: p.onAccentSoft),
                ),
              ),
              const Spacer(),
              if (loan.returned)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Text('Settled',
                      style: AppTextStyles.caption
                          .copyWith(color: p.onAccentSoft)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            loan.counterparty ?? (lent ? 'Someone' : 'Someone'),
            style: AppTextStyles.headline.copyWith(color: p.label),
          ),
          if (loan.description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(loan.description!,
                style:
                    AppTextStyles.body.copyWith(color: p.labelSecondary)),
          ],
          const SizedBox(height: 6),
          Text(
            loan.expectedReturnAt == null
                ? formatShortDate(loan.occurredAt)
                : '${formatShortDate(loan.occurredAt)} → '
                    'due ${formatShortDate(loan.expectedReturnAt!)}',
            style: AppTextStyles.caption.copyWith(color: p.labelTertiary),
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.chip),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: p.fill,
              valueColor: AlwaysStoppedAnimation(p.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Stat(label: 'Total', value: loan.amountMinor, currency: currency),
              _Stat(
                label: lent ? 'Received' : 'Repaid',
                value: repaid,
                currency: currency,
                tint: p.accent,
              ),
              _Stat(
                label: remaining < 0 ? 'Extra' : 'Remaining',
                value: remaining.abs(),
                currency: currency,
                tint: remaining > 0 ? null : p.accent,
                alignEnd: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.currency,
    this.tint,
    this.alignEnd = false,
  });

  final String label;
  final int value;
  final CurrencyOption currency;
  final Color? tint;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment:
              alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: context.palette.labelSecondary)),
            const SizedBox(height: 2),
            Text(
              formatMoney(value, currency),
              style: AppTextStyles.title
                  .copyWith(color: tint ?? context.palette.label),
            ),
          ],
        ),
      );
}

class _NoPaymentsYet extends StatelessWidget {
  const _NoPaymentsYet({required this.lent});
  final bool lent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          children: [
            Icon(AppIcons.loans,
                size: AppIconSize.xl, color: context.inkSubtle),
            const SizedBox(height: AppSpacing.md),
            Text(
              lent ? 'Nothing repaid yet' : "You haven't repaid any of this yet",
              style: AppTextStyles.body.copyWith(color: context.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              lent
                  ? 'Add each amount as it comes back.'
                  : 'Add each amount as you pay it off.',
              style: AppTextStyles.caption.copyWith(color: context.inkSubtle),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ── Timeline ─────────────────────────────────────────────────────────────────

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.payment,
    required this.currency,
    required this.stepNumber,
    required this.isLast,
    required this.onDelete,
  });

  final LoanPayment payment;
  final CurrencyOption currency;
  final int stepNumber;
  final bool isLast;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration:
                      BoxDecoration(color: p.accent, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '$stepNumber',
                      style: TextStyle(
                        color: p.onAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: p.accent.withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: context.hairline),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatMoney(payment.amountMinor, currency),
                              style: AppTextStyles.title
                                  .copyWith(color: p.label)),
                          const SizedBox(height: 2),
                          Text(formatShortDate(payment.paidAt),
                              style: AppTextStyles.caption
                                  .copyWith(color: p.labelSecondary)),
                          if (payment.note?.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(payment.note!,
                                style: AppTextStyles.caption
                                    .copyWith(color: p.labelTertiary)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(AppIcons.delete,
                          size: AppIconSize.sm, color: context.inkSubtle),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemainingStep extends StatelessWidget {
  const _RemainingStep({
    required this.remaining,
    required this.currency,
    required this.lent,
  });

  final int remaining;
  final CurrencyOption currency;
  final bool lent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.separator, width: 2),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${formatMoney(remaining, currency)} '
                '${lent ? 'still to come back' : 'still to pay'}',
                style: AppTextStyles.body.copyWith(color: p.labelSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add repayment ────────────────────────────────────────────────────────────

Future<void> _showAddPaymentSheet(
    BuildContext context, WidgetRef ref, RecordRow loan) {
  return AppSheet.show(
    context,
    transparent: true,
    builder: (_) => _AddLoanPaymentSheet(loan: loan),
  );
}

class _AddLoanPaymentSheet extends ConsumerStatefulWidget {
  const _AddLoanPaymentSheet({required this.loan});
  final RecordRow loan;

  @override
  ConsumerState<_AddLoanPaymentSheet> createState() =>
      _AddLoanPaymentSheetState();
}

class _AddLoanPaymentSheetState extends ConsumerState<_AddLoanPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _paidAt = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(databaseProvider).addLoanPayment(
          loanId: widget.loan.id,
          amountMinor: int.parse(_amount.text) * 100,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          paidAt: _paidAt,
        );
    AppHaptics.success();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final lent = widget.loan.type == RecordType.loanGiven;

    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(lent ? 'Record a repayment' : 'Record a payment',
                    style:
                        AppTextStyles.headline.copyWith(color: context.ink)),
                const SizedBox(height: AppSpacing.lg),
                Text('Amount (${currency.code})',
                    style: AppTextStyles.caption
                        .copyWith(color: context.inkMuted)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amount,
                  autofocus: true,
                  style: AppTextStyles.display
                      .copyWith(fontSize: 32, color: context.ink),
                  decoration: InputDecoration(
                    prefixText: '${currency.symbol}  ',
                    hintText: '0',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Note (optional)',
                    style: AppTextStyles.caption
                        .copyWith(color: context.inkMuted)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _note,
                  decoration: const InputDecoration(
                      hintText: 'e.g. second instalment'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Date',
                    style: AppTextStyles.caption
                        .copyWith(color: context.inkMuted)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _paidAt,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && mounted) {
                      setState(() => _paidAt = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.hairline),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(AppIcons.calendar,
                            size: AppIconSize.sm, color: context.inkSubtle),
                        const SizedBox(width: 12),
                        Text(formatShortDate(_paidAt),
                            style: AppTextStyles.body
                                .copyWith(color: context.ink)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.palette.accent,
                    foregroundColor: context.palette.onAccent,
                  ),
                  onPressed: _save,
                  child: const Text('Save repayment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
