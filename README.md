#Railway Wagon Operations Analytics
📌 Project Overview

Railway freight operations involve high-value assets (wagons), complex routing, cargo planning, and frequent maintenance.
This project analyzes railway wagon operational data to identify inefficiencies in:

Wagon utilization & idle time

Route delays and bottlenecks

Cargo overloading & underutilization

Maintenance frequency & downtime

High-risk wagons affecting operations

The goal is to provide data-driven insights that help improve operational efficiency, reliability, and asset utilization.

🎯 Business Objectives

Evaluate wagon utilization and idle time

Identify delay-prone routes and operational bottlenecks

Analyze maintenance frequency and downtime

Detect overloading and underutilization issues

Identify high-risk wagons requiring immediate action

Provide executive-level operational health visibility

🗂️ Dataset Description

The project uses structured operational datasets stored in MySQL and connected to Power BI.

| Table Name         | Description                                         |
| ------------------ | --------------------------------------------------- |
| `wagon_df`         | Wagon master data (type, capacity, status)          |
| `route_df`         | Route details (source, destination, distance, zone) |
| `trip_df_modified` | Trip-level operational data (500 trips)             |
| `cargo_df`         | Cargo details per trip                              |
| `maintenance_csv`  | Wagon maintenance history                           |
| `risk_wagon`       | Pre-calculated maintenance risk per wagon           |


🛠️ Tools & Technologies

MySQL – Data storage, cleaning, and analytics

Advanced SQL – CTEs, window functions, CASE logic

Power BI – Dashboarding & DAX measures

Excel – Initial data generation

GitHub – Version control & portfolio hosting

🔑 Key KPIs & Metrics

Total Trips

Delay Percentage & Average Delay Hours

Trips per Wagon (Utilization)

Idle Hours per Wagon

Overloaded / Underutilized Trips

Maintenance Downtime Days

High-Risk Wagons

Overall Operational Health (Healthy / Medium Risk / High Risk)

📊 Analysis Performed
1️⃣ Wagon Utilization & Idle Time

Calculated trips per wagon

Used window functions to compute idle time between trips

Identified underutilized and high-idle wagons

2️⃣ Route Performance & Delays

Delay percentage by route and zone

Identified bottleneck routes with consistent delays

3️⃣ Cargo Load Efficiency

Aggregated cargo weight per trip

Classified trips as Overloaded, Optimal, or Underutilized

4️⃣ Maintenance & Downtime

Maintenance frequency analysis

Total and average downtime per wagon

Preventive vs corrective maintenance evaluation

5️⃣ High-Risk Wagon Identification

Used pre-calculated maintenance risk data

Identified wagons causing maximum operational impact

6️⃣ Operational Health KPI

Combined delay performance and maintenance risk

Classified operational status as Healthy, Medium Risk, or High Risk

📈 Power BI Dashboard

A 1-page Executive Dashboard was built to provide instant visibility into operations.

Dashboard Highlights

Executive KPI cards

Wagon utilization & idle risk

Route delay bottlenecks

Cargo efficiency & penalty risk

Maintenance reliability & high-risk wagons

Stakeholder Use Case

Enables leadership to quickly identify problem areas and take corrective actions.

🧠 Key Insights

A small percentage of wagons contribute disproportionately to delays and downtime

High-idle wagons perform significantly fewer trips, leading to revenue loss

Overloaded trips experience higher delays and compliance risk

Certain routes consistently underperform, indicating structural bottlenecks

✅ Recommendations

Reallocate underutilized wagons to high-demand routes

Enforce cargo load validation before dispatch

Prioritize preventive maintenance for high-risk wagons

Monitor route-level performance continuously

Use operational health KPI for proactive decision-making

