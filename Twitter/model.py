#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Oct 19 09:43:17 2022

@author: cyrilvallez
"""

from transformers import AutoModel, AutoTokenizer

model_name = 'distilbert-base-uncased-finetuned-sst-2-english'
model = AutoModel.from_pretrained(model_name)
tokenizer = AutoTokenizer.from_pretrained(model_name)

#%%

from transformers import pipeline

classifier = pipeline("sentiment-analysis")