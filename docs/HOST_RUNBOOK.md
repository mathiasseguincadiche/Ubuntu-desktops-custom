# Runbook HOST — Ubuntu Desktop 26.04 LTS

Ce document couvre l'exploitation du HOST physique uniquement. La pile DevOps doit rester dans `ubuntu-devops`.

## 1. Contrôle initial

```bash
./diagnostic.sh
```

Ne pas poursuivre si le diagnostic contient un KO. Vérifier notamment Ubuntu 26.04, EXT4, AMD-V/SVM, `/dev/kvm`, Intel Arc, routes, stockage et gates de sécurité.

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

## 6. Desktop et applications

Le HOST contient les applications desktop définies par le projet, notamment VS Code, navigateur, gestionnaire de mots de passe, bureautique, multimédia, Remote Desktop et outils graphiques. Les outils DevOps lourds restent dans la VM.

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
