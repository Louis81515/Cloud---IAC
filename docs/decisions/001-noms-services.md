# ADR 001 — Noms de Services Redis figés

## Contexte

Le frontend PHP résout le leader et les followers **par leur nom de Service** : dans
`guestbook.php`, l'hôte est `redis-leader` pour les écritures et `redis-follower` pour les
lectures, tant que `GET_HOSTS_FROM` vaut `dns`. Le script de démarrage des followers fait de même
(`redis-server --replicaof redis-leader 6379`).

Le mode `GET_HOSTS_FROM=env` existe dans le code : il lit alors `REDIS_LEADER_SERVICE_HOST` et
`REDIS_FOLLOWER_SERVICE_HOST`.

## Décision

Les Services Redis portent **exactement** les noms `redis-leader` et `redis-follower`, définis
dans `values.yaml` (`redisLeader.service.name`, `redisFollower.service.name`) et non préfixés par
le nom de la release. Les pods et les Deployments portent aussi ces noms, pour que les commandes
de diagnostic et les runbooks restent identiques d'un environnement à l'autre.

L'isolation entre environnements est assurée par les **namespaces**, pas par le préfixe de nom :
`redis-leader` dans `dev` et `redis-leader` dans `prod` sont deux Services distincts.

## Conséquences

- Les images officielles fonctionnent sans modification, en mode `dns`.
- Les commandes (`kubectl exec deploy/redis-leader`, `kubectl get svc frontend`) sont stables.
- Limite : on ne peut pas installer deux releases du chart dans le **même** namespace (collision
  de noms). Ce cas ne se produit pas dans le projet (une release par namespace).
- Les noms ne sont pas dérivés de `guestbook.fullname` ; c'est une exception assumée à la règle
  « les noms viennent des helpers ».

## Alternatives écartées

- **Préfixer les noms avec `{{ include "guestbook.fullname" . }}`** : le frontend ne résoudrait
  plus `redis-leader` et l'application afficherait une erreur de connexion, sans erreur visible
  dans `kubectl get pods`.
- **Passer en `GET_HOSTS_FROM=env` et injecter les noms templatés** : fonctionne, mais ajoute
  trois variables à synchroniser image ↔ chart, et une valeur oubliée produit le même échec
  silencieux. Le gain est nul puisque les namespaces isolent déjà.
