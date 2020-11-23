# Workshop Infrastructure as Code - Infranets en partenariat avec la Banque Nationale
## Installation Terraform
Pour que Terraform, il faut installer le bon éxécutable
- Télécharger le fichier binaire à partir de ce site : https://www.terraform.io/downloads.html
- Déziper le package
- Déplacer le fichier éxécutable dans le PATH de votre ordinateur
    - Windows : C:\Windows\ (droits administrateurs requis)
    - Linux : \usr\bin (peut varier selon le distro)
- Redémarrer le CLI et essayer la commande ```terraform version```

## Variable
Il y aura quelque variable à changer pour que le script terraform fonctionne. Voir le fichier variable.tf

## Connexion SSH aux instance
Pour se connecter à l'une au l'autre des instance, il faut utiliser le procédure suivante : 

### Avec Putty (Windows)
- Télécharger l'outil puTTY : https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
- En l'ouvrant, sous "Host Name", mettre ```ubuntu@<ip de l'instance>```
- Pour sélectionner le certificat (format .ppk, important), sous ```Connection -> SSH```, cliquer sur ```Auth```
- Sous la section Authentification parameters, cliquer sur ```Browse...``` et sélectionner la clé privé que vous venez de créer (format.ppk)
- Cliquer sur ```Open``` en bas à droite

### Avec l'outil cli ssh
- Le format de la clé privée doit être .PEM
- Faire la commande : ```ssh -i "/path/de/la/cle/prive.pem" ubuntu@<ip de l'instance>``` (format .pem, important)

Exemple : ```ssh -i "./infranets.pem" ubuntu@1.2.3.4```

## Création de votre infrastructure
Vous allez devoir compléter le script afin de faire votre infrastructure. Je vais vous accompagner tout le long du workshop.

### Étape 1 : Paramétrer vos variables

### Étape 2 : Définir les règles du pare-feu
Dans le fichier `main.tf`, vous pouvez configurer le pare-feu dans le bloc `"aws_security_group" "default"`. Il manque deux règles dans ce bloc :
```HCL
ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
```
Ici la règle `ingress` indique quand une communication rentre sur le port `22/tcp` depuis toutes les adresses IP `0.0.0.0/0`. Elle sera authorisée.

### Étape 3 : Ajout des deux instances EC2
Nous allons maintenant créer deux VM EC2. A la fin du fichier `main.tf` ajoutez : 
```HCL
resource "aws_instance" "backs" {
  instance_type          = "t2.micro"
  ami                    = var.aws_ami
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.default.id]
  subnet_id              = aws_subnet.iac_subnet.id
  count                  = 2
  tags = {
    Name = "${var.prefix}_iac_instance_${count.index}"
  }
}
```
Vous remarquerez la présences des option `ami` pour l'image utilisée (Ubuntu 20.04), `key_name` votre clé SSH, `subnet_id` qui correspond à votre réseau privé. Ici on indique `count = 2`, cela permet de créer 2 VM en une seule instruction. Pour accéder au variables des VM nous pourrons faire : `aws_instance.backs.0.ma_var` (remplacer le 0 par 1 pour avoir la deuxième VM).

### Étape 4 : Ajout du Load-Balancer
A la suite de vos VM dans le fichier `main.tf` ajoutez : 
```HCL
resource "aws_elb" "lb" {
  name            = "load-balancer"
  subnets         = [aws_subnet.iac_subnet.id]
  security_groups = [aws_security_group.elb.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  instances                   = aws_instance.backs.*.id
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}
```
Je vous invite à regarder la ligne `instances = aws_instance.backs.*.id`. Cette ligne indique les backends du Load Balancer. C'est sur ces VM que le Load Balancer redirigera le trafic. Le bloc `listener` indique sur quel port le LB écoute (`80`), avec quel protocole il doit écouter et où il doit rediriger (port + protocole). Le bloc `health_check` permet de savoir si les backends sont encore accessibles. Si ce n'est pas le cas, le LB sortira la VM du groupe de VM.

### Étape 5 : Script Ansible
Je vous invite à lire le script Ansible dans `ansible/playbook.yaml`. Si vous ne savez pas comment fonctionne les commandes dans Linux, vous pouvez sauter cette étape.
Pour faire un résumer sur ce script, je mets à jour Ubuntu puis j'ajoute un serveur HTTP Nginx. Et à la fin, j'injecte un fichier HTML pour avoir de quoi à afficher.

### Étape 6 : Lancer Terraform
Pour lancer Terraform, il faut d'abord l'initialiser. Depuis une console, déplacez vous dans le dossier que vous avez cloner puis faites `terraform init`. Cela va ajouter les dépendances requises pour AWS.
Une fois initialiser vous pouvez lancer le test : `terraform plan`. Si vous avez des erreurs vérifier les étapes d'avant. 
Si tout est bon vous pouvez lancer la création de l'infrastructure en faisant : `terraform apply`.
Vous avez créé votre infrastructure 🤗😎😊 Bravo!!!

### Étape 7 : Lancer Ansible
Maintenant vous pouvez lancer Ansible. Pour ce faire, vous devez faire cette commande dans le dossier ansible : `ansible-playbook -i ../inventory playbook.yaml`

### Étape 8 : Tester votre infra
Sur la console AWS allez chercher l'adresse IP de votre Load Balancer. Puis allez sur http://VOTRE_IP_LB/. Si vous avez une page web, bravo 😛 vous avez réussi 😜. Sinon, il est temps de debuguer 😑🙄