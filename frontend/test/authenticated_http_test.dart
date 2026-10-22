import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/authenticated_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AuthenticatedHttpClient', () {
    test(
      'does not read or attach tokens on login and register requests',
      () async {
        var accessTokenReads = 0;
        var refreshTokenReads = 0;
        final client = MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response(
            '{}',
            request.url.path.endsWith('/login/') ? 200 : 201,
          );
        });
        final api = AuthenticatedHttpClient(
          client: client,
          readAccessToken: () async {
            accessTokenReads++;
            return 'stale-access-token';
          },
          readRefreshToken: () async {
            refreshTokenReads++;
            return 'stale-refresh-token';
          },
          saveAccessToken: (_) async {},
          saveRefreshToken: (_) async {},
          clearTokens: () async {},
        );

        for (final endpoint in ['login', 'register']) {
          final response = await api.request(
            'POST',
            Uri.parse('https://example.test/api/auth/$endpoint/'),
            headers: const {'Authorization': 'Bearer stale-access-token'},
            body: '{}',
          );
          expect(response.statusCode, endpoint == 'login' ? 200 : 201);
        }

        expect(accessTokenReads, 0);
        expect(refreshTokenReads, 0);
      },
    );

    test(
      'refreshes once and retries the original request with new token',
      () async {
        var accessToken = 'expired-access';
        var refreshToken = 'refresh-1';
        var resourceAttempts = 0;
        var refreshAttempts = 0;

        final client = MockClient((request) async {
          if (request.url.path.endsWith('/auth/token/refresh/')) {
            refreshAttempts++;
            expect(jsonDecode(request.body), {'refresh': 'refresh-1'});
            return http.Response(
              jsonEncode({'access': 'fresh-access', 'refresh': 'refresh-2'}),
              200,
            );
          }

          resourceAttempts++;
          if (request.headers['Authorization'] == 'Bearer expired-access') {
            return http.Response('', 401);
          }
          expect(request.headers['Authorization'], 'Bearer fresh-access');
          return http.Response('ok', 200);
        });

        final api = AuthenticatedHttpClient(
          client: client,
          readAccessToken: () async => accessToken,
          readRefreshToken: () async => refreshToken,
          saveAccessToken: (value) async {
            accessToken = value;
          },
          saveRefreshToken: (value) async {
            refreshToken = value;
          },
          clearTokens: () async {
            accessToken = '';
            refreshToken = '';
          },
        );

        final response = await api.request(
          'GET',
          Uri.parse('https://example.test/api/resource/'),
          headers: const {'Accept': 'application/json'},
        );

        expect(response.statusCode, 200);
        expect(resourceAttempts, 2);
        expect(refreshAttempts, 1);
        expect(accessToken, 'fresh-access');
        expect(refreshToken, 'refresh-2');
      },
    );

    test('does not retry more than once after a 401', () async {
      var accessToken = 'expired-access';
      var resourceAttempts = 0;
      var refreshAttempts = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/token/refresh/')) {
          refreshAttempts++;
          return http.Response(jsonEncode({'access': 'fresh-access'}), 200);
        }
        resourceAttempts++;
        return http.Response('', 401);
      });
      final api = AuthenticatedHttpClient(
        client: client,
        readAccessToken: () async => accessToken,
        readRefreshToken: () async => 'refresh-token',
        saveAccessToken: (value) async {
          accessToken = value;
        },
        saveRefreshToken: (_) async {},
        clearTokens: () async {},
      );

      final response = await api.request(
        'POST',
        Uri.parse('https://example.test/api/batch/'),
        body: '{"records":[]}',
      );

      expect(response.statusCode, 401);
      expect(resourceAttempts, 2);
      expect(refreshAttempts, 1);
    });
  });
}
