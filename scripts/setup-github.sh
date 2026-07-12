#!/usr/bin/env bash
# Configura environments, branch protection, rulesets y seguridad nativa.
# Uso: ./scripts/setup-github.sh [owner/repo]
# Requiere: gh autenticado con scope repo (+ admin:org si aplica)

set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
OWNER="${REPO%%/*}"
NAME="${REPO#*/}"

echo "==> Repositorio: $REPO"

# ---------------------------------------------------------------------------
# 1. Environments
# ---------------------------------------------------------------------------
echo "==> Creando environments..."

# development — sin reviewers ni wait timer
gh api --method PUT "repos/$REPO/environments/development" \
  --input - <<'EOF'
{
  "wait_timer": 0,
  "prevent_self_review": false,
  "reviewers": [],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF
gh api --method POST "repos/$REPO/environments/development/deployment-branch-policies" \
  -f name=develop -F type=branch 2>/dev/null || true

# certification — Required reviewers (QA Lead). Actualiza el login abajo.
QA_LEAD="${QA_LEAD:-$OWNER}"
QA_USER_ID=$(gh api "users/$QA_LEAD" --jq .id)
gh api --method PUT "repos/$REPO/environments/certification" \
  --input - <<EOF
{
  "wait_timer": 0,
  "prevent_self_review": true,
  "reviewers": [{"type": "User", "id": $QA_USER_ID}],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF
gh api --method POST "repos/$REPO/environments/certification/deployment-branch-policies" \
  -f name=staging -F type=branch 2>/dev/null || true

# production — Tech Lead + Seguridad (mín. 2), wait 10 min, solo main
TECH_LEAD="${TECH_LEAD:-$OWNER}"
SECURITY_LEAD="${SECURITY_LEAD:-$OWNER}"
TECH_ID=$(gh api "users/$TECH_LEAD" --jq .id)
SEC_ID=$(gh api "users/$SECURITY_LEAD" --jq .id)

# Si Tech Lead y Seguridad son la misma persona (setup inicial),
# GitHub exige reviewers distintos para 2 aprobaciones: se deja 1 y se documenta.
if [ "$TECH_ID" = "$SEC_ID" ]; then
  echo "::warning::TECH_LEAD y SECURITY_LEAD son el mismo usuario. Configura 2 reviewers distintos después."
  REVIEWERS="[{\"type\": \"User\", \"id\": $TECH_ID}]"
else
  REVIEWERS="[{\"type\": \"User\", \"id\": $TECH_ID}, {\"type\": \"User\", \"id\": $SEC_ID}]"
fi

gh api --method PUT "repos/$REPO/environments/production" \
  --input - <<EOF
{
  "wait_timer": 10,
  "prevent_self_review": true,
  "reviewers": $REVIEWERS,
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF
gh api --method POST "repos/$REPO/environments/production/deployment-branch-policies" \
  -f name=main -F type=branch 2>/dev/null || true

echo "    OK environments: development, certification, production"
echo "    Agrega secretos: DEV_DEPLOY_TOKEN, CERT_DEPLOY_TOKEN, PROD_DEPLOY_TOKEN"

# ---------------------------------------------------------------------------
# 2. Branch protection
# ---------------------------------------------------------------------------
echo "==> Aplicando branch protection..."

# develop — 1 aprobación + checks
gh api --method PUT "repos/$REPO/branches/develop/protection" \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Build & Lint",
      "Pruebas unitarias",
      "CodeQL (SAST rápido)"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true
}
EOF

# staging — 2 aprobaciones + code owners
gh api --method PUT "repos/$REPO/branches/staging/protection" \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Pruebas de integración",
      "Escaneo de dependencias (SCA)"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 2,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true
}
EOF

# main — gates completos
# Nota: required_signatures y restrictions pueden fallar según plan/permisos.
gh api --method PUT "repos/$REPO/branches/main/protection" \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Suite completa de pruebas",
      "SAST completo (CodeQL)",
      "Escaneo de dependencias (bloqueante)",
      "Escaneo de secretos",
      "Escaneo de imagen Docker"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 2,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "required_signatures": true
}
EOF

echo "    OK branch protection: develop, staging, main"

# ---------------------------------------------------------------------------
# 3. Seguridad nativa
# ---------------------------------------------------------------------------
echo "==> Activando seguridad nativa del repo..."

# Dependabot alerts
gh api --method PUT "repos/$REPO/vulnerability-alerts" 2>/dev/null \
  && echo "    Dependabot alerts: ON" \
  || echo "    Dependabot alerts: no disponible / ya activo"

# Dependabot security updates
gh api --method PUT "repos/$REPO/automated-security-fixes" 2>/dev/null \
  && echo "    Dependabot security updates: ON" \
  || echo "    Dependabot security updates: no disponible / ya activo"

# Secret scanning + push protection (públicos gratis; privados requieren GHAS)
gh api --method PUT "repos/$REPO/secret-scanning/alerts" 2>/dev/null || true
gh api --method PATCH "repos/$REPO" \
  --input - <<'EOF' 2>/dev/null || true
{
  "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" },
    "dependabot_security_updates": { "status": "enabled" }
  }
}
EOF
echo "    Secret scanning / push protection: solicitado"

# Code scanning default setup (CodeQL)
gh api --method PUT "repos/$REPO/code-scanning/default-setup" \
  --input - <<'EOF' 2>/dev/null \
  && echo "    Code scanning default setup: ON" \
  || echo "    Code scanning: usa workflows CodeQL del repo (ci-develop / ci-main)"
{
  "state": "configured",
  "query_suite": "extended",
  "languages": ["javascript"]
}
EOF

# ---------------------------------------------------------------------------
# 4. Ruleset recomendado (opcional, versionable)
# ---------------------------------------------------------------------------
echo "==> Creando ruleset de main (si no existe)..."

EXISTING=$(gh api "repos/$REPO/rulesets" --jq '.[] | select(.name=="main-production-gates") | .id' 2>/dev/null || true)
if [ -z "$EXISTING" ]; then
  gh api --method POST "repos/$REPO/rulesets" \
    --input - <<'EOF'
{
  "name": "main-production-gates",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 2,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "Suite completa de pruebas" },
          { "context": "SAST completo (CodeQL)" },
          { "context": "Escaneo de dependencias (bloqueante)" },
          { "context": "Escaneo de secretos" },
          { "context": "Escaneo de imagen Docker" }
        ]
      }
    }
  ],
  "bypass_actors": []
}
EOF
  echo "    Ruleset main-production-gates creado"
else
  echo "    Ruleset ya existe (id=$EXISTING)"
fi

echo ""
echo "==> Setup completado para $REPO"
echo "Pasos manuales restantes:"
echo "  1. Settings → Environments → agregar secretos DEV_/CERT_/PROD_DEPLOY_TOKEN"
echo "  2. Actualizar QA_LEAD / TECH_LEAD / SECURITY_LEAD y re-ejecutar si hace falta"
echo "  3. Actualizar .github/CODEOWNERS con el equipo real"
echo "  4. Settings → Branches → Restrict push en main al bot CI + admins (UI)"
