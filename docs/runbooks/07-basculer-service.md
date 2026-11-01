# Runbook 7 — Basculer le frontend entre `ClusterIP` et `LoadBalancer`

**Quand** : phase de test sur GKE (on n'expose rien), ouverture au public, ou fermeture d'un
environnement.

## Vers `ClusterIP` (fermer l'accès public)

```bash
helm upgrade stack-<env> helm/guestbook -n <env> \
  -f helm/guestbook/values-<env>.yaml \
  --set frontend.service.type=ClusterIP

kubectl get svc frontend -n <env>        # TYPE ClusterIP, pas d'EXTERNAL-IP

# accès de test sans exposer le Service
kubectl port-forward svc/frontend 8080:8080 -n <env>
```

## Vers `LoadBalancer` (ouvrir l'accès public)

```bash
helm upgrade stack-<env> helm/guestbook -n <env> \
  -f helm/guestbook/values-<env>.yaml

kubectl get svc frontend -n <env> -w     # attendre l'EXTERNAL-IP (2 à 5 min)
```

Le fichier `values-<env>.yaml` ne contient pas `type` : le défaut de `values.yaml` est
`LoadBalancer`. Un `helm upgrade` sans `--set` revient donc au `LoadBalancer`.

## Vérification

```bash
kubectl get svc frontend -n <env> -o wide
curl -s "http://<EXTERNAL-IP>:<PORT>/guestbook.php?cmd=get"
```

Les Endpoints doivent être non vides :

```bash
kubectl get endpoints frontend -n <env>
```

Des Endpoints vides signifient que le sélecteur du Service ne correspond à aucun pod (label
`component` absent ou différent).

## Notes

- Le port ne change pas pendant la bascule : 8080 (dev), 8081 (staging), 8082 (prod).
- En local, le type `LoadBalancer` n'est joignable qu'avec `minikube tunnel` (terminal
  administrateur). Sans tunnel, le Service reste `<pending>`.
- La bascule ne touche ni les données ni les pods du leader.
