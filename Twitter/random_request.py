#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Dec  7 16:27:46 2022

@author: cyrilvallez
"""

from datetime import datetime, date, timedelta
import os
import json
import argparse

import request
import utils


def random_queries(folder_name:str, query_file:str, N_days:int, left_lim: date, right_lim: date,
                   max_per_page: int, max_pages: int, verbose: bool = True,
                   folder_prefix: str = '../Data/Twitter/') -> None:
    """
    Will randomly query twitter API for `N_days` days between `left_lim` and
    `right_lim`, using the query in the text file `query_file`. Results will
    be written into `folder_prefix + folder_name`. Each query period will be one day.

    Parameters
    ----------
    folder_name : str
        The folder where to save the results.
    query_file : str
        The path to the text file containing the query.
    N_days : int
        Number of random query.
    left_lim : date
        Left limit of the interval to pick random dates.
    right_lim : date
        Right limit of the interval to pick random dates.
    max_per_page : int
        The maximum number of tweets to get per page of results.
    max_pages : int
        The maximum number of pages to query (the total number of tweets retrieved
        is max_per_page*max_pages). Set to `-1` for no limits.
    verbose : bool, optional
        Whether to write some summary to the standard output. The default is True.
    folder_prefix : str, optional
        Path for storing the results (prefix path to `folder_name`). The default is '../Data/Twitter/'.

    Raises
    ------
    ValueError
        If the filenames already exist.

    Returns
    -------
    None

    """
    
    if folder_name[-1] != '/':
        folder_name += '/'
        
    if folder_prefix[-1] != '/':
        folder_prefix += '/'
        
    os.makedirs(folder_prefix + folder_name, exist_ok=True)
    
    # Load the query file
    query = utils.load_query(query_file)
    # If max_per_page is higher than 100, we silently set it back to 100
    max_per_page = max_per_page if max_per_page <= 100 else 100
    # If max_pages is -1 we set it to inf so that there are no limits
    max_pages = max_pages if max_pages != -1 else float('inf')
    
    random_datetimes = utils.get_random_date(left_lim, right_lim, N_days)
    filenames = []
    
    # Create filenames
    for day in random_datetimes:
        start = datetime.replace(day, tzinfo=None)
        end = datetime.replace(day + timedelta(days=1), tzinfo=None)
        file = folder_prefix + folder_name + start.isoformat(timespec='minutes').replace(':', '-') + \
            '_to_' + end.isoformat(timespec='minutes').replace(':', '-') + '.json'
        if os.path.exists(file):
            raise ValueError(('A filename corresponding to the same folder and date already exists.'
                              ' Choose another folder name.'))
        filenames.append(file)
    
    if verbose:
        print(f'The query you used is : \n{query}')
        print(f'Making {N_days} queries for random days.')
    
    for start, filename in zip(random_datetimes, filenames):
        
        # We query for a single day
        end = start + timedelta(days=1)
        
        # We log the arguments at the beginning of the file
        log = {'query_file': query_file, 'query': query, 'start_time': start.isoformat(sep=' '), \
           'end_date': end.isoformat(sep=' '), 'max_per_page': max_per_page, \
           'max_pages': max_pages}
        
        with open(filename, 'w') as filehandle:
            filehandle.write(f'{json.dumps(log)}\n\n')
    
        request.query_API(filename, query, start, end, max_per_page, max_pages)
        
        
        

if __name__ == '__main__':
    
    parser = argparse.ArgumentParser(description='Twitter random API call')
    parser.add_argument('folder', type=str,
                        help=('A name for the output folder where we will store the results.'
                              ' Please do NOT provide full path, only the last part, or'
                              ' set --folder_prefix to "" (null string).'))
    parser.add_argument('query', type=str,
                        help='Path to the filename containing the query.')
    parser.add_argument('N_days', type=int,
                        help='The number of random days to pick')
    parser.add_argument('--left_lim', type=date.fromisoformat, default='2020-01-01',
                        help=('The left limit for the interval in which to pick random days (YYYY-MM-DD).'
                              ' The default is 2020-01-01.'))
    parser.add_argument('--right_lim', type=date.fromisoformat, default='2022-12-01',
                        help=('The right limit for the interval in which to pick random days (YYYY-MM-DD).'
                              ' The default is 2022-01-01.'))
    parser.add_argument('--max_per_page', type=int, default=50,
                        help='Max number of results per API call. The default is 50.')
    parser.add_argument('--max_pages', type=int, default=-1,
                        help='Max number of API calls. Give `-1` for no limit.')
    parser.add_argument('--verbose', type=str, default='True', choices=['True', 'False'],
                        help='Whether to write some summary to standard output. The default is True')
    parser.add_argument('--folder_prefix', type=str, default='../Data/Twitter/',
                        help='Prefix to the path to the output files (the full path will be folder_prefix + folder.')
    args = parser.parse_args()
    
    folder_name = args.folder
    query_file = args.query
    N_days = args.N_days
    left = args.left_lim
    right = args.right_lim
    max_per_page = args.max_per_page
    max_pages = args.max_pages
    verbose = True if args.verbose == 'True' else False
    folder_prefix = args.folder_prefix
    
    random_queries(folder_name, query_file, N_days, left, right, max_per_page, max_pages,
                   verbose, folder_prefix)