/*
Copyright 2025.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package ignition

import (
	"encoding/base64"
	"encoding/json"
	"fmt"

	igntypes "github.com/coreos/ignition/v2/config/v3_4/types"
	dpuprovisioningv1alpha1 "github.com/nvidia/doca-platform/api/provisioning/v1alpha1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"sigs.k8s.io/yaml"
)

// cleanDPUFlavor returns a copy with only apiVersion, kind, name, namespace, and spec.
func cleanDPUFlavor(flavor *dpuprovisioningv1alpha1.DPUFlavor) *dpuprovisioningv1alpha1.DPUFlavor {
	return &dpuprovisioningv1alpha1.DPUFlavor{
		TypeMeta: flavor.TypeMeta,
		ObjectMeta: metav1.ObjectMeta{
			Name:      flavor.Name,
			Namespace: flavor.Namespace,
		},
		Spec: flavor.Spec,
	}
}

// AddDPUFlavorYAML serializes the DPU Flavor CR as YAML and adds it as /etc/dpf/dpuflavor.yaml
func AddDPUFlavorYAML(ign *igntypes.Config, flavor *dpuprovisioningv1alpha1.DPUFlavor) error {
	data, err := yaml.Marshal(cleanDPUFlavor(flavor))
	if err != nil {
		return fmt.Errorf("failed to marshal DPU flavor: %w", err)
	}
	return addDPUFlavorFile(ign, data, "/etc/dpf/dpuflavor.yaml")
}

// AddDPUFlavorJSON serializes the DPU Flavor CR as JSON and adds it as /etc/dpf/dpuflavor.json
func AddDPUFlavorJSON(ign *igntypes.Config, flavor *dpuprovisioningv1alpha1.DPUFlavor) error {
	data, err := json.Marshal(cleanDPUFlavor(flavor))
	if err != nil {
		return fmt.Errorf("failed to marshal DPU flavor: %w", err)
	}
	return addDPUFlavorFile(ign, data, "/etc/dpf/dpuflavor.json")
}

func addDPUFlavorFile(ign *igntypes.Config, data []byte, path string) error {
	encoded := base64.StdEncoding.EncodeToString(data)
	source := fmt.Sprintf("data:text/plain;charset=utf-8;base64,%s", encoded)

	file := igntypes.File{
		Node: igntypes.Node{
			Path:      path,
			Overwrite: Ptr(true),
		},
		FileEmbedded1: igntypes.FileEmbedded1{
			Mode: Ptr(0644),
			Contents: igntypes.Resource{
				Source: &source,
			},
		},
	}

	ign.Storage.Files = append(ign.Storage.Files, file)
	return nil
}
