## 2.0.1

- States may now be safely called before a machine is turned on, returning `false`.

## 2.0.0

- Machine, state, and transition labels are now optional, final parameters.
- It is now possible to select a starting state dynamically with `start` and `pstart`.
- The `$` syntax for streams is gone. Instead, you pass callbacks to functions, e.g. `onEnter`, `onChange`.
- Machines no longer need to be `dispose`d, as all callbacks are executed synchronously.
- Transitions may now receive callbacks when they are confirmed to have triggered via `onTrigger`.
- States may now have any number of nested machines.
- Nested machines are now completely separate. For the class-based style, they must be a different class. This allows them to be reused multiple times.
- Nested machines may now dynamically determine their initial state, including based on data in root state, if parameterized.
- Machine `toString` has been redesigned to account for potentially multiple nested machines.
- Instructed Claude Code to test extensively the entire new implementation. AI-generated tests are isolated in separate files.

## 1.1.1

- Improved tests.
- Improved class-based example with `extends`.
- Slightly modified `toString` implementation to not used parentheses in the nested case.
    - For example, `on -> (blue -> (bright))` is now `on -> blue -> bright`.

## 1.1.0

- Allow configuration of queuing behavior for machines at construction time.
- **Breaking Change**. The new default is to *not* queue, and the `clear` parameter no longer exists.

## 1.0.4

- Added support for state and transition guards.

## 1.0.3

- It is no longer possible to use `pstate` without `ptransition` on accident.
- Parameterized states store their data while active, accessible with the `data` getter.

## 1.0.2

- Make machines and states listenable in the same way using streams.

## 1.0.1

- Improve semantics around transition execution.

## 1.0.0

- Initial version.
