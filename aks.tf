locals {
  vnet_enabled        = var.vnet_create && var.vnet_service_id == null
  node_resource_group = var.node_resource_group == "" ? "${var.name}-aks-${var.node_pool_name}-${var.location}" : var.node_resource_group
  cluster_subnet_id   = local.vnet_enabled ? module.vnet.subnets.0.id : var.vnet_service_id // Assuming the cluster subnet is first in the Subnet list
  dns_service_ip      = cidrhost(var.vnet_service_cidr, 2)
  oms_enabled         = var.oms_log_analytics_workspace_id != null
}

resource "azurerm_kubernetes_cluster" "cloudcommons" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group
  dns_prefix                      = var.dns_prefix
  kubernetes_version              = var.kubernetes_version
  node_resource_group             = local.node_resource_group
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges
  enable_pod_security_policy      = var.enable_pod_security_policy

  default_node_pool {
    name                  = var.node_pool_name
    node_count            = var.node_pool_count
    enable_node_public_ip = var.node_public_ip_enable
    vm_size               = var.node_pool_vm_size
    max_pods              = var.node_pool_max_pods
    os_disk_size_gb       = var.node_pool_os_disk_size_gb
    vnet_subnet_id        = local.cluster_subnet_id
    enable_auto_scaling   = var.auto_scaling_enable
    min_count             = var.auto_scaling_enable == true ? var.auto_scaling_min_count : null
    max_count             = var.auto_scaling_enable == true ? var.auto_scaling_max_count : null
  }

  linux_profile {
    admin_username = var.linux_admin_username
    ssh_key {
      key_data = var.linux_ssh_key
    }
  }

  network_profile {
    network_plugin     = var.network_plugin
    network_policy     = var.network_policy
    dns_service_ip     = local.dns_service_ip
    docker_bridge_cidr = var.network_docker_bridge_cidr
    service_cidr       = var.vnet_service_cidr
    load_balancer_sku  = var.network_load_balancer_sku
  }

  role_based_access_control {
    enabled = var.rbac_enabled
    dynamic "azure_active_directory" {
      for_each = var.rbac_aad == true ? [1] : []
      content {
        client_app_id     = var.rbac_aad_client_app_id
        server_app_id     = var.rbac_aad_server_app_id
        server_app_secret = var.rbac_aad_server_app_secret
        tenant_id         = var.rbac_aad_tenant_id
      }
    }
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  addon_profile {
    http_application_routing {
      enabled = var.http_application_routing_enabled
    }
    kube_dashboard {
      enabled = var.kube_dashboard_enabled
    }
    oms_agent {
      enabled                    = local.oms_enabled
      log_analytics_workspace_id = var.oms_log_analytics_workspace_id
    }
  }

  tags = {
    app         = var.app
    environment = var.environment
    creator     = var.creator
  }
}
