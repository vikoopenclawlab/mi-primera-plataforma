#!/bin/bash
# Fastify API - Start/Stop script

ACTION=$1

case $ACTION in
  start)
    echo "Starting Fastify API..."
    kubectl scale deployment fastify-api -n plataformas-web --replicas=1
    kubectl rollout status deployment/fastify-api -n plataformas-web --timeout=60s
    echo "Fastify API started"
    ;;
  stop)
    echo "Stopping Fastify API..."
    kubectl scale deployment fastify-api -n plataformas-web --replicas=0
    echo "Fastify API stopped"
    ;;
  status)
    kubectl get deployment fastify-api -n plataformas-web
    kubectl get pods -l app=fastify-api -n plataformas-web
    ;;
  logs)
    kubectl logs -l app=fastify-api -n plataformas-web --tail=20
    ;;
  *)
    echo "Usage: $0 {start|stop|status|logs}"
    ;;
esac
