#############
# IMPORTANT #
#############
# Modifier le nom ci-dessous avec ce que vous voulez (nom, pseudo, ...)
variable "prefix" {
  type    = string
  default = "un_nom_quelconque" # Modifier ICI 😋
}

variable "key_name" {
  # Mettre le nom de votre clé SSH créée sur AWS
  default = "etienne"
}

variable "aws_ami" {
  # Ne pas modifier
  # Ubuntu 20.04 LTS dans ca-central-1
  default = "ami-02e44367276fe7adc"
}

variable "subnet_CIDR" {
  # Ne pas modifier 
  # C'est votre adresse de réseau utiliser dans le VPC
  default = "172.31.0.0/24"
}