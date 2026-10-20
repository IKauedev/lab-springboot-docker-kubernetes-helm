#!/usr/bin/env bash
# Operação do laboratório. Uso:  ./scripts/lab.sh <comando> [dev|prod]
#
#   up                 cria o Minikube (perfil helm-lab) com ingress + metrics-server
#   build              constrói as imagens DENTRO do Minikube
#   deploy [dev|prod]  helm upgrade --install (padrão: dev)
#   status             helm list + pods + services
#   test               helm test
#   forward            port-forward: employee :8081, department :8082, Jaeger :16686
#   demo               percorre o ciclo de vida do Helm (upgrade, rollback, history)
#   template [dev|prod] renderiza os manifestos sem instalar
#   down               remove o release (mantém o cluster)
#   destroy            apaga o cluster inteiro

set -euo pipefail

PROFILE="helm-lab"
RELEASE="lab"
COMMAND="${1:-help}"
ENV="${2:-dev}"
NAMESPACE="lab-${ENV}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART="${ROOT}/charts/lab-platform"

# `-f values-prod.yaml` só no prod
VALUES_ARGS=()
if [[ "${ENV}" == "prod" ]]; then
  VALUES_ARGS=(-f "${CHART}/values-prod.yaml")
fi

# Em Windows (Git Bash) os caminhos precisam estar no formato C:/... para o minikube/helm
to_native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

section() { printf '\n\033[36m== %s ==\033[0m\n' "$1"; }

case "${COMMAND}" in
  up)
    minikube start -p "${PROFILE}" --cpus 4 --memory 6144 --driver docker
    minikube -p "${PROFILE}" addons enable metrics-server
    minikube -p "${PROFILE}" addons enable ingress
    kubectl config use-context "${PROFILE}"
    ;;
  build)
    for app in employee department; do
      minikube -p "${PROFILE}" image build -t "lab/${app}:1.0.0" "$(to_native "${ROOT}/apps/${app}-service")"
    done
    ;;
  deploy)
    helm dependency update "$(to_native "${CHART}")"
    helm upgrade --install "${RELEASE}" "$(to_native "${CHART}")" -n "${NAMESPACE}" --create-namespace \
      "${VALUES_ARGS[@]}" --wait --timeout 5m
    kubectl -n "${NAMESPACE}" get pods
    ;;
  status)
    helm list -A
    kubectl -n "${NAMESPACE}" get pods,svc,hpa,ingress
    ;;
  test)
    helm test "${RELEASE}" -n "${NAMESPACE}" --logs
    ;;
  forward)
    echo "employee -> http://localhost:8081/   department -> http://localhost:8082/   Jaeger -> http://localhost:16686/   (Ctrl+C para sair)"
    trap 'kill $(jobs -p) 2>/dev/null' EXIT INT TERM
    kubectl -n "${NAMESPACE}" port-forward "svc/${RELEASE}-employee" 8081:8080 &
    kubectl -n "${NAMESPACE}" port-forward "svc/${RELEASE}-department" 8082:8080 &
    kubectl -n "${NAMESPACE}" port-forward "svc/${RELEASE}-jaeger" 16686:16686 &
    wait
    ;;
  template)
    helm dependency update "$(to_native "${CHART}")" >/dev/null
    helm template "${RELEASE}" "$(to_native "${CHART}")" -n "${NAMESPACE}" "${VALUES_ARGS[@]}"
    ;;
  demo)
    EMPLOYEE_PODS=(-l app.kubernetes.io/name=employee)

    section "1. Estado atual (revisão 1)"
    helm history "${RELEASE}" -n "${NAMESPACE}"

    section "2. Upgrade: 3 réplicas no employee, só mudando values"
    helm upgrade "${RELEASE}" "$(to_native "${CHART}")" -n "${NAMESPACE}" "${VALUES_ARGS[@]}" \
      --set employee.replicaCount=3 --wait
    kubectl -n "${NAMESPACE}" get pods "${EMPLOYEE_PODS[@]}"

    section "3. Values customizados aplicados no release"
    helm get values "${RELEASE}" -n "${NAMESPACE}"

    section "4. Mudar ConfigMap: o checksum recria os pods"
    helm upgrade "${RELEASE}" "$(to_native "${CHART}")" -n "${NAMESPACE}" "${VALUES_ARGS[@]}" \
      --set employee.replicaCount=3 --set employee.config.GREETING=ola --wait
    kubectl -n "${NAMESPACE}" get pods "${EMPLOYEE_PODS[@]}"

    section "5. Histórico e rollback para a revisão 1"
    helm history "${RELEASE}" -n "${NAMESPACE}"
    helm rollback "${RELEASE}" 1 -n "${NAMESPACE}" --wait
    helm history "${RELEASE}" -n "${NAMESPACE}"
    kubectl -n "${NAMESPACE}" get pods "${EMPLOYEE_PODS[@]}"
    ;;
  down)
    helm uninstall "${RELEASE}" -n "${NAMESPACE}"
    ;;
  destroy)
    minikube delete -p "${PROFILE}"
    ;;
  *)
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    ;;
esac
