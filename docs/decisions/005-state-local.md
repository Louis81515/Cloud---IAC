# ADR 005 — State Terraform local

## Contexte

Le cluster est créé dans un projet GCP de lab, éphémère : le projet et son contenu sont supprimés
en fin de session. Une seule personne conduit Terraform à la fois.

## Décision

Le state Terraform est **local** (`terraform/terraform.tfstate`), non versionné. En revanche,
`.terraform.lock.hcl` est versionné : il fige les versions exactes des providers et leurs
empreintes, ce qui garantit que le poste Windows et Cloud Shell téléchargent les mêmes binaires.

## Conséquences

- Aucune ressource cloud supplémentaire à créer (pas de bucket) : la session démarre plus vite et
  il n'y a rien à détruire en plus du cluster.
- **Perdre le state, c'est perdre le lien avec l'infrastructure** : un `terraform destroy` ne sait
  plus quoi supprimer. Dans le lab, le projet est de toute façon supprimé à la fin.
- **Pas de verrou** : deux `apply` simultanés corrompent le state. Règle d'équipe : un seul
  opérateur Terraform à la fois, annoncé dans le canal de l'équipe.
- Le state n'est pas partagé entre postes : il faut piloter Terraform depuis la machine qui le
  détient (ou copier le fichier hors de Git).

## Alternatives écartées

- **Backend GCS + verrouillage** : c'est la cible en entreprise (un bucket par projet, un préfixe
  par environnement), mais cela ajoute une ressource à créer et à détruire à chaque session, pour
  aucun bénéfice dans un lab d'une heure.
- **Terraform Cloud** : dépendance externe et compte à configurer, hors périmètre.
