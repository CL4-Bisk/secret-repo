import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentProofPickerProvider = Provider<PaymentProofPickerContract>(
  (ref) => const FilePickerPaymentProofPicker(),
);

abstract interface class PaymentProofPickerContract {
  Future<PickedPaymentProofFile?> pickImageProof();
}

class PickedPaymentProofFile {
  const PickedPaymentProofFile({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class FilePickerPaymentProofPicker implements PaymentProofPickerContract {
  const FilePickerPaymentProofPicker();

  @override
  Future<PickedPaymentProofFile?> pickImageProof() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null) {
      return null;
    }

    if (bytes == null) {
      throw StateError('Could not read the selected image file.');
    }

    return PickedPaymentProofFile(fileName: file.name, bytes: bytes);
  }
}
