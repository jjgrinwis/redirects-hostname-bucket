locals {
  # sbd_dns_records: Builds a map of DNS record data for SBD (Secure By Default) challenges.
  # IMPORTANT: Uses keys(var.hostname_redirects) as static keys for for_each to avoid Terraform planning issues.
  # Terraform requires for_each keys to be known at plan time, so we cannot use data from 
  # data.akamai_property_hostnames which is only available after apply.
  # 
  # For each hostname in var.hostname_redirects, determines the DNS zone and record name dynamically:
  # - If the challenge hostname ends with a value from var.custom_zones, that value is used as the zone.
  # - Otherwise, the zone is the last two labels of the hostname (default behavior).
  # The name is everything before the zone.
  # The challenge/target value is looked up from the data source at apply time.
  sbd_dns_records = {
    for hostname in keys(var.hostname_redirects) :
    hostname => merge(
      {
        # The full hostname for the DNS challenge (e.g., _acme-challenge.foo.example.com)
        challenge_hostname = "_acme-challenge.${hostname}"
        # Look up the challenge/target value from the data source (available at apply time)
        challenge = try(
          [for bucket in data.akamai_property_hostnames.redirect_bucket_hostnames.hostname_bucket :
            bucket.cert_status[0].target if bucket.cname_from == hostname
          ][0],
          null
        )
      },
      # Calculate zone and name based on custom_zones match or default to 2 labels
      # Check if the hostname itself is a custom zone, not if it ends with one
      (contains(var.custom_zones, hostname)
        ? {
          # Hostname is a custom zone - use the full hostname as the zone
          zone = hostname
          name = "_acme-challenge.${hostname}"
        }
        : (try([for z in var.custom_zones : z if endswith(hostname, ".${z}")][0], null) != null
          ? {
            # Hostname is a subdomain of a custom zone - use the custom zone
            zone = try([for z in var.custom_zones : z if endswith(hostname, ".${z}")][0], null)
            name = "_acme-challenge.${hostname}"
          }
          : {
            # No custom zone match - use default of last 2 labels
            zone = join(".", slice(split(".", hostname), length(split(".", hostname)) - 2, length(split(".", hostname))))
            name = "_acme-challenge.${hostname}"
          }
        )
      )
    )
  }
}

# create SBD CNAME records for the domain validation
resource "akamai_dns_record" "sbd_cname" {
  provider = akamai.edgedns

  for_each = local.sbd_dns_records

  zone       = each.value.zone
  name       = each.value.name
  target     = [each.value.challenge]
  recordtype = "CNAME"
  ttl        = 60

  # Ensure this waits for the hostname bucket to be created
  depends_on = [akamai_property_hostname_bucket.redirect_hostname_bucket]
}
