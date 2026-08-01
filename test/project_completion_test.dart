// drift exports SQL `isNull`/`isNotNull` expressions that collide with the
// matcher package's identically-named matchers.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpense_traker/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ProjectRow> insertProject() async {
    await db.into(db.projects).insert(
          ProjectsCompanion.insert(
            name: 'Bakery POS App',
            totalAmountMinor: 30000000,
            startDate: DateTime(2026, 2, 5),
          ),
        );
    return (db.select(db.projects)..limit(1)).getSingle();
  }

  test('new projects start ongoing (completedAt is null)', () async {
    final p = await insertProject();
    expect(p.completedAt, isNull);
  });

  test('setProjectCompleted round-trips true then false', () async {
    final p = await insertProject();

    await db.setProjectCompleted(p.id, completed: true);
    final done = await db.watchProject(p.id).first;
    expect(done!.completedAt, isNotNull);

    await db.setProjectCompleted(p.id, completed: false);
    final reopened = await db.watchProject(p.id).first;
    expect(reopened!.completedAt, isNull);
  });

  test('completion is independent of payments', () async {
    final p = await insertProject();
    await db.addProjectPayment(
      projectId: p.id,
      projectName: p.name,
      amountMinor: 30000000, // fully paid
      paidAt: DateTime(2026, 3, 28),
    );

    final stillOngoing = await db.watchProject(p.id).first;
    expect(stillOngoing!.completedAt, isNull,
        reason: 'paying in full must not mark a project complete');
  });

  test('editing a project preserves its completion mark', () async {
    final p = await insertProject();
    await db.setProjectCompleted(p.id, completed: true);

    // The form builds a companion WITHOUT completedAt (Value.absent()).
    await db.upsertProject(ProjectsCompanion(
      id: Value(p.id),
      name: const Value('Bakery POS App v2'),
      totalAmountMinor: Value(p.totalAmountMinor),
      startDate: Value(p.startDate),
    ));

    final after = await db.watchProject(p.id).first;
    expect(after!.name, 'Bakery POS App v2');
    expect(after.completedAt, isNotNull,
        reason: 'an absent companion field must not clear completedAt');
  });
}
