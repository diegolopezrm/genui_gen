## 0.1.0

Initial release.

- `@GenUiWidget`, `@GenUiProp` and `@GenUiAction` annotations.
- `GenUiBindings`, `GenUiBinding` and `GenUiValues` runtime helpers that
  resolve literal, `{"path": ...}` and `{"call": ...}` values by composing
  genui's `Bound*` widgets.
- `genUiActionHandler` for dispatching `event` and `functionCall` A2UI actions
  the same way the core `Button` does. Malformed action data is reported as an
  `A2uiValidationException` so the model receives the message.
- `genUiReportMissing` for reporting required properties the model omitted,
  once per component instance and never for unresolved data bindings.
- `@GenUiProp` and `@GenUiAction` target both parameters and fields.
