#*************** ALB Target Group для веб-серверов ***********#
resource "yandex_alb_target_group" "web_servers" {
  name           = "web-servers-tg-${var.flow}"
  description    = "Целевая группа для web серверов"
  target {
    subnet_id    = yandex_vpc_subnet.lan_a.id
    ip_address   = yandex_compute_instance.web_a.network_interface.0.ip_address
  }
  target {
    subnet_id    = yandex_vpc_subnet.lan_b.id
    ip_address   = yandex_compute_instance.web_b.network_interface.0.ip_address
  }
}

#*************** ALB Backend Group ****************************#
resource "yandex_alb_backend_group" "web_backend" {
  name           = "web-backend-${var.flow}"
  description    = "Группа бэкендов"

  http_backend {
    name             = "web-backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_alb_target_group.web_servers.id]
    
    healthcheck {
      timeout             = "3s"
      interval            = "2s"
      healthy_threshold   = 4
      unhealthy_threshold = 6
      http_healthcheck {
        path              = "/"
      }
    }
  }
}

#***************  HTTP Router ********************************#
resource "yandex_alb_http_router" "web_router" {
  name          = "web-router-${var.flow}"
}

#***************  Virtual Host  ******************************#
resource "yandex_alb_virtual_host" "web_virtual_host" {
  name           = "web-virtual-host-${var.flow}"
  http_router_id = yandex_alb_http_router.web_router.id
  
  route {
    name = "web-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_backend.id
      }
    }
  }
}

#**************  Application Load Balancer  ***********************#
resource "yandex_alb_load_balancer" "web_balancer" {
  name               = "web-balancer-${var.flow}"
  network_id         = yandex_vpc_network.develop.id
  security_group_ids = [yandex_vpc_security_group.web_sg.id]

  # Размещается в 2-х зонах
  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.lan_a.id
    }
    location {
      zone_id   = "ru-central1-b"
      subnet_id = yandex_vpc_subnet.lan_b.id
    }
  }

  listener {
    name = "web-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web_router.id
      }
    }
  }
} 