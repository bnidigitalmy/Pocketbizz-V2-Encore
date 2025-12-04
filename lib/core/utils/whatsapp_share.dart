import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

/// WhatsApp Share Utility for PocketBizz
/// Share claims, payments, and other documents via WhatsApp
class WhatsAppShare {
  static final DateFormat _dateFormat = DateFormat('dd MMMM yyyy', 'ms_MY');

  /// Share Claim Invoice via WhatsApp
  static Future<void> shareClaim({
    required String phoneNumber,
    required String claimNumber,
    required String vendorName,
    required DateTime claimDate,
    required double netAmount,
    required double balanceAmount,
    required List<ClaimItemSummary> items,
    String? notes,
  }) async {
    final message = _buildClaimMessage(
      claimNumber: claimNumber,
      vendorName: vendorName,
      claimDate: claimDate,
      netAmount: netAmount,
      balanceAmount: balanceAmount,
      items: items,
      notes: notes,
    );

    await _launchWhatsApp(phoneNumber, message);
  }

  /// Share Payment Receipt via WhatsApp
  static Future<void> sharePayment({
    required String phoneNumber,
    required String paymentNumber,
    required String vendorName,
    required DateTime paymentDate,
    required String paymentMethod,
    required double totalAmount,
    String? paymentReference,
    String? notes,
  }) async {
    final message = _buildPaymentMessage(
      paymentNumber: paymentNumber,
      vendorName: vendorName,
      paymentDate: paymentDate,
      paymentMethod: paymentMethod,
      totalAmount: totalAmount,
      paymentReference: paymentReference,
      notes: notes,
    );

    await _launchWhatsApp(phoneNumber, message);
  }

  /// Share Delivery Note via WhatsApp
  static Future<void> shareDelivery({
    required String phoneNumber,
    required String deliveryNumber,
    required String vendorName,
    required DateTime deliveryDate,
    required double totalAmount,
    required List<DeliveryItemSummary> items,
    String? notes,
  }) async {
    final message = _buildDeliveryMessage(
      deliveryNumber: deliveryNumber,
      vendorName: vendorName,
      deliveryDate: deliveryDate,
      totalAmount: totalAmount,
      items: items,
      notes: notes,
    );

    await _launchWhatsApp(phoneNumber, message);
  }

  /// Share Payment Reminder via WhatsApp
  static Future<void> sharePaymentReminder({
    required String phoneNumber,
    required String vendorName,
    required double outstandingAmount,
    required int daysOverdue,
    String? claimNumber,
  }) async {
    final message = _buildPaymentReminderMessage(
      vendorName: vendorName,
      outstandingAmount: outstandingAmount,
      daysOverdue: daysOverdue,
      claimNumber: claimNumber,
    );

    await _launchWhatsApp(phoneNumber, message);
  }

  /// Launch WhatsApp with message
  static Future<void> _launchWhatsApp(String phoneNumber, String message) async {
    // Clean phone number (remove spaces, dashes, etc.)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Remove leading 0 and add country code if needed
    String formattedPhone = cleanPhone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '60${formattedPhone.substring(1)}';
    } else if (!formattedPhone.startsWith('60')) {
      formattedPhone = '60$formattedPhone';
    }

    final url = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}';
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot launch WhatsApp');
      }
    } catch (e) {
      throw Exception('Error launching WhatsApp: $e');
    }
  }

  /// Build Claim Message
  static String _buildClaimMessage({
    required String claimNumber,
    required String vendorName,
    required DateTime claimDate,
    required double netAmount,
    required double balanceAmount,
    required List<ClaimItemSummary> items,
    String? notes,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('*POCKETBIZZ - INVOIS TUNTUTAN*');
    buffer.writeln('');
    buffer.writeln('*No. Tuntutan:* $claimNumber');
    buffer.writeln('*Tarikh:* ${_dateFormat.format(claimDate)}');
    buffer.writeln('*Vendor:* $vendorName');
    buffer.writeln('');
    buffer.writeln('*Senarai Produk:*');
    
    for (var item in items) {
      buffer.writeln('• ${item.productName}');
      buffer.writeln('  ${item.quantitySold.toStringAsFixed(1)}x @ RM ${item.unitPrice.toStringAsFixed(2)} = RM ${item.netAmount.toStringAsFixed(2)}');
    }
    
    buffer.writeln('');
    buffer.writeln('*Jumlah Bersih:* RM ${netAmount.toStringAsFixed(2)}');
    buffer.writeln('*Baki Tertunggak:* RM ${balanceAmount.toStringAsFixed(2)}');
    
    if (notes != null && notes.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('*Nota:*');
      buffer.writeln(notes);
    }
    
    buffer.writeln('');
    buffer.writeln('Sila lihat dokumen lengkap untuk butiran terperinci.');
    buffer.writeln('');
    buffer.writeln('Terima kasih!');
    
    return buffer.toString();
  }

  /// Build Payment Message
  static String _buildPaymentMessage({
    required String paymentNumber,
    required String vendorName,
    required DateTime paymentDate,
    required String paymentMethod,
    required double totalAmount,
    String? paymentReference,
    String? notes,
  }) {
    final methodLabels = {
      'bill_to_bill': 'Bill to Bill',
      'per_claim': 'Per Claim',
      'partial': 'Bayar Separa',
      'carry_forward': 'Carry Forward',
    };

    final buffer = StringBuffer();
    
    buffer.writeln('*POCKETBIZZ - RESIT BAYARAN*');
    buffer.writeln('');
    buffer.writeln('*No. Bayaran:* $paymentNumber');
    buffer.writeln('*Tarikh:* ${_dateFormat.format(paymentDate)}');
    buffer.writeln('*Vendor:* $vendorName');
    buffer.writeln('*Kaedah:* ${methodLabels[paymentMethod] ?? paymentMethod}');
    
    if (paymentReference != null && paymentReference.isNotEmpty) {
      buffer.writeln('*Rujukan:* $paymentReference');
    }
    
    buffer.writeln('');
    buffer.writeln('*Jumlah Bayaran:* RM ${totalAmount.toStringAsFixed(2)}');
    
    if (notes != null && notes.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('*Nota:*');
      buffer.writeln(notes);
    }
    
    buffer.writeln('');
    buffer.writeln('Terima kasih!');
    
    return buffer.toString();
  }

  /// Build Delivery Message
  static String _buildDeliveryMessage({
    required String deliveryNumber,
    required String vendorName,
    required DateTime deliveryDate,
    required double totalAmount,
    required List<DeliveryItemSummary> items,
    String? notes,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('*POCKETBIZZ - NOTA PENGHANTARAN*');
    buffer.writeln('');
    buffer.writeln('*No. Penghantaran:* $deliveryNumber');
    buffer.writeln('*Tarikh:* ${_dateFormat.format(deliveryDate)}');
    buffer.writeln('*Vendor:* $vendorName');
    buffer.writeln('');
    buffer.writeln('*Senarai Produk:*');
    
    for (var item in items) {
      buffer.writeln('• ${item.productName}');
      buffer.writeln('  ${item.quantity.toStringAsFixed(1)}x @ RM ${item.unitPrice.toStringAsFixed(2)} = RM ${item.totalPrice.toStringAsFixed(2)}');
    }
    
    buffer.writeln('');
    buffer.writeln('*Jumlah:* RM ${totalAmount.toStringAsFixed(2)}');
    
    if (notes != null && notes.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('*Nota:*');
      buffer.writeln(notes);
    }
    
    buffer.writeln('');
    buffer.writeln('Terima kasih!');
    
    return buffer.toString();
  }

  /// Build Payment Reminder Message
  static String _buildPaymentReminderMessage({
    required String vendorName,
    required double outstandingAmount,
    required int daysOverdue,
    String? claimNumber,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('*POCKETBIZZ - PERINGATAN BAYARAN*');
    buffer.writeln('');
    buffer.writeln('Kepada: *$vendorName*');
    buffer.writeln('');
    
    if (claimNumber != null) {
      buffer.writeln('*No. Tuntutan:* $claimNumber');
    }
    
    buffer.writeln('*Baki Tertunggak:* RM ${outstandingAmount.toStringAsFixed(2)}');
    
    if (daysOverdue > 0) {
      buffer.writeln('*Hari Lewat:* $daysOverdue hari');
    }
    
    buffer.writeln('');
    buffer.writeln('Sila selesaikan pembayaran segera.');
    buffer.writeln('');
    buffer.writeln('Terima kasih!');
    
    return buffer.toString();
  }
}

// Data Models for WhatsApp Share

class ClaimItemSummary {
  final String productName;
  final double quantitySold;
  final double unitPrice;
  final double netAmount;

  ClaimItemSummary({
    required this.productName,
    required this.quantitySold,
    required this.unitPrice,
    required this.netAmount,
  });
}

class DeliveryItemSummary {
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  DeliveryItemSummary({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}



