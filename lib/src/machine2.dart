//
// Sentinels
//

final Set<State> any = .unmodifiable({SimpleState._(Machine(), label: 'any')});

//
// Machine
//

class Machine {
  final Set<State> _states = {};
  (State, dynamic)? _current;

  final List<void Function(State?, State)> _onChange = [];
  final Map<State, List<void Function(dynamic)>> _onEnter = {};
  final Map<State, List<void Function(dynamic)>> _onExit = {};
  final Map<Transition, List<void Function(State)>> _onTrigger = {};

  bool get isRunning => _current != null;
  bool get isStopped => _current == null;

  State get current {
    assert(isRunning, 'The machine is not running yet.');
    return _current!.$1;
  }

  void start(SimpleState state) {
    assert(isStopped, 'The machine is already running.');
    _apply(null, state, null);
  }

  void pstart<T, S extends ParameterizedState<T>>(S state, T data) {
    assert(isStopped, 'The machine is already running.');
    _apply(null, state, data);
  }

  void stop() {
    assert(isRunning, 'The machine is already stopped.');
    _current = null;
  }

  SimpleState state([String? label]) {
    final state = SimpleState._(this, label: label);
    _states.add(state);
    return state;
  }

  ParameterizedState<T> pstate<T>([String? label]) {
    final state = ParameterizedState<T>._(this, label: label);
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

    _apply(transition, transition.to, data);
    return true;
  }

  void _apply(Transition? transition, State next, dynamic data) {
    final previous = _current?.$1;

    for (final fn in _onExit[previous] ?? const <void Function(dynamic)>[]) {
      fn(data);
    }

    if (transition != null) {
      for (final fn in _onTrigger[transition] ?? const <void Function(State)>[]) {
        fn(previous!);
      }
    }

    _current = (next, data);

    for (final fn in _onChange) {
      fn(previous, next);
    }

    for (final fn in _onEnter[next] ?? const <void Function(dynamic)>[]) {
      fn(data);
    }
  }
}

//
// States
//

sealed class State {
  const State(this._parent, {this.label});

  final Machine _parent;
  final String? label;

  bool call() => identical(this, _parent.current);
}

class SimpleState extends State {
  const SimpleState._(super._parent, {super.label});
}

class ParameterizedState<T> extends State {
  const ParameterizedState._(super.parent, {super.label});

  T get data {
    assert(call(), 'The state is not active.');
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
