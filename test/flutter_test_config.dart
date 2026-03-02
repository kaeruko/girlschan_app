import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (goldenFileComparator is LocalFileComparator) {
    final testUrl = (goldenFileComparator as LocalFileComparator).basedir;
    
    // 許容誤差を 1% (0.01) に設定
    // 0.01 の差分（微細なアンチエイリアスのズレ）まではテストをパスさせる
    goldenFileComparator = LocalFileComparatorWithThreshold(
      Uri.parse('$testUrl/test.dart'),
      0.01, 
    );
  }
  await testMain();
}

class LocalFileComparatorWithThreshold extends LocalFileComparator {
  final double threshold;

  LocalFileComparatorWithThreshold(Uri testFile, this.threshold) : super(testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (!result.passed && result.diffPercent > threshold) {
      final String error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    if (!result.passed) {
      if (kDebugMode) {
        print('微小な差異(${result.diffPercent}%)が検出されましたが、許容範囲(${threshold}%)内のためパスしました。');
      }
    }
    return true;
  }
}
