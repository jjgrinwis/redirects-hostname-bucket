variable "custom_zones" {
  description = "List of delegated DNS subzones. Used to correctly determine the zone name when creating SBD challenge CNAME records. If a hostname ends with one of these zones, that zone is used; otherwise, the last 2 labels are assumed to be the zone (e.g., 'example.com')."
  type        = list(string)
  default     = ["shop.example.com", "api.example.com"]
}

variable "group_name" {
  description = "The Akamai Control Center group name where resources will be created. Used to look up contract and group IDs."
  type        = string
  default     = "acc_group"
}

variable "email_list" {
  description = "List of email addresses to receive notifications for property activations and edge hostname creation."
  type        = list(string)
  default     = ["admin@example.com"]
  validation {
    condition     = alltrue([for e in var.email_list : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", e))])
    error_message = "All emails must be valid email addresses."
  }
}

variable "akamai_products" {
  description = "Map of friendly product names to Akamai product IDs. Used to translate product_name to the required product_id."
  type        = map(string)

  default = {
    "ion" = "prd_Fresca"
    "dsa" = "prd_Site_Accel"
    "dd"  = "prd_Download_Delivery"
  }
}

variable "cpcode" {
  description = "Your unique Akamai CPcode name to be used with your property. If it's not defined(\"\"), the default cpcode will be used. https://techdocs.akamai.com/property-mgr/docs/content-provider-code-beh#use-a-default-cp-code"
  type        = string
  default     = ""
}

variable "product_name" {
  description = "The Akamai delivery product name"
  type        = string
  default     = "dsa"
  validation {
    condition     = contains(["ion", "dsa", "dd"], lower(var.product_name))
    error_message = "Product name must be one of: ion, dsa, dd."
  }
}

variable "domain_suffix" {
  description = "Edge hostname suffix determining the Akamai network. Use 'edgekey.net' for Enhanced TLS (ESSL) or 'edgesuite.net' for Standard TLS (Freeflow)."
  type        = string
  default     = "edgesuite.net"
  validation {
    condition     = contains(["edgekey.net", "edgesuite.net"], var.domain_suffix)
    error_message = "Domain suffix must be one of: edgekey.net(ESSL), or edgesuite.net(FF)."
  }
}

variable "ip_behavior" {
  description = "IP version behavior for the edge hostname. IPV4 = IPv4 only, IPV6_PERFORMANCE = prefer IPv6, IPV6_COMPLIANCE = IPv6 with IPv4 fallback."
  type        = string
  default     = "IPV6_COMPLIANCE"
  validation {
    condition     = contains(["IPV4", "IPV6_PERFORMANCE", "IPV6_COMPLIANCE"], var.ip_behavior)
    error_message = "IP behavior must be one of: IPV4, IPV6_PERFORMANCE, IPV6_COMPLIANCE."
  }
}

variable "property_name" {
  description = "Name of the Akamai Property. Also used as the base for the edge hostname (property_name.domain_suffix)."
  type        = string
  default     = "redirects.example.com"
}

variable "hostname_redirects" {
  description = "Map of hostname to redirect URL. Each hostname (key) must be unique and maps to its target redirect URL. Note: If duplicate hostnames are specified, the last value silently overwrites previous ones without warning."
  type        = map(string)
  default = {
    "old.example.com"  = "https://new.example.com"
    "shop.example.com" = "https://store.example.com/welcome"
  }
}

variable "redirect_policy_name" {
  description = "Name of the Edge Redirector Cloudlet policy"
  type        = string
  default     = "redirect_policy"
}
