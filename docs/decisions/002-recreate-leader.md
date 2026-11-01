# ADR 002 — `Recreate` sur le leader, `RollingUpdate` ailleurs

## Contexte

Les données Redis vivent sur un PVC en `ReadWriteOnce` monté sur `/data`. Un volume RWO ne peut
être monté que par un seul nœud à la fois. Or un `RollingUpdate` démarre le nouveau pod **avant**
d'arrêter l'ancien.

## Décision

- `redis-leader` : `strategy.type: Recreate`. L'ancien pod est arrêté avant que le nouveau ne
  démarre.
- `frontend` et `redis-follower` : `RollingUpdate`. Ils ne montent pas de volume, ils peuvent
  tourner à deux versions pendant quelques secondes.
- Dans les manifestes bruts `k8s/`, le frontend précise `maxSurge: 2` et `maxUnavailable: 1`
  (au moins la moitié des réplicas reste disponible pendant la mise à jour).

## Conséquences

- Pendant la mise à jour du leader, les écritures sont indisponibles quelques dizaines de secondes.
  Les lectures continuent (followers).
- Sur GKE, le disque persistant doit être détaché du nœud puis réattaché au nouveau : compter
  1 à 2 minutes avant que le pod soit `Ready`. Ce délai est normal, pas une erreur.
- Aucun `Multi-Attach error` et aucun risque de deux Redis écrivant le même volume.

## Alternatives écartées

- **`RollingUpdate` sur le leader** : les deux pods demandent le même volume RWO ; sur un cluster
  multi-nœuds, le second reste bloqué en `ContainerCreating`/`Multi-Attach`, et sur un seul nœud
  les deux processus écrivent dans `/data` en même temps.
- **`ReadWriteMany`** (`NFS`/Filestore) : permettrait deux pods, mais Redis n'est pas conçu pour
  deux écrivains sur le même répertoire, et le coût d'un partage de fichiers sur GKE n'est pas
  justifié ici.
- **Un Redis par pod avec réplication applicative** : hors périmètre, remplacerait le leader par
  une architecture Sentinel/cluster (voir les limites du README).
