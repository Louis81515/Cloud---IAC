# ADR 003 — Persistance Redis sur un PVC, avec journal append-only

## Contexte

L'application telle que fournie par le tutoriel ne persiste rien : un redémarrage du pod vide la
base. C'est exactement le problème que le client veut résoudre.

## Décision

1. Un **PersistentVolumeClaim** `redis-leader-pvc` est monté sur `/data` dans le conteneur du
   leader. Taille et mode d'accès sont des valeurs (`persistence.size`, `persistence.accessMode`).
2. `redis.conf` (ConfigMap) définit `dir /data` et `appendonly yes` avec `appendfsync everysec`,
   plus des snapshots RDB (`save 900 1`, `save 300 10`, `save 60 10000`).
3. `storageClass` vaut `""` dans `values.yaml`, ce qui doit signifier **classe par défaut**. Le
   template doit donc **omettre** le champ `storageClassName` quand la valeur est vide :

   ```yaml
   {{- if .Values.redisLeader.persistence.storageClass }}
   storageClassName: {{ .Values.redisLeader.persistence.storageClass | quote }}
   {{- end }}
   ```
4. Le conteneur Redis est lancé avec `redis-server /usr/local/etc/redis/redis.conf`, le fichier
   étant fourni par le ConfigMap monté en lecture seule.

## Conséquences

- Un pod leader supprimé est recréé et Redis rejoue le journal : les messages reviennent.
- En cas de coupure brutale, la perte maximale est d'environ une seconde d'écritures
  (`appendfsync everysec`).
- Le volume est lié à la zone du cluster ; sur Autopilot, la classe `standard-rwo` provisionne un
  disque persistant dans la zone du nœud.
- Le volume n'est **pas** conservé lors d'un `helm uninstall` (pas d'annotation `keep`) : la
  désinstallation d'une release perd les données de cet environnement.

## Alternatives écartées

- **RDB seul** : perte de toutes les écritures depuis le dernier snapshot (plusieurs minutes).
- **`emptyDir`** : persiste pendant la vie du pod, perdu au redémarrage — c'est le comportement du
  prototype, inacceptable ici.
- **Écrire `storageClassName: ""` en dur** : ce n'est pas « classe par défaut » mais « aucune
  classe », et le PVC reste `Pending`. C'est le piège que le template évite.
- **Volume NFS / Filestore** : surdimensionné pour un fichier Redis, et ne résout pas le problème
  du seul écrivain.
