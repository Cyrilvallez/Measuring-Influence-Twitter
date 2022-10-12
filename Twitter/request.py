#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Oct 12 15:51:35 2022

@author: cyrilvallez
"""

from twarc import Twarc2, expansions
import datetime
import json
import yaml


def get_credentials(path=".twitter_credentials.yaml"):
    """
    Retrieves the twitter credential from a yaml file.

    Parameters
    ----------
    path : str, optional
        The path to the yaml file containing the credentials. The default
        is ".twitter_credential.yaml".

    Returns
    -------
    credentials : dictionary
        Dictionary containing the credentials contained in the yaml file.

    """
    with open(path, "r") as stream:
        credentials = yaml.safe_load(stream)
    
    return credentials
    

# Replace your bearer token below
client = Twarc2(bearer_token=get_credentials()['Bearer token'])

# Specify the start time in UTC for the time period you want replies from
start_time = datetime.datetime(2021, 1, 1, 0, 0, 0, 0, datetime.timezone.utc)

# Specify the end time in UTC for the time period you want Tweets from
end_time = datetime.datetime(2021, 5, 30, 0, 0, 0, 0, datetime.timezone.utc)
 
# This is where we specify our query as discussed in module 5
query = "from:twitterdev"

# Name and path of the file where you want the Tweets written to
file_name = 'tweets.txt'


def main():

    # The search_all method call the full-archive search endpoint to get Tweets
    # based on the query, start and end times
    search_results = client.search_all(query=query, start_time=start_time,
                                       end_time=end_time, max_results=100)

    # Twarc returns all Tweets for the criteria set above, so we page through
    # the results
    for page in search_results:
        # The Twitter API v2 returns the Tweet information and the user, media etc.  separately
        # so we use expansions.flatten to get all the information in a single JSON
        result = expansions.flatten(page)
        # We will open the file and append one JSON object per new line
        with open(file_name, 'a+') as filehandle:
            for tweet in result:
                filehandle.write('%s\n' % json.dumps(tweet))


if __name__ == "__main__":
    main()
    
    