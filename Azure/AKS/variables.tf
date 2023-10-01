variable "resource_group_name" {}
variable "cluster_preset_configuration" {}
variable "cluster_name" {}
variable "region" {}
variable "availabilityzone" {
  type = list(string)
}
variable "pricing_tier" {}
variable "kubernetes_version" {}
variable "automatic_upgrade" {}
variable "authentication_authorization" {}
variable "node_pools" {
  type = list(string)
}
variable "node_size" {}
variable "node_count" {
  type = number
}
variable "private_cluster" {
  type = bool
}
variable "network_plugin" {}
variable "virtual_network_name" {}
variable "subnet_name" {}
variable "network_address_space" {}
variable "address_prefixes" {}
variable "dns_name_prefix" {}
variable "network_policy" {}

variable "acrrepo_name" {}
variable "azureuser" {}
variable "azurepassword" {}
variable "azuretenantid" {}
