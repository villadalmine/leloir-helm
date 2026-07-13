# Probar Leloir en un sandbox efímero (vcluster)

¿Querés evaluar Leloir **sin ensuciar tu cluster** ni levantar VMs pesadas? Usá
[vcluster](https://www.vcluster.com/): un plano de control de Kubernetes completo
que corre **dentro de un simple namespace** de tu cluster. Lo creás, instalás
Leloir adentro, jugás, y lo **destruís en segundos** — sin dejar rastro.

Es el patrón ideal para evaluar charts: aislamiento total y descartable.

## Requisitos

- Un cluster Kubernetes cualquiera (Minikube, Kind, K3s, EKS…) con `kubectl` configurado.
- [`helm`](https://helm.sh/docs/intro/install/) v3.8+ (soporte OCI).
- El CLI de [`vcluster`](https://www.vcluster.com/docs/get-started) (`v0.20+`).

## 1. Crear el vcluster efímero

```bash
vcluster create leloir-sandbox -n vcluster-leloir --connect
```

`--connect` apunta tu `kubectl`/`helm` al cluster virtual. (Todo lo que hagas
ahora ocurre DENTRO del sandbox.)

## 2. Instalar Leloir desde GHCR (OCI)

```bash
helm install leloir oci://ghcr.io/villadalmine/leloir --version 0.1.0 \
  --namespace leloir-system --create-namespace \
  --set profile=local
```

El `profile: local` es seguro-para-probar: genera los Secrets nativos (token
interno, admin estático), levanta un **Postgres 16 + pgvector** interno, y deja
OIDC apagado. Todo lo OSS queda prendido (gateway L7 + budgets + RBAC).

## 3. Verificar que levantó

```bash
kubectl get pods -n leloir-system
```

Deberías ver los 5 pods `1/1 Running` (control plane, gateway, memory-mcp,
webhook-receiver, postgresql). El control plane espera a Postgres con un
`initContainer` (arranque limpio, sin CrashLoop).

Accedé a la API/UI:

```bash
kubectl -n leloir-system port-forward svc/leloir-controlplane 8080:80
# → http://localhost:8080
```

## 4. Destruir el sandbox (sin rastro)

```bash
vcluster disconnect
vcluster delete leloir-sandbox -n vcluster-leloir
```

Listo — el cluster virtual y TODO lo que instalaste adentro desaparecen. Tu
cluster principal quedó intacto.

---

## Para desarrolladores del chart

Si estás iterando sobre el chart (código local, no la versión publicada), usá el
script [`scripts/test-vcluster.sh`](../scripts/test-vcluster.sh): crea un vcluster,
instala el chart **desde el directorio local** con `--wait`, y reporta cualquier
`CrashLoopBackOff` o error de volumen. Ideal para el ciclo de CI/validación.

> Idea futura: un **dev-environment "probalo" self-service** (vcluster + ArgoCD)
> empaquetado, para que un usuario levante Leloir con un click.
