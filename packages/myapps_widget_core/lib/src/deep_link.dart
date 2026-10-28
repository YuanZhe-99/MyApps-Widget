/// A parsed widget tap target: `<scheme>://widget/<kind>[?instance=<id>]`.
class WidgetDeepLink {
  /// Purpose: Hold one widget tap target.
  /// Inputs: `kind`; optional `instanceId`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  const WidgetDeepLink({required this.kind, this.instanceId});

  /// The widget kind that was tapped.
  final String kind;

  /// The configured instance, for configurable widgets.
  final String? instanceId;

  /// Purpose: Build the URI a native widget opens when tapped.
  /// Inputs: `scheme` — the app's URL scheme, such as `myday`.
  /// Returns: `Uri`.
  /// Side effects: None.
  /// Notes: The app registers the scheme and routes the link itself.
  Uri toUri(String scheme) => Uri(
    scheme: scheme,
    host: 'widget',
    pathSegments: [kind],
    queryParameters: instanceId == null ? null : {'instance': instanceId!},
  );

  /// Purpose: Parse a widget tap URI.
  /// Inputs: `uri`; optional `scheme` to require.
  /// Returns: The link, or null when `uri` is not a widget link.
  /// Side effects: None.
  /// Notes: Extra query parameters are ignored for forward compatibility.
  static WidgetDeepLink? tryParse(Uri uri, {String? scheme}) {
    if (scheme != null && uri.scheme != scheme) return null;
    if (uri.host != 'widget' || uri.pathSegments.length != 1) return null;
    final kind = uri.pathSegments.single;
    if (kind.isEmpty) return null;
    return WidgetDeepLink(
      kind: kind,
      instanceId: uri.queryParameters['instance'],
    );
  }
}
