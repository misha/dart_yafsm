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

  /// Pending operations for this machine.
  final _pendingOperations = <(MachineTransition, dynamic data)>[];

  /// The current state.
  MachineState _current = _none;

  /// Stream controller for the current state.
  final _currentController = StreamController<MachineState>.broadcast(sync: true);

  /// Creates a new machine with the given [name].
  Machine(this.name);

  /// Sets this machine's initial state to [state], with some [data] for parameterized states.
  ///
  /// The machine must first [start] to see that state.
  void initialize<D>(MachineState<D> state, [D? data]) {
    assert(_states.contains(state), 'Initial state must be a known state.');
    assert(state is SimpleMachineState || data is D, 'Parameterized states initial states require data.');
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
  ///
  /// Optionally clears any pending events instead of processing them.
  void start({
    bool clear = false,
  }) {
    assert(_initial != null, 'You must supply an initial state with [initialize] first.');
    _transition(_initial!, _initialData);

    if (!clear) {
      for (final (transition, data) in _pendingOperations) {
        _trigger(transition, data);
      }
    }

    _pendingOperations.clear();
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
      return '$current -> (${machines.join(',')})';
    } else {
      return current.toString();
    }
  }

  bool _trigger(MachineTransition transition, dynamic data) {
    if (!isRunning) {
      _pendingOperations.add((transition, data));
      return false;
    }

    if (transition.from.contains(current) || transition.from == any) {
      _transition(transition.to, data);
      return true;
    } else {
      return false;
    }
  }

  void _transition(MachineState next, dynamic data) {
    _current._onExit();
    _current = next;
    _currentController.add(next);
    next._onEnter(data);
  }
}

/// A single machine state, which may contain nested state machines.
sealed class MachineState<D> {
  /// The name of this state.
  final String name;

  /// The machine that owns this state.
  final Machine? _machine;

  /// Any machines nested inside this state.
  final _submachines = <Machine>[];

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
  Machine nest(String name) {
    final machine = Machine(name);
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

/// A parameter-less machine state.
class SimpleMachineState extends MachineState<void> {
  SimpleMachineState._(super.name, super.parent, {super.internal});

  /// Listens to events that occur on this state.
  void on({
    void Function()? enter,
    void Function()? exit,
  }) {
    if (enter != null) {
      _enterController.stream.forEach((_) => enter());
    }

    if (exit != null) {
      _exitController.stream.forEach((_) => exit());
    }
  }
}

/// A parameterized machine state.
class ParameterizedMachineState<D> extends MachineState<D> {
  ParameterizedMachineState._(super.name, super.parent, {super.internal});

  /// Listens to events that occur on this state.
  void on({
    void Function(D data)? enter,
    void Function()? exit,
  }) {
    if (enter != null) {
      _enterController.stream.forEach((data) => enter(data));
    }

    if (exit != null) {
      _exitController.stream.forEach((_) => exit());
    }
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

  MachineTransition(this.name, this.from, this.to, this._machine)
      : assert(from == any || _machine._states.containsAll(from), 'All "from" states must be known.'),
        assert(to == _none || _machine._states.contains(to), 'The "to" state must be known.');

  @override
  String toString() {
    return '${_machine.name}.$name';
  }
}

/// A transition to a parameter-less state.
class SimpleMachineTransition extends MachineTransition<void> {
  SimpleMachineTransition._(super.name, super.from, super.to, super.machine);

  /// Attempt to perform this transition.
  ///
  /// If the machine has not started yet, the transition will be enqueued.
  ///
  /// Returns true if triggered successfully, false otherwise.
  bool call([void _]) {
    return _machine._trigger(this, null);
  }
}

/// A transition to a parameterized state.
class ParameterizedMachineTransition<D> extends MachineTransition<D> {
  ParameterizedMachineTransition._(super.name, super.from, super.to, super.machine);

  /// Attempt to perform this transition with the given data.
  ///
  /// If the machine has not started yet, the transition will be enqueued.
  ///
  /// Returns true if triggered successfully, false otherwise.
  bool call(D data) {
    return _machine._trigger(this, data);
  }
}
