terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"
  subscription_id                 = var.subscription_id
  features {

  }
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_key_vault" "vault" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "vault_secret" {
  name         = "ssh-public-keys"
  key_vault_id = data.azurerm_key_vault.vault.id
}

# ACR
resource "azurerm_container_registry" "acr" {
  name                = "${var.project_name}acr${var.environment}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = {
    project_name = var.project_name
    environment  = var.environment
  }
}

resource "azurerm_role_assignment" "pull_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.k8s.principal_id
}

resource "random_string" "random" {
  length  = 3
  special = false
  upper   = false
}

# Module k8s
module "k8s" {
  source                  = "../../modules/kubernetes"
  resource_group_name     = data.azurerm_resource_group.main.name
  resource_group_location = data.azurerm_resource_group.main.location

  # Node pool
  subnet_id = module.networking.subnet_id

  # Linux profile
  ssh_key = data.azurerm_key_vault_secret.vault_secret.value

  # Network profile
  service_cidr   = var.service_cidr
  dns_service_ip = var.dns_service_ip

  # Tags
  project_name = var.project_name
  environment  = var.environment

  depends_on = [module.networking]
}

# Module networking
module "networking" {
  source                  = "../../modules/networking"
  resource_group_name     = data.azurerm_resource_group.main.name
  resource_group_location = data.azurerm_resource_group.main.location

  #Network
  address_space  = var.address_space
  address_prefix = var.address_prefix

  # Tags
  project_name = var.project_name
  environment  = var.environment
}
