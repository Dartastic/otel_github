// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_github/otel_github.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_github-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('REST records CLIENT span + rate limits', () async {
    await tracedGithubRest<String>(
      endpoint: 'repos.get',
      owner: 'dart-lang',
      repo: 'sdk',
      invoke: () async => const GithubRestResult(
        value: 'repo',
        rateLimitRemaining: 4998,
        rateLimitReset: 1747260000,
      ),
    );
    final a = attrsOf(spans.findSpanByName('github repos.get')!);
    expect(a['github.endpoint'], 'repos.get');
    expect(a['github.api'], 'rest');
    expect(a['github.owner'], 'dart-lang');
    expect(a['github.repo'], 'sdk');
    expect(a['github.rate_limit.remaining'], 4998);
    expect(a['github.rate_limit.reset'], 1747260000);
  });

  test('GraphQL records CLIENT span', () async {
    await tracedGithubGraphql<String>(
      operationName: 'GetRepo',
      invoke: () async => 'ok',
    );
    final a = attrsOf(spans.findSpanByName('github graphql GetRepo')!);
    expect(a['graphql.operation.name'], 'GetRepo');
    expect(a['github.api'], 'graphql');
  });

  test('suppression skips spans', () async {
    await runWithoutGithubInstrumentationAsync(() async {
      await tracedGithubRest<String>(
        endpoint: 'repos.get',
        invoke: () async => const GithubRestResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('github '), isEmpty);
  });
}
