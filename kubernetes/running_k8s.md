Once you have deployed your kubernetes cluster, let's start demo pods.

Quick note:

* *replication_controller* - controls the amount of pods (it runs pod)
* *pod* - is just a container without possibility to access directly, but by kube-proxy random port
* *service* - load balancer, VIP for pods, which allows to connect to it

First of all if we would like to support DNS resolving of our services, we have to install SkyDNS. In out exmaple we will use 1 replica.:

```sh
wget -O https://raw.githubusercontent.com/GoogleCloudPlatform/kubernetes/release-1.0/cluster/addons/dns/skydns-rc.yaml.in
kubectl create -f skydns-rc.yaml

```

List skydns RC:

```sh
kubectl get rc/kube-dns-v8 --namespace=kube-system
```

Stop and delete skydns RC:

```sh
kubectl delete rc kube-dns-v8 --namespace=kube-system
```

Enter your k8s master node and enter following commands:

```sh
curl -O https://raw.githubusercontent.com/GoogleCloudPlatform/kubernetes/v1.0.1/examples/guestbook/redis-master-controller.yaml
kubectl create -f redis-master-controller.yaml
curl -O https://raw.githubusercontent.com/GoogleCloudPlatform/kubernetes/v1.0.1/examples/guestbook/redis-master-service.yaml
kubectl create -f redis-master-service.yaml
curl -O https://raw.githubusercontent.com/GoogleCloudPlatform/kubernetes/v1.0.1/examples/guestbook/redis-slave-controller.yaml
kubectl create -f redis-slave-controller.yaml
curl -O https://raw.githubusercontent.com/GoogleCloudPlatform/kubernetes/v1.0.1/examples/guestbook/redis-slave-service.yaml
kubectl create -f redis-slave-service.yaml
curl -O https://raw.githubusercontent.com/GoogleCloudPlatform/kubernetes/v1.0.1/examples/guestbook/frontend-controller.yaml
kubectl create -f frontend-controller.yaml
curl -O https://raw.githubusercontent.com/GoogleCloudPlatform/kubernetes/v1.0.1/examples/guestbook/frontend-service.yaml
kubectl create -f frontend-service.yaml
```

destroy pods by one name:

```sh
kubectl stop rc -l "name==redis-master"
kubectl delete rc -l "name==redis-master"
```

destroy pods by names:

```sh
kubectl delete rc -l "name in (redis-master, redis-slave, frontend)"
```

destroy services by one name:

```sh
kubectl delete service -l "name==redis-master"
```

destroy services by names:

```sh
kubectl delete service -l "name in (redis-master, redis-slave, frontend)"
```

## FAQ

* do we really need flannel in this example?

ANS: ?

* how to run two slaves on different nodes?

ANS: ?

* how does environments pass to redis-slave? there is no info about master in RC yaml for slaves

ANS: ?

* it seems redis-slave doesn't know anything about redis-master:

```
[9] 07 Aug 15:26:56.742 * Connecting to MASTER redis-master:6379
[9] 07 Aug 15:26:56.742 # Unable to connect to MASTER: No such file or directory
```

ANS: Have to use DNS service

* how can I override default "sh -c /run.sh" in redis-slave container?

ANS: use "command:" in yaml

* is there a difference between 'kubectl delete service -l "name==redis-master"' and 'kubectl stop service -l "name==redis-master"'?

ANS: ?

## TODO

* instead of using master hostname - set this value into etcd, then save it into environmentfile
* add DNS service into cloud-config
