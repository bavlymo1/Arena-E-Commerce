import 'dart:typed_data';

import 'package:e_commerce_project/features/vendor_shows/domain/models/new_show.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/session_time.dart';
import 'package:e_commerce_project/features/vendor_shows/domain/models/show.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_shows_repository.dart';

NewShow draft({String date = '2028-02-29', Iterable<SessionTime>? times}) =>
    NewShow(
      vendorId: 'arena',
      title: 'Show',
      description: 'Description',
      showDate: date,
      sessions: times ?? [SessionTime('14:00'), SessionTime('19:00')],
    );

Show show({
  int count = 0,
  String imageId = 'show-a',
  String id = 'show-a',
  String vendorId = 'arena',
  ShowStatus status = ShowStatus.active,
  DateTime? createdAt,
}) => Show(
  id: id,
  vendorId: vendorId,
  title: 'SHOW',
  description: '',
  showDate: '2026-11-16',
  imageId: imageId,
  status: status,
  bookedCount: count,
  lastBookingId: '',
  createdAt: createdAt,
);

void main() {
  test('calendar date rejects overflow and accepts leap day', () {
    expect(draft().showDate, '2028-02-29');
    for (final invalid in [
      '2027-02-29',
      '2026-02-30',
      '2026-13-01',
      '',
      '2026-1-1',
    ]) {
      expect(() => draft(date: invalid), throwsArgumentError);
    }
  });

  test('session times are strict and derive deterministic IDs', () {
    expect(SessionTime('19:00').id, '1900');
    for (final invalid in ['24:00', '12:60', '9:00', '', '12:00Z']) {
      expect(() => SessionTime(invalid), throwsArgumentError);
    }
    expect(
      () => Session(id: '1400', time: SessionTime('19:00')),
      throwsArgumentError,
    );
  });

  test('draft requires one to five distinct times and snapshots input', () {
    expect(
      draft(times: List.generate(5, (i) => SessionTime('0$i:00')))
          .sessions
          .length,
      5,
    );
    expect(() => draft(times: []), throwsArgumentError);
    expect(
      () => draft(times: [SessionTime('19:00'), SessionTime('19:00')]),
      throwsArgumentError,
    );
    expect(
      () => draft(times: List.generate(6, (i) => SessionTime('0$i:00'))),
      throwsArgumentError,
    );
    final input = [SessionTime('19:00')];
    final value = draft(times: input);
    input.clear();
    expect(value.sessions.single.id, '1900');
    expect(() => value.sessions.clear(), throwsUnsupportedError);
  });

  test('session fixes capacity at 47 and protects booked-seat snapshots', () {
    final input = [1, 47];
    final value = Session(
      id: '1900',
      time: SessionTime('19:00'),
      bookedSeats: input,
    );
    input.clear();
    expect(value.capacity, 47);
    expect(value.bookedSeats, {1, 47});
    expect(() => value.bookedSeats.add(2), throwsUnsupportedError);
    expect(
      () =>
          Session(id: '1900', time: SessionTime('19:00'), bookedSeats: [1, 1]),
      throwsArgumentError,
    );
  });

  test('show requires matching image and bounded whole-show total', () {
    expect(show(count: 235).bookedCount, 235);
    expect(show().titleSearch, 'show');
    expect(() => show(count: -1), throwsArgumentError);
    expect(() => show(count: 236), throwsArgumentError);
    expect(() => show(imageId: ''), throwsArgumentError);
    expect(() => show(imageId: 'other'), throwsArgumentError);
  });

  test(
    'fake rejects empty image and preserves reusable cache boundary',
    () async {
      final fake = FakeShowsRepository();
      await expectLater(
        fake.addShow(draft(), Uint8List(0)),
        throwsArgumentError,
      );
      final poster = Uint8List.fromList([1, 2, 3]);
      await fake.addShow(draft(), poster);
      poster[0] = 9;
      expect(fake.added.single.$2, [1, 2, 3]);
      fake.shows['show-a'] = show();
      fake.clearPosterCache();
      expect(await fake.watchShow('show-a').first, isNotNull);
      fake.dispose();
      expect(() => fake.watchShow('show-a'), throwsStateError);
    },
  );

  test(
    'fake feed limits newest active records and scopes vendor/session reads',
    () async {
      final fake = FakeShowsRepository();
      fake.shows['older'] = show(
        id: 'older',
        imageId: 'older',
        createdAt: DateTime.utc(2026, 11, 15),
      );
      fake.shows['newer'] = show(
        id: 'newer',
        imageId: 'newer',
        vendorId: 'other',
        createdAt: DateTime.utc(2026, 11, 16),
      );
      fake.shows['deleting'] = show(
        id: 'deleting',
        imageId: 'deleting',
        status: ShowStatus.deleting,
        createdAt: DateTime.utc(2026, 11, 17),
      );
      expect((await fake.watchActiveShows(limit: 1).first).single.id, 'newer');
      final active = await fake.watchActiveShows().first;
      expect(active.map((value) => value.id), ['newer', 'older']);
      expect(() => active.clear(), throwsUnsupportedError);
      expect(() => fake.watchActiveShows(limit: 0), throwsArgumentError);
      expect((await fake.watchVendorShows('other').first).single.id, 'newer');
      fake.sessions['older'] = [
        Session(id: '1900', time: SessionTime('19:00')),
      ];
      expect((await fake.watchSessions('older').first).single.id, '1900');
      expect(await fake.watchSessions('newer').first, isEmpty);
      fake.dispose();
    },
  );

  test('domain helpers compute posterRevision, newest-first order, remainingSeats, and JPEG headers', () {
    final older = show(
      id: 'older',
      imageId: 'older',
      createdAt: DateTime.utc(2026, 11, 15),
    );
    final newer = show(
      id: 'newer',
      imageId: 'newer',
      createdAt: DateTime.utc(2026, 11, 16),
    );
    final uncreated = show(id: 'uncreated', imageId: 'uncreated');

    final sorted = [uncreated, older, newer]..sort(Show.compareNewestFirst);
    expect(sorted.map((s) => s.id), ['newer', 'older', 'uncreated']);

    expect(
      older.posterRevision,
      show(
        id: 'older',
        imageId: 'older',
        createdAt: DateTime.utc(2026, 11, 15),
      ).posterRevision,
    );
    expect(older.posterRevision, isNot(newer.posterRevision));

    final partialSession = Session(
      id: '1900',
      time: SessionTime('19:00'),
      bookedSeats: [1, 2],
    );
    expect(partialSession.remainingSeats, 45);
    expect(partialSession.isSoldOut, isFalse);

    final fullSession = Session(
      id: '1900',
      time: SessionTime('19:00'),
      bookedSeats: List<int>.generate(47, (i) => i + 1),
    );
    expect(fullSession.remainingSeats, 0);
    expect(fullSession.isSoldOut, isTrue);

    expect(hasJpegHeader(Uint8List.fromList([0xff, 0xd8, 0xff])), isTrue);
    expect(hasJpegHeader(Uint8List.fromList([0xff, 0xd8])), isFalse);
    expect(hasJpegHeader(Uint8List.fromList([0x89, 0x50, 0x4e])), isFalse);
  });
}
