variable "aws_region" {
  description = "AWS region where all resources are created."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Short prefix used to name resources. Use lowercase letters, numbers, and hyphens."
  type        = string
  default     = "metabase"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "metabase_image" {
  description = "Pinned Metabase container image. Update deliberately when upgrading."
  type        = string
  default     = "metabase/metabase:v0.64.0"
}

variable "metabase_cpu" {
  description = "Fargate CPU units for the Metabase task."
  type        = number
  default     = 512
}

variable "metabase_memory" {
  description = "Fargate memory (MiB) for the Metabase task."
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Number of Metabase tasks to run."
  type        = number
  default     = 1
}

variable "db_instance_class" {
  description = "RDS instance size."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 20
}

variable "tags" {
  description = "Extra tags to add to every supported resource."
  type        = map(string)
  default     = {}
}
