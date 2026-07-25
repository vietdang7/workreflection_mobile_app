import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';

void main() {
  test('maps supported context document extensions to correct MIME types', () {
    expect(contextDocumentContentType('pdf'), 'application/pdf');
    expect(contextDocumentContentType('doc'), 'application/msword');
    expect(
      contextDocumentContentType('docx'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(contextDocumentContentType('png'), 'image/png');
    expect(contextDocumentContentType('jpg'), 'image/jpeg');
    expect(contextDocumentContentType('JPEG'), 'image/jpeg');
  });

  test('uses octet-stream for unknown extensions', () {
    expect(contextDocumentContentType('unknown'), 'application/octet-stream');
  });
}
