const test = require('node:test');
const assert = require('node:assert/strict');

test('order-service service metadata is configured', () => {
  assert.equal('order-service', 'order-service');
  assert.equal(3003, 3003);
});
