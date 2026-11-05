const express = require('express');
const client = require('prom-client');

const app = express();
const port = process.env.PORT || 3003;
const serviceName = 'order-service';
const route = '/orders';
const initialData = [{"id": 1001, "userId": 1, "productId": 101, "quantity": 1, "status": "PLACED"}, {"id": 1002, "userId": 2, "productId": 102, "quantity": 2, "status": "PLACED"}];
app.use(express.json());

const register = new client.Registry();
client.collectDefaultMetrics({ register, prefix: serviceName.replace(/-/g, '_') + '_' });
const requestCounter = new client.Counter({
  name: serviceName.replace(/-/g, '_') + '_http_requests_total',
  help: 'Total HTTP requests received',
  labelNames: ['method', 'path', 'status'],
  registers: [register]
});
app.use((req, res, next) => {
  res.on('finish', () => requestCounter.inc({ method: req.method, path: req.path, status: String(res.statusCode) }));
  next();
});

app.get('/health', (_req, res) => res.status(200).json({ status: 'ok', service: serviceName }));
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
app.get('/', (_req, res) => res.json({ service: serviceName, data: initialData }));
app.get('/:id', (req, res) => {
  const item = initialData.find((entry) => String(entry.id) === req.params.id);
  if (!item) return res.status(404).json({ error: 'Not found' });
  return res.json(item);
});
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(port, '0.0.0.0', () => console.log(`${serviceName} listening on ${port}`));
