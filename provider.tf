# NE PAS MODIFIER CE FICHIER
terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region  = "ca-central-1"
  version = "~> 3.0"
  profile = "workshop"
}
