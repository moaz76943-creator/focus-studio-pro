import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:focus_studio_pro/core/storage/app_database.dart';
import 'package:focus_studio_pro/features/backup/backup_service.dart';

void main() {
  sqfliteFfiInit();

  test('Non-destructive template change preserves all existing card fields', () async {
    final tempDirectory = await Directory.systemTemp.createTemp('focus_studio_pro_stage2_');
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: p.join(tempDirectory.path, 'test.db'),
    );
    addTearDown(() async {
      await db.close();
      await tempDirectory.delete(recursive: true);
    });
    final now = DateTime.now().toUtc().toIso8601String();

    await db.upsertDeck({
      'id': 'deck_1',
      'parent_id': null,
      'title': 'German Core A1',
      'description': 'Foundational vocabulary',
      'category_path': 'Languages/German/A1',
      'archived': 0,
      'created_at_utc': now,
      'updated_at_utc': now,
    });

    await db.updateCardTemplateSafely(
      templateId: 'tpl_multi',
      name: 'Polyglot Standard',
      fields: [
        {'key': 'word', 'label': 'Word'},
        {'key': 'translation_ar', 'label': 'Arabic Translation'},
        {'key': 'example', 'label': 'Example'},
      ],
      questionSideFields: ['word'],
      answerSideFields: ['translation_ar', 'example'],
    );

    await db.upsertCard({
      'id': 'card_1',
      'deck_id': 'deck_1',
      'template_id': 'tpl_multi',
      'fields_map_json': jsonEncode({
        'word': 'sich erinnern',
        'translation_ar': 'يتذكر',
        'example': 'Ich erinnere mich an dich.',
        'custom_etymology': 'Old High German irinneron',
      }),
      'preserved_extra_fields_json': '{}',
      'target_languages_json': jsonEncode(['de', 'ar']),
      'tags_json': jsonEncode(['reflexive', 'A2']),
      'is_favorite': 1,
      'is_difficult': 0,
      'is_archived': 0,
      'fsrs_state_json': jsonEncode({'stability': 2.5, 'difficulty': 5.0}),
      'created_at_utc': now,
      'updated_at_utc': now,
    });

    await db.updateCardTemplateSafely(
      templateId: 'tpl_multi',
      name: 'Polyglot Updated',
      fields: [
        {'key': 'headword', 'label': 'Headword'},
        {'key': 'translation_ar', 'label': 'Arabic'},
      ],
      questionSideFields: ['headword'],
      answerSideFields: ['translation_ar'],
      renamedFieldsMap: {'word': 'headword'},
    );

    final cards = await db.queryAll('cards');
    expect(cards.length, 1);
    final fieldsMap =
        jsonDecode(cards.first['fields_map_json'] as String) as Map<String, dynamic>;
    final preservedMap = jsonDecode(
        cards.first['preserved_extra_fields_json'] as String) as Map<String, dynamic>;

    expect(fieldsMap['headword'], 'sich erinnern');
    expect(fieldsMap['custom_etymology'], 'Old High German irinneron');
    expect(preservedMap['word'], 'sich erinnern');
  });

  test('AES-256-GCM encrypted backup round-trip and CSV/TSV UTF-8 validation', () async {
    final tempDirectory1 = await Directory.systemTemp.createTemp('focus_studio_pro_backup_source_');
    final db1 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: p.join(tempDirectory1.path, 'source.db'),
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await db1.upsertDeck({
      'id': 'deck_rtl',
      'parent_id': null,
      'title': 'البطاقات العربية',
      'description': 'حفظ كامل للتشكيل والـ UTF-8',
      'category_path': 'العربية/المستوى1',
      'archived': 0,
      'created_at_utc': now,
      'updated_at_utc': now,
    });

    final encrypted = await BackupService.createEncryptedBackup(
      db: db1,
      passphrase: 'Strong_Passphrase_2026!',
    );

    final tempDirectory2 = await Directory.systemTemp.createTemp('focus_studio_pro_backup_restore_');
    final db2 = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: p.join(tempDirectory2.path, 'restore.db'),
    );
    addTearDown(() async {
      await db1.close();
      await db2.close();
      await tempDirectory1.delete(recursive: true);
      await tempDirectory2.delete(recursive: true);
    });
    await BackupService.restoreEncryptedBackup(
      db: db2,
      encryptedPayload: encrypted,
      passphrase: 'Strong_Passphrase_2026!',
    );

    final restoredDecks = await db2.queryAll('decks');
    expect(restoredDecks.length, 1);
    expect(restoredDecks.first['title'], 'البطاقات العربية');

    const csvSample = 'front,back,example\n"الْعِلْمُ نُورٌ","Knowledge is light","طَلَبُ الْعِلْمِ"';
    final preview = BackupService.previewDelimitedImport(csvSample, delimiter: ',');
    expect(preview.isValid, isTrue);
    expect(preview.rowCount, 1);
    expect(preview.parsedRows.first['front'], 'الْعِلْمُ نُورٌ');
  });

  test('Updating and restoring parent/card rows preserves foreign-key children', () async {
    final tempDirectory = await Directory.systemTemp.createTemp('focus_studio_pro_fk_');
    final db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      customPath: p.join(tempDirectory.path, 'fk.db'),
    );
    addTearDown(() async {
      await db.close();
      await tempDirectory.delete(recursive: true);
    });
    final now = DateTime.now().toUtc().toIso8601String();

    await db.upsertDeck({
      'id': 'deck_fk',
      'parent_id': null,
      'title': 'Original',
      'description': '',
      'category_path': '',
      'archived': 0,
      'created_at_utc': now,
      'updated_at_utc': now,
    });
    await db.upsertCard({
      'id': 'card_fk',
      'deck_id': 'deck_fk',
      'template_id': 'template_fk',
      'fields_map_json': jsonEncode({'word': 'lernen'}),
      'preserved_extra_fields_json': '{}',
      'target_languages_json': '[]',
      'tags_json': '[]',
      'is_favorite': 0,
      'is_difficult': 0,
      'is_archived': 0,
      'fsrs_state_json': jsonEncode({'stability': 1.0, 'difficulty': 5.0}),
      'created_at_utc': now,
      'updated_at_utc': now,
    });
    await db.insertReviewLog({
      'event_id': 'review_fk',
      'card_id': 'card_fk',
      'rating': 3,
      'reviewed_at_utc': now,
      'scheduled_days': 1.0,
      'elapsed_days': 0.0,
      'stability': 1.0,
      'difficulty': 5.0,
    });

    await db.upsertDeck({
      'id': 'deck_fk',
      'parent_id': null,
      'title': 'Updated',
      'description': '',
      'category_path': '',
      'archived': 0,
      'created_at_utc': now,
      'updated_at_utc': now,
    });
    await db.upsertCard({
      'id': 'card_fk',
      'deck_id': 'deck_fk',
      'template_id': 'template_fk',
      'fields_map_json': jsonEncode({'word': 'studieren'}),
      'preserved_extra_fields_json': '{}',
      'target_languages_json': '[]',
      'tags_json': '[]',
      'is_favorite': 0,
      'is_difficult': 0,
      'is_archived': 0,
      'fsrs_state_json': jsonEncode({'stability': 2.0, 'difficulty': 4.5}),
      'created_at_utc': now,
      'updated_at_utc': now,
    });

    final snapshot = await db.exportFullSnapshot();
    await db.restoreSnapshotAtomically(snapshot);
    await db.restoreSnapshotAtomically(snapshot);

    expect((await db.queryAll('decks')).single['title'], 'Updated');
    expect((await db.queryAll('cards')).single['id'], 'card_fk');
    expect((await db.queryAll('review_logs')).single['event_id'], 'review_fk');
  });
}
