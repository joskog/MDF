# **Downloading Expanded Datasets for Data Engineering Lab**

## **Introduction**
For this lab, you will need **population** and **economic data** for multiple countries over an extended time period. While we provide a basic dataset, you can **download and expand the dataset** from reputable sources such as the **World Bank**.

---

## **1️⃣ Downloading Population Data**
### **Source: World Bank Open Data**
- **Dataset Name**: *Population, total (SP.POP.TOTL)*
- **Link**: [World Bank Population Dataset](https://data.worldbank.org/indicator/SP.POP.TOTL)

### **Steps to Download:**
1. Click the link above to go to the dataset page.
2. Click on **"Download"** (upper right corner).
3. Select **CSV format**.
4. Choose **"All Countries"** and **"Time Period: 1960 - Present"**.
5. Save the file as `population_data.csv`.

---

## **2️⃣ Downloading GDP and Economic Data**
### **Source: World Bank Open Data**
- **Dataset Name**: *GDP (current US$) (NY.GDP.MKTP.CD)*
- **Link**: [World Bank GDP Dataset](https://data.worldbank.org/indicator/NY.GDP.MKTP.CD)

### **Steps to Download:**
1. Click the link above to access the GDP dataset.
2. Click **"Download"** → Choose **CSV format**.
3. Select **"All Countries"** and **"Time Period: 1960 - Present"**.
4. Save the file as `gdp_data.csv`.

---

## **3️⃣ Preparing the Data**
After downloading, you will need to **clean and format the datasets** for use in AWS.

### **Cleaning Steps:**
1. Open the CSV files in **Excel or Python (Pandas)**.
2. Remove unnecessary columns (such as metadata and extra text rows).
3. Keep only the relevant columns:
   - `Country Name`, `Country Code`, `Year`, `Population` (for population dataset).
   - `Country Name`, `Country Code`, `Year`, `GDP (current US$)` (for GDP dataset).
4. Convert from **wide format** to **long format** using Pandas:
   ```python
   import pandas as pd

   # Load CSV
   population_df = pd.read_csv("population_data.csv", skiprows=4)
   gdp_df = pd.read_csv("gdp_data.csv", skiprows=4)

   # Select relevant columns
   years = [str(year) for year in range(2010, 2025)]
   population_filtered = population_df[['Country Name', 'Country Code'] + years]
   gdp_filtered = gdp_df[['Country Name', 'Country Code'] + years]

   # Convert wide format to long format
   population_long = population_filtered.melt(id_vars=['Country Name', 'Country Code'], var_name='Year', value_name='Population')
   gdp_long = gdp_filtered.melt(id_vars=['Country Name', 'Country Code'], var_name='Year', value_name='GDP')

   # Save cleaned data
   population_long.to_csv("cleaned_population_data.csv", index=False)
   gdp_long.to_csv("cleaned_gdp_data.csv", index=False)
   ```

---

## **4️⃣ Next Steps**
Once you have cleaned the data, you can:
- **Upload it to S3**.
- **Catalog it using AWS Glue**.
- **Load it into RDS for SQL queries**.

This dataset will allow for **deeper analysis of trends in population and GDP over time**.

---

## **Support & Questions**
If you have any issues downloading or preparing the data, please ask in class or refer to the **World Bank documentation**.

Happy coding! 🚀
