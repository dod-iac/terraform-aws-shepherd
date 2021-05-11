#
# Assume Role
#
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

#
# Shepherd Users
#

data "aws_iam_policy_document" "shepherd_users_s3" {
  // Allow all actions against athena results bucket
  statement {
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:Put*",
    ]
    resources = [
      module.athena_results.arn,
      "${module.athena_results.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  // Allow limited actions against akamai buckets
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketRequestPayment",
      "s3:GetEncryptionConfiguration",
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = flatten([for bucket in var.subscriber_buckets : [
      format("arn:%s:s3:::%s", data.aws_partition.current.partition, bucket),
      format("arn:%s:s3:::%s/*", data.aws_partition.current.partition, bucket),
      ]
    ])
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

data "aws_iam_policy_document" "shepherd_users_athena" {

  statement {
    actions = [
      "athena:ListWorkGroups",
    ]
    effect    = "Allow"
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  // Allow full access to athena against the workgroup
  statement {
    actions = [
      "athena:BatchGet*",
      "athena:CreateNamedQuery",
      "athena:Get*",
      "athena:List*",
      "athena:StartQueryExecution",
      "athena:StopQueryExecution",
      "athena:TagResource",
      "athena:UpdateWorkGroup",
    ]
    effect    = "Allow"
    resources = aws_athena_workgroup.shepherd[*].arn
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project]
    }
  }

  // Allow full access to athena against the datacatalog
  statement {
    actions = [
      "athena:GetDataCatalog",
      "athena:GetDatabase",
      "athena:GetTableMetadata",
      "athena:ListDatabases",
      "athena:ListDatabases",
      "athena:ListTableMetadata",
      "athena:ListTagsForResource",
    ]
    effect = "Allow"
    resources = [
      format("arn:%s:athena:%s:%s:datacatalog/%s",
        data.aws_partition.current.partition,
        data.aws_region.current.name,
        data.aws_caller_identity.current.account_id,
        "AwsDataCatalog"
      ),
    ]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project]
    }
  }
}

data "aws_iam_policy_document" "shepherd_users_glue" {

  statement {
    effect = "Allow"
    actions = [
      "glue:BatchCreatePartition",
      "glue:BatchDeletePartition",
      "glue:BatchDeleteTable",
      "glue:BatchDeleteTableVersion",
      "glue:CreateTable",
      "glue:DeleteTable",
      "glue:DeleteTableVersion",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetTableVersion",
      "glue:UpdatePartition",
      "glue:UpdateTable",
    ]
    resources = flatten([
      [format("arn:%s:glue:%s:%s:catalog",
        data.aws_partition.current.partition,
        data.aws_region.current.name,
      data.aws_caller_identity.current.account_id)],
      aws_glue_catalog_database.shepherd[*].arn,
      [for bucket in var.subscriber_buckets : [
        format("arn:%s:glue:%s:%s:table/%s/*",
          data.aws_partition.current.partition,
          data.aws_region.current.name,
          data.aws_caller_identity.current.account_id,
          replace(replace(format("%s-%s", local.glue_database_name_prefix, bucket), "-", "_"), ".", "_"),
        )
      ]],
    ])
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

data "aws_iam_policy_document" "shepherd_users_other" {

  // Allow decrypt of all AWS resources using AWS managed KMS keys
  statement {
    effect = "Allow"
    actions = [
      "kms:ListAliases",
      "kms:Decrypt",
    ]
    resources = ["*"] // This should apply only to AWS KMS keys where the principal can be `*`.
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "quicksight:*",
    ]
    resources = [
      "*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:DescribeParameters",
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter*",
      "ssm:PutParameter",
    ]
    resources = [
      format("arn:%s:ssm:%s:%s:parameter/%s-%s/*",
        data.aws_partition.current.partition,
        data.aws_region.current.name,
        data.aws_caller_identity.current.account_id,
        var.project,
        var.environment,
      ),
    ]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "tag:*",
    ]
    resources = [
      "*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "shepherd_users_s3" {
  name        = "app-${var.project}-${var.environment}-s3"
  description = "Policy for 'shepherd_users' s3 access"
  policy      = jsonencode(jsondecode(data.aws_iam_policy_document.shepherd_users_s3.json))
}

resource "aws_iam_policy" "shepherd_users_athena" {
  name        = "app-${var.project}-${var.environment}-athena"
  description = "Policy for 'shepherd_users' athena access"
  policy      = jsonencode(jsondecode(data.aws_iam_policy_document.shepherd_users_athena.json))
}

resource "aws_iam_policy" "shepherd_users_glue" {
  name        = "app-${var.project}-${var.environment}-glue"
  description = "Policy for 'shepherd_users' glue access"
  policy      = jsonencode(jsondecode(data.aws_iam_policy_document.shepherd_users_glue.json))
}

resource "aws_iam_policy" "shepherd_users_other" {
  name        = "app-${var.project}-${var.environment}-other"
  description = "Policy for 'shepherd_users' other access"
  policy      = jsonencode(jsondecode(data.aws_iam_policy_document.shepherd_users_other.json))
}

resource "aws_iam_role_policy_attachment" "shepherd_users_policy_attachment_s3" {
  role       = aws_iam_role.shepherd_users.name
  policy_arn = aws_iam_policy.shepherd_users_s3.arn
}

resource "aws_iam_role_policy_attachment" "shepherd_users_policy_attachment_athena" {
  role       = aws_iam_role.shepherd_users.name
  policy_arn = aws_iam_policy.shepherd_users_athena.arn
}

resource "aws_iam_role_policy_attachment" "shepherd_users_policy_attachment_glue" {
  role       = aws_iam_role.shepherd_users.name
  policy_arn = aws_iam_policy.shepherd_users_glue.arn
}

resource "aws_iam_role_policy_attachment" "shepherd_users_policy_attachment_other" {
  role       = aws_iam_role.shepherd_users.name
  policy_arn = aws_iam_policy.shepherd_users_other.arn
}

#
# Shepherd Engineers
#

data "aws_iam_policy_document" "shepherd_engineers" {

  // Terraform State Lock
  statement {
    sid = "TerraformStateLockAccess"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    effect = "Allow"
    resources = [
      format("arn:%s:dynamodb:%s:%s:table/dds-shepherd-govcloud-terraform-state-lock",
        data.aws_partition.current.partition,
        data.aws_region.current.name,
      data.aws_caller_identity.current.account_id),
    ]
  }

  // Allow all actions against athena results bucket
  statement {
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "athena:*",
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "glue:*",
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
  // Allow Get* List* for IAM permissions  
  statement {
    effect = "Allow"
    actions = [
      "iam:Get*",
      "iam:List*",
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  // Allow decrypt of all AWS resources using AWS managed KMS keys
  statement {
    effect = "Allow"
    actions = [
      "kms:ListAliases",
      "kms:Decrypt",
    ]
    resources = ["*"] // This should apply only to AWS KMS keys where the principal can be `*`.
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "quicksight:*",
    ]
    resources = [
      "*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:*",
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "tag:*",
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "shepherd_engineers" {
  name        = "app-${var.project}-${var.environment}-engineers"
  description = "Policy for 'shepherd_engineers' access"
  policy      = jsonencode(jsondecode(data.aws_iam_policy_document.shepherd_engineers.json))
}

resource "aws_iam_role_policy_attachment" "shepherd_engineers_policy_attachment" {
  role       = aws_iam_role.shepherd_engineers.name
  policy_arn = aws_iam_policy.shepherd_engineers.arn
}


#
# Allow group to assume role
#

# Allow assuming the "shepherd_users" role
data "aws_iam_policy_document" "assume_role_shepherd_users_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.shepherd_users.arn]
  }
}

resource "aws_iam_policy" "assume_role_shepherd_users_policy" {
  name        = "app-${var.project}-${var.environment}-users-assume-role"
  path        = "/"
  description = "Allows the 'shepherd_users' role to be assumed."
  policy      = data.aws_iam_policy_document.assume_role_shepherd_users_policy_doc.json
}

resource "aws_iam_group_policy_attachment" "shepherd_users_assume_role_policy_attachment" {
  group      = aws_iam_group.shepherd_users.name
  policy_arn = aws_iam_policy.assume_role_shepherd_users_policy.arn
}

# Allow assuming the "shepherd_engineers" role
data "aws_iam_policy_document" "assume_role_shepherd_engineers_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.shepherd_engineers.arn]
  }
}

resource "aws_iam_policy" "assume_role_shepherd_engineers_policy" {
  name        = "app-${var.project}-${var.environment}-engineers-assume-role"
  path        = "/"
  description = "Allows the 'shepherd_engineers' role to be assumed."
  policy      = data.aws_iam_policy_document.assume_role_shepherd_engineers_policy_doc.json
}

resource "aws_iam_group_policy_attachment" "shepherd_engineers_assume_role_policy_attachment" {
  group      = aws_iam_group.shepherd_engineers.name
  policy_arn = aws_iam_policy.assume_role_shepherd_engineers_policy.arn
}
