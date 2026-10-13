# 🎫 IT Support Tickets Analysis & Machine Learning

End-to-end analysis of IT support ticket data: from SQL Server data warehouse extraction, through statistical analysis and visualization, to machine learning models that predict **SLA breaches** and classify **ticket priority**.

---

## 📌 Project Overview

This project analyzes IT support ticket data to understand ticket characteristics, identify operational patterns, and uncover the factors associated with SLA breaches and ticket priority.

It combines statistical testing, exploratory data analysis (EDA), data visualization, and machine learning to produce actionable insights for improving IT support operations.

## 🎯 Objectives

- Understand the structure and characteristics of the support ticket dataset.
- Assess data quality and explore key statistical patterns.
- Identify trends and relationships through visualization.
- Build and evaluate ML models for:
  - SLA breach margin prediction (regression)
  - SLA breach prediction (binary classification)
  - Ticket priority classification (multi-class)
- Turn findings into practical recommendations for support teams.

## 🛠️ Tools & Technologies

| Area | Tools |
|---|---|
| Language | Python |
| Data handling | Pandas, NumPy |
| Visualization | Matplotlib, Seaborn |
| Machine learning | Scikit-learn |
| Database | SQL Server (`pyodbc`, `sqlalchemy`) |
| Environment | Jupyter Notebook |

## 🔄 Workflow

```
Business Understanding → Data Loading → Data Understanding → Data Quality Assessment
→ Statistical Analysis → EDA & Visualization → Feature Engineering
→ Machine Learning → Model Evaluation → Key Findings & Recommendations
```

## 🗂️ Data Source

Data is loaded from a SQL Server data warehouse (`IT_Solution_DWH`, schema `Gold`) built on a star schema:

| Table | Description |
|---|---|
| `FactTickets` | Ticket-level facts (SLA target, response/resolution times, reopen count, satisfaction score, complexity) |
| `DimTicketState` | Ticket status and priority |
| `DimIssue` | Issue category and type |
| `DimCustomer` | Customer age, gender, tenure, segment, subscription type |
| `DimTicketContext` | Product, channel, region, language |
| `DimTicketFlags` | Escalation and SLA breach flags |
| `DimDate` | Creation date |

> ⚠️ The database is not included in this repository. To run the notebook, connect to your own SQL Server instance with the same schema, or adapt the loading step to read from CSV files.

## 📓 Project Structure

The analysis is organized into six stages:

1. **Setup & Data Loading** – library checks, SQL Server connection, schema inspection, and chunked loading of the full ticket dataset into a single DataFrame.
2. **Data Understanding & Quality Assessment** – shape, data types, missing values, duplicate checks, and summary statistics.
3. **Statistical Analysis**
   - Descriptive statistics and statistical testing
   - Performance by category and priority
   - Monthly support performance
   - Ticket complexity vs. resolution time
   - Priority vs. SLA breaches, and category vs. escalation
   - Operational time quality checks
   - Spearman correlation analysis
4. **Visualization**
   - Escalation rate by category
   - SLA breach rate by priority
   - Average customer satisfaction by priority
   - Monthly SLA breach trend
   - Median resolution time by category
   - Correlation heatmap
   - Ticket volume by category
5. **Machine Learning – SLA**
   - Target analysis, feature availability, and **data-leakage review**
   - Outlier investigation on the target
   - Regression: Linear Regression baseline vs. Random Forest Regressor (target: `sla_breach_margin_minutes`)
   - Classification: Logistic Regression vs. Random Forest Classifier (target: `sla_breached`)
   - Permutation feature importance and final model evaluation
6. **Machine Learning – Priority Classification** – Logistic Regression and Random Forest to classify tickets as Low / Medium / High / Urgent.

## 🤖 Modeling Details

- **Train/test split:** 80/20 with `random_state=42` and stratification for classification tasks.
- **Preprocessing:** `ColumnTransformer` pipelines — median imputation + standard scaling for numeric features, most-frequent imputation + one-hot encoding for categorical features.
- **Class imbalance:** handled with `class_weight="balanced"`.
- **Leakage control:** columns that reveal the outcome (e.g., resolution time, status, the SLA flag itself when predicting the margin) are explicitly excluded from the feature set.
- **Metrics:**
  - Regression: MAE, RMSE, R²
  - Binary classification: Accuracy, Precision, Recall, F1, ROC-AUC, PR-AUC, confusion matrix
  - Priority classification: Accuracy, macro Precision / Recall / F1, per-class report

## 📈 Key Findings

> _Add your main results here after running the notebook — for example: which categories have the highest escalation rate, which priority level breaches SLA most often, which features matter most, and the final model scores._

| Model | Task | Key Metric |
|---|---|---|
| Linear Regression | SLA breach margin | _R² = …_ |
| Random Forest Regressor | SLA breach margin | _R² = …_ |
| Logistic Regression | SLA breach (final model) | _F1 = …, ROC-AUC = …_ |
| Random Forest Classifier | SLA breach | _F1 = …, ROC-AUC = …_ |
| Logistic Regression | Priority | _Macro F1 = …_ |
| Random Forest | Priority | _Macro F1 = …_ |

## 🚀 Getting Started

### Prerequisites

- Python 3.9+
- Microsoft SQL Server access
- [ODBC Driver 18 for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)


### Configuration

Update the connection settings in the first cells of the notebook/script:

```python
server = r".\SQL2025"          # your SQL Server instance
database = "IT_Solution_DWH"   # your database
```

The connection uses Windows Authentication (`Trusted_Connection=yes`).

### Run

```bash
jupyter notebook
```

Then open the notebook and run the cells in order. (The `.py` file is the notebook exported as a script.)

## 📁 Repository Contents

```
├── NTI_Support_Tickets_Analysis.py   # Full analysis & ML pipeline (exported from Jupyter)
└── README.md
```


