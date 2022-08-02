package main

import (
	"flag"
	"path/filepath"
	"time"

	kubeinformers "k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
	"k8s.io/klog/v2"

	clientset "github.com/nakamasato/sample-controller/pkg/generated/clientset/versioned"
	informers "github.com/nakamasato/sample-controller/pkg/generated/informers/externalversions"
)

func main() {
	klog.InitFlags(nil)

	var kubeconfig *string
	if home := homedir.HomeDir(); home != "" {
		kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional)")
	} else {
		kubeconfig = flag.String("kubeconfig", "", "absolute path to kubeconfig file")
	}
	flag.Parse()

	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		klog.Fatalf("Error building kubeconfig: %s", err.Error())
	}

	kubeClient, err := kubernetes.NewForConfig(config)
	if err != nil {
		klog.Errorf("getting kubernetes client set %s\n", err.Error())
	}

	exampleClient, err := clientset.NewForConfig(config)
	if err != nil {
		klog.Fatalf("Error building example clientset: %s", err.Error())
	}

	kubeInformerFactory := kubeinformers.NewSharedInformerFactory(kubeClient, time.Second*30)
	exampleInformerFactory := informers.NewSharedInformerFactory(exampleClient, time.Second*30)
	stopCh := make(chan struct{})
	controller := NewController(
		kubeClient,
		exampleClient,
		kubeInformerFactory.Apps().V1().Deployments(),
		exampleInformerFactory.Example().V1alpha1().Foos(),
	)
	kubeInformerFactory.Start(stopCh)
	exampleInformerFactory.Start(stopCh)
	if err = controller.Run(stopCh); err != nil {
		klog.Fatalf("error occurred when running controller %s\n", err.Error())
	}
}
