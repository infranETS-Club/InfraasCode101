# NE PAS MODIFIER CE FICHIER
terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  version = "~> 3.0"
  region  = "ca-central-1"
}
