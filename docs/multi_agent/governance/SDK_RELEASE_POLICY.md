# Nebula SDK Release Policy

`S1-F03-001` freezes one release path for the SDK. It does not change SDK public API or product behavior.

## Channels

| Channel | Dependency form | Version rule | Publication authority |
|---|---|---|---|
| Development | local `path` | development version allowed | developer machine only; never a release artifact |
| Beta / RC | immutable Forgejo Git tag | prerelease SemVer, `rc*`; tag is exactly `v<pubspec version>` | reviewed commit, then Coordinator tag publication |
| Production | package registry | stable SemVer; no prerelease suffix | reviewed release + explicit HTTPS registry |

The current `publish_to: none` is valid for development and Git-tag RC distribution. It intentionally blocks registry publication. Production cannot be declared until `publish_to` points at the approved registry in a separately authorized release change.

## Branch and tag rules

1. Release-governance implementation occurs only on `s1/f03-001-release`.
2. Shared `main`, `dev`, and `release/*` are not implementation delivery branches.
3. An RC tag points at the exact Coordinator-approved canonical commit. Tag format is `v<pubspec version>`; RC1 intends `v0.1.0-rc1` only after that version is separately authorized and canonical.
4. Tags are immutable release identities. Never retarget a rejected RC tag; publish a new prerelease version/tag.
5. The release gate requires clean tree, exact HEAD/approved-commit equality, tag→HEAD equality, API-surface match, and frozen Task authority (`Platform API mode=NONE`, `SDK public API mode=READ_ONLY`).

## Mechanical checklist

```bash
dart pub get --offline
dart run tool/task_source_guard.dart --self-check
dart run tool/platform_api_guard.dart --self-check
dart run tool/api_surface.dart
dart run tool/sdk_release_gate.dart \
  --channel beta \
  --approved-commit <40-char-commit> \
  --tag v<pubspec-version>
dart run tool/governance.dart
dart analyze
dart test
dart run tool/smoke.dart
```

The tag-triggered workflow repeats these gates. It never publishes to pub.dev and never mutates package source. Git consumers must pin the immutable tag or its resolved commit; floating branches are not release dependencies.
