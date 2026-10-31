# Keeping Dependencies Up to Date with Renovate

## Motivation

This repository pins a lot of versions: upstream Helm charts in each `charts/*/Chart.yaml`, container image tags in `values.yaml`, OpenTofu providers in `iac/opentofu` and git tags in `app-of-apps/values.yaml`. Checking each of them by hand for new releases quickly becomes tedious.

[Renovate](https://docs.renovatebot.com/) is a bot that scans a git repository, finds every pinned version and opens a pull request whenever a newer one is available. Each update stays a reviewed commit in git, which fits the GitOps workflow: once merged, Argo CD syncs it.

I first considered [Argo CD Image Updater](https://argocd-image-updater.readthedocs.io/), but it only bumps container image tags on Argo CD applications. It can't update chart versions in `Chart.yaml`, which is most of what this repository pins. It's better suited to automatically deploying images built by your own CI.

Renovate can be used through Mend's hosted GitHub App, but I chose to self-host it as a Kubernetes CronJob in the cluster so that it's managed by Argo CD like everything else and doesn't depend on an external service.

## How it works

* `renovate.json` at the repository root is the **repository config**: what to update and how. Renovate's built-in managers detect:
    * `helmv3`: chart dependencies in `Chart.yaml`
    * `helm-values`: `image.repository` / `image.tag` pairs in `values.yaml`
    * `terraform`: OpenTofu providers
    * a custom regex manager for any version annotated with a `# renovate:` comment (see [Tracking a custom version](#tracking-a-custom-version))
* `charts/renovate` deploys the official [Renovate Helm chart](https://github.com/renovatebot/helm-charts) as a CronJob running every hour. Its **global config** (in `values.yaml`) restricts it to this repository and only acts when `renovate.json` exists.
* Patch and minor updates are grouped into one pull request per manager, and major updates get their own pull request.
* A "Dependency Dashboard" issue lists every pending update and lets you trigger one manually by ticking a checkbox.

## Setup

### Prerequisites

* A running Kubernetes cluster with Argo CD and external-secrets
* An OpenBao instance exposed through the `openbao-homelab` ClusterSecretStore

### Create a GitHub token

On GitHub, go to "Settings" > "Developer settings" > "Personal access tokens" > "Fine-grained tokens" and generate a new token:

* **Repository access**: only `homelab-setup`
* **Permissions** (read and write):
    * Contents
    * Pull requests
    * Issues (for the Dependency Dashboard)
    * Workflows (only needed if GitHub Actions workflows are added later)

> **Note:** fine-grained tokens expire (at most one year). Set a reminder to rotate it.

### Create a commit signing key

Without a signing key, Renovate's commits show up as "Unverified" on GitHub. Generate a dedicated SSH key without a passphrase so the CronJob can use it:

```bash
ssh-keygen -t ed25519 -C renovate -N "" -f renovate-signing
```

On GitHub, go to "Settings" > "SSH and GPG keys" > "New SSH key", select **Signing Key** as the key type and paste the content of `renovate-signing.pub`.

The commit author email must be a verified email of the account. Renovate uses the GitHub noreply address, which can be found in "Settings" > "Emails" under "Keep my email addresses private" (format `ID+username@users.noreply.github.com`). It's set as `gitAuthor` in `charts/renovate/values.yaml`.

### Store the secrets in OpenBao

Create the secret `kubernetes/talos-cluster/renovate/github-token` with the following fields:

| Field         | Value                                  |
|---------------|----------------------------------------|
| `token`       | The GitHub fine-grained token          |
| `signing-key` | The content of `renovate-signing`      |

Then delete the local key files:

```bash
rm renovate-signing renovate-signing.pub
```

The `ExternalSecret` in `charts/renovate/templates/external-secrets-github-token.yaml` exposes them to Renovate as `RENOVATE_TOKEN`, `RENOVATE_GITHUB_COM_TOKEN` (avoids rate limits when fetching release notes) and `RENOVATE_GIT_PRIVATE_KEY`.

### Deploy

Renovate is declared in `app-of-apps/values.yaml`:

```yaml
renovate:
  namespace: renovate
  project: infrastructure
```

Push to `main` and Argo CD deploys it. To trigger a run without waiting for the next hourly schedule:

```bash
kubectl -n renovate create job --from=cronjob/renovate renovate-manual
kubectl -n renovate logs -f job/renovate-manual
```

Once the run completes, the "Dependency Dashboard" issue and the first update pull requests should appear on GitHub, with commits marked as "Verified".

## Usage

### Tracking a custom version

Versions that Renovate can't detect on its own, such as the gateway-api `targetRevision` in `app-of-apps/values.yaml`, can be tracked with a `# renovate:` comment right above the line:

```yaml
# renovate: datasource=github-tags depName=kubernetes-sigs/gateway-api
targetRevision: v1.7.0
```

Any [datasource](https://docs.renovatebot.com/modules/datasource/) works (`docker`, `helm`, `github-releases`...). This only applies to `values.yaml` files.

### Major updates

Major updates of infrastructure charts like cilium, longhorn or cert-manager can require manual steps or CRD changes. Read their upgrade notes before merging.

### Rotating the token

The `ExternalSecret` has `refreshInterval: "0"`, so it never re-syncs on its own. After updating the token in OpenBao, force a sync:

```bash
kubectl -n renovate annotate externalsecret renovate-github-token force-sync=$(date +%s) --overwrite
```
