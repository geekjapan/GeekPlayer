import 'package:drift/drift.dart';

/// drift v6 schema: favorited media items.
///
/// Introduced by `add-media-library`. Row presence means "favorited";
/// row absence means "not favorited". This avoids a boolean column and
/// makes count/list queries trivial.
@DataClassName('FavoriteRow')
class Favorites extends Table {
  /// Normalized `file://` URI — primary key.
  TextColumn get uri => text()();

  /// When the item was marked as a favorite.
  DateTimeColumn get favoritedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{uri};
}
