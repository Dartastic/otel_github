// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_github/otel_github.dart';

/// Traces GitHub calls with OpenTelemetry.
///
/// `otel_github` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each GitHub call in
/// [tracedGithubRest]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'github-example');

  // Wraps a GitHub REST call (Octokit endpoint, e.g.
  final githubRestId = await tracedGithubRest<String>(
    endpoint: 'example',
    owner: 'example',
    repo: 'example',
    invoke: () async {
      // Make the GitHub call here, then report what it returned.
      const id = 'github_8f3a2c';
      return const GithubRestResult(
          value: id, rateLimitRemaining: 25, rateLimitReset: 25);
    },
  );
  OTelLog.info('tracedGithubRest repos.get returned $githubRestId');

  // Wraps a GitHub GraphQL query/mutation in a CLIENT span.
  final githubGraphqlId = await tracedGithubGraphql<String>(
    operationName: 'example',
    operationType: 'standard',
    invoke: () async {
      // Make the GitHub call here, then report what it returned.
      return 'github_8f3a2c';
    },
  );
  OTelLog.info('tracedGithubGraphql returned $githubGraphqlId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutGithubInstrumentationAsync.
  await runWithoutGithubInstrumentationAsync(
    () => tracedGithubRest<String>(
      endpoint: 'example',
      owner: 'example',
      repo: 'example',
      invoke: () async {
        const id = 'github_8f3a2c';
        return const GithubRestResult(
            value: id, rateLimitRemaining: 25, rateLimitReset: 25);
      },
    ),
  );

  await OTel.shutdown();
}
