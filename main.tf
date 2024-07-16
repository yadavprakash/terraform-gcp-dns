module "labels" {
  source      = "git::git@github.com:yadavprakash/terraform-gcp-labels.git?ref=v1.0.0"
  name        = var.name
  environment = var.environment
  label_order = var.label_order
  managedby   = var.managedby
  repository  = var.repository
}
data "google_client_config" "current" {
}

#------------------------------------------------------------------------------------------------
# A zone is peering subtree of the DNS namespace under one administrative responsibility.
#------------------------------------------------------------------------------------------------
resource "google_dns_managed_zone" "peering" {
  count         = var.type == "peering" ? 1 : 0
  provider      = google-beta
  project       = data.google_client_config.current.project
  name          = format("%s", module.labels.id)
  dns_name      = var.domain
  description   = var.description
  labels        = var.labels
  visibility    = "private"
  force_destroy = var.force_destroy

  dynamic "private_visibility_config" {
    for_each = length(var.private_visibility_config_networks) > 0 ? [1] : []
    content {
      dynamic "networks" {
        for_each = var.private_visibility_config_networks
        content {
          network_url = networks.value
        }
      }
    }
  }

  peering_config {
    target_network {
      network_url = var.target_network
    }
  }
}

#-------------------------------------------------------------------------------------------------
# A zone is forwarding subtree of the DNS namespace under one administrative responsibility.
#-------------------------------------------------------------------------------------------------
resource "google_dns_managed_zone" "forwarding" {
  count         = var.type == "forwarding" ? 1 : 0
  provider      = google-beta
  project       = data.google_client_config.current.project
  name          = format("%s", module.labels.id)
  dns_name      = var.domain
  description   = var.description
  labels        = var.labels
  visibility    = "private"
  force_destroy = var.force_destroy

  dynamic "private_visibility_config" {
    for_each = length(var.private_visibility_config_networks) > 0 ? [1] : []
    content {
      dynamic "networks" {
        for_each = var.private_visibility_config_networks
        content {
          network_url = networks.value
        }
      }
    }
  }

  forwarding_config {
    dynamic "target_name_servers" {
      for_each = var.target_name_server_addresses
      content {
        ipv4_address    = target_name_servers.value.ipv4_address
        forwarding_path = lookup(target_name_servers.value, "forwarding_path", "default")
      }
    }
  }
}

#-----------------------------------------------------------------------------------------------
# A zone is private subtree of the DNS namespace under one administrative responsibility.
#-----------------------------------------------------------------------------------------------
resource "google_dns_managed_zone" "private" {
  count         = var.type == "private" ? 1 : 0
  project       = data.google_client_config.current.project
  name          = format("%s", module.labels.id)
  dns_name      = var.domain
  description   = var.description
  labels        = var.labels
  visibility    = "private"
  force_destroy = var.force_destroy

  dynamic "private_visibility_config" {
    for_each = length(var.private_visibility_config_networks) > 0 ? [1] : []
    content {
      dynamic "networks" {
        for_each = var.private_visibility_config_networks
        content {
          network_url = networks.value
        }
      }
    }
  }
}

#-------------------------------------------------------------------------------------------------
# A zone is public subtree of the DNS namespace under one administrative responsibility.
#-------------------------------------------------------------------------------------------------
resource "google_dns_managed_zone" "public" {
  count         = var.type == "public" ? 1 : 0
  project       = data.google_client_config.current.project
  name          = format("%s", module.labels.id)
  dns_name      = var.domain
  description   = var.description
  labels        = var.labels
  visibility    = "public"
  force_destroy = var.force_destroy

  dynamic "dnssec_config" {
    for_each = length(var.dnssec_config) == 0 ? [] : [var.dnssec_config]
    iterator = config
    content {
      kind          = lookup(config.value, "kind", "dns#managedZoneDnsSecConfig")
      non_existence = lookup(config.value, "non_existence", "nsec3")
      state         = lookup(config.value, "state", "off")

      default_key_specs {
        algorithm  = lookup(var.default_key_specs_key, "algorithm", "rsasha256")
        key_length = lookup(var.default_key_specs_key, "key_length", 2048)
        key_type   = lookup(var.default_key_specs_key, "key_type", "keySigning")
        kind       = lookup(var.default_key_specs_key, "kind", "dns#dnsKeySpec")
      }
      default_key_specs {
        algorithm  = lookup(var.default_key_specs_zone, "algorithm", "rsasha256")
        key_length = lookup(var.default_key_specs_zone, "key_length", 1024)
        key_type   = lookup(var.default_key_specs_zone, "key_type", "zoneSigning")
        kind       = lookup(var.default_key_specs_zone, "kind", "dns#dnsKeySpec")
      }
    }
  }

  cloud_logging_config {
    enable_logging = var.enable_logging
  }
}

#----------------------------------------------------------------------------------------------------
# A zone is reverse_lookup subtree of the DNS namespace under one administrative responsibility.
#----------------------------------------------------------------------------------------------------
resource "google_dns_managed_zone" "reverse_lookup" {
  count          = var.type == "reverse_lookup" ? 1 : 0
  provider       = google-beta
  project        = data.google_client_config.current.project
  name           = format("%s", module.labels.id)
  dns_name       = var.domain
  description    = var.description
  labels         = var.labels
  visibility     = "private"
  force_destroy  = var.force_destroy
  reverse_lookup = true

  dynamic "private_visibility_config" {
    for_each = length(var.private_visibility_config_networks) > 0 ? [1] : []
    content {
      dynamic "networks" {
        for_each = var.private_visibility_config_networks
        content {
          network_url = networks.value
        }
      }
    }
  }
}

#--------------------------------------------------------------------------------------------------------
# A zone is service_directory subtree of the DNS namespace under one administrative responsibility.
#--------------------------------------------------------------------------------------------------------
resource "google_dns_managed_zone" "service_directory" {
  count         = var.type == "service_directory" ? 1 : 0
  provider      = google-beta
  project       = data.google_client_config.current.project
  name          = format("%s", module.labels.id)
  dns_name      = var.domain
  description   = var.description
  labels        = var.labels
  visibility    = "private"
  force_destroy = var.force_destroy

  private_visibility_config {
    dynamic "networks" {
      for_each = var.private_visibility_config_networks
      content {
        network_url = networks.value
      }
    }
  }

  service_directory_config {
    namespace {
      namespace_url = var.service_namespace_url
    }
  }
}

#--------------------------------------------------------------------------------------------------
# Manages a set of DNS records within Google Cloud DNS.
##-------------------------------------------------------------------------------------------------
resource "google_dns_record_set" "cloud-static-records" {
  project      = data.google_client_config.current.project
  managed_zone = format("%s", module.labels.id)

  for_each = { for record in var.recordsets : join("/", [record.name, record.type]) => record }
  name = (
    each.value.name != "" ?
    "${each.value.name}.${var.domain}" :
    var.domain
  )
  type    = each.value.type
  ttl     = each.value.ttl
  rrdatas = each.value.records

  depends_on = [
    google_dns_managed_zone.private,
    google_dns_managed_zone.public,
  ]
}