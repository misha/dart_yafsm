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
