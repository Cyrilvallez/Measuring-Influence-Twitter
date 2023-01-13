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
df.rename(columns={"Date": "created_at", "Author": "username", "Title": "original_text", "Twitter Followers": "follower_count", "Expanded URLs": "urls"}, inplace=True)

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

# Drop non-lightweight columns
df.drop(labels=["original_text", "urls"], axis="columns", inplace=True)

# Export to json
df.to_json('~/Desktop/Thesis/Data/BrandWatch/Skripal/skripal_clean_lightweight.json', orient="records", lines=True)


