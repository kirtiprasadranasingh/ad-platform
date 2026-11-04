[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('infrastructure','databricks')][string]$Phase,
    [Parameter(Mandatory)][ValidateSet('plan','apply')][string]$Action,
    [Parameter(Mandatory)][string]$BackendFile,
    [Parameter(Mandatory)][string]$PlanFile,
    [string]$VariablesFile,
    [string]$ApprovedPlanSha256
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Execute only on an approved private managed-identity runner.
# No automatic state unlock, cleanup deletion, targeted apply or firewall changes.
$stackDirectory = Join-Path $PSScriptRoot $(if ($Phase -eq 'infrastructure') { 'terraform' } else { 'databricks' })
$backendPath = (Resolve-Path -LiteralPath $BackendFile).Path
$planPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PlanFile)
$inputPath = if ($VariablesFile) { (Resolve-Path -LiteralPath $VariablesFile).Path } else { $null }
$backendText = ((Get-Content -LiteralPath $backendPath) | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
if ($backendText -match 'REPLACE_') { throw 'Client backend configuration is incomplete.' }
if ($inputPath -and ((Get-Content -Raw -LiteralPath $inputPath) -match 'REPLACE_')) {
    throw 'Client deployment inputs still contain example placeholders.'
}
if ($backendText -match '(?im)^\s*(access_key|sas_token|client_secret)\s*=') {
    throw 'Backend credentials in files are forbidden; use managed identity.'
}
foreach ($required in @('use_azuread_auth','use_msi')) {
    if ($backendText -notmatch "(?im)^\s*$required\s*=\s*true\s*$") {
        throw "Backend must explicitly enable $required."
    }
}
if ($backendText -notmatch "(?im)^\s*key\s*=\s*`"[^\`"]+/$Phase\.tfstate`"\s*$") {
    throw "Backend key must be environment-scoped and end in /$Phase.tfstate."
}
if ($Action -eq 'apply') {
    if ($ApprovedPlanSha256 -notmatch '^[a-fA-F0-9]{64}$') {
        throw 'Apply requires the independently reviewed saved-plan SHA256.'
    }
    if ((Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash -ne $ApprovedPlanSha256) {
        throw 'Saved plan does not match the approved hash.'
    }
} elseif (-not $VariablesFile) {
    throw 'Plan requires an explicit client variables file.'
}
Push-Location $stackDirectory
try {
    terraform init -input=false -lockfile=readonly "-backend-config=$backendPath"
    if ($LASTEXITCODE -ne 0) { throw 'Backend initialization failed.' }
    terraform validate -no-color
    if ($LASTEXITCODE -ne 0) { throw 'Configuration validation failed.' }
    if ($Action -eq 'plan') {
        if (Test-Path -LiteralPath $planPath) { throw 'Refusing to overwrite an existing saved plan.' }
        terraform plan -input=false -lock-timeout=5m "-var-file=$inputPath" "-out=$planPath"
        if ($LASTEXITCODE -ne 0) { throw 'Plan failed.' }
    }
    # Keep machine-readable plan in memory, not a public artifact or console log.
    $planJson = terraform show -json $planPath
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect saved plan.' }
    $planJson | python (Join-Path $PSScriptRoot 'check_plan.py') - $Phase
    if ($LASTEXITCODE -ne 0) { throw 'Security guardrails rejected the saved plan.' }
    if ($Action -eq 'apply') {
        # Recheck immediately before apply; Terraform also verifies state serial.
        if ((Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash -ne $ApprovedPlanSha256) {
            throw 'Saved plan changed after review.'
        }
        terraform apply -input=false -lock-timeout=5m $planPath
        if ($LASTEXITCODE -ne 0) { throw 'Apply failed. Investigate; do not auto-delete resources or unlock state.' }
    } else {
        Write-Output ('Saved plan SHA256: ' + (Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash)
        Write-Output 'Review this exact plan and record independent approval before apply.'
    }
} finally {
    $planJson = $null
    Pop-Location
}
