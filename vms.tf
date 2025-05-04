#*************  считываем данные об образе ОС  *************
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

#**********************  Разворачиваем VM бастион  *************************#
resource "yandex_compute_instance" "bastion" {
  name        = "bastion" #Имя ВМ в облачной консоли
  hostname    = "bastion" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init-bastion.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lan_a.id #зона ВМ должна совпадать с зоной subnet!!!
    nat                = true
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.bastion.id]
  }
}

/* #********************  Создаём map серверов  *************************************#
locals {
  web_servers = {
    web_a = { zone = "ru-central1-a", subnet = yandex_vpc_subnet.lan_a.id }
    web_b = { zone = "ru-central1-b", subnet = yandex_vpc_subnet.lan_b.id }
    #web_c = { zone = "ru-central1-a", subnet = yandex_vpc_subnet.lan_a.id }
  }
}

#*******************  Шаблон для всех серверов ***********************************#
resource "yandex_compute_instance" "web" {
  for_each = local.web_servers

  name        = each.key
  hostname    = each.key
  platform_id = "standard-v3"
  zone        = each.value.zone

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      size     = 10
    }
  }

  metadata = {
    user-data = file("./cloud-init-web.yml")
  }

  network_interface {
    subnet_id          = each.value.subnet
    security_group_ids = [yandex_vpc_security_group.LAN.id]
  }

   # Общий provisioner для всех серверов
  provisioner "file" {
    source      = "./vms-payload.yml"
    destination = "/home/pks/vms-payload.yml"
    connection {
      type        = "ssh"
      user        = "pks"
      private_key = file("./vm-cloud-diplom")
      host        = self.network_interface.0.ip_address
      bastion_host = yandex_compute_instance.bastion.network_interface.0.nat_ip_address
    }
  } 
} */

 #**********************  Разворачиваем VMs серверов web a *************************#
resource "yandex_compute_instance" "web_a" {
  name        = "web-a" #Имя ВМ в облачной консоли
  hostname    = "web-a" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!


  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init-web.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lan_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]
  }
}

#**********************  Разворачиваем VMs серверов web b *************************#
resource "yandex_compute_instance" "web_b" {
  name        = "web-b" #Имя ВМ в облачной консоли
  hostname    = "web-b" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-b" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init-web.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lan_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]

  }
}


#**********************  Создаём текстовый файл  *************************#
resource "local_file" "inventory" {
  content  = <<-EOF
  [bastion]
  ${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}

  [webservers]
  ${yandex_compute_instance.web_a.network_interface.0.ip_address}
  ${yandex_compute_instance.web_b.network_interface.0.ip_address}
  [webservers:vars]
  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q pks@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
  EOF
  filename = "./hosts.ini"
}


