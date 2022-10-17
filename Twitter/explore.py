#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct 13 10:46:34 2022

@author: cyrilvallez
"""

import numpy as np
import pandas as pd
import os
from urlexpander import expand
from nltk.sentiment.vader import SentimentIntensityAnalyzer

def read_json(file, skiprows=0):
    """
    Read a json file into a DataFrame but skipping the N first rows.

    Parameters
    ----------
    file : str
        The path to the json file.
    skiprows : int, optional
        The number of lines to skip. The default is 0.

    Returns
    -------
    df : pd.DataFrame
        The dataframe.

    """
    with open(file) as f:
        for i in range(skiprows):
            f.readlines(1)
        # It is very important to read columns such as id or author_id as strings, otherwise
        # pandas will infer that the type is int but this will cause an overflow because they are
        # too large, resulting in erroneous values
        df = pd.read_json(f, lines=True, dtype=object, convert_dates=False)
    return df

filename = '/Users/cyrilvallez/Desktop/Thesis_repo/Data/Twitter/cop26_whole_period_extended_2.json'

df = read_json(filename, skiprows=1)

# Checks that author_id correspond correctly
assert ((df['author_id'] == df['author'].apply(lambda x: x['id'])).all())

    
usernames = []
hashtags = []
categories = []
original_texts = []
URLs = []
countries = []
country_codes = []
sentiments = []

analyzer = SentimentIntensityAnalyzer()

# Creates new columns using a single row iteration instead of multiple df.apply
for x in df.itertuples():
    
    username = x.author['username']
    
    country = x.geo['country'] if pd.notnull(x.geo) else float('nan')
    
    country_code = x.geo['country_code'] if pd.notnull(x.geo) else float('nan')
        
    category = [dic['type'] for dic in x.referenced_tweets] if \
        type(x.referenced_tweets) == list else ['tweeted']
        
    original_text = x.referenced_tweets[0]['text'] if category == ['retweeted'] else x.text
    
    sentiment_scores = analyzer.polarity_scores(original_text)
    sentiment_scores = {key:sentiment_scores[key] for key in ['pos', 'neu', 'neg']}
    sentiment = max(sentiment_scores, key=sentiment_scores.get)
    
    urls = []
    # If it is a retweet, the entities are given in the parent tweet elements most
    # of the time because the text is truncated after 140 characters
    if category == ['retweeted']:
        # get hashtag from the parent if there are any
        if (pd.notnull(x.referenced_tweets[0]['entities']) and 'hashtags' in x.referenced_tweets[0]['entities'].keys()):
            hashtag = [dic['tag'] for dic in x.referenced_tweets[0]['entities']['hashtags']] 
        else:
            hashtag = float('nan')
        # get urls from the parent (we know there are some urls)
        for dic in x.referenced_tweets[0]['entities']['urls']:
            if 'unwound_url' in dic.keys():
                urls.append(dic['unwound_url'])
            else:
                urls.append(dic['expanded_url'])
    else:
        # get hashtag if there are any
        if (pd.notnull(x.entities) and 'hashtags' in x.entities.keys()):
            hashtag = [dic['tag'] for dic in x.entities['hashtags']] 
        else:
            hashtag = float('nan')
        # get urls 
        for dic in x.entities['urls']:
            if 'unwound_url' in dic.keys():
                urls.append(dic['unwound_url'])
            else:
                urls.append(dic['expanded_url'])
    
    # This is a huge bottleneck but allows to expand the urls that would otherwise
    # not be workable
    for i, url in enumerate(urls):
        if 'bit.ly' in url:
            urls[i] = expand(url)
                
    usernames.append(username)
    hashtags.append(hashtag)
    categories.append(category)
    original_texts.append(original_text)
    URLs.append(urls)
    countries.append(country)
    country_codes.append(country_code)
    sentiments.append(sentiment)

df['username'] = usernames
df['hashtags'] = hashtags
df['category'] = categories
df['original_text'] = original_texts
df['URLs'] = URLs
df['country'] = countries
df['country_code'] = country_codes
df['sentiment'] = sentiments
    
post_process_cols = ['id', 'author_id', 'username', 'created_at', 'lang', 'text',
                     'original_text', 'hashtags', 'category', 'URLs', 'country',
                     'country_code', 'sentiment']

export = False

if export:
    df[post_process_cols].to_csv(filename.rsplit('.', 1)[0] + '.csv', index=False)
    

#%%

test2 = df.apply(lambda x: [a['type'] for a in x['referenced_tweets']] if type(x['referenced_tweets']) == list else ['tweet'] , axis=1)
    
    
#%%

test = df['category'].apply(lambda x: True if x == ['quoted'] else False)
# indices = (test == True).index

unique, counts = np.unique(df['category'], return_counts=True)

#%%

unique, counts = np.unique(df['sentiment'], return_counts=True)

