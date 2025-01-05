import yaml
import pandas as pd
import os
from thefuzz import process
import Levenshtein

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
    
    categories = []
    for category, brands in categories_yaml['categories'].items():
        for brand in brands:
            categories.append([category, brand])
    
    categories = pd.DataFrame(categories, columns=['category', 'brand'])
    return categories


def import_transactions():
    """Load the transactions dataset and convert it to a pandas dataframe"""
    file_path = os.path.join('..', 'datasets', 'sample_dataset_transactions.csv')
    transactions = pd.read_csv(file_path, thousands=',', parse_dates=['date'])
    return pd.DataFrame(data = transactions)


def primary_match(brands, string_keywords):
    """creates a dictionary that calculates the best string-to-brand match for each description"""
    best_matches = {}
    brands_list = brands.tolist()
    for keyword in string_keywords:
        best_match = process.extractOne(keyword, brands_list)
        best_matches[keyword] = best_match
    return pd.DataFrame.from_dict(best_matches, orient='index', columns=('string_match_brand','string_match_score'))


def sequence_keywords(string_keywords):
    """transform the clean description into a split sequence of words and retains the reference to the initial description index"""
    string_keywords_s = string_keywords.str.split(expand=True)
    dataset_keywords = pd.melt(string_keywords_s, ignore_index=False, var_name='word_position', value_name='word').dropna()
    dataset_keywords['word_position'] = dataset_keywords['word_position'] + 1
    dataset_keywords['length'] = dataset_keywords['word'].str.len()
    dataset_keywords.index.name = 'index'
    dataset_keywords.sort_values(by=['index', 'word_position'], inplace=True)
    dataset_keywords.astype('string')
    dataset_keywords.reset_index(inplace=True) # after reshaping, the index needs to be reset to avoid hierarchical indexes
    return dataset_keywords


def secondary_match(brands, dataset_keywords):
    """calculate the minimum Levenshtein distance between each split word of the description and the brands and return it"""
    word_by_word_distance = []

    for _, row in dataset_keywords.iterrows(): # Iterate through rows of dataset_keywords
        word = row['word']
        word_position = row['word_position']
        index = row['index']
        
        # Compare with each brand in categories_df
        for brand in brands: # categories['brand']
            distance = Levenshtein.distance(word, brand)
            # Append a dictionary with the results
            word_by_word_distance.append({
                'word_in_desc': word,
                'word_position': word_position,
                'word_match_brand': brand,
                'word_match_distance': distance,
                'description_index': index
            })
    
    word_by_word_df = pd.DataFrame(word_by_word_distance) # Convert the list of dictionaries into a DataFrame
    
    # Group by 'col1' and find the index of the minimum value in 'col2'
    min_distance = word_by_word_df.groupby("description_index")["word_match_distance"].idxmin()
    
    # Use the indices to filter the DataFrame
    return word_by_word_df.loc[min_distance] # best_word_match_df



def categorisation_logic(row):
    """logic of word assignation
    # layer 01: if methods_match = True, then good
    # layer 02: if methods_match = False, if word_match_distance = 0, then word_match_brand
    # layer 03: if methods_match = False and word_match_distance >= 1 and string_match_score > 80, then string_match_brand
    # layer 04: else "unassagined """
    
    if row['methods_match']:
        return row['string_match_brand']
    elif row['word_match_distance'] == 0:
        return row['word_match_brand']
    elif row['string_match_score'] > 80:
        return row ['string_match_brand']
    else:
        return '*unassigned*'

