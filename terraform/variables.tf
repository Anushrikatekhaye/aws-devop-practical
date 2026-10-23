variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used for naming resources."
  type        = string
  default     = "devops-practical"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

# ---------------------------------------------------------------- network
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheaper); false = one per AZ (highly available)."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------- compute
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

# ---------------------------------------------------------------- database
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appadmin"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ standby for RDS."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  description = "Set false for production so a final snapshot is taken on destroy."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------- HTTPS
variable "domain_name" {
  description = <<-EOT
    Fully-qualified domain for the application (e.g. app.example.com).
    Leave empty ("") to run without a domain: Terraform then imports a
    self-signed certificate into ACM so the HTTPS listener still works
    (browsers will show a warning). Set it once you own a domain.
  EOT
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Optional Route 53 hosted zone ID. If set with domain_name, ACM validation and the alias record are created automatically."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------- logging
variable "alb_log_retention_days" {
  type    = number
  default = 90
}
