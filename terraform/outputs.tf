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