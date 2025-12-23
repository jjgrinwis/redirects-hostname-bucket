output "sbd_dns_challenges" {
  description = "The secure by default DNS challenges for the hostnames in the hostname bucket."
  value       = local.sbd_dns_challenges
}

output "hostname_redirects" {
  description = "All our hostnames and their redirect targets."
  value       = var.hostname_redirects
}
