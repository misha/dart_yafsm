import 'package:yafsm/yafsm.dart';

class SwitchMachine extends Machine {
  late final isOn = state();
  late final isOff = state();
  late final turnOn = transition({isOff}, isOn);
  late final turnOff = transition({isOn}, isOff);
}

void main() {
  final m = SwitchMachine();
  m.start(m.isOff);
  print(m.isOn()); // -> false
  m.turnOn();
  print(m.isOn()); // -> true
  m.turnOff();
  print(m.isOn()); // -> false
}
