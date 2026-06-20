import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Dev-only embedded HTTP server that serves a read-only **Database
/// Inspector** web UI for the demo's local database.
///
/// Features: per-table tabs with live auto-refresh, click-to-sort columns,
/// a substring filter, and a read-only SQL query runner (SELECT / PRAGMA
/// only).
///
/// NOT for production: binds on all interfaces, no auth, exposes raw table
/// contents. It exists so you can watch the queue drain and the pull
/// cursors advance in a browser while poking the app.
class DatabaseInspectorServer {
  DatabaseInspectorServer({
    required this.tables,
    required this.query,
    required this.runSql,
    this.preferredPort = 8090,
  });

  /// Table names to expose, in display order.
  final List<String> tables;

  /// Returns every row of [table] verbatim (dev-only raw dump).
  final Future<List<Map<String, Object?>>> Function(String table) query;

  /// Runs an arbitrary read-only SQL statement and returns its rows.
  final Future<List<Map<String, Object?>>> Function(String sql) runSql;

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
      res.headers.set('Access-Control-Allow-Origin', '*');
      try {
        switch (req.uri.path) {
          case '/data':
            await _handleData(res);
          case '/query':
            await _handleQuery(req.uri.queryParameters['sql'] ?? '', res);
          default:
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

  Future<void> _handleData(HttpResponse res) async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in tables) {
      out[t] = await query(t);
    }
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(out));
  }

  Future<void> _handleQuery(String sql, HttpResponse res) async {
    res.headers.contentType = ContentType.json;
    final guard = _readOnlyGuard(sql);
    if (guard != null) {
      res.write(jsonEncode({'error': guard}));
      return;
    }
    try {
      final rows = await runSql(sql.trim());
      res.write(jsonEncode({'rows': rows}));
    } catch (e) {
      res.write(jsonEncode({'error': '$e'}));
    }
  }

  /// Returns an error string if [sql] is not a safe read-only statement,
  /// or `null` if it is allowed.
  static String? _readOnlyGuard(String sql) {
    final trimmed = sql.trim();
    if (trimmed.isEmpty) return 'enter a SELECT or PRAGMA statement';
    if (trimmed.contains(';')) return 'only a single statement is allowed';
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('select') && !lower.startsWith('pragma')) {
      return 'read-only: only SELECT / PRAGMA queries are allowed';
    }
    return null;
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
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Database Inspector</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, system-ui, sans-serif; margin: 0;
         background: #fafafa; color: #222; }
  header { padding: 14px 20px; background: #1f2330; color: #fff; }
  header h1 { font-size: 16px; margin: 0; font-weight: 600; }
  header .meta { color: #9aa0b4; font-size: 12px; font-weight: 400; }
  .tabs { display: flex; flex-wrap: wrap; gap: 4px; padding: 8px 16px 0;
          background: #eceef3; border-bottom: 1px solid #d8dbe3; }
  .tab { padding: 6px 12px; cursor: pointer; font-size: 13px; border: none;
         background: transparent; border-radius: 6px 6px 0 0; color: #444; }
  .tab.active { background: #fafafa; font-weight: 600; color: #1f2330; }
  .tab .count { color: #999; font-weight: 400; }
  .body { padding: 16px 20px 60px; }
  .toolbar { margin-bottom: 10px; }
  input[type=text], textarea { font: inherit; padding: 6px 8px;
         border: 1px solid #ccc; border-radius: 6px; width: 100%; }
  textarea { min-height: 70px; font-family: ui-monospace, monospace;
             font-size: 12px; }
  button.run { margin-top: 8px; padding: 6px 14px; font-size: 13px;
        border: none; border-radius: 6px; background: #3056d3; color: #fff;
        cursor: pointer; }
  table { border-collapse: collapse; width: 100%; font-size: 12px;
          background: #fff; margin-top: 8px; }
  th, td { border: 1px solid #e2e2e2; padding: 4px 8px; text-align: left;
           vertical-align: top; white-space: pre-wrap; word-break: break-word; }
  th { background: #f0f0f0; position: sticky; top: 0; cursor: pointer;
       user-select: none; }
  th .arrow { color: #3056d3; }
  .empty { color: #aaa; font-style: italic; margin-top: 8px; }
  .error { color: #c0392b; margin-top: 8px; font-size: 13px; }
</style>
</head>
<body>
<header>
  <h1>Database Inspector <span class="meta" id="ts"></span></h1>
</header>
<div class="tabs" id="tabs"></div>
<div class="body" id="body"></div>
<script>
var DATA = {};
var TABLES = [];
var active = null;            // table name, or '__sql__'
var sortCol = null, sortDir = 1;
var filter = '';
var sqlText = 'SELECT * FROM sync_queue ORDER BY created_at DESC';
var sqlResult = null, sqlError = null;

function el(tag, props) {
  var e = document.createElement(tag);
  if (props) for (var k in props) e[k] = props[k];
  return e;
}

async function loadData() {
  try {
    var res = await fetch('/data');
    DATA = await res.json();
    TABLES = Object.keys(DATA);
    if (active === null) active = TABLES.length ? TABLES[0] : '__sql__';
    document.getElementById('ts').textContent =
      'updated ' + new Date().toLocaleTimeString();
    renderTabs();
    if (active !== '__sql__') renderBody();
  } catch (e) {
    document.getElementById('ts').textContent = 'error: ' + e;
  }
}

function renderTabs() {
  var bar = document.getElementById('tabs');
  bar.innerHTML = '';
  TABLES.forEach(function (name) {
    var b = el('button', { className: 'tab' + (active === name ? ' active' : '') });
    b.innerHTML = name + ' <span class="count">(' + DATA[name].length + ')</span>';
    b.onclick = function () { active = name; sortCol = null; filter = ''; renderTabs(); renderBody(); };
    bar.appendChild(b);
  });
  var sqlTab = el('button', { className: 'tab' + (active === '__sql__' ? ' active' : ''), textContent: 'SQL' });
  sqlTab.onclick = function () { active = '__sql__'; renderTabs(); renderBody(); };
  bar.appendChild(sqlTab);
}

function rowsFor(name) {
  var rows = (DATA[name] || []).slice();
  if (filter) {
    var f = filter.toLowerCase();
    rows = rows.filter(function (r) {
      return Object.keys(r).some(function (k) {
        return String(r[k]).toLowerCase().indexOf(f) >= 0;
      });
    });
  }
  if (sortCol !== null) {
    rows.sort(function (a, b) {
      var x = a[sortCol], y = b[sortCol];
      if (x === y) return 0;
      if (x === null) return 1; if (y === null) return -1;
      return (x > y ? 1 : -1) * sortDir;
    });
  }
  return rows;
}

function tableEl(rows, sortable) {
  if (!rows.length) { return el('div', { className: 'empty', textContent: '- empty -' }); }
  var cols = Object.keys(rows[0]);
  var t = el('table');
  var head = el('tr');
  cols.forEach(function (c) {
    var th = el('th');
    var arrow = (sortable && sortCol === c) ? (sortDir > 0 ? ' UP' : ' DOWN') : '';
    th.innerHTML = c + '<span class="arrow">' + arrow + '</span>';
    if (sortable) th.onclick = function () {
      if (sortCol === c) sortDir = -sortDir; else { sortCol = c; sortDir = 1; }
      renderBody();
    };
    head.appendChild(th);
  });
  t.appendChild(head);
  rows.forEach(function (r) {
    var tr = el('tr');
    cols.forEach(function (c) {
      var v = r[c];
      tr.appendChild(el('td', { textContent: v === null ? 'NULL' : String(v) }));
    });
    t.appendChild(tr);
  });
  return t;
}

function renderBody() {
  var body = document.getElementById('body');
  body.innerHTML = '';
  if (active === '__sql__') { renderSql(body); return; }
  var bar = el('div', { className: 'toolbar' });
  var search = el('input', { type: 'text', placeholder: 'filter rows...', value: filter });
  search.oninput = function () { filter = search.value; renderBody(); };
  bar.appendChild(search);
  body.appendChild(bar);
  body.appendChild(tableEl(rowsFor(active), true));
}

function renderSql(body) {
  var ta = el('textarea', { value: sqlText });
  ta.oninput = function () { sqlText = ta.value; };
  body.appendChild(ta);
  var btn = el('button', { className: 'run', textContent: 'Run (read-only)' });
  btn.onclick = runQuery;
  body.appendChild(btn);
  if (sqlError) body.appendChild(el('div', { className: 'error', textContent: sqlError }));
  if (sqlResult) body.appendChild(tableEl(sqlResult, false));
}

async function runQuery() {
  sqlError = null; sqlResult = null;
  try {
    var res = await fetch('/query?sql=' + encodeURIComponent(sqlText));
    var out = await res.json();
    if (out.error) sqlError = out.error; else sqlResult = out.rows;
  } catch (e) { sqlError = '' + e; }
  renderBody();
}

loadData();
setInterval(loadData, 2000);
</script>
</body>
</html>
''';
