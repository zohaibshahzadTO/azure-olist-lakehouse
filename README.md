# azure-olist-lakehouse
End-to-end batch lakehouse on Azure: Terraform-provisioned ADLS Gen2, Data Factory orchestration, Databricks/PySpark bronze-silver-gold Delta layers, a data quality gate, Azure Monitor alerting, Grafana dashboard, and GitHub Actions CI. Built on the Olist e-commerce dataset.

# Concepts Involved

**Medallion architecture (bronze/silver/gold):** https://www.databricks.com/glossary/medallion-architecture
**Delta Lake: https://delta.io/ · docs:** https://docs.delta.io/latest/index.html
**ADLS Gen2:** https://learn.microsoft.com/azure/storage/blobs/data-lake-storage-introduction
**Azure Data Factory concepts:** https://learn.microsoft.com/azure/data-factory/introduction
**PySpark API reference:** https://spark.apache.org/docs/latest/api/python/

# Project Skeleton

azure-olist-lakehouse/
├── README.md
├── NOTES.md                        # running log: what broke, what you did
├── .gitignore
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── adf/
│   └── pipeline_olist_batch.json   # exported from the ADF UI in section 5
├── databricks/
│   ├── 01_bronze_to_silver.py
│   ├── 02_silver_to_gold.py
│   └── 03_dq_checks.py
├── src/olist/
│   ├── __init__.py
│   └── transforms.py               # pure PySpark functions, unit-tested
├── tests/
│   └── test_transforms.py
├── scripts/
│   ├── download_olist.sh / .ps1
│   └── upload_bronze.sh / .ps1
├── grafana/
│   └── dashboard.json              # exported in section 6
└── .github/workflows/ci.yml