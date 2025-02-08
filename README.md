# Yafsm

Yet another finite state machine for Dart.

## Features

- Easily and quickly define states and transitions.
- Optionally require data for certain states.
- Manage complexity by nesting machines inside states.
- Elegantly handle transition attempts before the machine starts.
- Enables a class-based definition style with the `late` keyword.
- Zero dependencies - it's just one Dart file.

## Installation

Add the package to your Dart or Flutter project:

```bash
dart pub add yafsm
```

## Basic Usage

There are three steps to setting up a state machine:

```dart
// 1. Declare the machine, states, and transitions.
final m = Machine('switch');
final isOn = m.state('on');
final isOff = m.state('off');
final turnOn = m.transition('turn on', {isOff}, isOn);
final turnOff = m.transition('turn off', {isOn}, isOff);

// 2. Set an initial state.
m.initialize(isOff);

// 3. Start the machine.
m.start();

// Call states and transitions to manipulate the machine.
if (isOff()) {
  turnOn();
}
```

## Advanced Usage

### State Changes

You can react to changes in machine state in two ways:

1. Listen to the stream of machine states, accessible via `current$`:

```dart
m.current$.forEach((state) {
  print('Now in state: $state');
});
```

2. Listen to specific machine states, accessible via `enter$` and `exit$`:

```dart
isOn.enter$.forEach((_) {
  print('turning on');
});

isOn.exit$.forEach((_) {
  print('turning off');
});
```

I recommend sticking to `enter$` and `exit$` for integrating the machine with your application. Additionally, the state's streams are the only way to receive parameterized state data in a type-safe way.

However, the `current$` stream may be useful for debugging or more high-level behavior.

### Parameterized States

Sometimes, states will need data. You can create parameterized states with `pstate`, and transitions to parameterized states with `ptransition`.

I like to use the new Dart record syntax here.

```dart
final isOn = m.pstate<({String reason})>('on');
final turnOn = m.ptransition('turn on', {isOff}, isOn);
// ...
turnOn((reason: 'scared of the dark'));
```

The method names differ in order to provide a slightly different interface for each type of state.

### Guards

States and transitions may be guarded with arbitrary test functions.

```dart
turnOn.guard(() => hasElectricity);
turnOn();
print(isOn()); // -> false
```

Parameterized guards also have access to the proposed state data.

### Queue

There can be some time between when a machine starts, and when your code wants to start calling transitions. To account for this, machines can be configured to enqueue incoming events.

For example, the following code works as expected:

```dart
final m = Machine('switch', queue: true);
final isOn = m.state('on');
final isOff = m.state('off');
final turnOn = m.transition('turn on', {isOff}, isOn);

// Attempt a transition - but we haven't started yet!
turnOn();
m.initialize(isOff);
m.start();
print(isOn()); // -> true
```

I have found this queuing functionality to lead to more natural reasoning about machine behavior.

### Nested Machines

States tend to explode in complexity; nested machines can help combat the issue. 

To create a nested machine, call `nest` on the target state. All nested machines are started and stopped automatically as its original state is entered and exited. Just remember to initialize any nested machines as well!

```dart
final m2 = isOn.nest('on');
final isBlue = m2.state('blue light');
final isRed = m2.state('red light');
final makeRed = m2.transition('make red', {isBlue}, isRed);
m2.initialize(isBlue);
// ...
m.start();
print(isBlue(), isRed()); // -> false, false
turnOn();
print(isBlue(), isRed()); // -> true, false
makeRed();
print(isBlue(), isRed()); // -> false, true
turnOff();
print(isBlue(), isRed()); // -> false, false
```

Nested machines may also be individually configured to queue or not.

### Class-Based Definition

Machine definitions play well with the `late` keyword. This lends itself to an interesting class-based style in Dart. Here is the same switch example written in a class-based style:

```dart
class SwitchMachine {
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
```

This style has several advantages:

- The list of states and transitions are visually co-located, greatly improving legibility.
- States and transitions may be accessed directly by a consumer, without the need to pass them or rename them in any way.
- The state may be tested (almost) entirely separately from your application. I suppose the type parameters are still implementation-dependent.

## Motivation

I needed a nestable state machine library for my current project. There are several FSM libraries already out there, but the most well-maintained ones do not allow you to nest machines. As a result, I decided to implement a simple yet correct nestable FSM.

Additionally, I have attempted to keep the source code simple and concise. If you need more features or control, I can recommend copying the sole source file `machine.dart` into your project instead.
