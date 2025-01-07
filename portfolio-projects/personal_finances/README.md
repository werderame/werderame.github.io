# **Personal Finance Categorization Tool**

**A Text Processing Study**. Some enjoy, or even feel it necessary to keep track of their personal finances. Expenses are, however, many, hard to read and essentially impossible to keep track of *manually*. With the intent to automate the categorisation of transaction descriptions, this text processing study aims at making it easy to assign, store and review categories of our bank transactions. Inspired by the [repository of Jer Bouma](https://github.com/JerBouma/PersonalFinance), this tool integrates multiple Levenshtein methods to achieve accuracy and flexibility.

## Foreword

How I see my own personal finances, they contain roughly two groups of transactions: **capital** and **running expenses**. Both could use some automation, however, it is important to distinguish between: 

* Telling apart the two groups: running expenses and invested capital   
* Categorising of the running expenses

This project focuses on the second group. Therefore it is advisable to use this tool on the running expenses, and having cleaned one’s transactions of those lines that correspond to pension schemes, investments, real estate property, etc. The purpose of this tool, in other words, it to tell us how much we are spending per category during a window of time, rather than computing our personal financial overview.

## **Features**

* **Personalised Categorization**: Assigns categories to transactions based on descriptions using a dynamic and configurable YAML file.  
* **thefuzz Text Preprocessing**: Cleans and standardizes transaction descriptions to improve match accuracy.  
* **Levenshtein Distance Matching**: Calculates the similarity between transaction descriptions and category keywords for more intelligent mapping.  
* **Categorisation Logic**. Applies conditions to propose the best category match to each description.  
* **Manual Review and Update**: Offers flexibility for manual review and fine-tuning of categories, ensuring accuracy.


---

## **How It Works**

1. **Data Preparation**  
   Transaction data is imported as a CSV file containing a `description` column. Please prepare a csv file and update the path in order to load it in your environment. 
2. **Preprocessing**  
   Descriptions are cleaned and standardized through regular expressions, removing unnecessary details like long digit strings, excessive punctuation, and common irrelevant terms.  
3. **Categorization**  
   * **Primary Matching**: Uses Levenshtein `process.Extract()` to match transaction descriptions to predefined keywords.  
   * **Secondary Matching**: Uses Levenshtein `distance()` and returns the minimum distance between each word of the description and the keywords from the YAML file.  
4. **Categorisation Logic**  
   Applies layered conditions to match the most accurate keyword to the description:   
   * if the two matching principles agree then it uses that keyword.  
   * else, if the secondary method has `distance == 0` then it uses that keyword  
   * else , if the primary method has `score > 80` then it uses that keyword  
   * else it returns “unassigned”, since the confidence seems too low with the current categories data provided.  
5. **Manual Review**  
   Transactions “unassigned” matches are flagged for manual categorization. Users can review and update the categories dynamically.

---

### **Example Workflow**

1. **Install Dependencies:**  
   * Clone the repository and install the required Python packages.  
2. **Prepare Your Configuration:**  
   * Create a `categories.yaml` file to define categories and associated brands. This YAML file should follow the structure:

```categories:
  house:
    - rent
    - ikea
  shopping:
    - amazon: [amazon.com, amz bill]
    - zalando
```
   * Notice that the `categories` dictionary contains 2 or 3 levels, allowing to be more generic or more specific (depending on the confidence in matching a string). The parsing of categories in this script will return the 2nd level if there is no further specific string, or the string in case there is one, like so:
```
category   brand       keyword
house      rent        rent
house      ikea        ikea
shopping   amazon      amazon.com       # "amazon.com" matches "amazon.com" in a description with higher confidence than "amazon"
shopping   amazon      amz bill         # "amz bill" will likely be required to match the same description, while "amazon" won't return enough confidence
shopping   zalando     zalando

```
   * Use the provided `load_categories` function to load this file into a DataFrame for processing.  
3. **Run the Tool:**  
   * Clean transaction data using the `preprocess_description` function. This prepares the raw descriptions by removing noise like extra spaces, irrelevant words, and numeric patterns.  
   * Categorize transactions using a matching algorithm (e.g., Levenshtein distance). Matches are automatically assigned, while unmatched transactions can be flagged for manual review.  
4. **Export Results:**  
   * Save the categorized transactions to a new CSV or other desired format for further analysis and reporting.  
   * Unmatched transactions can be exported separately for review, allowing iterative improvement of the categorization process.

---

## **Configuration**

### **YAML File**

All categories and their corresponding keywords are defined in `categories.yaml`. This file is designed for easy updates and customizations.
Feel free to open it and customize it as required. Use the 3rd level lists `[amazon.com, amz bill]` in order to match with more confidence your descriptions. This is particularly useful in case your description contains private and small businesses names which no one else would recognise. E.g.
```
'favid friedman consultation insurance'
```

This won't ever be categorised as a `service` or other category, because words like `insurance` will likely make it look like some car related insurance. Therefore we can tackle this case like so: 
```
categories:
    service:
        - lawyer: [david friedman]
```

### **Preprocessing Rules**

The `preprocess_description` function ensures that transaction descriptions are cleaned and standardized before matching. Key transformations include:

* Removing 6+ digit strings (e.g., card numbers).  
* Retaining meaningful punctuation (e.g., "amazon.de").  
* Converting text to lowercase.  
* Stripping excessive whitespace and special characters.
* Remove common words that would skew the precision of mathces (common locations or adjectives like 'berlin' or 'berliner', or common names like 'john' or name of relatives)

---

## **Future Enhancements**

* **Visualization**: Add data visualization tools for analyzing spending patterns.  

---

## **Contributing**

Contributions are welcome\! If you have ideas for improvement or additional features, feel free to submit a pull request or open an issue.

---

## **License**

This project is licensed under the MIT License.

