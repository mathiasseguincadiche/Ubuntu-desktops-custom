# Runbook VM_DEVOPS — ubuntu-devops

Ce document couvre l'exploitation de la VM Ubuntu Server 26.04 LTS `ubuntu-devops` et de sa pile DevOps/DevSecOps.

## 1. État de la VM

```bash
virsh -c qemu:///system domstate ubuntu-devops
virsh -c qemu:///system dominfo ubuntu-devops
virsh -c qemu:///system domifaddr ubuntu-devops
```

## 2. Démarrage et arrêt

```bash
virsh -c qemu:///system start ubuntu-devops
virsh -c qemu:///system shutdown ubuntu-devops
```

`destroy` est réservé au dernier recours.

## 3. Connexion SSH

```bash
ssh ubuntu@<IP_VM>
```

Pour VS Code, utiliser Remote - SSH avec la même identité et travailler dans le filesystem Linux de la VM.

## 4. Santé Ubuntu

Dans la VM :

```bash
cat /etc/os-release
systemctl --failed
journalctl -b -p warning..alert
cloud-init status --long
```

La release attendue est Ubuntu Server 26.04 LTS.

## 5. Validation de la pile DevOps

```bash
git --version
terraform version
ansible --version
docker --version
docker buildx version
docker compose version
kubectl version --client
helm version --short
kind version
aws --version
az version
```

## 6. Validation DevSecOps

```bash
gitleaks version
trivy --version
shellcheck --version
hadolint --version
checkov --version
```

## 7. Docker

```bash
systemctl status docker --no-pager
docker info
docker run --rm hello-world
```

Si Docker échoue, diagnostiquer le service, le stockage et les logs avant toute réinstallation.

## 8. Kubernetes lab

`kubectl`, Helm et kind sont des outils client/lab de la VM.

```bash
kubectl version --client
helm version --short
kind version
kind get clusters
```

La présence de ces outils ne signifie pas qu'un cluster doit être actif en permanence.

## 9. Cloud CLIs

```bash
aws --version
az version
```

Les credentials AWS/Azure ne doivent jamais être committés dans le dépôt. Utiliser les mécanismes d'authentification runtime appropriés.

## 10. IaC

```bash
terraform version
ansible --version
ansible-lint --version
```

Avant une opération Terraform destructive, inspecter systématiquement le plan. Pour Ansible, privilégier les playbooks idempotents et les modes de contrôle disponibles.

## 11. Réseau

Depuis la VM :

```bash
ip addr
ip route
getent hosts github.com
dig @9.9.9.9 github.com A +short
dig @1.1.1.1 github.com A +short
```

Le contrat impose Internet et DNS fonctionnels, mais bloque l'accès initié vers le LAN physique.

## 12. Reboot et persistance

```bash
sudo reboot
```

Après retour SSH, revalider au minimum :

```bash
docker --version
terraform version
cloud-init status
```

## 13. Incident de provisioning

En cas d'échec de création, conserver les logs et vérifier le rollback ciblé du domaine, de la réservation DHCP et du disque nouvellement créé avant toute nouvelle tentative.

## 14. Principe de séparation

Ne pas installer Docker, Terraform, Ansible, Kubernetes ou les Cloud CLIs sur le HOST pour contourner un problème dans la VM. Corriger la VM ou son provisioning.
