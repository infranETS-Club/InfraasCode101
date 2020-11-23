# NE PAS MODIFIER CE FICHIER
data "aws_vpc" "workshop" {
  cidr_block = "172.31.0.0/16"
}

data "aws_internet_gateway" "gw" {
  internet_gateway_id = "igw-043a16bfd8d26f040"
}
