terraform {
  backend "s3" {
    bucket = "vaishnavi-b75"
    key    = "expense-project/prod/terraform.tfstate"
    region = "us-east-1"  # Specify your desired AWS region here
    }  
}

