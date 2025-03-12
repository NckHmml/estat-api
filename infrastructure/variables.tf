variable "rds_password" {
  description = "Root password for the database"
  type        = string
}

variable "root_vpc" {
  description = "AWS default VPC"
  type        = string
}

variable "root_sg" {
  description = "AWS default Security Group"
  type        = string
}
