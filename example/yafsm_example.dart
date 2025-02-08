import 'package:yafsm/yafsm.dart';

class SwitchMachine extends Machine {
  SwitchMachine() : super('Switch') {
    initialize(isOff);
  }

  late final isOn = state('on');
  late final isOff = state('off');
  late final turnOn = transition('turn on', {isOff}, isOn);
  late final turnOff = transition('turn off', {isOn}, isOff);
}

void main() {
  final m = SwitchMachine();
  m.start();
  print(m.isOn()); // -> false
  m.turnOn();
  print(m.isOn()); // -> true
  m.turnOff();
  print(m.isOn()); // -> false
}
