#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct 13 10:46:34 2022

@author: cyrilvallez
"""

import pandas as pd
import urlexpander
import tldextract
from datetime import datetime

filename = '~/Desktop/Thesis/Data/BrandWatch/Skripal/skripal_experiment_with_followers.csv'
df = pd.read_csv(filename, sep='\t', dtype=object)

# Select only non missing data
df = df[pd.notnull(df["Expanded URLs"])]

#%%

# Perform some sanity checks
assert(all(df.Date == df.time))
assert(all(df.Domain == "twitter.com"))

# Drop useless columns
df.drop(labels=["Url", "Domain", "time"], axis="columns", inplace=True)

# Rename columns
df.rename(columns={"Date": "created_at", "Author": "username", "Title": "text", "Twitter Followers": "follower_count", "Expanded URLs": "urls"}, inplace=True)

# Format correctly and add UTC time zone info
df.created_at = df["created_at"].apply(lambda x: datetime.strptime(x, '%Y-%m-%dT%H:%M:%S.0').isoformat() + '.000Z')

# Create list of urls
df.urls = [url.split(', ') for url in df.urls]

# Cast follower_count to int instead of object (str)
df = df.astype({"follower_count": int})

#%%

def try_expand(urls: list[str]) -> list[str]:

    copy = urls.copy()
    for i, url in enumerate(copy):
        if urlexpander.is_short(url) or 'act.gp' in url:
            try:
                copy[i] = urlexpander.expand(url)
            except:
                # In this case we do nothing
                pass
    
    return copy


def get_domain_and_suffix(urls: list[str]) -> list[str]:
    
    parsing = [tldextract.extract(url) for url in urls]
    # Join the domain and suffix into a single string
    domain = ['.'.join(part for part in url[1:] if part) for url in parsing]
    
    return domain



# try expand everything
df.urls = df["urls"].apply(try_expand)

# extract domains
df["domain"] = df["urls"].apply(get_domain_and_suffix)

#%%

# Export to json
df.to_json('~/Desktop/Thesis/Data/BrandWatch/Skripal/skripal_clean.json', orient="records", lines=True)


#%%

import lightweight

def effective_category(tweet: dict) -> str:
    """
    Check if a given tweet should be classified as a retweet or usual tweet.
    Quote tweets are considered retweets, and replies are considered tweets.
    Return the original tweet author if this is a retweet, or NaN for tweets.

    Parameters
    ----------
    tweet : dict
        The tweet object.

    Returns
    -------
    str
        Username of original author.

    """
    
    if tweet['text'].startswith('RT @'):
        content = tweet['text'].split('RT @')[1]
        name = content.split(' ')[0]
        if ':' in name:
            return name.split(':')[0]
        else:
            return name
        
    else:
        return float('nan')
    

# Extract retweet info
df['retweet_from'] = df.apply(effective_category, axis=1)
df['effective_category'] = df['retweet_from'].apply(lambda x: 'tweet' if pd.isnull(x) else 'retweet')

# Check if the urls are in the news table
news = pd.read_csv(lightweight.NEWS_TABLE)
mask = [lightweight.isin(domains, news) for domains in df['domain']]

# Keep only rows with urls in the news table
df = df[mask]

# Drop non-lightweight columns
df.drop(labels=["text", "urls"], axis="columns", inplace=True)

# Export to json
df.to_json('~/Desktop/Thesis/Data/BrandWatch/Skripal/skripal_clean_lightweight.json', orient="records", lines=True)




#%%


# TEST

import pandas as pd
import os
import json
import numpy as np

folder = '/Users/cyrilvallez/Desktop/Thesis/Data/Twitter/COP26/'
filenames = [folder + file for file in os.listdir(folder) if not file.startswith('.')]


#%%

tweets = []
with open(filenames[1], 'r') as file:

    for i, line in enumerate(file):

        if i < 2:
            continue
        
        if i > 20:
            break
        
        tweet = json.loads(line)
        tweets.append(tweet)
        
df = pd.DataFrame.from_records(tweets)
#%%

def effective_category_quick(tweet: dict) -> str:
    """
    Check if a given tweet should be classified as a retweet or usual tweet.
    Quote tweets are considered retweets, and replies are considered tweets.
    Return the original tweet author if this is a retweet, or NaN for tweets.

    Parameters
    ----------
    tweet : dict
        The tweet object.

    Returns
    -------
    str
        Username of original author.

    """
    
    # Sometimes tweets are mislabeled by Twitter (or users are using functionalities incorrectly)
    # thus we first check by RT @username for all possible tweets categories
    if tweet['text'].startswith('RT @'):
        content = tweet['text'].split('RT @')[1]
        name = content.split(' ')[0]
        if ':' in name:
            return name.split(':')[0]
        else:
            return name
        
        
    # Replies and other tweets are considered as tweets
    else:
        return float('nan')


for i, file in enumerate(filenames):
    
    print(i)
    df = pd.read_json(file, lines=True, convert_dates=False, dtype=object)
    df["foo"] = df.apply(effective_category_quick, axis=1)
    df['effective_category'] = df["foo"].apply(lambda x: 'tweet' if pd.isnull(x) else 'retweet')
    
    
#%%
import pandas as pd

news = pd.read_csv('/Users/cyrilvallez/Desktop/Thesis/Data/NewsGuard-metadata-2022090100.csv')





