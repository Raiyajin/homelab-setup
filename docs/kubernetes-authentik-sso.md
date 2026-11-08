# Single Sign-On with Authentik

## Motivation

Each web UI in the cluster (Argo CD, Argo Workflows, Grafana...) has its own login and its own users. [Authentik](https://goauthentik.io/) is a self-hosted identity provider: users and groups live in one place, and apps delegate their login to it over OpenID Connect (OIDC).

I chose Authentik over Dex (which only federates an external provider such as GitHub) to keep authentication independent from external services. It runs in the cluster, which creates a chicken-and-egg problem when the cluster is broken, so every app keeps a local break-glass account (see [Break-glass access](#break-glass-access)).

## How it works

* `charts/authentik` deploys the official [Authentik chart](https://goauthentik.io/docs/install-config/install/kubernetes) (pulled from `oci://ghcr.io/goauthentik/helm-charts`) with its PostgreSQL database (`postgres` chart from `oci://ghcr.io/raiyajin/charts`). The UI is at `https://auth.homelab.internal`.
* Secrets come from OpenBao through the `authentik-secrets` `ExternalSecret`, loaded as environment variables in the server and worker pods.
* Uploaded files (app icons, branding) are stored on a Longhorn volume mounted at `/data` on the server (`templates/pvc.yaml`).
* Apps, providers, groups and access rules are managed as code with [blueprints](https://docs.goauthentik.io/docs/customize/blueprints/): each file in `charts/authentik/blueprints/` is put in the `authentik-blueprints` ConfigMap, which the worker mounts and applies when it changes (and every hour).
* Each app gets:
    * an **OAuth2/OIDC provider**: client ID, client secret, redirect URI and the claims sent in the token
    * an **application**: the entry on the user dashboard, linked to the provider
    * a **policy binding**: only members of the bound group can log in
* Authorization stays in each app: the `profile` scope adds a `groups` claim to the token, and each app maps groups to its own roles.
* Users (and their MFA devices) are managed in the UI, not in blueprints.

| Concept | Role |
|---|---|
| User / Group | Who you are / what you can do. `homelab-admins` is defined in `blueprints/argocd.yaml` |
| Provider | How Authentik talks to the app (OIDC here; Proxy for apps without login, not used yet) |
| Application | The app as users see it, access is restricted with policy bindings |
| Flow | The login, consent and logout steps. Apps use `default-provider-authorization-implicit-consent` (no consent screen) |

### Apps using SSO

| App | Client ID | Redirect URI | Group mapping |
|---|---|---|---|
| Argo CD | `argocd` | `https://argocd.homelab.internal/auth/callback` | `homelab-admins` → `role:admin` (`configs.rbac.policy.csv`) |
| Argo Workflows | `argo-workflows` | `https://argo-workflows.homelab.internal/oauth2/callback` | `homelab-admins` → `argo-admin` SA (`templates/sso-rbac.yaml`) |
| Grafana | `grafana` | `https://grafana.homelab.internal/login/generic_oauth` | `homelab-admins` → `Admin`, others `Viewer` (`role_attribute_path`) |

## Setup

### Prerequisites

* A running Kubernetes cluster with Argo CD, external-secrets, Longhorn and cert-manager (trust-manager)
* An OpenBao instance exposed through the `openbao-homelab` ClusterSecretStore
* The `authentik-https` listener on the internal Gateway (`charts/cilium/values.yaml`)

### Create the Authentik secrets

Generate them once, `secret_key` must never change after the first install:

```bash
bao kv put -mount=kubernetes/talos-cluster authentik/config \
  secret_key="$(openssl rand -base64 60 | tr -d '\n')" \
  postgres_password="$(openssl rand -hex 32)"
```

Every OIDC client secret read by `authentik-secrets` must exist as well (see [Adding SSO to an app](#adding-sso-to-an-app)), otherwise the whole `ExternalSecret` fails to sync.

### Initial setup

Once Argo CD has synced the `authentik` application, open `https://auth.homelab.internal/if/flow/initial-setup/` and set the `akadmin` password.

Then, in the admin interface:

1. Create your own user in "Directory" > "Users" and add it to the `homelab-admins` group. Use it daily, `akadmin` is only the break-glass account.
2. Log in with your user and enroll an MFA device in the user settings ("MFA Devices").

### Break-glass access

Authentik runs in the cluster, so it can be down exactly when you need to fix it. Keep a local login on every app:

* Authentik: `akadmin`
* Argo CD: the local `admin` user (`kubectl -n argocd get secret argocd-initial-admin-secret` or the password you set)
* Argo Workflows: a bearer token (`client` auth mode)

## Adding SSO to an app

The example below uses an app called `myapp` served at `https://myapp.homelab.internal`.

### 1. Create the client secret

The same OpenBao value is read by Authentik and by the app:

```bash
bao kv put -mount=kubernetes/talos-cluster myapp/oidc client_secret="$(openssl rand -hex 32)"
```

> **Note:** create it before pushing. `authentik-secrets` syncs all its keys or none: a missing key leaves Authentik degraded.

### 2. Expose it to Authentik

Add the key to `charts/authentik/templates/external-secrets.yaml`:

```yaml
  - secretKey: MYAPP_OIDC_CLIENT_SECRET
    remoteRef:
      key: kubernetes/talos-cluster/myapp/oidc
      property: client_secret
```

### 3. Write the blueprint

Create `charts/authentik/blueprints/myapp.yaml`, it's picked up automatically by the ConfigMap:

```yaml
# yaml-language-server: $schema=https://goauthentik.io/blueprints/schema.json
version: 1
metadata:
  name: homelab My App
entries:
  - model: authentik_providers_oauth2.oauth2provider
    id: myapp-provider
    identifiers:
      name: myapp
    attrs:
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
      client_type: confidential
      client_id: myapp
      client_secret: !Env MYAPP_OIDC_CLIENT_SECRET
      # Empty when created from a blueprint (the UI fills it), authorize then fails as "malformed"
      grant_types:
        - authorization_code
        - refresh_token
      redirect_uris:
        - matching_mode: strict
          url: https://myapp.homelab.internal/<callback path>
          redirect_uri_type: authorization
      property_mappings:
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-openid]]
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-email]]
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-profile]]
      signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]

  - model: authentik_core.application
    id: myapp-app
    identifiers:
      slug: myapp
    attrs:
      name: My App
      provider: !KeyOf myapp-provider
      meta_launch_url: https://myapp.homelab.internal

  - model: authentik_policies.policybinding
    identifiers:
      target: !KeyOf myapp-app
      group: !Find [authentik_core.group, [name, homelab-admins]]
    attrs:
      order: 0
```

The issuer URL of the app is `https://auth.homelab.internal/application/o/<slug>/` (the trailing slash matters).

> **Note:** a blueprint is the source of truth for the objects it declares: changes made in the UI to these objects are overwritten on the next apply. Removing an entry from a file doesn't delete the object, set `state: absent` on it first.

### 4. Configure the app

In the app's chart:

1. Add an `ExternalSecret` reading `kubernetes/talos-cluster/myapp/oidc`, in the format the app expects (see `charts/argo-cd/templates/external-secrets-oidc.yaml` or the `argo-server-sso` one in `charts/argo-workflows/templates/external-secrets.yaml`).
2. Configure OIDC with the issuer, the client ID `myapp`, the client secret and the scopes `openid profile email`.
3. Map the `groups` claim to the app's roles.
4. Trust the homelab CA, `auth.homelab.internal` is signed by OpenBao:
    * Label the namespace with `cert-manager.io/trust: enabled` (`managedNamespaceMetadata` in `app-of-apps/values.yaml`) so trust-manager copies the `ca-trust-bundle` ConfigMap into it
    * Mount it and point the app at it. For Go apps, `SSL_CERT_FILE` replaces the system CAs, which is fine since the bundle also contains the public CAs:

```yaml
env:
  - name: SSL_CERT_FILE
    value: /etc/ssl/homelab/trust-bundle.pem
volumes:
  - name: ca-trust-bundle
    configMap:
      name: ca-trust-bundle
volumeMounts:
  - name: ca-trust-bundle
    mountPath: /etc/ssl/homelab
    readOnly: true
```

### 5. Deploy

1. Push, and wait for the `authentik` and app syncs.
2. Restart Authentik: environment variables are only read at startup, so the new client secret isn't visible to the blueprint until then:

```bash
kubectl -n authentik rollout restart deploy/authentik-worker deploy/authentik-server
```

3. Check that the blueprint applied in "System" > "Blueprints" (status "successful"). Errors only show up there, not in Argo CD.
4. Log in to the app with your user (not `akadmin`, which isn't in `homelab-admins`). Use a private window if you're logged in to Authentik as `akadmin`.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `invalid_request: The request is otherwise malformed` | The provider has no `grant_types` (Authentik server logs show `Invalid grant_type for provider`) |
| `x509: certificate signed by unknown authority` in the app | The `ca-trust-bundle` isn't mounted, or the pod started before trust-manager copied it (restart it) |
| Access denied on the Authentik side | The user isn't in the group bound to the application |
| Grafana `Login failed: InternalError`, its logs show `Error getting email address` on `.../userinfo//emails` | The Authentik user has no email, Grafana requires one (set it in "Directory" > "Users") |
| Logged in but no permissions | The `groups` claim is missing (`profile` scope) or doesn't match the app's role mapping |
| `authentik-secrets` degraded, `Secret does not exist` | An OpenBao key read by the `ExternalSecret` wasn't created |
| Blueprint error about a missing value (`client_secret: This field may not be null`) | The client secret env var was empty when it applied: create the OpenBao key, restart Authentik, then click "Apply" on the blueprint (it's otherwise only retried hourly) |
| `No file management backend configured` when uploading an image | `/data` isn't a mounted volume on the server |

The Authentik server logs show the details of each failed login:

```bash
kubectl -n authentik logs deploy/authentik-server | grep -iE 'invalid|malformed|denied'
```
