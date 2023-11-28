import 'package:yafsm/yafsm.dart';

class SwitchMachine {
  SwitchMachine() {
    root.initialize(isOff);
  }

  final root = Machine('switch');
  late final isOn = root.state('on');
  late final isOff = root.state('off');
  late final turnOn = root.transition('turn on', {isOff}, isOn);
  late final turnOff = root.transition('turn off', {isOn}, isOff);
}

void main() {
  final m = SwitchMachine();
  m.root.start();
  print(m.isOn()); // -> false
  m.turnOn();
  print(m.isOn()); // -> true
  m.turnOff();
  print(m.isOn()); // -> false
}
