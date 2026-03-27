# Region must be one of: us-east-1, us-east-2, us-west-2, eu-west-1, ca-central-1, ap-southeast-2
# ARNs: https://docs.aws.amazon.com/systems-manager/latest/userguide/ps-integration-lambda-extensions.html#ps-integration-lambda-extensions-add
locals {
  secrets_ext_arns_arm64 = {
    us-east-1 = {
      arn     = "arn:aws:lambda:us-east-1:177933569100:layer:AWS-Parameters-and-Secrets-Lambda-Extension-Arm64"
      version = 61
    }
    us-east-2 = {
      arn     = "arn:aws:lambda:us-east-2:590474943231:layer:AWS-Parameters-and-Secrets-Lambda-Extension-Arm64"
      version = 67
    }
    us-west-2 = {
      arn     = "arn:aws:lambda:us-west-2:345057560386:layer:AWS-Parameters-and-Secrets-Lambda-Extension-Arm64"
      version = 61
    }
    eu-west-1 = {
      arn     = "arn:aws:lambda:eu-west-1:015030872274:layer:AWS-Parameters-and-Secrets-Lambda-Extension-Arm64"
      version = 63
    }
    ca-central-1 = {
      arn     = "arn:aws:lambda:ca-central-1:200266452380:layer:AWS-Parameters-and-Secrets-Lambda-Extension-Arm64"
      version = 62
    }
    ap-southeast-2 = {
      arn     = "arn:aws:lambda:ap-southeast-2:665172237481:layer:AWS-Parameters-and-Secrets-Lambda-Extension-Arm64"
      version = 63
    }
  }

  secrets_ext_arns_x86_64 = {
    us-east-1 = {
      arn     = "arn:aws:lambda:us-east-1:177933569100:layer:AWS-Parameters-and-Secrets-Lambda-Extension"
      version = 67
    }
    us-east-2 = {
      arn     = "arn:aws:lambda:us-east-2:590474943231:layer:AWS-Parameters-and-Secrets-Lambda-Extension"
      version = 73
    }
    us-west-2 = {
      arn     = "arn:aws:lambda:us-west-2:345057560386:layer:AWS-Parameters-and-Secrets-Lambda-Extension"
      version = 67
    }
    eu-west-1 = {
      arn     = "arn:aws:lambda:eu-west-1:015030872274:layer:AWS-Parameters-and-Secrets-Lambda-Extension"
      version = 63
    }
    ca-central-1 = {
      arn     = "arn:aws:lambda:ca-central-1:200266452380:layer:AWS-Parameters-and-Secrets-Lambda-Extension"
      version = 70
    }
    ap-southeast-2 = {
      arn     = "arn:aws:lambda:ap-southeast-2:665172237481:layer:AWS-Parameters-and-Secrets-Lambda-Extension"
      version = 63
    }
  }
}

data "aws_lambda_layer_version" "aws_params_secrets_arm64" {
  layer_name = local.secrets_ext_arns_arm64[data.aws_region.current.id].arn
  version    = local.secrets_ext_arns_arm64[data.aws_region.current.id].version
}

data "aws_lambda_layer_version" "aws_params_secrets_x86_64" {
  layer_name = local.secrets_ext_arns_x86_64[data.aws_region.current.id].arn
  version    = local.secrets_ext_arns_x86_64[data.aws_region.current.id].version
}

#-----------------------------------------------------
# TODO: relocate layer to `dist` and add to postbuild
#-----------------------------------------------------

data "archive_file" "secrets_wrapper_layer" {
  type        = "zip"
  source_dir  = "${path.module}/secrets-wrapper"
  output_path = "${path.module}/.build/wrapper_layer.zip"
}

resource "aws_lambda_layer_version" "secrets_wrapper" {
  layer_name          = "secrets-env-wrapper"
  description         = "Exec wrapper that fetches Secrets Manager secrets and injects them as environment variables."
  filename            = data.archive_file.secrets_wrapper_layer.output_path
  source_code_hash    = data.archive_file.secrets_wrapper_layer.output_base64sha256
  compatible_runtimes = ["nodejs22.x", "python3.13"]

  compatible_architectures = ["arm64", "x86_64"]
}
