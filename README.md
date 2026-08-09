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

## Pruebas E2E con Playwright

```bash
npx playwright install chromium   # solo la primera vez
npm run test:e2e                  # ejecuta tests/e2e en chromium
npm run test:e2e:ui               # modo interactivo para depurar
npm run test:e2e:report           # abre el último reporte HTML
```

`playwright.config.js` levanta `node src/server.js` automáticamente antes de
correr los tests y lo apaga al terminar. Para apuntar a un entorno ya desplegado
en vez del servidor local, define `E2E_BASE_URL`:

```bash
E2E_BASE_URL=https://certification.example.com npm run test:e2e
```

Los specs viven en `tests/e2e/`: `api.spec.js` cubre los endpoints JSON y
`home.spec.js` la interfaz. El job `Pruebas E2E (Playwright)` corre en los CI de
`staging` y `main`, y sube el reporte HTML como artefacto.

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

## Workflows opcionales, desactivados por defecto

Los siguientes jobs aparecen como **skipped** hasta activar explícitamente su
variable de repositorio en `Settings → Secrets and variables → Actions → Variables`:

| Workflow | Variable de activación | Uso |
|---|---|---|
| `Alerta de PR a main` | `ENABLE_PR_MAIN_EMAIL_ALERT=true` | Envía una alerta SMTP al crear o actualizar un PR hacia `main`. |
| `CD opcional a AWS ECS` | `ENABLE_AWS_ECS_CD=true` | Publica la imagen en ECR y actualiza un servicio ECS. |
| `CD opcional a Google Cloud Run` | `ENABLE_CLOUD_RUN_CD=true` | Publica la imagen en Artifact Registry y despliega Cloud Run. |

Para el correo, configura los secretos `SMTP_SERVER`, `SMTP_PORT`,
`SMTP_USERNAME`, `SMTP_PASSWORD`, `MAIL_FROM` y `MAIL_TO`. El workflow no envía
secretos a PRs procedentes de forks.

Para AWS, configura las variables `AWS_REGION`, `AWS_ROLE_TO_ASSUME`,
`AWS_ECR_REPOSITORY`, `AWS_ECS_TASK_DEFINITION_FILE`,
`AWS_ECS_CONTAINER_NAME`, `AWS_ECS_CLUSTER` y `AWS_ECS_SERVICE`. El acceso usa
OIDC, por lo que no se guardan claves de AWS en GitHub.

Para Cloud Run, configura `GCP_PROJECT_ID`, `GCP_REGION`,
`GCP_ARTIFACT_REPOSITORY`, `GCP_WORKLOAD_IDENTITY_PROVIDER`,
`GCP_SERVICE_ACCOUNT` y `CLOUD_RUN_SERVICE`. El acceso usa Workload Identity
Federation, sin una clave JSON de cuenta de servicio. Activa solo uno de los dos
workflows CD de nube para evitar un doble despliegue.
