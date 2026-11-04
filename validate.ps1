[CmdletBinding()]
param(
    # Use only after providers have been initialized on this machine.
    [switch]$Offline
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    foreach ($stack in @('terraform', 'databricks')) {
        terraform "-chdir=$stack" fmt -check -recursive
        if ($LASTEXITCODE -ne 0) { throw "Terraform formatting failed: $stack" }
        if (-not $Offline) {
            terraform "-chdir=$stack" init -backend=false -input=false -lockfile=readonly
            if ($LASTEXITCODE -ne 0) { throw "Provider initialization failed: $stack" }
        } elseif (-not (Test-Path -LiteralPath (Join-Path $stack '.terraform/providers'))) {
            throw "Offline validation needs initialized providers: $stack. Run validate.ps1 once with registry access."
        }
        terraform "-chdir=$stack" validate -no-color
        if ($LASTEXITCODE -ne 0) { throw "Terraform validation failed: $stack" }
        terraform "-chdir=$stack" test -no-color
        if ($LASTEXITCODE -ne 0) { throw "Terraform mock-plan tests failed: $stack" }
    }
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Invoke-Deployment.ps1'), [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) { throw 'Deployment script syntax invalid' }
    python -m unittest discover -s . -p 'test_*.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Regression tests failed' }
    Write-Output 'Local validation passed. This is NOT deployment approval or compliance certification.'
} finally {
    Pop-Location
}
