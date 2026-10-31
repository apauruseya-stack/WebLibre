// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cookie_banner.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pushes the cookie banner mode to the built-in extension whenever the
/// setting changes.
///
/// Activated at app scope in `main.dart`, so a change made on the settings
/// screen reaches native even when no browser view is mounted. The extension
/// itself does the detection and the clicking; this only sets its limits.

@ProviderFor(CookieBannerReplicationService)
final cookieBannerReplicationServiceProvider =
    CookieBannerReplicationServiceProvider._();

/// Pushes the cookie banner mode to the built-in extension whenever the
/// setting changes.
///
/// Activated at app scope in `main.dart`, so a change made on the settings
/// screen reaches native even when no browser view is mounted. The extension
/// itself does the detection and the clicking; this only sets its limits.
final class CookieBannerReplicationServiceProvider
    extends $NotifierProvider<CookieBannerReplicationService, void> {
  /// Pushes the cookie banner mode to the built-in extension whenever the
  /// setting changes.
  ///
  /// Activated at app scope in `main.dart`, so a change made on the settings
  /// screen reaches native even when no browser view is mounted. The extension
  /// itself does the detection and the clicking; this only sets its limits.
  CookieBannerReplicationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cookieBannerReplicationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cookieBannerReplicationServiceHash();

  @$internal
  @override
  CookieBannerReplicationService create() => CookieBannerReplicationService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$cookieBannerReplicationServiceHash() =>
    r'28f61e9c564e210e572798741e9875727782e11c';

/// Pushes the cookie banner mode to the built-in extension whenever the
/// setting changes.
///
/// Activated at app scope in `main.dart`, so a change made on the settings
/// screen reaches native even when no browser view is mounted. The extension
/// itself does the detection and the clicking; this only sets its limits.

abstract class _$CookieBannerReplicationService extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The latest cookie banner decision per site, newest event wins.
///
/// This is a display cache only. Losing it on a restart costs a status row, not
/// the decisions themselves: those live in the page and in the site's cookies.

@ProviderFor(CookieBannerStatus)
final cookieBannerStatusProvider = CookieBannerStatusProvider._();

/// The latest cookie banner decision per site, newest event wins.
///
/// This is a display cache only. Losing it on a restart costs a status row, not
/// the decisions themselves: those live in the page and in the site's cookies.
final class CookieBannerStatusProvider
    extends
        $NotifierProvider<
          CookieBannerStatus,
          Map<String, CookieBannerEventData>
        > {
  /// The latest cookie banner decision per site, newest event wins.
  ///
  /// This is a display cache only. Losing it on a restart costs a status row, not
  /// the decisions themselves: those live in the page and in the site's cookies.
  CookieBannerStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cookieBannerStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cookieBannerStatusHash();

  @$internal
  @override
  CookieBannerStatus create() => CookieBannerStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, CookieBannerEventData> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, CookieBannerEventData>>(
        value,
      ),
    );
  }
}

String _$cookieBannerStatusHash() =>
    r'6c95e57074acbe715ed75a9a0de668a13d76bc19';

/// The latest cookie banner decision per site, newest event wins.
///
/// This is a display cache only. Losing it on a restart costs a status row, not
/// the decisions themselves: those live in the page and in the site's cookies.

abstract class _$CookieBannerStatus
    extends $Notifier<Map<String, CookieBannerEventData>> {
  Map<String, CookieBannerEventData> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<String, CookieBannerEventData>,
              Map<String, CookieBannerEventData>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, CookieBannerEventData>,
                Map<String, CookieBannerEventData>
              >,
              Map<String, CookieBannerEventData>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The most recent decision for [host], if one was reported this session.
///
/// A parent-domain entry also matches its subdomains, so a decision recorded
/// for `example.com` still explains `www.example.com`.

@ProviderFor(cookieBannerStatusFor)
final cookieBannerStatusForProvider = CookieBannerStatusForFamily._();

/// The most recent decision for [host], if one was reported this session.
///
/// A parent-domain entry also matches its subdomains, so a decision recorded
/// for `example.com` still explains `www.example.com`.

final class CookieBannerStatusForProvider
    extends
        $FunctionalProvider<
          CookieBannerEventData?,
          CookieBannerEventData?,
          CookieBannerEventData?
        >
    with $Provider<CookieBannerEventData?> {
  /// The most recent decision for [host], if one was reported this session.
  ///
  /// A parent-domain entry also matches its subdomains, so a decision recorded
  /// for `example.com` still explains `www.example.com`.
  CookieBannerStatusForProvider._({
    required CookieBannerStatusForFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'cookieBannerStatusForProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cookieBannerStatusForHash();

  @override
  String toString() {
    return r'cookieBannerStatusForProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<CookieBannerEventData?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CookieBannerEventData? create(Ref ref) {
    final argument = this.argument as String?;
    return cookieBannerStatusFor(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CookieBannerEventData? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CookieBannerEventData?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CookieBannerStatusForProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cookieBannerStatusForHash() =>
    r'3a106f1dc59721148c570aa66c674cdfba5691bc';

/// The most recent decision for [host], if one was reported this session.
///
/// A parent-domain entry also matches its subdomains, so a decision recorded
/// for `example.com` still explains `www.example.com`.

final class CookieBannerStatusForFamily extends $Family
    with $FunctionalFamilyOverride<CookieBannerEventData?, String?> {
  CookieBannerStatusForFamily._()
    : super(
        retry: null,
        name: r'cookieBannerStatusForProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The most recent decision for [host], if one was reported this session.
  ///
  /// A parent-domain entry also matches its subdomains, so a decision recorded
  /// for `example.com` still explains `www.example.com`.

  CookieBannerStatusForProvider call(String? host) =>
      CookieBannerStatusForProvider._(argument: host, from: this);

  @override
  String toString() => r'cookieBannerStatusForProvider';
}
