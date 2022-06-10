terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.17"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.0.0"
    }
  }
  backend "s3" {
    encrypt = true
    bucket = "serverless-terraform-class-state"
    key = "terraform-state/terraform.tfstate"
    region = "us-east-2"

    dynamodb_table = "serverless-terraform-class-state-lock"
  }
}

locals {
  create_in_backend = terraform.workspace == "backend" ? 1 : 0
  create_in_other_envs = terraform.workspace != "backend" ? 1 : 0
  lambdas = ["foo", "bar"]
}

# Providers
provider "aws" {
  region  = "us-east-2"
  profile = "default"
}

# Modules
module "backend" {
  count  = local.create_in_backend
  source = "./modules/backend"
}

module "vpc" {
  count  = local.create_in_other_envs
  source = "./modules/vpc"
  env    = var.env
}

module "hosting" {
  count  = local.create_in_other_envs
  source = "./modules/hosting"
  env    = var.env
  domain = "serverlessterraform.com"
}

module "lambda" {
  count  = local.create_in_other_envs
  source = "./modules/lambda"
  env    = var.env
  lambdas = local.lambdas
}

module "api-gateway" {
  count  = local.create_in_other_envs
  source = "./modules/api-gateway"
  env    = var.env
  lambdas = module.lambda[0].lambdas
}



