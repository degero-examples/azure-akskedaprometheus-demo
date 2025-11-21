#!/bin/bash

helm uninstall --wait ingress-nginx-basic -n ingress-nginx
kubectl delete ns ingress-nginx