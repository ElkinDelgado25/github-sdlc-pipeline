# github-sdlc-pipeline

Plantilla lista para producción del flujo SDLC en GitHub:

**feature → develop (Dev) → staging (Cert) → main (Prod)**

Incluye workflows CI/CD, environments con approval gates, branch protection, Dependabot, CodeQL, escaneo de secretos e imagen Docker.

## Arranque rápido

```bash
npm ci
npm run lint
npm run test:all
```

## Qué incluye

- Ramas `main`, `develop`, `staging`
- Environments: `development`, `certification`, `production`
- Checks con los nombres exactos de la guía (para branch protection)
- Deploys por environment + release/tag en `main`
- Sync automático `main` → `develop` tras producción
- Script `scripts/setup-github.sh` / `.ps1` para aplicar la config vía API

## Documentación

Ver [docs/GUIA-IMPLEMENTACION.md](docs/GUIA-IMPLEMENTACION.md) para el paso a paso completo.

## Configuración post-clone

1. Ejecutar el script de setup (environments + protection + seguridad)
2. Cargar secretos `DEV_DEPLOY_TOKEN`, `CERT_DEPLOY_TOKEN`, `PROD_DEPLOY_TOKEN` en cada environment
3. Actualizar `.github/CODEOWNERS` y los reviewers (QA / Tech / Seguridad)
4. Restringir push a `main` al bot de CI + admins en la UI de GitHub
