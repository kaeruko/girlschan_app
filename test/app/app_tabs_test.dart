import 'package:flutter_test/flutter_test.dart';
import 'package:girlschan_app/app/app_tabs.dart';

void main() {
  test('ANNOTATION_MODE無効時は通常タブ構成へ影響しない', () {
    final tabIds = buildAppTabs(
      annotationMode: false,
    ).map((tab) => tab.id).toList();

    expect(tabIds, [
      'tab_new',
      'tab_popular',
      'tab_favorites',
      'tab_clips',
      'tab_search',
      'tab_settings',
    ]);
    expect(tabIds, isNot(contains('tab_annotation')));
  });

  test('ANNOTATION_MODE有効時だけアノテーションタブを追加する', () {
    final disabled = buildAppTabs(annotationMode: false).map((tab) => tab.id);
    final enabled = buildAppTabs(annotationMode: true).map((tab) => tab.id);

    expect(disabled, isNot(contains('tab_annotation')));
    expect(enabled, contains('tab_annotation'));
  });
}
