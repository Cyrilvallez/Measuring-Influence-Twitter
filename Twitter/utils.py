#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct 13 09:39:26 2022

@author: cyrilvallez
"""

import os
import yaml
from datetime import datetime, date, timedelta, timezone
import pandas as pd
import numpy as np

CURRENT_FOLDER = os.path.dirname(__file__)
PROJECT_FOLDER = os.path.dirname(CURRENT_FOLDER)


def get_credentials(path: str = CURRENT_FOLDER + "/.twitter_credentials.yaml") -> dict:
    """
    Retrieves the twitter credential from a yaml file.

    Parameters
    ----------
    path : str, optional
        The path to the yaml file containing the credentials. The default
        is CURRENT_FOLDER + "/.twitter_credentials.yaml".

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



def split_time_interval(start_time: datetime, end_time: datetime,
                        time_interval: timedelta = timedelta(days=4)) -> list[datetime]:
    """
    Split a time interval into smaller intervals. This is useful to make multiple
    queries instead of just one for large time interval that would result in
    one huge file.

    Parameters
    ----------
    start_time : datetime
        Start of the interval.
    end_time : datetime
        End of the interval.
    time_interval : timedelta, optional
        The time delta to use to break the interval in smaller ones.
        The default is timedelta(days=4).

    Returns
    -------
    list[datetime]
        List corresponding to all intervals.

    """
    
    intervals = [start_time]
    
    if end_time - start_time > time_interval:
        start = start_time
        while start + time_interval < end_time:
            intervals.append(start + time_interval)
            start += time_interval
            
    intervals.append(end_time)
    
    return intervals
    


def format_filename(filename: str, time_intervals: list[datetime], 
                    folder: str = PROJECT_FOLDER + '/Data/Twitter/', extension: str = '.json') -> list[str]:
    """
    Return a list of complete paths to the files we will create.

    Parameters
    ----------
    filename : str
        The filename for saving the file.
    time_intervals : list[datetime]
        Time intervals corresponding to the query dates, as returned by 
        `split_time_intervals`.
    folder : str, optional
        Where to store the tweets. The default is PROJECT_FOLDER + '/Data/Twitter/'.
    extension : str, optional
        The extension for saving the tweets. The default is '.json'.

    Raises
    ------
    ValueError
        If the filename is not valid or already taken.

    Returns
    -------
    filename : list[str]
        List of all the final formatted paths.

    """
    
    if '/' in filename or '.' in filename:
        raise ValueError('Please provide a name without any \'.\' or \'/\'.')
        
    filenames = []
        
    # If we are going to write more than one file, create a folder as the filename
    # and returns filenames as the time periods into this folder
    if len(time_intervals) > 2:
        # Creates folder if it does not already exists
        os.makedirs(folder + filename, exist_ok=True)
        for i in range(len(time_intervals)-1):
            start = datetime.replace(time_intervals[i], tzinfo=None)
            end = datetime.replace(time_intervals[i+1], tzinfo=None)
            file = folder + filename + '/' + start.isoformat(timespec='minutes').replace(':', '-') + \
                '_to_' + end.isoformat(timespec='minutes').replace(':', '-') + extension
            if os.path.exists(file):
                raise ValueError('A filename already exists with this name. Choose another one.')
            filenames.append(file)
            
    else:
        filenames.append(folder + filename + extension)
        if os.path.exists(filenames[0]):
            raise ValueError('A filename already exists with this name. Choose another one.')
    
    return filenames



def get_random_date(left_lim: date, right_lim: date, N: int) -> list[datetime]:
    """
    Generate random dates between the two limits provided (without replacement). 
    The left limit is included, while the right limit is excluded. This means
    you can obtain the left limit, but never the right one.
    It return datetime with time set to 0 and utc timezone.

    Parameters
    ----------
    left_lim : date
        The left interval limit.
    right_lim : date
        The right interval limit.
    N : int
        The number of random dates you want between the two limits.

    Raises
    ------
    ValueError
        If N is larger than the interval.

    Returns
    -------
    list[datetime]
        The random datetimes between the limits.

    """
    
    # Random number generator with seed to be reproducible
    rng = np.random.default_rng(1234)
    
    delta = (right_lim - left_lim).days
    
    if N > delta:
        raise ValueError('Cannot pick more sample than there are days in the interval you provided.')
    
    random_numbers = rng.choice(delta, size=N, replace=False)
    # Sort the randm number so the random dates will also be ordered
    random_numbers = np.sort(random_numbers)
    random_dates = [left_lim + timedelta(days=int(rand)) for rand in random_numbers]
    random_datetimes = [datetime(d.year, d.month, d.day, tzinfo=timezone.utc) for d in random_dates]
    
    return random_datetimes



def clean_news_table(path: str = PROJECT_FOLDER + '/Data/news_table-v1-UT60-FM5.csv') -> None:
    """
    Remove all duplicates in the news table, and save the clean version to csv.

    Parameters
    ----------
    path : str, optional
        The path to the news table. The default is PROJECT_FOLDER + '/Data/news_table-v1-UT60-FM5.csv'.

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
    
    news.to_csv(PROJECT_FOLDER + '/Data/news_table_clean.csv', index=False)
    
    
    
def clean_full_newsguard_table(path: str = PROJECT_FOLDER + '/Data/NewsGuard-metadata-2022090100.csv') -> None:
    """
    Remove all duplicates in the full newsguard table, and save the clean version to csv.

    Parameters
    ----------
    path : str, optional
        The path to the news table. The default is PROJECT_FOLDER + '/Data/NewsGuard-metadata-2022090100.csv'.

    Returns
    -------
    None

    """
    
    news = pd.read_csv(path)
    # Removes duplicate rows
    news.drop_duplicates(inplace=True, ignore_index=True)
    # Remove missing score rows
    news = news[pd.notnull(news.Score)].reset_index(drop=True)
    # Select only unique domains
    unique, indices = np.unique(news['Domain'], return_index=True)
    for name, idx in zip(unique, indices):
        assert(all(news.loc[news.Domain == name, 'Rating'] == news.loc[idx, 'Rating']))
    news = news.iloc[indices].reset_index(drop=True)
    
    # sort
    news.sort_values('Domain', inplace=True, ignore_index=True)
    # Keep only domain and score columns
    news = news[['Domain', 'Score']]
    # Rename columns for consistency
    news.rename(columns={'Domain': 'domain', 'Score': 'score'}, inplace=True)
    # Create class column based on the newsguard criterion (score of 60)
    news['class'] = news['score'].apply(lambda x: 'U' if x < 60 else 'T')
    
    news.to_csv(PROJECT_FOLDER + '/Data/newsguard_full_table_clean.csv', index=False)