variable "env" {
  description = "Environment name"
  default = "dev"
  type = string
}
variable "dynamo_table_arn" {
  type = string
}
variable "aurora_arn" {
  type = string
}
variable "lambdas" {
  default = []
  type = list(string)
}
