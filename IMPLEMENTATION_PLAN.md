# Standalone Public Helm Chart para Leloir (Plan de Implementación)

**Autor:** Antigravity (Arquitecto / Revisor)
**Implementador:** Claude
**Destino:** `leloir-helm/charts/leloir`

Actualmente, el despliegue de Leloir está fuertemente acoplado a la infraestructura del homelab (repo `infra-ai`), dividido en dos partes:
1. **Ansible**: Crea el Namespace, Postgres (StatefulSet + PVC), los Secretos (OIDC, credenciales DB, token thrash), el RBAC, y el MCP Gateway.
2. **Chart de homelab (GitOps/ArgoCD)**: Solo despliega el ConfigMap y el Deployment principal del `leloir-controlplane`.

Para que cualquier persona pueda instalar Leloir en su propio cluster con un simple `helm install leloir oci://ghcr.io/villadalmine/leloir-helm`, necesitamos construir un **Chart Standalone** que empaquete todo esto de manera agnóstica.

## Propuesta de Arquitectura del Chart Público

Claude, tu tarea es crear y poblar este nuevo chart en `leloir-helm/charts/leloir`. El nuevo chart debe consolidar todas las dependencias. Esta es la estructura que debes implementar:

### 1. Dependencias (Postgres)
El usuario no debería tener que instalar Postgres a mano.
* Usa el **subchart oficial de Bitnami para PostgreSQL** como dependencia en el `Chart.yaml`.
* Si el usuario pone `postgresql.enabled: true` en sus values, el chart debe levantar automáticamente una base de datos Postgres 16 con la extensión `pgvector` lista para usar.
* Si pone `postgresql.enabled: false`, el usuario debe poder inyectar un DSN hacia un Postgres externo (ej. AWS RDS).

### 2. Componentes Internos a empaquetar
El chart debe incluir los siguientes manifiestos (puedes inspirarte en lo que hace actualmente Ansible en `infra-ai/infra/roles/install-leloir/tasks/main.yml`):
* **CRDs**: Una carpeta `crds/` con los 8 CRDs de Leloir para que Helm los instale automáticamente.
* **Control Plane**: Deployment, Service, ConfigMap.
* **MCP Gateway**: Deployment, Service, ConfigMap. (Por ahora, mantenlo como un Deployment separado tal como está en Ansible, no lo metas como sidecar).
* **Seguridad / RBAC**: Creación automática de ServiceAccounts y (Cluster)Roles con permisos estrictos (cluster-wide watcher para Leloir, pero Role namespaced para LiteLLM).

### 3. Perfiles de Seguridad (Corporate vs Local)
Debemos ser seguros por defecto pero fáciles de probar. El `values.yaml` del chart debe tener un flag `profile`:
* `profile: local`: Genera Secretos nativos de K8s (token thrash, master keys fake), desactiva OIDC, levanta el Postgres interno, usa un usario admin estático. (Ideal para probar en Minikube/Kind).
* `profile: corporate`: Requiere o inyecta variables de OIDC, requiere inyectar un Postgres externo o configuración de Vault (modo seguro).

### 4. Imágenes Docker y Gateway API
* Por ahora, usa `ghcr.io/villadalmine/leloir-controlplane` como repositorio de imágenes en el `values.yaml`. Sabemos que son privadas por ahora, asume que el usuario inyectará sus propios `imagePullSecrets`.
* Ofrece `Ingress` estandar (Nginx/Traefik) en el `values.yaml` por defecto, pero deja la opción de usar `HTTPRoute` (Gateway API) tal como hacemos en el homelab si `gateway.enabled: true`.

## Directiva de Trabajo para Claude
Claude, este es el plan oficial. Procede a implementar el Chart en este repositorio. Una vez que tengas un draft del chart, yo (Antigravity) operaré como Juez/Revisor. No modifiques la infra real en `infra-ai`, este chart debe nacer limpio aquí en `leloir-helm`.
