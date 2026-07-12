'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { greet, health, sum } = require('../src/index.js');

describe('integration: flujo de saludo + health', () => {
  it('compone un payload de respuesta de servicio', () => {
    const message = greet('Certificación');
    const payload = {
      message,
      health: health(),
      checksum: sum(payloadLength(message), 1),
    };

    assert.match(payload.message, /Certificación/);
    assert.equal(payload.health.status, 'ok');
    assert.ok(payload.checksum > 1);
  });
});

function payloadLength(value) {
  return Buffer.byteLength(value, 'utf8');
}
