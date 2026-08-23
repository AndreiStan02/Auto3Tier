# Auto3Tier

Deploy a three-tier application to AWS by editing one file.

You bring a backend container image in ECR and a built single-page app.
Auto3Tier provisions the network, database, container platform, load
balancer and CDN, then publishes your frontend — all from a GitHub Actions
workflow.

```
                    CloudFront
                    ├── /*      → S3          (your SPA)
                    └── /api/*  → ALB → ECS   (your container)
                                        │
                                       RDS
```

One domain serves both, so your frontend calls `/api/...` with no CORS
configuration and no API base URL.

---

## Setup

### 1. Get your own copy

Clone this repository, detach it from its origin, and push it to a
repository of your own. Actions and secrets have to live in a repo you
control.

```bash
git clone https://github.com/AndreiStan02/Auto3Tier.git my-app
cd my-app
rm -rf .git

git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<your-username>/my-app.git
git push -u origin main
```

Removing `.git` gives you a clean history and makes sure you never push
back to the original repository.

### 2. Create AWS credentials

In the AWS console, create an IAM **user** (not a role) with programmatic
access, and attach:

- `PowerUserAccess`
- an inline policy allowing `iam:*Role*`, `iam:*Policy*` and `iam:PassRole`

Terraform creates IAM roles for the ECS tasks, which `PowerUserAccess` alone
does not permit. Avoid `AdministratorAccess` — a leaked key then cannot
touch billing, Organizations, or account settings.

Generate an access key.

### 3. Add two repository secrets

**Settings → Secrets and variables → Actions**

| Secret | Value |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | from step 2 |
| `AWS_SECRET_ACCESS_KEY` | from step 2 |

### 4. Configure your app

Edit [`environment/terraform.tfvars`](environment/terraform.tfvars) — the
only file you need to change:

```hcl
project_name  = "my-store"
aws_region    = "eu-west-1"
backend_image = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/api:v1"
backend_port  = 8080
health_path   = "/health"
```

### 5. Add your frontend

Copy your build output into [`spa/`](spa/) so that `spa/index.html` exists.
See [spa/README.md](spa/README.md).

### 6. Deploy

**Actions → Deploy → Run workflow.** The first run takes 15–20 minutes,
mostly RDS and CloudFront. When it finishes, the run summary shows your URL.

The state bucket is created automatically on first run and reused after
that. There is nothing to bootstrap by hand.

---

## What your backend needs to do

**Listen on `backend_port`** (default 8080), on all interfaces — binding to
`127.0.0.1` means the load balancer cannot reach it.

**Answer `health_path`** with HTTP 200, without authentication. If health
checks fail, the deployment rolls back and the workflow fails.

**Read the database from these environment variables:**

| Variable | Source |
| --- | --- |
| `DB_HOST`, `DB_PORT`, `DB_NAME` | plain values |
| `DB_USERNAME`, `DB_PASSWORD` | injected from Secrets Manager at container start |

If your framework wants a single `DATABASE_URL`, assemble it in your
entrypoint script — the password only exists once the container starts, so
it cannot be composed in the task definition.

**Match the CPU architecture.** Images built on an Apple Silicon Mac are
ARM64. Either build with `--platform linux/amd64`, or set
`cpu_architecture = "ARM64"` in your tfvars. A mismatch fails with
`exec format error`.

---

## Redeploying

Every change goes through the same route: commit, then **Actions → Deploy →
Run workflow**. The workflow is idempotent — it always creates what is
missing, updates what has drifted, and leaves the rest alone. Running it
twice in a row is safe and the second run changes nothing.

Runs are serialised, so if you start one while another is in progress the
second waits rather than failing.

### Shipping a new backend version

Push your image to ECR, then update the tag in `terraform.tfvars`:

```hcl
backend_image = "1234.dkr.ecr.eu-west-1.amazonaws.com/api:v2"
```

Terraform registers a new task definition revision and ECS performs a
rolling deployment: new tasks start alongside the old ones, must pass health
checks, and only then do the old ones drain and stop. If the new version
never goes healthy, the circuit breaker rolls back automatically and the
workflow fails with your previous version still serving traffic.

> **Reusing a tag does nothing.** If you push a new image to
> `:latest` and re-run Deploy, `backend_image` has not changed, so Terraform
> plans no change, no new revision is registered, and ECS never redeploys.
> The run goes green and your old code keeps running.
>
> Use a unique tag per build — a git SHA works well. If you must reuse a
> tag, force a deployment by hand:
>
> ```bash
> aws ecs update-service --cluster <name>-ecs-cluster \
>   --service <name>-ecs-service --force-new-deployment
> ```

### Shipping frontend changes

Replace the files in `spa/`, commit, and run Deploy. Terraform finds nothing
to change and finishes in seconds; the sync uploads only what differs and
invalidates the CDN. Usually under a minute end to end.

Files you delete locally are removed from S3 on the next deploy.

### Changing configuration

Edit `terraform.tfvars` and re-run. Read the **Plan** step in the run log
before the apply — it prints exactly what will be created, changed, or
destroyed, and it is the only review point in the pipeline.

| Change | Effect |
| --- | --- |
| `cpu`, `memory`, `desired_count` | new task revision, rolling deployment |
| `backend_port`, `health_path` | new revision plus target group update |
| `price_class` | CloudFront update, no downtime |
| `db_instance_class`, `db_allocated_storage` | RDS modification, brief downtime — `apply_immediately` is on |
| `db_multi_az` | RDS modification, several minutes |
| `az_count`, `vpc_cidr` | **destroys and recreates subnets**, taking the database and tasks with them |
| `project_name` | renames nearly everything, so nearly everything is replaced |
| `aws_region` | points at a different state bucket entirely — see below |

Anything in the `modules/` directory behaves the same way: commit and
re-run.

### Two changes that need a destroy first

**`aws_region`** — the state bucket name includes the region, so changing it
makes Terraform initialise against a fresh, empty bucket. It will build a
complete second stack in the new region while the original keeps running and
billing, invisible to it. Destroy first, then change the region.

**`project_name`** — technically applies, but replaces almost every resource
and takes the database with it. Treat it as a new deployment.

### Rolling back

Set `backend_image` to the previous tag and run Deploy. That is a normal
rolling deployment in reverse, so it takes the same couple of minutes and
carries the same health-check protection.

Infrastructure changes roll back the same way: revert the commit, re-run.
The exception is anything that destroyed data on the way out — a replaced
database does not come back.

---

## Tearing down

**Actions → Destroy → Run workflow**, and type `destroy` to confirm.

> **This permanently deletes your database.** No final snapshot is taken,
> deletion protection is off, and automated backups are disabled — all three
> are required for the teardown to run unattended. Everything in the
> database is gone, with no recovery path.

Destroy also removes the Terraform state bucket once the infrastructure is
gone, leaving the account clean. Two things remain, because the workflow
cannot remove them: the IAM user you created in step 2, and any CloudWatch
log groups AWS created outside Terraform.

If a destroy fails partway, the state bucket is deliberately kept — re-run
the workflow, since Terraform still holds the record of what is left.

---

## Costs

Roughly **\$50–70/month** in `eu-west-1` at defaults and light traffic. The
NAT gateway (~\$32) and RDS (~\$15) dominate; ALB, CloudFront and S3 are
small at low volume. Nothing here has a free tier that lasts.

`single_nat_gateway = false` adds a NAT per AZ. `db_multi_az = true` roughly
doubles the database cost.

---

## Not suitable for production as-is

The defaults trade durability for a stack that can be created and destroyed
cleanly by a workflow. Before running anything real:

| Setting | Change to | Why |
| --- | --- | --- |
| `skip_final_snapshot` | `false` | keep data on delete |
| `deletion_protection` | `true` | prevent accidental deletion |
| `backup_retention_period` | `7` or more | point-in-time recovery |
| `db_multi_az` | `true` | survive an AZ failure |
| `single_nat_gateway` | `false` | egress survives an AZ failure |

CloudFront reaches the load balancer over plain HTTP. That leg is inside the
AWS network but unencrypted; fixing it means a custom domain and an ACM
certificate on the ALB.

The ALB accepts traffic from the CloudFront IP range, which is shared by all
CloudFront distributions. Locking it to yours specifically requires a secret
header CloudFront injects and an ALB listener rule that requires it.

---

## Layout

```
environment/          root module — the config surface
modules/
  network/            VPC, subnets, NAT, S3 endpoint
  data-tier/          RDS, subnet group, credentials
  application-tier/   ALB, ECS Fargate, IAM, logs
  presentation-tier/  S3, CloudFront, OAC
spa/                  your built frontend
.github/
  actions/tf-setup/   shared credentials + state + init
  workflows/          deploy, destroy
```

## Troubleshooting

**Tasks will not start.** Check the stopped task, not the service events —
the service only reports that it could not place a task:

```bash
aws ecs list-tasks --cluster <name>-ecs-cluster --desired-status STOPPED
aws ecs describe-tasks --cluster <name>-ecs-cluster --tasks <arn> \
  --query 'tasks[0].stoppedReason'
```

`CannotPullContainerError` means the image URI or its permissions are wrong.
`exec format error` means the architecture does not match.

**Container starts, then dies.** Application logs are in CloudWatch under
`/ecs/<project_name>`. You can also open a shell in a running task:

```bash
aws ecs execute-command --cluster <name>-ecs-cluster --task <arn> \
  --container <name>-container --interactive --command "/bin/sh"
```

**Site loads but the API 502s.** The container is running but failing health
checks. Confirm `health_path` returns 200 and that the app listens on
`backend_port` on `0.0.0.0`.

**Frontend changes do not appear.** CloudFront invalidation takes a minute
or two. If it persists, confirm your bundler puts a content hash in asset
filenames.
