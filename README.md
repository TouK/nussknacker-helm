# Nussknacker Helm Chart

## Lokalny setup na microk8s
Instalujemy microk8s

Włączamy wtyczki:

- microk8s enable dns
- microk8s enable ingress
- microk8s enable helm3 - na 14.12.2021 helm3 jest w wesji 3.5.0, wymagana jest 3.7.x https://github.com/ubuntu/microk8s/issues/843
```
sudo snap install helm --classic
sudo mkdir /var/snap/microk8s/current/bin
sudo ln -s /snap/bin/helm /var/snap/microk8s/current/bin/helm3
```

Instalacja local-path provisionera obsługującego dynamic provisioning: https://github.com/rancher/local-path-provisioner
```
microk8s.kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

Ustawienie jej jako default storageclass

```
microk8s.kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Przechodzimy do katalogu src

Dodajemy repozytoria:
- microk8s.helm3 repo add touk https://helm-charts.touk.pl/public

### Sprawdzamy zależności.

- helm dep list
- helm dep update

### Dry-run
- microk8s.helm3 install nussknacker . --set ingress.enabled=true --set ingress.domain=default.svc.cluster.local --dry-run

### Instalacja
- microk8s.helm3 install nussknacker . --set ingress.enabled=true --set ingress.domain=default.svc.cluster.local

Pierwsze uruchomienie może potrwać z uwagi na ściąganie obrazów, po ściągnięciu obrazów najlepiej ponownie zainstalować charta

### Upgrade
```
microk8s.kubectl create secret generic nussknacker-postgresql  --from-literal postgresql-password=`date +%s | sha256sum | base64 | head -c 32`
```

```
microk8s.helm3 upgrade --set postgresql.existingSecret=nussknacker-postgresql -f values.yml nussknacker /home/arkadius/src/touk-git/nussknacker-helm-chart/src
```


### Usuwanie
- microk8s.helm3 uninstall nussknacker

## Master
Pipeline na master buduje i deploy'uje charta do
Designer jest wystawiony pod https://master-nussknacker.carpinion.touk.pl/processes
Hermes jest wystawiony pod https://master-hermes-management.carpinion.touk.pl

## Gitlab

### Dostęp do klastra
https://gangway.carpinion.touk.pl/#

### GUI NU

- wyszukujemy namespace naszego brancha
- kubens nazwa_namespace
- kubectl get ingress
- otwieramy adres NU

Dane na kafkę możemy wysłać curl'em
```
curl -X POST -H "content-type: application/json" https://bump-nk-1-1-0-cvj5n8-hermes-frontend.carpinion.touk.pl/topics/testgroup.inputHermes --data '{ "id": "an id3", "content": "a content", "tags": [] }' -v
```

## Aktualizacja do nowszych API K8s
Sprawdzenie różnic w yaml
```
kubectl explain --api-version=networking.k8s.io/v1beta1 ingress.spec.rules.http.paths.backend
kubectl explain --api-version=networking.k8s.io/v1 ingress.spec.rules.http.paths.backend.service
```
