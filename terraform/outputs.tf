output "bastion_wan_ip" {
  value = yandex_compute_instance.bastion.network_interface.0.nat_ip_address
}
output "bastion_lan_ip" {
  value = yandex_compute_instance.bastion.network_interface.0.ip_address
}
output "web_a_lan_ip" {
  value = yandex_compute_instance.web_a.network_interface.0.ip_address
}
output "web_b_lan_ip" {
  value = yandex_compute_instance.web_b.network_interface.0.ip_address
}
output "zabbix_lan_ip" {
  value = yandex_compute_instance.zabbix.network_interface.0.ip_address
}
output "zabbix_wan_ip" {
  value = yandex_compute_instance.zabbix.network_interface.0.nat_ip_address
}
output "elastic_lan_ip" {
  value = yandex_compute_instance.elastic.network_interface.0.ip_address
}

output "bastion_name" {
  value = yandex_compute_instance.bastion.name
}
output "zabbix_name" {
  value = yandex_compute_instance.zabbix.name
}
output "web_a_name" {
  value = yandex_compute_instance.web_a.name
}
output "web_b_name" {
  value = yandex_compute_instance.web_b.name
}
output "elastic_name" {
  value = yandex_compute_instance.elastic.name
}

output "vm_username" {
  value = var.vm_username
}