// This file is completely written and managed by Claude Code.

import 'package:test/test.dart';
import 'package:yafsm/src/machine2.dart';

void main() {
  //
  // Basic lifecycle
  //

  test('isRunning and isStopped reflect machine state', () {
    final m = Machine();
    final a = m.state();
    expect(m.isStopped, isTrue);
    expect(m.isRunning, isFalse);

    m.start(a);
    expect(m.isRunning, isTrue);
    expect(m.isStopped, isFalse);

    m.stop();
    expect(m.isStopped, isTrue);
    expect(m.isRunning, isFalse);
  });

  test('start throws when already running', () {
    final m = Machine();
    final a = m.state();
    m.start(a);
    expect(() => m.start(a), throwsStateError);
  });

  test('pstart throws when already running', () {
    final m = Machine();
    final a = m.pstate<int>();
    m.pstart(a, 1);
    expect(() => m.pstart(a, 2), throwsStateError);
  });

  test('current throws when stopped', () {
    final m = Machine();
    m.state();
    expect(() => m.current, throwsStateError);
  });

  test('stop is idempotent', () {
    final m = Machine();
    final a = m.state();
    m.start(a);
    m.stop();
    m.stop();
    expect(m.isStopped, isTrue);
  });

  test('stop on a never-started machine is safe', () {
    final m = Machine();
    m.state();
    m.stop();
    expect(m.isStopped, isTrue);
  });

  test('can restart after stop', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);

    m.start(a);
    go();
    expect(b(), isTrue);

    m.stop();
    m.start(a);
    expect(a(), isTrue);
  });

  //
  // State.call()
  //

  test('state call returns true only for active state', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);

    m.start(a);
    expect(a(), isTrue);
    expect(b(), isFalse);

    go();
    expect(a(), isFalse);
    expect(b(), isTrue);
  });

  test('states with same label are distinct', () {
    final m = Machine();
    final a1 = m.state('x');
    final a2 = m.state('x');
    final go = m.transition({a1}, a2);

    m.start(a1);
    expect(a1(), isTrue);
    expect(a2(), isFalse);

    go();
    expect(a1(), isFalse);
    expect(a2(), isTrue);
  });

  //
  // Transitions
  //

  test('transition returns true on success and false on failure', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final aToB = m.transition({a}, b);

    m.start(a);
    expect(aToB(), isTrue);
    expect(aToB(), isFalse);
  });

  test('transition returns false when machine is stopped', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);
    expect(go(), isFalse);
  });

  test('transition from multiple specific source states', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final c = m.state();
    final toC = m.transition({a, b}, c);
    final toA = m.transition({c}, a);
    final toB = m.transition({a}, b);

    m.start(a);
    expect(toC(), isTrue);
    expect(c(), isTrue);

    toA();
    toB();
    expect(toC(), isTrue);
    expect(c(), isTrue);
  });

  test('self-transition', () {
    final log = <String>[];
    final m = Machine();
    final a = m.state();
    final loop = m.transition({a}, a);

    a.onEnter(() => log.add('enter'));
    a.onExit(() => log.add('exit'));
    m.onChange((_, __) => log.add('change'));

    m.start(a);
    log.clear();

    expect(loop(), isTrue);
    expect(a(), isTrue);
    expect(log, orderedEquals(['exit', 'enter', 'change']));
  });

  test('any wildcard transition', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final c = m.state();
    final reset = m.transition(any, a);
    final goB = m.transition({a}, b);
    final goC = m.transition({b}, c);

    m.start(b);
    goC();
    expect(c(), isTrue);

    reset();
    expect(a(), isTrue);

    goB();
    reset();
    expect(a(), isTrue);
  });

  test('parameterized transition carries data', () {
    final m = Machine();
    final a = m.state();
    final b = m.pstate<String>();
    final go = m.ptransition({a}, b);

    m.start(a);
    go('hello');
    expect(b(), isTrue);
    expect(b.data, 'hello');
  });

  test('parameterized transition data updates on repeated entry', () {
    final m = Machine();
    final a = m.state();
    final b = m.pstate<int>();
    final goB = m.ptransition({a}, b);
    final goA = m.transition({b}, a);

    m.start(a);
    goB(1);
    expect(b.data, 1);

    goA();
    goB(2);
    expect(b.data, 2);
  });

  //
  // Parameterized states
  //

  test('parameterized state data throws when not active', () {
    final m = Machine();
    final a = m.pstate<int>();
    m.pstart(a, 42);
    expect(a.data, 42);

    m.stop();
    expect(() => a.data, throwsStateError);
  });

  test('pstart sets initial data', () {
    final m = Machine();
    final a = m.pstate<({String name, int age})>();
    m.pstart(a, (name: 'Alice', age: 30));
    expect(a.data, (name: 'Alice', age: 30));
  });

  //
  // Guards
  //

  test('guard blocks transition', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);

    b.guard(() => false);

    m.start(a);
    expect(go(), isFalse);
    expect(a(), isTrue);
  });

  test('guard does not fire callbacks when blocking', () {
    final log = <String>[];
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);

    b.guard(() => false);
    a.onExit(() => log.add('exit a'));
    b.onEnter(() => log.add('enter b'));
    m.onChange((_, __) => log.add('change'));

    m.start(a);
    log.clear();

    go();
    expect(log, isEmpty);
  });

  test('multiple guards must all pass', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);

    var first = true;
    var second = true;
    b.guard(() => first);
    b.guard(() => second);

    m.start(a);

    first = true;
    second = false;
    expect(go(), isFalse);

    first = false;
    second = true;
    expect(go(), isFalse);

    first = true;
    second = true;
    expect(go(), isTrue);
    expect(b(), isTrue);
  });

  test('guard on parameterized state receives data', () {
    final m = Machine();
    final a = m.state();
    final b = m.pstate<int>();
    final go = m.ptransition({a}, b);

    b.guard((n) => n > 0);

    m.start(a);
    expect(go(-1), isFalse);
    expect(go(5), isTrue);
    expect(b.data, 5);
  });

  test('guard re-evaluated each attempt', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);

    var allowed = false;
    b.guard(() => allowed);

    m.start(a);
    expect(go(), isFalse);

    allowed = true;
    expect(go(), isTrue);
  });

  //
  // Callbacks — onChange
  //

  test('onChange fires on start', () {
    final changes = <(State?, State?)>[];
    final m = Machine();
    final a = m.state();
    m.onChange((prev, next) => changes.add((prev, next)));

    m.start(a);
    expect(changes, [(null, a)]);
  });

  test('onChange receives null previous on initial start', () {
    State? seenPrevious = Machine().state(); // sentinel
    final m = Machine();
    final a = m.state();
    m.onChange((prev, _) => seenPrevious = prev);

    m.start(a);
    expect(seenPrevious, isNull);
  });

  test('multiple onChange listeners all fire in order', () {
    final log = <int>[];
    final m = Machine();
    final a = m.state();

    m.onChange((_, __) => log.add(1));
    m.onChange((_, __) => log.add(2));
    m.onChange((_, __) => log.add(3));

    m.start(a);
    expect(log, orderedEquals([1, 2, 3]));
  });

  //
  // Callbacks — onEnter / onExit
  //

  test('onEnter fires on start before onChange', () {
    final log = <String>[];
    final m = Machine();
    final a = m.state();
    a.onEnter(() => log.add('enter'));
    m.onChange((_, __) => log.add('change'));

    m.start(a);
    expect(log, orderedEquals(['enter', 'change']));
  });

  test('onExit does not fire on start', () {
    var exited = false;
    final m = Machine();
    final a = m.state();
    a.onExit(() => exited = true);

    m.start(a);
    expect(exited, isFalse);
  });

  test('onExit fires on stop before onChange', () {
    final log = <String>[];
    final m = Machine();
    final a = m.state();
    a.onExit(() => log.add('exit'));
    m.onChange((_, __) => log.add('change'));

    m.start(a);
    log.clear();

    m.stop();
    expect(log, orderedEquals(['exit', 'change']));
  });

  test('onExit fires before onEnter on transition', () {
    final log = <String>[];
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);

    a.onExit(() => log.add('exit a'));
    b.onEnter(() => log.add('enter b'));

    m.start(a);
    log.clear();

    go();
    expect(log, orderedEquals(['exit a', 'enter b']));
  });

  test('multiple onEnter callbacks fire in registration order', () {
    final log = <int>[];
    final m = Machine();
    final a = m.state();
    a.onEnter(() => log.add(1));
    a.onEnter(() => log.add(2));
    a.onEnter(() => log.add(3));

    m.start(a);
    expect(log, orderedEquals([1, 2, 3]));
  });

  test('parameterized onEnter receives data', () {
    String? received;
    final m = Machine();
    final a = m.pstate<String>();
    a.onEnter((data) => received = data);

    m.pstart(a, 'hello');
    expect(received, 'hello');
  });

  test('parameterized onExit receives the active data', () {
    int? received;
    final m = Machine();
    final a = m.pstate<int>();
    final b = m.state();
    final go = m.transition({a}, b);
    a.onExit((data) => received = data);

    m.pstart(a, 99);
    go();
    expect(received, 99);
  });

  //
  // Callbacks — onTrigger
  //

  test('onTrigger fires with previous state', () {
    final triggers = <(State, State)>[];
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);
    go.onTrigger((prev, next) => triggers.add((prev, next)));

    m.start(a);
    go();
    expect(triggers, [(a, b)]);
  });

  test('onTrigger does not fire on start', () {
    var fired = false;
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);
    go.onTrigger((_, __) => fired = true);

    m.start(a);
    expect(fired, isFalse);
  });

  test('onTrigger does not fire on stop', () {
    var fired = false;
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);
    go.onTrigger((_, __) => fired = true);

    m.start(a);
    m.stop();
    expect(fired, isFalse);
  });

  //
  // Full callback ordering
  //

  test('full callback order: onExit, child stop, onTrigger, onEnter, child start, onChange', () {
    final log = <String>[];
    final parent = Machine();
    final a = parent.state('a');
    final b = parent.state('b');
    final go = parent.transition({a}, b);

    final childA = Machine();
    final ca = childA.state();
    ca.onExit(() => log.add('child a stop'));

    final childB = Machine();
    final cb = childB.state();
    cb.onEnter(() => log.add('child b start'));

    a.nest(childA, () => .start(ca));
    b.nest(childB, () => .start(cb));

    a.onExit(() => log.add('exit a'));
    b.onEnter(() => log.add('enter b'));
    go.onTrigger((_, __) => log.add('trigger'));
    parent.onChange((_, __) => log.add('change'));

    parent.start(a);
    log.clear();

    go();
    expect(
      log,
      orderedEquals([
        'exit a',
        'child a stop',
        'trigger',
        'enter b',
        'child b start',
        'change',
      ]),
    );
  });

  //
  // Nesting — simple
  //

  test('nested machine starts when parent enters state', () {
    final parent = Machine();
    final a = parent.state();
    final child = Machine();
    final c1 = child.state();
    a.nest(child, () => .start(c1));

    parent.start(a);
    expect(child.isRunning, isTrue);
    expect(c1(), isTrue);
  });

  test('nested machine stops when parent leaves state', () {
    final parent = Machine();
    final a = parent.state();
    final b = parent.state();
    final go = parent.transition({a}, b);
    final child = Machine();
    final c1 = child.state();
    a.nest(child, () => .start(c1));

    parent.start(a);
    go();
    expect(child.isStopped, isTrue);
  });

  test('nested machine restarts fresh on re-entry', () {
    final parent = Machine();
    final a = parent.state();
    final b = parent.state();
    final goB = parent.transition({a}, b);
    final goA = parent.transition({b}, a);

    final child = Machine();
    final c1 = child.state();
    final c2 = child.state();
    final advance = child.transition({c1}, c2);
    a.nest(child, () => .start(c1));

    parent.start(a);
    advance();
    expect(c2(), isTrue);

    goB();
    goA();
    expect(c1(), isTrue);
  });

  test('nested machine transitions do not affect parent', () {
    final parent = Machine();
    final a = parent.state();
    final child = Machine();
    final c1 = child.state();
    final c2 = child.state();
    final advance = child.transition({c1}, c2);
    a.nest(child, () => .start(c1));

    parent.start(a);
    advance();
    expect(a(), isTrue);
    expect(c2(), isTrue);
  });

  test('multiple nested machines on one state', () {
    final parent = Machine();
    final a = parent.state();

    final child1 = Machine();
    final s1 = child1.state();
    final child2 = Machine();
    final s2 = child2.state();

    a.nest(child1, () => .start(s1));
    a.nest(child2, () => .start(s2));

    parent.start(a);
    expect(child1.isRunning, isTrue);
    expect(child2.isRunning, isTrue);

    parent.stop();
    expect(child1.isStopped, isTrue);
    expect(child2.isStopped, isTrue);
  });

  test('deeply nested machines (3 levels)', () {
    final top = Machine();
    final t1 = top.state();

    final mid = Machine();
    final m1 = mid.state();

    final bottom = Machine();
    final b1 = bottom.state();

    t1.nest(mid, () => .start(m1));
    m1.nest(bottom, () => .start(b1));

    top.start(t1);
    expect(mid.isRunning, isTrue);
    expect(bottom.isRunning, isTrue);
    expect(b1(), isTrue);

    top.stop();
    expect(mid.isStopped, isTrue);
    expect(bottom.isStopped, isTrue);
  });

  //
  // Nesting — parameterized parent
  //

  test('parameterized parent passes data to child ignition', () {
    final parent = Machine();
    final idle = parent.state();
    final active = parent.pstate<int>();
    final go = parent.ptransition({idle}, active);

    final child = Machine();
    final c1 = child.pstate<int>();
    active.nest(child, (n) => .pstart(c1, n * 10));

    parent.start(idle);
    go(5);
    expect(c1(), isTrue);
    expect(c1.data, 50);
  });

  test('parameterized parent re-entry passes fresh data to child', () {
    final parent = Machine();
    final a = parent.pstate<String>();
    final b = parent.state();
    final goB = parent.transition({a}, b);
    final goA = parent.ptransition({b}, a);

    final child = Machine();
    final c1 = child.pstate<String>();
    a.nest(child, (data) => .pstart(c1, data));

    parent.pstart(a, 'first');
    expect(c1.data, 'first');

    goB();
    goA('second');
    expect(c1.data, 'second');
  });

  //
  // Nesting — same child on multiple parent states
  //

  test('same child machine attached to different parent states', () {
    final parent = Machine();
    final a = parent.state();
    final b = parent.state();
    final goB = parent.transition({a}, b);
    final goA = parent.transition({b}, a);

    final child = Machine();
    final c1 = child.state();
    final c2 = child.state();
    child.transition({c1}, c2);

    a.nest(child, () => .start(c1));
    b.nest(child, () => .start(c2));

    parent.start(a);
    expect(c1(), isTrue);

    goB();
    expect(c2(), isTrue);

    goA();
    expect(c1(), isTrue);
  });

  //
  // Edge cases
  //

  test('transition on stopped machine returns false', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);
    expect(go(), isFalse);
  });

  test('guard blocks without side effects', () {
    final log = <String>[];
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);

    b.guard(() => false);
    a.onExit(() => log.add('exit'));
    b.onEnter(() => log.add('enter'));
    go.onTrigger((_, __) => log.add('trigger'));
    m.onChange((_, __) => log.add('change'));

    m.start(a);
    log.clear();

    go();
    expect(log, isEmpty);
    expect(a(), isTrue);
  });

  test('label is accessible on states and transitions', () {
    final m = Machine();
    final a = m.state('alpha');
    final b = m.state();
    final go = m.transition({a}, b, 'go');

    expect(a.label, 'alpha');
    expect(b.label, isNull);
    expect(go.label, 'go');
  });

  //
  // State.call() when stopped
  //

  test('state call throws when machine is stopped', () {
    final m = Machine();
    final a = m.state();
    expect(() => a(), throwsStateError);
  });

  test('state call throws after machine is stopped', () {
    final m = Machine();
    final a = m.state();
    m.start(a);
    expect(a(), isTrue);
    m.stop();
    expect(() => a(), throwsStateError);
  });

  //
  // onChange fires on stop with (previous, null)
  //

  test('onChange fires on stop with null next', () {
    final changes = <(State?, State?)>[];
    final m = Machine();
    final a = m.state();
    m.onChange((prev, next) => changes.add((prev, next)));

    m.start(a);
    changes.clear();

    m.stop();
    expect(changes, [(a, null)]);
  });

  //
  // toString
  //

  test('labeled state toString returns label', () {
    final m = Machine();
    final a = m.state('hello');
    expect(a.toString(), 'hello');
  });

  test('unlabeled state toString returns state#id', () {
    final m = Machine();
    final a = m.state();
    expect(a.toString(), 'state#${a.id}');
  });

  //
  // State IDs
  //

  test('state IDs are monotonically increasing', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final c = m.state();
    expect(a.id, lessThan(b.id));
    expect(b.id, lessThan(c.id));
  });

  //
  // Transition from/to field access
  //

  test('transition exposes from set and to state', () {
    final m = Machine();
    final a = m.state();
    final b = m.state();
    final go = m.transition({a}, b);

    expect(go.from, contains(a));
    expect(go.to, same(b));
  });

  test('any transition exposes any sentinel as from', () {
    final m = Machine();
    final a = m.state();
    final reset = m.transition(any, a);

    expect(identical(reset.from, any), isTrue);
  });

  //
  // Nested child onExit fires when parent transitions away
  //

  test('nested child onExit callback fires when parent leaves state', () {
    final log = <String>[];
    final parent = Machine();
    final a = parent.state();
    final b = parent.state();
    final go = parent.transition({a}, b);

    final child = Machine();
    final c1 = child.state();
    c1.onExit(() => log.add('child exit'));
    a.nest(child, () => .start(c1));

    parent.start(a);
    expect(child.isRunning, isTrue);
    log.clear();

    go();
    expect(log, contains('child exit'));
  });

  //
  // Nesting with Ignition.pstart
  //

  test('nest with pstart ignition', () {
    final parent = Machine();
    final a = parent.state();

    final child = Machine();
    final loaded = child.pstate<int>();
    a.nest(child, () => .pstart(loaded, 42));

    parent.start(a);
    expect(loaded(), isTrue);
    expect(loaded.data, 42);
  });

  //
  // Machine.toString()
  //

  group('toString', () {
    test('stopped machine', () {
      final m = Machine();
      m.state('a');
      expect(m.toString(), '[]');
    });

    test('running machine with no children', () {
      final m = Machine();
      final a = m.state('a');
      m.start(a);
      expect(m.toString(), '[a]');
    });

    test('running machine uses state label', () {
      final m = Machine();
      final a = m.state('hello');
      m.start(a);
      expect(m.toString(), '[hello]');
    });

    test('running machine with unlabeled state', () {
      final m = Machine();
      final a = m.state();
      m.start(a);
      expect(m.toString(), '[state#${a.id}]');
    });

    test('single nested child', () {
      final parent = Machine();
      final a = parent.state('a');

      final child = Machine();
      final x = child.state('x');
      a.nest(child, () => .start(x));

      parent.start(a);
      expect(parent.toString(), '[a [x]]');
    });

    test('multiple nested children', () {
      final parent = Machine();
      final a = parent.state('a');

      final child1 = Machine();
      final x = child1.state('x');
      final child2 = Machine();
      final y = child2.state('y');

      a.nest(child1, () => .start(x));
      a.nest(child2, () => .start(y));

      parent.start(a);
      expect(parent.toString(), '[a [x, y]]');
    });

    test('deeply nested (3 levels)', () {
      final top = Machine();
      final a = top.state('a');

      final mid = Machine();
      final b = mid.state('b');

      final bottom = Machine();
      final c = bottom.state('c');

      a.nest(mid, () => .start(b));
      b.nest(bottom, () => .start(c));

      top.start(a);
      expect(top.toString(), '[a [b [c]]]');
    });

    test('toString updates after transition', () {
      final m = Machine();
      final a = m.state('a');
      final b = m.state('b');
      final go = m.transition({a}, b);

      m.start(a);
      expect(m.toString(), '[a]');

      go();
      expect(m.toString(), '[b]');
    });

    test('toString updates when nested machine transitions', () {
      final parent = Machine();
      final a = parent.state('a');

      final child = Machine();
      final x = child.state('x');
      final y = child.state('y');
      final advance = child.transition({x}, y);

      a.nest(child, () => .start(x));

      parent.start(a);
      expect(parent.toString(), '[a [x]]');

      advance();
      expect(parent.toString(), '[a [y]]');
    });

    test('toString after parent leaves nested state', () {
      final parent = Machine();
      final a = parent.state('a');
      final b = parent.state('b');
      final go = parent.transition({a}, b);

      final child = Machine();
      final x = child.state('x');
      a.nest(child, () => .start(x));

      parent.start(a);
      expect(parent.toString(), '[a [x]]');

      go();
      expect(parent.toString(), '[b]');
    });

    test('toString after stop', () {
      final m = Machine();
      final a = m.state('a');
      m.start(a);
      m.stop();
      expect(m.toString(), '[]');
    });

    test('mixed nesting: one child with sub-children, one without', () {
      final top = Machine();
      final a = top.state('root');

      final child1 = Machine();
      final leaf = child1.state('leaf');

      final child2 = Machine();
      final branch = child2.state('branch');
      final grandchild = Machine();
      final deep = grandchild.state('deep');
      branch.nest(grandchild, () => .start(deep));

      a.nest(child1, () => .start(leaf));
      a.nest(child2, () => .start(branch));

      top.start(a);
      expect(top.toString(), '[root [leaf, branch [deep]]]');
    });
  });
}
