#******  создаем облачную сеть FailOver Network  ********#
resource "yandex_vpc_network" "develop" {
  name = "develop-fo-net-${var.flow}"
}

#*************  создаем подсеть lan zone a  *************#
resource "yandex_vpc_subnet" "lan_a" {
  name           = "develop-fo-${var.flow}-lan-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["10.0.1.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

#*************  создаем подсеть lan zone b  *************#
resource "yandex_vpc_subnet" "lan_b" {
  name           = "develop-fo-${var.flow}-lan-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["10.0.2.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
}

#********  создаем NAT для выхода в интернет  ***********#
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "fo-gateway-${var.flow}"
  shared_egress_gateway {}
}

#*  создаем сетевой маршрут для выхода в интернет через NAT  *#
resource "yandex_vpc_route_table" "rt" {
  name       = "fo-route-table-${var.flow}"
  network_id = yandex_vpc_network.develop.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

#********  создаем группы безопасности(firewall)  ************#
resource "yandex_vpc_security_group" "bastion" {
  name        = "bastion-sg-${var.flow}"
  description = "Файервол bastion"
  network_id  = yandex_vpc_network.develop.id

  ingress {
    description    = "Allow 0.0.0.0/0"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

#*******  создаем группы безопасности(firewall)  ************#
resource "yandex_vpc_security_group" "zabbix" {
  name        = "zabbix-sg-${var.flow}"
  description = "Файервол zabbix"
  network_id  = yandex_vpc_network.develop.id

  ingress {
    description    = "Allow HTTPS"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    description    = "Allow HTTP"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

/*   ingress {
    description    = "Allow 0.0.0.0/0"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
 */
  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

}

#*************  правила файрвола для LAN  *************#
resource "yandex_vpc_security_group" "LAN" {
  name = "LAN-sg-${var.flow}"
  network_id = yandex_vpc_network.develop.id

# Правила для входящего трафика
  ingress {
    description    = "Allow 10.0.0.0/8"
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.0.0/8"]
    from_port      = 0
    to_port        = 65535
  }
# Правило для исходящего трафика
  egress {
    description    = "Permit ANY"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

#*************  правила файрвола для веб-серверов  *************
resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-sg-${var.flow}"
  network_id = yandex_vpc_network.develop.id

# Правила для входящего трафика
  ingress {
    description    = "Allow HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description    = "Allow HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  # Правило для health check от балансировщика
  ingress {
    description    = "Allow health check from load balancer"
    protocol       = "TCP"
    from_port      = 0
    to_port        = 65535
    #v4_cidr_blocks = ["198.18.235.0/24", "198.18.248.0/24"]
    #v4_cidr_blocks = ["0.0.0.0/0"]
    predefined_target = "loadbalancer_healthchecks" # [198.18.235.0/24, 198.18.248.0/24]
  }
}