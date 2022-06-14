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
  lambdas = ["foo", "bar", /*"foo-dynamo",*/ "foo-aurora"]
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

module "dynamodb" {
  count  = local.create_in_other_envs
  source = "./modules/dynamo-db"
  env    = var.env
}

module "lambda" {
  count  = local.create_in_other_envs
  source = "./modules/lambda"
  env    = var.env
  lambdas = local.lambdas
  dynamo_table_arn = module.dynamodb[0].dynamo_table_arn
  aurora_arn = module.aurora-db[0].aurora_arn
}

module "api-gateway" {
  count  = local.create_in_other_envs
  source = "./modules/api-gateway"
  env    = var.env
  lambdas = module.lambda[0].lambdas
}

module "aurora-db" {
  count  = local.create_in_other_envs
  source = "./modules/aurora-db"
  env    = var.env
  vpc_id = module.vpc[0].vpc_id
  database_subnets = module.vpc[0].subnets
  private_subnets_cidr_blocks = module.vpc[0].private_subnets_cidr_blocks
}


module "step-functions" {
  count  = local.create_in_other_envs
  source = "./modules/step-functions"
  env    = var.env
}



