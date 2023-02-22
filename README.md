# Describing information influence in social media with coupling inference methods

This repository contains all the code used during my Master thesis. It is organized as follow:

# Setting up the environment

In this project, we used Python for data acquisition and processing, and Julia for all later computations. \
To install both Python and Julia as well as all required packages, in their correct version, the easiest way is to dowload this repository, navigate to it, and run:

```
cd path/to/the/repo
source config.sh
```

Note that you need to `source` this file, not just run it (otherwise installation will fail). Note that this method has only been tested on Linux. It is likely to work on Mac OS as well, but won't work on Windows.

It will download Julia 1.8.1 and Miniconda3 in the user directory, and add them to the path. It will also automatically install all dependencies and packages for both Julia and Python (for Python, all packages will be downloaded in the `base` conda environment).


If you cannot use this config file because of your OS, or you want more control over where to download the packages, you may download Julia 1.8.1 from the [official website](https://julialang.org/downloads/oldreleases/) and install it manually. In the same way, download Miniconda3 (version does not really matter here for conda) from [here](https://docs.conda.io/en/latest/miniconda.html) and install it.

To install all required packages, you then need to run both:

```
# For Python packages (you may choose to change env)
conda env update --name base --file python_requirements.yaml 
```

and 

```
# For Julia packages
julia julia_requirements.jl
```

Note that if you don't intend to download data from Twitter or modify (preprocess in a different way) the existing data, you may only download Julia and its dependencies.


# Usage

We now describe our code and how to use it.

## Twitter

This repository contains Python code to download data from the Twitter API (v2) and preprocess it according to our needs.
