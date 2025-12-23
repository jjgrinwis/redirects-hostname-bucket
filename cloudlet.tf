# create a dedicated redirect policy for the Edge Redirector Cloudlet.
resource "akamai_cloudlets_policy" "edge_redirector_policy" {
  name          = var.redirect_policy_name
  cloudlet_code = "ER"
  group_id      = data.akamai_contract.contract.group_id
  match_rules = templatefile("${path.module}/templates/cloudlet-policy.json.tftpl", {
    hostname_redirects = var.hostname_redirects
  })
  description = "Terraform managed Edge Redirector Cloudlet policy."
}

# activate redirect cloudlet policy on staging and production networks.
resource "akamai_cloudlets_policy_activation" "edge_redirector_policy_activation" {
  for_each = toset(["staging", "production"])

  policy_id             = resource.akamai_cloudlets_policy.edge_redirector_policy.id
  network               = each.value
  version               = resource.akamai_cloudlets_policy.edge_redirector_policy.version
  associated_properties = [var.property_name]
  timeouts {
    default = "20m"
  }
}
