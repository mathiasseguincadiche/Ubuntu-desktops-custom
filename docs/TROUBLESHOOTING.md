# Troubleshooting — Ubuntu-desktops-custom V1.0.0

Ce guide sert à isoler les incidents sans contourner les gates du projet.

## 1. Méthode générale

Toujours commencer par collecter l'état avant de modifier quoi que ce soit :

```bash
./diagnostic.sh
systemctl --failed
journalctl -b -p warning..alert
```

Conserver `logs/`, `reports/` et `state/` avant correction.

## 2. Diagnostic global en KO

- relire le check en échec ;
- ne pas lancer `--apply` ;
- vérifier si le défaut concerne HOST, KVM, VM_DEVOPS ou BACKUP ;
- corriger la cause racine puis relancer `./diagnostic.sh` et `./install.sh --dry-run`.

## 3. `/dev/kvm` absent

```bash
grep -Ewo 'svm|vmx' /proc/cpuinfo | sort -u
lsmod | grep kvm
ls -l /dev/kvm
```

Sur AMD, vérifier SVM/AMD-V dans l'UEFI. Ne pas masquer l'absence de KVM par une configuration différente du contrat HOST.

## 4. Intel Arc / Vulkan

```bash
lspci -nnk | grep -A3 -Ei 'vga|display'
vulkaninfo --summary
journalctl -k -b | grep -Ei 'xe|i915|drm|firmware'
```

Vérifier kernel, firmware et Mesa avant d'ajouter un dépôt graphique tiers.

## 5. `devops-nat` absent ou inactif

```bash
virsh -c qemu:///system net-list --all
virsh -c qemu:///system net-info devops-nat
ip addr show virbr50
```

Ne jamais exécuter `nft flush ruleset`. Le projet doit uniquement gérer sa table nftables propriétaire.

## 6. VM sans Internet

Dans la VM :

```bash
ip route
getent hosts github.com
curl -I https://github.com
dig @9.9.9.9 github.com A +short
dig @1.1.1.1 github.com A +short
```

Sur le HOST, vérifier `devops-nat`, le bridge et le forwarding géré par libvirt avant de toucher au firewall.

## 7. VM accède au LAN physique alors qu'elle ne devrait pas

C'est un incident de sécurité. Arrêter la phase concernée et vérifier immédiatement la table nftables propriétaire du projet et les routes locales détectées. Ne pas considérer la plateforme READY tant que le blocage LAN n'est pas rétabli.

## 8. SSH vers ubuntu-devops impossible

```bash
virsh -c qemu:///system domstate ubuntu-devops
virsh -c qemu:///system domifaddr ubuntu-devops
virsh -c qemu:///system domiflist ubuntu-devops
```

Puis vérifier la clé, l'adresse DHCP réservée et `sshd` dans la VM via console si nécessaire.

## 9. cloud-init en erreur

Dans la VM :

```bash
cloud-init status --long
sudo journalctl -u cloud-init -u cloud-final --no-pager
sudo tail -n 200 /var/log/cloud-init-output.log
```

Corriger le template ou l'entrée runtime plutôt que modifier manuellement la VM si le problème est reproductible.

## 10. Docker en erreur

```bash
systemctl status docker --no-pager
journalctl -u docker -b --no-pager
docker info
```

Ne pas réinstaller Docker sur le HOST pour contourner le problème VM.

## 11. Terraform / Ansible / Kubernetes CLI absents

```bash
command -v terraform ansible kubectl helm kind
terraform version
ansible --version
kubectl version --client
helm version --short
kind version
```

Relancer le provisioning prévu par le projet après diagnostic, pas une installation ad hoc non versionnée.

## 12. Cloud CLI en erreur

```bash
aws --version
az version
```

Distinguer un problème d'installation d'un problème d'authentification. Les credentials restent runtime et ne doivent jamais entrer dans Git.

## 13. DevSecOps en erreur

```bash
gitleaks version
trivy --version
hadolint --version
shellcheck --version
checkov --version
```

Si un téléchargement échoue, vérifier d'abord la release upstream et son checksum plutôt que désactiver la vérification d'intégrité.

## 14. Backup Restic échoue

```bash
restic snapshots
restic check --read-data
```

Vérifier la cible externe, les secrets runtime et l'espace disponible. Ne pas lancer de prune après un backup non vérifié.

## 15. QCOW2 suspect

VM arrêtée :

```bash
qemu-img check /chemin/disque.qcow2
qemu-img info /chemin/disque.qcow2
```

Ne pas supprimer ni écraser le disque avant d'avoir une copie/restauration vérifiée.

## 16. Échec d'APPLY

- arrêter la chaîne dépendante ;
- conserver logs et état ;
- vérifier le rollback automatique ;
- ne pas contourner `run_mutating` ou les gates ;
- corriger, relancer diagnostic et dry-run, puis seulement recommencer.

## 17. Après correction

La résolution est terminée uniquement lorsque les contrôles concernés repassent au vert et que le diagnostic global ne contient plus de KO.
