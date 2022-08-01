#!/bin/bash

set -ue

MODULE_NAME=github.com/nakamasato/sample-controller
REPO_URL=https://$MODULE_NAME
DATE_FORMAT="%Y-%m-%dT%H:%M:%S%z"
FOO_CONTROLLER_FILE=controller.go
FOO_CRD_FILE=config/crd/foos.yaml
FOO_TYPES_FILE=pkg/apis/example.com/v1alpha1/types.go
MAIN_GO_FILE=main.go

# Start from main
# git fetch
# git reset origin/main --hard # TODO: confirm this will blow up all the uncommited changes

# Delete files
for f in go.mod go.sum $MAIN_GO_FILE $FOO_CONTROLLER_FILE config/**/*.yaml;do
    if [ -f $f ];then
        rm $f
        git add $f
    fi
done
if [ -d pkg ]; then rm -rf pkg;git add pkg; fi
git commit -m "Remove files"

# 0. Init Go module
go mod init $MODULE_NAME
TITLE_AND_MESSAGE="0. Initialize Go module"
git add go.mod && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/00-init-module/index.md
gsed -i "s/date:.*/date: $(date +"$DATE_FORMAT")/" docs/content/docs/00-init-module/index.md

# 1. Define Go types for CRD
mkdir -p pkg/apis/example.com/v1alpha1

cat <<EOF >> pkg/apis/example.com/v1alpha1/doc.go
package v1alpha1
EOF

cat <<EOF >> $FOO_TYPES_FILE
package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

// Foo is a specification for a Foo resource
type Foo struct {
    metav1.TypeMeta   \`json:",inline"\`
    metav1.ObjectMeta \`json:"metadata,omitempty"\`

    Spec   FooSpec   \`json:"spec"\`
    Status FooStatus \`json:"status"\`
}

// FooSpec is the spec for a Foo resource
type FooSpec struct {
    DeploymentName string \`json:"deploymentName"\`
    Replicas       *int32 \`json:"replicas"\`
}

// FooStatus is the status for a Foo resource
type FooStatus struct {
    AvailableReplicas int32 \`json:"availableReplicas"\`
}

// FooList is a list of Foo resources
type FooList struct {
    metav1.TypeMeta \`json:",inline"\`
    metav1.ListMeta \`json:"metadata"\`

    Items []Foo \`json:"items"\`
}
EOF

cat <<EOF >> pkg/apis/example.com/v1alpha1/register.go
package v1alpha1

import (
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/runtime/schema"
)

var (
    // SchemeBuilder initializes a scheme builder
    SchemeBuilder = runtime.NewSchemeBuilder(addKnownTypes)
    // AddToScheme is a global function that registers this API group & version to a scheme
    AddToScheme = SchemeBuilder.AddToScheme
)

// SchemeGroupVersion is group version used to register these objects.
var SchemeGroupVersion = schema.GroupVersion{
    Group:   "example.com",
    Version: "v1alpha1",
}

func Resource(resource string) schema.GroupResource {
    return SchemeGroupVersion.WithResource(resource).GroupResource()
}

func addKnownTypes(scheme *runtime.Scheme) error {
    scheme.AddKnownTypes(SchemeGroupVersion,
        &Foo{},
        &FooList{},
    )
    metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
    return nil
}
EOF

go mod tidy
TITLE_AND_MESSAGE="1. Define Go types for CRD"
git add go.sum go.mod pkg/apis/example.com/v1alpha1 && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/01-define-go-types-for-crd/index.md
gsed -i "s/date:.*/date: $(date +"$DATE_FORMAT")/" docs/content/docs/01-define-go-types-for-crd/index.md

# 2. Generate codes
codeGeneratorDir=~/repos/kubernetes/code-generator
if [ ! -d "$codeGeneratorDir" ] ; then
    git clone https://github.com/kubernetes/code-generator.git $codeGeneratorDir
fi

# add comment tag

cat <<EOF > tmpfile
// +k8s:deepcopy-gen=package
// +groupName=example.com

EOF

gsed -i $'/^package v1alpha1$/{e cat tmpfile\n}' pkg/apis/example.com/v1alpha1/doc.go # add before

cat <<EOF > tmpfile
// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

EOF
gsed -i $'/^\/\/ Foo is a specification for a Foo resource$/{e cat tmpfile\n}' $FOO_TYPES_FILE # add before

cat <<EOF > tmpfile
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

EOF
gsed -i $'/^\/\/ FooList is a list of Foo resources$/{e cat tmpfile\n}' $FOO_TYPES_FILE # add before

"${codeGeneratorDir}"/generate-groups.sh all ${MODULE_NAME}/pkg/generated ${MODULE_NAME}/pkg/apis example.com:v1alpha1 --go-header-file "${codeGeneratorDir}"/hack/boilerplate.go.txt --trim-path-prefix $MODULE_NAME
go mod tidy
go fmt ./...
go vet ./...
TITLE_AND_MESSAGE="2. Generate codes"
git add pkg && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/02-generate-code/index.md
gsed -i "s/date:.*/date: $(date +"$DATE_FORMAT")/" docs/content/docs/02-generate-code/index.md

# 3. Create CRD

cat <<EOF >> config/crd/foos.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: foos.example.com
spec:
  group: example.com
  names:
    kind: Foo
    listKind: FooList
    plural: foos
    singular: foo
  scope: Namespaced
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            apiVersion:
              type: string
            kind:
              type: string
            metadata:
              type: object
            spec:
              type: object
              properties:
                deploymentName:
                  type: string
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 10
            status:
              type: object
              properties:
                availableReplicas:
                  type: integer
EOF
TITLE_AND_MESSAGE="3. Create CRD yaml file"
git add config && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/03-create-crd-yaml/index.md
gsed -i "s/date:.*/date: $(date +"$DATE_FORMAT")/" docs/content/docs/03-create-crd-yaml/index.md

# 4. Checkpoint
cat <<EOF >> $MAIN_GO_FILE
package main

import (
	"context"
	"flag"
	"path/filepath"

	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
	"k8s.io/klog/v2"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	clientset "github.com/nakamasato/sample-controller/pkg/generated/clientset/versioned"
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

	foos, err := exampleClient.ExampleV1alpha1().Foos("").List(context.Background(), metav1.ListOptions{})
	if err != nil {
		klog.Fatalf("listing foos %s", err.Error())
	}
	klog.Infof("length of foos is %d", len(foos.Items))
}
EOF
go mod tidy
go vet ./...
go fmt ./...

cat <<EOF >> config/sample/foo.yaml
apiVersion: example.com/v1alpha1
kind: Foo
metadata:
  name: foo-sample
spec:
  deploymentName: foo-sample
  replicas: 1
EOF
TITLE_AND_MESSAGE="4. Checkpoint: Check custom resource and codes"
git add config $MAIN_GO_FILE && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/04-check-points-check-custom-resource-and-codes/index.md
gsed -i "s/date:.*/date: $(date +"$DATE_FORMAT")/" docs/content/docs/04-check-points-check-custom-resource-and-codes/index.md

echo "
You can check the behavior at this point:
    1. kubectl apply -f config/crd/foos.yaml
    2. go run $MAIN_GO_FILE
    3. kubectl apply -f config/sample/foo.yaml
    4. check logs
    5. kubectl delete -f config/sample/foo.yaml
    6. stop $MAIN_GO_FILE
    7. kubectl delete -f config/crd/foos.yaml
"

# 5. Implement reconciliation loop
gsed -i "s/date:.*/date: $(date +"$DATE_FORMAT")/" docs/content/docs/05-implement-reconciliation-loop/index.md

# 5.1. Create controller
cat <<EOF >> $FOO_CONTROLLER_FILE
package main

import (
	"time"

	clientset "$MODULE_NAME/pkg/generated/clientset/versioned"
	informers "$MODULE_NAME/pkg/generated/informers/externalversions/example.com/v1alpha1"
	listers "$MODULE_NAME/pkg/generated/listers/example.com/v1alpha1"

	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/util/workqueue"
    "k8s.io/klog/v2"
)

type Controller struct {
	// sampleclientset is a clientset for our own API group
	sampleclientset clientset.Interface

	foosSynced cache.InformerSynced // cache is synced for foo
}

func NewController(sampleclientset clientset.Interface, fooInformer informers.FooInformer) *Controller {
	controller := &Controller{
		sampleclientset: sampleclientset,
		foosSynced:      fooInformer.Informer().HasSynced,
	}

	fooInformer.Informer().AddEventHandler(
		cache.ResourceEventHandlerFuncs{
			AddFunc:    controller.handleAdd,
			DeleteFunc: controller.handleDelete,
		},
	)
	return controller
}

func (c *Controller) Run(stopCh chan struct{}) error {
    if ok := cache.WaitForCacheSync(stopCh, c.foosSynced); !ok {
        klog.Info("cache is not synced")
    }

    go wait.Until(c.worker, time.Second, stopCh)

    <-stopCh
    return nil
}

func (c *Controller) worker() {
	c.processNextItem()
}

func (c *Controller) processNextItem() bool {
	return true
}

func (c *Controller) handleAdd(obj interface{}) {
	klog.Info("handleAdd is called")
}

func (c *Controller) handleDelete(obj interface{}) {
	klog.Info("handleDelete is called")
}

EOF

cat<<EOF > $MAIN_GO_FILE
package main

import (
    "flag"
    "path/filepath"
    "time"

    "k8s.io/client-go/tools/clientcmd"
    "k8s.io/client-go/util/homedir"
    "k8s.io/klog/v2"

    clientset "$MODULE_NAME/pkg/generated/clientset/versioned"
    informers "$MODULE_NAME/pkg/generated/informers/externalversions"
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
        klog.Fatalf("error occurred when running controller %s\n", err.Error())
    }
}
EOF

go mod tidy
go fmt ./...
git add pkg go.mod go.sum $FOO_CONTROLLER_FILE $MAIN_GO_FILE
TITLE_AND_MESSAGE="5.1. Create Controller"
git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/05-implement-reconciliation-loop/index.md

# 5.2. Fetch Foo object

# add foosLister and workqueue to Controller
cat <<EOF > tmpfile

// queue
workqueue workqueue.RateLimitingInterface
EOF
gsed -i '/foosSynced cache.InformerSynced/r tmpfile' $FOO_CONTROLLER_FILE # add after
gsed -i '/foosSynced cache.InformerSynced/i foosLister listers.FooLister' $FOO_CONTROLLER_FILE # add before

# init controller
cat <<EOF > tmpfile
		foosLister:      fooInformer.Lister(),
		workqueue:       workqueue.NewNamedRateLimitingQueue(workqueue.DefaultControllerRateLimiter(), "foo"),
EOF
gsed -i '/foosSynced:.*fooInformer.Informer().HasSynced,/r tmpfile' $FOO_CONTROLLER_FILE # add after

# defer workqueue
gsed -i '/func (c \*Controller) Run(stopCh chan struct{}) error {/a defer c.workqueue.ShutDown()' $FOO_CONTROLLER_FILE # add after

# define enqueueFoo
gsed -i '/.*klog.Info("handle.* is called")/a c.enqueueFoo(obj)' $FOO_CONTROLLER_FILE # add after
cat<<EOF >> $FOO_CONTROLLER_FILE

// enqueueFoo takes a Foo resource and converts it into a namespace/name
// string which is then put onto the work queue. This method should *not* be
// passed resources of any type other than Foo.
func (c *Controller) enqueueFoo(obj interface{}) {
    var key string
    var err error
    if key, err = cache.MetaNamespaceKeyFunc(obj); err != nil {
        klog.Errorf("failed to get key from the cache %s\n", err.Error())
        return
    }
    c.workqueue.Add(key)
}
EOF
gsed -i "/^func.*processNextItem() bool {$/,/^$/d" $FOO_CONTROLLER_FILE # delete processNextItem func
cat<<EOF > tmpfile
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
            klog.Errorf("expected string in workqueue but got %#v", obj)
            return nil
        }

        ns, name, err := cache.SplitMetaNamespaceKey(key)
        if err != nil {
            klog.Errorf("failed to split key into namespace and name %s\n", err.Error())
            return err
        }

        // temporary main logic
        foo, err := c.foosLister.Foos(ns).Get(name)
        if err != nil {
            klog.Errorf("failed to get foo resource from lister %s\n", err.Error())
            return err
        }
        klog.Infof("Got foo %+v\n", foo.Spec)

        // Forget the queue item as it's successfully processed and
        // the item will not be requeued.
        c.workqueue.Forget(obj)
        klog.Infof("Successfully synced '%s'", key)
        return nil
    }(obj)

    if err != nil {
        return true
    }

    return true
}

EOF
gsed -i $'/^func.*handleAdd(obj interface{}) {$/{e cat tmpfile\n}' $FOO_CONTROLLER_FILE # add before
go fmt ./...
go vet ./...
TITLE_AND_MESSAGE="5.2. Fetch Foo object"
git add $MAIN_GO_FILE $FOO_CONTROLLER_FILE && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/05-implement-reconciliation-loop/index.md

# 5.3. Create/Delete Deployment for Foo resource

cat <<EOF > tmpfile
    appsinformers "k8s.io/client-go/informers/apps/v1"
    "k8s.io/client-go/kubernetes"
    appslisters "k8s.io/client-go/listers/apps/v1"
EOF
gsed -i '/"k8s.io\/apimachinery\/pkg\/util\/wait"/r tmpfile' $FOO_CONTROLLER_FILE # add after

cat <<EOF > tmpfile
// kubeclientset is a standard kubernetes clientset
kubeclientset kubernetes.Interface
EOF
gsed -i "/^type Controller struct {$/r tmpfile" $FOO_CONTROLLER_FILE # add after

cat <<EOF > tmpfile

deploymentsLister appslisters.DeploymentLister
deploymentsSynced cache.InformerSynced
EOF
gsed -i "/sampleclientset clientset.Interface$/r tmpfile" $FOO_CONTROLLER_FILE # add after

gsed -i 's/^func NewController(.*{/func NewController(/g' $FOO_CONTROLLER_FILE # delete arguments
cat <<EOF > tmpfile
kubeclientset kubernetes.Interface,
sampleclientset clientset.Interface,
deploymentInformer appsinformers.DeploymentInformer,
fooInformer informers.FooInformer) *Controller {
EOF
gsed -i '/^func NewController($/r tmpfile' $FOO_CONTROLLER_FILE # add arguments after the function name

gsed -i "/^.*controller := &Controller{$/,/}$/d" $FOO_CONTROLLER_FILE # delete controller := Controller{...}
cat <<EOF > tmpfile
    controller := &Controller{
      kubeclientset:     kubeclientset,
      sampleclientset:   sampleclientset,
      deploymentsLister: deploymentInformer.Lister(),
      deploymentsSynced: deploymentInformer.Informer().HasSynced,
      foosLister:        fooInformer.Lister(),
      foosSynced:        fooInformer.Informer().HasSynced,
      workqueue:         workqueue.NewNamedRateLimitingQueue(workqueue.DefaultControllerRateLimiter(), "foo"),
    }
EOF
gsed -i '/fooInformer informers.FooInformer).*{$/r tmpfile' $FOO_CONTROLLER_FILE # add after the last line of the function argument

# update $MAIN_GO_FILE
cat <<EOF > tmpfile
	kubeinformers "k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
EOF
gsed -i $'/clientcmd"$/{e cat tmpfile\n}' $MAIN_GO_FILE # add imports before clientcmd

cat <<EOF > tmpfile
	kubeClient, err := kubernetes.NewForConfig(config)
	if err != nil {
		klog.Errorf("getting kubernetes client set %s\n", err.Error())
	}

EOF
gsed -i $'/exampleClient, err :=/{e cat tmpfile\n}' $MAIN_GO_FILE # add before example, err := xxx
echo 'kubeInformerFactory := kubeinformers.NewSharedInformerFactory(kubeClient, time.Second*30)' > tmpfile
gsed -i $'/exampleInformerFactory :=/{e cat tmpfile\n}' $MAIN_GO_FILE # add before exampleInformerFactory :=
cat <<EOF > tmpfile
	controller := NewController(
		kubeClient,
		exampleClient,
		kubeInformerFactory.Apps().V1().Deployments(),
		exampleInformerFactory.Example().V1alpha1().Foos(),
	)
  kubeInformerFactory.Start(stopCh)
EOF
gsed -i 's/.*controller := NewController(exampleClient.*/cat tmpfile/e' $MAIN_GO_FILE # replace controller := xxx


gsed -i "/ns, name, err/,/^$/d" $FOO_CONTROLLER_FILE # remove ns, name, err := xxx if err != nil {}
gsed -i "/\/\/ temporary main logic/,/^$/d" $FOO_CONTROLLER_FILE # remove temporary main logic
cat << EOF > tmpfile
if err := c.syncHandler(key); err != nil {
        // Put the item back on the workqueue to handle any transient errors.
        c.workqueue.AddRateLimited(key)
        return fmt.Errorf("error syncing '%s': %s, requeuing", key, err.Error())
}

EOF
gsed -i $'/Forget the queue item/{e cat tmpfile\n}' $FOO_CONTROLLER_FILE
gsed -i "/DeleteFunc: controller.handleDelete,/d" $FOO_CONTROLLER_FILE # delete DeleteFunc
gsed -i "/func.*handleDelete/,/^$/d" $FOO_CONTROLLER_FILE # delete handleDelete


cat <<EOF > tmpfile

func (c *Controller) syncHandler(key string) error {
    ns, name, err := cache.SplitMetaNamespaceKey(key)
    if err != nil {
        klog.Errorf("failed to split key into namespace and name %s\n", err.Error())
        return err
    }

    foo, err := c.foosLister.Foos(ns).Get(name)
    if err != nil {
        klog.Errorf("failed to get foo resource from lister %s\n", err.Error())
        if errors.IsNotFound(err) {
            return nil
        }
        return err
    }

    deploymentName := foo.Spec.DeploymentName
    if deploymentName == "" {
        klog.Errorf("deploymentName must be specified %s\n", key)
        return nil
    }
    deployment, err := c.deploymentsLister.Deployments(foo.Namespace).Get(deploymentName)
    if errors.IsNotFound(err) {
        deployment, err = c.kubeclientset.AppsV1().Deployments(foo.Namespace).Create(context.TODO(), newDeployment(foo), metav1.CreateOptions{})
    }

    if err != nil {
        return err
    }

    klog.Infof("deployment %s is valid", deployment.Name)

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
EOF
cat tmpfile >> $FOO_CONTROLLER_FILE # add after the last line of the function argument

cat <<EOF > tmpfile
    "context"
    "fmt"
EOF
gsed -i '/import (/r tmpfile' $FOO_CONTROLLER_FILE # add after import (
cat <<EOF > tmpfile
    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/api/errors"
EOF
gsed -i '/"k8s.io\/apimachinery\/pkg\/util\/wait"/r tmpfile' $FOO_CONTROLLER_FILE # add after
cat <<EOF > tmpfile
    samplev1alpha1 "$MODULE_NAME/pkg/apis/example.com/v1alpha1"
EOF
gsed -i '/clientset "github.com/r tmpfile' $FOO_CONTROLLER_FILE # add after

go fmt ./...
go vet ./...
TITLE_AND_MESSAGE="5.3. Create/Delete Deployment for Foo resource"
git add $MAIN_GO_FILE $FOO_CONTROLLER_FILE && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/05-implement-reconciliation-loop/index.md

# 5.4. Check and update Deployment if necessary

cat <<EOF > tmpfile
const (
    // MessageResourceExists is the message used for Events when a resource
    // fails to sync due to a Deployment already existing
    MessageResourceExists = "Resource %q already exists and is not managed by Foo"
)

EOF
gsed -i $'/type Controller struct {/{e cat tmpfile\n}' $FOO_CONTROLLER_FILE # add before

cat <<EOF > tmpfile
    // If the Deployment is not controlled by this Foo resource, we should log
    // a warning to the event recorder and return error msg.
    if !metav1.IsControlledBy(deployment, foo) {
        msg := fmt.Sprintf(MessageResourceExists, deployment.Name)
        klog.Info(msg)
        return fmt.Errorf("%s", msg)
    }

    // If this number of the replicas on the Foo resource is specified, and the
    // number does not equal the current desired replicas on the Deployment, we
    // should update the Deployment resource.
    if foo.Spec.Replicas != nil && *foo.Spec.Replicas != *deployment.Spec.Replicas {
        klog.Infof("Foo %s replicas: %d, deployment replicas: %d\n", name, *foo.Spec.Replicas, *deployment.Spec.Replicas)
        deployment, err = c.kubeclientset.AppsV1().Deployments(foo.Namespace).Update(context.TODO(), newDeployment(foo), metav1.UpdateOptions{})
    }

    // If an error occurs during Update, we'll requeue the item so we can
    // attempt processing again later. This could have been caused by a
    // temporary network failure, or any other transient reason.
    if err != nil {
        return err
    }

EOF

gsed -i $'/klog.Infof("deployment %s is valid", deployment.Name)/{e cat tmpfile\n}' $FOO_CONTROLLER_FILE # add before
gsed -i '/.*klog.Infof("deployment %s is valid", deployment.Name)/,/^$/d' $FOO_CONTROLLER_FILE # delete log
cat <<EOF > tmpfile
    AddFunc: controller.enqueueFoo,
    UpdateFunc: func(old, new interface{}) {
            controller.enqueueFoo(new)
    },
EOF
gsed -i 's/.*AddFunc: controller.handleAdd,/cat tmpfile/e' $FOO_CONTROLLER_FILE # replace with tmpfile
gsed -i "/^func.*handleAdd(obj interface{}) {$/,/^$/d" $FOO_CONTROLLER_FILE # delete handleAdd function
go fmt ./...
go vet ./...
TITLE_AND_MESSAGE="5.4. Check and update Deployment if necessary"
git add $MAIN_GO_FILE $FOO_CONTROLLER_FILE && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/05-implement-reconciliation-loop/index.md

# 5.5. Update Foo status

cat <<EOF > tmpfile

func (c *Controller) updateFooStatus(foo *samplev1alpha1.Foo, deployment *appsv1.Deployment) error {
    // NEVER modify objects from the store. It's a read-only, local cache.
    // You can use DeepCopy() to make a deep copy of original object and modify this copy
    // Or create a copy manually for better performance
    fooCopy := foo.DeepCopy()
    fooCopy.Status.AvailableReplicas = deployment.Status.AvailableReplicas
    // If the CustomResourceSubresources feature gate is not enabled,
    // we must use Update instead of UpdateStatus to update the Status block of the Foo resource.
    // UpdateStatus will not allow changes to the Spec of the resource,
    // which is ideal for ensuring nothing other than resource status has been updated.
    _, err := c.sampleclientset.ExampleV1alpha1().Foos(foo.Namespace).UpdateStatus(context.TODO(), fooCopy, metav1.UpdateOptions{})
    return err
}
EOF

cat tmpfile >> $FOO_CONTROLLER_FILE

# add updateFooStatus after temporary network failure ...
gsed -i '/\/\/ temporary network failure, or any other transient reason/,/}/c \
	// temporary network failure, or any other transient reason.\
	if err != nil {\
		return err\
	}\
\
	// Finally, we update the status block of the Foo resource to reflect the\
	// current state of the world\
	err = c.updateFooStatus(foo, deployment)\
	if err != nil {\
        klog.Errorf("failed to update Foo status for %s", foo.Name)\
		return err\
	}\
' $FOO_CONTROLLER_FILE

# add subresources to crd
yq -i '.spec.versions[0].subresources |= {"status": {}}' $FOO_CRD_FILE
go fmt ./...
TITLE_AND_MESSAGE="5.5. Update Foo status"
git add $FOO_CRD_FILE $FOO_CONTROLLER_FILE && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/05-implement-reconciliation-loop/index.md

# 5.6. Capture the update of Deployment

cat <<EOF >> $FOO_CONTROLLER_FILE

    // handleObject will take any resource implementing metav1.Object and attempt
    // to find the Foo resource that 'owns' it. It does this by looking at the
    // objects metadata.ownerReferences field for an appropriate OwnerReference.
    // It then enqueues that Foo resource to be processed. If the object does not
    // have an appropriate OwnerReference, it will simply be skipped.
    func (c *Controller) handleObject(obj interface{}) {
        var object metav1.Object
        var ok bool
        if object, ok = obj.(metav1.Object); !ok {
            tombstone, ok := obj.(cache.DeletedFinalStateUnknown)
            if !ok {
                return
            }
            object, ok = tombstone.Obj.(metav1.Object)
            if !ok {
                return
            }
            klog.Infof("Recovered deleted object '%s' from tombstone", object.GetName())
        }
        klog.Infof("Processing object: %s", object.GetName())
        if ownerRef := metav1.GetControllerOf(object); ownerRef != nil {
            // If this object is not owned by a Foo, we should not do anything more
            // with it.
            if ownerRef.Kind != "Foo" {
                return
            }

            foo, err := c.foosLister.Foos(object.GetNamespace()).Get(ownerRef.Name)
            if err != nil {
                klog.Errorf("ignoring orphaned object '%s' of foo '%s'", object.GetSelfLink(), ownerRef.Name)
                return
            }

            c.enqueueFoo(foo)
            return
        }
    }
EOF

cat <<EOF > tmpfile
    // Set up an event handler for when Deployment resources change. This
    // handler will lookup the owner of the given Deployment, and if it is
    // owned by a Foo resource then the handler will enqueue that Foo resource for
    // processing. This way, we don't need to implement custom logic for
    // handling Deployment resources. More info on this pattern:
    // https://github.com/kubernetes/community/blob/8cafef897a22026d42f5e5bb3f104febe7e29830/contributors/devel/controllers.md
    deploymentInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc: controller.handleObject,
        UpdateFunc: func(old, new interface{}) {
            newDepl := new.(*appsv1.Deployment)
            oldDepl := old.(*appsv1.Deployment)
            if newDepl.ResourceVersion == oldDepl.ResourceVersion {
                // Periodic resync will send update events for all known Deployments.
                // Two different versions of the same Deployment will always have different RVs.
                return
            }
            controller.handleObject(new)
        },
        DeleteFunc: controller.handleObject,
    })

EOF
gsed -i $'/.*return controller/{e cat tmpfile\n}' $FOO_CONTROLLER_FILE # add before
go fmt ./...
go vet ./...
TITLE_AND_MESSAGE="5.6. Capture the update of Deployment"
git add $FOO_CONTROLLER_FILE && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/05-implement-reconciliation-loop/index.md

# 5.7. Create events for Foo resource

cat <<EOF > tmpfile

    // recorder is an event recorder for recording Event resources to the
    // Kubernetes API.
    recorder record.EventRecorder
EOF
gsed -i '/.*workqueue workqueue.RateLimitingInterface/r tmpfile' $FOO_CONTROLLER_FILE # add after

cat <<EOF > tmpfile

    eventBroadcaster := record.NewBroadcaster()
    eventBroadcaster.StartStructuredLogging(0)
    eventBroadcaster.StartRecordingToSink(&typedcorev1.EventSinkImpl{Interface: kubeclientset.CoreV1().Events("")})
    recorder := eventBroadcaster.NewRecorder(scheme.Scheme, corev1.EventSource{Component: controllerAgentName})
EOF
gsed -i '/.*fooInformer informers.FooInformer) \*Controller {/r tmpfile' $FOO_CONTROLLER_FILE # add after
gsed -i '/.*workqueue:.*workqueue.NewNamedRateLimitingQueue(workqueue.DefaultControllerRateLimiter(), "foo"),/a recorder: recorder,' $FOO_CONTROLLER_FILE # add after
# import necessary packages
gsed -i '/.*appsinformers "k8s.io\/client-go\/informers\/apps\/v1"/a typedcorev1 "k8s.io\/client-go\/kubernetes\/typed\/core\/v1"' $FOO_CONTROLLER_FILE # add typedcorev1 after *appsinformers "k8s.io\/client-go\/informers\/apps\/v1"
gsed -i '/.*appsinformers "k8s.io\/client-go\/informers\/apps\/v1"/a "k8s.io\/client-go\/tools\/record"' $FOO_CONTROLLER_FILE # add client-go/tools/record after *appsinformers "k8s.io\/client-go\/informers\/apps\/v1"
gsed -i '/.*informers "github.com/a "github.com\/nakamasato\/sample-controller\/pkg\/generated\/clientset\/versioned\/scheme"' $FOO_CONTROLLER_FILE # add "$MODULE_NAME/pkg/generated/clientset/versioned/scheme" after informers "$MODULE_NAME/pkg/generated/informers/externalversions/example.com/v1alpha1"
go mod tidy

# add constants

cat <<EOF > tmpfile
    // SuccessSynced is used as part of the Event 'reason' when a Foo is synced
    SuccessSynced = "Synced"
    // ErrResourceExists is used as part of the Event 'reason' when a Foo fails
    // to sync due to a Deployment of the same name already existing.
    ErrResourceExists = "ErrResourceExists"

EOF
gsed -i '/.*const (/r tmpfile' $FOO_CONTROLLER_FILE # add after

cat <<EOF > tmpfile

	// MessageResourceSynced is the message used for an Event fired when a Foo
	// is synced successfully
	MessageResourceSynced = "Foo synced successfully"
EOF
gsed -i '/MessageResourceExists =/r tmpfile' $FOO_CONTROLLER_FILE # add after

cat <<EOF > tmpfile
const controllerAgentName = "sample-controller"

EOF
gsed -i $'/const (/{e cat tmpfile\n}' $FOO_CONTROLLER_FILE # add before

gsed -i '/msg := fmt.Sprintf(MessageResourceExists, deployment.Name)/a c.recorder.Event(foo, corev1.EventTypeWarning, ErrResourceExists, msg)' $FOO_CONTROLLER_FILE # add after

# add c.recorder.Event at the end of syncHandler
gsed -i '/err = c.updateFooStatus(foo, deployment)/,/^}/c \
	err = c.updateFooStatus(foo, deployment)\
	if err != nil {\
		klog.Errorf("failed to update Foo status for %s", foo.Name)\
		return err\
	}\
\
    c.recorder.Event(foo, corev1.EventTypeNormal, SuccessSynced, MessageResourceSynced)\
	return nil\
}' $FOO_CONTROLLER_FILE
go fmt ./...
go vet ./...
TITLE_AND_MESSAGE="5.7. Create events for Foo resource"
git add go.mod go.sum $FOO_CONTROLLER_FILE && git commit -m "$TITLE_AND_MESSAGE"
commit_hash=$(git rev-parse HEAD)
gsed -i "s#\[$TITLE_AND_MESSAGE\].*#[$TITLE_AND_MESSAGE]($REPO_URL/commit/$commit_hash)#" docs/content/docs/05-implement-reconciliation-loop/index.md
git add docs && git commit -m "docs: Update docs links"
