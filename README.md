# Porter Argo Demo

<div>
  <style>
    table {
      border-collapse: collapse;
    }

    td {
      border: none;
      padding: 10px;
    }
  </style>
  <table>
    <tr>
      <td>
        <img src="./docs/imgs/porter-logo.png" alt="Porter Logo" width="100">
      </td>
      <td>
        <img src="./docs/imgs/argo_workflows_logo.png" alt="Argo Workflows Logo" width="100">
      </td>
    </tr>
  </table>
</div>

NOTE: This project is a work-in-progress please reach out with any feedback.

The [Porter Operator](https://github.com/getporter/operator) 
and [Argo Workflows](https://github.com/argoproj/argo-workflows/) working side by side. To quickly 
see the power of these two project working together just clone this repo and
deploy locally.

```
git clone https://github.com/bdegeeter/porter-argo-demo
cd porter-argo-demo
make deploy
```

The default `make deploy` target installs all tool dependencies in the `.tools` directory
and creates a local [KinD](https://kind.sigs.k8s.io/) cluster. It then deploys 
the [Porter Operator](https://getporter.org/operator/),
[Argo Workflows](https://argoproj.github.io/argo-workflows/) and a demo:w
[Argo WorkflowTemplate](https://argoproj.github.io/argo-workflows/workflow-templates/).
The workflow template creates a [Porter Operator Installation](https://getporter.org/operator/file-formats/)
resource.

There's some additional make targets for submitting a demo workflow for the template and getting
the installation outputs from the Porter bundle.

You can also submit a workflow and watch it execute via the Argo WebUI at https://porter-argo.localtest.me/workflows

```
make argo-submit-workflow
make argo-get-latest-output
```

Any bundle can be run by this Argo Workflow using the `porterBundleRepo` and `porterBundleVersion` parameters.
Required [CredentialSets](https://getporter.org/operator/file-formats/#credentialset) must 
be created in advance and referenced via a JSON list `[ "my-cred-set" ]`. Parameters must 
be a valid JSON object `{ "delay": "3", "exitStatus": "0" }`