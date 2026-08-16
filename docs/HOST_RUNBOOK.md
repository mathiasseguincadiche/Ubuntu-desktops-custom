# Runbook HOST — Ubuntu Desktop 26.04 LTS

Ce document couvre l'exploitation du HOST physique uniquement. La pile DevOps doit rester dans `ubuntu-devops`.

## 1. Contrôle initial

```bash
./diagnostic.sh
```

Ne pas poursuivre si le diagnostic contient un KO. Vérifier notamment Ubuntu 26.04, EXT4, AMD-V/SVM, `/dev/kvm`, Intel Arc, routes, stockage et gates de sécurité.

Le diagnostic produit également un inventaire en lecture seule des applications suivies par le projet à travers APT/DEB, Snap et Flatpak. Le rapport `reports/<RUN_ID>-app-packaging-inventory.txt` indique pour chaque application la source préférée, la ou les sources déjà installées, la provenance attendue lorsqu'elle est vérifiable, et un état `CONFORMING`, `PLANNED`, `PRESERVED`, `DRIFT` ou `DUPLICATE`. Pour `vendor-apt`, la provenance du paquet installé est contrôlée contre le dépôt éditeur attendu. Pour Flatpak, le remote attendu est contrôlé. Aucun paquet n'est installé, supprimé, rafraîchi ou migré par cet inventaire.

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
snap list vlc
```

Vérifier la lecture matérielle avant toute modification de codec ou de backend graphique.

## 6. Desktop, applications et politique de packaging

Le HOST contient les applications desktop définies par le projet, notamment VS Code, navigateur, gestionnaire de mots de passe, bureautique, multimédia, Remote Desktop et outils graphiques. Les outils DevOps lourds restent dans la VM.

La référence exécutable est `manifests/host/app-packaging-policy.conf`. Le choix est fait application par application selon l'ordre suivant : source officielle upstream, recommandation explicite de l'éditeur, fonctionnalités disponibles, version stable maintenue, intégration Ubuntu/GNOME/Wayland, sécurité/isolation et maintenance automatisable.

Politique retenue :

- **APT éditeur signé** : Firefox et Thunderbird via `packages.mozilla.org`, VS Code via Microsoft, Brave via Brave, ONLYOFFICE via ONLYOFFICE, Steam via le dépôt stable Valve ;
- **Flatpak Flathub upstream** : Bitwarden Desktop, OBS Studio et GNOME Extension Manager ;
- **Snap éditeur** : VLC, afin que VideoLAN distribue directement les versions majeures stables et correctifs associés ;
- **APT Ubuntu** : LibreOffice, FileZilla, PDF Arranger, Remmina, Ghostwriter, Ptyxis et Xournal++ lorsque le paquet Resolute est la meilleure option native disponible ;
- **DEB éditeur vérifié** : draw.io, téléchargé depuis la release officielle avec contrôle SHA-256.

Cas particuliers documentés :

- LibreOffice recommande en règle générale la méthode de la distribution Linux pour l'intégration optimale ;
- Remmina fournit un PPA, mais il ne publie pas de suite Resolute ; le Snap a en outre des limitations d'accès et d'intégration, donc le paquet Ubuntu natif est retenu ;
- Ghostwriter documente un PPA upstream, mais ce PPA ne publie pas Resolute tandis qu'Ubuntu 26.04 contient une release upstream récente ;
- OBS recommande le PPA sur Ubuntu lorsqu'il existe pour la série cible, mais son PPA stable ne publie actuellement pas Resolute ; le Flatpak officiel est donc retenu plutôt qu'un paquet Ubuntu plus ancien ;
- Bitwarden n'a pas un format Linux possédant simultanément chaque fonctionnalité. Flatpak est retenu pour mises à jour automatiques, biométrie, intégration navigateur et isolation ; le Direct Importer reste spécifique à AppImage.

Une application déjà installée via un autre gestionnaire ou une mauvaise provenance est signalée `DRIFT`. Plusieurs sources donnent `DUPLICATE`. Les installateurs du projet refusent les migrations cross-manager sensibles au lieu de supprimer automatiquement Firefox, Thunderbird, VLC, OBS, Extension Manager ou Steam. Le nettoyage/migration est décidé explicitement après lecture de l'inventaire.

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
dpkg-query -W steam-launcher
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
