
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/wifi_network.dart';

class PdfGenerator {
  static Future<void> printWifiPoster(WifiNetwork network) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Scan to Connect',
                  style: const pw.TextStyle(
                    fontSize: 40,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Wi-Fi: ${network.ssid}',
                  style: const pw.TextStyle(
                    fontSize: 24,
                  ),
                ),
                pw.SizedBox(height: 40),
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                  ),
                  child: pw.BarcodeWidget(
                    data: network.qrData,
                    barcode: pw.Barcode.qrCode(),
                    width: 250,
                    height: 250,
                    color: network.qrColorHex != null ? PdfColor.fromHex(network.qrColorHex!) : PdfColors.black,
                  ),
                ),
                if (network.password.isNotEmpty && !network.isHidden) ...[
                  pw.SizedBox(height: 40),
                  pw.Text(
                    'Password: ${network.password}',
                    style: const pw.TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'WiFi_Poster_${network.ssid}.pdf',
    );
  }

  static Future<void> printTableTent(WifiNetwork network) async {
    final doc = pw.Document();

    pw.Widget buildHalf(bool rotate) {
      return pw.Transform.rotateBox(
        angle: rotate ? 3.14159 : 0,
        child: pw.Container(
          height: PdfPageFormat.a4.height / 2 - 40,
          width: PdfPageFormat.a4.width,
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('GUEST WI-FI', style: const pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                ),
                child: pw.BarcodeWidget(
                  data: network.qrData,
                  barcode: pw.Barcode.qrCode(),
                  width: 150,
                  height: 150,
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(network.ssid, style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              if (network.password.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text('Password: ${network.password}', style: const pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
              ],
            ],
          ),
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHalf(true),
              pw.Divider(color: PdfColors.grey400, borderStyle: pw.BorderStyle.dashed),
              buildHalf(false),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'WiFi_TableTent_${network.ssid}.pdf',
    );
  }
}
