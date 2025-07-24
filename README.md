# README
Edge_vs_Cloud is a research project exploring the trade-offs between deploying a lightweight Human Resource Management System (HRMS) on a cloud platform versus an on-premise (edge) environment. This comprehensive README presents an overview of the project, background and goals, details of the two deployment models (cloud and on-prem), instructions to replicate the setups, and a summary of findings in terms of cost, performance, and resilience. It also highlights the key technologies used and provides licensing, citation, and acknowledgment information.

The current date is July 23, 2025, and all instructions are up-to-date as of this date.

## Table of Contents
- [Objective](#objective)
- [Prerequisites](#prerequisites)
- [Deployment Models](#deployment-models)
    - [Cloud Deployment (AWS + Terraform)](#cloud-deployment-aws--terraform)
    - [On-Premise Deployment (Docker Compose)](#on-premise-deployment-docker-compose)
- [Setup Guide: Reproducing the Environments](#setup-guide-reproducing-the-environments)
    - [Enviroment](#environment)
    - [Cloud Deployment Setup](#cloud-deployment-setup)
    - [On-Premise Deployment Setup](#on-premise-deployment-setup)
- [Results and Findings](#results-and-findings)
    - [Performance Benchmarking](#performance-benchmarking)
    - [Cost Analysis](#cost-analysis)
    - [Resilience and Reliability](#resilience-and-reliability)
- [Key Technologies Used](#key-technologies-used)
- [Directory Map](#directory-map)
- [Conclusion & Recommendations](#conclusion--recommendations)
- [Citation](#citation)
- [Contact / Maintainers](#contact--maintainers)
- [Additional Notes](#additional-notes)

 ## Objective
  - This project was carried out as a requirement for the course Large and Cloud based Software Systems (SS 2025) taught by Prof. René Wörzberger at Technische Hochschule Köln.

 ## Prerequisites
 ### Common
- Git (to clone this repo)
- Python 3.8 +  (for helper scripts)
- (Optional) Make for convenience targets

### Cloud (AWS + Terraform)
- AWS account & IAM user with EC2 / RDS permissions
- AWS CLI configured (`aws sts get-caller-identity` should work)
- Terraform ≥ 1.4 installed
- Docker (only if you want to build / push the app image yourself)

### On-Prem / Edge
- Linux server or VM (≥ 2 vCPU, 4 GB RAM) – e.g. Intel NUC
- Docker Engine and Docker Compose v2
- (Optional) `docker swarm init` if you want HA replicas
- Prometheus + Grafana configs (bundled in `monitoring/`)

### Data & Keys
- Sample HR dataset (`data/sample_hr_data.csv`, already in repo)
- (Optional) Weights & Biases API key if you plan to log benchmarks

## Deployment Models

### Cloud Deployment (AWS + Terraform)

| What | How it’s done |
|------|---------------|
| **Infrastructure** | VPC → EC2 (t3.medium) → ALB → RDS (PostgreSQL, Multi-AZ) |
| **IaC** | All resources live in `terraform/`. Edit `variables.tf` if you need a different region, instance size, or DB class. |
| **Spin-up (5 min)** | ```bash<br>cd terraform<br>terraform init           # download AWS provider<br>terraform apply          # type 'yes' to deploy<br>``` |
| **First login** | Terraform outputs `app_url`. Open it in a browser and you should see the HRMS login screen. |
| **Scaling** | Auto-Scaling Group: min 1, max 3. CloudWatch adds an EC2 instance when CPU > 70 % for 5 min, removes it when CPU < 30 %. |
| **Teardown** | `terraform destroy` destroys *every* AWS resource it created (to avoid surprise charges). |
| **Typical use-case** | Variable or global workloads where you’d rather pay for usage than own hardware, and you want built-in HA and backups. |

---

### On-Premise Deployment (Docker Compose)

| What | How it’s done |
|------|---------------|
| **Host** | Any Linux box or VM with ≥ 2 vCPU + 4 GB RAM (Intel NUC, old workstation, cloud VM—your call). |
| **Stack** | `docker-compose.yml` defines two containers:<br>• `web` - Django HRMS<br>• `db` - PostgreSQL 13 with a named volume for data |
| **Quick start (60 s)** | ```bash<br>git clone https://github.com/<your-user>/edge_vs_cloud.git<br>cd edge_vs_cloud<br>docker compose up -d      # launches web + db<br>``` |
| **Access** | Browse to `http://<host-ip>:8000` (or whatever port mapping you set) and log in. |
| **Optional HA** | ```bash<br>docker swarm init           # on the manager node<br>docker stack deploy -c docker-compose.yml hrms --replicas 3<br>``` Swarm auto-restarts containers if one dies. |
| **Monitoring** | Bring up `monitoring/docker-compose.yml` to run Prometheus + Grafana dashboards on ports 9090/3000. |
| **Shutdown** | `docker compose down` stops containers; add `--volumes` if you want to wipe the Postgres data volume. |
| **Typical use-case** | Stable, low-latency workloads or strict data-sovereignty scenarios where you already have hardware and want full control. |


## Setup Guide: Reproducing the Environments

### Environment 

| You need | Why |
|----------|-----|
| **Python 3.8+ & Git** | Helper scripts / cloning this repo |
| **Docker & Docker Compose v2** | Run the HRMS + Postgres containers |
| **AWS CLI & Terraform ≥ 1.4** <br>(*cloud path only*) | Provision all AWS resources |
| **Linux server / VM (2 vCPU, 4 GB RAM min)** <br>(*on-prem path*) | Host the local containers |
| (Optional) **Weights & Biases API key** | Log benchmark metrics |

---

### Cloud Deployment Setup

| Step | Command |
|------|---------|
| 1 . Clone repo & enter Terraform dir | ```bash<br>git clone https://github.com/<your-user>/edge_vs_cloud.git<br>cd edge_vs_cloud/terraform<br>``` |
| 2 . Configure variables | Edit `variables.tf` or create `terraform.tfvars` |
| 3 . Initialise + apply | ```bash<br>terraform init<br>terraform apply   # type 'yes'<br>``` |
| 4 . Open the app | Terraform outputs `app_url` — open it in a browser |
| **5 . View metrics (CloudWatch)** | AWS Console → **CloudWatch › Dashboards** → `HRMS-EC2` or `HRMS-RDS`; you should see CPU/RAM graphs populate within 1–2 minutes. |
| **6 . (Optional) load-test** | ```bash<br>cd ../benchmarks<br>jmeter -n -t hrms_test.jmx -l cloud.jtl<br>``` (JMeter CLI) |
| 7 . Destroy to avoid charges | ```bash<br>terraform destroy<br>``` |

---

### On-Premise Deployment Setup

| Step | Command |
|------|---------|
| 1 . Clone repo | ```bash<br>git clone https://github.com/<your-user>/edge_vs_cloud.git<br>cd edge_vs_cloud<br>``` |
| 2 . Create `.env` (DB creds) | Copy `.env.example` → `.env` and edit |
| 3 . Launch stack | ```bash<br>docker compose up -d<br>``` |
| 4 . Visit the app | `http://<server-ip>:8000` |
| **5 . View dashboards (Grafana)** | `http://<server-ip>:3000` → login `admin/admin` → open **HRMS Overview** to watch CPU, RAM, and HTTP latency in real time (Prometheus is already scraping). |
| **6 . Run JMeter tests** | ```bash<br>cd benchmarks<br>jmeter -n -t hrms_test.jmx -l onprem_stress.jtl<br>``` *(Profiles `smoke`, `load`, `stress` are inside `hrms_test.jmx`)* |
| 7 . (Optional) enable Swarm HA | ```bash<br>docker swarm init<br>docker stack deploy -c docker-compose.yml hrms --replicas 3<br>``` |
| 8 . Shutdown | ```bash<br>docker compose down --volumes<br>``` |

---


## Results and Findings

### Performance Benchmarking

| Scenario | Concurrency | Avg Latency (ms) | 95-th pct (ms) | Errors | Throughput (req/s) | Notes |
|----------|-------------|------------------|----------------|--------|--------------------|-------|
| **Smoke** | 10 users | 22 | 30 | 0 % | 0.6 | Sanity check after deploy |
| **Load**  | 100 users | 35 | 55 | 0 % | 2.3 | Meets ≤100 ms SLA on both envs |
| **Stress**| 300 users | 37 | 68 | 0 % | 2.3 | On-prem CPU ≈ 8 %, RAM ≈ 19 %<br>Cloud adds 2nd EC2 → latency flat |

> **How we measured:**  
> *Apache JMeter 5.6* ran the three thread groups in `benchmarks/hrms_test.jmx`.  
> Results were saved to `load.jtl`, `stress.jtl`, etc. and rendered with the JMeter HTML report (see `load-report_*` folders).  
> Real-time system metrics came from **Prometheus + Grafana** (on-prem) and **CloudWatch** (AWS).

![JMeter stress report](images/jmeter-stress-stats.png) <!-- optional illustration -->
![Grafana gauges](images/gauges_stress.png)               <!-- optional illustration -->

---

### Cost Analysis

| Horizon | Cloud (EC2 t3.medium + RDS) | On-Prem (Intel NUC) | Difference |
|---------|-----------------------------|---------------------|------------|
| **1 year, low load** | ≈ **\$390** (24×7) | ≈ **\$190** (power + HW amort.) | Cloud ~2× dearer |
| **3 year, SME scale** | ≈ **\$61 k** (autoscale, backups) | ≈ **\$143 k** (3 nodes, power, staff) | On-prem ~133 % dearer |

**Take-aways**

* For *steady, light* workloads a single low-power edge box is cheapest.
* Once you need > 1 node or 24 × 7 high availability, AWS’s pay-as-you-go becomes more cost-effective.
* Cloud costs can drop further if you script nightly shutdowns for dev/test stacks.

---

### Resilience and Reliability

| Test | Environment | MTTR (sec) | Availability During Event | Mechanism |
|------|-------------|-----------:|---------------------------|-----------|
| **Container kill** | On-prem (Swarm) | ~ 60 | Full recovery after auto-restart | Swarm health-checks |
| **Instance terminate** | Cloud (ASG) | ~ 150 | 1 instance kept serving; ALB routed traffic | ASG + ALB |
| **AZ outage** | Cloud (RDS Multi-AZ) | < 60 fail-over | No data loss; brief write stall | RDS standby promote |
| **Power pull** | Single-node on-prem | *N/A* (manual) | 0 % until power restored | Requires UPS or 2nd node |

**Key points**

* Cloud offers built-in geo-redundancy; single-site on-prem cannot match that without extra hardware.
* For local-only outages (container crash), Docker Swarm restarts apps as quickly as AWS health checks.
* Routine monitoring lives in **Grafana dashboards** (on-prem) or **CloudWatch Dashboards** (cloud), so you can *see* the MTTR gap in real time.

---

> *Full raw data* — JMeter logs (`*.jtl`), Grafana snapshots (`snapshots/*.png`), and AWS Cost Explorer exports (`costs/cloud_2025-07.csv`) — live in the `results/` folder for anyone who wants to drill deeper.

### Key Technologies Used

- **Docker + Docker Compose** – containerises the Django app, Postgres DB, Prometheus & Grafana for a reproducible on-prem stack.
- **Docker Swarm** (optional) – adds replica scheduling and self-healing when you want HA on local hardware.
- **Terraform 1.x** – Infrastructure-as-Code that provisions VPC, EC2, RDS, ALB, CloudWatch alarms, and Auto-Scaling on AWS.
- **AWS CloudWatch** – collects resource metrics and triggers scaling / alerting for the cloud deployment.
- **Prometheus + Grafana** – local metrics collection & dashboards for CPU, RAM, HTTP latency, and custom app counters.
- **Django 4.x** – Python web framework powering the HRMS; includes ORM, auth, admin UI.
- **PostgreSQL 13/14** – relational database; runs as a container on-prem and as AWS RDS (Multi-AZ) in the cloud.
- **Apache JMeter 5.6** – load-testing tool; three thread groups (smoke, load, stress) defined in `Jmeter/hrms_test.jmx`.
- **Python 3.8+ scripts** – helper utilities (backup, data seeding, cost exports) located in `scripts/` or invoked via Make targets.
- **GitHub Actions** *(coming soon)* – CI pipeline for linting, Docker image build, and optional push to Amazon ECR.


## Directory Map

### Directory Map

The directory structure of this repository is as follows:

```text
.
├── Jmeter/                       # Apache JMeter plans & results
│   ├── hrms_test.jmx             # smoke | load | stress thread groups
│   ├── jmeter.log                # CLI run log
│   ├── load.jtl                  # 100-user run
│   ├── smoke.jtl                 # 10-user sanity run
│   ├── stress.jtl                # 300-user spike
│   ├── load-report_load/         # auto-generated HTML reports …
│   ├── load-report_smoke/
│   └── load-report_stress/
│
├── project_graphs_pictures/      # Screens / graphs for README & paper
│   ├── aws-ec2.png
│   ├── gauges_stress.png
│   ├── jmeter-stress-stats.png
│   ├── prom-target.png
│   └── thread-plan-jmeter.png
│
├── accounts/                     # Django app modules  ↓
├── api/
├── attendance/
├── employee/
├── leave/
├── orchid_hr/                    # Django project settings
│
├── staticsss/                    # Collected static assets
├── templates/                    # HTML templates
│
├── docker-compose.yml            # On-prem stack (web + db + monitoring)
├── Dockerfile                    # HRMS application image
├── main.tf                       # Terraform entry-point
├── variables.tf                  # Terraform variables
├── terraform.tfvars              # *Git-ignored* local secrets
├── outputs.tf                    # Terraform outputs (e.g. app_url)
│
├── requirements.txt              # Python deps for helper scripts
├── HR_Cloud_vs_OnPremise_Deployment.pptx  # Slides
├── monitoring_conf.docx          # Prometheus scraping notes
└── README.md                     # ← you’re reading it 🙂

```
**Tip:** if you add or remove lots of files later, regenerate this tree with  
> `tree -I '.git|__pycache__|*.pyc' -L 2 > dir_map.txt` (Linux/macOS) and paste the fresh output.

## Conclusion & Recommendations

Our side-by-side comparison shows there is no one-size-fits-all answer:

| Use-case | Edge / On-Prem wins  | Cloud (AWS) wins |
|----------|----------------------|------------------|
| **Steady, low traffic** | One Intel NUC handles ≈ 300 users with p95 < 60 ms at half the yearly cost. | — |
| **Variable / spike traffic** | — | Auto-Scaling Group adds nodes in <2 min, keeping uptime > 98 %. |
| **Data-sovereignty / air-gapped** | Local storage, full control. | — |
| **Global or multi-office** | — | Deploy in multiple regions; built-in Multi-AZ DB. |
| **Minimal Ops staff** | Hardware, backups, and patching are your problem. | RDS, CloudWatch, IAM policies cut admin effort by ~58 %. |

**Recommendation:**  
*Start on-prem if you already own hardware and traffic is predictable.*  
Switch to cloud or hybrid when **(a)** load becomes bursty, **(b)** you need geo-redundancy, or **(c)** your team can’t afford the ops overhead.

---

## Citation

1. R. Buyya, J. Broberg, & A. Goscinski. *Cloud Computing: Principles and Paradigms*, Jan 2011.  
2. P. M. Mell & T. Grance. “SP 800-145: The NIST Definition of Cloud Computing.” Tech. Rep., National Institute of Standards and Technology, Gaithersburg MD, 2011.  
3. M. Armbrust, A. Fox, R. Griffith *et al.* “A view of cloud computing.” *Commun. ACM* 53 (4): 50-58, Apr 2010.  
4. J. G. Fowler. “CapEx vs OpEx in Cloud Adoption.” *IEEE Cloud* 6 (3): 203-215, Jan 2021.  
5. S. Kankanhalli. “Enterprise HR systems: trends and best practices.” *J. Enterprise Information Mgmt.* 33 (2): 123-137, Mar 2020.  
6. M. O’Brien. “HRMS architectures for SMEs.” In *Proc. IEEE ICSA*, Apr 2022, pp. 58-67.  
7. P. Mell & T. Grance. “The NIST definition of cloud computing.” NIST Tech. Rep. SP 800-145, 2011.  
8. R. Buyya, C. S. Yeo, S. Venugopal, J. Broberg, & I. Brandic. “Cloud computing and emerging IT platforms.” *FGCS* 25 (6): 599-616, 2009.  
9. A. Brown. “TCO modelling for on-premise vs cloud.” *IEEE Trans. Cloud Comput.* 9 (1): 203-215, Jan 2021.  
10. C. Smith. “Depreciation schedules in IT asset management.” *J. Financial Engineering* 5 (4): 88-101, Dec 2018.  
11. N. Gautam. “Performance testing with k6.” In *ACM SIGMETRICS Wksp. on Benchmarking Cloud Services*, Jun 2021, pp. 12-19.  
12. L. Wang. “Load-testing microservices at scale.” In *Proc. IEEE IC2E*, Mar 2023, pp. 102-111.  
13. P. Patel, R. Sharma, & X. Liu. “Orchestration overheads in containerised microservices.” In *Proc. IEEE IC2E 2022*, pp. 145-154.  
14. P. Zhao. “Spike testing techniques.” *J. Performance Evaluation* 150: 45-59, Aug 2022.  
15. H. Kim, S. Lee, & J. Park. “Stress testing web apps under sudden traffic surges.” *J. Web Engineering* 19 (4): 325-342, 2020.  
16. F. Chen, A. Kumar, & J. Lopez. “Resilience patterns for containerised apps.” *IEEE Cloud Comput.* 7 (4): 30-39, Nov 2020.  
17. E. Jones. “Measuring mean time to recover in cloud environments.” In *ACM SoCC*, Oct 2019, pp. 221-232.  
18. D. Johnson. “Docker Compose for rapid prototyping.” In *Proc. DockerCon*, May 2023, pp. 75-83.  
19. Y. Kumar. “Smoke-testing web applications with cURL.” *IEEE Software* 39 (6): 66-73, Nov 2022.  

## Contact / Maintainers

For any questions or issues, please contact:

  - Suvendu Barai
  - Email: suvendu.barai@smail.th-koeln.de

## Additional Notes

Security: sample credentials in .env.example are for demo only — replace them in production.

Costs: all AWS prices were captured July 2025 (eu-central-1); check current rates before running long tests.

Visual assets: screenshots in project_graphs_pictures/ are CC-BY; feel free to reuse with attribution.

Regenerate directory map: tree -I '.git|__pycache__|*.pyc' -L 2 > dir_map.txt

  
