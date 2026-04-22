
resource "kubernetes_service_account_v1" "openbao" {
  metadata {
    name      = "openbao-service-account"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding_v1" "openbao" {
  metadata {
    name = "openbao-cluster-role"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.openbao.metadata[0].name
    namespace = "kube-system"
  }
}

# Since K8s 1.24+, we need to manually create the secret to get a long-lived token
resource "kubernetes_secret_v1" "openbao" {
  metadata {
    name      = "openbao-token"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.openbao.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  backend = vault_auth_backend.kubernetes.path

  kubernetes_host    = local.kubeconfig.host
  kubernetes_ca_cert = base64decode(local.kubeconfig.ca_certificate)

  token_reviewer_jwt = kubernetes_secret_v1.openbao.data["token"]
}

resource "vault_policy" "external_secrets" {
  name = "external-secrets-policy"

  policy = <<EOT
path "kubernetes/talos-cluster/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "external_secrets" {
  backend = vault_auth_backend.kubernetes.path

  role_name                        = "external-secrets-role"
  bound_service_account_names      = ["external-secrets"]
  bound_service_account_namespaces = ["external-secrets"]
  token_policies                   = [vault_policy.external_secrets.name]
  token_ttl                        = 3600
}
