'use strict';

const { test, expect } = require('@playwright/test');

test.describe('Página principal', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('muestra el título de la demo', async ({ page }) => {
    await expect(page).toHaveTitle('SDLC Pipeline Demo');
    await expect(page.getByRole('heading', { level: 1 })).toHaveText('SDLC Pipeline Demo');
  });

  test('saluda con el nombre escrito en el formulario', async ({ page }) => {
    await page.getByLabel('Nombre').fill('Elkin');
    await page.getByRole('button', { name: 'Saludar' }).click();

    await expect(page.getByTestId('greeting')).toHaveText('Hola, Elkin!');
  });

  test('muestra el error cuando el nombre queda vacío', async ({ page }) => {
    await page.getByLabel('Nombre').fill('   ');
    await page.getByRole('button', { name: 'Saludar' }).click();

    await expect(page.getByTestId('greeting')).toContainText('non-empty string');
  });
});
