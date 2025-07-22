#!/bin/bash

# Script d'installation de Centreon
# Auteur : Garance Defrel
# Date : 30/04/2025
# Version : 1.0

# Vérification root
if [ "$EUID" -ne 0 ]; then
    echo "[ERREUR] Ce script doit être exécuté en tant que root."
    exit 1
fi

read -sp "Entrez le mot de passe MySQL pour l'utilisateur CENTREON : " MYSQL_PASS

# Paramètres prédéfinis
SURY_URL=https://packages.sury.org/php/
SURY_URL_KEY=https://packages.sury.org/php/apt.gpg
MARIADB_URL=https://r.mariadb.com/downloads/mariadb_repo_setup
CENTREON_URL=https://packages.centreon.com/apt-standard-24.10-stable/
CENTREON_PLUGIN_URL=https://packages.centreon.com/apt-plugins-stable/
CENTREON_URL_KEY=https://apt-key.centreon.com

function update_system(){
    # Mise à jour du système
    echo "[INFO] Mise à jour du système en cours..."
    if apt update && apt upgrade -y; then
        echo "[OK] Mise à jour du système réussie !"
    else
        echo "[ERREUR] Echec de la mise à jour du système."
        exit 1
    fi 
}

# Fonction : Installation des dépendances
function install_dependencies(){
    # Installation des dépendances
    echo "[INFO] Installation des dépendances..."
    if apt install -y lsb-release ca-certificates apt-ransport-https software-properties-common wget gnupg2 curl; then
        echo "[OK] Installation des dépendances réussie !"
    else
        echo "[ERREUR] Echec de l'installation des dépendances."
        exit 1
    fi
}

# Fonction : Ajout des dépôts
function add_repositories(){
    echo "[INFO] Ajout des dépôts nécessaires..."
    # Ajout du dépôt Sury pour PHP
    if echo "deb $SURY_URL $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list; then
        echo "[OK] Dépôt Sury ajouté avec succès !"
    else
        echo "[ERREUR] Echec de l'ajout du dépôt Sury."
        exit 1
    fi
    # Ajout de la clé GPG du dépôt Sury
    if wget -O- $SURY_URL_KEY | gpg --dearmor | tee /etc/apt/trusted.gpg.d/php.gpg > /dev/null 2>&1; then
        echo "[OK] Clé GPG du dépôt Sury ajoutée avec succès !"
    else
        echo "[ERREUR] Echec de l'ajout de la clé GPG du dépôt Sury."
        exit 1
    fi
    # Ajout du dépôt MariaDB
    if curl -LsS $MARIADB_URL |sudo bash -s -- --os-type=debian --os-version=12 --mariadb-server-version="mariadb-10.11"; then
        echo "[OK] Dépôt MariaDB ajouté avec succès !"
    else
        echo "[ERREUR] Echec de l'ajout du dépôt MariaDB."
        exit 1
    fi
    # Ajout du dépôt principal Centreon
    if echo "deb $CENTREON_URL $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/centreon.list; then
        echo "[OK] Dépôt principal Centreon ajouté avec succès !"
    else
        echo "[ERREUR] Echec de l'ajout du dépôt principal Centreon."
        exit 1
    fi
    # Ajout du dépôt des plugins Centreon
    if echo "deb $CENTREON_PLUGIN_URL $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/centreon-plugins.list; then
        echo "[OK] Dépôt des plugins Centreon ajouté avec succès !"
    else
        echo "[ERREUR] Echec de l'ajout du dépôt des plugins Centreon."
        exit 1
    fi
    # Ajout de la clé GPG du dépôt Centreon
    if wget -O- $CENTREON_URL_KEY | gpg --dearmor | tee /etc/apt/trusted.gpg.d/centreon.gpg > /dev/null 2>&1; then
        echo "[OK] Clé GPG du dépôt Centreon ajoutée avec succès !"
    else
        echo "[ERREUR] Echec de l'ajout de la clé GPG du dépôt Centreon."
        exit 1
    fi
}

# Fonction : Installation de Centreon
function install_centreon(){
    # Installation de Centreon
    echo "[INFO] Installation de Centreon..."
    if apt install -y centreon-mariadb centreon; then
        echo "[OK] Installation de Centreon réussie !"
    else
        echo "[ERREUR] Echec de l'installation de Centreon."
        exit 1
    fi

    # Redémarrage des services système
    echo "[INFO] Redémarrage des services système..."
    if systemctl daemon-reload && systemctl restart mariadb; then
        echo "[OK] Services système redémarrés avec succès !"
    else
        echo "[ERREUR] Echec du redémarrage des services système."
        exit 1
    fi
}

# Fonction : Sécurisation de MariaDB
function secure_mariaDB(){
    echo "[INFO] Sécurisation de MariaDB..."
    if mysql_secure_installation <<EOF
Y
Y
$MYSQL_PASS
$MYSQL_PASS
Y
n
Y
Y
EOF
    then
        echo "[OK] MariaDB sécurisée."
    else
        echo "[ERREUR] La sécurisation de MariaDB a échoué."
        exit 1
    fi
}

# Fonction : Activation des services 
function enable_services(){
    #Activation des services Centreon
    echo "[INFO] Activation des services Centreon..."
    if systemctl enable php8.2-fpm apache2 centreon cbd centengine gorgoned centreontrapd snmpd snmptrapd; then
        echo "[OK] Services Centreon activés avec succès !"
    else
        echo "[ERREUR] Echec de l'activation des services Centreon."
        exit 1
    fi
    # Activation du service MariaDB
    echo "[INFO] Activation du service MariaDB..."
    if systemctl enable mariadb; then
        echo "[OK] Service MariaDB activé avec succès !"
    else
        echo "[ERREUR] Echec de l'activation du service MariaDB."
        exit 1
    fi
    # Démarrage des services
    echo "[INFO] Démarrage des services..."
    if systemctl start apache2; then
        echo "[OK] Services démarrés avec succès !"
    else
        echo "[ERREUR] Echec du démarrage des services."
        exit 1
    fi
    # Vérification du statut des services
    echo "[INFO] Vérification du statut des services..."
    if systemctl status apache2 centengine mariadb; then
        echo "[OK] Services en cours d'exécution !"
    else
        echo "[ERREUR] Echec de la vérification du statut des services."
        exit 1
    fi
}

# Installation complète
function full_install(){
    update_system
    install_dependencies
    add_repositories
    install_centreon
    secure_mariaDB
    enable_services
}

# Menu interactif
function interactive_menu() {
    while true; do
        echo
        read -n1 -p "Menu : [1] MAJ, [2] DEPENDENCIES, [3] REPOSITORIES, [4] CENTREON, [5] MARIADB, [6] SERVICES, [7] INSTALLATION COMPLETE, [q] Quitter : " choice
        echo
        case $choice in
            1) update_system ;;
            2) install_dependencies ;;
            3) add_repositories ;;
            4) install_centreon ;;
            5) secure_mariaDB ;;
            6) enable_services ;;
            7) full_install ;;
            [qQ]) echo "Fin du script." ; break ;;
            *) echo "[ERREUR] Option invalide." ;;
        esac
    done
}

# Lancement
if [[ "$1" == "--auto" ]]; then
    full_install_glpi
else
    interactive_menu
fi