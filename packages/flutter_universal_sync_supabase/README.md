# flutter_universal_sync_supabase

A [Supabase](https://supabase.com) (PostgREST)
[`RemoteSyncAdapter`](../flutter_universal_sync_core/) for the
[`flutter_universal_sync`](https://github.com/REPLACE_ME/flutter_universal_sync)
family.

```yaml
dependencies:
  flutter_universal_sync_core: ^0.2.0
  flutter_universal_sync_supabase: ^0.1.0
  http: ^1.2.2
```

```dart
final remote = SupabaseSyncAdapter(
  url: Uri.parse('https://YOUR.supabase.co'),
  anonKey: 'YOUR_ANON_KEY',
  token: () => supabaseAuth.currentSession?.accessToken,  // rotating user JWT
);
final engine = SyncEngine(remote: remote, /* ... */);
```

| Queue op | Request |
|---|---|
| insert | `POST /rest/v1/<table>` with `Prefer: resolution=merge-duplicates` |
| update / delete | `PATCH /rest/v1/<table>?id=eq.<id>` (delete sends the tombstone payload) |
| pull | `GET /rest/v1/<table>?or=(updated_at.gt.<iso>,deleted_at.gt.<iso>)&order=updated_at` |

Your tables need `updated_at` / `deleted_at` columns and RLS policies that permit
the operations. Verified with `MockClient`; point it at a real project to go live.

## License

MIT.
