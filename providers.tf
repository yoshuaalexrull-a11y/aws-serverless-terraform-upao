terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" 
}

# Esto es para obtener las zonas de disponibilidad dinámicamente
data "aws_availability_zones" "available" {
  state = "available"
}