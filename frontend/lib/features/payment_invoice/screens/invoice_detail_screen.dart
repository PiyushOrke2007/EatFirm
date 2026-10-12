import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/invoice_model.dart';
import '../providers/payment_invoice_provider.dart';

/// Screen displaying the official immutable tax invoice matching order snapshots (SRS PAY-04).
class InvoiceDetailScreen extends StatefulWidget {
  final String orderId;
  final PaymentInvoiceProvider provider;

  const InvoiceDetailScreen({
    super.key,
    required this.orderId,
    required this.provider,
  });

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.provider.fetchInvoice(widget.orderId);
    });
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.provider.currentInvoice;
    final isLoading = widget.provider.isLoadingInvoice;
    final error = widget.provider.invoiceError;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tax Invoice'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: AppSpacing.md),
                  Text('Loading official tax invoice...', style: AppTypography.bodySmall),
                ],
              ),
            )
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.error),
                        const SizedBox(height: AppSpacing.md),
                        const Text('Unable to Load Invoice', style: AppTypography.title),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: 'Retry',
                          onPressed: () => widget.provider.fetchInvoice(widget.orderId),
                          isFullWidth: false,
                        ),
                      ],
                    ),
                  ),
                )
              : invoice == null
                  ? const Center(child: Text('No invoice available'))
                  : _buildInvoiceContent(invoice),
    );
  }

  Widget _buildInvoiceContent(InvoiceDetailModel detail) {
    final inv = detail.invoice;
    final rest = detail.restaurant;
    final cust = detail.customer;
    final payment = detail.payment;
    final breakdown = detail.breakdown;
    final isPaid = (payment['status'] ?? inv.paymentStatus) == 'PAID';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Invoice Header Banner
          AppCard(
            backgroundColor: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EatFirm',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text(
                          'Electronic Food Delivery Tax Invoice',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPaid ? AppColors.successLight : AppColors.warningLight,
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Text(
                        isPaid ? 'PAID' : 'PAYMENT DUE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPaid ? const Color(0xFF065F46) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Invoice Number', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text(
                          inv.invoiceNumber,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Date of Issue', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text(
                          '${inv.issuedAt.day.toString().padLeft(2, '0')}/${inv.issuedAt.month.toString().padLeft(2, '0')}/${inv.issuedAt.year}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Entity Details (Restaurant & Customer Snapshots)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fulfilled By
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FULFILLED BY',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rest['name']?.toString() ?? 'Restaurant',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rest['address']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'FSSAI: ${rest['foodLicenseNumber'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Delivered To
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DELIVERED TO',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cust['name']?.toString() ?? inv.recipientName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cust['deliveryAddress']?.toString() ?? inv.deliveryAddress,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Phone: ${cust['phone'] ?? inv.recipientPhone}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 3. Itemized Order Items
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: AppSpacing.sm),
                ...detail.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: item.isVeg ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                if (item.description != null && item.description!.isNotEmpty)
                                  Text(
                                    item.description!,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${item.quantity} × ₹${double.tryParse(item.unitPrice)?.toStringAsFixed(2) ?? item.unitPrice}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '₹${double.tryParse(item.lineTotal)?.toStringAsFixed(2) ?? item.lineTotal}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 4. Authoritative Bill Breakdown
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment & Tax Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: AppSpacing.sm),
                _buildSummaryLine('Item Subtotal', breakdown['subtotal']?.toString() ?? inv.subtotal),
                _buildSummaryLine('Delivery Fee', breakdown['deliveryFee']?.toString() ?? inv.deliveryFee),
                _buildSummaryLine('Taxes & GST (5%)', breakdown['taxAmount']?.toString() ?? inv.taxAmount),
                if (double.tryParse(breakdown['discountAmount']?.toString() ?? inv.discountAmount) != null &&
                    double.parse(breakdown['discountAmount']?.toString() ?? inv.discountAmount) > 0)
                  _buildSummaryLine(
                    'Discount Applied',
                    breakdown['discountAmount']?.toString() ?? inv.discountAmount,
                    isDiscount: true,
                  ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      '₹${double.tryParse(breakdown['totalAmount']?.toString() ?? inv.totalAmount)?.toStringAsFixed(2) ?? inv.totalAmount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isPaid ? AppColors.successLight.withAlpha(80) : AppColors.surface,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(
                      color: isPaid ? AppColors.successLight : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle : Icons.schedule,
                        color: isPaid ? AppColors.success : AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPaid ? 'Payment Collected via Cash on Delivery' : 'Payment Due upon Delivery (COD)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: isPaid ? const Color(0xFF065F46) : const Color(0xFF92400E),
                              ),
                            ),
                            if (payment['transactionReference'] != null)
                              Text(
                                'Ref: ${payment['transactionReference']}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 5. Legal disclaimer footer
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'This is a system-generated electronic tax invoice authorized under Section 31 of CGST Act. Thank you for dining with EatFirm!',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, {bool isDiscount = false}) {
    final formatted = double.tryParse(value)?.toStringAsFixed(2) ?? value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            isDiscount ? '-₹$formatted' : '₹$formatted',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDiscount ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
