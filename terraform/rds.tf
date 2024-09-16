resource "aws_rds_cluster" "cluster" {
  cluster_identifier     = "${var.env}-rds-cluster"
  availability_zones     = ["${var.region}a", "${var.region}c", "${var.region}d"]
  engine                 = "aurora-mysql"
  engine_mode            = "provisioned"
  engine_version         = "8.0.mysql_aurora.3.07.0"
  database_name          = "recordings"
  master_username        = "root"
  master_password        = "example-password"
  storage_encrypted      = true
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.id
  vpc_security_group_ids = [aws_security_group.rds.id]

  serverlessv2_scaling_configuration {
    max_capacity = 2.0
    min_capacity = 1.0
  }
}

resource "aws_rds_cluster_instance" "cluster_instance" {
  count                = 3
  identifier           = "${var.env}-rds-cluster-instance-${count.index}"
  cluster_identifier   = aws_rds_cluster.cluster.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.cluster.engine
  engine_version       = aws_rds_cluster.cluster.engine_version
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.id

  monitoring_interval  = 60
  monitoring_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/rds-monitoring-role"
  performance_insights_enabled = true
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.env}-db-subnet-group"
  subnet_ids = [aws_subnet.rds_az_a.id, aws_subnet.rds_az_c.id, aws_subnet.rds_az_d.id]
}
