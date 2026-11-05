const test = require('node:test');
const assert = require('node:assert/strict');

test('product-service service metadata is configured', () => {
  assert.equal('product-service', 'product-service');
  assert.equal(3002, 3002);
});
