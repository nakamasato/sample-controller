package controller

import (
	"context"
	"fmt"
	"log"
	"time"

	samplev1alpha1 "github.com/nakamasato/sample-controller/pkg/apis/example.com/v1alpha1"
	clientset "github.com/nakamasato/sample-controller/pkg/client/clientset/versioned"
	informers "github.com/nakamasato/sample-controller/pkg/client/informers/externalversions/example.com/v1alpha1"
	listers "github.com/nakamasato/sample-controller/pkg/client/listers/example.com/v1alpha1"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/wait"
	appsinformers "k8s.io/client-go/informers/apps/v1"
	"k8s.io/client-go/kubernetes"
	appslisters "k8s.io/client-go/listers/apps/v1"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/util/workqueue"
)

type Controller struct {
	// kubeclientset is a standard kubernetes clientset
	kubeclientset kubernetes.Interface
	// sampleclientset is a clientset for our own API group
	sampleclientset clientset.Interface

	deploymentsLister appslisters.DeploymentLister
	deploymentsSynced cache.InformerSynced

	foosLister listers.FooLister    // lister for foo
	foosSynced cache.InformerSynced // cache is synced for foo

	// queue
	workqueue workqueue.RateLimitingInterface
}

func NewController(
	kubeclientset kubernetes.Interface,
	sampleclientset clientset.Interface,
	deploymentInformer appsinformers.DeploymentInformer,
	fooInformer informers.FooInformer) *Controller {
	controller := &Controller{
		kubeclientset:     kubeclientset,
		sampleclientset:   sampleclientset,
		deploymentsLister: deploymentInformer.Lister(),
		deploymentsSynced: deploymentInformer.Informer().HasSynced,
		foosLister:        fooInformer.Lister(),
		foosSynced:        fooInformer.Informer().HasSynced,
		workqueue:         workqueue.NewNamedRateLimitingQueue(workqueue.DefaultControllerRateLimiter(), "foo"),
	}

	fooInformer.Informer().AddEventHandler(
		cache.ResourceEventHandlerFuncs{
			AddFunc: controller.handleAdd,
		},
	)
	return controller
}

func (c *Controller) Run(stopCh <-chan struct{}) error {
	if ok := cache.WaitForCacheSync(stopCh, c.foosSynced); !ok {
		log.Printf("cache is not synced")
	}

	go wait.Until(c.worker, time.Second, stopCh)

	<-stopCh
	return nil
}

func (c *Controller) worker() {
	c.processNextItem()
}

func (c *Controller) processNextItem() bool {
	obj, shutdown := c.workqueue.Get()
	if shutdown {
		return false
	}

	// wrap this block in a func to use defer c.workqueue.Done
	err := func(obj interface{}) error {
		// call Done to tell workqueue that the item was finished processing
		defer c.workqueue.Done(obj)
		var key string
		var ok bool

		if key, ok = obj.(string); !ok {
			// As the item in the workqueue is actually invalid, we call
			// Forget here else we'd go into a loop of attempting to
			// process a work item that is invalid.
			c.workqueue.Forget(obj)
			return nil
		}

		if err := c.syncHandler(key); err != nil {
			// Put the item back on the workqueue to handle any transient errors.
			c.workqueue.AddRateLimited(key)
			return fmt.Errorf("error syncing '%s': %s, requeuing", key, err.Error())
		}

		// Forget the queue item as it's successfully processed and
		// the item will not be requeued.
		c.workqueue.Forget(obj)
		return nil
	}(obj)

	if err != nil {
		return true
	}

	return true
}

func (c *Controller) handleAdd(obj interface{}) {
	log.Println("handleAdd was called")
	c.enqueueFoo(obj)
}

// enqueueFoo takes a Foo resource and converts it into a namespace/name
// string which is then put onto the work queue. This method should *not* be
// passed resources of any type other than Foo.
func (c *Controller) enqueueFoo(obj interface{}) {
	var key string
	var err error
	if key, err = cache.MetaNamespaceKeyFunc(obj); err != nil {
		log.Printf("failed to get key from the cache %s\n", err.Error())
		return
	}
	c.workqueue.Add(key)
}

func (c *Controller) syncHandler(key string) error {
	ns, name, err := cache.SplitMetaNamespaceKey(key)
	if err != nil {
		log.Printf("failed to split key into namespace and name %s\n", err.Error())
		return err
	}

	foo, err := c.foosLister.Foos(ns).Get(name)
	if err != nil {
		log.Printf("failed to get foo resource from lister %s\n", err.Error())
		if errors.IsNotFound(err) {
			return nil
		}
		return err
	}

	deploymentName := foo.Spec.DeploymentName
	if deploymentName == "" {
		log.Printf("deploymentName must be specified %s\n", key)
		return nil
	}
	deployment, err := c.deploymentsLister.Deployments(foo.Namespace).Get(deploymentName)
	if errors.IsNotFound(err) {
		deployment, err = c.kubeclientset.AppsV1().Deployments(foo.Namespace).Create(context.TODO(), newDeployment(foo), metav1.CreateOptions{})
	}

	if err != nil {
		return err
	}

	log.Printf("deployment %s is valid", deployment.Name)

	return nil
}

func newDeployment(foo *samplev1alpha1.Foo) *appsv1.Deployment {
	labels := map[string]string{
		"app":        "nginx",
		"controller": foo.Name,
	}
	return &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:            foo.Spec.DeploymentName,
			Namespace:       foo.Namespace,
			OwnerReferences: []metav1.OwnerReference{*metav1.NewControllerRef(foo, samplev1alpha1.SchemeGroupVersion.WithKind("Foo"))},
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: foo.Spec.Replicas,
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: labels,
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "nginx",
							Image: "nginx:latest",
						},
					},
				},
			},
		},
	}
}