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
  default = "un_nom_quelconque"
}

variable "subnet_CIDR" {
  # C'est l'adresse de votre sous-réseau
  default = "172.31.0.0/24"
}

variable "aws_ami" {
  # Ne pas modifier
  # Ubuntu 20.04 LTS dans ca-central-1
  default = "ami-02e44367276fe7adc"
}
