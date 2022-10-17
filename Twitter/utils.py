#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct 13 09:39:26 2022

@author: cyrilvallez
"""

import os
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
    with open(path, 'r') as stream:
        credentials = yaml.safe_load(stream)
    
    return credentials



def load_query(query_path):
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



def format_filename(filename, folder='../Data/Twitter/', extension='.json'):
    """
    Format the original filename to meet the format.

    Parameters
    ----------
    filename : str
        The filename for saving the file.
    folder : str, optional
        Where to store the tweets. The default is '../Data/Twitter/'.
    extension : str, optional
        The extension for saving the tweets. The default is '.txt'.

    Raises
    ------
    ValueError
        If the filename is not valid or already taken.

    Returns
    -------
    filename : str
        The final formatted path.

    """
    
    if '/' in filename:
        raise ValueError('The filename name must not be a path. Please provide a name without any \'/\'.')
    
    filename = folder + filename + extension
    if os.path.exists(filename):
        raise ValueError('A filename already exists with this name. Choose another one.')
    
    return filename

