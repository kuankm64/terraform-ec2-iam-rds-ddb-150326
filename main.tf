#############################################################
############## VPC & NETWORKING RESOURCES ###################
#############################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16.0"

  name                               = "kuankm_rds_vpc"
  cidr                               = "172.31.0.0/16"
  azs                                = data.aws_availability_zones.available.names
  public_subnets                     = ["172.31.101.0/24", "172.31.102.0/24"]
  private_subnets                    = ["172.31.1.0/24", "172.31.2.0/24"]
  database_subnets                   = ["172.31.201.0/24", "172.31.202.0/24"]
  create_database_subnet_route_table = true
  enable_nat_gateway                 = true
  single_nat_gateway                 = true
}

resource "aws_security_group" "ec2_sg" {
  name_prefix = "kuankm-ec2-sg"
  description = "EC2 SG"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "ec2_sg_allow_all_traffic" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "kuankm-rds-sg"
  description = "RDS SG"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "sql" {
  security_group_id            = aws_security_group.rds_sg.id
  referenced_security_group_id = aws_security_group.ec2_sg.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}

#############################################################
#################### EC2 RESOURCES ##########################
#############################################################
resource "aws_instance" "private_ec2" {
  ami                    = data.aws_ami.amazon2023.id
  instance_type          = "t2.micro"
  subnet_id              = flatten(module.vpc.private_subnets)[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name = "kuankm-rds-ec2"
  }
}

resource "aws_iam_role" "instance" {
  name               = "kuankm-ssm-rds-instance-role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "kuankm-ssm-rds-profile"
  role = aws_iam_role.instance.name
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#############################################################
#################### RDS RESOURCES ##########################
#############################################################
resource "aws_db_instance" "default" {
  allocated_storage           = 20
  identifier                  = "kuankm-rds-mysqldb"
  engine                      = "mysql"
  engine_version              = "8.0"
  instance_class              = "db.t4g.micro"
  manage_master_user_password = true
  username                    = "admin"
  port                        = 3306
  db_subnet_group_name        = module.vpc.database_subnet_group_name
  vpc_security_group_ids      = [aws_security_group.rds_sg.id]
  skip_final_snapshot         = true
}

#############################################################
#################### DYNAMODB RESOURCES #####################
#############################################################
import {
  to = aws_dynamodb_table.books
  id = "kuankm-bookinventory"
}
resource "aws_dynamodb_table" "books" {
  name           = "kuankm-bookinventory"
  billing_mode   = "PAY_PER_REQUEST"
  
  # Partition Key
  hash_key       = "ISBN"
  # Sort Key (Range Key)
  range_key      = "Genre"

  attribute {
    name = "ISBN"
    type = "S"
  }

  attribute {
    name = "Genre"
    type = "S"
  }

  tags = {
    Name = "kuankm-bookinventory"
  }
}
resource "aws_iam_role_policy" "dynamo_access" {
  name = "kuankm-dynamodb-access-policy"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.books.arn
      }
    ]
  })
}
