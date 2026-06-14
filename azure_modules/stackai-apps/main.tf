locals {
  storage_name_base = replace(lower(var.environment), "-", "")
}
