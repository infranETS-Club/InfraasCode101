# Workshop Infrastructure as Code - InfranETS en partenariat avec la Banque Nationale
## Conseil
Pour faciliter le tout, je vous conseil d'utiliser VS Code pour ouvrir les fichiers. Il y existe même une extension terraform si vous voulez avoir des couleurs.

## Installer Terraform
Pour que Terraform, il faut installer le bon exécutable
- Télécharger le fichier binaire à partir de ce site : https://www.terraform.io/downloads.html
- Dézipper le package
- Déplacer le fichier exécutable dans le PATH de votre ordinateur
  - Windows : C:\Windows\ (droits administrateur requis)
  - Linux : /usr/bin (peut varier selon le distro)
- Redémarrer le CLI (cmd) et essayer la commande ```terraform version```

## Installer Ansible
Malheureusement, le CLI de Ansible n’est pas tout à fait compatible pour Windows. Ainsi, il faudra utiliser une distro de Linux pour exécuter la commande. Si vous avez seulement un ordinateur Windows, vous pouvez facilement utiliser le Windows subsystem Linux (WSL) pour faire cela (voir [ici](https://ubuntu.com/tutorials/ubuntu-on-windows) pour savoir comment faire). 

Pour installer Ansible, utiliser votre disto préféré de Linux et suivre les étapes décrites sur ce site : https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html

Pour vérifier que tout fonctionne bien, faire la commande ```ansible-playbook --version```
### Important
Pour que le playbook d’Ansible fonctionne bien, il faut absolument que vous exécutiez Terraform et Ansible dans la même arborescence puisque Terraform "donne" des informations à Ansible pour bien fonctionner.

## Identifiants AWS (credentials)
Pour que terraform utilise facilement les credentials d'AWS, faites comme suit :

- Créer un dossier `.aws` au root de votre user
  - Windows : `cd %userprofile%`
  - Linux : `cd ~/`
- Créer 2 fichiers sans extension : ```credentials``` et ```config```
- Ajouter ce qui suit dans les fichiers et les modifier avec les informations du courriel

credentials
```HCL
[default]
aws_access_key_id = votre_key_id
aws_secret_access_key = votre_access_key
```

config
```HCL
[default]
region = ca-central-1
output = json
```

Ainsi, Terraform devrait automatiquement utiliser cette configuration d'identifiants.

## Ajout d'un clé privée
Pour que Ansible / Terraform fonctionne correctement, il faut avoir une clé SSH privé. Pour ce faire, suivre cette procédure : 
- Télécharger une key pair au format .pem (important!) à partir de la console d'AWS
- Si vous utiliser un Windows, premièrement copier la clé dans votre répertoire personnel de Linux (```cp nomDeLaCle.pem ~/```)
- Changer les permissions de la clé pour qu'elle respecte les règles d'AWS : ```chmod 700 nomDeLaCle.pem```
- Retenir le path de la clé, vous en aurez besoin pour Ansible plus tard

## Création de votre infrastructure
Vous allez devoir compléter le script afin de faire votre infrastructure. Nous allons vous accompagner tout le long du workshop.

### Étape 1 : Paramétrer vos variables
Voir le fichier ```variable.tf```

Pour le ```subnet_CIDR```, il faudra utiliser le sous-réseau avec le numéro que l’on vous a donné. Par exemple, si votre numéro est le 17, votre sous-réseau sera ```172.31.17.0/24```

Pour la ```key name```, s’arrurer d’utiliser le même nom que vous avez entré dans la console d’AWS

Pour le préfix, mettre la première chose qui vous passe par la tête, en un mot 😅

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
Ici la règle `ingress` indique quand une communication rentre sur le port `22/tcp` depuis toutes les adresses IP `0.0.0.0/0`. Elle sera donc autorisée.

### Étape 3 : Ajout des deux instances EC2
Nous allons maintenant créer deux VM EC2. À la fin du fichier `main.tf` ajoutez : 
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
Vous remarquerez la présence des options `ami` pour l’image utilisée (Ubuntu 20.04), `key_name` votre clé SSH, `subnet_id` qui correspond à votre réseau privé. Ici on indique `count = 2`, cela permet de créer 2 VM en une seule instruction. Pour accéder aux variables des VM, nous pourrons faire : `aws_instance.backs.0.la_var` (remplacer le 0 par 1 pour avoir la deuxième VM).

### Étape 4 : Ajout du Load-Balancer
À la suite de vos VM dans le fichier `main.tf` ajoutez : 
```HCL
resource "aws_elb" "lb" {
  name            = "${var.prefix}-load-balancer"
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
Je vous invite à regarder la ligne `instances = aws_instance.backs.*.id`. Cette ligne indique tous les backends du Load Balancer. C’est sur ces VM que le Load Balancer redirigera le trafic. Le bloc `listener` indique sur quel port le LB écoute (`80`), avec quel protocole il doit écouter et où il doit rediriger (port + protocole). Le bloc `health_check` permet de savoir si les backends sont encore accessibles. Si ce n’est pas le cas, le LB sortira la VM du groupe de VM.

### Étape 5 : Script Ansible
Je vous invite à lire le script Ansible dans `ansible/playbook.yaml`. Si vous ne savez pas comment fonctionnent les commandes dans Linux, vous pouvez sauter cette étape.
Pour faire un résumé de ce script, il met à jour Ubuntu puis ajoute un serveur HTTP Nginx. À la fin, il injecte un fichier HTML pour avoir de quoi à afficher.

### Étape 6 : Lancer Terraform
Pour lancer Terraform, il faut d’abord l’initialiser. Depuis une console, déplacez-vous dans le dossier que vous avez cloné puis faites `terraform init`. Cela va ajouter les dépendances requises pour AWS.
Une fois initialiser vous pouvez lancer le test : `terraform plan`. Si vous avez des erreurs, vérifiez les étapes d’avant. 
Si tout est bon vous pouvez lancer la création de l’infrastructure en faisant : `terraform apply`.
Vous avez créé votre infrastructure 🤗😎😊 Bravo!!!

### Étape 7 : Lancer Ansible
Maintenant vous pouvez lancer Ansible. Pour ce faire, vous devez faire cette commande dans le dossier ansible : `ansible-playbook -i ../inventory playbook.yaml --private-key /chemin/vers/la/cle/privee`

### Étape 8 : Tester votre infra
Sur la console AWS, allez chercher l’adresse IP de votre Load Balancer. Puis allez sur http://VOTRE_IP_LB/. Si vous avez une page web, bravo 😛 vous avez réussi 😜. Sinon, il est temps de déboguer 😑🙄

### destroy

## Connexion SSH aux instances
Cette étape n'est pas nécessaire pour le workshop. Elle peut par contre être utile pour déboguer ou pour essayer de pousser un peu plus loin.

Pour se connecter à l’une au l’autre des instances, il faut utiliser la procédure suivante : 

### Avec Putty (Windows)
- Télécharger l’outil puTTY : https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
- En l’ouvrant, sous "Host Name", mettre ```ubuntu@<ip de l’instance>```
- Pour sélectionner le certificat, sous ```Connection -> SSH```, cliquer sur ```Auth```
- Sous la section Authentification parameters, cliquer sur ```Browse...``` et sélectionner la clé privée que vous venez de créer (format .ppk, important)
    - Pour convertir une clé privé .pem et .ppk, suivre cette procédure : https://aws.amazon.com/premiumsupport/knowledge-center/convert-pem-file-into-ppk/
- Cliquer sur ```Open``` en bas à droite

### Avec l’outil cli SSH
- Le format de la clé privée doit être .PEM
- Faire la commande : ```ssh — i "/chemin/de/la/cle/prive.pem" ubuntu@<ip de l’instance>``` (format .pem, important)

Exemple : ```ssh -i "./infranets.pem" ubuntu@1.2.3.4```
