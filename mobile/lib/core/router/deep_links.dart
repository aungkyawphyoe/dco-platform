import 'package:flutter/foundation.dart';

import '../../features/vehicle_sharing/domain/share_invite_link.dart';
import 'routes.dart';

/// Path used by the emailed "accept invitation" deep link.
const _acceptPath = '/share/accept';

/// Translates a platform deep link into a GoRouter location.
///
/// Flutter's built-in deep linking hands the whole URI (for example
/// `dco://vehicle/share/join?code=ABCD1234`) to the router. GoRouter matches on
/// the URI path, which would be `/share/join` here, so the URI is normalized
/// before the router's redirect runs.
///
/// Returns null for normal in-app locations, leaving regular navigation
/// untouched. A `dco://` link the app does not understand lands on the
/// garage instead of a routing error page.
String? deepLinkLocation(Uri uri) {
  if (uri.scheme.toLowerCase() != ShareInviteLink.scheme) return null;
  if (kDebugMode) debugPrint('Deep link received: $uri');

  final invite = ShareInviteLink.fromDeepLink(uri);
  if (invite != null) return invite.routeLocation;

  if (uri.host.toLowerCase() != ShareInviteLink.host) {
    return AppRoutes.dashboard;
  }

  switch (_normalizePath(uri.path)) {
    case ShareInviteLink.path:
      // Missing or malformed code: still open the join screen so it can be
      // typed by hand.
      return AppRoutes.vehicleShareJoin;
    case _acceptPath:
      final token = uri.queryParameters['token']?.trim();
      if (token == null || token.isEmpty) return AppRoutes.dashboard;
      return Uri(
        path: AppRoutes.vehicleShareAccept,
        queryParameters: {'token': token},
      ).toString();
  }

  return AppRoutes.dashboard;
}

String _normalizePath(String path) {
  if (path.isEmpty || path == '/') return path;
  return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
}
