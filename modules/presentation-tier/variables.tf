variable "name" {
  description = "Prefix for all resource names"
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}

variable "price_class" {
  description = <<-EOT
    CloudFront edge location coverage.
    PriceClass_100 = North America + Europe (cheapest)
    PriceClass_200 = adds Asia, Middle East, Africa
    PriceClass_All = adds South America and Oceania
    Does not restrict who can access the site, only how close the edge is.
  EOT
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "alb_dns_name" {
  description = "DNS name of the application-tier load balancer. Serves /api/*."
  type        = string
}
