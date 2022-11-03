#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Oct 26 09:32:25 2022

@author: cyrilvallez
"""

import pandas as pd
import json
import urlexpander
import tldextract
import os
import argparse
from nltk.sentiment.vader import SentimentIntensityAnalyzer

ANALYZER = SentimentIntensityAnalyzer()

# =============================================================================
# Parsing and processing of twitter attributes
# =============================================================================

def get_username(tweet: dict) -> str:
    """
    Return the username of the author of the tweet.

    Parameters
    ----------
    tweet : dict
        A tweet as returned by the twitter API.

    Returns
    -------
    str
        The username of the author.

    """
    
    return tweet['author']['username']


def get_followers_count(tweet: dict) -> int:
    """
    Return the number of followers of the author of the tweet.

    Parameters
    ----------
    tweet : dict
        A tweet as returned by the twitter API.

    Returns
    -------
    int
        The number of followers of the author.

    """
    
    return tweet['author']['public_metrics']['followers_count']


def get_tweet_count(tweet: dict) -> int:
    """
    Return the number of tweets posted by the author of the tweet.

    Parameters
    ----------
    tweet : dict
        A tweet as returned by the twitter API.

    Returns
    -------
    int
        The number of tweet posted by the author.

    """
    
    return tweet['author']['public_metrics']['tweet_count']


def get_country(tweet: dict) -> str:
    """
    Return the country location associated with a tweet.

    Parameters
    ----------
    tweet : dict
        A tweet as returned by the twitter API.

    Returns
    -------
    str
        The country.

    """
    
    return tweet['geo']['country'] if 'geo' in tweet.keys() else float('nan')


def get_country_code(tweet: dict) -> str:
    """
    Return the country location code associated with a tweet.

    Parameters
    ----------
    tweet : dict
        A tweet as returned by the twitter API.

    Returns
    -------
    str
        The 2 letter country code.

    """
    
    return tweet['geo']['country_code'] if 'geo' in tweet.keys() else float('nan') 


def get_tweet_category(tweet: dict) -> list[str]:
    """
    Return the category/categories of a tweet. For example, is it a tweet,
    retweet, replied,...

    Parameters
    ----------
    tweet : dict
        A tweet as returned by the twitter API.

    Returns
    -------
    list[str]
        A list containing all categories of the tweet.

    """
    
    if 'referenced_tweets' in tweet.keys():
        return [dic['type'] for dic in tweet['referenced_tweets']] 
    else:
        return ['tweeted']
    
        
def get_original_text(tweet: dict, category: list[str]) -> str:
    """
    Returns the original text of a tweet. This is useful since retweets are
    automatically truncated after 140 characters by the Twitter API. For retweets,
    this won't have the `RT @user` mention at the beginning.

    Parameters
    ----------
    tweet : dict
        A tweet as returned by the twitter API.
    category : list[str]
        A list containing all categories of the tweet, as returned by 
        `get_tweet_category(tweet)`.

    Returns
    -------
    str
        The original tweet text.

    """
    
    return tweet['referenced_tweets'][0]['text'] if category == ['retweeted'] else tweet['text']

    
def get_sentiment(original_text: str) -> str:
    """
    Returns the sentiment of the text of a tweet. This is a baseline using
    the naive VADER sentiment analysis tool.

    Parameters
    ----------
    original_text : str
        The original tweet text, as returned by `get_original_text(tweet)`.

    Returns
    -------
    str
        The sentiment of the text.

    """
    
    compound = ANALYZER.polarity_scores(original_text)['compound']
    if compound > 0.05:
        return 'positive'
    elif compound < -0.05:
        return 'negative'
    else:
        return 'neutral'
    
    
def get_urls(tweet: dict, category: list[str], try_expand: bool = True) -> list[str]:
    """
    Extract all URLs appearing in a tweet.

    Parameters
    ----------
    tweet : dict
        A tweet as returned by the twitter API.
    category : list[str]
        A list containing all categories of the tweet, as returned by 
        `get_tweet_category(tweet)`.
    try_expand : bool, optional
        Whether to try to manually expand URLs that Twitter did not expand.
        This is a huge time bottleneck but allows to get more valid tweet to work
        with. The default is True.

    Returns
    -------
    urls : list[str]
        All the urls associated with a tweet.

    """
    
    urls = []
    # If it is a retweet, the entities are given in the parent tweet elements most
    # of the time because the text is truncated after 140 characters
    if category == ['retweeted']:
        # get urls from the parent 
        if 'entities' in tweet['referenced_tweets'][0].keys():
            if 'urls' in tweet['referenced_tweets'][0]['entities'].keys():
                for dic in tweet['referenced_tweets'][0]['entities']['urls']:
                    if 'unwound_url' in dic.keys():
                        urls.append(dic['unwound_url'])
                    else:
                        urls.append(dic['expanded_url'])           
        
    else:
        # get urls 
        if 'entities' in tweet.keys():
            if 'urls' in tweet['entities'].keys():
                for dic in tweet['entities']['urls']:
                    if 'unwound_url' in dic.keys():
                        urls.append(dic['unwound_url'])
                    else:
                        urls.append(dic['expanded_url'])
                
    if try_expand:
        for i, url in enumerate(urls):
            if urlexpander.is_short(url) or 'act.gp' in url:
                try:
                    urls[i] = urlexpander.expand(url)
                except:
                    # In this case we do nothing
                    pass
                
    if len(urls) == 0:
        urls = float('nan')
                
    return urls


def get_hashtags(tweet: dict, category: list[str]) -> list[str]:
    """
    Extract all hashtags appearing in a tweet.

    Parameters
    ----------
    tweet : dict
        A tweet as returned by the twitter API.
    category : list[str]
        A list containing all categories of the tweet, as returned by 
        `get_tweet_category(tweet)`.

    Returns
    -------
    hashtags : list[str]
        All the hashtags associated with a tweet.

    """
    
    # Default if there are no hashtags
    hashtags = float('nan')
    
    if category == ['retweeted']:
        # get hashtag from the parent if there are any
        if 'entities' in tweet['referenced_tweets'][0].keys():
            if 'hashtags' in tweet['referenced_tweets'][0]['entities'].keys():
                hashtags = [dic['tag'] for dic in tweet['referenced_tweets'][0]['entities']['hashtags']] 
            
    else:
        # get hashtag if there are any
        if 'entities' in tweet.keys():
            if 'hashtags' in tweet['entities'].keys():
                hashtags = [dic['tag'] for dic in tweet['entities']['hashtags']] 
    
    return hashtags


def get_domain_and_suffix(urls: list[str]) -> tuple[list[str], list[str]]:
    """
    Returns the domain and domain suffix of URLs.

    Parameters
    ----------
    urls : list[str]
        The URLs to extract data from.

    Returns
    -------
    domain : list[str]
        The domain associated with each URL.
    domain_suffix : list[str]
        The domain suffix associated with each URL.

    """

    # If it is float, this means that it's nan thus we return nan as well
    if type(urls) == float:
        return float('nan'), float('nan')
    
    parsing = [tldextract.extract(url) for url in urls]
    domain = [url.domain for url in parsing]
    domain_suffix = [url.suffix for url in parsing]
    
    return domain, domain_suffix



# =============================================================================
# Loading and processing an actual file
# =============================================================================

# Attributes we want to keep without processing them in the original tweet data
ATTRIBUTES_TO_PRESERVE = [
    'id',
    'author_id',
    'created_at',
    'lang',
    'text'
    ]


def process_tweets(filename: str, to_df: bool = True, try_expand: bool = True,
                skiprows: int = 2):
    """
    Load the tweets from file, and process them to conserve only the interesting
    attributes.
    
    Parameters
    ----------
    filename : str
        The path to the file.
    to_df : bool, optional
        Whether to convert all the tweets to a DataFrame. The default is True.
    try_expand : bool, optional
        Whether to try to manually expand URLs that Twitter did not expand.
        This is a huge time bottleneck but allows to get more valid tweet to work
        with. The default is True.
    skiprows : int, optional
        The number of lines to skip at the beginning of the file. This allows to discard
        lines containing the info on how the data was queried from Twitter. 
        The default is 2.
    
    Returns
    -------
    DataFrame or list[dict] depending on `to_df`.
        The processed tweets.
    
    """
    
    dics = []

    with open(filename, 'r') as file:
    
        for i, line in enumerate(file):

            if i < skiprows:
                continue
            
            tweet = json.loads(line)
            dic = {}
            for attribute in ATTRIBUTES_TO_PRESERVE:
                dic[attribute] = tweet[attribute]
            dic['username'] = get_username(tweet)
            dic['follower_count'] = get_followers_count(tweet)
            dic['tweet_count'] = get_tweet_count(tweet)
            dic['country'] = get_country(tweet)
            dic['country_code'] = get_country_code(tweet)
            dic['category'] = get_tweet_category(tweet)
            dic['original_text'] = get_original_text(tweet, dic['category'])
            dic['sentiment'] = get_sentiment(dic['original_text'])
            dic['urls'] = get_urls(tweet, dic['category'], try_expand)
            dic['hashtags'] = get_hashtags(tweet, dic['category'])
            domains, suffixes = get_domain_and_suffix(dic['urls'])
            dic['domain'] = domains
            dic['domain_suffix'] = suffixes
            
            dics.append(dic)
            
            
    if to_df:
        return pd.DataFrame.from_records(dics)
    else:
        return dics

    

def process_and_save_tweets(filename: str, try_expand: bool = True,
                         skiprows: int = 2) -> None:
    
    """
    Load the tweets from file, process them to conserve only the interesting
    attributes, and save those processed tweets as json.

    Parameters
    ----------
    filename : str
        The path to the file.
    try_expand : bool, optional
        Whether to try to manually expand URLs that Twitter did not expand.
        This is a huge time bottleneck but allows to get more valid tweet to work
        with. The default is True.
    skiprows : int, optional
        The number of lines to skip at the beginning of the file. This allows to discard
        lines containing the info on how the data was queried from Twitter. 
        The default is 2.

    Returns
    -------
    None

    """
    
    # Removes current extension and add `_processed.json` instead
    new_filename = filename.rsplit('.', 1)[0] + '_processed.json'
    if os.path.exists(new_filename):
        raise ValueError(('It seems like this file was already processed. This '
                          'would overwrite it.'))

    # process the tweets and create a dataframe to easily save them back
    df = process_tweets(filename, to_df=True, try_expand=try_expand,
                     skiprows=skiprows)
    df.to_json(new_filename, orient="records", lines=True)



    

if __name__ == '__main__':
    
    parser = argparse.ArgumentParser(description='Process tweets')
    parser.add_argument('filename', type=str,
                        help='Path to the raw tweet file.')
    parser.add_argument('--try_expand', type=str, choices=['True', 'False'], default='True',
                        help='Whether to try to manually expand URLs that Twitter did not expand.')
    parser.add_argument('--skiprows', type=int, default=2,
                        help='The number of lines to skip at the beginning of the file.')
    args = parser.parse_args()
    
    filename = args.filename
    try_expand = True if args.try_expand == 'True' else False
    skiprows = args.skiprows
    
    process_and_save_tweets(filename, try_expand, skiprows)
    
    