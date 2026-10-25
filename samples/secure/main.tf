terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

variable "trusted_admin_cidr" {
  description = "Reserved documentation CIDR; replace with an approved, tightly scoped admin range before use."
  type        = string
  default     = "203.0.113.10/32"
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-security-lab-secure"
  location = "Central India"

  tags = {
    environment = "learning"
    managed_by  = "terraform"
  }
}

resource "azurerm_network_security_group" "lab" {
  name                = "nsg-security-lab-secure"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  tags = azurerm_resource_group.lab.tags
}

resource "azurerm_network_security_rule" "restricted_ssh" {
  name                        = "AllowSshFromTrustedAdminRange"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.trusted_admin_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.lab.name
}
