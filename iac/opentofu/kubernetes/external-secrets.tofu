locals {
  openbao_roles = {
    "external-secrets" = {
      bound_service_account_names      = ["external-secrets"]
      bound_service_account_namespaces = ["external-secrets"]
      policy                           = <<-EOT
          path "kubernetes/talos-cluster/*" {
            capabilities = ["read", "list"]
          }
        EOT
    }
    "cert-manager" = {
      bound_service_account_names      = ["cert-manager"]
      bound_service_account_namespaces = ["tools"]
      policy                           = <<-EOT
        path "pki/sign/cert-manager" {
          capabilities = ["create", "update"]
        }
      EOT
    }
  }
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

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

resource "vault_kubernetes_auth_backend_config" "config" {
  backend = vault_auth_backend.kubernetes.path

  kubernetes_host    = local.kubeconfig.host
  kubernetes_ca_cert = base64decode(local.kubeconfig.ca_certificate)

  token_reviewer_jwt = kubernetes_secret_v1.openbao.data["token"]
}

resource "vault_pki_secret_backend_role" "role" {
  backend = "pki"

  name    = "cert-manager"
  ttl     = "720h"
  max_ttl = "8760h"

  allow_ip_sans = false
  key_type      = "ec"
  key_bits      = 256

  allowed_domains             = ["homelab.internal"]
  allow_bare_domains          = false
  allow_localhost             = false
  allow_subdomains            = true
  allow_wildcard_certificates = false
}

resource "vault_policy" "policy" {
  for_each = local.openbao_roles

  name   = "${each.key}-policy"
  policy = each.value.policy
}

resource "vault_kubernetes_auth_backend_role" "role" {
  for_each = local.openbao_roles

  backend = vault_auth_backend.kubernetes.path

  role_name                        = "${each.key}-role"
  bound_service_account_names      = each.value.bound_service_account_names
  bound_service_account_namespaces = each.value.bound_service_account_namespaces
  token_policies                   = [vault_policy.policy[each.key].name]
  token_ttl                        = 3600
}
