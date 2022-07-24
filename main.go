package main

import (
    "context"
    "flag"
    "path/filepath"

    "k8s.io/client-go/tools/clientcmd"
    "k8s.io/client-go/util/homedir"
    "k8s.io/klog/v2"

    clientset "github.com/nakamasato/sample-controller/pkg/generated/clientset/versioned"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
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

    exampleClientset, err := clientset.NewForConfig(config)
    if err != nil {
        klog.Fatalf("Error building kubernetes clientset: %s", err.Error())
    }
    klog.Info(exampleClientset)

    foos, err := exampleClientset.ExampleV1alpha1().Foos("").List(context.Background(), metav1.ListOptions{})
    if err != nil {
        klog.Fatalf("listing foos %s %s", err.Error())
    }
    klog.Infof("length of foos is %d", len(foos.Items))
}
