import 'dart:async';

/// Matches any machine state.
final Set<MachineState> any = Set.unmodifiable({
  SimpleMachineState._(
    '__any__',
    null,
    internal: true,
  )
});

/// The terminal machine state.
final MachineState<void> _none = SimpleMachineState._(
  '__none__',
  null,
  internal: true,
);

/// A nestable state machine implementation.
class Machine {
  /// This machine's name, primarily used for debugging.
  final String name;

  /// This machine's current state.
  MachineState get current => _current;

  /// The machine's stream of state changes.
  Stream<MachineState> get current$ => _currentController.stream;

  /// Whether or not this machine has been initialized yet.
  bool get isInitialized => _initial != null;

  /// Whether or not this machine is currently running.
  bool get isRunning => current != _none;

  /// The machine's initial state and data.
  MachineState? _initial;
  dynamic _initialData;

  /// All states creates by this machine.
  final _states = <MachineState>{};

  /// Whether or not this machine will queue up pending operations when not in operation.
  final bool queue;

  /// Pending operations for this machine.
  final _pending = <(MachineTransition, dynamic data)>[];

  /// The current state.
  MachineState _current = _none;

  /// Stream controller for the current state.
  final _currentController = StreamController<MachineState>.broadcast(sync: true);

  /// Creates a new machine with the given [name].
  Machine(
    this.name, {
    this.queue = false,
  });

  /// Sets this machine's initial state to [state], with some [data] for parameterized states.
  ///
  /// The machine must first [start] to see that state.
  void initialize<D>(MachineState<D> state, [D? data]) {
    assert(_states.contains(state), 'Initial state must be a known state.');
    assert(data is D, 'Invalid data for initial state.');
    _initial = state;
    _initialData = data;
  }

  /// Makes a new simple (void) state for this machine.
  ///
  /// Simple state transitions are created with [transition].
  SimpleMachineState state(String name) {
    final state = SimpleMachineState._(name, this);
    _states.add(state);
    return state;
  }

  /// Makes a new parameterized state for this machine.
  ///
  /// Parameterized state transitions are created with [ptransition].
  ParameterizedMachineState<D> pstate<D>(String name) {
    final state = ParameterizedMachineState<D>._(name, this);
    _states.add(state);
    return state;
  }

  /// Makes a new, simple transition for this machine.
  SimpleMachineTransition transition(
    String name,
    Set<MachineState> from,
    SimpleMachineState to,
  ) {
    return SimpleMachineTransition._(name, from, to, this);
  }

  /// Makes a new, parameterized transition for this machine.
  ParameterizedMachineTransition<D> ptransition<D>(
    String name,
    Set<MachineState> from,
    ParameterizedMachineState<D> to,
  ) {
    return ParameterizedMachineTransition._(name, from, to, this);
  }

  /// Starts the machine, processing all pending events.
  void start() {
    assert(_initial != null, 'You must supply an initial state with [initialize] first.');
    _transition(_initial!, _initialData);

    for (final (transition, data) in _pending) {
      _trigger(transition, data);
    }

    _pending.clear();
  }

  /// Stops the machine.
  void stop() {
    _transition(_none, null);
  }

  /// Disposes this machine.
  void dispose() {
    stop();
    _currentController.close();

    for (final state in _states) {
      state.dispose();
    }
  }

  @override
  String toString() {
    final machines = current._submachines;

    if (machines.isNotEmpty) {
      return '$current -> ${machines.join(',')}';
    } else {
      return current.toString();
    }
  }

  bool _trigger(MachineTransition transition, dynamic data) {
    // Store transitions that come in before the machine has started.
    if (!isRunning) {
      if (queue) {
        _pending.add((transition, data));
      }

      return false;
    }

    // Throw out transitions that cannot be performed given the current state.
    if (!(transition.from.contains(current) || transition.from == any)) {
      return false;
    }

    // Throw out the trigger if rejected by a transition or state guard.
    if (transition._guards.any((guard) => !guard(data)) || //
        transition.to._guards.any((guard) => !guard(data))) {
      return false;
    }

    _transition(transition.to, data);
    return true;
  }

  void _transition(MachineState next, dynamic data) {
    _current._onExit();
    _current = next;
    _currentController.add(next);
    next._onEnter(data);
  }
}

typedef Guard<D> = bool Function(D data);
typedef SimpleGuard = bool Function();

/// A single machine state, which may contain nested state machines.
sealed class MachineState<D> {
  /// The name of this state.
  final String name;

  /// Stream of enter events, with their accompanying data.
  Stream<D> get enter$ => _enterController.stream;

  /// Stream of exit events.
  Stream<void> get exit$ => _exitController.stream;

  /// The machine that owns this state.
  final Machine? _machine;

  /// Any machines nested inside this state.
  final _submachines = <Machine>[];

  /// Any guards for this state.
  final _guards = <Guard>[];

  /// Controller for enter events.
  final _enterController = StreamController<D>.broadcast(sync: true);

  /// Controller for exit events.
  final _exitController = StreamController<void>.broadcast(sync: true);

  MachineState(
    this.name,
    this._machine, {
    bool internal = false,
  })  : assert(internal || name != '__any__', '"__any__" is a reserved state name.'),
        assert(internal || name != '__none__', '"__none__" is a reserved state name.');

  /// Returns true if this state is active, false otherwise.
  bool call() {
    return _machine?.current == this;
  }

  /// Makes a new, nested machine inside this state.
  Machine nest(
    String name, {
    bool queue = false,
  }) {
    final machine = Machine(name, queue: queue);
    _submachines.add(machine);
    return machine;
  }

  @override
  String toString() {
    return name;
  }

  /// Disposes this state.
  void dispose() {
    _enterController.close();
    _exitController.close();

    for (final machine in _submachines) {
      machine.dispose();
    }
  }

  void _onEnter(D data) {
    _enterController.add(data);

    for (final machine in _submachines) {
      machine.start();
    }
  }

  void _onExit() {
    for (final machine in _submachines) {
      machine.stop();
    }

    _exitController.add(null);
  }
}

/// A machine state without parameters.
class SimpleMachineState extends MachineState<void> {
  SimpleMachineState._(super.name, super.machine, {super.internal});

  /// Guards entry to this state using the given test.
  void guard(SimpleGuard test) {
    _guards.add((_) => test());
  }
}

/// A machine state with parameterized data.
class ParameterizedMachineState<D> extends MachineState<D> {
  D? _data;

  D get data {
    if (!call()) {
      throw StateError('Cannot retrieve state data unless the state is active.');
    }

    return _data!;
  }

  ParameterizedMachineState._(super.name, super.machine, {super.internal});

  /// Guards entry to this state using the given test.
  void guard(Guard<D> test) {
    _guards.add((data) => test(data as D));
  }

  @override
  void _onEnter(D data) {
    _data = data;
    super._onEnter(data);
  }

  @override
  void _onExit() {
    super._onExit();
    _data = null;
  }
}

/// A transition from a set of states to a target state.
///
/// Call the transition to trigger it.
sealed class MachineTransition<D> {
  final String name;
  final Set<MachineState> from;
  final MachineState<D> to;
  final Machine _machine;
  final _guards = <Guard>[];

  MachineTransition(this.name, this.from, this.to, this._machine)
      : assert(from == any || _machine._states.containsAll(from), 'All "from" states must be known.'),
        assert(to == _none || _machine._states.contains(to), 'The "to" state must be known.');

  @override
  String toString() {
    return '${_machine.name}.$name';
  }

  /// Attempt to perform this transition with the given data.
  ///
  /// If the machine has not started yet, the transition will be enqueued.
  ///
  /// Returns true if triggered successfully, false otherwise.
  bool call(D data) {
    return _machine._trigger(this, data);
  }
}

/// A transition to a parameter-less state.
class SimpleMachineTransition extends MachineTransition<void> {
  SimpleMachineTransition._(super.name, super.from, super.to, super.machine);

  @override
  bool call([void data]) {
    return _machine._trigger(this, null);
  }

  /// Guards acceptance of this transition using the given test.
  void guard(SimpleGuard test) {
    _guards.add((_) => test());
  }
}

/// A transition to a parameterized state.
class ParameterizedMachineTransition<D> extends MachineTransition<D> {
  ParameterizedMachineTransition._(super.name, super.from, super.to, super.machine);

  /// Guards acceptance of this transition using the given test.
  void guard(Guard<D> test) {
    _guards.add((data) => test(data as D));
  }
}
