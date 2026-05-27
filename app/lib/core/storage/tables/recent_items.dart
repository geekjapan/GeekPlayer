import 'package:drift/drift.dart';

/// drift v1 schema: "recently opened" list spanning all media kinds.
///
/// `kind` is a free-form string discriminator: `'video'` in this change,
/// `'audio'` / `'novel'` etc. added by later waves. Keying by URI means
/// re-opening the same Episode bumps its row instead of creating a new
/// entry, giving us reverse-chronological behaviour for free.
@DataClassName('RecentItemRow')
class RecentItems extends Table {
  TextColumn get uri => text()();
  TextColumn get kind => text()();
  DateTimeColumn get openedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{uri};
}
