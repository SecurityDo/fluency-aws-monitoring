provider "aws" {
  region     = var.region
}

module "regionConfig" {
  source           = "./modules/region_config"
  region     = var.region
  accountID = var.accountID
  role = var.role
  expireDays = var.expireDays
}
