#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct 13 10:46:34 2022

@author: cyrilvallez
"""

import numpy as np
import pandas as pd
import time

import process

#%%
# filename = '/Users/cyrilvallez/Desktop/Thesis/Data/Twitter/all_links_test.json'
# filename = '/Users/cyrilvallez/Desktop/Thesis/Data/Twitter/cop26_whole_period.json'
# filename = '/Users/cyrilvallez/Desktop/Thesis/Data/Twitter/all_links_processed.json'
filename = '/Users/cyrilvallez/Desktop/Thesis/Data/Twitter/all_links_cop26_processed.json'

t0 = time.time()
df = pd.read_json(filename, lines=True, dtype=object)
dt = time.time() - t0

df = df[pd.notnull(df['urls'])]
df['full_urls'] = df.apply(lambda x: [domain + '.' + suffix for domain, suffix in zip(x['domain'], x['domain_suffix'])], axis=1)

#%%

news = '../Data/news_table_clean.csv'
news = pd.read_csv(news)

#%%

def isin(urls, news_outlet):
    for url in urls:
        index = np.asarray(url == news_outlet['domain']).nonzero()[0]
        if not len(index) == 0:
            return news_outlet["tufm_class"][index[0]]
        
    return float('nan')

df['action'] = df["full_urls"].apply(lambda x: isin(x, news))
# remove news source not matching one of the source news table
df = df[pd.notnull(df['action'])]


#%%

def isin(a, b):
    if type(a) == float or a is None:
        return float('nan')
    for url in a:
        if url in b:
            return url
    return float('nan')



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


#%%

unique, count = np.unique(df['category'], return_counts=True)



#%%

# test2 = pd.read_csv("test.csv", quoting=csv.QUOTE_ALL)
test2 = pd.read_json("test.json", lines=True, dtype=object)

#%%

foo = df[pd.isnull(df['urls'])]


#%% 
test = pd.DataFrame({'A': [float('nan'), 2, 3]})
test.to_json('test.json', orient="records", lines=True)



        
        
        
        