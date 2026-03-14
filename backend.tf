terraform {
  backend "s3" {
    bucket = "sctp-ce12-tfstate-bucket"
    key    = "kuankm-rds.tfstate"
    region = "ap-southeast-1"
  }
}