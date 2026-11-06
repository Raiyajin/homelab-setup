# Expose GitHub Webhooks Through OPNsense

GitHub webhooks reach the cluster through a dedicated `webhooks` Gateway, separate from the public Gateway used by browser traffic on port 443:

```
GitHub ──> WAN:44300 ──(DNAT, source = GitHub hook IPs)──> 10.50.0.210:443 (Gateway "webhooks") ──> HTTPRoute
```

- Gateway: `charts/cilium/values.yaml` (`gateway.webhooks`), IP taken from the `public` LB pool (`10.50.0.208/29`)
- Routes: only the exact webhook paths are exposed, e.g. `/api/webhook` for Argo CD in `charts/argo-cd/templates/route.yaml`
- DNS: created by external-dns (OVH) from the HTTPRoute hostname
- TLS: Let's Encrypt certificate issued through DNS-01, no inbound port needed

Using a dedicated port lets the firewall only accept GitHub source IPs, which is not possible on 443 shared with users.

## Create the GitHub hooks alias

Go to `Firewall > Aliases` and add:

| Field | Value |
|-------|-------|
| Name | `github_hooks` |
| Type | `URL Table in JSON format` |
| Content | `https://api.github.com/meta` |
| Path expression | `.hooks[]` |
| Refresh Frequency | 1 day |

Save and apply.

Check the alias in `Firewall > Diagnostics > Aliases`: it must list CIDRs (IPv4 and IPv6). If it is empty, check `Firewall > Log Files > General`.

> If the JSON alias type is not available, use a `Network(s)` alias and paste the `hooks` CIDRs from https://api.github.com/meta manually (it won't auto-update).

## Create the port forward

Go to `Firewall > NAT > Port Forward` and add:

| Field | Value |
|-------|-------|
| Interface | WAN |
| Protocol | TCP |
| Source | `github_hooks` |
| Destination | WAN address |
| Destination port | `44300` |
| Redirect target IP | `10.50.0.210` |
| Redirect target port | `443` |
| Filter rule association | Add associated filter rule |

## Configure the webhook in GitHub

In the repository `Settings > Webhooks > Add webhook`:

- Payload URL: `https://webhooks.<domain>:44300/api/webhook`
- Content type: `application/json`
- Secret: the value stored in OpenBao, created with:
  ```bash
  bao kv put -mount=kubernetes/talos-cluster argo-cd/github/webhook secret="$(openssl rand -hex 32)"
  bao kv get -mount=kubernetes/talos-cluster -field=secret argo-cd/github/webhook
  ```
  It is synced by the `argocd-github-webhook` ExternalSecret and referenced from `argocd-secret` as `$argocd-github-webhook:secret`.

The secret is required: GitHub hook IPs are shared by every GitHub user, so the IP filter alone does not authenticate the sender.

Verify with `Recent Deliveries > Redeliver`, the response must be `200`.

## Expose another webhook

1. Add a listener to `gateway.webhooks` in `charts/cilium/values.yaml` (or allow the namespace on the existing one)
2. Add an HTTPRoute with `parentRefs: [{name: webhooks, namespace: kube-system}]`, matching only the webhook path

## Argo Workflows CI

Argo Server receives GitHub webhooks on `/api/v1/events/argo/github` (`charts/argo-workflows/templates/route.yaml`). It checks the HMAC secret, then submits the WorkflowTemplate matched by a `WorkflowEventBinding` (`charts/argo-workflows/workflows/`).

1. Create the secrets in OpenBao:
   ```bash
   bao kv put -mount=kubernetes/talos-cluster argo-workflows/github/webhook secret="$(openssl rand -hex 32)"
   # classic PAT, scopes: repo:status, write:packages
   bao kv put -mount=kubernetes/talos-cluster argo-workflows/github/pat token=<ghp_...>
   ```
2. In the repository, add a second webhook (Argo CD keeps its own):
   - Payload URL: `https://webhooks.<domain>:44300/api/v1/events/argo/github`
   - Content type: `application/json`
   - Secret: `bao kv get -mount=kubernetes/talos-cluster -field=secret argo-workflows/github/webhook`
   - Events: `Pushes` and `Pull requests`

Every delivery gets a `200`, even when no binding matches. To check that a binding fired, look at the submitted workflows: `kubectl -n argo get wf`.

UI: `https://argo-workflows.homelab.internal`. Log in with `Bearer $(kubectl -n argo create token argo-workflows-server)`.
