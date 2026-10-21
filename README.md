## Hi, I’m Filippo 👋
I’m a Senior Analytics Engineer and Data Analyst with a generalist mindset. I learn new subjects quickly and enjoy figuring out how unfamiliar businesses work. I studied philosophy, worked with ERP systems and logistics, and moved into analytics because I like investigating problems and building practical solutions.

My strongest work often starts with something that hasn’t been designed yet: understanding the problem, finding the right approach and building it from the ground up.

### 🌱 A Bit About Me
I usually start by talking to the people doing the work. How does the process actually run? What are they trying to decide, and what would make that decision easier? Those conversations shape the data model, its level of detail and the rules behind the calculation.

Recent projects have taken me into energy metering, inventory planning and component cost reconciliation. I enjoy getting deep enough into a subject to challenge assumptions, make the logic explicit and explain the result clearly to someone who doesn’t write SQL.

Outside of work, I enjoy bouldering, baking bread and making things in wood. You’ll find some of my woodworking further down this page.

### 🛠️ Skills and Tools
&nbsp;&nbsp;&nbsp;![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![GLPK](https://img.shields.io/badge/GLPK-555555?style=flat&logo=gnu&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-003B57?style=flat&logo=microsoftsqlserver&logoColor=white)
![dbt](https://img.shields.io/badge/dbt-FF694B?style=flat&logo=dbt&logoColor=white)
![Databricks](https://img.shields.io/badge/Databricks-FF3621?style=flat&logo=databricks&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=flat&logo=snowflake&logoColor=white)
![Tableau](https://img.shields.io/badge/Tableau-E97627?style=flat&logo=tableau&logoColor=white)
- **Data analysis:** exploratory and diagnostic analysis, KPI definition, variance analysis and reconciliation across sources.
- **Quantitative modelling:** inventory and demand projections, time-series logic, scenario simulation and comparison of operational policies.
- **Optimisation:** linear programming with GLPK, modelling constraints and objectives, and inventory allocation.
- **SQL and analytics engineering:** recursive queries, dimensional modelling, temporal validity logic and reusable transformations.
- **dbt:** layered model design, source definitions, YAML documentation, composite-grain tests and business-rule validation.
- **Python:** data pipelines, automation, analytical workflows and simulation.
- **Platforms and visualisation:** Snowflake, Databricks, Tableau and Power BI.
- **Business process design:** understanding requirements, formalising operational rules and explaining calculations and trade-offs to stakeholders.
- **AI-assisted development:** challenging designs, generating code and validating outputs through manual review and representative data.


### 🤝 What I’m Looking For
I’m looking for a role where data is close to decisions and operations — where analytics means enablement function that strengthens the business and eventually improves the product. Longer term, I’d love to move deeper into operations research / optimization (planning, capacity or scheduling) and help build systems that make companies more efficient and resilient. Right now, I’m focused on growing my experience in analytics and engineering, and contributing as a strong, reliable teammate who delivers.

I look forward to chatting with you -feel free to get in touch.  
Or read on to see some of my recent works ..  
  
&nbsp;&nbsp;&nbsp;[![LinkedIn](https://img.shields.io/badge/_/-Filippo-0c66c3?style=flat&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/filippo-carraro/?locale=en_US) [![GitHub](https://img.shields.io/badge/_/-Filippo-181717?style=flat&logo=github&logoColor=white)](https://github.com/werderame)

## Portfolio
<div style="display: flex; width: 100%; height: 1px;"><div style="flex: 1; background-color: #0f2276;"></div><div style="flex: 1; background-color: #1a958b;"></div><div style="flex: 1; background-color: #1b910a;"></div><div style="flex: 1; background-color: #fa5208;"></div><div style="flex: 1; background-color: #fa0814;"></div><div style="flex: 1; background-color: #9307de;"></div><div style="flex: 1; background-color: #23910a;"></div><div style="flex: 1; background-color: #2b1cf2;"></div></div>    

   
### Selected Projects
#### 🪃 Weeks of Stock and Dynamic Demand Average (@ Enpal)

How many weeks of demand does our stock represent when demand changes over time? At Enpal, I built a dbt pipeline combining inventory, incoming purchases and planned demand, then projecting stock recursively, week by week. The resulting stock horizon determines whether the KPI uses a six-week average or a shorter dynamic demand window. The challenge was defining a useful coverage measure while keeping it separate from forecast consumption. This portfolio version preserves my SQL logic and uses synthetic data, worked examples, visuals and tests to make the calculation easy to follow.


You can enter this project via the README stakeholder summary or you can jump to the DWH architecture of the data pipeline &nbsp;&nbsp;&nbsp;[![Download PDF](https://img.shields.io/badge/pdf-FF0000?style=flat&logo=adobeacrobatreader&logoColor=white)](https://werderame.github.io/assets/img/readme_weeks_of_stock_dbt.pdf)&nbsp;&nbsp;&nbsp;[![GitHub Repository](https://img.shields.io/badge/-Repo-181717?style=flat&logo=github&logoColor=white)](https://github.com/werderame/weeks-of-stock-dbt.git)


#### 🧩 Inventory Management Modeling and Optimization
&nbsp;&nbsp;&nbsp;Three allocation models—imperfect FEFO, perfect FEFO, and optimization-based—are compared to reveal the operational and strategic consequences of inventory management operations. Inspired by FMCG delivery services, this project investigates the real-world cost of FEFO adherence (First-Expired-First-Out) through modeling a menu-planning-to-fulfillment data pipeline. The simulation adds a linear optimization algorithm, which will shed some light on how even a 3% operational deviation leads to major inefficiencies as well as opportunities.
    
&nbsp;&nbsp;&nbsp;There is a lot going on behind the scenes. If you would like to dive into the sections of this project, have a read here:&nbsp;&nbsp;&nbsp;[![GitHub Repository](https://img.shields.io/badge/-Repo-181717?style=flat&logo=github&logoColor=white)](https://github.com/werderame/optimizing_inventory_management.git)


#### ♻️ FEFO Waste Projection Model (@ HelloFresh)
&nbsp;&nbsp;&nbsp;Designed a data-driven solution to tackle inventory waste in a complex supply chain environment. Leveraging Python, SQL, and automated ETL pipelines, the project integrates inventory snapshots, demand data, and purchase orders to project waste risks using FEFO principles. Results are visualized through actionable dashboards, empowering stakeholders to make informed decisions, optimize inventory, and reduce costs.    
    
&nbsp;&nbsp;&nbsp;Want to know _everything_? Download the .pdf overview or check out the repo:&nbsp;&nbsp;&nbsp;[![Download PDF](https://img.shields.io/badge/pdf-FF0000?style=flat&logo=adobeacrobatreader&logoColor=white)](https://werderame.github.io/assets/img/readme_file_fefo_github.pdf)
[![GitHub Repository](https://img.shields.io/badge/-Repo-181717?style=flat&logo=github&logoColor=white)](https://github.com/werderame/werderame.github.io/tree/main/portfolio-projects/fefo_waste_projection)    

#### 📦 Packaging Licencing Fee Calculator (@ HelloFresh)
&nbsp;&nbsp;&nbsp;Automated a dynamic pipeline integrated with Google Sheets and the DWH to calculate packaging disposal and recycling fees. The tool aggregates data from multiple sources, automates calculations, and outputs results to Tableau, saving ~10 man-hours/month and €120,000/month through improved accuracy.  
    
&nbsp;&nbsp;&nbsp;Lots more nerdy information over here..&nbsp;&nbsp;&nbsp;[![Download PDF](https://img.shields.io/badge/-pdf-FF0000?style=flat&logo=adobeacrobatreader&logoColor=white)](https://werderame.github.io/assets/img/readme_file_packaging_fee_github.pdf)
[![GitHub Repository](https://img.shields.io/badge/-Repo-181717?style=flat&logo=github&logoColor=white)](https://github.com/werderame/werderame.github.io/tree/main/portfolio-projects/packaging_licencing_fee)
    
#### 🏷️💰 Personal Finances
&nbsp;&nbsp;&nbsp;Track your expenses with this tool designed to automate the categorization of bank transactions. Inspired by Jer Bouma's repository, it combines advanced text processing and Levenshtein-based methods for accurate, flexible, and easy-to-review financial categorization. Feel free to use it or get in touch if you have more ideas! [![GitHub Repository](https://img.shields.io/badge/-Repo-181717?style=flat&logo=github&logoColor=white)](https://github.com/werderame/werderame.github.io/tree/main/portfolio-projects/personal_finances)   



## Outside of Data
<div style="display: flex; width: 100%; height: 1px;"><div style="flex: 1; background-color: #0f2276;"></div><div style="flex: 1; background-color: #1a958b;"></div><div style="flex: 1; background-color: #1b910a;"></div><div style="flex: 1; background-color: #fa5208;"></div><div style="flex: 1; background-color: #fa0814;"></div><div style="flex: 1; background-color: #9307de;"></div><div style="flex: 1; background-color: #23910a;"></div><div style="flex: 1; background-color: #2b1cf2;"></div></div>    


### 🪵 Working with wood

I also love working with wood. Through Filo Holz, I make cutting boards, boxes and other small wooden objects in my Berlin workshop.

During my recent career break, I’ve given this project more space: making pieces, taking part in a local market and now beginning client work.

<p>
  <a href="https://www.instagram.com/reel/Der7A1-i0uk/"><img src="/assets/img/woodworking/walnut-board-video.jpg" alt="Walnut end-grain cutting board. Click to watch the video on Instagram." height="240" /></a>
  <a href="https://www.instagram.com/p/DecMlHHCv2y/"><img src="/assets/img/woodworking/walnut-grain.jpg" alt="Close-up of the walnut end-grain pattern in a handmade cutting board." height="240" /></a>
</p>

[See the board up close](https://www.instagram.com/p/DecMlHHCv2y/) · [Watch the short video](https://www.instagram.com/reel/Der7A1-i0uk/)


<div style="display: flex; width: 100%; height: 2px;"><div style="flex: 1; background-color: #0f2276;"></div><div style="flex: 1; background-color: #1a958b;"></div><div style="flex: 1; background-color: #1b910a;"></div><div style="flex: 1; background-color: #fa5208;"></div><div style="flex: 1; background-color: #fa0814;"></div><div style="flex: 1; background-color: #9307de;"></div><div style="flex: 1; background-color: #23910a;"></div><div style="flex: 1; background-color: #2b1cf2;"></div></div>
