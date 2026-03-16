// This file is completely written and managed by Claude Code.

import 'package:test/test.dart';
import 'package:yafsm/src/machine.dart';

//
// Machine subclasses
//

class SwitchMachine extends Machine {
  late final isOn = state('on');
  late final isOff = state('off');
  late final turnOn = transition({isOff}, isOn);
  late final turnOff = transition({isOn}, isOff);
}

class TrafficLight extends Machine {
  late final red = state('red');
  late final yellow = state('yellow');
  late final green = state('green');
  late final toYellow = transition({red, green}, yellow);
  late final toRed = transition({yellow}, red);
  late final toGreen = transition({yellow}, green);
}

class CounterMachine extends Machine {
  late final idle = state('idle');
  late final counting = pstate<int>('counting');
  late final begin = ptransition({idle}, counting);
  late final increment = ptransition({counting}, counting);
  late final reset = transition({counting}, idle);
}

class DoorMachine extends Machine {
  late final closed = state('closed');
  late final open = state('open');
  late final locked = pstate<({String code})>('locked');

  late final openDoor = transition({closed}, open);
  late final closeDoor = transition({open}, closed);
  late final lock = ptransition({closed}, locked);
  late final unlock = transition({locked}, closed);
}

class GuardedSwitchMachine extends Machine {
  bool hasElectricity = false;

  late final isOn = state('on');
  late final isOff = state('off');
  late final turnOn = transition({isOff}, isOn);
  late final turnOff = transition({isOn}, isOff);

  GuardedSwitchMachine() {
    isOn.guard(() => hasElectricity);
  }
}

class ParentMachine extends Machine {
  late final idle = state('idle');
  late final active = state('active');
  late final activate = transition({idle}, active);
  late final deactivate = transition({active}, idle);

  final Machine child;
  final SimpleState childInitial;

  ParentMachine(this.child, this.childInitial) {
    active.nest(child, () => .start(childInitial));
  }
}

class ResettableMachine extends Machine {
  late final a = state('a');
  late final b = state('b');
  late final c = state('c');
  late final goB = transition({a}, b);
  late final goC = transition({b}, c);
  late final resetToA = transition(any, a);
}

class FormMachine extends Machine {
  late final empty = state('empty');
  late final filling = pstate<({String name, String email})>('filling');
  late final submitted = pstate<({String name, String email, DateTime at})>('submitted');
  late final error = pstate<String>('error');

  late final startFilling = ptransition({empty}, filling);
  late final updateFields = ptransition({filling}, filling);
  late final submit = ptransition({filling}, submitted);
  late final fail = ptransition({filling}, error);
  late final retry = ptransition({error}, filling);
  late final reset = transition(any, empty);
}

class ConnectionMachine extends Machine {
  late final disconnected = state('disconnected');
  late final connecting = pstate<({String host, int port})>('connecting');
  late final connected = pstate<({String host, int port, int latency})>('connected');
  late final reconnecting = pstate<({String host, int port, int attempt})>('reconnecting');

  late final connect = ptransition({disconnected}, connecting);
  late final established = ptransition({connecting, reconnecting}, connected);
  late final lost = ptransition({connected}, reconnecting);
  late final disconnect = transition(any, disconnected);

  ConnectionMachine() {
    connecting.guard((data) => data.port > 0 && data.port <= 65535);
    reconnecting.guard((data) => data.attempt <= 5);
  }
}

class AuthMachine extends Machine {
  late final loggedOut = state('loggedOut');
  late final loggingIn = pstate<({String username, String password})>('loggingIn');
  late final loggedIn = pstate<({String username, String token, DateTime expiry})>('loggedIn');
  late final expired = pstate<({String username})>('expired');

  late final login = ptransition({loggedOut, expired}, loggingIn);
  late final succeed = ptransition({loggingIn}, loggedIn);
  late final expire = ptransition({loggedIn}, expired);
  late final logout = transition(any, loggedOut);
}

class ShoppingCartMachine extends Machine {
  late final empty = state('empty');
  late final hasItems = pstate<List<({String name, int qty, double price})>>('hasItems');
  late final checkedOut = pstate<({double total, String paymentId})>('checkedOut');

  late final addItem = ptransition({empty, hasItems}, hasItems);
  late final checkout = ptransition({hasItems}, checkedOut);
  late final clear = transition(any, empty);

  ShoppingCartMachine() {
    checkedOut.guard((data) => data.total > 0);
  }
}

class PlayerMachine extends Machine {
  late final idle = state('idle');
  late final playing = pstate<({String track, Duration position})>('playing');
  late final paused = pstate<({String track, Duration position})>('paused');
  late final buffering = pstate<({String track, double progress})>('buffering');

  late final play = ptransition({idle, paused}, playing);
  late final pause = ptransition({playing}, paused);
  late final buffer = ptransition({idle, playing, paused}, buffering);
  late final bufferDone = ptransition({buffering}, playing);
  late final stopPlayback = transition(any, idle);
}

class GuardedDoorMachine extends Machine {
  late final closed = state('closed');
  late final open = state('open');
  late final locked = pstate<({String code})>('locked');

  late final openDoor = transition({closed}, open);
  late final closeDoor = transition({open}, closed);
  late final lock = ptransition({closed}, locked);
  late final unlock = transition({locked}, closed);

  GuardedDoorMachine() {
    locked.guard((data) => data.code.length >= 4);
  }
}

class ElevatorMachine extends Machine {
  late final idle = pstate<({int floor})>('idle');
  late final moving = pstate<({int from, int to})>('moving');
  late final doorsOpen = pstate<({int floor})>('doorsOpen');

  late final move = ptransition({idle}, moving);
  late final arrive = ptransition({moving}, doorsOpen);
  late final closeDoors = ptransition({doorsOpen}, idle);

  ElevatorMachine() {
    moving.guard((data) => data.from != data.to);
    moving.guard((data) => data.to >= 0 && data.to <= 50);
  }
}

class NestedParentMachine extends Machine {
  late final off = state('off');
  late final on = pstate<({String mode})>('on');
  late final turnOn = ptransition({off}, on);
  late final turnOff = transition({on}, off);

  final Machine child;

  NestedParentMachine(this.child, Ignition Function(({String mode}) data) startChild) {
    on.nest(child, startChild);
  }
}

void main() {
  //
  // Basic subclass usage
  //

  test('SwitchMachine basic transitions', () {
    final m = SwitchMachine();
    m.start(m.isOff);

    expect(m.isOff(), isTrue);
    expect(m.isOn(), isFalse);

    m.turnOn();
    expect(m.isOn(), isTrue);
    expect(m.isOff(), isFalse);

    m.turnOff();
    expect(m.isOff(), isTrue);
  });

  test('SwitchMachine invalid transition returns false', () {
    final m = SwitchMachine();
    m.start(m.isOff);
    expect(m.turnOff(), isFalse);
    expect(m.isOff(), isTrue);
  });

  test('SwitchMachine current reflects active state', () {
    final m = SwitchMachine();
    m.start(m.isOff);
    expect(m.current, same(m.isOff));

    m.turnOn();
    expect(m.current, same(m.isOn));
  });

  //
  // TrafficLight — multi-source transitions
  //

  test('TrafficLight cycle', () {
    final t = TrafficLight();
    t.start(t.red);
    expect(t.red(), isTrue);

    t.toYellow();
    expect(t.yellow(), isTrue);

    t.toGreen();
    expect(t.green(), isTrue);

    t.toYellow();
    expect(t.yellow(), isTrue);

    t.toRed();
    expect(t.red(), isTrue);
  });

  test('TrafficLight cannot skip yellow', () {
    final t = TrafficLight();
    t.start(t.red);

    expect(t.toGreen(), isFalse);
    expect(t.toRed(), isFalse);
    expect(t.red(), isTrue);
  });

  //
  // CounterMachine — parameterized self-transitions
  //

  test('CounterMachine tracks count via parameterized state', () {
    final c = CounterMachine();
    c.start(c.idle);

    c.begin(0);
    expect(c.counting(), isTrue);
    expect(c.counting.data, 0);

    c.increment(1);
    expect(c.counting.data, 1);

    c.increment(2);
    expect(c.counting.data, 2);

    c.reset();
    expect(c.idle(), isTrue);
  });

  test('CounterMachine cannot begin when already counting', () {
    final c = CounterMachine();
    c.start(c.idle);

    c.begin(0);
    expect(c.begin(5), isFalse);
    expect(c.counting.data, 0);
  });

  //
  // DoorMachine — mixed simple and parameterized states
  //

  test('DoorMachine lock stores code', () {
    final d = DoorMachine();
    d.start(d.closed);

    d.lock((code: '1234'));
    expect(d.locked(), isTrue);
    expect(d.locked.data, (code: '1234'));

    d.unlock();
    expect(d.closed(), isTrue);
  });

  test('DoorMachine cannot open when locked', () {
    final d = DoorMachine();
    d.start(d.closed);

    d.lock((code: 'secret'));
    expect(d.openDoor(), isFalse);
    expect(d.locked(), isTrue);
  });

  test('DoorMachine full lifecycle', () {
    final d = DoorMachine();
    d.start(d.closed);

    d.openDoor();
    expect(d.open(), isTrue);

    d.closeDoor();
    expect(d.closed(), isTrue);

    d.lock((code: 'abc'));
    expect(d.locked(), isTrue);

    d.unlock();
    d.openDoor();
    expect(d.open(), isTrue);
  });

  //
  // GuardedSwitchMachine — guards in subclass constructor
  //

  test('GuardedSwitchMachine guard blocks until condition met', () {
    final m = GuardedSwitchMachine();
    m.start(m.isOff);

    expect(m.turnOn(), isFalse);
    expect(m.isOff(), isTrue);

    m.hasElectricity = true;
    expect(m.turnOn(), isTrue);
    expect(m.isOn(), isTrue);
  });

  test('GuardedSwitchMachine guard does not affect turnOff', () {
    final m = GuardedSwitchMachine();
    m.hasElectricity = true;
    m.start(m.isOn);

    m.hasElectricity = false;
    expect(m.turnOff(), isTrue);
    expect(m.isOff(), isTrue);
  });

  //
  // ParentMachine — nesting via constructor
  //

  test('ParentMachine starts child on activate', () {
    final child = SwitchMachine();
    final parent = ParentMachine(child, child.isOff);
    parent.start(parent.idle);

    expect(child.isStopped, isTrue);

    parent.activate();
    expect(child.isRunning, isTrue);
    expect(child.isOff(), isTrue);
  });

  test('ParentMachine stops child on deactivate', () {
    final child = SwitchMachine();
    final parent = ParentMachine(child, child.isOff);
    parent.start(parent.idle);

    parent.activate();
    child.turnOn();
    expect(child.isOn(), isTrue);

    parent.deactivate();
    expect(child.isStopped, isTrue);

    parent.activate();
    expect(child.isOff(), isTrue);
  });

  //
  // ResettableMachine — any sentinel in subclass
  //

  test('ResettableMachine reset from any state', () {
    final m = ResettableMachine();
    m.start(m.a);

    m.goB();
    m.goC();
    expect(m.c(), isTrue);

    m.resetToA();
    expect(m.a(), isTrue);
  });

  test('ResettableMachine reset from initial state', () {
    final m = ResettableMachine();
    m.start(m.a);

    m.resetToA();
    expect(m.a(), isTrue);
  });

  //
  // Callbacks on subclass machines
  //

  test('SwitchMachine callbacks fire correctly', () {
    final log = <String>[];
    final m = SwitchMachine();

    m.isOn.onEnter(() => log.add('enter:on'));
    m.isOn.onExit(() => log.add('exit:on'));
    m.isOff.onEnter(() => log.add('enter:off'));
    m.isOff.onExit(() => log.add('exit:off'));
    m.turnOn.onTrigger((_, __) => log.add('trigger:turnOn'));
    m.turnOff.onTrigger((_, __) => log.add('trigger:turnOff'));

    m.start(m.isOff);
    log.clear();

    m.turnOn();
    expect(log, orderedEquals(['exit:off', 'trigger:turnOn', 'enter:on']));
    log.clear();

    m.turnOff();
    expect(log, orderedEquals(['exit:on', 'trigger:turnOff', 'enter:off']));
  });

  test('CounterMachine parameterized callbacks receive data', () {
    final entries = <int>[];
    final exits = <int>[];
    final c = CounterMachine();

    c.counting.onEnter((n) => entries.add(n));
    c.counting.onExit((n) => exits.add(n));

    c.start(c.idle);
    c.begin(0);
    c.increment(1);
    c.increment(2);
    c.reset();

    expect(entries, [0, 1, 2]);
    expect(exits, [0, 1, 2]);
  });

  //
  // Multiple independent subclass instances
  //

  test('multiple SwitchMachine instances are independent', () {
    final a = SwitchMachine();
    final b = SwitchMachine();

    a.start(a.isOff);
    b.start(b.isOn);

    a.turnOn();
    expect(a.isOn(), isTrue);
    expect(b.isOn(), isTrue);

    b.turnOff();
    expect(a.isOn(), isTrue);
    expect(b.isOff(), isTrue);
  });

  //
  // Subclass toString uses labels
  //

  test('subclass states have labels from constructor', () {
    final m = SwitchMachine();
    expect(m.isOn.toString(), 'on');
    expect(m.isOff.toString(), 'off');
  });

  test('subclass states have monotonically increasing IDs', () {
    final m = TrafficLight();
    expect(m.red.id, lessThan(m.yellow.id));
    expect(m.yellow.id, lessThan(m.green.id));
  });

  //
  // FormMachine — complex parameterized record types
  //

  group('FormMachine', () {
    test('fill and submit', () {
      final f = FormMachine();
      f.start(f.empty);

      f.startFilling((name: 'Alice', email: 'a@b.c'));
      expect(f.filling(), isTrue);
      expect(f.filling.data.name, 'Alice');
      expect(f.filling.data.email, 'a@b.c');

      final now = DateTime(2026, 3, 16);
      f.submit((name: 'Alice', email: 'a@b.c', at: now));
      expect(f.submitted(), isTrue);
      expect(f.submitted.data.name, 'Alice');
      expect(f.submitted.data.at, now);
    });

    test('update fields replaces data', () {
      final f = FormMachine();
      f.start(f.empty);

      f.startFilling((name: '', email: ''));
      expect(f.filling.data, (name: '', email: ''));

      f.updateFields((name: 'Bob', email: ''));
      expect(f.filling.data.name, 'Bob');

      f.updateFields((name: 'Bob', email: 'bob@x.y'));
      expect(f.filling.data.email, 'bob@x.y');
    });

    test('fail captures error message', () {
      final f = FormMachine();
      f.start(f.empty);

      f.startFilling((name: 'A', email: 'bad'));
      f.fail('Invalid email');
      expect(f.error(), isTrue);
      expect(f.error.data, 'Invalid email');
    });

    test('retry from error returns to filling with new data', () {
      final f = FormMachine();
      f.start(f.empty);

      f.startFilling((name: 'A', email: 'bad'));
      f.fail('Invalid email');
      f.retry((name: 'A', email: 'good@x.y'));
      expect(f.filling(), isTrue);
      expect(f.filling.data.email, 'good@x.y');
    });

    test('reset from any state', () {
      final f = FormMachine();
      f.start(f.empty);

      f.startFilling((name: 'A', email: 'a@b.c'));
      f.submit((name: 'A', email: 'a@b.c', at: DateTime(2026)));
      f.reset();
      expect(f.empty(), isTrue);
    });

    test('reset from error state', () {
      final f = FormMachine();
      f.start(f.empty);

      f.startFilling((name: 'A', email: 'bad'));
      f.fail('oops');
      f.reset();
      expect(f.empty(), isTrue);
    });

    test('cannot submit from empty', () {
      final f = FormMachine();
      f.start(f.empty);

      expect(
        f.submit((name: 'A', email: 'a@b.c', at: DateTime(2026))),
        isFalse,
      );
      expect(f.empty(), isTrue);
    });

    test('callbacks on parameterized form states', () {
      final log = <String>[];
      final f = FormMachine();

      f.filling.onEnter((data) => log.add('filling:${data.name}'));
      f.filling.onExit((data) => log.add('left-filling:${data.name}'));
      f.submitted.onEnter((data) => log.add('submitted:${data.name}'));
      f.error.onEnter((msg) => log.add('error:$msg'));

      f.start(f.empty);
      f.startFilling((name: 'Alice', email: 'a@b.c'));
      f.fail('bad');
      f.retry((name: 'Bob', email: 'b@c.d'));
      f.submit((name: 'Bob', email: 'b@c.d', at: DateTime(2026)));

      expect(
        log,
        orderedEquals([
          'filling:Alice',
          'left-filling:Alice',
          'error:bad',
          'filling:Bob',
          'left-filling:Bob',
          'submitted:Bob',
        ]),
      );
    });
  });

  //
  // ConnectionMachine — guards on parameterized states
  //

  group('ConnectionMachine', () {
    test('connect and establish', () {
      final c = ConnectionMachine();
      c.start(c.disconnected);

      c.connect((host: 'localhost', port: 8080));
      expect(c.connecting(), isTrue);
      expect(c.connecting.data.host, 'localhost');
      expect(c.connecting.data.port, 8080);

      c.established((host: 'localhost', port: 8080, latency: 42));
      expect(c.connected(), isTrue);
      expect(c.connected.data.latency, 42);
    });

    test('guard rejects invalid port', () {
      final c = ConnectionMachine();
      c.start(c.disconnected);

      expect(c.connect((host: 'x', port: 0)), isFalse);
      expect(c.disconnected(), isTrue);

      expect(c.connect((host: 'x', port: 70000)), isFalse);
      expect(c.disconnected(), isTrue);

      expect(c.connect((host: 'x', port: 443)), isTrue);
      expect(c.connecting(), isTrue);
    });

    test('reconnect up to 5 attempts', () {
      final c = ConnectionMachine();
      c.start(c.disconnected);

      c.connect((host: 'h', port: 80));
      c.established((host: 'h', port: 80, latency: 10));
      c.lost((host: 'h', port: 80, attempt: 1));
      expect(c.reconnecting(), isTrue);
      expect(c.reconnecting.data.attempt, 1);

      c.established((host: 'h', port: 80, latency: 20));
      expect(c.connected(), isTrue);

      c.lost((host: 'h', port: 80, attempt: 5));
      expect(c.reconnecting(), isTrue);
    });

    test('guard blocks reconnect beyond 5 attempts', () {
      final c = ConnectionMachine();
      c.start(c.disconnected);

      c.connect((host: 'h', port: 80));
      c.established((host: 'h', port: 80, latency: 10));

      expect(c.lost((host: 'h', port: 80, attempt: 6)), isFalse);
      expect(c.connected(), isTrue);
    });

    test('disconnect from any state', () {
      final c = ConnectionMachine();
      c.start(c.disconnected);

      c.connect((host: 'h', port: 80));
      c.disconnect();
      expect(c.disconnected(), isTrue);

      c.connect((host: 'h', port: 80));
      c.established((host: 'h', port: 80, latency: 5));
      c.disconnect();
      expect(c.disconnected(), isTrue);
    });
  });

  //
  // AuthMachine — multi-source parameterized transitions
  //

  group('AuthMachine', () {
    test('login flow', () {
      final a = AuthMachine();
      a.start(a.loggedOut);

      a.login((username: 'alice', password: 'secret'));
      expect(a.loggingIn(), isTrue);
      expect(a.loggingIn.data.username, 'alice');

      final expiry = DateTime(2026, 4, 1);
      a.succeed((username: 'alice', token: 'tok123', expiry: expiry));
      expect(a.loggedIn(), isTrue);
      expect(a.loggedIn.data.token, 'tok123');
      expect(a.loggedIn.data.expiry, expiry);
    });

    test('token expiry and re-login', () {
      final a = AuthMachine();
      a.start(a.loggedOut);

      a.login((username: 'alice', password: 'pw'));
      a.succeed((username: 'alice', token: 't1', expiry: DateTime(2026)));

      a.expire((username: 'alice'));
      expect(a.expired(), isTrue);
      expect(a.expired.data.username, 'alice');

      a.login((username: 'alice', password: 'pw'));
      expect(a.loggingIn(), isTrue);
    });

    test('logout from any state', () {
      final a = AuthMachine();
      a.start(a.loggedOut);

      a.login((username: 'u', password: 'p'));
      a.logout();
      expect(a.loggedOut(), isTrue);

      a.login((username: 'u', password: 'p'));
      a.succeed((username: 'u', token: 't', expiry: DateTime(2026)));
      a.logout();
      expect(a.loggedOut(), isTrue);

      a.login((username: 'u', password: 'p'));
      a.succeed((username: 'u', token: 't', expiry: DateTime(2026)));
      a.expire((username: 'u'));
      a.logout();
      expect(a.loggedOut(), isTrue);
    });

    test('cannot succeed from loggedOut', () {
      final a = AuthMachine();
      a.start(a.loggedOut);

      expect(
        a.succeed((username: 'u', token: 't', expiry: DateTime(2026))),
        isFalse,
      );
      expect(a.loggedOut(), isTrue);
    });

    test('onEnter/onExit callbacks with auth data', () {
      final tokens = <String>[];
      final a = AuthMachine();

      a.loggedIn.onEnter((data) => tokens.add(data.token));
      a.loggedIn.onExit((data) => tokens.add('revoked:${data.token}'));

      a.start(a.loggedOut);
      a.login((username: 'u', password: 'p'));
      a.succeed((username: 'u', token: 'abc', expiry: DateTime(2026)));
      a.expire((username: 'u'));

      expect(tokens, ['abc', 'revoked:abc']);
    });
  });

  //
  // ShoppingCartMachine — list data in parameterized state
  //

  group('ShoppingCartMachine', () {
    test('add items and checkout', () {
      final s = ShoppingCartMachine();
      s.start(s.empty);

      s.addItem([(name: 'Widget', qty: 1, price: 9.99)]);
      expect(s.hasItems(), isTrue);
      expect(s.hasItems.data.length, 1);

      s.addItem([
        (name: 'Widget', qty: 1, price: 9.99),
        (name: 'Gadget', qty: 2, price: 19.99),
      ]);
      expect(s.hasItems.data.length, 2);

      s.checkout((total: 49.97, paymentId: 'pay_123'));
      expect(s.checkedOut(), isTrue);
      expect(s.checkedOut.data.paymentId, 'pay_123');
    });

    test('guard blocks zero-total checkout', () {
      final s = ShoppingCartMachine();
      s.start(s.empty);

      s.addItem([(name: 'Free', qty: 1, price: 0.0)]);
      expect(s.checkout((total: 0, paymentId: 'x')), isFalse);
      expect(s.hasItems(), isTrue);
    });

    test('clear from any state', () {
      final s = ShoppingCartMachine();
      s.start(s.empty);

      s.addItem([(name: 'A', qty: 1, price: 5.0)]);
      s.clear();
      expect(s.empty(), isTrue);

      s.addItem([(name: 'B', qty: 1, price: 10.0)]);
      s.checkout((total: 10.0, paymentId: 'p'));
      s.clear();
      expect(s.empty(), isTrue);
    });

    test('cannot checkout from empty', () {
      final s = ShoppingCartMachine();
      s.start(s.empty);
      expect(s.checkout((total: 10.0, paymentId: 'x')), isFalse);
    });
  });

  //
  // PlayerMachine — multiple parameterized source states
  //

  group('PlayerMachine', () {
    test('play pause resume cycle', () {
      final p = PlayerMachine();
      p.start(p.idle);

      p.play((track: 'song.mp3', position: Duration.zero));
      expect(p.playing(), isTrue);
      expect(p.playing.data.track, 'song.mp3');

      p.pause((track: 'song.mp3', position: Duration(seconds: 30)));
      expect(p.paused(), isTrue);
      expect(p.paused.data.position, Duration(seconds: 30));

      p.play((track: 'song.mp3', position: Duration(seconds: 30)));
      expect(p.playing(), isTrue);
    });

    test('buffering interrupts playback', () {
      final p = PlayerMachine();
      p.start(p.idle);

      p.play((track: 's.mp3', position: Duration.zero));
      p.buffer((track: 's.mp3', progress: 0.0));
      expect(p.buffering(), isTrue);

      p.bufferDone((track: 's.mp3', position: Duration(seconds: 5)));
      expect(p.playing(), isTrue);
    });

    test('buffer from idle', () {
      final p = PlayerMachine();
      p.start(p.idle);

      p.buffer((track: 's.mp3', progress: 0.5));
      expect(p.buffering(), isTrue);
      expect(p.buffering.data.progress, 0.5);
    });

    test('stop from any state', () {
      final p = PlayerMachine();
      p.start(p.idle);

      p.play((track: 's.mp3', position: Duration.zero));
      p.stopPlayback();
      expect(p.idle(), isTrue);

      p.play((track: 's.mp3', position: Duration.zero));
      p.pause((track: 's.mp3', position: Duration(seconds: 10)));
      p.stopPlayback();
      expect(p.idle(), isTrue);
    });

    test('cannot pause from idle', () {
      final p = PlayerMachine();
      p.start(p.idle);
      expect(p.pause((track: 's.mp3', position: Duration.zero)), isFalse);
    });

    test('parameterized callbacks track play history', () {
      final history = <String>[];
      final p = PlayerMachine();

      p.playing.onEnter((data) => history.add('play:${data.track}'));
      p.paused.onEnter((data) => history.add('pause@${data.position.inSeconds}s'));

      p.start(p.idle);
      p.play((track: 'a.mp3', position: Duration.zero));
      p.pause((track: 'a.mp3', position: Duration(seconds: 60)));
      p.play((track: 'a.mp3', position: Duration(seconds: 60)));
      p.stopPlayback();

      expect(history, ['play:a.mp3', 'pause@60s', 'play:a.mp3']);
    });
  });

  //
  // GuardedDoorMachine — parameterized guard on lock code
  //

  group('GuardedDoorMachine', () {
    test('guard rejects short lock codes', () {
      final d = GuardedDoorMachine();
      d.start(d.closed);

      expect(d.lock((code: 'ab')), isFalse);
      expect(d.closed(), isTrue);

      expect(d.lock((code: 'abcd')), isTrue);
      expect(d.locked(), isTrue);
      expect(d.locked.data.code, 'abcd');
    });

    test('unlock returns to closed', () {
      final d = GuardedDoorMachine();
      d.start(d.closed);

      d.lock((code: 'secret'));
      d.unlock();
      expect(d.closed(), isTrue);
    });
  });

  //
  // ElevatorMachine — multiple guards on same parameterized state
  //

  group('ElevatorMachine', () {
    test('basic floor movement', () {
      final e = ElevatorMachine();
      e.pstart(e.idle, (floor: 1));

      e.move((from: 1, to: 5));
      expect(e.moving(), isTrue);
      expect(e.moving.data, (from: 1, to: 5));

      e.arrive((floor: 5));
      expect(e.doorsOpen(), isTrue);
      expect(e.doorsOpen.data.floor, 5);

      e.closeDoors((floor: 5));
      expect(e.idle(), isTrue);
      expect(e.idle.data.floor, 5);
    });

    test('guard blocks same-floor movement', () {
      final e = ElevatorMachine();
      e.pstart(e.idle, (floor: 3));

      expect(e.move((from: 3, to: 3)), isFalse);
      expect(e.idle(), isTrue);
    });

    test('guard blocks out-of-range floor', () {
      final e = ElevatorMachine();
      e.pstart(e.idle, (floor: 1));

      expect(e.move((from: 1, to: -1)), isFalse);
      expect(e.move((from: 1, to: 51)), isFalse);
      expect(e.move((from: 1, to: 50)), isTrue);
    });

    test('full round trip', () {
      final e = ElevatorMachine();
      e.pstart(e.idle, (floor: 0));

      e.move((from: 0, to: 10));
      e.arrive((floor: 10));
      e.closeDoors((floor: 10));

      e.move((from: 10, to: 0));
      e.arrive((floor: 0));
      e.closeDoors((floor: 0));

      expect(e.idle.data.floor, 0);
    });

    test('callbacks with parameterized elevator data', () {
      final log = <String>[];
      final e = ElevatorMachine();

      e.moving.onEnter((d) => log.add('moving:${d.from}->${d.to}'));
      e.doorsOpen.onEnter((d) => log.add('doors@${d.floor}'));
      e.idle.onEnter((d) => log.add('idle@${d.floor}'));

      e.pstart(e.idle, (floor: 1));
      log.clear();

      e.move((from: 1, to: 5));
      e.arrive((floor: 5));
      e.closeDoors((floor: 5));

      expect(log, ['moving:1->5', 'doors@5', 'idle@5']);
    });
  });

  //
  // NestedParentMachine — parameterized parent with nested child
  //

  group('NestedParentMachine', () {
    test('child starts based on parent parameterized data', () {
      final child = Machine();
      final normalMode = child.state('normal');
      final turboMode = child.state('turbo');

      final parent = NestedParentMachine(child, (data) {
        return data.mode == 'turbo' ? .start(turboMode) : .start(normalMode);
      });

      parent.start(parent.off);
      parent.turnOn((mode: 'normal'));
      expect(normalMode(), isTrue);

      parent.turnOff();
      parent.turnOn((mode: 'turbo'));
      expect(turboMode(), isTrue);
    });

    test('child stops when parent turns off', () {
      final child = Machine();
      final s = child.state('s');

      final parent = NestedParentMachine(child, (_) => .start(s));

      parent.start(parent.off);
      parent.turnOn((mode: 'any'));
      expect(child.isRunning, isTrue);

      parent.turnOff();
      expect(child.isStopped, isTrue);
    });

    test('child restarts with fresh data on re-entry', () {
      final child = Machine();
      final a = child.state('a');
      final b = child.state('b');
      child.transition({a}, b);

      final parent = NestedParentMachine(child, (_) => .start(a));

      parent.start(parent.off);
      parent.turnOn((mode: 'x'));
      child.transition({a}, b)();
      expect(b(), isTrue);

      parent.turnOff();
      parent.turnOn((mode: 'y'));
      expect(a(), isTrue);
    });
  });
}
