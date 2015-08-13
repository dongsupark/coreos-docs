#!/bin/bash

LIBVIRT_PATH=/var/lib/libvirt/images/coreos

for i in $(virsh list --all --name | grep k8s); do
	virsh destroy $i; virsh undefine $i && rm -rf $LIBVIRT_PATH/${i} && rm -f $LIBVIRT_PATH/${i}.qcow2
done
