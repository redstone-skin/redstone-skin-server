# k3s migration environment

This directory is an isolated migration baseline. It intentionally uses one
application replica and file-backed cache/session storage until PostgreSQL
compatibility and the production data import have been verified.

## Prerequisites

- A default `StorageClass`, or add `storageClassName` to `pvc.yaml`.
- An existing PostgreSQL database reachable from the namespace.
- Traefik and cert-manager if `ingress.yaml` is enabled.
- The `app` and `web` images pushed to a registry reachable by k3s.

## Configure

1. Replace the two image names in `kustomization.yaml`.
2. Set the actual PostgreSQL host in `configmap.yaml`.
3. Create `mcskin-secrets` without committing credentials. For example:

   ```sh
   kubectl create namespace mcskin-migration
   kubectl -n mcskin-migration create secret generic mcskin-secrets \
     --from-env-file=/secure/path/mcskin.env
   ```

4. Apply the base without creating a production Ingress or changing DNS:

   ```sh
   kubectl apply -k deploy/k3s
   ```

5. Run the migration Job only against the empty test database:

   ```sh
   kubectl apply -f deploy/k3s/migration-job.example.yaml
   kubectl -n mcskin-migration logs -f job/mcskin-migrate
   ```

The example Secret and migration Job are deliberately excluded from the
Kustomization. `ingress.yaml` is also excluded and must only be applied during
an explicitly planned test-host or production cutover. Never commit a
populated Secret file.

## Production state that is not in Git

The production installation has these enabled plugins, but the repository's
`plugins/` directory only contains `.gitignore`:

- `config-generator` 3.2.2
- `204-for-unexisted-players` 0.1.4
- `hitokoto` 1.3.0
- `legacy-api` 1.1.3
- `share-registration-link` 2.0.2
- `textures-aliyun-oss` 2.0.6
- `trust-proxies` 0.1.3
- `yggdrasil-api` 5.1.5
- `usm-api` 1.2.3
- `restricted-email-domains` 0.3.0

Copy the production `plugins/`, `public/plugins/`, and `public/lang/` trees to
the PVC before application acceptance testing. Historical plugin tables also
exist in production (`reg_link`, `textures_description`, `mojang_verifications`,
`uuid`, and `ygg_log`); the real data migration must create and import them in
addition to the core schema.

## Local PostgreSQL smoke test

The Compose environment uses PostgreSQL 16 and intentionally stores only
throwaway local data:

```sh
docker compose build app web
docker compose up -d
docker compose exec app php artisan migrate --force
curl http://localhost:8080/healthz
curl -I http://localhost:8080/
```

On 2026-09-02 the locked production baseline (`b69faa4d`) successfully built,
all 24 core migrations ran on PostgreSQL 16, and both endpoints returned HTTP
200. This proves the empty core schema and runtime chain; it does not yet prove
the MySQL production-data conversion or plugin behavior.
