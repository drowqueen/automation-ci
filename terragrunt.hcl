# Root terragrunt.hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "terragrunt-state-drq"  # Replace with your S3 bucket name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"                   # Match your AWS region
    dynamodb_table = "my-terragrunt-locks"         # Optional: For state locking
  }
}

terraform {
  extra_arguments "vars" {
    commands = ["apply", "plan"]
    arguments = [
      "-lock-timeout=300s"
    ]
  }
}
