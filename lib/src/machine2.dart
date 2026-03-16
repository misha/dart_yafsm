//
// Sentinels
//

final Set<State> any = .unmodifiable({SimpleState._(Machine(), 0, label: 'any')});

//
// Machine
//

class Machine {
  int _id = 1;
  final Set<State> _states = {};
  final Map<State, List<bool Function(dynamic)>> _guards = {};
  final Map<State, List<(Machine, Ignition Function(dynamic))>> _children = {};

  (State, dynamic)? _current;

  final List<void Function(State?, State)> _onChange = [];
  final Map<State, List<void Function(dynamic)>> _onEnter = {};
  final Map<State, List<void Function(dynamic)>> _onExit = {};
  final Map<Transition, List<void Function(State)>> _onTrigger = {};

  bool get isRunning => _current != null;
  bool get isStopped => _current == null;

  State get current {
    if (isStopped) {
      throw StateError('The machine is not running yet.');
    }

    return _current!.$1;
  }

  void start(SimpleState state) {
    if (isRunning) {
      throw StateError('The machine is already running.');
    }

    _enter(null, null, state, null);
  }

  void pstart<T, S extends ParameterizedState<T>>(S state, T data) {
    if (isRunning) {
      throw StateError('The machine is already running.');
    }

    _enter(null, null, state, data);
  }

  void stop() {
    if (isRunning) {
      _exit(null);
    }
  }

  SimpleState state([String? label]) {
    final state = SimpleState._(this, _id++, label: label);
    _states.add(state);
    return state;
  }

  ParameterizedState<T> pstate<T>([String? label]) {
    final state = ParameterizedState<T>._(this, _id++, label: label);
    _states.add(state);
    return state;
  }

  SimpleTransition transition(Set<State> from, SimpleState to, [String? label]) {
    assert(identical(from, any) || from.every(_states.contains), 'Unknown `from` state.');
    assert(_states.contains(to), 'Unknown `to` state.');
    return SimpleTransition._(this, from: from, to: to, label: label);
  }

  ParameterizedTransition<T> ptransition<T>(Set<State> from, ParameterizedState<T> to, [String? label]) {
    assert(identical(from, any) || from.every(_states.contains), 'Unknown `from` state.');
    assert(_states.contains(to), 'Unknown `to` state.');
    return ParameterizedTransition._(this, from: from, to: to, label: label);
  }

  bool _attempt(Transition transition, dynamic data) {
    if (!isRunning) {
      return false;
    }

    if (!(transition.from.contains(current) || identical(transition.from, any))) {
      return false;
    }

    final next = transition.to;

    for (final guard in _guards[next] ?? const <bool Function(dynamic)>[]) {
      if (!guard(data)) {
        return false;
      }
    }

    _apply(transition, next, data);
    return true;
  }

  void _apply(Transition? transition, State next, dynamic data) {
    final previous = _current?.$1;
    _exit(transition);
    _enter(transition, previous, next, data);
  }

  void _exit(Transition? transition) {
    final state = _current!.$1;

    for (final fn in _onExit[state] ?? const <void Function(dynamic)>[]) {
      fn(_current?.$2);
    }

    for (final (child, _) in _children[state] ?? const <(Machine, void Function(Machine))>[]) {
      child.stop();
    }

    if (transition != null) {
      for (final fn in _onTrigger[transition] ?? const <void Function(State)>[]) {
        fn(state);
      }
    }

    _current = null;
  }

  void _enter(Transition? transition, State? previous, State next, dynamic data) {
    _current = (next, data);

    for (final fn in _onChange) {
      fn(previous, next);
    }

    for (final fn in _onEnter[next] ?? const <void Function(dynamic)>[]) {
      fn(data);
    }

    for (final (child, ignition) in _children[next] ?? const <(Machine, Ignition Function(dynamic))>[]) {
      ignition(data)._start(child);
    }
  }
}

//
// States
//

sealed class State {
  const State(this._parent, this.id, {this.label});

  final Machine _parent;
  final int id;
  final String? label;

  bool call() => identical(this, _parent.current);

  @override
  String toString() => label ?? 'state#$id';
}

class SimpleState extends State {
  const SimpleState._(super._parent, super.id, {super.label});
}

class ParameterizedState<T> extends State {
  const ParameterizedState._(super.parent, super.id, {super.label});

  T get data {
    if (!call()) {
      throw StateError('This state is not active.');
    }

    return _parent._current!.$2 as T;
  }
}

//
// Transitions
//

sealed class Transition<S extends State> {
  const Transition(
    this._parent, {
    required this.from,
    required this.to,
    this.label,
  });

  final Machine _parent;
  final Set<State> from;
  final S to;
  final String? label;
}

class SimpleTransition extends Transition<SimpleState> {
  const SimpleTransition._(
    super._parent, {
    required super.from,
    required super.to,
    super.label,
  });

  bool call() => _parent._attempt(this, null);
}

class ParameterizedTransition<T> extends Transition<ParameterizedState<T>> {
  const ParameterizedTransition._(
    super._parent, {
    required super.from,
    required super.to,
    String? label,
  });

  bool call(T data) => _parent._attempt(this, data);
}

//
// Callbacks
//

extension MachineCallbacks on Machine {
  void onChange(void Function(State? previous, State next) fn) => _onChange.add(fn);
}

extension SimpleStateCallbacks on SimpleState {
  void onEnter(void Function() fn) => //
      (_parent._onEnter[this] ??= []).add((_) => fn());

  void onExit(void Function() fn) => //
      (_parent._onExit[this] ??= []).add((_) => fn());
}

extension ParameterizedStateCallbacks<T> on ParameterizedState<T> {
  void onEnter(void Function(T data) fn) => //
      (_parent._onEnter[this] ??= []).add((data) => fn(data as T));

  void onExit(void Function(T data) fn) => //
      (_parent._onExit[this] ??= []).add((data) => fn(data as T));
}

extension TransitionCallbacks<S extends State> on Transition<S> {
  void onTrigger(void Function(State previous, S next) fn) => //
      (_parent._onTrigger[this] ??= []).add((previous) => fn(previous, to));
}

//
// Guards
//

extension SimpleStateGuards on SimpleState {
  void guard(bool Function() test) => //
      (_parent._guards[this] ??= []).add((_) => test());
}

extension ParameterizedStateGuards<T> on ParameterizedState<T> {
  void guard(bool Function(T data) test) => //
      (_parent._guards[this] ??= []).add((data) => test(data as T));
}

//
// Nesting
//

sealed class Ignition {
  static const start = SimpleStateIgnition._;
  static const pstart = ParameterizedStateIgnition._;

  const Ignition();

  void _start(Machine machine);
}

class SimpleStateIgnition extends Ignition {
  const SimpleStateIgnition._(this.state);

  final SimpleState state;

  @override
  void _start(Machine machine) => machine.start(state);
}

class ParameterizedStateIgnition<T> extends Ignition {
  const ParameterizedStateIgnition._(this.state, this.data);

  final ParameterizedState<T> state;
  final T data;

  @override
  void _start(Machine machine) => machine.pstart(state, data);
}

extension SimpleStateNesting on SimpleState {
  void nest(Machine child, Ignition Function() start) => //
      (_parent._children[this] ??= []).add((child, (_) => start()));
}

extension ParameterizedStateNesting<T> on ParameterizedState<T> {
  void nest(Machine child, Ignition Function(T data) start) => //
      (_parent._children[this] ??= []).add((child, (data) => start(data as T)));
}
