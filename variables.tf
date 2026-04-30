variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod)"
  type        = string
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "account_suffix" {
  description = "Sufijo único para el bucket S3"
  type        = string
  default     = "josue-upao"
}