import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Dev-only embedded HTTP server that serves a read-only, auto-refreshing
/// view of the demo's local database.
///
/// NOT for production: it binds on all interfaces and exposes raw table
/// contents with no auth. It exists so you can watch the queue drain and
/// the pull cursors advance in a browser while poking the app.
class DbViewerServer {
  DbViewerServer({
    required this.tables,
    required this.query,
    this.preferredPort = 8090,
  });

  /// Table names to expose, in display order.
  final List<String> tables;

  /// Returns every row of [table] verbatim (dev-only raw dump).
  final Future<List<Map<String, Object?>>> Function(String table) query;

  /// Port to try first; falls back to an ephemeral port if it is taken.
  final int preferredPort;

  HttpServer? _server;

  /// Starts the server and returns the base URL to open in a browser.
  Future<Uri> start() async {
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server = server;
    unawaited(_serve(server));
    return Uri.parse('http://localhost:${server.port}');
  }

  Future<void> _serve(HttpServer server) async {
    await for (final req in server) {
      final res = req.response;
      try {
        if (req.uri.path == '/data') {
          final out = <String, List<Map<String, Object?>>>{};
          for (final t in tables) {
            out[t] = await query(t);
          }
          res.headers.contentType = ContentType.json;
          res.headers.set('Access-Control-Allow-Origin', '*');
          res.write(jsonEncode(out));
        } else {
          res.headers.contentType = ContentType.html;
          res.write(_indexHtml);
        }
      } catch (e) {
        res.statusCode = HttpStatus.internalServerError;
        res.write('error: $e');
      } finally {
        await res.close();
      }
    }
  }

  /// Stops the server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

const _indexHtml = '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>sync_demo DB viewer</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; margin: 24px;
         background: #fafafa; color: #222; }
  h1 { font-size: 18px; }
  h2 { font-size: 13px; margin-top: 28px; text-transform: uppercase;
       letter-spacing: .05em; color: #555; }
  table { border-collapse: collapse; width: 100%; font-size: 12px;
          background: #fff; margin-top: 6px; }
  th, td { border: 1px solid #e2e2e2; padding: 4px 8px; text-align: left;
           vertical-align: top; white-space: pre-wrap; word-break: break-word; }
  th { background: #f0f0f0; position: sticky; top: 0; }
  .meta { color: #999; font-size: 12px; font-weight: normal; }
  .empty { color: #aaa; font-style: italic; margin-top: 6px; }
</style>
</head>
<body>
<h1>sync_demo database <span class="meta" id="ts"></span></h1>
<div id="tables"></div>
<script>
async function load() {
  try {
    const res = await fetch('/data');
    const data = await res.json();
    const root = document.getElementById('tables');
    root.innerHTML = '';
    for (const name of Object.keys(data)) {
      const rows = data[name];
      const h = document.createElement('h2');
      h.textContent = name + ' (' + rows.length + ')';
      root.appendChild(h);
      if (!rows.length) {
        const e = document.createElement('div');
        e.className = 'empty';
        e.textContent = '- empty -';
        root.appendChild(e);
        continue;
      }
      const cols = Object.keys(rows[0]);
      const t = document.createElement('table');
      const head = document.createElement('tr');
      cols.forEach(function (c) {
        const th = document.createElement('th');
        th.textContent = c;
        head.appendChild(th);
      });
      t.appendChild(head);
      rows.forEach(function (r) {
        const tr = document.createElement('tr');
        cols.forEach(function (c) {
          const td = document.createElement('td');
          const v = r[c];
          td.textContent = v === null ? 'NULL' : String(v);
          tr.appendChild(td);
        });
        t.appendChild(tr);
      });
      root.appendChild(t);
    }
    document.getElementById('ts').textContent =
      '- updated ' + new Date().toLocaleTimeString();
  } catch (e) {
    document.getElementById('ts').textContent = '- error: ' + e;
  }
}
load();
setInterval(load, 2000);
</script>
</body>
</html>
''';
