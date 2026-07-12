'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { greet, sum, health } = require('../src/index.js');

describe('unit: greet', () => {
  it('saluda con el nombre dado', () => {
    assert.equal(greet('QA'), 'Hola, QA!');
  });

  it('rechaza nombres vacíos', () => {
    assert.throws(() => greet(''), TypeError);
  });
});

describe('unit: sum', () => {
  it('suma dos números', () => {
    assert.equal(sum(2, 3), 5);
  });

  it('rechaza no-números', () => {
    assert.throws(() => sum('2', 3), TypeError);
  });
});

describe('unit: health', () => {
  it('devuelve status ok', () => {
    const result = health();
    assert.equal(result.status, 'ok');
    assert.equal(result.service, 'github-sdlc-pipeline');
  });
});
