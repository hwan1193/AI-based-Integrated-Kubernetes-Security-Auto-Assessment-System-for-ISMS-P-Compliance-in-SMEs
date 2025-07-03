# AI-based-Integrated-Kubernetes-Security-Auto-Assessment-System-for-ISMS-P-Compliance-in-SMEs
# 📌 중소기업 대상 ISMS-P 대응 AI 기반 쿠버네티스 통합 보안 자동 진단 시스템
## 📝 개요  
본 프로젝트는 쿠버네티스 클러스터를 대상으로 정적 분석(Kube-bench, Anchore)과 동적 분석(Suricata, Filebeat, Falco)을 통합하여 자동으로 보안 진단을 수행하는 시스템입니다.  
중소기업(SME)이 수작업 없이도 ISMS-P 보안 요구사항을 충족할 수 있도록 설계되었습니다.

## 🎯 주요 목표  
- ✅ 원클릭 보안 자동 진단 제공  
- ✅ 실시간 네트워크 위협 및 설정 오류 시각화  
- ✅ ISMS-P 보안 통제항목 대응을 위한 점검  
- ✅ AI 기반 피드백 및 자동 스크립트 배포 기능 통합

## 🧱 시스템 아키텍처  
![image](https://github.com/user-attachments/assets/1aecff0e-c401-4623-8ef2-84e4d9933fd5)

<설명: 정적/동적 분석 → 결과 분류 → 자동화 스크립트 → AI 모듈 → Master/Worker 노드 실행 → Kibana 시각화>

![image](https://github.com/user-attachments/assets/568621ea-5a75-4498-9043-179c476eb507)

![image](https://github.com/user-attachments/assets/31dc6757-7bb9-4d57-b552-92491826fd51)

![image](https://github.com/user-attachments/assets/3d3d510f-afa3-4e1d-b5e4-fb658b289fb3)

![image](https://github.com/user-attachments/assets/97a78d71-a8a5-4854-a1fd-13853669e27c)

![image](https://github.com/user-attachments/assets/cb67fc9d-49ff-4bc3-9270-85db302902e9)
## 🔐 사용된 보안 도구  

| 도구               | 유형       | 역할                                                                 |
|--------------------|------------|----------------------------------------------------------------------|
| Kube-bench         | 정적 분석  | CIS Kubernetes 기준 준수 여부 점검                                  |
| Anchore Engine     | 정적 분석  | 컨테이너 이미지 보안 및 정책 점검                                   |
| Kube-escape        | 정적 분석  | 권한 상승 및 보안 설정 취약점 탐지                                  |
| Suricata           | 동적 분석  | 네트워크 기반 실시간 위협 탐지 (IDS/IPS)                            |
| Filebeat           | 동적 분석  | 경량 로그 수집기                                                     |
| Kibana             | 동적 분석  | 로그 시각화 및 실시간 모니터링 대시보드                             |
| Falco              | 동적 분석  | 런타임 행위 기반 보안 위협 탐지                                     |
| Helm               | 배포 도구  | 쿠버네티스 앱 설치 및 정책 적용 자동화                              |

## ⚙️ 작동 방식  

1. 정적 및 동적 보안 분석 수행  
2. 중앙 결과 분류 시스템  
3. AI 모듈 기반 자동 스크립트 실행  
4. Kubernetes DaemonSet을 통한 자동 배포  
5. Kibana를 통한 시각화 및 실시간 알림

# HTML 보고서
http://223.130.138.26:5000/

![image](https://github.com/user-attachments/assets/907c259d-9846-4235-a988-b302880aa379)

![image](https://github.com/user-attachments/assets/e5f8c66a-9f9a-4457-b9cb-810ef0bb329f)

![image](https://github.com/user-attachments/assets/65cd6e6a-537f-4d4a-8f56-6f23ef36a9e4)

![image](https://github.com/user-attachments/assets/ad4f27b4-6f67-4849-b07f-c19f730c542b)

## 🚀 빠른 시작 예시

```bash
# kube-bench 배포
kubectl apply -f job-kube-bench.yaml

# filebeat 배포
kubectl apply -f filebeat-kube-bench.yaml

# 로그 확인
kubectl logs -n kube-system -l app=kube-bench




![image](https://github.com/user-attachments/assets/ac69c267-1e00-453b-bb20-c52d08380863)




