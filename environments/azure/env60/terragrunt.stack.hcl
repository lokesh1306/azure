locals {
  root = "${get_repo_root()}/units/azure/external"
}

unit "07-infrastructure" {
  source = "${local.root}/07-infrastructure"
  path   = "07-infrastructure"
}

unit "08-apps" {
  source = "${local.root}/08-apps"
  path   = "08-apps"
}
