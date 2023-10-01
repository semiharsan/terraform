provider "azurerm" {
  features {}
}

terraform {
    backend "azurerm" {
    resource_group_name = "NetworkWatcherRG"
    storage_account_name = "arsitterraformstorage"
    container_name = "terraformcontainer"
    key = "terraformstoragekey"
    }
}


data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "arsitaks" {
  name     = var.resource_group_name
  location = var.region
}

resource "azurerm_virtual_network" "arsitaks" {
  name                = var.virtual_network_name
  address_space       = [var.network_address_space]
  location            = azurerm_resource_group.arsitaks.location
  resource_group_name = azurerm_resource_group.arsitaks.name
}

resource "azurerm_subnet" "arsitaks" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.arsitaks.name
  virtual_network_name = azurerm_virtual_network.arsitaks.name
  address_prefixes     = [var.address_prefixes]
}

resource "azurerm_kubernetes_cluster" "arsitaks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.arsitaks.location
  resource_group_name = azurerm_resource_group.arsitaks.name
  dns_prefix          = var.dns_name_prefix
  kubernetes_version = var.kubernetes_version
  private_cluster_enabled = var.private_cluster

  default_node_pool {
    name       = var.node_pools[0]
    node_count = var.node_count
    min_count = 1
    max_count = 2
    vm_size    = var.node_size
    #availability_zones = var.availabilityzone
    enable_auto_scaling = true
  }

  network_profile {
    network_plugin = var.network_plugin
    network_policy = var.network_policy
    load_balancer_sku = "standard"
    outbound_type    = "loadBalancer"
  }

  identity {
    type = "SystemAssigned"
  }
  
  depends_on = [azurerm_subnet.arsitaks]
  
  tags = {}
}

resource "azurerm_container_registry" "arsitaks" {
  name                     = var.acrrepo_name
  resource_group_name      = azurerm_resource_group.arsitaks.name
  location                 = azurerm_resource_group.arsitaks.location
  sku                      = "Standard"
  admin_enabled            = true
}

resource "null_resource" "enable_aks_preview_extension" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = <<-EOT
      az login --service-principal --username ${var.azureuser} --password ${var.azurepassword} --tenant ${var.azuretenantid}
      az aks get-credentials --resource-group=${var.resource_group_name} --name=${var.cluster_name} --overwrite-existing
      kubectl apply -f cert-manager.yaml
      az extension add --name aks-preview
      kubectl get all --all-namespaces
    EOT
  }

  depends_on = [azurerm_kubernetes_cluster.arsitaks]
}

output "acr_login_server" {
  value = azurerm_container_registry.arsitaks.login_server
}
