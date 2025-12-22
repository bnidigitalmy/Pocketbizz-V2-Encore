import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../data/models/delivery.dart';
import '../../data/models/business_profile.dart';

/// PDF Generator for Delivery Invoices
/// Supports 3 formats: Standard (A4), A5 Receipt, Thermal 58mm
class DeliveryInvoicePDFGenerator {
  /// Download image from URL and convert to PDF image
  static Future<pw.ImageProvider?> _downloadImageFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;
        return pw.MemoryImage(imageBytes);
      }
    } catch (e) {
      // If download fails, return null (will fallback to text)
      debugPrint('Failed to download QR code image: $e');
    }
    return null;
  }
  /// Generate PDF Invoice for Delivery
  /// 
  /// [format] can be: 'standard', 'a5', or 'thermal'
  static Future<Uint8List> generateDeliveryInvoice(
    Delivery delivery, {
    BusinessProfile? businessProfile,
    String format = 'standard',
  }) async {
    switch (format.toLowerCase()) {
      case 'a5':
      case 'mini':
        return _generateA5Invoice(delivery, businessProfile);
      case 'thermal':
        return _generateThermalInvoice(delivery, businessProfile);
      case 'standard':
      case 'normal':
      default:
        return _generateStandardInvoice(delivery, businessProfile);
    }
  }

  /// Generate Standard A4 Invoice
  static Future<Uint8List> _generateStandardInvoice(
    Delivery delivery,
    BusinessProfile? businessProfile,
  ) async {
    final pdf = pw.Document();
    final date = DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTime.now());
    final deliveryDate = DateFormat('dd MMMM yyyy', 'ms_MY').format(delivery.deliveryDate);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header with Business Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        businessProfile?.businessName ?? 'Invois Penghantaran',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                      if (businessProfile?.tagline != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          businessProfile!.tagline!,
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.grey700,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                      if (businessProfile?.address != null) ...[
                        pw.SizedBox(height: 8),
                        pw.Text(
                          businessProfile!.address!,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                      if (businessProfile?.phone != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Tel: ${businessProfile!.phone}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                      if (businessProfile?.email != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Email: ${businessProfile!.email}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blueGrey800,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'INVOIS PENGHANTARAN',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            delivery.invoiceNumber ?? 'N/A',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: pw.BoxDecoration(
                        color: _getStatusColor(delivery.status),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        _getStatusLabel(delivery.status),
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // Delivery Details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Tarikh Invoice: $date',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Tarikh Penghantaran: $deliveryDate',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // Vendor Details
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'VENDOR:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    delivery.vendorName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Items Table
            if (delivery.items.isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(1.0),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('No', isHeader: true),
                      _buildTableCell('Produk', isHeader: true),
                      _buildTableCell('Kuantiti', isHeader: true),
                      _buildTableCell('Harga (RM)', isHeader: true),
                      _buildTableCell('Jumlah (RM)', isHeader: true),
                    ],
                  ),
                  // Item Rows
                  ...delivery.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final acceptedQty = item.quantity - item.rejectedQty;

                    return pw.TableRow(
                      children: [
                        _buildTableCell('${index + 1}'),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.productName,
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                              if (item.rejectedQty > 0) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Ditolak: ${item.rejectedQty.toStringAsFixed(1)} (${item.rejectionReason ?? 'Tiada sebab'})',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.red700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _buildTableCell(acceptedQty.toStringAsFixed(1)),
                        _buildTableCell(item.unitPrice.toStringAsFixed(2)),
                        // Calculate total based on accepted quantity (not stored totalPrice which might be wrong)
                        _buildTableCell((acceptedQty * item.unitPrice).toStringAsFixed(2)),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 16),

              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'JUMLAH:',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            // Recalculate total based on accepted quantities
                            'RM${delivery.items.fold<double>(0.0, (sum, item) {
                              final acceptedQty = item.quantity - item.rejectedQty;
                              return sum + (acceptedQty * item.unitPrice);
                            }).toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            pw.SizedBox(height: 24),

            // Payment Details
            if (businessProfile?.accountNumber != null) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MAKLUMAT PEMBAYARAN:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    if (businessProfile!.bankName != null)
                      pw.Text(
                        'Bank: ${businessProfile.bankName}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    pw.Text(
                      'No. Akaun: ${businessProfile.accountNumber}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      'Nama: ${businessProfile.accountName ?? businessProfile.businessName}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Notes
            if (delivery.notes != null && delivery.notes!.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Nota:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      delivery.notes!,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Terima kasih!',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generate A5 Receipt Format
  static Future<Uint8List> _generateA5Invoice(
    Delivery delivery,
    BusinessProfile? businessProfile,
  ) async {
    final pdf = pw.Document();
    final deliveryDate = DateFormat('dd MMMM yyyy', 'ms_MY').format(delivery.deliveryDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      businessProfile?.businessName ?? 'INVOIS PENGHANTARAN',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      delivery.invoiceNumber ?? 'N/A',
                      style: const pw.TextStyle(fontSize: 12),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Divider(),

              // Vendor
              pw.Text(
                'Vendor: ${delivery.vendorName}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Tarikh: $deliveryDate',
                style: const pw.TextStyle(fontSize: 10),
              ),

              pw.SizedBox(height: 12),
              pw.Divider(),

              // Items
              ...delivery.items.map((item) {
                final acceptedQty = item.quantity - item.rejectedQty;
                final lineTotal = acceptedQty * item.unitPrice;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              item.productName,
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Text(
                            'RM${lineTotal.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      pw.Text(
                        '${acceptedQty.toStringAsFixed(1)} x RM${item.unitPrice.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                      if (item.rejectedQty > 0)
                        pw.Text(
                          'Ditolak: ${item.rejectedQty.toStringAsFixed(1)}',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.red700),
                        ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 12),
              pw.Divider(),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'JUMLAH:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    // Recalculate total based on accepted quantities
                    'RM${delivery.items.fold<double>(0.0, (sum, item) {
                      final acceptedQty = item.quantity - item.rejectedQty;
                      return sum + (acceptedQty * item.unitPrice);
                    }).toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),
              pw.Divider(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Terima kasih!',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Thermal 58mm Format
  static Future<Uint8List> _generateThermalInvoice(
    Delivery delivery,
    BusinessProfile? businessProfile,
  ) async {
    final pdf = pw.Document();
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final deliveryDate = DateFormat('dd/MM/yyyy').format(delivery.deliveryDate);
    
    // Thermal printer width: 58mm = ~219 points at 72 DPI
    const thermalWidth = 219.0;
    
    // Calculate totals
    final totalAmount = delivery.items.fold<double>(0.0, (sum, item) {
      final acceptedQty = item.quantity - item.rejectedQty;
      return sum + (acceptedQty * item.unitPrice);
    });

    // Download QR code image if available (before building PDF)
    pw.ImageProvider? qrCodeImage;
    if (businessProfile?.paymentQrCode != null && businessProfile!.paymentQrCode!.isNotEmpty) {
      try {
        qrCodeImage = await _downloadImageFromUrl(businessProfile.paymentQrCode!);
      } catch (e) {
        debugPrint('Failed to load QR code image: $e');
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(thermalWidth, double.infinity, marginAll: 5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Business Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      businessProfile?.businessName ?? 'INVOIS PENGHANTARAN',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (businessProfile?.address != null && businessProfile!.address!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        businessProfile.address!,
                        style: const pw.TextStyle(fontSize: 7),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                    if (businessProfile?.phone != null && businessProfile!.phone!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Tel: ${businessProfile.phone}',
                        style: const pw.TextStyle(fontSize: 7),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Invoice Title
              pw.Center(
                child: pw.Text(
                  'INVOIS PENGHANTARAN',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Vendor Info
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Kepada:',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      delivery.vendorName,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    // Nombor Vendor - Display below Vendor Name
                    if (delivery.vendorNumber != null && delivery.vendorNumber!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Nombor Vendor: ${delivery.vendorNumber}',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                    ],
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Tarikh: $deliveryDate',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Text(
                      'No: ${delivery.invoiceNumber ?? 'N/A'}',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Items Table Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Produk',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Kuantiti',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Harga',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Jumlah',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),

              pw.SizedBox(height: 2),
              pw.Divider(),

              // Items
              ...delivery.items.map((item) {
                final acceptedQty = item.quantity - item.rejectedQty;
                final lineTotal = acceptedQty * item.unitPrice;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Produk
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.productName,
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                            ),
                            if (item.rejectedQty > 0) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Ditolak: ${item.rejectedQty.toStringAsFixed(0)}',
                                style: pw.TextStyle(fontSize: 6, color: PdfColors.red700),
                              ),
                              if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty)
                                pw.Text(
                                  '(${item.rejectionReason})',
                                  style: pw.TextStyle(fontSize: 6, color: PdfColors.red700),
                                ),
                            ],
                          ],
                        ),
                      ),
                      // Kuantiti
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          acceptedQty.toStringAsFixed(0),
                          style: const pw.TextStyle(fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      // Harga
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          item.unitPrice.toStringAsFixed(2),
                          style: const pw.TextStyle(fontSize: 7),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      // Jumlah
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          lineTotal.toStringAsFixed(2),
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 2),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Jumlah Kasar:',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'RM ${totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'JUMLAH KESELURUHAN: RM ${totalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Nota Penting
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '* Harga sudah termasuk tolakan komisyen',
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'NOTA PENTING:',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Jumlah akhir bayaran tertakluk kepada kuantiti sebenar produk yang berjaya dijual oleh kedai.',
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Maklumat Pembayaran
              pw.Center(
                child: pw.Text(
                  'MAKLUMAT PEMBAYARAN',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 2),
              if (businessProfile?.paymentQrCode != null && businessProfile!.paymentQrCode!.isNotEmpty) ...[
                pw.Center(
                  child: pw.Text(
                    'Scan untuk bayar',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),
                pw.SizedBox(height: 2),
                // Display QR code image if downloaded successfully
                if (qrCodeImage != null) ...[
                  pw.Center(
                    child: pw.Image(
                      qrCodeImage!,
                      width: 80,
                      height: 80,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ] else ...[
                  // Fallback to URL text if image download failed
                  pw.Center(
                    child: pw.Text(
                      businessProfile.paymentQrCode!,
                      style: pw.TextStyle(fontSize: 6, color: PdfColors.blue700),
                    ),
                  ),
                ],
                pw.SizedBox(height: 4),
              ],
              if (businessProfile?.bankName != null && businessProfile!.bankName!.isNotEmpty) ...[
                pw.Text(
                  businessProfile.bankName!,
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (businessProfile?.accountNumber != null && businessProfile!.accountNumber!.isNotEmpty) ...[
                pw.Text(
                  businessProfile.accountNumber!,
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (businessProfile?.accountName != null && businessProfile!.accountName!.isNotEmpty) ...[
                pw.Text(
                  businessProfile.accountName!,
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Diterima Oleh
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Diterima Oleh:',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '_________________________',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Text(
                      'Nama Wakil Kedai',
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Tarikh: _______________',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Terima kasih
              pw.Center(
                child: pw.Text(
                  'Terima kasih atas kerjasama!',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Dokumen ini dijana oleh www.pocketbizz.my',
                  style: pw.TextStyle(
                    fontSize: 6,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    double fontSize = 11,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blueGrey800 : PdfColors.black,
        ),
      ),
    );
  }

  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return PdfColors.green;
      case 'pending':
        return PdfColors.orange;
      case 'claimed':
        return PdfColors.blue;
      case 'rejected':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

  static String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return 'DIHANTAR';
      case 'pending':
        return 'MENUNGGU';
      case 'claimed':
        return 'DITUNTUT';
      case 'rejected':
        return 'DITOLAK';
      default:
        return status.toUpperCase();
    }
  }
}

