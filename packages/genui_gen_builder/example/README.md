# Example

`genui_gen_builder` is a `build_runner` generator and has no runnable example
of its own. The annotated widgets and the app that renders their generated
catalog items offline live in the repository's `example/` directory:

<https://github.com/dieg0lopez/genui_gen/tree/main/example>

Quick reference (see the package README for the full walkthrough):

```sh
dart pub add genui genui_gen json_schema_builder
dart pub add dev:build_runner dev:genui_gen_builder
dart run build_runner build
```
