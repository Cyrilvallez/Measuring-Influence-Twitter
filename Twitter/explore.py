#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct 13 10:46:34 2022

@author: cyrilvallez
"""

import numpy as np
import pandas as pd
import urlexpander
import tldextract
from nltk.sentiment.vader import SentimentIntensityAnalyzer

def read_json(file, skiprows=1):
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

filename = '/Users/cyrilvallez/Desktop/Thesis_repo/Data/Twitter/cop26_whole_period.json'
# filename = '/Users/cyrilvallez/Desktop/Thesis_repo/Data/Twitter/test_richmond_4.json'

df = read_json(filename, skiprows=1)
# df = read_json('/Users/cyrilvallez/Desktop/Thesis_repo/Data/Twitter/test_richmond.json')

# Checks that author_id correspond correctly
assert ((df['author_id'] == df['author'].apply(lambda x: x['id'])).all())

    
usernames = []
hashtags = []
categories = []
original_texts = []
URLs = []
domains = []
domain_suffixes = []
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
        ('referenced_tweets' in x._fields and type(x.referenced_tweets) == list) else ['tweeted']
        
    original_text = x.referenced_tweets[0]['text'] if category == ['retweeted'] else x.text
    
    compound = analyzer.polarity_scores(original_text)['compound']
    if compound > 0.05:
        sentiment = 'positive'
    elif compound < -0.05:
        sentiment = 'negative'
    else:
        sentiment = 'neutral'
    
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
    
    # This is a bottleneck but allows to expand some urls that would otherwise
    # not be workable with
    for i, url in enumerate(urls):
        if urlexpander.is_short(url) or 'act.gp' in url:
            urls[i] = urlexpander.expand(url)
            
    parsing = [tldextract.extract(url) for url in urls]
    domain = [url.domain for url in parsing]
    domain_suffix = [url.suffix for url in parsing]
                
    usernames.append(username)
    hashtags.append(hashtag)
    categories.append(category)
    original_texts.append(original_text)
    URLs.append(urls)
    domains.append(domain)
    domain_suffixes.append(domain_suffix)
    countries.append(country)
    country_codes.append(country_code)
    sentiments.append(sentiment)

df['username'] = usernames
df['hashtags'] = hashtags
df['category'] = categories
df['original_text'] = original_texts
df['URLs'] = URLs
df['domain'] = domains
df['domain_suffix'] = domain_suffixes
df['country'] = countries
df['country_code'] = country_codes
df['sentiment'] = sentiments
    
post_process_cols = ['id', 'author_id', 'username', 'created_at', 'lang', 'text',
                     'original_text', 'hashtags', 'category', 'URLs', 'domain',
                     'domain_suffix', 'country', 'country_code', 'sentiment']

export = False

if export:
    df[post_process_cols].to_csv(filename.rsplit('.', 1)[0] + '.csv', index=False)
    

#%%

unique, counts = np.unique(df['sentiment'], return_counts=True)

#%%

def classify(domain_list):
    for domain in domain_list:
        if domain == "cnn":
            return "cnn"
        elif domain == "foxnews":
            return "foxnews"
        elif domain == "greenpeace":
            return "greenpeace"
        elif domain == "richmondstandard":
            return "richmondstandard"
        else:
            return "0"
    


#%%

df['real_domain'] = df['domain'].apply(classify)
df = df[df['real_domain'] != "0"]
unique, counts = np.unique(df['real_domain'], return_counts=True)
print(unique)
print(counts)

#%%

avg = df['original_text'].apply(lambda x: len(x.split(' '))).quantile(q=0.75)
print(avg)

#%%

for i in range(len(df)):
    text = df['original_text'][i]
    print(f'{i} \n{text} \n \n')

#%%

from transformers import pipeline

classifier = pipeline("sentiment-analysis")

#%%

t0 = time.time()
i = 5
print(df['original_text'][i])
print('\n')
print(classifier(df['original_text'][i]))

#%%

t0 = time.time()
for i in range(10):
    a = classifier(df['original_text'][i])
print(f'{time.time() - t0} s')

#%%


test = df['original_text'].apply(lambda x: classifier(x)[0]['label'])

#%%

unique, count = np.unique(df['username'].apply(lambda x: x[0]), return_counts=True)





