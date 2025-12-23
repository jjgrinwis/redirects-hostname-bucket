# Default provider for property/hostname management
provider "akamai" {
  edgerc         = "~/.edgerc"
  config_section = "betajam"
}

# Separate provider for EdgeDNS operations with different credentials
provider "akamai" {
  alias          = "edgedns"
  edgerc         = "~/.edgerc"
  config_section = "gss-demo"
}
