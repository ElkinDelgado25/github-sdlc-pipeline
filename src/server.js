'use strict';

const http = require('node:http');
const { greet, health } = require('./index.js');

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || '127.0.0.1';

/**
 * Página mínima que sirve de objetivo para las pruebas E2E de interfaz.
 */
const HOME_PAGE = `<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <title>SDLC Pipeline Demo</title>
  </head>
  <body>
    <h1>SDLC Pipeline Demo</h1>
    <form id="greet-form">
      <label for="name">Nombre</label>
      <input id="name" name="name" value="mundo" />
      <button type="submit" id="submit">Saludar</button>
    </form>
    <p id="greeting" data-testid="greeting"></p>
    <script>
      document.getElementById('greet-form').addEventListener('submit', async (event) => {
        event.preventDefault();
        const name = document.getElementById('name').value;
        const response = await fetch('/greet?name=' + encodeURIComponent(name));
        const body = await response.json();
        document.getElementById('greeting').textContent = body.message || body.error;
      });
    </script>
  </body>
</html>`;

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
  });
  res.end(body);
}

function handleGreet(res, url) {
  const name = url.searchParams.get('name');
  try {
    sendJson(res, 200, { message: name === null ? greet() : greet(name) });
  } catch (error) {
    sendJson(res, 400, { error: error.message });
  }
}

function createServer() {
  return http.createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host || `${HOST}:${PORT}`}`);

    if (req.method !== 'GET') {
      sendJson(res, 405, { error: 'method not allowed' });
      return;
    }

    if (url.pathname === '/health') {
      sendJson(res, 200, health());
      return;
    }

    if (url.pathname === '/greet') {
      handleGreet(res, url);
      return;
    }

    if (url.pathname === '/') {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      res.end(HOME_PAGE);
      return;
    }

    sendJson(res, 404, { error: 'not found' });
  });
}

if (require.main === module) {
  createServer().listen(PORT, HOST, () => {
    console.log(`servidor escuchando en http://${HOST}:${PORT}`);
  });
}

module.exports = { createServer, PORT, HOST };
