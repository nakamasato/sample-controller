package main

import (
	"flag"
	"log"
	"path/filepath"
	"time"

	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"

	clientset "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned"
	informers "github.com/nakamasato/sample-controller/pkg/client/informers/externalversions"
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

	exampleClient, err := clientset.NewForConfig(config)
	if err != nil {
		log.Printf("getting client set %s\n", err.Error())
	}

	exampleInformerFactory := informers.NewSharedInformerFactory(exampleClient, time.Second*30)
	ch := make(chan struct{})
	controller := controller.NewController(exampleClient, exampleInformerFactory.Example().V1alpha1().Foos())
	exampleInformerFactory.Start(ch)
	if err = controller.Run(ch); err != nil {
		log.Printf("error occurred when running controller %s\n", err.Error())
	}
}
