package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"path/filepath"

	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"

	client "github.com/nakamasato/sample-controller/pkg/generated/clientset/versioned"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
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
	fmt.Println(clientset)

	foos, err := clientset.ExampleV1alpha1().Foos("").List(context.Background(), metav1.ListOptions{})
	if err != nil {
		log.Printf("listing foos %s\n", err.Error())
	}
	fmt.Printf("length of foos is %d\n", len(foos.Items))
}
