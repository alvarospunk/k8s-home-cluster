# k8s-home-cluster

Infraestructura base para correr bots de Telegram en local con k3d (Apple Silicon).

## Stack

| Componente | Descripción |
|---|---|
| **k3d** | Cluster k3s dentro de Docker. Nombre: `poc-tooling` |
| **LocalStack** | Simula AWS Secrets Manager. Namespace: `localstack` |
| **ESO** | External Secrets Operator. Sincroniza secrets de LocalStack a k8s |

## Estructura

```
cluster/
  k3d-config.yaml          # Configuración del cluster k3d

apps/
  localstack/
    localstack.yaml         # Namespace + Deployment + Service de LocalStack
  external-secrets/
    values.yaml             # Helm values para ESO (apunta a LocalStack)

bootstrap.sh                # Script: crea cluster + despliega todo lo de arriba
```

## Primer arranque

```bash
# Requisitos: Docker corriendo
brew install k3d helm kubectl

./bootstrap.sh
```

El script:
1. Crea el cluster k3d `poc-tooling`
2. Despliega LocalStack en el namespace `localstack`
3. Instala ESO via Helm apuntando a LocalStack

## El cluster arranca con Docker

Los contenedores k3d tienen política `unless-stopped`, así que al arrancar Docker (y por tanto el Mac) el cluster vuelve a estar disponible automáticamente.

## Añadir un nuevo bot

Cada bot vive en su propio repo y necesita:

1. **Secret en LocalStack** (una sola vez):
   ```bash
   # Port-forward o desde dentro del cluster:
   aws --endpoint-url=http://localhost:4566 secretsmanager create-secret \
       --name <mi-bot>/telegram-token \
       --secret-string '{"TELEGRAM_BOT_TOKEN":"TOKEN_REAL"}'
   ```

2. **Manifiestos k8s en el repo del bot** (`k8s/`):
   - `namespace.yaml`
   - `deployment.yaml` (con `imagePullPolicy: Never`)
   - `pvc.yaml` (si el bot persiste datos)
   - `external-secret.yaml` (Secret de creds LocalStack + SecretStore + ExternalSecret)

3. **`deploy.sh`** en el repo del bot para construir la imagen, importarla con `k3d image import` y aplicar los manifiestos.

## Comandos útiles

```bash
k3d cluster list
kubectl get pods -A
kubectl get externalsecret -A
kubectl logs -f deployment/localstack -n localstack
```
