import 'package:a2ui_core/a2ui_core.dart';

/// The protocol version a surface drawing on [catalog] speaks: the one the
/// catalog declares, or v0.9, which a catalog that declares none is read as.
///
/// The basic catalog of `package:a2ui_flutter/basic_catalog.dart` declares
/// v1.0, the one of `package:a2ui_flutter/v0_9/basic_catalog.dart` v0.9, and
/// a catalog derived from either keeps it.
A2uiProtocolVersion protocolVersionOf(
  Catalog<ComponentApi, FunctionApi> catalog,
) => catalog.protocolVersion ?? A2uiProtocolVersion.v0_9;
