# Réseau KVM — NAT CUSTOM

## Référence figée

- Réseau VM : `192.168.50.0/24`
- Interface/passerelle HOST KVM : `192.168.50.254`
- DHCP : `192.168.50.100-192.168.50.200`
- DNS 1 : `9.9.9.9`
- DNS 2 : `1.1.1.1`
- Bridge libvirt prévu : `virbr50`
- Réseau libvirt : `devops-nat`
- Autostart réseau : activé

`192.168.50.0/24` est le réseau **virtuel KVM du projet**, distinct du LAN physique de la workstation. L'hôte y participe via `virbr50` à l'adresse `.254`, ce qui permet HOST↔VM sans exposer les VM au LAN physique.

## Politique

| Flux | Politique |
|---|---|
| VM → Internet | ALLOW |
| VM → DNS publics configurés | ALLOW |
| VM → VM | ALLOW |
| HOST → VM | ALLOW |
| VM → HOST via réseau KVM | ALLOW |
| VM → LAN physique | BLOCK |
| LAN physique → VM | BLOCK |
| Internet → VM | BLOCK |
| Port-forward entrant | désactivé par défaut |

## Principe d'isolation

Le NAT libvirt seul n'est pas considéré comme une preuve suffisante d'isolation vis-à-vis du LAN physique. La phase d'implémentation devra ajouter une politique de filtrage explicite et testée, sans flush global de nftables/iptables et sans perturber le firewall existant de l'hôte.

La politique d'isolation ne devra **pas** coder en dur le sous-réseau du LAN physique. Au PRECHECK, le moteur devra inventorier les routes et interfaces réellement actives de l'hôte, identifier les réseaux directement connectés hors `devops-nat`, détecter tout chevauchement avec `192.168.50.0/24`, puis construire une politique de filtrage minimale. Une ambiguïté ou un chevauchement doit produire `BLOCKED / MANUAL_ACTION_REQUIRED`, jamais une règle approximative.

## DNS

`9.9.9.9` et `1.1.1.1` constituent le contrat DNS voulu pour les VM. Leur mécanisme exact d'application sera choisi pendant l'implémentation après validation du comportement libvirt/dnsmasq sur Ubuntu 26.04. Le XML de squelette ne prétend donc pas, à lui seul, garantir ces upstreams.

## Adressage

- `.1-.99` : hors DHCP et disponibles pour usages futurs contrôlés ; `.1` n'est pas la passerelle.
- `.100-.200` : pool DHCP et autorité d'adressage des VM.
- `.201-.253` : hors DHCP, réserve future.
- `.254` : exclusivement passerelle/interface virtuelle de l'hôte.

Les VM importantes, dont `ubuntu-devops`, recevront une identité MAC déterministe et une réservation DHCP libvirt **dans la plage `.100-.200`**. L'adresse précise sera choisie pendant l'implémentation après contrôle de conflit ; elle n'est pas inventée dans le squelette. On évite ainsi une double autorité entre DHCP et configuration IP statique dans le guest.

## Tests d'isolation futurs

Le PRE-TEST devra utiliser au minimum deux guests contrôlés afin de vérifier séparément VM↔VM et HOST↔VM. Le test VM→LAN doit viser une adresse réellement découverte sur le LAN physique et dont la réponse attendue est connue ; un simple timeout vers une adresse inexistante ne constitue pas une preuve d'isolation. Les tests d'exposition entrante devront vérifier qu'aucune règle DNAT/port-forward inattendue n'expose les guests.

## Postchecks obligatoires futurs

Le module réseau ne pourra être déclaré `SUCCESS` qu'après validation de :

1. interface `virbr50` et adresse `192.168.50.254/24` sur le HOST ;
2. DHCP dans la plage `.100-.200` ;
3. résolution DNS conformément au contrat DNS ;
4. HOST → VM ;
5. VM → HOST ;
6. VM → VM ;
7. VM → Internet ;
8. VM → LAN physique : blocage démontré ;
9. LAN physique/Internet → VM : aucune exposition entrante non explicitement configurée.

## Reprise / rollback futurs

La création du réseau devra être transactionnelle : inventaire et sauvegarde de l'état libvirt/firewall avant action, création/validation de `devops-nat`, puis rollback ciblé uniquement des objets/règles créés par le projet si un postcheck échoue. Le rollback ne doit jamais supprimer ou réinitialiser des règles firewall préexistantes qui n'appartiennent pas au projet.

## Redémarrage et persistance

Le PRE-TEST final devra également démontrer la persistance après redémarrage : `devops-nat` en autostart, `virbr50` recréé correctement avec `.254`, DHCP/DNS fonctionnels, règles d'isolation présentes sans duplication, et VM configurées pour l'autostart uniquement si le profil utilisateur le demande. Le réseau ne sera pas considéré stable sur la seule base d'un test effectué juste après sa création.

## Critère de réussite réseau

Le verdict `KVM NETWORK READY` ne pourra être émis que si **tous** les postchecks ci-dessus réussissent. Un accès Internet fonctionnel ne suffit pas : l'isolation du LAN, la communication HOST↔VM, la stabilité de l'adressage et la persistance font partie du même contrat.

## Ordre de mise en œuvre futur

1. PRECHECK read-only des routes/interfaces/firewall/libvirt.
2. DRY-RUN et plan détaillé.
3. Snapshot logique de l'état pertinent.
4. Définition du réseau libvirt.
5. Application ciblée de l'isolation.
6. Tests de connectivité/isolation.
7. Vérification d'idempotence.
8. Test de persistance/reboot en environnement de pré-test.
9. Seulement ensuite, éligibilité au verdict `KVM NETWORK READY`.

## Limite actuelle du squelette

La configuration décrit le **résultat attendu**, pas encore l'implémentation. En particulier, le choix précis du mécanisme de filtrage compatible avec le firewall Ubuntu 26.04 et la manière de forcer/valider les upstreams DNS seront décidés après pré-test technique. Cette décision évite de figer aujourd'hui une commande firewall ou dnsmasq qui pourrait entrer en conflit avec la pile réellement présente sur l'hôte.

## Contrat figé vs décisions d'implémentation

**Figé :** CIDR, `.254`, plage DHCP, DNS souhaités, HOST↔VM, VM↔VM, Internet par NAT, blocage du LAN physique, absence de forwarding entrant, autostart, réservations DHCP déterministes et critères de validation.

**À décider par pré-test :** mécanisme exact de filtrage persistant, intégration au firewall existant et mécanisme exact d'enforcement des deux DNS. Ces choix techniques ne pourront pas réduire les garanties du contrat figé.

## Principe fail-closed

Si le moteur ne peut pas déterminer de manière fiable le LAN physique, détecte un chevauchement, ne peut pas préserver le firewall existant, ou ne peut pas démontrer le blocage VM→LAN, le résultat doit être `BLOCKED` et non un réseau partiellement configuré présenté comme sain.

## Gate de sécurité

Ce document et le XML sont déclaratifs. Aucun réseau n'est créé ou modifié tant que `REAL_MACHINE_APPROVED=false` et que le pré-test n'est pas validé.
