# Configura environments, branch protection, rulesets y seguridad nativa.
# Uso: .\scripts\setup-github.ps1 [-Repo owner/name]
# Requiere: gh autenticado con scope repo

param(
  [string]$Repo = ""
)

$ErrorActionPreference = "Stop"

if (-not $Repo) {
  $Repo = gh repo view --json nameWithOwner -q .nameWithOwner
}

$Owner = $Repo.Split("/")[0]
Write-Host "==> Repositorio: $Repo"

# --- Environments -----------------------------------------------------------
Write-Host "==> Creando environments..."

$bodyDev = @{
  wait_timer = 0
  prevent_self_review = $false
  reviewers = @()
  deployment_branch_policy = @{
    protected_branches = $false
    custom_branch_policies = $true
  }
} | ConvertTo-Json -Depth 5

$tmp = New-TemporaryFile
Set-Content -Path $tmp -Value $bodyDev -Encoding utf8
gh api --method PUT "repos/$Repo/environments/development" --input $tmp
Remove-Item $tmp
gh api --method POST "repos/$Repo/environments/development/deployment-branch-policies" -f name=develop -F type=branch 2>$null

$QaLead = if ($env:QA_LEAD) { $env:QA_LEAD } else { $Owner }
$QaId = gh api "users/$QaLead" --jq .id
$bodyCert = @{
  wait_timer = 0
  prevent_self_review = $true
  reviewers = @(@{ type = "User"; id = [int]$QaId })
  deployment_branch_policy = @{
    protected_branches = $false
    custom_branch_policies = $true
  }
} | ConvertTo-Json -Depth 5
$tmp = New-TemporaryFile
Set-Content -Path $tmp -Value $bodyCert -Encoding utf8
gh api --method PUT "repos/$Repo/environments/certification" --input $tmp
Remove-Item $tmp
gh api --method POST "repos/$Repo/environments/certification/deployment-branch-policies" -f name=staging -F type=branch 2>$null

$TechLead = if ($env:TECH_LEAD) { $env:TECH_LEAD } else { $Owner }
$SecLead = if ($env:SECURITY_LEAD) { $env:SECURITY_LEAD } else { $Owner }
$TechId = [int](gh api "users/$TechLead" --jq .id)
$SecId = [int](gh api "users/$SecLead" --jq .id)

if ($TechId -eq $SecId) {
  Write-Warning "TECH_LEAD y SECURITY_LEAD son el mismo usuario. Configura 2 reviewers distintos después."
  $reviewers = @(@{ type = "User"; id = $TechId })
} else {
  $reviewers = @(
    @{ type = "User"; id = $TechId },
    @{ type = "User"; id = $SecId }
  )
}

$bodyProd = @{
  wait_timer = 10
  prevent_self_review = $true
  reviewers = $reviewers
  deployment_branch_policy = @{
    protected_branches = $false
    custom_branch_policies = $true
  }
} | ConvertTo-Json -Depth 5
$tmp = New-TemporaryFile
Set-Content -Path $tmp -Value $bodyProd -Encoding utf8
gh api --method PUT "repos/$Repo/environments/production" --input $tmp
Remove-Item $tmp
gh api --method POST "repos/$Repo/environments/production/deployment-branch-policies" -f name=main -F type=branch 2>$null

Write-Host "    OK environments"

# --- Branch protection ------------------------------------------------------
Write-Host "==> Aplicando branch protection..."

function Set-BranchProtection {
  param([string]$Branch, [hashtable]$Payload)
  $tmp = New-TemporaryFile
  ($Payload | ConvertTo-Json -Depth 8) | Set-Content -Path $tmp -Encoding utf8
  gh api --method PUT "repos/$Repo/branches/$Branch/protection" --input $tmp
  Remove-Item $tmp
}

Set-BranchProtection -Branch develop -Payload @{
  required_status_checks = @{
    strict = $true
    contexts = @("Build & Lint", "Pruebas unitarias", "CodeQL (SAST rápido)")
  }
  enforce_admins = $true
  required_pull_request_reviews = @{
    dismiss_stale_reviews = $true
    require_code_owner_reviews = $false
    required_approving_review_count = 1
    require_last_push_approval = $false
  }
  restrictions = $null
  required_linear_history = $false
  allow_force_pushes = $false
  allow_deletions = $false
  block_creations = $false
  required_conversation_resolution = $true
}

Set-BranchProtection -Branch staging -Payload @{
  required_status_checks = @{
    strict = $true
    contexts = @("Pruebas de integración", "Pruebas E2E (Playwright)", "Escaneo de dependencias (SCA)")
  }
  enforce_admins = $true
  required_pull_request_reviews = @{
    dismiss_stale_reviews = $true
    require_code_owner_reviews = $true
    required_approving_review_count = 2
    require_last_push_approval = $false
  }
  restrictions = $null
  required_linear_history = $false
  allow_force_pushes = $false
  allow_deletions = $false
  block_creations = $false
  required_conversation_resolution = $true
}

Set-BranchProtection -Branch main -Payload @{
  required_status_checks = @{
    strict = $true
    contexts = @(
      "Suite completa de pruebas",
      "Pruebas E2E (Playwright)",
      "SAST completo (CodeQL)",
      "Escaneo de dependencias (bloqueante)",
      "Escaneo de secretos",
      "Escaneo de imagen Docker"
    )
  }
  enforce_admins = $true
  required_pull_request_reviews = @{
    dismiss_stale_reviews = $true
    require_code_owner_reviews = $true
    required_approving_review_count = 2
    require_last_push_approval = $true
  }
  restrictions = $null
  required_linear_history = $true
  allow_force_pushes = $false
  allow_deletions = $false
  block_creations = $false
  required_conversation_resolution = $true
  required_signatures = $true
}

Write-Host "    OK branch protection"

# --- Seguridad --------------------------------------------------------------
Write-Host "==> Activando seguridad nativa..."
try { gh api --method PUT "repos/$Repo/vulnerability-alerts" | Out-Null; Write-Host "    Dependabot alerts: ON" } catch { Write-Host "    Dependabot alerts: skip" }
try { gh api --method PUT "repos/$Repo/automated-security-fixes" | Out-Null; Write-Host "    Dependabot security updates: ON" } catch { Write-Host "    Dependabot security updates: skip" }

$secBody = @{
  security_and_analysis = @{
    secret_scanning = @{ status = "enabled" }
    secret_scanning_push_protection = @{ status = "enabled" }
    dependabot_security_updates = @{ status = "enabled" }
  }
} | ConvertTo-Json -Depth 5
$tmp = New-TemporaryFile
Set-Content -Path $tmp -Value $secBody -Encoding utf8
try { gh api --method PATCH "repos/$Repo" --input $tmp | Out-Null; Write-Host "    Secret scanning: solicitado" } catch { Write-Host "    Secret scanning: skip (plan/permisos)" }
Remove-Item $tmp

# --- Ruleset ----------------------------------------------------------------
Write-Host "==> Ruleset main..."
$existing = gh api "repos/$Repo/rulesets" --jq '.[] | select(.name=="main-production-gates") | .id' 2>$null
if (-not $existing) {
  $ruleset = @{
    name = "main-production-gates"
    target = "branch"
    enforcement = "active"
    conditions = @{
      ref_name = @{
        include = @("refs/heads/main")
        exclude = @()
      }
    }
    rules = @(
      @{ type = "deletion" },
      @{ type = "non_fast_forward" },
      @{
        type = "pull_request"
        parameters = @{
          required_approving_review_count = 2
          dismiss_stale_reviews_on_push = $true
          require_code_owner_review = $true
          require_last_push_approval = $true
          required_review_thread_resolution = $true
        }
      },
      @{
        type = "required_status_checks"
        parameters = @{
          strict_required_status_checks_policy = $true
          required_status_checks = @(
            @{ context = "Suite completa de pruebas" },
            @{ context = "Pruebas E2E (Playwright)" },
            @{ context = "SAST completo (CodeQL)" },
            @{ context = "Escaneo de dependencias (bloqueante)" },
            @{ context = "Escaneo de secretos" },
            @{ context = "Escaneo de imagen Docker" }
          )
        }
      }
    )
    bypass_actors = @()
  } | ConvertTo-Json -Depth 10
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp -Value $ruleset -Encoding utf8
  gh api --method POST "repos/$Repo/rulesets" --input $tmp
  Remove-Item $tmp
  Write-Host "    Ruleset creado"
} else {
  Write-Host "    Ruleset ya existe (id=$existing)"
}

Write-Host ""
Write-Host "==> Setup completado para $Repo"
Write-Host "Agrega secretos DEV_/CERT_/PROD_DEPLOY_TOKEN en cada environment."
Write-Host "Actualiza CODEOWNERS y reviewers reales (QA/Tech/Seguridad)."
