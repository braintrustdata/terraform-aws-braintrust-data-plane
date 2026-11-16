locals {
  brainstore_init_scripts = merge(
    { reader = local.reader_init_script },
    local.has_writer_nodes ? { writer = local.writer_init_script } : {},
    local.has_fast_reader_nodes ? { fast_reader = local.fast_reader_init_script } : {},
    local.has_automation_writer_nodes ? { automation_writer = local.automation_writer_init_script } : {},
  )
}

# Keep EC2 and ASG ownership in Terraform. These stacks only store cfn-init
# metadata; the handle is an anchor, with no wait condition or signal required.
# One stack per pool keeps the inline template limit independent of pool count.
resource "aws_cloudformation_stack" "brainstore_init" {
  for_each = local.brainstore_init_scripts

  # Immutable metadata prevents a booting instance from fetching a different
  # script than its launch template intended. A script/secret-version change
  # changes the stack ID in user data and preserves launch-template rollouts.
  name = "${var.deployment_name}-brainstore-init-${replace(each.key, "_", "-")}-${substr(sha256(each.value), 0, 16)}"
  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Resources = {
      BrainstoreInit = {
        Type = "AWS::CloudFormation::WaitConditionHandle"
        Metadata = {
          "AWS::CloudFormation::Init" = {
            config = {
              files = {
                "/opt/braintrust/bootstrap.sh" = {
                  content = each.value
                  mode    = "000700"
                  owner   = "root"
                  group   = "root"
                }
              }
              commands = {
                bootstrap = {
                  command = "/bin/bash /opt/braintrust/bootstrap.sh"
                }
              }
            }
          }
        }
      }
    }
  })

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}
