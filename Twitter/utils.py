#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct 13 09:39:26 2022

@author: cyrilvallez
"""

import os
import yaml
import pandas as pd
import numpy as np


def get_credentials(path: str = ".twitter_credentials.yaml") -> dict:
    """
    Retrieves the twitter credential from a yaml file.

    Parameters
    ----------
    path : str, optional
        The path to the yaml file containing the credentials. The default
        is ".twitter_credential.yaml".

    Returns
    -------
    credentials : dict
        Dictionary containing the credentials contained in the yaml file.

    """
    with open(path, 'r') as stream:
        credentials = yaml.safe_load(stream)
    
    return credentials



def load_query(query_path: str) -> str:
    """
    Load a text file containing the query.

    Parameters
    ----------
    query_path : str
        The path to the file containing the query.

    Returns
    -------
    query : str
        The query.

    """
    
    with open(query_path, 'r') as file:
        query = file.read()
        
    return query



def format_filename(filename: str, folder: str = '../Data/Twitter/',
                    extension: str = '.json') -> str:
    """
    Format the original filename to meet the format.

    Parameters
    ----------
    filename : str
        The filename for saving the file.
    folder : str, optional
        Where to store the tweets. The default is '../Data/Twitter/'.
    extension : str, optional
        The extension for saving the tweets. The default is '.txt'.

    Raises
    ------
    ValueError
        If the filename is not valid or already taken.

    Returns
    -------
    filename : str
        The final formatted path.

    """
    
    if '/' in filename:
        raise ValueError('The filename name must not be a path. Please provide a name without any \'/\'.')
    
    filename = folder + filename + extension
    if os.path.exists(filename):
        raise ValueError('A filename already exists with this name. Choose another one.')
    
    return filename



def clean_news_table(path: str = '../Data/news_table-v1-UT60-FM5.csv') -> None:
    """
    Remove all duplicates in the news table, and save the clean version to csv.

    Parameters
    ----------
    path : str, optional
        The path to the news table. The default is '../Data/news_table-v1-UT60-FM5.csv'.

    Returns
    -------
    None

    """
    
    news = pd.read_csv(path)
    # Removes all duplicates
    news.drop_duplicates(inplace=True, ignore_index=True)
    news.sort_values('Domain', inplace=True, ignore_index=True)
    unique, indices = np.unique(news['Domain'], return_index=True)
    news = news.iloc[indices].reset_index(drop=True)
    # removes unused rows
    news = news[news['tufm_class'] != '0'].reset_index(drop=True)
    # removes unused column
    news.drop('ID', axis=1, inplace=True)
    # rename column (for consistency)
    news.rename(columns={'Domain': 'domain'}, inplace=True)
    
    news.to_csv('../Data/news_table_clean.csv', index=False)