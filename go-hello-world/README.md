# Go Hello World

A minimal Go HTTP service with environment-aware demo endpoints and Kubernetes manifests.

## Run locally

```sh
cd go-hello-world
go run .
```

Open <http://localhost:8080> to see `Hello, world!`. `APP_ENV` controls the environment in the two service responses; it defaults to `local`.

```sh
APP_ENV=dev go run .
```

Endpoints:

- `GET /service1` returns `hello world service1 from dev`
- `GET /service2` returns `hello world service2 from dev`
- `GET /healthz` returns `ok` for Kubernetes health probes

Change `APP_ENV` to `staging` or `prod` to see the corresponding response. Build one container image and promote the same immutable image tag or digest through environments; set `APP_ENV` in the environment's Deployment manifest.

## Kubernetes deployment

The example manifests use the same image for all environments and separate them with `dev`, `staging`, and `prod` namespaces. Replace `ghcr.io/q-chakorn/ci-workflow-demo:latest` with a versioned image tag or digest produced by your build, and replace the example Ingress hosts with real DNS names. An NGINX Ingress Controller must already be installed in the cluster.

```sh
kubectl apply -f deploy/k8s/namespaces.yaml
kubectl apply -f deploy/k8s/deployments.yaml
kubectl apply -f deploy/k8s/services.yaml
kubectl apply -f deploy/k8s/ingress.yaml
```

Use distinct environment config (and secrets, if added) per namespace. For a release, update the image reference consistently in the three Deployments to the already-built artifact, then promote it from dev to staging to prod.
