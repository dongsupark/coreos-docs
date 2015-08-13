#!/bin/bash

LIBVIRT_PATH=/var/lib/libvirt/images/coreos

for i in $(virsh list --all --name | grep -E '^k8s-(master|node)'); do
	virsh destroy $i; virsh undefine $i && rm -rf $LIBVIRT_PATH/${i} && rm -f $LIBVIRT_PATH/${i}.qcow2
done
