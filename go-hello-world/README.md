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

Change `APP_ENV` to `staging` or `prod` to see the corresponding response. Build one container image and promote the same immutable image digest through environments; each Kustomize overlay sets its own `APP_ENV`.

## GitOps deployment and image promotion

Argo CD has one Application per environment and watches `deploy/k8s/overlays/dev`, `deploy/k8s/overlays/staging`, and `deploy/k8s/overlays/prod`. CI tests the app, builds and pushes one image to GHCR, then updates the `dev` Kustomize overlay to that image's immutable digest. The workflow run summary shows the digest.

After validating the image in dev, run the **Promote image** GitHub Actions workflow with environment `staging` and the same `sha256:...` digest. After validating staging, run it again with environment `prod` and that same digest. The workflow checks that the preceding environment already uses the digest, updates only the requested Kustomize overlay, and commits the change for Argo CD to sync. This keeps the promoted artifact identical across environments and makes each change traceable in Git.

The manifests use separate `dev`, `staging`, and `prod` namespaces. Replace the example Ingress hosts with real DNS names. An NGINX Ingress Controller must already be installed in the cluster.

For a local manual deployment, apply each environment overlay with `kubectl apply -k deploy/k8s/overlays/dev` (or `staging` / `prod`).

Use distinct environment config (and secrets, if added) per namespace. Do not update image tags by hand; promote the digest through the GitHub Actions workflow so every environment runs the same built image.
