const express = require('express');
const { initDb } = require('./db');
const syncRoutes = require('./routes/sync');

const app = express();
app.use(express.json({ limit: '10mb' }));

// Tiny request logger so you can watch sync traffic in dev.
app.use((req, _res, next) => {
  if (process.env.QUIET !== '1') {
    console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
  }
  next();
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', time: Date.now() });
});

app.use('/sync', syncRoutes);

// Final error handler so client gets JSON instead of HTML.
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: err.message ?? 'internal_error' });
});

const PORT = Number(process.env.PORT) || 3000;

if (require.main === module) {
  initDb();
  app.listen(PORT, () => {
    console.log(`flutter_universal_sync test backend listening on http://localhost:${PORT}`);
  });
}

module.exports = { app, initDb };
