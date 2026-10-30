
"""
Retail Chain Profit Leakage & Demand Optimization

Script Name:
    data_cleaning.py

Purpose:
    Reproduce the main data cleaning pipeline developed in the
    Jupyter Notebook.

The script:
    1. Reads the original raw Excel workbook.
    2. Creates separate copies of the seven source tables.
    3. Removes exact duplicate records.
    4. Flags negative quantities.
    5. Handles missing / unmatched SKU mappings.
    6. Handles invalid promotion IDs.
    7. Maps returns to sales.
    8. Cleans vendor dates and calculates SLA status.
    9. Standardizes Store_ID values.
    10. Flags cancelled sales.
    11. Handles confirmed SKU formatting differences.
    12. Handles incomplete and conflicting duplicate records.
    13. Exports a separate cleaned Excel workbook.

Important:
    The original raw workbook is never modified.
    The output is written to a separate file.
"""

import pandas as pd


# =========================================================
# 1. FILE CONFIGURATION
# =========================================================

RAW_FILE = (
    r"C:\Users\manit\OneDrive\Desktop\PROJECT_1"
    r"\Retail_Profit_Leakage_Dataset.xlsx"
)

OUTPUT_FILE = (
    "Retail_Profit_Leakage_Cleaned_Data_From_Script.xlsx"
)


# =========================================================
# 2. LOAD THE RAW EXCEL WORKBOOK
# =========================================================

def load_data():

    excel_data = pd.ExcelFile(RAW_FILE)

    sales = pd.read_excel(
        excel_data,
        sheet_name="Sales_Transactions"
    )

    product = pd.read_excel(
        excel_data,
        sheet_name="Product_Master"
    )

    inventory = pd.read_excel(
        excel_data,
        sheet_name="Inventory_Daily"
    )

    returns = pd.read_excel(
        excel_data,
        sheet_name="Returns"
    )

    vendor = pd.read_excel(
        excel_data,
        sheet_name="Vendor_Supply"
    )

    promotions = pd.read_excel(
        excel_data,
        sheet_name="Promotions"
    )

    customer = pd.read_excel(
        excel_data,
        sheet_name="Customer_Master"
    )

    return (
        sales,
        product,
        inventory,
        returns,
        vendor,
        promotions,
        customer
    )


# =========================================================
# 3. SKU COMPARISON KEY
# =========================================================

def sku_comparison_key(sku):

    if pd.isna(sku):
        return pd.NA

    return (
        str(sku)
        .strip()
        .upper()
        .replace("-", "")
        .replace("_", "")
    )


# =========================================================
# 4. MAIN CLEANING PIPELINE
# =========================================================

def main():

    print("Starting data cleaning...")
    print()

    # -----------------------------------------------------
    # Load raw tables
    # -----------------------------------------------------

    (
        sales,
        product,
        inventory,
        returns,
        vendor,
        promotions,
        customer
    ) = load_data()

    print("Raw data loaded successfully.")
    print()

    # -----------------------------------------------------
    # Create independent cleaning copies
    # -----------------------------------------------------

    sales_clean = sales.copy()
    product_clean = product.copy()
    inventory_clean = inventory.copy()
    returns_clean = returns.copy()
    vendor_clean = vendor.copy()
    promotions_clean = promotions.copy()
    customer_clean = customer.copy()

    # =====================================================
    # STEP 1 — REMOVE EXACT DUPLICATES
    # =====================================================

    sales_clean = sales_clean.drop_duplicates()

    product_clean = product_clean.drop_duplicates()

    inventory_clean = inventory_clean.drop_duplicates()

    returns_clean = returns_clean.drop_duplicates()

    vendor_clean = vendor_clean.drop_duplicates()

    promotions_clean = promotions_clean.drop_duplicates()

    customer_clean = customer_clean.drop_duplicates()

    print("Exact duplicate records removed.")
    print()

    # =====================================================
    # STEP 2 — SALES SKU MAPPING
    # =====================================================

    # Preserve original SKU for audit purposes

    sales_clean["Original_SKU_ID"] = (
        sales_clean["SKU_ID"].copy()
    )

    # Product Master SKU set

    product_skus = set(
        product_clean["SKU_ID"]
        .astype(str)
        .str.strip()
        .str.upper()
    )

    # Initial SKU mapping status

    matched_sku = (
        sales_clean["SKU_ID"]
        .astype("string")
        .str.strip()
        .str.upper()
        .isin(product_skus)
    )

    sales_clean["SKU_Mapping_Status"] = "Matched"

    sales_clean.loc[
        ~matched_sku,
        "SKU_Mapping_Status"
    ] = "Missing"

    # =====================================================
    # STEP 3 — NEGATIVE QUANTITY FLAG
    # =====================================================

    sales_clean["Negative_Quantity_Flag"] = "No"

    sales_clean.loc[
        sales_clean["Quantity"] < 0,
        "Negative_Quantity_Flag"
    ] = "Yes"

    # Negative quantities are retained.
    # Their original values are not changed.

    # =====================================================
    # STEP 4 — PROMO ID MISMATCH
    # =====================================================

    # Preserve original Promo_ID

    sales_clean["Original_Promo_ID"] = (
        sales_clean["Promo_ID"].copy()
    )

    # Identify invalid promotion IDs

    unmatched_promo_sales = sales_clean[
        sales_clean["Promo_ID"].notna()
        &
        ~sales_clean["Promo_ID"].isin(
            promotions_clean["Promo_ID"]
        )
    ].copy()

    invalid_promo_ids = (
        unmatched_promo_sales["Promo_ID"]
        .unique()
    )

    # Invalid Promo_ID values become missing

    sales_clean.loc[
        sales_clean["Promo_ID"].isin(
            invalid_promo_ids
        ),
        "Promo_ID"
    ] = pd.NA

    # Create mapping status

    sales_clean["Promo_Mapping_Status"] = "Matched"

    # No original promotion

    sales_clean.loc[
        sales_clean["Original_Promo_ID"].isna(),
        "Promo_Mapping_Status"
    ] = "No Promotion"

    # Invalid original promotion

    sales_clean.loc[
        sales_clean["Original_Promo_ID"].isin(
            invalid_promo_ids
        ),
        "Promo_Mapping_Status"
    ] = "Missing"

    # =====================================================
    # STEP 5 — RETURNS WITHOUT SALES MAPPING
    # =====================================================

    returns_clean["Sales_Mapping_Status"] = "Matched"

    returns_clean.loc[
        ~returns_clean["Order_ID"].isin(
            sales_clean["Order_ID"]
        ),
        "Sales_Mapping_Status"
    ] = "Missing"

    # =====================================================
    # STEP 6 — VENDOR DATE CLEANING
    # =====================================================

    vendor_date_columns = [
        "PO_Date",
        "Expected_Delivery_Date",
        "Actual_Delivery_Date"
    ]

    for column in vendor_date_columns:

        vendor_clean[column] = pd.to_datetime(
            vendor_clean[column],
            errors="coerce"
        )

    # Calculate delivery delay

    vendor_clean["Delay_Days"] = (
        vendor_clean["Actual_Delivery_Date"]
        -
        vendor_clean["Expected_Delivery_Date"]
    ).dt.days

    # SLA Status

    vendor_clean["SLA_Status"] = "On Time"

    vendor_clean.loc[
        vendor_clean["Delay_Days"] > 0,
        "SLA_Status"
    ] = "Late"

    vendor_clean.loc[
        vendor_clean["Delay_Days"] < 0,
        "SLA_Status"
    ] = "Early"

    vendor_clean.loc[
        vendor_clean["Delay_Days"].isna(),
        "SLA_Status"
    ] = "Missing"

    # =====================================================
    # STEP 7 — STORE ID STANDARDIZATION
    # =====================================================

    # Preserve original Store_ID

    sales_clean["Original_Store_ID"] = (
        sales_clean["Store_ID"].copy()
    )

    # Standardize Store_ID
    #
    # Original notebook logic:
    # - convert to text
    # - strip spaces
    # - uppercase
    # - remove hyphens
    # - remove underscores

    sales_clean["Store_ID"] = (
        sales_clean["Store_ID"]
        .astype(str)
        .str.strip()
        .str.upper()
        .str.replace("-", "", regex=False)
        .str.replace("_", "", regex=False)
    )

    # =====================================================
    # STEP 8 — CANCELLED SALES
    # =====================================================

    sales_clean["Cancellation_Flag"] = "No"

    sales_clean.loc[
        sales_clean["Order_Status"] == "Cancelled",
        "Cancellation_Flag"
    ] = "Yes"

    # Cancelled transactions are retained.

    # =====================================================
    # STEP 9 — DATE CONVERSION
    # =====================================================

    sales_clean["Order_Date"] = pd.to_datetime(
        sales_clean["Order_Date"],
        errors="coerce"
    )

    inventory_clean["Date"] = pd.to_datetime(
        inventory_clean["Date"],
        errors="coerce"
    )

    returns_clean["Return_Date"] = pd.to_datetime(
        returns_clean["Return_Date"],
        errors="coerce"
    )

    promotions_clean["Start_Date"] = pd.to_datetime(
        promotions_clean["Start_Date"],
        errors="coerce"
    )

    promotions_clean["End_Date"] = pd.to_datetime(
        promotions_clean["End_Date"],
        errors="coerce"
    )

    customer_clean["Signup_Date"] = pd.to_datetime(
        customer_clean["Signup_Date"],
        errors="coerce"
    )

    # =====================================================
    # STEP 10 — STANDARDIZE SKU FORMAT
    # =====================================================

    # Important:
    # Only spaces/case are standardized here.
    # Meaningful hyphens and underscores are preserved.

    sku_tables = [
        sales_clean,
        product_clean,
        inventory_clean,
        returns_clean,
        vendor_clean
    ]

    for df in sku_tables:

        df["SKU_ID"] = (
            df["SKU_ID"]
            .astype("string")
            .str.strip()
            .str.upper()
        )

    # =====================================================
    # STEP 11 — CREATE SKU_COMPARE
    # =====================================================

    # SKU_Compare is used only to identify reliable
    # formatting-only differences.

    product_clean["SKU_Compare"] = (
        product_clean["SKU_ID"]
        .apply(sku_comparison_key)
    )

    for df in [
        sales_clean,
        inventory_clean,
        returns_clean,
        vendor_clean
    ]:

        df["SKU_Compare"] = (
            df["SKU_ID"]
            .apply(sku_comparison_key)
        )

    # =====================================================
    # STEP 12 — FIND CONFIRMED SKU MAPPINGS
    # =====================================================

    product_lookup = product_clean[
        [
            "SKU_ID",
            "SKU_Name",
            "Category",
            "Brand",
            "Unit_Cost",
            "MRP",
            "SKU_Compare"
        ]
    ].copy()

    sku_mappings = {}

    source_tables = [
        sales_clean,
        inventory_clean,
        returns_clean,
        vendor_clean
    ]

    for df in source_tables:

        unmatched = df[
            df["SKU_ID"].notna()
            &
            ~df["SKU_ID"].isin(
                product_skus
            )
        ].copy()

        check = (
            unmatched[
                ["SKU_ID", "SKU_Compare"]
            ]
            .drop_duplicates()
            .merge(
                product_lookup,
                on="SKU_Compare",
                how="left",
                suffixes=("_Source", "_Product")
            )
        )

        possible_matches = check[
            check["SKU_ID_Product"].notna()
        ]

        for _, row in possible_matches.iterrows():

            sku_mappings[
                row["SKU_ID_Source"]
            ] = row["SKU_ID_Product"]

    print(
        "Confirmed SKU mappings:",
        len(sku_mappings)
    )

    # =====================================================
    # STEP 13 — APPLY ONLY CONFIRMED SKU MAPPINGS
    # =====================================================

    for df in [
        sales_clean,
        inventory_clean,
        returns_clean,
        vendor_clean
    ]:

        df["SKU_ID"] = (
            df["SKU_ID"]
            .replace(sku_mappings)
        )

    # Update Sales SKU mapping status

    corrected_sales = (
        sales_clean["Original_SKU_ID"]
        .isin(sku_mappings.keys())
        &
        sales_clean["SKU_ID"]
        .isin(sku_mappings.values())
    )

    sales_clean.loc[
        corrected_sales,
        "SKU_Mapping_Status"
    ] = "Matched"

    # =====================================================
    # STEP 14 — REMOVE INCOMPLETE RETURN DUPLICATES
    # =====================================================

    return_duplicate_ids = [
        "RET200894",
        "RET201120",
        "RET202264",
        "RET202444"
    ]

    returns_clean = returns_clean.drop(
        returns_clean[
            returns_clean["Return_ID"].isin(
                return_duplicate_ids
            )
            &
            returns_clean[
                [
                    "Return_Date",
                    "Return_Reason"
                ]
            ].isna().any(axis=1)
        ].index
    )

    # =====================================================
    # STEP 15 — PROMOTION PR0200
    # =====================================================

    # PR0200 has two records.
    # Remove only the incomplete record.

    promotions_clean = promotions_clean.drop(
        promotions_clean[
            (promotions_clean["Promo_ID"] == "PR0200")
            &
            (promotions_clean["Promo_Budget"].isna())
        ].index
    )

    # =====================================================
    # STEP 16 — FLAG PROMO_XXXX
    # =====================================================

    promotions_clean["Promo_ID_Status"] = "Valid"

    promotions_clean.loc[
        promotions_clean["Promo_ID"] == "PROMO_XXXX",
        "Promo_ID_Status"
    ] = "Ambiguous"

    # =====================================================
    # STEP 17 — REMOVE INCOMPLETE VENDOR DUPLICATES
    # =====================================================

    vendor_duplicates = vendor_clean[
        vendor_clean.duplicated(
            subset=[
                "PO_ID",
                "SKU_ID",
                "Store_ID",
                "Actual_Delivery_Date"
            ],
            keep=False
        )
    ]

    vendor_incomplete = vendor_duplicates[
        vendor_duplicates.isna().any(axis=1)
    ]

    vendor_clean = vendor_clean.drop(
        vendor_incomplete.index
    )

    # =====================================================
    # STEP 18 — FLAG CONFLICTING VENDOR RECORDS
    # =====================================================

    vendor_key_counts = (
        vendor_clean
        .value_counts(
            subset=[
                "PO_ID",
                "SKU_ID",
                "Store_ID",
                "Actual_Delivery_Date"
            ]
        )
    )

    repeated_vendor_keys = (
        vendor_key_counts[
            vendor_key_counts > 1
        ]
    )

    conflicting_vendor_keys = (
        repeated_vendor_keys.index
    )

    vendor_clean["Vendor_Record_Status"] = "Valid"

    vendor_index = vendor_clean.set_index(
        [
            "PO_ID",
            "SKU_ID",
            "Store_ID",
            "Actual_Delivery_Date"
        ]
    ).index

    vendor_clean.loc[
        vendor_index.isin(
            conflicting_vendor_keys
        ),
        "Vendor_Record_Status"
    ] = "Conflict"

    # =====================================================
    # STEP 19 — REMOVE INCOMPLETE CUSTOMER DUPLICATES
    # =====================================================

    customer_duplicates = customer_clean[
        customer_clean.duplicated(
            subset=["Customer_ID"],
            keep=False
        )
    ]

    customer_incomplete = customer_duplicates[
        customer_duplicates.isna().any(axis=1)
    ]

    customer_clean = customer_clean.drop(
        customer_incomplete.index
    )

    # =====================================================
    # STEP 20 — FLAG CONFLICTING CUSTOMERS
    # =====================================================

    customer_clean["Customer_Record_Status"] = "Valid"

    conflicting_customer_ids = [
        "CUST009738",
        "CUST006624",
        "CUST008235"
    ]

    customer_clean.loc[
        customer_clean["Customer_ID"].isin(
            conflicting_customer_ids
        ),
        "Customer_Record_Status"
    ] = "Conflict"

    # =====================================================
    # STEP 21 — FINAL CLEANED TABLES
    # =====================================================

    cleaned_tables = {

        "Sales_Transactions":
            sales_clean,

        "Product_Master":
            product_clean,

        "Inventory_Daily":
            inventory_clean,

        "Returns":
            returns_clean,

        "Vendor_Supply":
            vendor_clean,

        "Promotions":
            promotions_clean,

        "Customer_Master":
            customer_clean
    }

    # =====================================================
    # STEP 22 — DISPLAY FINAL ROW COUNTS
    # =====================================================

    print()
    print("Final cleaned row counts:")
    print("-" * 45)

    for table_name, df in cleaned_tables.items():

        print(
            f"{table_name}: {len(df):,} rows"
        )

    # =====================================================
    # STEP 23 — EXPORT CLEANED WORKBOOK
    # =====================================================

    print()
    print("Writing cleaned workbook...")

    with pd.ExcelWriter(
        OUTPUT_FILE,
        engine="openpyxl"
    ) as writer:

        for table_name, df in cleaned_tables.items():

            df.to_excel(
                writer,
                sheet_name=table_name,
                index=False
            )

    print()
    print("Cleaning completed successfully.")
    print(
        f"Cleaned workbook created: {OUTPUT_FILE}"
    )


# =========================================================
# 24. RUN THE SCRIPT
# =========================================================

if __name__ == "__main__":
    main()
