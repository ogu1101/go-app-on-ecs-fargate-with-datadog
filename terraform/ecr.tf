resource "aws_ecr_repository" "repository" {
  name                 = "${var.env}-ecr-repository"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_iam_policy_document" "ecr" {
  statement {
    sid    = "ECRAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]   
    }

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_ecs_task_definition.task_definition.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_ecr_repository_policy" "repository_policy" {
  repository = aws_ecr_repository.repository.name
  policy     = data.aws_iam_policy_document.ecr.json
}
