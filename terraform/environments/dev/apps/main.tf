module "rg" {
  source = "../../../modules/foundation/resource_group"

  name     = var.rg_name
  location = var.location
}
