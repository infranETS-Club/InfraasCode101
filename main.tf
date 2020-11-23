# Création d'un subnet privé pour vos VMs et votre LB
resource "aws_subnet" "iac_subnet" {
  vpc_id                  = data.aws_vpc.workshop.id
  cidr_block              = var.subnet_CIDR
  map_public_ip_on_launch = true
  availability_zone       = "ca-central-1a"

  tags = {
    Name = "${var.prefix}_iac_subnet"
  }
}

# Instruction de routage pour le routeur
# On indique que pour toute IPs on redirige vers la Gateway
resource "aws_route_table" "routes" {
  vpc_id = data.aws_vpc.workshop.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.prefix}_iac_routes"
  }
}

# Association de la table de routage avec le subnet
resource "aws_route_table_association" "route_association" {
  subnet_id      = aws_subnet.iac_subnet.id
  route_table_id = aws_route_table.routes.id
}

# Création des règles du Parfeu par Défaut
# On authorise le 80 et 22 en entrant (Internet -> VM)
# Et tout en externe (VM -> Internet)
resource "aws_security_group" "default" {
  name   = "${var.prefix}IaCDefaultFirewall"
  vpc_id = data.aws_vpc.workshop.id

  # TODO Il manque une règle pour le port SSH 22 en entrant (ingress)


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # TODO Il manque une règle pour le trafic sortant (egress)

  tags = {
    Name = "${var.prefix}_iac_sg"
  }
}

# Creation des règles de parfeu pour le LB
# On authorise le 80 en entrant (Internet -> LB)
# On authorise tout en sortant (LB -> Internet)
resource "aws_security_group" "elb" {
  name   = "${var.prefix}IaCLBFirewall"
  vpc_id = data.aws_vpc.workshop.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [data.aws_internet_gateway.gw]
}

resource "aws_lb_cookie_stickiness_policy" "default" {
  name                     = "lbpolicy"
  load_balancer            = aws_elb.lb.id
  lb_port                  = 80
  cookie_expiration_period = 600
}

# TODO Il manque les VMs (appelé instance dans AWS)

# TODO Il manque le Load Balancer
