# Releasing to pub.dev

Packages publish via **GitHub Actions + pub.dev automated publishing (OIDC)** —
no tokens or secrets. The workflow is [`.github/workflows/publish.yml`](.github/workflows/publish.yml).
A push of a per-package tag `<package>-v<version>` publishes that one package.

```bash
git tag flutter_universal_sync_core-v0.3.0
git push origin flutter_universal_sync_core-v0.3.0
```

## One-time setup (per package)

pub.dev automated publishing can only be configured on a package that already
exists, so each package's **first** version is published by hand:

1. `cd packages/<package> && dart pub login && dart pub publish`
   (claims the name; you become the uploader).
2. On pub.dev → the package → **Admin → Automated publishing** → enable
   **Publishing from GitHub Actions**:
   - Repository: `himanshu64/flutter_universal_sync`
   - Tag pattern: `<package>-v{{version}}`
     (e.g. `flutter_universal_sync_core-v{{version}}`)

After that, every subsequent version publishes automatically from a tag push.

## Publish order

A dependent is only usable once its dependencies are live on pub.dev, so publish
in dependency order (each tier after the previous is on pub.dev):

1. **`flutter_universal_sync_core`** — everything depends on it.
2. Independent capability packages (no internal deps): **`_attachments`**, **`_auth`**.
3. Depends on core: **`_engine`**, **`_crdt`**, **`_realtime`**, **`_sqflite`**,
   **`_drift`**, **`_hive`**, **`_objectbox`**, **`_rest`**, **`_supabase`**,
   **`_appwrite`**, **`_graphql`**, **`_firebase`**.
4. Depends on engine: **`_background`**.

## Cutting a release

1. Bump `version:` in the package's `pubspec.yaml` and add a `CHANGELOG.md` entry.
2. If you changed a shared contract, bump dependents' constraint to match
   (e.g. `flutter_universal_sync_core: ^0.3.0`).
3. Merge to `main` (CI green).
4. Tag and push: `git tag <package>-v<version> && git push origin <package>-v<version>`.
5. The **Publish to pub.dev** workflow validates that the tag version matches the
   pubspec, runs `dart pub publish --dry-run`, then publishes.

## Notes

- `dependency_overrides` (local paths) are used for in-repo development and are
  **ignored by consumers** — pub.dev emits a harmless hint about them.
- `flutter_universal_sync_core` declares `test` as a runtime dependency (the
  shared adapter **contract suites** ship in `lib/src/testing/`). This is
  intentional; it slightly lowers the package's pana score.
- `flutter_universal_sync_objectbox` is a documented reference skeleton (codegen
  + native lib required); hold it back from release until completed.
