import 'package:test/test.dart';
import 'package:yafsm/src/machine2.dart';

class SwitchMachine extends Machine {
  late final isOn = state();
  late final isOff = state();
  late final turnOn = transition({isOff}, isOn);
  late final turnOff = transition({isOn}, isOff);
}

void main() {
  test('inline switch', () {
    final m = Machine();
    final isOn = m.state();
    final isOff = m.state();
    final turnOn = m.transition({isOff}, isOn);
    final turnOff = m.transition({isOn}, isOff);
    m.start(isOff);

    expect(isOff(), isTrue);
    turnOn();
    expect(isOn(), isTrue);
    turnOn();
    expect(isOn(), isTrue);
    turnOff();
    expect(isOff(), isTrue);
  });

  test('initial state', () {
    {
      final m = SwitchMachine();
      m.start(m.isOff);
      expect(m.isOff(), isTrue);
    }

    {
      final m = SwitchMachine();
      m.start(m.isOn);
      expect(m.isOn(), isTrue);
    }
  });

  group('callbacks', () {
    test('onChange', () {
      final changes = <(State?, State)>[];
      final m = SwitchMachine();
      m.onChange((previous, next) => changes.add((previous, next)));

      m.start(m.isOff);
      m.turnOn();
      m.turnOff();
      m.turnOn();
      m.turnOff();

      expect(
        changes,
        orderedEquals([
          (null, m.isOff),
          (m.isOff, m.isOn),
          (m.isOn, m.isOff),
          (m.isOff, m.isOn),
          (m.isOn, m.isOff),
        ]),
      );
    });

    test('onEnter/onExit', () {
      final enters = <State>[];
      final exits = <State>[];
      final m = SwitchMachine();
      m.isOff.onEnter(() => enters.add(m.isOff));
      m.isOff.onExit(() => exits.add(m.isOff));
      m.isOn.onEnter(() => enters.add(m.isOn));
      m.isOn.onExit(() => exits.add(m.isOn));

      m.start(m.isOff);
      m.turnOn();
      m.turnOff();
      m.turnOn();
      m.turnOff();

      expect(
        enters,
        orderedEquals([
          m.isOff,
          m.isOn,
          m.isOff,
          m.isOn,
          m.isOff,
        ]),
      );

      expect(
        exits,
        orderedEquals([
          m.isOff,
          m.isOn,
          m.isOff,
          m.isOn,
        ]),
      );
    });

    test('onTrigger', () {
      final triggers = <(State, State)>[];
      final m = SwitchMachine();
      m.turnOff.onTrigger((from, to) => triggers.add((from, to)));
      m.turnOn.onTrigger((from, to) => triggers.add((from, to)));

      m.start(m.isOff);
      m.turnOn();
      m.turnOff();
      m.turnOn();
      m.turnOff();

      expect(
        triggers,
        orderedEquals([
          (m.isOff, m.isOn),
          (m.isOn, m.isOff),
          (m.isOff, m.isOn),
          (m.isOn, m.isOff),
        ]),
      );
    });
  });

  test('parameterization', () {
    String? lastOnReason;
    String? lastOffReason;

    final m = Machine();
    final isOn = m.pstate<({String reason})>('on');
    final isOff = m.pstate<({String reason})>('off');
    final turnOn = m.ptransition({isOff}, isOn);
    final turnOff = m.ptransition({isOn}, isOff);

    isOn.onEnter((data) => lastOnReason = data.reason);
    isOff.onEnter((data) => lastOffReason = data.reason);

    expect(lastOnReason, isNull);
    expect(lastOffReason, isNull);

    m.pstart(isOff, (reason: 'a'));
    expect(lastOnReason, isNull);
    expect(lastOffReason, 'a');

    turnOn((reason: 'b'));
    expect(lastOnReason, 'b');
    expect(lastOffReason, 'a');

    turnOn((reason: 'c'));
    expect(lastOnReason, 'b');
    expect(lastOffReason, 'a');

    turnOff(((reason: 'd')));
    expect(lastOnReason, 'b');
    expect(lastOffReason, 'd');
  });

  test('guards', () {
    final m = SwitchMachine();
    m.start(m.isOff);

    bool hasElectricity = false;
    m.isOn.guard(() => hasElectricity);
    expect(m.turnOn(), isFalse);
    expect(m.isOn(), isFalse);

    hasElectricity = true;
    expect(m.turnOn(), isTrue);
    expect(m.isOn(), isTrue);
  });

  test('simple nested machine', () {
    final generalLocation = Machine();
    final atHome = generalLocation.state('at home');
    final isOut = generalLocation.state('is out');
    final goHome = generalLocation.transition({isOut}, atHome);
    final goOut = generalLocation.transition({atHome}, isOut);

    final specificLocation = Machine();
    final inKitchen = specificLocation.state('in the kitchen');
    final inOffice = specificLocation.state('in the office');
    // ignore: unused_local_variable
    final goToKitchen = specificLocation.transition({inOffice}, inKitchen);
    final goToOffice = specificLocation.transition({inKitchen}, inOffice);

    atHome.nest(specificLocation, () => .start(inKitchen));
    generalLocation.start(isOut);

    // Nested states inactive when parent not in 'atHome'.
    expect(specificLocation.isStopped, isTrue);

    // Transition to atHome activates nested machine.
    goHome();
    expect(atHome(), isTrue);
    expect(inKitchen(), isTrue);

    // Nested transitions work.
    goToOffice();
    expect(atHome(), isTrue);
    expect(inOffice(), isTrue);

    // Leaving parent state stops nested machine.
    goOut();
    expect(isOut(), isTrue);
    expect(specificLocation.isStopped, isTrue);

    // Re-entering parent state restarts nested machine at initial state.
    goHome();
    expect(inKitchen(), isTrue);
  });
}
