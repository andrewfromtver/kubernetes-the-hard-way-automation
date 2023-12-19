#!/bin/bash

apt-get update
apt-get -y install haproxy

echo "\
global
  maxconn 1000

defaults
  log global
  mode tcp
  retries 3
  timeout client 30m
  timeout connect 1s
  timeout server 30m
  timeout check 1s

listen stats
  mode http
  bind *:80
  stats enable
  stats uri /

listen k8s-controller
  bind *:6443
  option httpchk
  http-check send meth GET uri /healthz ver HTTP/1.1 hdr host kubernetes.default.svc.cluster.local
  server controller-1 $CONTROLLER_NODE_1_IP:6443 maxconn 100 check port 80
  server controller-2 $CONTROLLER_NODE_2_IP:6443 maxconn 100 check port 80

listen k8s-worker
  bind *:30000-32767
  server worker-1 $WORKER_NODE_1_IP maxconn 100 check port 10256
  server worker-2 $WORKER_NODE_2_IP maxconn 100 check port 10256
  server worker-3 $WORKER_NODE_3_IP maxconn 100 check port 10256

listen k8s-etcd
  server etcd-1 $ETCD_IP_1:2379 maxconn 100 check port 2379
  server etcd-2 $ETCD_IP_2:2379 maxconn 100 check port 2379
  server etcd-3 $ETCD_IP_3:2379 maxconn 100 check port 2379

" > /etc/haproxy/haproxy.cfg

systemctl restart haproxy
