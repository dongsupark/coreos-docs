Based on http://kubernetes.io/v1.0/examples/guestbook/README.html

Install libvirt on Ubuntu:

```sh
apt-get install libvirt-bin virtinst qemu-kvm virt-manager git

```

Configure local resolver to use libvirt's dnsmasq:

```sh
echo 'nameserver 192.168.122.1' | sudo tee -a /etc/resolvconf/resolv.conf.d/head && sudo resolvconf -u
```

Clone this exmaple:

```sh
git clone https://github.com/endocode/coreos-docs
```

Deploy cluster:

```sh
cd coreos-docs
git checkout kubernetes
cd kubernetes/examples
sudo ./deploy_k8s_cluster.sh %k8s_cluster_size% [%pub_key_path%]
```

Enter your Kubernetes master node:

```sh
ssh core@k8s-master # [-i ~/.ssh/id_rsa]
```

Quick note:

* *replication_controller* - controls the amount of pods (it runs pod)
* *pod* - is just a container without possibility to access directly, but by kube-proxy random port
* *service* - load balancer, VIP for pods, which allows to connect to it

First of all if we would like to support DNS resolving of our services, we have to install SkyDNS. In out example we will use 1 replica. These steps are alredy defined in cloud-config:

```sh
kubectl create -f skydns-rc.yaml
kubectl create -f skydns-service.yaml
```

List instances from all namespaces:

```sh
kubectl get pods --all-namespaces
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
kubectl create -f kubectl_demo/redis-master-controller.yaml
kubectl create -f kubectl_demo/redis-master-service.yaml
kubectl create -f kubectl_demo/redis-slave-controller.yaml
kubectl create -f kubectl_demo/redis-slave-service.yaml
kubectl create -f kubectl_demo/frontend-controller.yaml
kubectl create -f kubectl_demo/frontend-service.yaml
```

or just this command:

```sh
find kubectl_demo -type f -exec kubectl create -f {} \;
```

You can watch how your pods are being started:

```sh
watch kubectl get pods
```

If you want to expose service on every Kubernetes worker node you have to define service with `NodePort` type (there is an example in core user home directory):

```sh
kubectl create -f expose-frontend-to-30000-port.yaml
```

And then you will be able to access your frontpage through http://k8s-node-1:30000/ address.

Kube-UI in this exmaple is availabe on this URL: http://k8s-master:8001/api/v1/proxy/namespaces/kube-system/services/kube-ui/

Manual steps are following:

```sh
curl -O https://raw.githubusercontent.com/GoogleCloudPlatform/kubernetes/v1.0.1/cluster/addons/kube-ui/kube-ui-rc.yaml
kubectl create -f kube-ui-rc.yaml
curl -O https://raw.githubusercontent.com/GoogleCloudPlatform/kubernetes/v1.0.1/cluster/addons/kube-ui/kube-ui-svc.yaml
kubectl create -f kube-ui-svc.yaml
```

Make kubectl proxy available on "http://k8s-master:8001" and it will make available Kube-UI on this URL: http://k8s-master:8001/api/v1/proxy/namespaces/kube-system/services/kube-ui/

```sh
/opt/bin/kubectl proxy --accept-hosts='^k8s-master$'
```

Also you can nslookup your kube-ui using any pod in your default namespace through exec command:

```sh
kubectl exec %pod% -- nslookup kube-ui.kube-system.svc.skydns.local
```

If your pod has several containers, you can specify container using this command:

```sh
kubectl exec -ti kube-dns-v8-kvd0g --namespace=kube-system sh #will run shell of first defined container, in our case "kube2sky"
kubectl exec -ti kube-dns-v8-kvd0g -c kube2sky --namespace=kube-system sh # that will be equivalent to previous command
kubectl exec -ti kube-dns-v8-kvd0g -c skydns --namespace=kube-system sh # you will enter "skydns" container of "kube-dns-v8-kvd0g" pod
```

Decrease/increase replicas for Replication controller (in our exmaple: frontend):

```sh
kubectl scale --replicas=1 rc frontend
```

List exposes (services) (more [info](https://cloud.google.com/container-engine/docs/kubectl/expose) about expose)

```sh
kubectl get services --namespace=kube-system
```

Expose frontend demo to external IP:

```sh
kubectl expose rc frontend --port=80 --target-port=80 --public-ip="192.168.122.178" --name=guestbook-frontend
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

get nodes's IPs:

```sh
kubectl get -o template nodes --template='{{range .items}}{{range .status.addresses}}{{printf "%s\n" .address}}{{end}}{{end}}'
```

## FAQ

* do we really need flannel in this example?

ANS: Yes, we do, as when you talk to VIP, kube-proxy forwards request to real containers' endpoint IP. And it should be accessible on any Kubernetes node.

* how to run two slaves on different nodes?

ANS: ?

* how does environments pass to redis-slave? there is no info about master in RC yaml for slaves

ANS: Kubernetes automatically generates enviroments depending on namespace's services names and ports.

* it seems redis-slave doesn't know anything about redis-master:

```
[9] 07 Aug 15:26:56.742 * Connecting to MASTER redis-master:6379
[9] 07 Aug 15:26:56.742 # Unable to connect to MASTER: No such file or directory
```

ANS: You have to use DNS service

* how can I override default "sh -c /run.sh" in redis-slave container?

ANS: use "command:" in yaml

* is there a difference between 'kubectl delete service -l "name==redis-master"' and 'kubectl stop service -l "name==redis-master"'?

ANS: ?

* which IP will see APP inside pod's container if someone will try to connect through VIP?

ANS: APP will see docker/flannel interface host IP address

* What if master goes down?

ANS: Kubernetes workers can survive master node reboot.

## TODO

* instead of using master hostname - set this value into etcd, then save it into environmentfile
* add certificates into etcd2
