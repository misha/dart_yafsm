# Yafsm

Yet another finite state machine for Dart.

## Features

- Easily and quickly define states and transitions.
- Optionally require data for certain states.
- Manage complexity by nesting machines inside states.
- Enables a class-based definition style with the `late` keyword.
- Zero dependencies - it's just one Dart file.

## Installation

Add the package to your Dart or Flutter project:

```bash
dart pub add yafsm
```

## Basic Usage

There are two steps to setting up a state machine:

```dart
// 1. Declare the machine, states, and transitions.
final m = Machine();
final isOn = m.state();
final isOff = m.state();
final turnOn = m.transition({isOff}, isOn);
final turnOff = m.transition({isOn}, isOff);

// 2. Start the machine from any state.
m.start(isOff);

// Call states and transitions to manipulate the machine.
if (isOff()) turnOn();
```

## Advanced Usage

### State Changes

You can react to changes in machine state in two ways:

1. Listen to all state changes via `onChange`:

```dart
m.onChange((previous, next) {
  print('$previous -> $next');
});
```

2. Listen to specific states via `onEnter` and `onExit`:

```dart
isOn.onEnter(() {
  print('turning on');
});

isOn.onExit(() {
  print('turning off');
});
```

I recommend sticking to `onEnter` and `onExit` for integrating the machine with your application. Additionally, parameterized state callbacks are the only way to receive state data in a type-safe way.

However, `onChange` may be useful for debugging or more high-level behavior.

### Transitions

Transitions return a `bool` indicating whether the transition was successful. A transition will fail silently if the machine is not in one of the expected source states, or if a guard blocks it.

```dart
final success = turnOn();
print(success); // -> true or false
```

You can also listen to transitions via `onTrigger`:

```dart
turnOn.onTrigger((previous, next) {
  print('triggered turn on from $previous to $next');
});
```

### Parameterized States

Sometimes, states will need data. You can create parameterized states with `pstate`, and transitions to parameterized states with `ptransition`.

I like to use the new Dart record syntax here.

```dart
final isOn = m.pstate<({String reason})>();
final turnOn = m.ptransition({isOff}, isOn);
// ...
turnOn((reason: 'scared of the dark'));
```

The method names differ in order to provide a slightly different interface for each type of state. To start a machine in a parameterized state, use `pstart`:

```dart
m.pstart(isOn, (reason: 'already on'));
```

Parameterized state callbacks also receive the state data:

```dart
isOn.onEnter((data) {
  print('turning on because: ${data.reason}');
});
```

### Guards

States may be guarded with arbitrary test functions. A guard prevents any transition into the guarded state when the test returns false.

```dart
var hasElectricity = false;
isOn.guard(() => hasElectricity);
turnOn();
print(isOn()); // -> false
```

Parameterized guards also have access to the proposed state data.

```dart
locked.guard((data) => data.code.length >= 4);
```

### Wildcard Transitions

Use the `any` sentinel to create transitions that can fire from any state:

```dart
final reset = m.transition(any, initial);
```

### Nested Machines

States tend to explode in complexity; nested machines can help combat the issue.

To create a nested machine, call `nest` on the target state. All nested machines are started and stopped automatically as its parent state is entered and exited. The `nest` function also takes an ignition function, `.start` or `.pstart`, which can dynamically control the initial state of the nested machine.

```dart
final specificLocation = Machine();
final inKitchen = specificLocation.state('in the kitchen');
final inOffice = specificLocation.state('in the office');
final goToOffice = specificLocation.transition({inKitchen}, inOffice);

atHome.nest(specificLocation, () => .start(inKitchen));
// ...
m.start(isOut);
print(inKitchen()); // -> false
goHome();
print(inKitchen()); // -> true
goToOffice();
print(inOffice()); // -> true
goOut();
print(specificLocation.isStopped); // -> true
```

Parameterized parent states can pass data to the nested machine's ignition function:

```dart
final mode = ModeMachine();
final isNormal = mode.state('normal');
final isTurbo = mode.state('turbo');

isOn.nest(mode, (data) {
  return data.mode == 'turbo' ? .start(isTurbo) : .start(isNormal);
});
```

### Class-Based Definition

Machine definitions play well with the `late` keyword. This lends itself to an interesting class-based style in Dart. Here is the same switch example written in a class-based style:

```dart
class SwitchMachine extends Machine {
  late final isOn = state('on');
  late final isOff = state('off');
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
```

This style has several advantages:

- The list of states and transitions are visually co-located, greatly improving legibility.
- States and transitions may be accessed directly by a consumer, without the need to pass them or rename them in any way.
- The state may be tested (almost) entirely separately from your application. I suppose the type parameters are still implementation-dependent.

## Motivation

I needed a nestable state machine library for my current project. There are several FSM libraries already out there, but the most well-maintained ones do not allow you to nest machines. As a result, I decided to implement a simple yet correct nestable FSM.

Additionally, I have attempted to keep the source code simple and concise. If you need more features or control, I can recommend copying the sole source file `machine.dart` into your project instead.
