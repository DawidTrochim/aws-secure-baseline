# tflint settings. The aws plugin checks things like invalid instance types
# and the terraform plugin checks general style (unused variables, missing types etc.)
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
