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

      void record(State? previous, State next) {
        changes.add((previous, next));
      }

      final m = SwitchMachine();
      m.onChange(record);
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
  });
}
