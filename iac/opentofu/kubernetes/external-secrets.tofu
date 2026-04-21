resource "vault_auth_backend" "kubernetes" {
  type      = "kubernetes"
  path      = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  backend                = vault_auth_backend.kubernetes.path

  kubernetes_host        = "${local.bootstrapped_controlplane_ip}:6443"
  kubernetes_ca_cert     = base64decode(talos_machine_secrets.this.machine_secrets.certs.k8s["cert"])
  disable_local_ca_jwt   = false
}

resource "vault_policy" "external_secrets" {
  name      = "external-secrets-policy"

  policy    = <<EOT
path "secret/data/kubernetes/talos-cluster/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "external_secrets" {
  backend                          = vault_auth_backend.kubernetes.path

  role_name                        = "external-secrets-role"
  bound_service_account_names      = ["external-secrets"]
  bound_service_account_namespaces = ["external-secrets"]
  token_policies                   = [vault_policy.external_secrets.name]
  token_ttl                        = 3600
}