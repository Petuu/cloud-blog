# Cloud Blog — 프로젝트 전체 정리 문서



## 한 줄 요약

> "네이버/티스토리 같은 블로그 서비스를 AWS EKS 위에 직접 설계하고 구축한 프로젝트.
> HA 3-Tier 아키텍처, Terraform IaC, Docker + EKS 컨테이너 오케스트레이션,
> GitHub Actions CI/CD, Prometheus + Grafana 모니터링을 전부 경험하는 신입 취업 포트폴리오."

---

## 기본 정보

| 항목 | 내용 |
|------|------|
| 프로젝트 이름 | Cloud Blog |
| 목적 | 신입 클라우드/인프라 엔지니어 취업 포트폴리오 |
| GitHub | https://github.com/Petuu/cloud-blog |
| AWS 리전 | ap-northeast-2 (서울) |
| AWS 예산 | $100 크레딧 이내 |
| 개발 환경 | Windows 11 + WSL2 (Ubuntu) |
| 작업자 | 장재엽 (96년생, 경일대 컴공) |
| 보유 자격증 | CCNA, AWS SAA, VMware VCP-NV |

---

## 왜 이 프로젝트인가

블로그라는 누구나 아는 도메인을 사용해서 앱 로직 설명 없이 인프라 구성에만 집중할 수 있음.
"네이버 블로그처럼 생긴 서비스를 AWS에서 직접 구축했습니다"라는 설명이 면접관에게 바로 통함.
방문자 수 실시간 모니터링 기능을 추가해서 Prometheus 커스텀 메트릭과 Grafana 대시보드까지 자연스럽게 연결.

---

## 앱 기능 (최소화 — 인프라 집중)

| 기능 | 설명 |
|------|------|
| 글 목록 조회 | GET /posts — 전체 블로그 글 목록 반환 |
| 글 상세 조회 | GET /posts/{id} — 글 내용 + 조회수 +1 |
| 글 작성 | POST /posts — 관리자만 가능 |
| 방문자 메트릭 | GET /metrics — Prometheus 스크래핑용 |
| 헬스체크 | GET /health — K8s Probe용 |

회원가입, 댓글, 좋아요 등 부가 기능 없음. 인프라에 집중.

---

## 전체 아키텍처

### 3-Tier 구성

```
[Presentation Tier]
사용자 → Route53(DNS) → ALB(로드밸런서, Multi-AZ)

[Application Tier]
ALB → EKS 워커 노드 (t3.small × 2, AZ-a + AZ-c)
      └── FastAPI 파드 (블로그 API + /metrics 엔드포인트)
      └── Prometheus 파드 (메트릭 수집)
      └── Grafana 파드 (대시보드 시각화)

[Data Tier]
FastAPI → RDS PostgreSQL (t3.micro, Multi-AZ)
          Primary (AZ-a) + Read Replica (AZ-c)
```

### AWS 인프라 구성

```
ap-northeast-2 (서울 리전)
│
├── VPC (10.0.0.0/16)
│   │
│   ├── Public Subnet (AZ-a: 10.0.101.0/24, AZ-c: 10.0.102.0/24)
│   │   ├── ALB (Application Load Balancer)
│   │   ├── NAT Gateway (프라이빗 서브넷 인터넷 출구)
│   │   └── Internet Gateway
│   │
│   └── Private Subnet (AZ-a: 10.0.1.0/24, AZ-c: 10.0.2.0/24)
│       ├── EKS Worker Node × 2 (t3.small)
│       │   ├── FastAPI Pod × N (HPA: min 2, max 6)
│       │   ├── Prometheus Pod
│       │   └── Grafana Pod
│       └── RDS PostgreSQL (Multi-AZ)
│
├── ECR (Docker 이미지 저장소)
├── S3 (Terraform State 저장)
└── DynamoDB (Terraform State Lock)
```

---

## 데이터 흐름

### 1. 사용자 요청 흐름

```
사용자 브라우저
    └─→ Route53 (DNS 조회)
        └─→ ALB (HTTPS, Multi-AZ 분산)
            └─→ FastAPI 파드 (요청 처리)
                ├─→ RDS PostgreSQL (글 데이터 조회/저장)
                └─→ 응답 반환
```

### 2. 모니터링 흐름 (핵심)

```
사용자가 글 읽기
    └─→ FastAPI: 방문 카운터 +1 (메모리에 기록)
        └─→ /metrics 엔드포인트에 노출

Prometheus (15초마다)
    └─→ FastAPI /metrics 스크래핑
        └─→ 시계열 데이터로 저장

Grafana
    └─→ Prometheus에서 데이터 읽기 (PromQL 쿼리)
        └─→ 대시보드 실시간 표시
            ├── 오늘 방문자 수
            ├── 인기 글 TOP 5
            ├── 시간대별 트래픽
            ├── 파드 CPU/메모리
            └── HPA 파드 수 변화
```

### 3. CI/CD 흐름

```
개발자 코드 수정 → Git Push
    └─→ GitHub Actions 트리거
        ├─→ pytest 테스트 실행
        ├─→ Docker 이미지 빌드
        ├─→ ECR 이미지 푸시
        └─→ kubectl rolling update
            └─→ EKS 무중단 배포
```

---

## 기술 스택

### Infrastructure

| 분류 | 기술 | 역할 |
|------|------|------|
| IaC | Terraform 1.7+ | 전체 인프라 코드화 |
| 컨테이너 | Docker | 앱 이미지 빌드 |
| 이미지 저장 | ECR | Docker 이미지 관리 |
| 오케스트레이션 | EKS (K8s 1.29) | 컨테이너 운영 |
| 네트워크 | VPC + ALB + Route53 | 트래픽 라우팅 |
| 데이터베이스 | RDS PostgreSQL Multi-AZ | 블로그 글 저장 |
| State 관리 | S3 + DynamoDB | Terraform 상태 관리 |

### Application

| 분류 | 기술 | 역할 |
|------|------|------|
| 백엔드 | FastAPI (Python) | 블로그 API 서버 |
| DB ORM | SQLAlchemy | DB 쿼리 |
| 마이그레이션 | Alembic | DB 스키마 관리 |

### CI/CD & Monitoring

| 분류 | 기술 | 역할 |
|------|------|------|
| CI/CD | GitHub Actions | 자동 빌드 + 배포 |
| 메트릭 수집 | Prometheus | 인프라 + 앱 메트릭 |
| 시각화 | Grafana | 실시간 대시보드 |

---

## Kubernetes 오브젝트 구성

| 오브젝트 | 역할 | 이유 |
|----------|------|------|
| Deployment | 파드 배포 및 롤링 업데이트 | 무중단 배포 |
| Service | 파드 네트워크 접근 | 파드 IP는 수시로 바뀌므로 |
| Ingress | ALB 라우팅 규칙 | 외부 트래픽 → 파드 연결 |
| HPA | 파드 자동 확장 | 트래픽 폭증 대응 |
| ConfigMap | 설정값 관리 | 환경변수 코드 분리 |
| Secret | 민감 정보 관리 | DB 패스워드 등 |
| PodDisruptionBudget | 최소 파드 보장 | 배포 중 HA 유지 |
| Readiness Probe | 파드 준비 상태 확인 | 트래픽 안전 전달 |
| Liveness Probe | 파드 생존 확인 | 비정상 파드 자동 재시작 |

---

## Grafana 대시보드 구성

### 인프라 메트릭 (Prometheus 기본 제공)

| 패널 | 쿼리 개념 | 의미 |
|------|-----------|------|
| 파드 수 | HPA current replicas | 현재 실행 중인 파드 수 |
| CPU 사용률 | container_cpu_usage | 파드별 CPU 점유율 |
| 메모리 사용률 | container_memory_usage | 파드별 메모리 점유율 |
| 요청 수 (RPS) | http_requests_total | 초당 처리 요청 수 |
| 에러율 | http_requests 5xx 비율 | 오류 발생 비율 |

### 비즈니스 메트릭 (커스텀 — 직접 정의)

| 패널 | 메트릭 이름 | 의미 |
|------|-------------|------|
| 오늘 방문자 수 | blog_page_views_total | 전체 페이지 조회 누적 |
| 인기 글 TOP 5 | blog_post_views_total | 글별 조회 수 |
| 시간대별 트래픽 | blog_page_views_total (rate) | 시간당 방문 추이 |

---

## 디렉토리 구조 (목표)

```
cloud-blog/
├── terraform/
│   ├── bootstrap/          # S3, DynamoDB (최초 1회 실행)
│   ├── modules/
│   │   ├── vpc/            # 네트워크 기반
│   │   ├── eks/            # 쿠버네티스 클러스터
│   │   └── rds/            # 데이터베이스
│   └── envs/dev/           # 개발 환경 변수
│
├── app/
│   ├── main.py             # FastAPI 진입점
│   ├── routers/
│   │   ├── posts.py        # 글 CRUD API
│   │   └── metrics.py      # Prometheus 메트릭 노출
│   ├── models/
│   │   └── post.py         # DB 모델
│   ├── database.py         # RDS 연결
│   ├── Dockerfile
│   └── requirements.txt
│
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   └── configmap.yaml
│
└── .github/
    └── workflows/
        └── ci-cd.yml       # 테스트 → 빌드 → 배포
```

---

## 현재 개발 환경

| 항목 | 상태 |
|------|------|
| WSL2 (Ubuntu) | 완료 |
| AWS CLI | 완료 (IAM: cloud-infraflow-admin) |
| Terraform | 완료 |
| kubectl | 완료 |
| Helm | 완료 |
| Claude Code | 완료 (GitHub MCP + Notion MCP 연동) |
| GitHub 저장소 | cloud-infraflow (기존) → cloud-blog로 새로 생성 예정 |

---

## 비용 계획

| 리소스 | 스펙 | 일 비용 |
|--------|------|---------|
| EKS 컨트롤 플레인 | 관리형 | $0.10/h = $2.4/일 |
| EC2 워커 노드 × 2 | t3.small | $0.052/h = $1.25/일 |
| RDS PostgreSQL | t3.micro Multi-AZ | $0.034/h = $0.82/일 |
| NAT Gateway | - | $0.059/h = $1.42/일 |
| 합계 | - | 약 $6/일 |

작업 시작 시 `terraform apply`, 종료 시 `terraform destroy` 반복.
S3, DynamoDB는 항상 유지 (비용 거의 없음).
전체 완성까지 약 $50~60 예상.

---

## 작업 시작/종료 체크리스트

### 시작할 때

```bash
cd ~/cloud-blog
git pull origin main
cd terraform/envs/dev
terraform apply
```

### 종료할 때

```bash
cd ~/cloud-blog/terraform/envs/dev
terraform destroy
git add .
git commit -m "작업 내용 요약"
git push origin main
```

---

## 노션 페이지 양식 (통일)

새 페이지 만들 때 항상 이 순서 유지:

1. 한 줄 요약 (인용 블록)
2. 프로젝트 정보 표
3. 왜 만들었는가
4. 기술 스택 표
5. 아키텍처 다이어그램
6. 디렉토리 구조
7. 핵심 구현 상세 (코드 포함)
8. Grafana 대시보드 구성
9. 트러블슈팅 경험 표
10. 성과 표


---

