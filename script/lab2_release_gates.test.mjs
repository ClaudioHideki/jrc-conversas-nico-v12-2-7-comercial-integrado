import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const branch = 'codex/lab2-integral-20261102';
const native = readFileSync(new URL('../.github/workflows/backoffice-flow.yml', import.meta.url), 'utf8');
const build = readFileSync(new URL('../.github/workflows/build-ghcr.yml', import.meta.url), 'utf8');
const smoke = readFileSync(new URL('./smoke_backoffice_candidate.sh', import.meta.url), 'utf8');

test('the integral candidate triggers native validation and cannot bypass its image gate', () => {
  assert.match(native.split('pull_request:')[0], new RegExp(branch));
  assert.match(build, /needs: \[validate, commercial-flow, broker-and-import-integration\]/);
  assert.match(build, /test "\$IMAGE_TAG" = "\$EXPECTED_TAG"/);
  assert.match(build, /EXPECTED_TAG: ura-hml-sha-\$\{\{ github.sha \}\}/);
});

test('HML publication is manual and namespaced to the authorized destination', () => {
  assert.match(native.split('pull_request:')[0], /^\s+- main\s*$/m);
  assert.match(build, /workflow_dispatch:/);
  assert.doesNotMatch(build, /^  push:/m);
  assert.match(build, /\[\[ "\$GITHUB_REF_NAME" == codex\/ura-nativa-hml-\* \]\]/);
  assert.match(build, /IMAGE_NAME: claudiohideki\/jrc-conversas-nico-v12-2-7-comercial-integrado/);
  assert.match(build, /Impedir sobrescrita de tags HML existentes/);
  assert.match(build, /Publicar somente a imagem testada/);
});

test('every schema-loaded validation database applies SQL guards without dumping source', () => {
  assert.doesNotMatch(native, /rails db:prepare/);
  assert.equal((native.match(/rails runner script\/prepare_lab2_candidate_database.rb/g) || []).length, 3);
  assert.match(smoke, /rails runner script\/prepare_lab2_candidate_database.rb/);
});

test('native validation includes migration media and NICO permission regressions', () => {
  assert.match(native, /spec\/services\/jrc_migrations/);
  assert.match(native, /spec\/requests\/jrc_migration\*_spec.rb/);
  assert.match(native, /spec\/services\/jrc_nico\/migration\*_spec.rb/);
  assert.match(native, /JRC_IMPORT_MINIO_ENDPOINT/);
});

test('the consolidated release rejects stale Flow ownership manifests before Rails validation', () => {
  const integrationJob = native.split('  broker-and-import-integration:')[1];
  const checkout = integrationJob.slice(integrationJob.indexOf('uses: actions/checkout@'), integrationJob.indexOf('- name: Dependencias nativas'));
  assert.match(checkout, /fetch-depth: 0/, 'the manifest verifier needs its exact historical Git base');
  const manifestGate = native.indexOf('node script/jrc_native_module_manifest.mjs');
  const railsGate = native.indexOf('name: Regressao de contratos e integridade');
  assert.ok(manifestGate >= 0, 'the release must verify the frozen module manifest');
  assert.ok(manifestGate < railsGate, 'verify source hashes before exercising the candidate');
  assert.doesNotMatch(native, /jrc_native_module_manifest\.mjs\s+--write/);
});

test('the MinIO fixture is retrievable from its official release and verified before execution', () => {
  assert.equal(native.includes('minio/minio@sha256:'), false);
  assert.equal(native.includes('https://github.com/minio/minio/releases/download/RELEASE.2025-09-07T16-13-09Z/'), true);
  assert.equal(native.includes('7c5bd8512c6e966455b1d198209358b2d191c77a83ab377c4073281065fb855f'), true);
  assert.equal(native.includes('sha256sum --check'), true);
});

test('HML requires frozen ownership evidence and CSAT/timezone regressions before building',()=>{
  const integration=build.split('  broker-and-import-integration:')[1];
  assert.match(integration,/fetch-depth: 0/);
  assert.match(integration,/node script\/jrc_native_module_manifest.mjs/);
  assert.doesNotMatch(integration,/jrc_native_module_manifest.mjs\s+--write/);
  assert.match(integration,/csat_survey_service_concurrency_spec.rb/);
  assert.match(integration,/application_time_zone_spec.rb/);
});
