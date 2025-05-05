variable "flow" {
    type = string
    default = "diplom"
}

variable "cloud_id" {
    #name = "organization-politiko-ks"
    type = string
    default = "b1gsr925rdnh4d4obuqu"
}

variable "folder_id" {
    #name = "diplom-pks"
    type = string
    default = "b1g1nvf8fhbl914bbl81"
}

variable "bastion" {
    type = map(number)
    default = {
        cores = 2
        memory = 1
        core_fraction = 20
    }
}
