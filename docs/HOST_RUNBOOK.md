# Runbook HOST — Ubuntu Desktop 26.04 LTS

Ce document couvre l'exploitation du HOST physique uniquement. La pile DevOps doit rester dans `ubuntu-devops`.

## 1. Contrôle initial

```bash
./diagnostic.sh
```

Ne pas poursuivre si le diagnostic contient un KO. Vérifier notamment Ubuntu 26.04, EXT4, AMD-V/SVM, `/dev/kvm`, Intel Arc, routes, stockage et gates de sécurité.

Le diagnostic produit également un inventaire en lecture seule des applications suivies par le projet à travers APT/DEB, Snap et Flatpak. Le rapport `reports/<RUN_ID>-app-packaging-inventory.txt` indique pour chaque application la source préférée, la ou les sources déjà installées et un état `CONFORMING`, `PLANNED`, `PRESERVED`, `DRIFT` ou `DUPLICATE`. Aucun paquet n'est installé, supprimé, rafraîchi ou migré par cet inventaire.

## 2. Mise à jour contrôlée

```bash
git pull --ff-only
./diagnostic.sh
./install.sh --dry-run
```

Un APPLY réel n'est autorisé qu'après backup Restic externe vérifié sur le même commit.

## 3. Matériel et firmware

Contrôles utiles :

```bash
lscpu
lspci -nnk
lsblk -f
findmnt /
fwupdmgr get-devices
fwupdmgr get-updates
```

Pour la virtualisation AMD :

```bash
grep -Ewo 'svm|vmx' /proc/cpuinfo | sort -u
ls -l /dev/kvm
```

## 4. Intel Arc B580

Contrôler le pilote et Vulkan :

```bash
lspci -nnk | grep -A3 -Ei 'vga|display'
vulkaninfo --summary
vainfo
```

Ne pas installer de pile graphique tierce non prévue par le projet pour contourner un défaut. Diagnostiquer d'abord kernel, firmware, Mesa et paquet VA-API.

## 5. Audio, vidéo et codecs

Contrôles :

```bash
pactl info
ffmpeg -version
vainfo
```

Vérifier la lecture matérielle avant toute modification de codec ou de backend graphique.

## 6. Desktop, applications et politique de packaging

Le HOST contient les applications desktop définies par le projet, notamment VS Code, navigateur, gestionnaire de mots de passe, bureautique, multimédia, Remote Desktop et outils graphiques. Les outils DevOps lourds restent dans la VM.

La source d'installation n'est pas choisie avec une règle unique « Snap partout ». La référence exécutable est `manifests/host/app-packaging-policy.conf` et suit ces principes :

- **APT Ubuntu** pour les composants système, codecs, outils d'intégration GNOME et applications dont le paquet Ubuntu 26.04 fournit une base adaptée et reproductible ;
- **APT éditeur signé** pour VS Code et Brave, afin d'utiliser les dépôts natifs officiels de Microsoft et Brave ;
- **Snap préinstallé par Ubuntu** conservé pour les applications de base que le projet ne cherche pas à migrer, notamment Firefox et Thunderbird ;
- **Flatpak** pour Bitwarden et ONLYOFFICE Desktop Editors, comme applications desktop éditeur-supportées isolées du système ;
- **DEB éditeur vérifié** pour draw.io, téléchargé depuis la release officielle avec contrôle SHA-256.

Une application déjà installée dans la source attendue est laissée en place/convergée idempotemment. Une application présente via une autre source est signalée `DRIFT`. Plusieurs sources pour la même application sont signalées `DUPLICATE`. Ces situations sont à examiner avant l'APPLY mais ne provoquent aucune suppression automatique.

## 7. Terminal et shell

Point de référence : Ptyxis + Bash. Contrôles :

```bash
bash --version
printf '%s\n' "$SHELL"
ssh -V
```

Conserver les personnalisations shell idempotentes et versionnées lorsqu'elles appartiennent au projet.

## 8. Gaming

Contrôles principaux :

```bash
steam --version || true
gamemoded -t || true
vulkaninfo --summary
```

VRR, XeSS et les fonctions frame-generation dépendent également du jeu, du runtime et du pilote. Ne pas considérer ces fonctions comme un simple switch système global.

## 9. Journaux et diagnostic

```bash
journalctl -b -p warning..alert
journalctl -k -b
systemctl --failed
```

Conserver les rapports du projet dans `reports/` et les logs dans `logs/` avant correction.

## 10. Validation HOST

Le HOST est considéré prêt uniquement après validation de ses contrats et du diagnostic global. Une panne HOST doit bloquer les phases KVM/VM dépendantes plutôt que d'être contournée.
