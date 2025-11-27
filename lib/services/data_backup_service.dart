import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // ファイル共有用
import 'package:intl/intl.dart';
import '../services/api_service.dart'; // getClippedComments, getClipLabels 等

class DataBackupService {
  /// クリップデータをJSON文字列としてエクスポート
  Future<String> createExportJson() async {
    // 1. データの収集
    final clips = await getClippedComments();
    final labels = await getClipLabels();

    // 2. JSON構造の作成
    final data = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'GirlsChannelViewer',
      'clips': clips,
      'labels': labels,
    };

    // 3. 文字列化 (pretty printで見やすく)
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  /// JSON文字列をファイルとして保存・共有
  Future<void> shareExportFile() async {
    final jsonString = await createExportJson();
    
    // 一時ファイルを作成
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = 'garuchan_clips_$timestamp.json';
    final file = File('${tempDir.path}/$fileName');
    
    await file.writeAsString(jsonString);

    // 共有シートを表示
    await Share.shareXFiles([XFile(file.path)], text: 'ガルちゃんクリップのバックアップ');
  }

  /// クリップボードにコピー
  Future<void> copyToClipboard() async {
    final jsonString = await createExportJson();
    await Clipboard.setData(ClipboardData(text: jsonString));
  }

  /// JSON文字列からデータをインポート
  /// return: 追加された件数
  Future<int> importFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // バージョンチェック等はここで（必要なら）

      final clips = (data['clips'] as List).cast<Map<String, dynamic>>();
      final labels = (data['labels'] as List).cast<Map<String, dynamic>>();

      // 1. ラベルの復元（IDが変わらないように注意、あるいは名前でマッチング）
      // 今回は簡易的に「名前が存在しなければ作る」戦略で
      final currentLabels = await getClipLabels();
      final nameToIdMap = <String, int>{};
      
      for (final l in currentLabels) {
        nameToIdMap[l['name'] as String] = l['id'] as int;
      }

      for (final l in labels) {
        final name = l['name'] as String;
        final id = l['id'] as int;
        if (id == 0) continue; // デフォルトなどはスキップ

        if (!nameToIdMap.containsKey(name)) {
          // 新しいラベルを作成（APIの実装に合わせて調整）
          await addClipLabel(name);
          // IDを取り直す必要があるが、簡易実装としてここでは割愛
          // 本格的にやるなら addClipLabel が新IDを返すように修正が必要
        }
      }

      // 2. クリップの復元
      int addedCount = 0;
      final currentClips = await getClippedComments();
      final currentKeys = currentClips.map((c) => '${c['topicId']}-${c['no']}').toSet();

      for (final clip in clips) {
        final topicId = clip['topicId'] as int;
        final no = clip['no'] as int;
        final key = '$topicId-$no';

        // 重複チェック（既にあったらスキップ）
        if (currentKeys.contains(key)) {
          continue;
        }

        // 追加処理
        // APIサービスに「全データ指定で追加するメソッド」が必要になるかも
        // 今ある toggleClip だと足りない情報がある場合は専用メソッドを作る
        await importClipDirectly(clip);
        addedCount++;
      }

      return addedCount;

    } catch (e) {
      throw Exception('データの形式が正しくありません: $e');
    }
  }

  /// JSONファイルを選択してインポート
  Future<int> pickAndImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      return importFromJson(jsonString);
    }
    return 0;
  }
}