# CGI_CAPSTONE_PROJECT
Automotive Inventory Management System
 Complete Project Guide for Fresh Graduates
 Document Version: 1.0
 Date: July 2025
 Target Audience: Fresh Graduates - Business Intelligence & Reporting Training Program
 Document Type: Capstone Project Specification

Project Introduction
 Business Story & Scenarios
 Sample Data Structure & Examples
 Entity Relationship Diagram
 Database Design Requirements
 Step-by-Step Implementation Guide
 Sample Business Scenarios
 Assessment & Evaluation Criteria
 Success Tips for Freshers
 Note: To convert this document to PDF, copy the content to Microsoft Word or use a markdown-to
PDF converter. The ER diagram is provided in ASCII format for easy reference during development.
 Project Introduction
 Welcome to your capstone project! You'll be building a real-world inventory management system for
 an automotive parts manufacturing company. This project will showcase all the skills you've learned
 over the past 8 weeks.
 What You're Building: A complete Business Intelligence solution that helps an automotive company
 manage their inventory across multiple locations, track supplier performance, and make data-driven
 decisions.
 Industry Context: You're working for "AutoTech Manufacturing" - a company that makes:
 Control cables for motorcycles and cars
 Automotive lighting (headlamps, indicators)
 Electronic instrument clusters
 Brake components
The company operates 5 plants across different countries and serves major automotive manufacturers.
 Business Story & Scenarios
 The Challenge
 AutoTech Manufacturing is growing rapidly but struggling with:
 Inventory Issues: Some plants run out of critical parts while others have excess stock
 Supplier Problems: Difficulty tracking which suppliers deliver on time and with good quality
 Decision Making: Management needs real-time insights to make quick decisions
 Cost Control: Need to optimize inventory levels to reduce carrying costs
 Your Mission
 Build a comprehensive system that provides:
 1. Real-time inventory visibility across all locations
 2. Automated alerts when stock levels are low
 3. Supplier performance tracking to identify best and worst performers
 4. Executive dashboards for quick decision making
 5. Detailed reports for daily operations
 Sample Data Structure & Examples
 Company Structure
AutoTech Manufacturing Locations:
 🏭
 Plant-India-BNG (Bangalore, India)- Specializes in: Control cables, small components- Capacity: 50,000 cables/month- Employees: 200
 🏭
 Plant-USA-KAN (Kansas, USA)  - Specializes in: Non-automotive cables, exports- Capacity: 25,000 cables/month- Employees: 150
 🏭
 Plant-GER-MUN (Munich, Germany)- Specializes in: Automotive lighting- Capacity: 80,000 bulbs/month- Employees: 180
 🔬
 RND-Center-UK (London, UK)- R&D facility for new product development- Prototype testing and design- Employees: 50
 🏭
 Plant-MEX-JUA (Juarez, Mexico)- Assembly and packaging- Capacity: Mixed components- Employees: 120
 Product Categories with Examples
 1. Control Cables (Category: CABLES)
Sample Products:- Throttle Cable for Hero MotoCorp (Part: CBL-THR-001)
 * Length: 1200mm, Japanese standard
 * Cost: $45.50 per piece
 * Used in: Motorcycles- Clutch Cable for Honda Civic (Part: CBL-CLU-002)
 * Length: 950mm, Heavy duty
 * Cost: $52.30 per piece
 * Used in: Cars- Brake Cable for TVS Scooters (Part: CBL-BRK-003)
 * Length: 800mm, Stainless steel
 * Cost: $38.90 per piece
 * Used in: Scooters
 2. Automotive Lighting (Category: LIGHTING)
 Sample Products:- H4 Halogen Headlamp (Part: LGT-H4-001)
 * Voltage: 12V, Power: 60/55W
 * Cost: $125.00 per piece
 * Used in: Cars, trucks- LED Indicator Bulb (Part: LGT-LED-002)
 * Voltage: 12V, Power: 21W
 * Cost: $85.50 per piece
 * Used in: Modern vehicles- Tail Light Assembly (Part: LGT-TAIL-003)
 * Multi-function, LED technology
 * Cost: $210.00 per piece
 * Used in: Premium cars
 3. Electronic Components (Category: ELECTRONICS)
Sample Products:- Digital Speedometer Cluster (Part: ECU-SPD-001)
 * Android-based, 7-inch display
 * Cost: $2,500.00 per piece
 * Used in: Modern motorcycles- Fuel Sender Unit (Part: ECU-FUEL-002)
 * Electronic fuel level sensor
 * Cost: $180.00 per piece
 * Used in: All vehicles- Brake System Controller (Part: ECU-BRK-003)
 * Anti-lock braking system
 * Cost: $850.00 per piece
 * Used in: Premium vehicles
 Supplier Examples
Entity Relationship Diagram
 Database Schema Overview
 Key Suppliers:
 󾓥
 Yamaha Components Japan
   - Supplies: High-quality cables, Japanese standards
   - Rating: 4.8/5.0
   - Lead Time: 15 days
   - Payment Terms: 30 days
 󾓨
 Bosch Automotive Germany  
   - Supplies: Electronic components, sensors
   - Rating: 4.9/5.0
   - Lead Time: 12 days
   - Payment Terms: 45 days
 🇮🇳
 Tata Steel India
   - Supplies: Raw materials, steel components  
   - Rating: 4.2/5.0
   - Lead Time: 7 days
   - Payment Terms: 15 days
 󾓦
 Phillips Lighting USA
   - Supplies: LED components, lighting technology
   - Rating: 4.6/5.0
   - Lead Time: 20 days
   - Payment Terms: 30 days
 󾓭
 Shanghai Auto Parts Co.
   - Supplies: Cost-effective components
   - Rating: 3.8/5.0
   - Lead Time: 25 days
   - Payment Terms: 60 days
                    AUTOMOTIVE INVENTORY MANAGEMENT SYSTEM
                              ENTITY RELATIONSHIP DIAGRAM
    ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
    │    SUPPLIERS    │         │    LOCATIONS    │         │    PRODUCTS     │
    │─────────────────│         │─────────────────│         │─────────────────│
    │ supplier_id (PK)│         │ location_id (PK)│         │ product_id (PK) │
    │ supplier_name   │         │ location_name   │         │ product_name    │
    │ country         │         │ location_type   │         │ category        │
    │ supplier_type   │         │ country         │         │ unit_cost       │
    │ quality_rating  │         │ specialization  │         │ weight_kg       │
    │ lead_time_days  │         │ capacity        │         │ automotive_grade│
    │ payment_terms   │         │ active_status   │         │ active_status   │
    │ certification   │         └─────────────────┘         │ created_date    │
    │ active_status   │                                     │ updated_date    │
    └─────────────────┘                                     └─────────────────┘
            │                                                       │
            │                                                       │
            │ 1:M                                                   │ 1:M
            ▼                                                       ▼
    ┌─────────────────┐                                     ┌─────────────────┐
    │ PURCHASE_ORDERS │                                     │ INVENTORY_MASTER│
    │─────────────────│                                     │─────────────────│
    │ po_number (PK)  │                                     │ inventory_id(PK)│
    │ supplier_id (FK)│◄────────────────────────────────────┤ product_id (FK) │
    │ order_date      │                                     │ location_id(FK) │
    │ expected_date   │                                     │ current_stock   │
    │ actual_date     │                                     │ reorder_level   │
    │ total_amount    │                                     │ max_stock_level │
    │ order_status    │                                     │ safety_stock    │
    │ created_by      │                                     │ last_movement   │
    └─────────────────┘                                     │ unit_cost       │
            │                                               └─────────────────┘
            │ 1:M                                                   │
            ▼                                                       │ 1:M
    ┌─────────────────┐                                             ▼
    │ PO_LINE_ITEMS   │                                     ┌─────────────────┐
    │─────────────────│                                     │ INVENTORY_TRANS │
    │ line_id (PK)    │                                     │─────────────────│
    │ po_number (FK)  │                                     │ transaction_id  │
    │ product_id (FK) │◄────────────────────────────────────┤ product_id (FK) │
    │ quantity        │                                     │ location_id(FK) │
    │ unit_price      │                                     │ transaction_type│
    │ line_total      │                                     │ quantity        │
    └─────────────────┘                                     │ unit_cost       │
            │                                               │ trans_date      │
Key Relationships Explained
            │ 1:M                                           │ reference_no    │
            ▼                                               │ created_by      │
    ┌─────────────────┐                                     └─────────────────┘
    │SUPPLIER_PERFORM │                                             │
    │─────────────────│                                             │ M:1
    │ performance_id  │                                             ▼
    │ supplier_id (FK)│                                     ┌─────────────────┐
    │ po_number (FK)  │                                     │ STOCK_TRANSFERS │
    │ delivery_date   │                                     │─────────────────│
    │ promised_date   │                                     │ transfer_id (PK)│
    │ quality_rating  │                                     │ product_id (FK) │
    │ qty_delivered   │                                     │ from_location   │
    │ qty_rejected    │                                     │ to_location     │
    │ performance_month│                                    │ quantity        │
    └─────────────────┘                                     │ transfer_date   │
                                                            │ status          │
    ┌─────────────────┐                                     │ approved_by     │
    │  RND_PROJECTS   │                                     └─────────────────┘
    │─────────────────│
    │ project_id (PK) │
    │ project_name    │                    ┌─────────────────┐
    │ product_line    │                    │  AUDIT_TRAIL    │
    │ start_date      │                    │─────────────────│
    │ target_date     │                    │ audit_id (PK)   │
    │ budget_allocated│                    │ table_name      │
    │ budget_spent    │                    │ operation_type  │
    │ project_status  │                    │ old_values      │
    │ description     │                    │ new_values      │
    └─────────────────┘                    │ changed_by      │
            │                              │ change_date     │
            │ 1:M                          └─────────────────┘
            ▼
    ┌─────────────────┐
    │ RND_ALLOCATION  │
    │─────────────────│
    │ allocation_id   │
    │ project_id (FK) │
    │ product_id (FK) │
    │ allocated_qty   │
    │ allocation_date │
    │ consumed_qty    │
    │ status          │
    └─────────────────┘
1. Core Inventory Relationship:
 PRODUCTS (1) ↔ (M) INVENTORY_MASTER: Each product can be stored in multiple locations
 LOCATIONS (1) ↔ (M) INVENTORY_MASTER: Each location can store multiple products
 This creates a many-to-many relationship resolved through INVENTORY_MASTER
 2. Transaction Tracking:
 INVENTORY_MASTER (1) ↔ (M) INVENTORY_TRANSACTIONS: Each inventory record has
 multiple movement transactions
 PRODUCTS (1) ↔ (M) INVENTORY_TRANSACTIONS: Each product has multiple transactions
 across locations
 3. Procurement Chain:
 SUPPLIERS (1) ↔ (M) PURCHASE_ORDERS: Each supplier can have multiple purchase orders
 PURCHASE_ORDERS (1) ↔ (M) PO_LINE_ITEMS: Each PO contains multiple product lines
 PRODUCTS (1) ↔ (M) PO_LINE_ITEMS: Each product can appear in multiple PO lines
 4. Performance Monitoring:
 SUPPLIERS (1) ↔ (M) SUPPLIER_PERFORMANCE: Track performance over time
 PURCHASE_ORDERS (1) ↔ (M) SUPPLIER_PERFORMANCE: Link performance to specific orders
 5. R&D Integration:
 RND_PROJECTS (1) ↔ (M) RND_ALLOCATION: Each project allocates multiple components
 PRODUCTS (1) ↔ (M) RND_ALLOCATION: Products used across different R&D projects
 Business Rules Enforced by Relationships
 1. Referential Integrity: All foreign keys ensure data consistency
 2. Cascade Rules: Deleting a product cascades to related inventory records
 3. Check Constraints: Quantity fields cannot be negative
 4. Unique Constraints: Product-Location combination in INVENTORY_MASTER is unique
 5. Audit Trail: All changes tracked through triggers
 Database Design Requirements
 Core Tables You Need to Create
 1. Products Master Table
Table: PRODUCTS
 Purpose: Store all automotive parts information
 Required Fields:- Product ID (Primary Key) - Example: "CBL-THR-001"- Product Name - Example: "Throttle Cable for Hero MotoCorp"- Category - Example: "CABLES", "LIGHTING", "ELECTRONICS"- Unit Cost - Example: 45.50- Weight (in kg) - Example: 0.250- Automotive Grade (Y/N) - Example: "Y"- Active Status (Y/N) - Example: "Y"- Created Date- Last Updated Date
 Sample Data Needed: 200+ products across all categories
 2. Locations Master Table
 Table: LOCATIONS
 Purpose: Store all plant and facility information
 Required Fields:- Location ID (Primary Key) - Example: "BNG-001"- Location Name - Example: "Bangalore Plant 1"- Location Type - Example: "PLANT", "WAREHOUSE", "RND_LAB"- Country - Example: "India", "USA", "Germany"- Specialization - Example: "Control Cables"- Production Capacity - Example: 50000 (units per month)- Active Status (Y/N)
 Sample Data Needed: 5-8 locations across different countries
 3. Suppliers Master Table
Table: SUPPLIERS
 Purpose: Store supplier information and performance
 Required Fields:- Supplier ID (Primary Key) - Example: "SUP-001"- Supplier Name - Example: "Yamaha Components Japan"- Country - Example: "Japan"- Supplier Type - Example: "OEM", "AFTERMARKET"- Quality Rating (1-5) - Example: 4.8- Lead Time (days) - Example: 15- Payment Terms - Example: "30 days"- Certification Level - Example: "ISO9001", "TS16949"
 Sample Data Needed: 25-30 suppliers from different countries
 4. Inventory Master Table
 Table: INVENTORY_MASTER
 Purpose: Current stock levels at each location
 Required Fields:- Inventory ID (Primary Key)- Product ID (Foreign Key to PRODUCTS)- Location ID (Foreign Key to LOCATIONS)- Current Stock Quantity - Example: 1500- Reorder Level - Example: 500- Maximum Stock Level - Example: 5000- Safety Stock - Example: 200- Last Movement Date- Unit Cost at Location
 Sample Data Needed: 500+ records (products × locations)
 5. Inventory Transactions Table
Table: INVENTORY_TRANSACTIONS
 Purpose: Record all stock movements
 Required Fields:- Transaction ID (Primary Key)- Product ID (Foreign Key)- Location ID (Foreign Key)- Transaction Type - Example: "RECEIPT", "ISSUE", "TRANSFER"- Quantity - Example: 100 (positive for receipts, negative for issues)- Unit Cost - Example: 45.50- Transaction Date- Reference Number - Example: "PO-2024-001"- Created By User
 Sample Data Needed: 2000+ transactions over 6 months
 6. Purchase Orders Table
 Table: PURCHASE_ORDERS
 Purpose: Track orders placed with suppliers
 Required Fields:- PO Number (Primary Key) - Example: "PO-2024-001"- Supplier ID (Foreign Key)- Order Date- Expected Delivery Date- Actual Delivery Date (can be null)- Total Amount- Order Status - Example: "PENDING", "DELIVERED", "CANCELLED"- Created By User
 Sample Data Needed: 100+ purchase orders
 7. Supplier Performance Table
Table: SUPPLIER_PERFORMANCE
 Purpose: Track supplier delivery and quality metrics
 Required Fields:- Performance ID (Primary Key)- Supplier ID (Foreign Key)- PO Number (Foreign Key)- Delivery Date- Promised Date- Quality Rating (1-5)- Quantity Delivered- Quantity Rejected- Performance Month/Year
 Sample Data Needed: 300+ performance records
 Step-by-Step Implementation Guide
 Day 1: Database Foundation
 Morning Tasks (4 hours):
 1. Set up Oracle Database
 Create new database instance named "AUTOTECH_INVENTORY"
 Create tablespaces for data and indexes
 Set up basic user accounts
 2. Create Master Tables
 Build PRODUCTS table with all constraints
 Build LOCATIONS table with location data
 Build SUPPLIERS table with supplier information
 Add primary keys and check constraints
 Afternoon Tasks (4 hours): 3. Create Transaction Tables
 Build INVENTORY_MASTER table
 Build INVENTORY_TRANSACTIONS table
 Build PURCHASE_ORDERS table
 Add foreign key relationships
 4. Insert Sample Data
 Add 200+ products (mix of cables, lighting, electronics)
Add 5-8 locations across different countries
 Add 25-30 suppliers with realistic data
 Add current inventory levels for all products/locations
 Expected Outcome: Working database with realistic automotive data
 Day 2: Business Logic Development
 Morning Tasks (4 hours):
 1. Create Basic Procedures
 Procedure to check reorder levels
 Procedure to transfer stock between locations
 Function to calculate stock value
 Function to get supplier performance rating
 2. Create Triggers
 Trigger to log all inventory changes
 Trigger to update last movement date
 Trigger to validate stock quantities
 Afternoon Tasks (4 hours): 3. Advanced Business Logic
 Package for inventory management functions
 Package for supplier performance calculations
 Exception handling for business rule violations
 Automated reorder point calculations
 4. Testing Business Logic
 Test all procedures with sample data
 Verify triggers are working correctly
 Check exception handling scenarios
 Expected Outcome: Robust business logic handling automotive inventory rules
 Day 3: Data Integration (SSIS)
 Morning Tasks (4 hours):
 1. Set up SSIS Environment
 Create new SSIS project "AutoTech_ETL"
 Set up connections to Oracle database
Create folder structure for data files
 2. Build Supplier Data Integration
 Create package to import supplier delivery data
 Add data validation and cleansing transformations
 Implement error handling and logging
 Test with sample CSV files
 Afternoon Tasks (4 hours): 3. Build Production Data Integration
 Create package to process production output data
 Add aggregation transformations for daily summaries
 Implement quality check validations
 Schedule package execution
 4. Build Inventory Reconciliation
 Create package to reconcile stock across locations
 Add variance calculation logic
 Generate exception reports for large variances
 Automate daily reconciliation process
 Expected Outcome: Automated data integration processes
 Day 4: Reporting & Analytics
 Morning Tasks (4 hours):
 1. Create SSRS Reports
 Daily Inventory Status Report (by location and category)
 Reorder Alert Report (parts below reorder level)
 Supplier Performance Scorecard
 Inventory Aging Analysis Report
 2. Enhance Reports
 Add parameters for location and date filtering
 Include charts for trend visualization
 Implement drill-down capabilities
 Set up automated email delivery
 Afternoon Tasks (4 hours): 3. Build Power BI Dashboards
 Executive Dashboard (KPIs and high-level metrics)
Plant Operations Dashboard (real-time inventory status)
 Supplier Analytics Dashboard (performance trends)
 Inventory Optimization Dashboard (recommendations)
 4. Advanced Analytics
 Create calculated measures for inventory turnover
 Implement time-based comparisons
 Add forecasting visualizations
 Configure real-time data refresh
 Expected Outcome: Complete reporting and analytics solution
