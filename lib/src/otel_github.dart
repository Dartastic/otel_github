// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_github_suppression.dart';

const _tracerName = 'dartastic_otel_libs_github';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedGithubRest` callback.
class GithubRestResult<T> {
  const GithubRestResult({
    required this.value,
    this.rateLimitRemaining,
    this.rateLimitReset,
  });
  final T value;
  final int? rateLimitRemaining;
  final int? rateLimitReset;
}

/// Wraps a GitHub REST call (Octokit endpoint, e.g.
/// `repos.get` / `pulls.list`) in a CLIENT span.
Future<T> tracedGithubRest<T>({
  required String endpoint,
  required Future<GithubRestResult<T>> Function() invoke,
  String? owner,
  String? repo,
}) async {
  if (githubInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'github.endpoint': endpoint,
    'github.api': 'rest',
  };
  if (owner != null) m['github.owner'] = owner;
  if (repo != null) m['github.repo'] = repo;

  final span = _tracer().startSpan(
    'github $endpoint',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    final extras = <Attribute<Object>>[];
    if (r.rateLimitRemaining != null) {
      extras.add(OTel.attributeInt(
        'github.rate_limit.remaining',
        r.rateLimitRemaining!,
      ));
    }
    if (r.rateLimitReset != null) {
      extras.add(OTel.attributeInt(
        'github.rate_limit.reset',
        r.rateLimitReset!,
      ));
    }
    if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Wraps a GitHub GraphQL query/mutation in a CLIENT span.
Future<T> tracedGithubGraphql<T>({
  required String operationName,
  required Future<T> Function() invoke,
  String? operationType,
}) async {
  if (githubInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'graphql.operation.name': operationName,
    'graphql.operation.type': operationType ?? 'query',
    'github.api': 'graphql',
  };
  final span = _tracer().startSpan(
    'github graphql $operationName',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
