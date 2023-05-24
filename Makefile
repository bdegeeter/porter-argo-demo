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
deploy: | $(if $(findstring $(CLOUD),local), $(KIND_INGRESS_CRT) kind-create-cluster)
	@echo "deploy to $(CLOUD)"
	# Double deploy to load CRDs if they are being loaded for the first time
	$(KCTL_CMD) get crd/installations.getporter.org crd/workflows.argoproj.io || $(KCTL_CMD) apply -k deploy/$(CLOUD) || true 
	$(KCTL_CMD) apply -k deploy/$(CLOUD)
	$(KCTL_CMD) wait deployment -n $(NAMESPACE) argo-server porter-operator-controller-manager ingress-nginx-controller --for condition=Available=True --timeout=600s
ifeq ($(CLOUD),local)
	@echo "\nUse https://porter-argo.localtest.me to access Argo WebUI\n"
endif

.PHONY: test-installation
test-installation:
	$(KCTL_CMD) apply -n demo -f deploy/demo/test-installation.yaml


.PHONY: k9s
k9s: | $(K9S)
	$(K9S_CMD)

.PHONY: clean
clean: | clean-tools
