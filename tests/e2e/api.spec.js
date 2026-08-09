'use strict';

const { test, expect } = require('@playwright/test');

test.describe('API del servicio', () => {
  test('/health responde ok', async ({ request }) => {
    const response = await request.get('/health');

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('ok');
    expect(body.service).toBe('github-sdlc-pipeline');
    expect(Date.parse(body.timestamp)).not.toBeNaN();
  });

  test('/greet saluda con el nombre recibido', async ({ request }) => {
    const response = await request.get('/greet?name=Certificacion');

    expect(response.status()).toBe(200);
    expect(await response.json()).toEqual({ message: 'Hola, Certificacion!' });
  });

  test('/greet rechaza un nombre vacío', async ({ request }) => {
    const response = await request.get('/greet?name=%20');

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toContain('non-empty string');
  });

  test('una ruta desconocida devuelve 404', async ({ request }) => {
    const response = await request.get('/no-existe');

    expect(response.status()).toBe(404);
  });
});
