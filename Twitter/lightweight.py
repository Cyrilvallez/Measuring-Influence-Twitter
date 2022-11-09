#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Nov  8 11:30:21 2022

@author: cyrilvallez
"""
     
import os
from tqdm import tqdm
import pandas as pd
import argparse
       
# Path to the news source data
PROJECT_FOLDER = os.path.dirname(os.path.dirname(__file__))
NEWS_TABLE = PROJECT_FOLDER + '/Data/news_table_clean.csv'

            
# Default attributes we want to keep as the minimum
LIGHTWEIGHT_ATTRIBUTES = [
    'created_at',
    'username',
    'follower_count',
    'sentiment',
    'domain'
    ]



def isin(domains: list[str], news_outlet: pd.DataFrame) -> bool:
    """
    Check if any of the domains are present in the `domain` column of `news_outlet`.

    Parameters
    ----------
    domains : list[str]
        The domain list.
    news_outlet : pd.DataFrame
        The news source DataFrame, containing the `domain` column.

    Returns
    -------
    bool
        Whether at least one domain in `domains` is present in the news source.

    """
    
    if domains is None:
        return False
    
    for domain in domains:
        if any(domain == news_outlet['domain']):
            return True
        
    return False



def reduce(path: str, attributes: list[str] = LIGHTWEIGHT_ATTRIBUTES) -> pd.DataFrame:
    """
    Reduce the size of a DataFrame by keeping only rows matching at least one
    of the news source, and truncating the columns to the minimum needed.

    Parameters
    ----------
    path : str
        Path to the file we will reduce.
    attributes : list[str], optional
        The DataFrame columns we want to keep. The default is LIGHTWEIGHT_ATTRIBUTES.

    Returns
    -------
    df : pd.DataFrame
        The truncated DataFrame.

    """
    
    df = pd.read_json(path, lines=True, dtype=object, convert_dates=False)
    news = pd.read_csv(NEWS_TABLE)
    mask = [isin(domains, news) for domains in df['domain']]
    
    return df.loc[mask, attributes]
    



def reduce_and_save(path: str, attributes: list[str] = LIGHTWEIGHT_ATTRIBUTES) -> None:
    """
    Load the tweets from the file or folder given in `path`, reduce them to
    conserve only the minimum of attributes, and save those reduced tweets as json.

    Parameters
    ----------
    path : str
        The path to the file or folder.
    attributes : list[str], optional
        The DataFrame columns we want to keep. The default is LIGHTWEIGHT_ATTRIBUTES.


    Returns
    -------
    None

    """
    
    if os.path.isdir(path):
        if path[-1] == '/':
            path = path[0:-1]
        new_folder = path + '_lightweight'
        os.makedirs(new_folder, exist_ok=True)
        files = [file for file in os.listdir(path) if not file.startswith('.')]
        filenames = [os.path.join(path, file) for file in files]
        new_filenames = [os.path.join(new_folder, file) for file in files]
        # Loop over new filename to avoid overwriting some
        for file in new_filenames:
            if os.path.exists(file):
                raise ValueError(('It seems like at least one file in this folder was '
                                  'already reduced. This would overwrite it.'))
        for file, new_file in tqdm(zip(filenames, new_filenames), total=len(filenames)):
            # process the tweets and create a dataframe to easily save them back
            df = reduce(file, attributes)
            df.to_json(new_file, orient="records", lines=True)
        
        
    else:
        # Removes current extension and add `_lightweight.json` instead
        new_filename = path.rsplit('.', 1)[0] + '_lightweight.json'
        if os.path.exists(new_filename):
            raise ValueError(('It seems like this file was already reduced. This '
                              'would overwrite it.'))

        # process the tweets and create a dataframe to easily save them back
        df = reduce(path, attributes)
        df.to_json(new_filename, orient="records", lines=True)
        
        
    
        
if __name__ == '__main__':
        
    parser = argparse.ArgumentParser(description='Reduce tweets')
    parser.add_argument('path', type=str,
                        help='Path to the processed tweet file or folder.')
    parser.add_argument('--attributes', nargs='+', default=LIGHTWEIGHT_ATTRIBUTES,
                        help='All the columns we want to keep.')
    args = parser.parse_args()
    
    
    reduce_and_save(args.path, attributes=args.attributes)
    
    