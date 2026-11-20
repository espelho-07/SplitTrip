import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/receipt_data.dart';
import 'receipt_parser_service.dart';

/// Production-grade on-device Receipt Scanner Service.
/// Handles image acquisition (Camera/Gallery), local persistence caching,
/// ML Kit on-device Text Recognition, and deterministic parsing.
class ReceiptScannerService {
  final ImagePicker _picker;
  final ReceiptParserService _parser;
  final Uuid _uuid;

  ReceiptScannerService({
    ImagePicker? picker,
    ReceiptParserService? parser,
    Uuid? uuid,
  })  : _picker = picker ?? ImagePicker(),
        _parser = parser ?? ReceiptParserService(),
        _uuid = uuid ?? const Uuid();

  /// Captures an image from the camera and stores a local cached copy.
  /// High resolution (up to 2400x3600, 95% quality) ensures small thermal printer fonts
  /// and decimals are preserved for on-device ML Kit OCR.
  Future<String?> captureFromCamera() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2400,
        maxHeight: 3600,
        imageQuality: 95,
      );
      if (xFile == null) return null;
      return await persistReceiptFile(xFile.path);
    } catch (e) {
      debugPrint('[ReceiptScannerService] Error capturing from camera: $e');
      rethrow;
    }
  }

  /// Imports an image from the gallery and stores a local cached copy.
  /// High resolution (up to 2400x3600, 95% quality) ensures small thermal printer fonts
  /// and decimals are preserved for on-device ML Kit OCR.
  Future<String?> importFromGallery() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 3600,
        imageQuality: 95,
      );
      if (xFile == null) return null;
      return await persistReceiptFile(xFile.path);
    } catch (e) {
      debugPrint('[ReceiptScannerService] Error picking from gallery: $e');
      rethrow;
    }
  }

  /// Safely copies the image to the app documents directory so it survives
  /// process termination and remains available offline.
  Future<String> persistReceiptFile(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return sourcePath;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(appDir.path, 'receipts'));
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}$ext';
      final destinationPath = p.join(receiptsDir.path, fileName);

      final savedFile = await sourceFile.copy(destinationPath);
      return savedFile.path;
    } catch (e) {
      debugPrint('[ReceiptScannerService] Error copying receipt to documents dir: $e. Falling back to source.');
      return sourcePath;
    }
  }

  /// Deletes a local receipt file safely from storage.
  /// Typically called when the user cancels review or detaches a receipt.
  Future<bool> deleteReceiptFile(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return false;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[ReceiptScannerService] Deleted local receipt file: $filePath');
        return true;
      }
    } catch (e) {
      debugPrint('[ReceiptScannerService] Error deleting receipt file $filePath: $e');
    }
    return false;
  }

  /// Processes an image via ML Kit on-device OCR and parses it into [ReceiptData].
  Future<ReceiptData> processReceiptImage(
    String imagePath, {
    String? tripCurrencyCode,
  }) async {
    final currency = tripCurrencyCode ?? 'INR';

    try {
      final file = File(imagePath);
      if (!await file.exists() || await file.length() == 0) {
        return ReceiptData(
          id: _uuid.v4(),
          imagePath: imagePath,
          receipt: ReceiptMetadata(currency: currency),
          ocr: const ReceiptOcrResult(
            status: 'failed',
            confidence: OcrConfidenceLevel.low,
            warnings: ['Receipt image file does not exist or is empty.'],
            rawText: '',
          ),
        );
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText;
      try {
        recognizedText = await textRecognizer.processImage(inputImage);
      } finally {
        await textRecognizer.close();
      }

      final rawText = recognizedText.text;

      // Extract spatial lines with 2D bounding boxes from ML Kit blocks
      final structuredLines = <OcrLine>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          structuredLines.add(
            OcrLine(
              text: line.text,
              boundingBox: OcrBoundingBox(
                left: line.boundingBox.left,
                top: line.boundingBox.top,
                right: line.boundingBox.right,
                bottom: line.boundingBox.bottom,
              ),
              confidence: line.confidence,
            ),
          );
        }
      }

      return _parser.parse(
        rawText: rawText,
        structuredLines: structuredLines,
        imagePath: imagePath,
        tripCurrencyCode: currency,
      );
    } catch (e) {
      debugPrint('[ReceiptScannerService] OCR processing error: $e');
      return ReceiptData(
        id: _uuid.v4(),
        imagePath: imagePath,
        receipt: ReceiptMetadata(currency: currency),
        ocr: ReceiptOcrResult(
          status: 'failed',
          confidence: OcrConfidenceLevel.low,
          warnings: ['Failed to read receipt text: ${e.toString()}'],
          rawText: '',
        ),
      );
    }
  }
}
