#!/bin/bash

usage() {
  echo "Usage: $0 %domain_name%"
}

if [ "$1" == "" ]; then
  echo "Domain name is empty"
  usage
  exit 1
fi

LIBVIRT_PATH=/var/lib/libvirt/images/coreos

if [[ "$1" =~ ^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$ ]]; then
  virsh destroy $1; virsh undefine $1 && rm -rf $LIBVIRT_PATH/${1} && rm -f $LIBVIRT_PATH/${1}.qcow2
  exit 0
fi

for i in $(virsh list --all --name | grep -E '^node[0-9]'); do
  virsh destroy $i; virsh undefine $i && rm -rf $LIBVIRT_PATH/${i} && rm -f $LIBVIRT_PATH/${i}.qcow2
done
