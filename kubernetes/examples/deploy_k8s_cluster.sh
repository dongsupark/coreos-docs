#!/bin/bash -e

usage() {
  echo "Usage: $0 %k8s_cluster_size% [%pub_key_path%]"
}

print_green() {
  echo -e "\e[92m$1\e[0m"
}

if [ "$1" == "" ]; then
  echo "Cluster size is empty"
  usage
  exit 1
fi

if ! [[ $1 =~ ^[0-9]+$ ]]; then
  echo "'$1' is not a number"
  usage
  exit 1
fi

if [[ "$1" -lt "2" ]]; then
  echo "'$1' is lower than 2 (minimal k8s cluster size)"
  usage
  exit 1
fi

if [[ -z $2 || ! -f $2 ]]; then
  echo "SSH public key path is not specified"
  if [ -n $HOME ]; then
        PUB_KEY_PATH="$HOME/.ssh/id_rsa.pub"
  else
        echo "Can not determine home directory for SSH pub key path"
        exit 1
  fi

  print_green "Will use default path to SSH public key: $PUB_KEY_PATH"
  if [ ! -f $PUB_KEY_PATH ]; then
        echo "Path $PUB_KEY_PATH doesn't exist"
        exit 1
  fi
else
  PUB_KEY_PATH=$2
  print_green "Will use this path to SSH public key: $PUB_KEY_PATH"
fi

PUB_KEY=$(cat $PUB_KEY_PATH)
PRIV_KEY_PATH=$(echo ${PUB_KEY_PATH} | sed 's#.pub##')
CDIR=$(cd `dirname $0` && pwd)
TECTONIC_LICENSE=$(cat $CDIR/tectonic.lic 2>/dev/null)
DOCKER_CFG=$(cat $CDIR/docker.cfg 2>/dev/null)
LIBVIRT_PATH=/var/lib/libvirt/images/coreos
MASTER_USER_DATA_TEMPLATE=$CDIR/k8s_tectonic_master.yaml
#MASTER_USER_DATA_TEMPLATE=$CDIR/k8s_master.yaml
NODE_USER_DATA_TEMPLATE=$CDIR/k8s_node.yaml
CHANNEL=alpha
RELEASE=current
ETCD_DISCOVERY=$(curl -s "https://discovery.etcd.io/new?size=$1")
K8S_RELEASE=v1.1.3
FLANNEL_TYPE=vxlan

ETCD_ENDPOINTS=""
for SEQ in $(seq 1 $1); do
  if [ "$SEQ" == "1" ]; then
		ETCD_ENDPOINTS="http://k8s-master:2379"
  else
    NODE_SEQ=$[SEQ-1]
    ETCD_ENDPOINTS="$ETCD_ENDPOINTS,http://k8s-node-$NODE_SEQ:2379"
  fi
done

POD_NETWORK=10.2.0.0/16
SERVICE_IP_RANGE=10.3.0.0/24
K8S_SERVICE_IP=10.3.0.1
DNS_SERVICE_IP=10.3.0.10
K8S_DOMAIN=cluster.local
RAM=512
CPUs=1
IMG_NAME="coreos_${CHANNEL}_${RELEASE}_qemu_image.img"

if [ ! -d $LIBVIRT_PATH ]; then
  mkdir -p $LIBVIRT_PATH || (echo "Can not create $LIBVIRT_PATH directory" && exit 1)
fi

if [ ! -f $MASTER_USER_DATA_TEMPLATE ]; then
  echo "Cannot find $MASTER_USER_DATA_TEMPLATE template"
  exit 1
fi

if [ ! -f $MASTER_USER_DATA_TEMPLATE ]; then
  echo "Cannot find $MASTER_USER_DATA_TEMPLATE template"
  exit 1
fi

for SEQ in $(seq 1 $1); do
  if [ "$SEQ" == "1" ]; then
    COREOS_HOSTNAME="k8s-master"
    COREOS_MASTER_HOSTNAME=$COREOS_HOSTNAME
    USER_DATA_TEMPLATE=$MASTER_USER_DATA_TEMPLATE
  else
    NODE_SEQ=$[SEQ-1]
    COREOS_HOSTNAME="k8s-node-$NODE_SEQ"
    USER_DATA_TEMPLATE=$NODE_USER_DATA_TEMPLATE
  fi

  if [ ! -d $LIBVIRT_PATH/$COREOS_HOSTNAME/openstack/latest ]; then
    mkdir -p $LIBVIRT_PATH/$COREOS_HOSTNAME/openstack/latest || (echo "Can not create $LIBVIRT_PATH/$COREOS_HOSTNAME/openstack/latest directory" && exit 1)
  fi

  if [ ! -f $LIBVIRT_PATH/$IMG_NAME ]; then
    wget http://${CHANNEL}.release.core-os.net/amd64-usr/${RELEASE}/coreos_production_qemu_image.img.bz2 -O - | bzcat > $LIBVIRT_PATH/$IMG_NAME || (rm -f $LIBVIRT_PATH/$IMG_NAME && echo "Failed to download image" && exit 1)
  fi

  if [ ! -f $LIBVIRT_PATH/$COREOS_HOSTNAME.qcow2 ]; then
    qemu-img create -f qcow2 -b $LIBVIRT_PATH/$IMG_NAME $LIBVIRT_PATH/$COREOS_HOSTNAME.qcow2
  fi

  sed "s#%PUB_KEY%#$PUB_KEY#g;\
       s#%HOSTNAME%#$COREOS_HOSTNAME#g;\
       s#%DISCOVERY%#$ETCD_DISCOVERY#g;\
       s#%SERVICE_IP_RANGE%#$SERVICE_IP_RANGE#g;\
       s#%MASTER_HOST%#$COREOS_MASTER_HOSTNAME#g;\
       s#%K8S_RELEASE%#$K8S_RELEASE#g;\
       s#%FLANNEL_TYPE%#$FLANNEL_TYPE#g;\
       s#%POD_NETWORK%#$POD_NETWORK#g;\
       s#%K8S_SERVICE_IP%#$K8S_SERVICE_IP#g;\
       s#%DNS_SERVICE_IP%#$DNS_SERVICE_IP#g;\
       s#%K8S_DOMAIN%#$K8S_DOMAIN#g;\
       s#%TECTONIC_LICENSE%#$TECTONIC_LICENSE#g;\
       s#%DOCKER_CFG%#$DOCKER_CFG#g;\
       s#%ETCD_ENDPOINTS%#$ETCD_ENDPOINTS#g" $USER_DATA_TEMPLATE > $LIBVIRT_PATH/$COREOS_HOSTNAME/openstack/latest/user_data
  if [[ selinuxenabled ]]; then
    echo "Making SELinux configuration"
    semanage fcontext -d -t virt_content_t "$LIBVIRT_PATH/$COREOS_HOSTNAME(/.*)?" || true
    semanage fcontext -a -t virt_content_t "$LIBVIRT_PATH/$COREOS_HOSTNAME(/.*)?"
    restorecon -R "$LIBVIRT_PATH"
  fi

  virt-install \
    --connect qemu:///system \
    --import \
    --name $COREOS_HOSTNAME \
    --ram $RAM \
    --vcpus $CPUs \
    --os-type=linux \
    --os-variant=virtio26 \
    --disk path=$LIBVIRT_PATH/$COREOS_HOSTNAME.qcow2,format=qcow2,bus=virtio \
    --filesystem $LIBVIRT_PATH/$COREOS_HOSTNAME/,config-2,type=mount,mode=squash \
    --vnc \
    --noautoconsole
done

print_green "Use this command to connect to your CoreOS cluster: 'ssh -i $PUB_KEY_PATH core@$COREOS_MASTER_HOSTNAME'"
