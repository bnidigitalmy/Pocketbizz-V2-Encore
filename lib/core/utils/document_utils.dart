import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'pdf_generator.dart';
import 'whatsapp_share.dart';

/// Document Utilities - Main interface for generating, printing, and sharing documents
/// This is the main utility that combines PDF generation, printing, and WhatsApp sharing
class DocumentUtils {
  /// Generate and show options for Claim Invoice
  static Future<void> handleClaimDocument({
    required BuildContext context,
    required String claimNumber,
    required String vendorName,
    required String vendorPhone,
    required DateTime claimDate,
    required double grossAmount,
    required double commissionRate,
    required double commissionAmount,
    required double netAmount,
    required double paidAmount,
    required double balanceAmount,
    required List<ClaimItem> items,
    String? notes,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    // Show action sheet
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _buildActionSheet(
        context,
        title: 'Invois Tuntutan',
        options: [
          'Cetak Standard',
          'Cetak Thermal',
          'Hantar WhatsApp',
          'Simpan PDF',
          'Kongsi',
        ],
      ),
    );

    if (action == null) return;

    try {
      switch (action) {
        case 'Cetak Standard':
          await _printStandardClaim(
            claimNumber: claimNumber,
            vendorName: vendorName,
            vendorPhone: vendorPhone,
            claimDate: claimDate,
            grossAmount: grossAmount,
            commissionRate: commissionRate,
            commissionAmount: commissionAmount,
            netAmount: netAmount,
            paidAmount: paidAmount,
            balanceAmount: balanceAmount,
            items: items,
            notes: notes,
            businessName: businessName,
            businessAddress: businessAddress,
            businessPhone: businessPhone,
          );
          break;

        case 'Cetak Thermal':
          await _printThermalClaim(
            claimNumber: claimNumber,
            vendorName: vendorName,
            claimDate: claimDate,
            netAmount: netAmount,
            balanceAmount: balanceAmount,
            items: items,
            businessName: businessName,
          );
          break;

        case 'Hantar WhatsApp':
          await _shareClaimViaWhatsApp(
            phoneNumber: vendorPhone,
            claimNumber: claimNumber,
            vendorName: vendorName,
            claimDate: claimDate,
            netAmount: netAmount,
            balanceAmount: balanceAmount,
            items: items,
            notes: notes,
          );
          break;

        case 'Simpan PDF':
          await _saveClaimPDF(
            context: context,
            claimNumber: claimNumber,
            vendorName: vendorName,
            vendorPhone: vendorPhone,
            claimDate: claimDate,
            grossAmount: grossAmount,
            commissionRate: commissionRate,
            commissionAmount: commissionAmount,
            netAmount: netAmount,
            paidAmount: paidAmount,
            balanceAmount: balanceAmount,
            items: items,
            notes: notes,
            businessName: businessName,
            businessAddress: businessAddress,
            businessPhone: businessPhone,
          );
          break;

        case 'Kongsi':
          await _shareClaimPDF(
            claimNumber: claimNumber,
            vendorName: vendorName,
            vendorPhone: vendorPhone,
            claimDate: claimDate,
            grossAmount: grossAmount,
            commissionRate: commissionRate,
            commissionAmount: commissionAmount,
            netAmount: netAmount,
            paidAmount: paidAmount,
            balanceAmount: balanceAmount,
            items: items,
            notes: notes,
            businessName: businessName,
            businessAddress: businessAddress,
            businessPhone: businessPhone,
          );
          break;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Operasi berjaya!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate and show options for Payment Receipt
  static Future<void> handlePaymentDocument({
    required BuildContext context,
    required String paymentNumber,
    required String vendorName,
    required String vendorPhone,
    required DateTime paymentDate,
    required String paymentMethod,
    required double totalAmount,
    required String? paymentReference,
    required List<PaymentAllocation> allocations,
    String? notes,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    // Show action sheet
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _buildActionSheet(
        context,
        title: 'Resit Bayaran',
        options: [
          'Cetak Standard',
          'Cetak Thermal',
          'Hantar WhatsApp',
          'Simpan PDF',
          'Kongsi',
        ],
      ),
    );

    if (action == null) return;

    try {
      final pdfBytes = await PDFGenerator.generatePaymentReceipt(
        paymentNumber: paymentNumber,
        vendorName: vendorName,
        vendorPhone: vendorPhone,
        paymentDate: paymentDate,
        paymentMethod: paymentMethod,
        totalAmount: totalAmount,
        paymentReference: paymentReference,
        allocations: allocations,
        notes: notes,
        businessName: businessName,
        businessAddress: businessAddress,
        businessPhone: businessPhone,
      );

      switch (action) {
        case 'Cetak Standard':
          await PDFGenerator.printPDF(pdfBytes, name: 'Resit Bayaran $paymentNumber');
          break;

        case 'Cetak Thermal':
          // For thermal, use smaller format
          await PDFGenerator.printPDF(pdfBytes, name: 'Resit Bayaran $paymentNumber');
          break;

        case 'Hantar WhatsApp':
          await WhatsAppShare.sharePayment(
            phoneNumber: vendorPhone,
            paymentNumber: paymentNumber,
            vendorName: vendorName,
            paymentDate: paymentDate,
            paymentMethod: paymentMethod,
            totalAmount: totalAmount,
            paymentReference: paymentReference,
            notes: notes,
          );
          break;

        case 'Simpan PDF':
          final file = await PDFGenerator.savePDF(
            pdfBytes,
            'payment_${paymentNumber}_${DateFormat('yyyyMMdd').format(paymentDate)}.pdf',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ PDF disimpan: ${file.path}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          break;

        case 'Kongsi':
          await PDFGenerator.sharePDF(pdfBytes, fileName: 'payment_$paymentNumber.pdf');
          break;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Operasi berjaya!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate and show options for Delivery Note
  static Future<void> handleDeliveryDocument({
    required BuildContext context,
    required String deliveryNumber,
    required String vendorName,
    required String vendorPhone,
    required DateTime deliveryDate,
    required double totalAmount,
    required List<DeliveryItem> items,
    String? notes,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    // Show action sheet
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _buildActionSheet(
        context,
        title: 'Nota Penghantaran',
        options: [
          'Cetak Standard',
          'Cetak Thermal',
          'Hantar WhatsApp',
          'Simpan PDF',
          'Kongsi',
        ],
      ),
    );

    if (action == null) return;

    try {
      final pdfBytes = await PDFGenerator.generateDeliveryNote(
        deliveryNumber: deliveryNumber,
        vendorName: vendorName,
        vendorPhone: vendorPhone,
        deliveryDate: deliveryDate,
        totalAmount: totalAmount,
        items: items,
        notes: notes,
        businessName: businessName,
        businessAddress: businessAddress,
        businessPhone: businessPhone,
      );

      switch (action) {
        case 'Cetak Standard':
          await PDFGenerator.printPDF(pdfBytes, name: 'Nota Penghantaran $deliveryNumber');
          break;

        case 'Cetak Thermal':
          await PDFGenerator.printPDF(pdfBytes, name: 'Nota Penghantaran $deliveryNumber');
          break;

        case 'Hantar WhatsApp':
          await WhatsAppShare.shareDelivery(
            phoneNumber: vendorPhone,
            deliveryNumber: deliveryNumber,
            vendorName: vendorName,
            deliveryDate: deliveryDate,
            totalAmount: totalAmount,
            items: items.map((item) => DeliveryItemSummary(
              productName: item.productName,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              totalPrice: item.totalPrice,
            )).toList(),
            notes: notes,
          );
          break;

        case 'Simpan PDF':
          final file = await PDFGenerator.savePDF(
            pdfBytes,
            'delivery_${deliveryNumber}_${DateFormat('yyyyMMdd').format(deliveryDate)}.pdf',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ PDF disimpan: ${file.path}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          break;

        case 'Kongsi':
          await PDFGenerator.sharePDF(pdfBytes, fileName: 'delivery_$deliveryNumber.pdf');
          break;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Operasi berjaya!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper methods

  static Future<void> _printStandardClaim({
    required String claimNumber,
    required String vendorName,
    required String vendorPhone,
    required DateTime claimDate,
    required double grossAmount,
    required double commissionRate,
    required double commissionAmount,
    required double netAmount,
    required double paidAmount,
    required double balanceAmount,
    required List<ClaimItem> items,
    String? notes,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    final pdfBytes = await PDFGenerator.generateClaimInvoice(
      claimNumber: claimNumber,
      vendorName: vendorName,
      vendorPhone: vendorPhone,
      claimDate: claimDate,
      grossAmount: grossAmount,
      commissionRate: commissionRate,
      commissionAmount: commissionAmount,
      netAmount: netAmount,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      items: items,
      notes: notes,
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
    );

    await PDFGenerator.printPDF(pdfBytes, name: 'Invois Tuntutan $claimNumber');
  }

  static Future<void> _printThermalClaim({
    required String claimNumber,
    required String vendorName,
    required DateTime claimDate,
    required double netAmount,
    required double balanceAmount,
    required List<ClaimItem> items,
    String? businessName,
  }) async {
    final pdfBytes = await PDFGenerator.generateThermalClaim(
      claimNumber: claimNumber,
      vendorName: vendorName,
      claimDate: claimDate,
      netAmount: netAmount,
      balanceAmount: balanceAmount,
      items: items,
      businessName: businessName,
    );

    await PDFGenerator.printPDF(pdfBytes, name: 'Invois Tuntutan $claimNumber');
  }

  static Future<void> _shareClaimViaWhatsApp({
    required String phoneNumber,
    required String claimNumber,
    required String vendorName,
    required DateTime claimDate,
    required double netAmount,
    required double balanceAmount,
    required List<ClaimItem> items,
    String? notes,
  }) async {
    await WhatsAppShare.shareClaim(
      phoneNumber: phoneNumber,
      claimNumber: claimNumber,
      vendorName: vendorName,
      claimDate: claimDate,
      netAmount: netAmount,
      balanceAmount: balanceAmount,
      items: items.map((item) => ClaimItemSummary(
        productName: item.productName,
        quantitySold: item.quantitySold,
        unitPrice: item.unitPrice,
        netAmount: item.netAmount,
      )).toList(),
      notes: notes,
    );
  }

  static Future<void> _saveClaimPDF({
    required BuildContext context,
    required String claimNumber,
    required String vendorName,
    required String vendorPhone,
    required DateTime claimDate,
    required double grossAmount,
    required double commissionRate,
    required double commissionAmount,
    required double netAmount,
    required double paidAmount,
    required double balanceAmount,
    required List<ClaimItem> items,
    String? notes,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    final pdfBytes = await PDFGenerator.generateClaimInvoice(
      claimNumber: claimNumber,
      vendorName: vendorName,
      vendorPhone: vendorPhone,
      claimDate: claimDate,
      grossAmount: grossAmount,
      commissionRate: commissionRate,
      commissionAmount: commissionAmount,
      netAmount: netAmount,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      items: items,
      notes: notes,
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
    );

    final file = await PDFGenerator.savePDF(
      pdfBytes,
      'claim_${claimNumber}_${DateFormat('yyyyMMdd').format(claimDate)}.pdf',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ PDF disimpan: ${file.path}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  static Future<void> _shareClaimPDF({
    required String claimNumber,
    required String vendorName,
    required String vendorPhone,
    required DateTime claimDate,
    required double grossAmount,
    required double commissionRate,
    required double commissionAmount,
    required double netAmount,
    required double paidAmount,
    required double balanceAmount,
    required List<ClaimItem> items,
    String? notes,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    final pdfBytes = await PDFGenerator.generateClaimInvoice(
      claimNumber: claimNumber,
      vendorName: vendorName,
      vendorPhone: vendorPhone,
      claimDate: claimDate,
      grossAmount: grossAmount,
      commissionRate: commissionRate,
      commissionAmount: commissionAmount,
      netAmount: netAmount,
      paidAmount: paidAmount,
      balanceAmount: balanceAmount,
      items: items,
      notes: notes,
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
    );

    await PDFGenerator.sharePDF(pdfBytes, fileName: 'claim_$claimNumber.pdf');
  }

  static Widget _buildActionSheet(BuildContext context, {required String title, required List<String> options}) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(),
          ...options.map((option) => ListTile(
            leading: _getIconForOption(option),
            title: Text(option),
            onTap: () => Navigator.pop(context, option),
          )),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  static Icon _getIconForOption(String option) {
    if (option.contains('Cetak')) {
      return const Icon(Icons.print);
    } else if (option.contains('WhatsApp')) {
      return const Icon(Icons.message, color: Colors.green);
    } else if (option.contains('Simpan')) {
      return const Icon(Icons.save);
    } else if (option.contains('Kongsi')) {
      return const Icon(Icons.share);
    }
    return const Icon(Icons.description);
  }
}



