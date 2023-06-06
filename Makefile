INCLUDE_DIR=make
NAME=porter-argo-demo
NAMESPACE=demo
#TODO (bdegeeter): support azure, aws, gcp and local (kind)
CLOUD=local
KIND_INGRESS_DIR=deploy/k8s-ingress-nginx/overlays/kind/default-ingress-secret
KIND_INGRESS_CRT=$(KIND_INGRESS_DIR)/kind-tls.crt
KIND_INGRESS_KEY=$(KIND_INGRESS_DIR)/kind-tls.key
KIND_INGRESS_DOMAIN=porter-argo.localtest.me

include $(INCLUDE_DIR)/Makefile.tools

$(KIND_INGRESS_CRT): $(KIND_INGRESS_KEY)
	openssl req -new -x509 -key $(KIND_INGRESS_KEY) -out $(KIND_INGRESS_CRT) -days 365 -subj "/CN=$(KIND_INGRESS_DOMAIN)"

$(KIND_INGRESS_KEY):
	openssl genpkey -algorithm RSA -out $(KIND_INGRESS_KEY) -pkeyopt rsa_keygen_bits:2048

.PHONY: deploy
deploy: | $(ARGO) $(if $(findstring $(CLOUD),local), $(KIND_INGRESS_CRT) kind-create-cluster)
	@echo "\ndeploy nginx-ingress to $(CLOUD)"
	$(KCTL_CMD) apply -k deploy/k8s-ingress-nginx/overlays/kind
	$(KCTL_CMD) wait deployment -n nginx-ingress ingress-nginx-controller --for condition=Available=True --timeout=600s

	@echo "\ndeploy cert-manager to $(CLOUD)"
	$(KCTL_CMD) apply -k deploy/cert-manager/overlays/kind
	$(KCTL_CMD) wait deployment -n cert-manager cert-manager cert-manager-webhook --for condition=Available=True --timeout=600s

	@echo "\ndeploy open-telemetry to $(CLOUD)"
	$(KCTL_CMD) apply -k deploy/otel/overlays/kind || true
	$(KCTL_CMD) wait deployment -n otel opentelemetry-operator-controller-manager --for condition=Available=True --timeout=600s
	$(KCTL_CMD) apply -k deploy/otel/overlays/kind
	$(KCTL_CMD) wait deployment -n otel opentelemetry-operator-controller-manager --for condition=Available=True --timeout=600s

	@echo "\ndeploy jaeger to $(CLOUD)"
	$(KCTL_CMD) apply -k deploy/jaeger/overlays/kind || true
	$(KCTL_CMD) wait deployment -n otel jaeger-operator --for condition=Available=True --timeout=600s
	$(KCTL_CMD) apply -k deploy/jaeger/overlays/kind
	$(KCTL_CMD) wait deployment -n otel jaeger-operator --for condition=Available=True --timeout=600s

	@echo "\ndeploy porter, argo and demo to $(CLOUD)"
	# Double deploy to load CRDs if they are being loaded for the first time
	$(KCTL_CMD) get crd/installations.getporter.org crd/workflows.argoproj.io || $(KCTL_CMD) apply -k deploy/$(CLOUD) || true 
	$(KCTL_CMD) apply -k deploy/$(CLOUD)
	$(KCTL_CMD) wait deployment -n $(NAMESPACE) argo-server porter-operator-controller-manager --for condition=Available=True --timeout=600s
ifeq ($(CLOUD),local)
	@echo
	@echo "Use https://porter-argo.localtest.me to access Argo WebUI"
	@echo "Use https://porter-argo.localtest.me/tracing to access Jaeger WebUI"
	@echo
endif

.PHONY: test-installation
test-installation:
	$(KCTL_CMD) apply -n demo -f deploy/demo/test-installation.yaml

.PHONY: argo-submit-workflow
argo-submit-workflow:
	@$(ARGO_CMD) -n $(NAMESPACE) submit --from workflowtemplate/porter-install-demo -p deployName=test-install-$(shell date +%s) --watch

.PHONY: argo-get-latest-workflow
argo-get-latest:
	@$(ARGO_CMD) -n $(NAMESPACE) get @latest 

.PHONY: argo-get-latest-output
argo-get-latest-output: | $(JQ)
	@$(ARGO_CMD) -n $(NAMESPACE) get @latest -o json | $(JQ) -r '.status.nodes[] | select(.displayName == "porter-installation-outputs-grpc") | .outputs.parameters[] | select(.name == "porterOutputs") | .value' |base64 -d

.PHONY: k9s
k9s: | $(K9S)
	$(K9S_CMD)

.PHONY: clean
clean: | clean-tools
