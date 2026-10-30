
"""
Retail Chain Profit Leakage & Demand Optimization
Script: customer_segmentation.py

Purpose:
1. Read cleaned Sales and Returns data.
2. Calculate customer spending and purchase behaviour.
3. Apply K-Means clustering to create four customer segments.
4. Export customer-level results and a segment summary.
"""

import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans

# 1. File configuration
INPUT_FILE = "Retail_Cleaned_Data.xlsx"
OUTPUT_FILE = "Customer_Segmentation_Report.xlsx"

# 2. Read cleaned data
sales_clean = pd.read_excel(INPUT_FILE, sheet_name="Sales")
returns_clean = pd.read_excel(INPUT_FILE, sheet_name="Returns")

# 3. Select valid sales records
valid_sales = sales_clean[
    (sales_clean["Order_Status"] == "Delivered") &
    (sales_clean["Negative_Quantity_Flag"] != "Yes") &
    (sales_clean["Quantity"] > 0) &
    (sales_clean["Customer_ID"].notna()) &
    (sales_clean["Selling_Price"].notna()) &
    (sales_clean["Discount_Amount"].notna())
].copy()

# 4. Calculate net sales after discounts
valid_sales["Net_Sales"] = (valid_sales["Quantity"] * valid_sales["Selling_Price"]- valid_sales["Discount_Amount"])

# 5. Calculate customer-level metrics
customer_metrics = valid_sales.groupby("Customer_ID").agg(Total_Spend=("Net_Sales", "sum"),Order_Frequency=("Order_ID", "nunique")).reset_index()

customer_metrics["Average_Order_Value"] = (customer_metrics["Total_Spend"] /customer_metrics["Order_Frequency"])

# 6. Link returns to customers through Order_ID
return_customer = returns_clean.merge(sales_clean[["Order_ID", "Customer_ID"]],on="Order_ID",how="left")

return_frequency = (return_customer.dropna(subset=["Customer_ID"]).
    groupby("Customer_ID").agg(Return_Frequency=("Return_ID", "nunique")).reset_index())

# 7. Add return frequency to customer metrics
customer_metrics = customer_metrics.merge(return_frequency,on="Customer_ID",how="left")

customer_metrics["Return_Frequency"] = (customer_metrics["Return_Frequency"].fillna(0).astype(int))

# 8. Prepare the four clustering features
segmentation_features = [
    "Total_Spend",
    "Average_Order_Value",
    "Order_Frequency",
    "Return_Frequency"
]

# 9. Standardize the features
scaler = StandardScaler()
customer_scaled = scaler.fit_transform(customer_metrics[segmentation_features]
)

# 10. Create four customer clusters
kmeans_final = KMeans(n_clusters=4,random_state=42,n_init=10)

customer_metrics["Cluster"] = kmeans_final.fit_predict(customer_scaled)

# 11. Assign the segment names from the completed analysis
segment_names = {
    0: "High-Value Loyal Customers",
    1: "Low-Engagement Customers",
    2: "High-Value High-Return Customers",
    3: "High-Ticket Customers"
}

customer_metrics["Customer_Segment"] = (customer_metrics["Cluster"].map(segment_names))

# 12. Summarize the customer segments
segment_summary = customer_metrics.groupby("Customer_Segment").agg(
    Customer_Count=("Customer_ID", "nunique")).reset_index()

segment_summary["Customer_Percentage"] = (segment_summary["Customer_Count"] /segment_summary["Customer_Count"].sum() * 100).round(2)

# 13. Export the results
with pd.ExcelWriter(OUTPUT_FILE, engine="openpyxl") as writer:
    customer_metrics.to_excel(writer, sheet_name="Customer_Details", index=False)
    segment_summary.to_excel(writer, sheet_name="Segment_Summary", index=False)

print("Customer segmentation completed successfully.")
print("Customers segmented:", len(customer_metrics))
print("\nSegment summary:")
print(segment_summary.to_string(index=False))
print("\nReport saved to:", OUTPUT_FILE)
