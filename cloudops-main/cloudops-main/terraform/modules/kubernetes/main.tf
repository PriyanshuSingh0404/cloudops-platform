resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-aks-${var.environment}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  dns_prefix          = "acctestagent1"

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_B2s"
    vnet_subnet_id = var.subnet_id
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = "adminuser"

    ssh_key {
      key_data = var.ssh_key
    }
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }

  tags = {
    project_name = var.project_name
    environment  = var.environment
  }
}

# resource "azurerm_kubernetes_cluster_node_pool" "node_pool" {
#   name                  = "internal"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
#   vm_size               = "Standard_B2s"
#   node_count            = 2
#
#   tags = {
#     project_name = var.project_name
#     environment  = var.environment
#   }
# }
