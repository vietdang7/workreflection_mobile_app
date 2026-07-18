// Tests for FakeWorkshopRepository — verifies the behavior contract that all
// widget tests and unit tests depend on.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/workshop_repository.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';

import '../support/fake_workshop_repository.dart';

WorkshopDetail _workshop({
  String id = 'w1',
  int currentParticipants = 5,
  String? checkinCode,
}) {
  return WorkshopDetail(
    id: id,
    title: 'Test Workshop',
    date: DateTime(2026, 8, 1),
    price: 0,
    currency: 'VND',
    currentParticipants: currentParticipants,
    status: 'active',
    isActive: true,
    checkinCode: checkinCode,
  );
}

WorkshopRegistration _reg({
  String id = 'reg-1',
  String workshopId = 'w1',
  String status = 'registered',
  bool attended = false,
  DateTime? createdAt,
}) {
  return WorkshopRegistration(
    id: id,
    workshopId: workshopId,
    userId: 'fake-user',
    status: status,
    attended: attended,
    createdAt: createdAt ?? DateTime(2026, 7, 1),
  );
}


CcQuestion _question(String id) {
  return CcQuestion(
    id: id,
    layer: SurveyLayer.structure,
    scaleType: ScaleType.likert5,
    questionText: 'Question $id',
    questionOrder: 1,
    isActive: true,
  );
}

void main() {
  late FakeWorkshopRepository repo;

  setUp(() {
    repo = FakeWorkshopRepository();
  });

  // --- getActiveWorkshops ---

  test('getActiveWorkshops returns seeded workshops', () async {
    repo.seedWorkshops([_workshop(id: 'w1'), _workshop(id: 'w2')]);
    final result = await repo.getActiveWorkshops();
    expect(result.map((w) => w.id), containsAll(['w1', 'w2']));
  });

  // --- registerFree ---

  test('registerFree adds a registration with status registered', () async {
    repo.seedWorkshops([_workshop(id: 'w1', currentParticipants: 0)]);

    await repo.registerFree('w1');

    expect(repo.registerFreeCalls, ['w1']);
    final reg = await repo.getMyRegistration('w1');
    expect(reg, isNotNull);
    expect(reg!.status, 'registered');
    expect(reg.id, startsWith('reg-'));
  });

  test('registerFree increments workshop currentParticipants', () async {
    repo.seedWorkshops([_workshop(id: 'w1', currentParticipants: 3)]);

    await repo.registerFree('w1');

    final workshop = await repo.getWorkshop('w1');
    expect(workshop!.currentParticipants, 4);
  });

  // --- checkIn ---

  test('checkIn sets checkedInAt and attended on the registration', () async {
    repo.seedRegistration(_reg(id: 'reg-1', attended: false));

    await repo.checkIn('reg-1');

    expect(repo.checkInCalls, ['reg-1']);
    final reg = await repo.getMyRegistration('w1');
    expect(reg!.attended, isTrue);
    expect(reg.checkedInAt, isNotNull);
  });

  test('checkIn does NOT change the registration status', () async {
    repo.seedRegistration(_reg(id: 'reg-1', status: 'registered'));

    await repo.checkIn('reg-1');

    final reg = await repo.getMyRegistration('w1');
    expect(reg!.status, 'registered');
  });

  // --- setImageConsent ---

  test('setImageConsent updates imageConsent on the registration', () async {
    repo.seedRegistration(_reg(id: 'reg-1'));

    await repo.setImageConsent('reg-1', true);

    expect(repo.setImageConsentCalls, [('reg-1', true)]);
    final reg = await repo.getMyRegistration('w1');
    expect(reg!.imageConsent, isTrue);
  });

  test('setImageConsent records false consent correctly', () async {
    repo.seedRegistration(_reg(id: 'reg-1'));

    await repo.setImageConsent('reg-1', false);

    final reg = await repo.getMyRegistration('w1');
    expect(reg!.imageConsent, isFalse);
  });

  // --- submitWorkshopSurvey ---

  test('submitWorkshopSurvey marks hasSubmitted true for workshop', () async {
    expect(await repo.hasSubmittedWorkshopSurvey('w1'), isFalse);

    await repo.submitWorkshopSurvey(
      workshopId: 'w1',
      questionSetId: 'qs1',
      answers: {'q1': 3, 'q2': 4},
    );

    expect(await repo.hasSubmittedWorkshopSurvey('w1'), isTrue);
    expect(repo.submitSurveyCalls.length, 1);
    expect(repo.submitSurveyCalls.first['workshopId'], 'w1');
  });

  // --- getWorkshopSurveySet ---

  test('getWorkshopSurveySet returns seeded survey set', () async {
    final set = WorkshopSurveySet(
      questionSetId: 'qs1',
      questions: [_question('q1'), _question('q2')],
    );
    repo.seedSurveySet(set);

    final result = await repo.getWorkshopSurveySet('w1');

    expect(result, isNotNull);
    expect(result!.questionSetId, 'qs1');
    expect(result.questions.length, 2);
  });

  test('getWorkshopSurveySet returns null when nothing seeded', () async {
    final result = await repo.getWorkshopSurveySet('w1');
    expect(result, isNull);
  });

  // --- nextError ---

  test('nextError throws once then clears', () async {
    repo.nextError = Exception('forced error');

    // First call throws.
    expect(() => repo.getActiveWorkshops(), throwsException);

    // Second call succeeds (nextError was cleared).
    expect(() => repo.getActiveWorkshops(), returnsNormally);
  });

  // --- getMyRegistrations ordering ---

  test('getMyRegistrations returns newest first', () async {
    repo.seedRegistration(_reg(id: 'reg-1', createdAt: DateTime(2026, 1, 1)));
    repo.seedRegistration(
        _reg(id: 'reg-2', workshopId: 'w2', createdAt: DateTime(2026, 6, 1)));

    final regs = await repo.getMyRegistrations();

    expect(regs.first.id, 'reg-2');
    expect(regs.last.id, 'reg-1');
  });
}
