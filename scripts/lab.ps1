# Operação do laboratório. Uso:  .\scripts\lab.ps1 <comando> [args]
#
#   up                 cria o Minikube (perfil helm-lab) com ingress + metrics-server
#   build              constrói as imagens DENTRO do Minikube
#   deploy [dev|prod]  helm upgrade --install (padrão: dev)
#   status             helm list + pods + services
#   test               helm test
#   forward            port-forward: employee em :8081, department em :8082
#   demo               percorre o ciclo de vida do Helm (upgrade, rollback, history)
#   template [dev|prod] renderiza os manifestos sem instalar
#   down               remove o release (mantém o cluster)
#   destroy            apaga o cluster inteiro

param(
    [Parameter(Position = 0)][string]$Command = "help",
    [Parameter(Position = 1)][string]$Env = "dev"
)

$ErrorActionPreference = "Stop"
$Profile_ = "helm-lab"
$Release = "lab"
$Root = Split-Path -Parent $PSScriptRoot
$Chart = Join-Path $Root "charts\lab-platform"
$Namespace = "lab-$Env"

function Invoke-Native {
    # falha o script se o programa externo devolver código != 0
    $all = @($args | ForEach-Object { $_ })   # achata arrays aninhados (ex.: @(Get-ValuesArgs))
    & $all[0] $all[1..($all.Count - 1)]
    if ($LASTEXITCODE -ne 0) { throw "falhou: $($all -join ' ')" }
}

function Get-ValuesArgs {
    if ($Env -eq "prod") { return @("-f", (Join-Path $Chart "values-prod.yaml")) }
    return @()
}

switch ($Command) {
    "up" {
        Invoke-Native minikube start -p $Profile_ --cpus 4 --memory 6144 --driver docker
        Invoke-Native minikube -p $Profile_ addons enable metrics-server
        Invoke-Native minikube -p $Profile_ addons enable ingress
        Invoke-Native kubectl config use-context $Profile_
    }
    "build" {
        foreach ($app in "employee", "department") {
            Invoke-Native minikube -p $Profile_ image build -t "lab/${app}:1.0.0" (Join-Path $Root "apps\$app-service")
        }
    }
    "deploy" {
        Invoke-Native helm dependency update $Chart
        Invoke-Native helm upgrade --install $Release $Chart -n $Namespace --create-namespace @(Get-ValuesArgs) --wait --timeout 5m
        Invoke-Native kubectl -n $Namespace get pods
    }
    "status" {
        Invoke-Native helm list -A
        Invoke-Native kubectl -n $Namespace get pods, svc, hpa, ingress
    }
    "test" {
        Invoke-Native helm test $Release -n $Namespace --logs
    }
    "forward" {
        Write-Host "employee -> http://localhost:8081/   department -> http://localhost:8082/   Jaeger -> http://localhost:16686/   (Ctrl+C para sair)"
        $e = Start-Process kubectl "-n $Namespace port-forward svc/$Release-employee 8081:8080" -PassThru -NoNewWindow
        $d = Start-Process kubectl "-n $Namespace port-forward svc/$Release-department 8082:8080" -PassThru -NoNewWindow
        $j = Start-Process kubectl "-n $Namespace port-forward svc/$Release-jaeger 16686:16686" -PassThru -NoNewWindow
        try { Wait-Process -Id $e.Id, $d.Id, $j.Id } finally { Stop-Process -Id $e.Id, $d.Id, $j.Id -ErrorAction SilentlyContinue }
    }
    "template" {
        Invoke-Native helm dependency update $Chart
        Invoke-Native helm template $Release $Chart -n $Namespace @(Get-ValuesArgs)
    }
    "demo" {
        Write-Host "`n== 1. Estado atual (revisão 1) ==" -ForegroundColor Cyan
        Invoke-Native helm history $Release -n $Namespace

        Write-Host "`n== 2. Upgrade: 3 réplicas no employee, só mudando values ==" -ForegroundColor Cyan
        Invoke-Native helm upgrade $Release $Chart -n $Namespace @(Get-ValuesArgs) --set employee.replicaCount=3 --wait
        Invoke-Native kubectl -n $Namespace get pods -l app.kubernetes.io/name=employee

        Write-Host "`n== 3. Values customizados aplicados no release ==" -ForegroundColor Cyan
        Invoke-Native helm get values $Release -n $Namespace

        Write-Host "`n== 4. Mudar ConfigMap: o checksum recria os pods ==" -ForegroundColor Cyan
        Invoke-Native helm upgrade $Release $Chart -n $Namespace @(Get-ValuesArgs) --set employee.replicaCount=3 --set employee.config.GREETING=ola --wait
        Invoke-Native kubectl -n $Namespace get pods -l app.kubernetes.io/name=employee

        Write-Host "`n== 5. Histórico e rollback para a revisão 1 ==" -ForegroundColor Cyan
        Invoke-Native helm history $Release -n $Namespace
        Invoke-Native helm rollback $Release 1 -n $Namespace --wait
        Invoke-Native helm history $Release -n $Namespace
        Invoke-Native kubectl -n $Namespace get pods -l app.kubernetes.io/name=employee
    }
    "down" {
        Invoke-Native helm uninstall $Release -n $Namespace
    }
    "destroy" {
        Invoke-Native minikube delete -p $Profile_
    }
    default {
        Get-Content $PSCommandPath -TotalCount 12 | Select-Object -Skip 1
    }
}
