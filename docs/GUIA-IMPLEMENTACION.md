# Guía de implementación en GitHub (paso a paso)

Este repositorio implementa el flujo SDLC:

`feature/*` → `develop` → `staging` → `main` → Producción

con environments, branch protection, checks de seguridad y deploys automáticos.

## Arquitectura de ramas

| Rama | Ambiente | Approvals | Checks clave |
|------|----------|-----------|--------------|
| `develop` | Development | 1 | Build & Lint, Pruebas unitarias, CodeQL (SAST rápido) |
| `staging` | Certification | 2 + Code Owners | Pruebas de integración, Pruebas E2E (Playwright), Escaneo de dependencias (SCA) |
| `main` | Production | 2 + Code Owners | Suite completa, Pruebas E2E (Playwright), SAST completo, SCA bloqueante, secretos, imagen Docker |

## 1. Crear las ramas base

Ya están creadas en este repo. Si partes de cero:

```bash
git checkout -b develop
git push -u origin develop

git checkout -b staging
git push -u origin staging
# main ya existe por defecto
```

## 2. Environments

`Settings → Environments → New environment`

Crear: `development`, `certification`, `production`.

| Environment | Required reviewers | Wait timer | Deployment branches |
|-------------|-------------------|------------|---------------------|
| development | — | — | `develop` |
| certification | QA Lead | — | `staging` |
| production | Tech Lead + Seguridad (mín. 2) | 10 min | solo `main` |

Secretos por environment: `DEV_DEPLOY_TOKEN`, `CERT_DEPLOY_TOKEN`, `PROD_DEPLOY_TOKEN`.

Automatizable con:

```bash
# Git Bash / WSL
QA_LEAD=tu-qa TECH_LEAD=tu-tech SECURITY_LEAD=tu-sec ./scripts/setup-github.sh
```

```powershell
# Windows PowerShell
$env:QA_LEAD="tu-qa"; $env:TECH_LEAD="tu-tech"; $env:SECURITY_LEAD="tu-sec"
.\scripts\setup-github.ps1
```

## 3. Branch Protection Rules

`Settings → Branches → Add rule` (o vía el script de setup).

### `develop`
- Require PR → 1 aprobación
- Status checks: `Build & Lint`, `Pruebas unitarias`, `CodeQL (SAST rápido)`
- Require branches to be up to date

### `staging`
- Require PR → 2 aprobaciones
- Require review from Code Owners
- Status checks: `Pruebas de integración`, `Pruebas E2E (Playwright)`,
  `Escaneo de dependencias (SCA)`

### `main`
- Require PR → 2 aprobaciones + Code Owners
- Status checks: `Suite completa de pruebas`, `Pruebas E2E (Playwright)`,
  `SAST completo (CodeQL)`, `Escaneo de dependencias (bloqueante)`,
  `Escaneo de secretos`, `Escaneo de imagen Docker`
- Require signed commits
- Require linear history
- Do not allow bypassing (incluso admins)
- Restrict who can push → bot de CI + administradores

## 4. Seguridad nativa

`Settings → Code security`
- Dependabot alerts + security updates
- Secret scanning + Push protection
- Code scanning (CodeQL en workflows)

## 5. Rulesets (recomendado)

`Settings → Rules → Rulesets` — el script crea `main-production-gates`.

## 6. Flujo diario del equipo

1. `git checkout develop && git pull`
2. `git checkout -b feature/123-nueva-funcionalidad`
3. Commits Conventional (`feat:`, `fix:`, `docs:`...)
4. `git push -u origin feature/123-nueva-funcionalidad`
5. PR → `develop` → checks + 1 aprobación → merge (squash)
6. Congelar versión: PR `develop` → `staging`
7. QA valida en Certification (deploy automático)
8. PR `staging` → `main`
9. Gate de seguridad + aprobaciones → merge
10. Workflow crea tag, release y despliega a Production
11. `main` se sincroniza automáticamente a `develop`

## Workflows incluidos

| Archivo | Propósito |
|---------|-----------|
| `ci-develop.yml` | Gates de develop |
| `ci-staging.yml` | Gates de staging |
| `ci-main.yml` | Gates de producción |
| `deploy-development.yml` | Deploy a `development` |
| `deploy-certification.yml` | Deploy a `certification` (requiere aprobación QA) |
| `deploy-production.yml` | Tag + Release + Deploy + sync a develop |

## App demo

Node.js mínimo con lint, tests unitarios e integración, y Dockerfile para el escaneo Trivy.
