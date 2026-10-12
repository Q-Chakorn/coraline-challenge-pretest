# Metabase on AWS with Terraform

โครงนี้ใช้ Terraform สร้าง Metabase ที่เข้าใช้งานผ่านเว็บได้ พร้อม PostgreSQL สำหรับเก็บข้อมูลการตั้งค่าของ Metabase โดยแยกฐานข้อมูลออกจาก public network

## Architecture

```text
Internet
   |
Application Load Balancer (public subnet, HTTP :80)
   |
ECS Fargate: Metabase (private subnet, :3000)
   |
RDS PostgreSQL (private subnet, :5432)
```

- ผู้ใช้เข้าที่ Application Load Balancer (ALB) เท่านั้น
- Metabase ทำงานเป็น ECS Fargate task ใน private subnet และไม่มี public IP
- RDS PostgreSQL ทำงานใน private subnet, `publicly_accessible = false` และ Security Group อนุญาตพอร์ต `5432` จาก Security Group ของ Metabase เท่านั้น
- RDS สร้างรหัสผ่านเองและเก็บไว้ใน AWS Secrets Manager (`manage_master_user_password = true`)
- ECS ดึงเฉพาะ `username`, `password`, `host`, และ `port` จาก secret ตอนเริ่ม task; ไม่มี password ในโค้ด, `.tfvars`, หรือ Terraform output

> ตัวอย่างนี้เปิดเว็บด้วย HTTP เพื่อให้ทดลองได้ทันที. ก่อนใช้จริง ควรเพิ่ม ACM certificate, HTTPS listener (443), และ redirect จาก 80 ไป 443.

## Prerequisites

- Terraform 1.6 ขึ้นไป
- AWS CLI ที่ login แล้ว หรือ AWS credentials ใน environment
- สิทธิ์สร้าง VPC, ECS, RDS, IAM, ALB, CloudWatch Logs และ Secrets Manager

## Deploy

1. คัดลอกไฟล์ตัวอย่างและปรับค่า:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. ตรวจสอบแผน:

   ```bash
   terraform init
   terraform plan
   ```

3. สร้างระบบ:

   ```bash
   terraform apply
   ```

4. รอ ECS service ให้ task เป็น healthy แล้วเปิด URL:

   ```bash
   terraform output -raw metabase_url
   ```

หน้าแรกของ Metabase จะให้สร้างผู้ดูแลระบบ (admin) ครั้งแรก

## Configuration ที่สำคัญ

| ตัวแปร | ค่าเริ่มต้น | ความหมาย |
| --- | --- | --- |
| `aws_region` | `ap-southeast-1` | AWS Region |
| `project_name` | `metabase` | คำนำหน้าชื่อ resource |
| `metabase_image` | `metabase/metabase:v0.64.0` | image แบบระบุเวอร์ชันตายตัว |
| `desired_count` | `1` | จำนวน Metabase task |
| `db_instance_class` | `db.t4g.micro` | ขนาด RDS |

Metabase ใช้ environment variables `MB_DB_TYPE`, `MB_DB_DBNAME`, `MB_DB_USER`, `MB_DB_PASS`, `MB_DB_HOST`, และ `MB_DB_PORT` เพื่อเชื่อม PostgreSQL ตาม [เอกสาร Metabase](https://www.metabase.com/docs/latest/installation-and-operation/running-metabase-on-docker). Metabase จะสร้างตารางของตนเองใน database `metabase` ตอนเริ่มทำงาน

## Security notes

- อย่า commit `terraform.tfvars` หรือ state file; `.gitignore` ได้กันไว้แล้ว
- Terraform state อาจมีข้อมูล infrastructure ที่ละเอียดอ่อน ควรใช้ remote backend ที่เข้ารหัส เช่น S3 พร้อม versioning และ DynamoDB lock เมื่อทำงานเป็นทีม
- ค่า `skip_final_snapshot = true` และ `deletion_protection = false` ตั้งไว้ให้ลบ environment ทดลองได้ง่าย ต้องเปลี่ยนทั้งสองค่าก่อน production
- NAT Gateway มีค่าใช้จ่ายรายชั่วโมงและตาม data processing. งาน production ควรทำ NAT ต่อ Availability Zone หรือใช้ VPC endpoints ตามระดับความทนทานที่ต้องการ

## Destroy

เมื่อต้องการลบ environment ทดลอง:

```bash
terraform destroy
```

คำสั่งนี้ลบ RDS โดยไม่สร้าง final snapshot ตามค่าปัจจุบัน จึงไม่ควรใช้กับข้อมูลจริง
