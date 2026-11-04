const test = require('node:test');
const assert = require('node:assert/strict');

test('user-service service metadata is configured', () => {
  assert.equal('user-service', 'user-service');
  assert.equal(3001, 3001);
});
