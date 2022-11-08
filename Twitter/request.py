#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Oct 12 15:51:35 2022

@author: cyrilvallez
"""

from twarc import Twarc2, expansions
from datetime import datetime, timedelta, timezone
import json
import argparse
import utils


def make_query(filename: str, query: str, start_time: datetime,
               end_time: datetime, max_per_page: int, max_pages: int) -> None:
    """
    Make a "search all" query to the twitter API v2 and saves the results to
    the given `filename`.

    Parameters
    ----------
    filename : str
        The path and filename to save the results.
    query : str
        The query for the twitter API.
    start_time : datetime.datetime
        The start date for looking up tweets.
    end_time : datetime.datetime
        The end date for looking up tweets.
    max_per_page : int
        The maximum number of tweets to get per page of results.
    max_pages : int
        The maximum number of pages to query (the total number of tweets retrieved
        is max_per_page*max_pages).

    Returns
    -------
    None.

    """
    
    # Replace your bearer token below
    client = Twarc2(bearer_token=utils.get_credentials()['Bearer token'])

    # The search_all method call the full-archive search endpoint to get Tweets
    # based on the query, start and end times
    search_results = client.search_all(query=query, start_time=start_time,
                                       end_time=end_time, max_results=max_per_page)

    # Twarc returns all Tweets for the criteria set above, so we page through
    # the results
    for i, page in enumerate(search_results):

        if i > (max_pages - 1):
            break
        
        # The Twitter API v2 returns the Tweet information and the user, media etc.  separately
        # so we use expansions.flatten to get all the information in a single JSON
        result = expansions.flatten(page)
        # We will open the file and append one JSON object per new line
        
        with open(filename, 'a+') as filehandle:
            for tweet in result:
                # write the json file with new line after each new dump
                filehandle.write(f'{json.dumps(tweet)}\n')
                
    
             

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description='Twitter API call')
    parser.add_argument('filename', type=str,
                        help='A name for the output file.')
    parser.add_argument('query', type=str,
                        help='Path to the filename containing the query.')
    parser.add_argument('start_time', type=datetime.fromisoformat,
                        help='The start date for the tweets (YYYY-MM-DDTHH:MM:SS) in UTC timezone.')
    parser.add_argument('end_time', type=datetime.fromisoformat,
                        help='The end date for the tweets (YYYY-MM-DDTHH:MM:SS) in UTC timezone.')
    parser.add_argument('--max_per_page', type=int, default=50,
                        help='Max number of results per API call.')
    parser.add_argument('--max_pages', type=int, default=-1,
                        help='Max number of API calls. Give `-1` for no limit.')
    args = parser.parse_args()
    
    filename = args.filename
    query = utils.load_query(args.query)
    start_time = args.start_time.replace(tzinfo=timezone.utc)
    end_time = args.end_time.replace(tzinfo=timezone.utc)
    max_per_page = args.max_per_page
    # If max_pages is -1 we set it to inf so that there are no limits
    max_pages = args.max_pages if args.max_pages != -1 else float('inf')
    print(f'The query you used is : \n{query}')
    
    # We split the time into periods of 4 days and save the API answer to a new file
    # for each period to avoid huge files
    time_intervals = utils.split_time_interval(start_time, end_time)
    filenames = utils.format_filename(filename, time_intervals)
    
    for i in range(len(time_intervals)-1):
        
        # We log the arguments at the beginning of the file
        log = {'query_file': args.query, 'query': query, 'start_time': time_intervals[i].isoformat(sep=' '), \
           'end_date': time_intervals[i+1].isoformat(sep=' '), 'max_per_page': max_per_page, \
           'max_pages': max_pages}
        
        with open(filenames[i], 'w') as filehandle:
            filehandle.write(f'{json.dumps(log)}\n\n')
    
        make_query(filenames[i], query, time_intervals[i], time_intervals[i+1],
                   max_per_page, max_pages)
    
    
    