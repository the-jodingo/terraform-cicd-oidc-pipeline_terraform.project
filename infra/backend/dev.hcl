bucket         = "REPLACE-WITH-YOUR-STATE-BUCKET"
key            = "cicd/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
