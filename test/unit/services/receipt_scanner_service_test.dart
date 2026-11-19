import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kith_app/core/services/receipt_scanner_service.dart';
import 'package:kith_app/domain/models/receipt_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReceiptScannerService service;
  late Directory tempDir;

  setUp(() async {
    service = ReceiptScannerService();
    tempDir = await Directory.systemTemp.createTemp('receipt_scanner_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ReceiptScannerService Forensic Unit Tests', () {
    test('processReceiptImage returns failed ReceiptData if file does not exist', () async {
      final nonExistentPath = '${tempDir.path}/does_not_exist.jpg';

      final result = await service.processReceiptImage(nonExistentPath);

      expect(result.ocr.status, 'failed');
      expect(result.ocr.confidence, OcrConfidenceLevel.low);
      expect(result.ocr.warnings, contains('Receipt image file does not exist or is empty.'));
    });

    test('processReceiptImage returns failed ReceiptData if file is 0 bytes', () async {
      final emptyFile = File('${tempDir.path}/empty.jpg');
      await emptyFile.create();

      final result = await service.processReceiptImage(emptyFile.path);

      expect(result.ocr.status, 'failed');
      expect(result.ocr.confidence, OcrConfidenceLevel.low);
      expect(result.ocr.warnings, contains('Receipt image file does not exist or is empty.'));
    });

    test('deleteReceiptFile safely deletes existing file and returns true', () async {
      final sampleFile = File('${tempDir.path}/to_delete.jpg');
      await sampleFile.writeAsString('dummy receipt image bytes');
      expect(await sampleFile.exists(), isTrue);

      final deleted = await service.deleteReceiptFile(sampleFile.path);

      expect(deleted, isTrue);
      expect(await sampleFile.exists(), isFalse);
    });

    test('deleteReceiptFile returns false gracefully for non-existent or null path', () async {
      expect(await service.deleteReceiptFile(null), isFalse);
      expect(await service.deleteReceiptFile(''), isFalse);
      expect(await service.deleteReceiptFile('${tempDir.path}/non_existent.jpg'), isFalse);
    });
  });
}
