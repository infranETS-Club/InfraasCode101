# NE PAS MODIFIER CE FICHIER
resource "local_file" "ansible_inventory" {
    content = templatefile("inventory.tmpl", 
    {
        backs = aws_instance.backs.*.public_ip
        private-dns = aws_instance.backs.*.private_dns
    })
    filename = "inventory"
}