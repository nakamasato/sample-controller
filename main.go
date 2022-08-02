package main

import (
	"flag"
	"path/filepath"
	"time"

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

	exampleClient, err := clientset.NewForConfig(config)
	if err != nil {
		klog.Fatalf("Error building example clientset: %s", err.Error())
	}

	exampleInformerFactory := informers.NewSharedInformerFactory(exampleClient, time.Second*30)
	stopCh := make(chan struct{})
	controller := NewController(exampleClient, exampleInformerFactory.Example().V1alpha1().Foos())
	exampleInformerFactory.Start(stopCh)
	if err = controller.Run(stopCh); err != nil {
		klog.Fatalf("error occurred when running controller %s", err)
	}
}
