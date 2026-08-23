## 0.1.2

- Corrected the declared dependency lower bounds so they match what the
  generator actually requires: `source_gen` >= 4.1.0 (for
  `TypeChecker.typeNamedLiterally`) and `analyzer` >= 10.0.0 (where the element
  API the generator uses is no longer marked experimental). The previous
  0.1.0/0.1.1 lower bounds did not resolve to a working build.

