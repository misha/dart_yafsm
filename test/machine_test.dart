import 'package:test/test.dart';
import 'package:yafsm/yafsm.dart';

void main() {
  test('simple machine', () {
    final m = Machine('switch');
    final isOn = m.state('on');
    final isOff = m.state('off');
    final turnOn = m.transition('turn on', {isOff}, isOn);
    final turnOff = m.transition('turn off', {isOn}, isOff);
    m.initialize(isOff);
    m.start();

    expect(isOff(), isTrue);
    turnOn();
    expect(isOn(), isTrue);
    turnOn();
    expect(isOn(), isTrue);
    turnOff();
    expect(isOff(), isTrue);
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
    final m = Machine('switch');
    final isOn = m.state('on');
    final isOff = m.state('off');
    final turnOn = m.transition('turn on', {isOff}, isOn);
    final turnOff = m.transition('turn off', {isOn}, isOff);
    m.initialize(isOff);

    var onCount = 0;
    var offCount = 0;

    isOn.on(
      enter: () {
        onCount += 1;
      },
    );

    isOff.on(
      enter: () {
        offCount += 1;
      },
    );

    m.start();

    turnOn();
    turnOff();
    turnOn();
    turnOff();
    turnOn();
    turnOn();
    turnOff();

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

    isOn.on(
      enter: (data) {
        lastOnReason = data.reason;
      },
    );

    isOff.on(
      enter: (data) {
        lastOffReason = data.reason;
      },
    );

    turnOn((reason: 'test 1'));
    expect(lastOnReason, 'test 1');
    turnOn((reason: 'test 2'));
    expect(lastOnReason, 'test 1');
    turnOff(((reason: 'test 3')));
    expect(lastOffReason, 'test 3');
  });
}
