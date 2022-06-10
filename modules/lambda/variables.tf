variable "env" {
  description = "Environment name"
  default = "dev"
  type = string
}
variable "lambdas" {
  default = []
  type = list(string)
}
