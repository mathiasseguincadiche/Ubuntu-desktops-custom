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

Avant l'ouverture du runtime réel, un second inventaire read-only `reports/<RUN_ID>-preapply-app-packaging-inventory.txt` est obligatoire. Le gate exige strictement `drift=0` et `duplicates=0`. Une application absente mais planifiée (`PLANNED`) est autorisée, car l'APPLY doit précisément l'installer. En revanche, un ancien Snap, Flatpak, DEB/APT ou une mauvaise provenance pour une application gérée bloque l'APPLY **avant la première mutation**. Le projet ne crée donc jamais volontairement un second exemplaire par-dessus un paquet incompatible.

Après la phase HOST, `reports/<RUN_ID>-posthost-app-packaging-inventory.txt` doit afficher `planned=0`, `drift=0` et `duplicates=0`. Toute divergence arrête l'orchestration avant KVM/VM. Ce contrôle est complémentaire des postchecks de chaque module.

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

Le HOST contient les applications desktop définies par le projet, notamment VS Code, navigateurs, gestionnaire de mots de passe, Proton Mail, bureautique, multimédia, Remote Desktop et outils graphiques. Les outils DevOps lourds restent dans la VM.

La référence exécutable est `manifests/host/app-packaging-policy.conf`. Le choix est fait application par application selon l'ordre suivant : source officielle upstream, recommandation explicite de l'éditeur, fonctionnalités disponibles, version stable maintenue, intégration Ubuntu/GNOME/Wayland, sécurité/isolation et maintenance automatisable.

Politique retenue :

- **APT éditeur signé** : Firefox via `packages.mozilla.org`, VS Code via Microsoft, Brave via Brave, ONLYOFFICE via ONLYOFFICE, Steam via le dépôt stable Valve ;
- **DEB éditeur vérifié** : Proton Mail via le DEB Linux officiel Proton avec sélection de la dernière release `Stable` et contrôle SHA-512 ; draw.io via la release officielle avec contrôle SHA-256 ;
- **Flatpak Flathub upstream** : Bitwarden Desktop, OBS Studio et GNOME Extension Manager ;
- **Snap éditeur** : VLC, afin que VideoLAN distribue directement les versions majeures stables et correctifs associés ;
- **APT Ubuntu** : LibreOffice, FileZilla, Remmina, Ghostwriter, Ptyxis et Xournal++ lorsque le paquet Resolute est la meilleure option native disponible.

Applications explicitement retirées du desired state :

- **Thunderbird** : remplacé par Proton Mail. L'APPLY retire le paquet/application s'il est présent en APT, Snap ou Flatpak et préserve les données utilisateur gérées hors paquet ;
- **PDF Arranger** : retiré du poste et de la policy de packaging ; les variantes APT/Snap/Flatpak détectables sont retirées ;
- **DuckDuckGo** : aucune extension, aucun moteur de recherche forcé et aucun navigateur tiers ne sont gérés par le projet. Une ancienne policy DuckDuckGo créée par une version précédente du dépôt est retirée sans toucher aux autres réglages navigateur.

Cas particuliers documentés :

- LibreOffice recommande en règle générale la méthode de la distribution Linux pour l'intégration optimale ;
- Remmina fournit un PPA, mais il ne publie pas de suite Resolute ; le Snap a en outre des limitations d'accès et d'intégration, donc le paquet Ubuntu natif est retenu ;
- Ghostwriter documente un PPA upstream, mais ce PPA ne publie pas Resolute tandis qu'Ubuntu 26.04 contient une release upstream récente ;
- OBS recommande le PPA sur Ubuntu lorsqu'il existe pour la série cible, mais son PPA stable ne publie actuellement pas Resolute ; le Flatpak officiel est donc retenu plutôt qu'un paquet Ubuntu plus ancien ;
- Bitwarden n'a pas un format Linux possédant simultanément chaque fonctionnalité. Flatpak est retenu pour mises à jour automatiques, biométrie, intégration navigateur et isolation ; le Direct Importer reste spécifique à AppImage ;
- Proton Mail Linux reste présenté comme bêta par Proton, mais Proton publie des releases Linux marquées `Stable` dans son manifeste de mise à jour. Le projet ne sélectionne que cette catégorie et vérifie le SHA-512 avant installation.

Une application déjà installée via un autre gestionnaire ou une mauvaise provenance est signalée `DRIFT`. Plusieurs sources donnent `DUPLICATE`. Ces deux états sont désormais des **blockers globaux du REAL APPLY avant toute mutation**. Le nettoyage/migration doit donc être explicite et contrôlé ; aucun installateur n'est autorisé à empiler silencieusement le format préféré sur une installation incompatible. Après HOST, toute application encore `PLANNED`, `DRIFT` ou `DUPLICATE` fait échouer le post-gate global.

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

Le HOST est considéré prêt uniquement après validation de ses contrats et du diagnostic global. Une panne HOST doit bloquer les phases KVM/VM dépendantes plutôt que d'être contournée. Pour le packaging applicatif, le contrat de sortie HOST est strict : `planned=0`, `drift=0`, `duplicates=0`.
