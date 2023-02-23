# Describing information influence in social media with coupling inference methods

This repository contains all the code used for our work on influence on Twitter. We develop a new method to measure influence between users on Twitter in the context of disinformation campaigns. We investigate different subjects and events, such as climate change during the COP26 and COP27, and foreign influence after the Skripal poisoning in the UK in 2018. The final report is available [here](Master_Thesis_final.pdf).

# Setting up the environment

In this project, we used Python for data acquisition and processing, and Julia for all computations. \
To install both Python and Julia as well as all required packages, in their correct version, the easiest way is to dowload this repository, navigate to it, and run:

```sh
cd path/to/the/repo
source config.sh
```

You need to `source` the file, not just run it (otherwise installation will fail). Note that this method has only been tested on Linux. It is likely to work on Mac OS as well, but won't work on Windows.

It will download Julia 1.8.1 and Miniconda3 in the user directory, and add them to the path. It will also automatically install all required packages for both Julia and Python (for Python, they will be downloaded in the `base` conda environment).


If you cannot use this config file because of your OS, or you want more control over where to download the packages, you may download Julia 1.8.1 from the [official website](https://julialang.org/downloads/oldreleases/) and install it manually. In the same way, download Miniconda3 (version does not really matter) from [here](https://docs.conda.io/en/latest/miniconda.html) and install it.

Then, to install all required packages you need to run both:

```sh
# For Python packages (you may choose to change env)
conda env update --name base --file python_requirements.yaml 

# For Julia packages
julia julia_requirements.jl
```

Note that if you don't intend to download data from Twitter or modify (preprocess in a different way) the existing data, you may only download Julia and its dependencies (you will not need to use Python).


# Julia folder

This folder contains all the Julia code we used for analysis and computations.

## Code organization

The folder is organized as follows:

- **PreProcessing**: This module contains all the necessary methods and objects to preprocess the tweets, i.e. to define partitions (stratification of the dataset), actions, and actors.
- **Sensors**: Module containing all the heavy computation pipelines, i.e. time series creation, influence graphs computation, and finally influence cascades derivations.
- **Utils**: Contains three different utility modules with explicit names: *Helpers*, *Visualizations* and *Metrics*.
- **Engine**: This is the user interface. This high-level module defines functions to run experiments making use of all other modules. It also includes and re-export all other modules, so that including it is sufficient to include all the project code. 

There are also two other folders:

- **Runs**: This folder contains scripts to run the experiments we made. 
- **Notebooks**: Contains Pluto and Jupyter notebooks for quick and easy tests and visualization of results. Also contains Jupyter notebooks for processing the results of experiments.

## Running experiments

To run an experiment, the general syntax is the following:

```julia
using Dates

# You only need to include the Engine module
include("../../Engine/Engine.jl")
using .Engine

# Define the dataset you want to use
dataset = COP27

# Define partitions, actions and actors
partitions = cop_27_dates
actions = trust_score
actors = all_users(by_partition=true, min_tweets=3)

# Create the preprocessing pipeline object
agents = PreProcessingAgents(partitions, actions, actors)

# Create the experiment name (i.e. the name to save the results)
name = "JDD_all_users/COP27"

# Initialize time series, influence graphs and influence cascades generators 
tsg = TimeSeriesGenerator(Minute(120), standardize=true)
igg = InfluenceGraphGenerator(JointDistanceDistribution, Nsurro=100, threshold=0.001) 
icg = InfluenceCascadeGenerator(WithoutCuttoff)

# Create the computation pipeline object
pipeline = Pipeline(tsg, igg, icg)

# Run the experiment, save the results and log the parameters used
run_experiment(dataset, agents, pipeline, save=true, experiment_name=name)
```

Because it would be too long to describe how every part work, the reader is referred to the `Methodology` Section of our [report](Master_Thesis_final.pdf). To get details about the arguments of an object or function, one may look at the docstrings for the corresponding object or function. To check available datasets, you can use `subtypes(Dataset)`. For a list of all possible `partitions`, `actions`, and `actors` choices, it is possible to access the corresponding variables `PreProcessing.partition_options`, `PreProcessing.action_options`, and `PreProcessing.actor_options`. Finally, for a list of the `Generators` methods and arguments, you can look at the docstrings as previously mentioned.  

The results of the experiment will be written into `path/to/repo/Results/name`. It will contain 2 files, `data.jld2` containing the results, and `experiment.yml` summarizing all variables and parameters used to generate the experiment. 

## Loading back data from experiments

To load results from an experiment, you can use the following syntax:

```julia
graphs, cascades, df = load_data(RESULT_FOLDER * "/experiment_name/data.jld2")
```

which will return the influence graphs, cascades, and the dataframe used to derive them respectively.


# Twitter folder

This folder contains Python code to download data from the Twitter API (v2) and preprocess it according to our needs. 

## Download data

To download data, use `request.py`:

```sh
cd Twitter
python3 request.py dataset path/to/query.txt start_time end_time
```

This will download all tweets matching your `path/to/query.txt` between `start_date` and `end_date` (YYYY-MM-DD:HH-MM-SS or parts of it, e.g. YYYY-MM-DD), and save them in `path/to/repo//Data/Twitter/dataset`. If you need help for writing a query, see [this link](https://developer.twitter.com/en/docs/twitter-api/tweets/search/integrate/build-a-query).

You need to provide your Twitter credentials for it to work correctly. By default, they should be saved under `Twitter/.twitter_credentials.yaml` and contain the following line:

```yaml
Bearer token : your_token
```

## Download data from random days

Use `random_request.py` to make a query to the Twitter API (v2) and get results of this query on random days between 2020-01-01 and 2022-12-01 by default (this date are controlled by optional arguments `--left_lim` and `--right_lim` respectively).

```sh
python3 random_request.py dataset query.txt N_days
```

This will download data corresponding to the query for `N_days` days. Results will be written to `path/to/repo/Data/Twitter/dataset` (this can be changed with the `--folder_prefix` argument).

## Process the tweets

After downloading some tweets, use `process.py` to process them. The syntax is the following:

```sh
python3 process.py path/to/repo/Data/Twitter/dataset
```

It will find all interesting properties of each tweet and extract them from the raw unprocessed outputs returned by the Twitter API. By default it will same the resuts as `path/to/repo/Data/Twitter/dataset_processed`.

## Further process the tweets for our usecase

Finally, after having processed the tweets, there are still a lot of attributes that are not directly useful for our work and that take a lot of memory space if loaded in a DataFrame for example. All tweets not matching the URLs from the NewsGuard list are also not used at all in our analysis and should be removed. The script `lightweight.py` was written for this purpose. It reprocess the already processed tweets (as returned by `process.py`) in order to keep only tweets matching NewsGuard and only needed properties for each tweet.

```sh
python3 lightweight.py path/to/repo/Data/Twitter/dataset_processed
```

The result will be written to `path/to/repo/Data/Twitter/dataset_processed_lightweight`.  

# Data

To request access to the original Twitter and BrandWatch data we used, as well as the NewsGuard list of news sources, please formulate a request to [the author](mailto:cyril.vallez@orange.fr).


# Figures

The folder `Figures` contains all the figures we generated from our experiments, as well as flow charts depicting our methods. You are free to look at them if you want.  
However, note that by default generating figures with the `Visualizations` module will require a LaTeX installation on the machine running the process. If you do not have LaTeX installed on your machine, you can disable it to avoid errors. For this, you will need to comment lines 30 to 32 of `Visualizations.jl`. Alternatively, you can use:

```julia
include("../Engine/Engine.jl")
using .Engine

# Remove usage of latex to avoid errors if it is not installed
import PyPlot as plt
rcParams = plt.PyDict(plt.matplotlib."rcParams")
rcParams["text.usetex"] = false
rcParams["font.family"] = ["sans-serif"]
rcParams["font.serif"] = ["Computer Modern Roman"]
```

But note that you need to add those lines after including `Engine.jl`. 


