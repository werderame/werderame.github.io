import yaml
import pandas as pd

def spaceless_strings(my_list):
    """Process eazch string in the dataset and strip it of leading, tailing and extra spaces"""
    import re
    clean_list = [] # Initializing the target list will avoid duplicates in case we run the program twice
    for string in my_list: # For each string in the list
        while '  ' in string: 
            string = string.replace('  ',' ') # Replace any double space with single space
        string = string.strip() # and strip leading and tailing spaces
        string = re.sub(r"[-/+]", " ", string) # Plus remove selected characters
        string = string.lower()
        clean_list.append(string) # append the result to the target list
    return(clean_list) # store the clean list


def preprocess_desc(my_df):
    """clean the description of the DataFrame column description so to prepare it for later Levenshtein matches"""
    return (
        my_df['description']
        .str.lower()
        .str.replace(r'\d{6,}', '', regex=True) # removes 6 or more digits strings
        .str.replace(r'\b[a-zA-Z]{3}\b(?!\.)', '', regex=True) # removes 3 letter words or less but not "this.one"
        .str.replace(r'\.{2,}', ' ', regex=True)
        .str.replace(r'[\/\-\s]+', ' ', regex=True)  # Replace slashes, minuses, and multiple spaces with a single space
        .str.replace('visa', '', regex=True) # Remove the keyword "visa"
        .str.replace('issuer', '', regex=True) # Remove the keyword "issuer"
        .astype('string') # explicitly store as string
    )


def load_categories():
    """Load categories and brands from a YAML file and return them as a DataFrame."""
    yaml_path = '../notebooks/categories.yaml'
    with open(yaml_path, 'r') as file:
        categories_yaml = yaml.safe_load(file)
    
    cat_df = []
    for category, brands in categories_yaml['categories'].items():
        for brand in brands:
            cat_df.append([category, brand])
    
    cat_df = pd.DataFrame(cat_df, columns=['category', 'brand'])
    return cat_df