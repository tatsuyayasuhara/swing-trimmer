import 'dart:io';

import 'package:moor/ffi.dart';
import 'package:moor/moor.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Movies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get thumbnailPath => text()();
  TextColumn get moviePath => text()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get swungAt => dateTime().nullable()();
  TextColumn get club => text().withDefault(const Constant('none'))();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return VmDatabase(file);
  });
}

@UseMoor(tables: [Movies])
class MyDatabase extends _$MyDatabase {
  MyDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) {
          return m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from == 1) {
            // we added the dueDate property in the change from version 1
            await m.alterTable(TableMigration(movies));
          } else if (from == 2) {
            await m.addColumn(movies, movies.isRead);
          } else if (from == 3) {
            await m.addColumn(movies, movies.club);
          } else if (from == 4) {
            await m.alterTable(TableMigration(movies));
          } else if (from == 5) {
            await m.alterTable(TableMigration(
              movies,
              columnTransformer: {
                movies.club: movies.club.isNotNull(),
                // clubをnon-nullableにしたけど↓の書き方が正解だったかな...
                // movies.club: movies.club.cast<String>(),
              },
            ));
          }
        },
      );

  Future<List<Movie>> get allMovieEntries async =>
      (select(movies)..orderBy([(e) => OrderingTerm.desc(e.swungAt)])).get();

  Future updateMovie(Movie entry) async {
    return update(movies).replace(entry);
  }

  Future deleteMovie(int id) async {
    return (delete(movies)..where((e) => e.id.equals(id))).go();
  }

  Future<int> addMovie(MoviesCompanion entry) async {
    return into(movies).insert(entry);
  }

  Future<void> insertMultipleMovies(List<MoviesCompanion> list) async {
    await batch((batch) {
      batch.insertAll(movies, [...list]);
    });
  }
}
