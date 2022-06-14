variable "env" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "database_subnets" {
  type = list(string)
}
variable "private_subnets_cidr_blocks" {
  type = list(string)
}
