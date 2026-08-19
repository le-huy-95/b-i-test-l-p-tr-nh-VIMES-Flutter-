import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Dữ liệu cần thiết để dựng PDF phiếu xuất / phiếu nhập kho.
class StockDocPdfData {
  const StockDocPdfData({
    required this.title,
    required this.tenantName,
    required this.address,
    required this.code,
    required this.date,
    required this.receiverLabel,
    required this.receiver,
    required this.reasonLabel,
    required this.reason,
    required this.locationLabel,
    required this.location,
    required this.requestedLabel,
    required this.actualLabel,
    required this.lines,
    required this.total,
    required this.totalInWords,
    required this.signatureRoles,
    this.note,
    this.batchExtraBuilder,
  });

  final String title;
  final String tenantName;
  final String address;
  final String code;
  final DateTime date;
  final String receiverLabel;
  final String receiver;
  final String reasonLabel;
  final String reason;
  final String locationLabel;
  final String location;
  final String requestedLabel;
  final String actualLabel;

  /// Mỗi dòng gồm: STT, tên sản phẩm (kèm dòng phụ như batch/lô), mã số, đơn vị,
  /// số lượng yêu cầu, số lượng thực (xuất/nhập), đơn giá, thành tiền.
  final List<List<String>> lines;
  final double total;
  final String totalInWords;
  final List<String> signatureRoles;
  final String? note;

  /// Tuỳ chọn: builder dòng phụ cho cột tên sản phẩm (mặc định trả về rỗng).
  final String Function(List<String> line)? batchExtraBuilder;
}

class StockDocPdfService {
  StockDocPdfService._();

  static const _regularAsset = 'lib/assets/fonts/BeVietnamPro-Regular.ttf';
  static const _boldAsset = 'lib/assets/fonts/BeVietnamPro-Bold.ttf';

  static Future<Uint8List> buildPdf(StockDocPdfData data) async {
    final fontData = await rootBundle.load(_regularAsset);
    final boldData = await rootBundle.load(_boldAsset);
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(boldData);

    final doc = pw.Document(
      title: data.title,
      author: data.tenantName.isEmpty ? null : data.tenantName,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _buildHeader(data, font, fontBold),
          pw.SizedBox(height: 8),
          _buildTitle(data.title, fontBold),
          pw.SizedBox(height: 4),
          _buildDateLine(data, font),
          pw.SizedBox(height: 10),
          _buildDetailLines(data, font),
          pw.SizedBox(height: 10),
          _buildTable(data, font, fontBold),
          pw.SizedBox(height: 10),
          _buildTotals(data, font),
          pw.SizedBox(height: 18),
          _buildSignatureRow(data.signatureRoles, font, fontBold),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(
    StockDocPdfData data,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Đơn vị: ${data.tenantName.isEmpty ? '………' : data.tenantName}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Địa chỉ: ${data.address.isEmpty ? '………' : data.address}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Mẫu số: 01 - VT',
              style: pw.TextStyle(font: fontBold, fontSize: 10),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Số: ${data.code.isEmpty ? '…………' : data.code}',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTitle(String title, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text(
          '(Ban hành theo Thông tư số 200/2014/TT-BTC ngày 22-12-2014 của Bộ trưởng Bộ Tài chính)',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          title.toUpperCase(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: fontBold, fontSize: 18),
        ),
      ],
    );
  }

  static pw.Widget _buildDateLine(StockDocPdfData data, pw.Font font) {
    return pw.Text(
      'Ngày ${data.date.day} tháng ${data.date.month} năm ${data.date.year}',
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: font, fontSize: 11),
    );
  }

  static pw.Widget _buildDetailLines(StockDocPdfData data, pw.Font font) {
    final items = <pw.Widget>[
      pw.Text(
        '- ${data.receiverLabel}: ${data.receiver}',
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        '- ${data.reasonLabel}: ${data.reason}',
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        '- ${data.locationLabel}: ${data.location}',
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
    ];
    if (data.note != null && data.note!.trim().isNotEmpty) {
      items
        ..add(pw.SizedBox(height: 2))
        ..add(
          pw.Text(
            '- Ghi chú: ${data.note!.trim()}',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items,
    );
  }

  static pw.Widget _buildTable(
    StockDocPdfData data,
    pw.Font font,
    pw.Font fontBold,
  ) {
    const cols = <double>[26, 158, 48, 50, 50, 50, 54, 58];
    final headerRow = pw.TableRow(
      children: [
        _cell('STT', fontBold, col: 0, cols: cols),
        _cell(
          'Tên, nhãn hiệu, quy cách, phẩm chất vật tư, dụng cụ, sản phẩm, hàng hóa',
          fontBold,
          col: 1,
          cols: cols,
        ),
        _cell('Mã số', fontBold, col: 2, cols: cols),
        _cell('Đơn vị tính', fontBold, col: 3, cols: cols),
        _cell(
          'Số lượng\n${data.requestedLabel}',
          fontBold,
          col: 4,
          cols: cols,
        ),
        _cell(
          'Số lượng\n${data.actualLabel}',
          fontBold,
          col: 5,
          cols: cols,
        ),
        _cell('Đơn giá', fontBold, col: 6, cols: cols),
        _cell('Thành tiền', fontBold, col: 7, cols: cols),
      ],
    );

    final bodyRows = <pw.TableRow>[];
    for (final line in data.lines) {
      bodyRows.add(
        pw.TableRow(
          children: [
            _cell(line[0], font, col: 0, cols: cols),
            _cell(
              line[1],
              font,
              col: 1,
              cols: cols,
              align: pw.TextAlign.left,
            ),
            _cell(line[2], font, col: 2, cols: cols),
            _cell(line[3], font, col: 3, cols: cols),
            _cell(line[4], font, col: 4, cols: cols),
            _cell(line[5], font, col: 5, cols: cols),
            _cell(line[6], font, col: 6, cols: cols),
            _cell(line[7], font, col: 7, cols: cols),
          ],
        ),
      );
    }

    final totalRow = pw.TableRow(
      children: [
        _cell('', fontBold, col: 0, cols: cols),
        _cell('Cộng', fontBold, col: 1, cols: cols),
        _cell('', fontBold, col: 2, cols: cols),
        _cell('', fontBold, col: 3, cols: cols),
        _cell('', fontBold, col: 4, cols: cols),
        _cell('', fontBold, col: 5, cols: cols),
        _cell('', fontBold, col: 6, cols: cols),
        _cell(data.total.toStringAsFixed(0), fontBold, col: 7, cols: cols),
      ],
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
      columnWidths: {
        for (var i = 0; i < cols.length; i++) i: pw.FixedColumnWidth(cols[i]),
      },
      children: [headerRow, ...bodyRows, totalRow],
    );
  }

  static pw.Widget _cell(
    String text,
    pw.Font font, {
    required int col,
    required List<double> cols,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Container(
      width: cols[col],
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8.5, height: 1.2),
      ),
    );
  }

  static pw.Widget _buildTotals(StockDocPdfData data, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '- Tổng số tiền: ${data.total.toStringAsFixed(0)} (Viết bằng chữ: ${data.totalInWords})',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '- Số chứng từ gốc kèm theo: 01',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
      ],
    );
  }

  static pw.Widget _buildSignatureRow(
    List<String> roles,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final width = 515 / roles.length;
    return pw.Column(
      children: [
        pw.Row(
          children: [
            for (final role in roles)
              pw.SizedBox(
                width: width,
                child: pw.Text(
                  role,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fontBold, fontSize: 9),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 44),
        pw.Row(
          children: [
            for (final _ in roles)
              pw.SizedBox(
                width: width,
                child: pw.Text(
                  '(Ký, họ tên)',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Ghi PDF ra file tạm và trả về [PlatformFile] để upload.
  static Future<PlatformFile> writeToTempFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return PlatformFile(
      name: fileName,
      size: bytes.length,
      path: file.path,
    );
  }
}