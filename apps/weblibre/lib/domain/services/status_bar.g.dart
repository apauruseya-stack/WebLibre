// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_bar.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Always-mounted side-effect provider that hides (or shows) the status bar
/// according to the [GeneralSettings.hideStatusBar] setting.

@ProviderFor(statusBarApplier)
final statusBarApplierProvider = StatusBarApplierProvider._();

/// Always-mounted side-effect provider that hides (or shows) the status bar
/// according to the [GeneralSettings.hideStatusBar] setting.

final class StatusBarApplierProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Always-mounted side-effect provider that hides (or shows) the status bar
  /// according to the [GeneralSettings.hideStatusBar] setting.
  StatusBarApplierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'statusBarApplierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statusBarApplierHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return statusBarApplier(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$statusBarApplierHash() => r'cbff4cf419f58bbeaa12d9a810ba4ad5664d3360';
