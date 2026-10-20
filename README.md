# helm-microservices-lab

Laboratório para **ver o Helm funcionando** num Minikube local. Usa como referência o ecossistema de
`spring-microservices-docker-kubernetes` (apps) e `spring-microservices-gitops` (manifestos Kustomize + Argo CD),
mas reescrito com Helm e com apps menores.

```
apps/
  employee-service/     Spring Boot + MongoDB (CRUD, /whoami mostra pod e versão)
  department-service/   Spring Boot + MongoDB; /{id}/employees chama o employee (chamada entre serviços)
charts/
  microservice/         chart GENÉRICO: Deployment, Service, ConfigMap, HPA, Ingress, helm test
  mongodb/              Deployment, Service, Secret, PVC opcional
  observability/        OpenTelemetry Collector + Jaeger
  lab-platform/         UMBRELLA: mongodb + observability + microservice(alias employee) + microservice(alias department)
    values.yaml         dev
    values-prod.yaml    só o que muda no prod
    templates/seed-job.yaml   hook post-install que carrega dados de exemplo
scripts/lab.ps1         up | build | deploy | status | test | forward | demo | template | down | destroy
```

## Pré-requisitos

Docker em execução (Rancher Desktop ou Docker Desktop), `minikube`, `kubectl` e `helm` 3/4.

## Passo a passo

```powershell
.\scripts\lab.ps1 up            # cluster "helm-lab" (4 CPUs, 6 GB) + addons ingress e metrics-server
.\scripts\lab.ps1 build         # constrói lab/employee:1.0.0 e lab/department:1.0.0 dentro do Minikube
.\scripts\lab.ps1 deploy dev    # helm upgrade --install no namespace lab-dev
.\scripts\lab.ps1 status
.\scripts\lab.ps1 test          # helm test
.\scripts\lab.ps1 forward       # employee em :8081, department em :8082
```

Em outro terminal:

```powershell
curl http://localhost:8081/              # employees carregados pelo hook de seed
curl http://localhost:8081/whoami        # pod + versão
curl http://localhost:8082/1/employees   # department -> employee
```

O build usa `minikube image build`, então as imagens ficam no Docker do cluster e o chart usa
`pullPolicy: IfNotPresent` (nada é baixado de registry).

## O que observar em cada conceito do Helm

| Conceito | Onde ver |
|---|---|
| Chart reutilizável | `charts/microservice` serve para employee e department sem copiar nada |
| Dependências + alias | `lab-platform/Chart.yaml`: o mesmo chart entra duas vezes (`alias: employee`, `alias: department`) |
| Values em camadas | `values.yaml` < `-f values-prod.yaml` < `--set`. Veja com `helm get values lab -n lab-dev` |
| `global` | `global.mongodb.database` chega a todos os subcharts como `.Values.global` |
| `tpl` | `department.config.EMPLOYEE_URL` usa `{{ .Release.Name }}` dentro do values |
| Helpers (`_helpers.tpl`) | nomes `<release>-<serviço>` e labels padrão |
| Checksum de ConfigMap | anotação `checksum/config` no pod: mudou a config, os pods são recriados |
| Condicionais | HPA e Ingress só existem se `enabled`; com HPA ligado o Deployment omite `replicas` |
| Hooks | `seed-job.yaml` (`post-install`) e `tests/test-connection.yaml` (`helm test`) |
| `resource-policy: keep` | o PVC do Mongo no prod sobrevive a `helm uninstall` |
| Release e revisões | `helm history`, `helm rollback` |

### OpenTelemetry (traces)

```
employee / department  --OTLP gRPC-->  otel-collector  --OTLP-->  Jaeger (UI)
  (agente Java 2.10.0)                  (+ exporter debug no log)
```

- O agente Java vai dentro da imagem (`/otel`) e é ligado pelo chart com `otel.enabled: true`
  (`JAVA_TOOL_OPTIONS=-javaagent:...` + variáveis `OTEL_*`). Sem instrumentar o código.
- `charts/observability` instala o Collector (config em ConfigMap) e o Jaeger. Desligue tudo com
  `--set observability.enabled=false` (e `employee.otel.enabled=false`).
- Para ver: rode `forward`, faça `curl http://localhost:8082/1/employees` e abra
  http://localhost:16686, serviço `department`. O trace mostra a chamada passando
  por `department` -> `employee` -> MongoDB.
- Spans no log do Collector: `kubectl -n lab-dev logs deploy/lab-otel-collector`.
- Como as imagens mudaram, rode `build` de novo antes do `deploy`.

### Ver o ciclo de vida (upgrade e rollback)

```powershell
.\scripts\lab.ps1 demo          # sobe réplicas, muda ConfigMap, mostra history e faz rollback para a revisão 1
```

Ou à mão:

```powershell
helm upgrade lab charts/lab-platform -n lab-dev --set employee.replicaCount=3
helm history lab -n lab-dev
helm rollback lab 1 -n lab-dev
helm get manifest lab -n lab-dev       # o YAML que o Helm realmente aplicou
```

### Dev vs prod

```powershell
.\scripts\lab.ps1 template dev  > dev.yaml
.\scripts\lab.ps1 template prod > prod.yaml     # compare: HPA 2..5, PVC, mais recursos
.\scripts\lab.ps1 deploy prod                   # namespace lab-prod
```

### Ingress (opcional)

Com o driver docker no Windows, rode `minikube -p helm-lab tunnel` e adicione `127.0.0.1 lab.local` ao
arquivo hosts. Aí `http://lab.local/employee/` e `http://lab.local/department/` funcionam
(mesma ideia do `rewrite-target` do repositório gitops). Sem isso, use `forward`.

## Helm x Kustomize + Argo CD (o que você já tinha)

| gitops (Kustomize) | aqui (Helm) |
|---|---|
| `k8s/base/<app>` repetido por app | um chart `microservice`, parametrizado |
| `overlays/prod` com patches | `values-prod.yaml` |
| Argo CD sincroniza do Git | `helm upgrade --install` imperativo, com histórico de revisões |
| Rollout canary (Argo Rollouts) | Deployment padrão; o Helm não faz canary sozinho |

Os dois combinam: o Argo CD consegue sincronizar um chart Helm como fonte.

## Limpeza

```powershell
.\scripts\lab.ps1 down       # remove o release (o PVC do prod fica por causa do keep)
.\scripts\lab.ps1 destroy    # apaga o cluster helm-lab
```

> As credenciais do Mongo (`lab-password`) são só de laboratório.
