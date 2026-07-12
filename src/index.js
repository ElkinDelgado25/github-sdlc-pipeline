'use strict';

/**
 * API mínima de demostración para el pipeline SDLC.
 */
function greet(name = 'mundo') {
  if (typeof name !== 'string' || name.trim() === '') {
    throw new TypeError('name must be a non-empty string');
  }
  return `Hola, ${name.trim()}!`;
}

function health() {
  return {
    status: 'ok',
    service: 'github-sdlc-pipeline',
    timestamp: new Date().toISOString(),
  };
}

function sum(a, b) {
  if (typeof a !== 'number' || typeof b !== 'number' || Number.isNaN(a) || Number.isNaN(b)) {
    throw new TypeError('a and b must be numbers');
  }
  return a + b;
}

if (require.main === module) {
  console.log(JSON.stringify({ greeting: greet('SDLC'), health: health() }, null, 2));
}

module.exports = { greet, health, sum };
