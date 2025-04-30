#!/bin/bash

# 에러 핸들링 함수
run_or_exit() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "[!] 에러 발생: '$*' 명령 실행 실패 (코드 $status)" >&2
        echo "[!] 다시 시도하세요." >&2
        exit 1
    fi
}

# 기본 변수 설정
DEFAULT_NAMESPACE="kube-system"
DEFAULT_VALUES_FILE="./falco-values.yaml"

echo "======================================"
echo "  [ Suricata / Falco / Filebeat 설치 스크립트 ]"
echo "======================================"
echo ""

# 설치할 대상 선택
echo "설치할 대상을 선택하세요:"
select TARGET in "suricata" "falco" "filebeat" "전체 설치"; do
    if [[ -n "$TARGET" ]]; then
        echo "[+] 선택한 대상: $TARGET"
        break
    else
        echo "[!] 유효한 선택이 아닙니다. 다시 선택하세요."
    fi
done

# Namespace 입력받기
read -p "Kubernetes Namespace를 입력하세요 (기본값: $DEFAULT_NAMESPACE): " NAMESPACE
NAMESPACE=${NAMESPACE:-$DEFAULT_NAMESPACE}
echo "[+] 선택된 Namespace: $NAMESPACE"

export NAMESPACE

# --------- 공통 함수들 정의 -----------

install_suricata() {
    echo "[+] Suricata 설치 시작..."

    NODE_IP=$(ip -o -4 addr show | grep -v '127.0.0.1' | awk '{print $4}' | head -n1)
    if [ -z "$NODE_IP" ]; then
        echo "[!] 노드 IP를 가져오지 못했습니다. 관리자에게 문의하세요." >&2
        exit 1
    fi
    HOME_NET=$NODE_IP
    echo "[+] HOME_NET 자동 설정: $HOME_NET"

    INTERFACE=$(ip -o -4 route show to default | awk '{print $5}' | sort | uniq | head -n1)
    if [ -z "$INTERFACE" ]; then
        echo "[!] 네트워크 인터페이스를 감지하지 못했습니다. 관리자에게 문의하세요." >&2
        exit 1
    fi
    echo "[+] 감지된 인터페이스: $INTERFACE"

    export HOME_NET
    export INTERFACE

    echo "[+] 기존 Suricata 리소스 삭제..."
    kubectl delete configmap suricata-config -n "$NAMESPACE" --ignore-not-found
    kubectl delete daemonset suricata -n "$NAMESPACE" --ignore-not-found

    echo "[+] Suricata ConfigMap 생성 및 적용..."
    run_or_exit envsubst < suricata-config-template.yaml > suricata-config.yaml
    run_or_exit kubectl apply -f suricata-config.yaml -n "$NAMESPACE"

    echo "[+] Suricata DaemonSet 생성 및 적용..."
    run_or_exit envsubst < suricata-daemonset-template.yaml > suricata-daemonset.yaml
    run_or_exit kubectl apply -f suricata-daemonset.yaml -n "$NAMESPACE"

    echo "[+] Suricata DaemonSet 롤아웃 재시작..."
    run_or_exit kubectl rollout restart daemonset suricata -n "$NAMESPACE"
}

install_filebeat() {
    echo "[+] Filebeat 설치 시작..."

    echo "[+] 기존 Filebeat 리소스 삭제..."
    kubectl delete configmap filebeat-config -n "$NAMESPACE" --ignore-not-found
    kubectl delete daemonset filebeat -n "$NAMESPACE" --ignore-not-found
    kubectl delete serviceaccount filebeat -n "$NAMESPACE" --ignore-not-found

    echo "[+] Filebeat ConfigMap 생성 및 적용..."
    run_or_exit envsubst < filebeat-template.yaml > filebeat.yaml
    run_or_exit kubectl apply -f filebeat.yaml -n "$NAMESPACE"

    echo "[+] Filebeat DaemonSet 롤아웃 재시작..."
    if ! kubectl rollout restart daemonset filebeat -n "$NAMESPACE"; then
        echo "[!] Filebeat DaemonSet 롤아웃 재시작 실패, 계속 진행합니다. (수동 확인 필요)"
    fi

    echo "[+] Filebeat DaemonSet 상태 확인..."
    if ! kubectl rollout status daemonset/filebeat -n "$NAMESPACE" --timeout=60s; then
        echo "[!] Filebeat DaemonSet 롤아웃 상태 확인 실패 (시간 초과)"
        echo "[+] 실제 Pod 상태를 확인합니다..."

        FILEBEAT_PODS_STATUS=$(kubectl get pods -n "$NAMESPACE" -l k8s-app=filebeat -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase}{"\n"}{end}')
        echo "$FILEBEAT_PODS_STATUS"

        if echo "$FILEBEAT_PODS_STATUS" | grep -qv "Running"; then
            echo "[!] 일부 Filebeat Pod가 Running 상태가 아닙니다. 다시 시도하세요."
            exit 1
        else
            echo "[+] 모든 Filebeat Pod가 정상 Running 상태입니다."
        fi
    fi
}

install_falco() {
    echo "[+] Falco 설치 시작..."

    if ! command -v helm &> /dev/null; then
        echo "[+] Helm 설치 진행 중..."
        curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
        if [ $? -ne 0 ]; then
            echo "[!] Helm 설치 실패"
            exit 1
        fi
    else
        echo "[+] Helm 이미 설치됨."
    fi

    echo "[+] 기존 Falco 삭제..."
    helm uninstall falco -n "$NAMESPACE" --wait --timeout 60s || true
    kubectl delete daemonset falco -n "$NAMESPACE" --ignore-not-found

    if ! helm repo list | grep -q falcosecurity; then
        echo "[+] falcosecurity Helm 리포지토리 추가 중..."
        helm repo add falcosecurity https://falcosecurity.github.io/charts
    fi
    echo "[+] Helm 리포지토리 업데이트..."
    run_or_exit helm repo update

    NODE_STATUS=$(kubectl get nodes --no-headers | awk '{print $2}' | uniq)
    if [ "$NODE_STATUS" != "Ready" ]; then
        echo "[!] 노드 상태가 Ready가 아닙니다: $NODE_STATUS"
        exit 1
    fi

    if [ ! -f "$DEFAULT_VALUES_FILE" ]; then
        echo "[!] $DEFAULT_VALUES_FILE 파일이 존재하지 않습니다."
        exit 1
    fi

    echo "[+] Falco Helm 설치 진행 중..."
    helm upgrade --install falco falcosecurity/falco \
      --namespace "$NAMESPACE" \
      --create-namespace \
      -f "$DEFAULT_VALUES_FILE" \
      --wait --timeout 120s

    if [ $? -ne 0 ]; then
        echo "[!] Falco 설치 실패"
        exit 1
    fi

    echo "[+] Falco DaemonSet 상태 확인..."
    if ! kubectl rollout status daemonset/falco -n "$NAMESPACE" --timeout=60s; then
        echo "[!] Falco DaemonSet 롤아웃 상태 확인 실패 (시간 초과)"
        echo "[!] 계속 진행합니다. 수동으로 Pod 상태 확인 바랍니다."
    fi
}

# --------- 선택에 따른 실행 -----------

if [ "$TARGET" == "suricata" ]; then
    install_suricata

elif [ "$TARGET" == "filebeat" ]; then
    install_filebeat

elif [ "$TARGET" == "falco" ]; then
    install_falco

elif [ "$TARGET" == "전체 설치" ]; then
    echo "[+] 전체 설치 시작: suricata -> falco -> filebeat"
    install_suricata
    install_falco
    install_filebeat
fi

# --------- 완료 메시지 -----------

echo ""
date
echo "======================================"
echo "[+] $TARGET 설치 완료!"
echo "======================================"
