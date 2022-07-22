---
title: 'Sample Controller'
date: 2021-12-22T22:20+0900
---

## About Sample Controller

[Sample Controller](https://github.com/kubernetes/sample-controller/) is an example Kubernetes controller in the Kubernetes project, with which you can learn about how Kubernetes controller is implemented and how it works.

## Objective of the repo

Although the official repository is very helpful to understand a Kubernetes controller, it is still quite hard to read the source codes and implement it by yourself, especially for a newbie. So, I broke down the complete codes into steps in this repository ([nakamasato/sample-controller](https://github.com/nakamasato/sample-controller)) so anybody can create the example controller step by step from scratch.

I hope this documentation will be helpful to open the door to the world of Kubernetes operator.

## Overview of Sample Controller

![](sample-controller.drawio.svg)

1. Sample controller has only one custom resource `Foo`.
1. When a `Foo` object is created/updated, Sample controller creates/updates `Deployment` (with an `nginx` container) to keep it consistent with the `Foo` object, which can specify the `name` and `replicas` of `Deployment`.
1. Sample controller also updates the status of `Foo` object based on the number of available Pods created by the controlled `Deployment`.
