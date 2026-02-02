provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "app" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.app_name}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  os_type  = "Linux"
  sku_name = var.plan_sku_name

  tags = var.tags
}

# Komentarz: nazwa Web App w Azure musi być globalnie unikalna w *.azurewebsites.net.
# Dodajemy suffix, żeby nie wpadać w konflikt nazw.
resource "random_id" "suffix" {
  byte_length = 2
}

resource "azurerm_linux_web_app" "web" {
  name                = "app-${var.app_name}-${random_id.suffix.hex}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  service_plan_id     = azurerm_service_plan.plan.id

  https_only = true

  # WEBSITES_PORT: App Service musi wiedzieć, na jakim porcie nasłuchuje kontener
  app_settings = merge({
    WEBSITES_PORT = tostring(var.container_port)
  }, var.use_docker_registry_auth ? {
    DOCKER_REGISTRY_SERVER_URL      = var.docker_registry_url
    DOCKER_REGISTRY_SERVER_USERNAME = var.docker_registry_username
    DOCKER_REGISTRY_SERVER_PASSWORD = var.docker_registry_password
  } : {})

  site_config {
    minimum_tls_version = "1.2"
    always_on           = true

    # Najważniejsze: wskazanie obrazu i registry
    application_stack {
      docker_image_name        = "${var.docker_image}:${var.docker_tag}"
      docker_registry_url      = var.docker_registry_url

      # Jeśli obraz prywatny – włącz use_docker_registry_auth i podaj login/hasło
      docker_registry_username = var.use_docker_registry_auth ? var.docker_registry_username : null
      docker_registry_password = var.use_docker_registry_auth ? var.docker_registry_password : null
    }
  }

  tags = var.tags
}