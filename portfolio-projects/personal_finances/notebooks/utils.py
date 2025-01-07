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
        .str.replace(r'(?<!\.)\b[a-zA-Z0-9]{1,3}\b(?!\.)', '', regex=True) # removes 3 letter words or less but not "this.one"
        .str.replace(r'\.{2,}', ' ', regex=True)
        .str.replace(r'[\/\-\s]+', ' ', regex=True)  # Replace slashes, minuses, and multiple spaces with a single space
        
        # delete specific words to avoid confusing and ambiguous matching
        .str.replace('visa', '', regex=True) # Remove the keyword "visa"
        .str.replace('carraro', '', regex=True)
        .str.replace('charlotte quirin', '', regex=True)
        .str.replace('debitk.', '', regex=True)
        .str.replace('kartenzahlung', '', regex=True)
        .str.replace('online zahlung', '', regex=True)
        .str.replace('überweisung', '', regex=True)
        .str.replace('orsola', '', regex=True)
        .str.replace('berlin', '', regex=True)
        .str.replace('issuer', '', regex=True)
        .str.replace('linussio', '', regex=True)
        .str.replace('', '', regex=True)
        
        
        .astype('string') # explicitly store as string
    )


def parse_categories():
    """ load the category list from the yaml file and parse it:
            if the category-brand-keyword is complete, return such row
            if the keyword is missing, return the brand itself
            
            this condition allows to store both brands and string to match the descriptions more accurately
            
            e.g. 
            category: shopping
            brand: amazon
            keyword: www.amazon.com
            """
    cat_tab = []

    yaml_path = '../notebooks/categories.yaml'
    with open(yaml_path, 'r') as file:
        category_list = yaml.safe_load(file)
    
    for category, brand_list in category_list['categories'].items():
        for brands in brand_list:
            if isinstance (brands, dict):
                for brand, string_list in brands.items():
                    for string in string_list:
                        cat_tab.append([category, brand, string])
            elif isinstance (brands, str):
                    cat_tab.append([category, brands, brands])

    return pd.DataFrame(cat_tab, columns=['category', 'brand', 'key'])


def import_transactions(my_transac):
    """Load the transactions dataset and convert it to a pandas dataframe"""
    file_path = os.path.join('..', 'datasets', f'{my_transac}.csv')
    transactions = pd.read_csv(file_path, thousands=',', parse_dates=['date'])
    transactions_df = pd.DataFrame(data = transactions)
    return transactions_df


def primary_match(keys, string_keywords, transactions_df):
    """creates a dictionary that calculates the best string-to-brand match for each description"""
    best_matches = {}
    keys_list = keys.tolist()
    for keyword in string_keywords:
        best_match = process.extractOne(keyword, keys_list)
        best_matches[keyword] = best_match
    primary_match_df = pd.DataFrame.from_dict(best_matches, orient='index', columns=('string_match_brand','string_match_score'))

    merged_primary = pd.merge(transactions_df, primary_match_df, how='inner', right_index=True, left_on='string_keywords')
    return merged_primary

def sequence_keywords(string_keywords):
    """transform the clean description into a split sequence of words and retains the reference to the initial description index"""
    string_keywords_s = string_keywords.str.split(expand=True)
    dataset_keywords = pd.melt(string_keywords_s, ignore_index=False, var_name='word_position', value_name='word').dropna()
    dataset_keywords['word_position'] = dataset_keywords['word_position'] + 1
    dataset_keywords['length'] = dataset_keywords['word'].str.len()
    dataset_keywords.drop(dataset_keywords[dataset_keywords['length'] < 4].index, inplace=True)
    dataset_keywords.index.name = 'index'
    dataset_keywords.sort_values(by=['index', 'word_position'], inplace=True)
    dataset_keywords.astype('string')
    dataset_keywords.reset_index(inplace=True) # after reshaping, the index needs to be reset to avoid hierarchical indexes
    return dataset_keywords


def secondary_match(keys, dataset_keywords, finance_data_score_df):
    """calculate the minimum Levenshtein distance between each split word of the description and the brands and return it"""
    word_by_word_distance = []

    for _, row in dataset_keywords.iterrows(): # Iterate through rows of dataset_keywords
        word = row['word']
        word_position = row['word_position']
        index = row['index']
        
        # Compare with each brand in categories_df
        for key in keys: # categories['brand']
            distance = Levenshtein.distance(word, key)
            # Append a dictionary with the results
            word_by_word_distance.append({
                'word_in_desc': word,
                'word_position': word_position,
                'word_match_brand': key,
                'word_match_distance': distance,
                'description_index': index
            })
    
    word_by_word_df = pd.DataFrame(word_by_word_distance) # Convert the list of dictionaries into a DataFrame
    
    # Group by 'col1' and find the index of the minimum value in 'col2'
    min_distance = word_by_word_df.groupby("description_index")["word_match_distance"].idxmin()
    
    # Use the indices to filter the DataFrame
    best_word_match_df = word_by_word_df.loc[min_distance] # best_word_match_df

    finance_matches_df = pd.merge(finance_data_score_df, best_word_match_df, how='left', left_index=True, right_on='description_index')
    
    finance_matches_df.drop('description_index', axis=1, inplace=True)
    finance_matches_df['methods_match'] = False
    
    finance_matches_df.loc[finance_matches_df['string_match_brand'] == finance_matches_df['word_match_brand'], 'methods_match'] = True
    
    return finance_matches_df


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


def filter_unassigned(df):
    """Save the mising values to a csv for ease of re-categorisation"""
    unassigned = df[df['category'].isnull()]
    unassigned = unassigned[['euro value', 'date', 'string_keywords', 'string_match_brand', 'string_match_score', 'word_match_brand', 'word_match_distance']]
    return unassigned
