import 'package:test/test.dart';
import 'package:yafsm/yafsm.dart';

class SwitchMachine extends Machine {
  SwitchMachine({
    super.queue,
  }) : super('Switch') {
    initialize(isOff);
  }

  late final isOn = state('on');
  late final isOff = state('off');
  late final turnOn = transition('turn on', {isOff}, isOn);
  late final turnOff = transition('turn off', {isOn}, isOff);
}

void main() {
  test('simple machine', () {
    final m = SwitchMachine();
    m.start();

    expect(m.isOff(), isTrue);
    m.turnOn();
    expect(m.isOn(), isTrue);
    m.turnOn();
    expect(m.isOn(), isTrue);
    m.turnOff();
    expect(m.isOff(), isTrue);
  });

  test('nested machine', () {
    final m = Machine('location');
    final atHome = m.state('at home');
    final isOut = m.state('isOut');
    final goHome = m.transition('go home', {isOut}, atHome);
    final goOut = m.transition('go out', {atHome}, isOut);
    m.initialize(isOut);

    final m2 = atHome.nest('home location');
    final inKitchen = m2.state('in the kitchen');
    final inOffice = m2.state('in the office');
    // ignore: unused_local_variable
    final goToKitchen = m2.transition('go to the kitchen', {inOffice}, inKitchen);
    final goToOffice = m2.transition('go to the office', {inKitchen}, inOffice);
    m2.initialize(inKitchen);

    m.start();

    expect(inKitchen(), isFalse);
    expect(inOffice(), isFalse);
    goHome();
    expect(atHome(), isTrue);
    expect(inKitchen(), isTrue);
    goToOffice();
    expect(atHome(), isTrue);
    expect(inOffice(), isTrue);
    goOut();
    expect(isOut(), isTrue);
    expect(inKitchen(), isFalse);
    expect(inOffice(), isFalse);
  });

  test('machine callbacks', () {
    final m = SwitchMachine();
    var onCount = 0;
    var offCount = 0;

    m.isOn.enter$.forEach((_) {
      onCount += 1;
    });

    m.isOff.enter$.forEach((_) {
      offCount += 1;
    });

    m.start();

    m.turnOn();
    m.turnOff();
    m.turnOn();
    m.turnOff();
    m.turnOn();
    m.turnOn();
    m.turnOff();

    expect(onCount, equals(3));
    expect(offCount, equals(4));
  });

  test('parameterization', () {
    final m = Machine('switch');
    final isOn = m.pstate<({String reason})>('on');
    final isOff = m.pstate<({String reason})>('off');
    final turnOn = m.ptransition('turn on', {isOff}, isOn);
    final turnOff = m.ptransition('turn off', {isOn}, isOff);
    m.initialize(isOff, (reason: ''));
    m.start();
    String? lastOnReason;
    String? lastOffReason;

    isOn.enter$.forEach((data) {
      lastOnReason = data.reason;
    });

    isOff.enter$.forEach((data) {
      lastOffReason = data.reason;
    });

    turnOn((reason: 'test 1'));
    expect(lastOnReason, 'test 1');
    turnOn((reason: 'test 2'));
    expect(lastOnReason, 'test 1');
    turnOff(((reason: 'test 3')));
    expect(lastOffReason, 'test 3');
  });

  test('parameterized state data', () {
    final m = Machine('switch');
    final isOn = m.pstate<({String reason})>('on');
    final isOff = m.pstate<({String reason})>('off');
    final turnOn = m.ptransition('turn on', {isOff}, isOn);

    m.initialize(isOff, (reason: 'sleeping'));
    m.start();

    expect(isOff.data.reason, 'sleeping');
    expect(() => isOn.data, throwsStateError);
    expect(turnOn((reason: 'woke up')), true);
    expect(isOn.data.reason, 'woke up');
    expect(() => isOff.data, throwsStateError);
  });

  test('state guard', () {
    final m = SwitchMachine();
    m.start();

    bool hasElectricity = false;
    m.isOn.guard(() => hasElectricity);
    expect(m.turnOn(), isFalse);
    expect(m.isOn(), isFalse);

    hasElectricity = true;
    expect(m.turnOn(), isTrue);
    expect(m.isOn(), isTrue);
  });

  test('transition guard', () {
    final m = SwitchMachine();
    m.start();

    bool hasElectricity = false;
    m.turnOn.guard(() => hasElectricity);
    expect(m.turnOn(), isFalse);
    expect(m.isOn(), isFalse);

    hasElectricity = true;
    expect(m.turnOn(), isTrue);
    expect(m.isOn(), isTrue);
  });

  group('queue', () {
    test('disabled', () {
      final m = SwitchMachine();
      m.start();

      expect(m.isOff(), isTrue);
    });

    test('enabled', () {
      final m = SwitchMachine(queue: true);
      m.turnOn();
      m.start();

      expect(m.isOn(), isTrue);
    });
  });

  group('toString', () {
    test('simple', () {
      final m = SwitchMachine();

      m.start();
      expect(m.toString(), equals('off'));
    });

    test('nested', () {
      final m = SwitchMachine();
      final color = m.isOn.nest('color');
      final isBlue = color.state('blue');
      final isRed = color.state('red');
      final toRed = color.transition('to red', {isBlue}, isRed);
      color.initialize(isBlue);

      m.start();
      expect(m.toString(), equals('off'));

      m.turnOn();
      expect(m.toString(), equals('on -> blue'));

      toRed();
      expect(m.toString(), equals('on -> red'));

      m.turnOff();
      expect(m.toString(), equals('off'));
    });
  });
}
