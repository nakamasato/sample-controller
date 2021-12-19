package main

import (
	"flag"
	"log"
	"path/filepath"
	"time"

	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"

	client "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned"
	finformer "github.com/nakamasato/sample-controller/pkg/client/informers/externalversions"
	"github.com/nakamasato/sample-controller/pkg/controller"
)

func main() {
	var kubeconfig *string

	if home := homedir.HomeDir(); home != "" {
		kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional)")
	} else {
		kubeconfig = flag.String("kubeconfig", "", "absolute path to kubeconfig file")
	}
	flag.Parse()

	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		log.Printf("Building config from flags, %s", err.Error())
	}

	clientset, err := client.NewForConfig(config)
	if err != nil {
		log.Printf("getting client set %s\n", err.Error())
	}

	informerFactory := finformer.NewSharedInformerFactory(clientset, 20*time.Minute)
	ch := make(chan struct{})
	c := controller.NewController(clientset, informerFactory.Example().V1alpha1().Foos())
	informerFactory.Start(ch)
	if err = c.Run(ch); err != nil {
		log.Printf("error occurred when running controller %s\n", err.Error())
	}
}
