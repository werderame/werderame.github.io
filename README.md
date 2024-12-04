# werderame.github.io

# Data Analyst

### Education
SQL table transformation (course), Introduction to Databases (course), Operations
management (course), Production Planning (certification), Introduction to Data Science
Specialization (certification).

### Latest Work Experience
#### Sr. Process Manager, Data Analytics @ HelloFresh 
Analytic tools to support decision-making in manufacturing Supply Chain: KPIs and Dashboards, FEFO Model to predict Waste, ad hoc business applications and pipelines.

### Selected Projects
#### FEFO Waste Projection Model: Optimizing Shelf Life Management (@ HelloFresh)
   Objective. Developed a Python-based First Expired, First Out (FEFO) model that uses an ETL pipeline to publish waste projections, providing transparency and improving decision-making in menu planning, supply planning, and purchasing.        
   Approach. Data Extraction: Pulled and merged inventory data from various internal systems (e.g., DWH, Google Sheets). Adapted to operational constraints (time dependency based on location). Integrated information on expiration dates, inventory batches, and product handling timeframes.  
⋅⋅⋅Data Processing. Extracted Inventory and current Purchase Order data from the DWH, as well as demand data. Allocated inventory to demand by applying the FEFO logic to prioritize products by their expiration date. Determined what inventory would be consumed and what remaining and by which date. Uploaded the resulting data to the DWH.⋅⋅
⋅⋅⋅Visualization & Insights. Built visual dashboards (Tableau) and tracker-reports (Top 5 logs) to support project management and decisions across operational stakeholders.⋅⋅
⋅⋅⋅Results. Efficiency: Enabled accurate and timely decisions to reduce waste. Scalability: The FEFO model is adaptable across various markets and product categories. Impact: Led to more informed menu planning, helping align purchasing volumes with real-time expiration risks; cost savings: 17.000€/w.
⋅⋅⋅*Tools & Technologies. Languages: SQL, Python. Platforms: Databricks, Tableau, Google Sheets. Data Storage: DWH, Google Sheets.

2. Packaging Licensing Fee Calculator (@ HelloFresh)
Objective. Automate a pipeline dynamically integrated with Google Sheets that pushes to the DWH calculated costs related to utilized packaging.
Key Problem. HelloFresh is required to report and pay fees related to the disposal and recycling of packaging materials delivered to customers. This includes packaging such as plastics, paper, and metals. Tracking these materials and calculating the corresponding fees used to be a time-consuming, manual process.
Solution Overview. This tool aggregates data from multiple sources to automatically calculate licensing fees based on the weight of packaging materials delivered each month. Data Sources: Fetched consumption data from paying customers’ deliveries and donated/disposed inventory movements. Packaging Weight and Fee Data: Extracts dynamically from a Google Sheets file.
Results. 	The raw data is published to the DWH. A visual report is provided in Tableau.
Impact.	Estimated 10 man-hours saved per month. Cost savings of approximately €120,000 per month. (These savings are due to the choice of sources in the manual reporting, that relied on highly inaccurate inventory transactions, rather than using more downstream tables.)
