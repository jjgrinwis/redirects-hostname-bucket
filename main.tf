# First lookup contract as that contains information regarding contract and group ids.
data "akamai_contract" "contract" {
  group_name = var.group_name
}

locals {
  # Determine if the edgehostname is using on the Akamai secure network. (ESSL)
  secure = var.domain_suffix == "edgekey.net"

  # a check to decide if we have to create a cpcode resource or not.
  cpcode_defined = trimspace(var.cpcode) != ""
  cpcode         = var.cpcode

  # collect all secure by default DNS challenges for the hostnames in the hostname bucket for SBD DNS validation.
  sbd_dns_challenges = flatten([
    for bucket in data.akamai_property_hostnames.redirect_bucket_hostnames.hostname_bucket : [
      for cert in bucket.cert_status : {
        hostname  = cert.hostname
        challenge = cert.target
      }
    ]
  ])
}


# Create an Akamai Property for Redirect with hostname buckets enabled
# based on the domain_suffix we determine if this property should use secure network or not.
# This version now has support the use default cpcodes when a cpcode is not defined.
resource "akamai_property" "redirect_property" {
  name        = var.property_name
  product_id  = var.akamai_products[lower(var.product_name)]
  contract_id = data.akamai_contract.contract.id
  group_id    = data.akamai_contract.contract.group_id
  rule_format = "latest"
  rules = templatefile("${path.module}/templates/property-rules.json.tftpl", {
    is_secure            = local.secure
    cpcode               = local.cpcode_defined ? tonumber(trimprefix(resource.akamai_cp_code.cp_code[0].id, "cpc_")) : 0
    cloudlet_policy_id   = tonumber(resource.akamai_cloudlets_policy.edge_redirector_policy.id)
    cloudlet_policy_name = resource.akamai_cloudlets_policy.edge_redirector_policy.name
  })
  use_hostname_bucket = true
  version_notes       = "Terraform managed property using Hostname Bucket and the Edge Redirector cloudlet."
}

# Conditionally create or lookup Akamai CPcode if cpcode is defined
resource "akamai_cp_code" "cp_code" {
  count       = local.cpcode_defined ? 1 : 0
  name        = local.cpcode
  contract_id = data.akamai_contract.contract.id
  group_id    = data.akamai_contract.contract.group_id
  product_id  = var.akamai_products[lower(var.product_name)]
}

# our dedicated edge hostname for the redirect property using hostname bucket.
resource "akamai_edge_hostname" "redirect_edge_hostname" {
  product_id          = resource.akamai_property.redirect_property.product_id
  contract_id         = resource.akamai_property.redirect_property.contract_id
  group_id            = resource.akamai_property.redirect_property.group_id
  edge_hostname       = "${var.property_name}.${var.domain_suffix}"
  ip_behavior         = var.ip_behavior
  status_update_email = var.email_list
}

# to make use of hostname buckets our property needs to be enabled on staging or production network.
# this only needs to happens once. The next time only hostname buckets will be updated.
# more info about the phases of activation: https://techdocs.akamai.com/property-mgr/docs/how-activation-works#phases-of-activation
resource "akamai_property_activation" "redirect_activation" {
  for_each = toset(["STAGING", "PRODUCTION"])

  property_id                    = resource.akamai_property.redirect_property.id
  contact                        = var.email_list
  version                        = resource.akamai_property.redirect_property.latest_version
  network                        = each.value
  note                           = "Activating a Terraform managed hostname bucket property on Akamai ${lower(each.value)} network."
  auto_acknowledge_rule_warnings = true
}

# now add hostnames to our hostname bucket on staging and production networks.
resource "akamai_property_hostname_bucket" "redirect_hostname_bucket" {
  for_each = toset(["STAGING", "PRODUCTION"])

  property_id = resource.akamai_property_activation.redirect_activation[each.value].property_id
  network     = each.value

  # our dynamic list of hostnames we're going to add to the hostname bucket.
  hostnames = {
    for h in keys(var.hostname_redirects) :
    h => {
      cert_provisioning_type = "DEFAULT"
      edge_hostname_id       = resource.akamai_edge_hostname.redirect_edge_hostname.id
    }
  }
}

# now let's get the Secure By Default (SBD) challenges to validate the certificate request via DNS.
# there is an option to filter pending default certs, but in this case we want all challenges as we're using terraform to create the DNS records and will delete them otherwise.
data "akamai_property_hostnames" "redirect_bucket_hostnames" {
  group_id    = data.akamai_contract.contract.group_id
  contract_id = data.akamai_contract.contract.id
  property_id = resource.akamai_property.redirect_property.id
  #filter_pending_default_certs = true

  # hostname bucket resource should have done it's work before getting all the SDB challenges.
  depends_on = [akamai_property_hostname_bucket.redirect_hostname_bucket]
}
