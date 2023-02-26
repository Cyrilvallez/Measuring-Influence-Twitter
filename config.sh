# Make sure we have the command we need
sudo apt install unzip
sudo apt install tar
sudo apt install wget



# Download and install miniconda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
bash ~/miniconda.sh -b -p ~/miniconda3
source ~/miniconda3/bin/activate
conda init

# Update current base environment to meet requirements
conda env update --name base --file python_requirements.yaml
# conda env create -f python_env.yaml


# Download and install Julia 1.8.1
wget https://julialang-s3.julialang.org/bin/linux/x64/1.8/julia-1.8.1-linux-x86_64.tar.gz -O ~/julia.tar.gz
tar -zxf ~/julia.tar.gz -C ~/

# Setup environment variable and install requirements
echo '# Julia environment variable' >> ~/.bashrc
echo 'export PATH="$PATH:/$HOME/julia-1.8.1/bin"' >> ~/.bashrc
source ~/.bashrc
julia julia_requirements.jl


# Delete installers
rm ~/miniconda.sh
rm ~/julia.tar.gz

# Install github credential cache system and create folders
conda install gh --channel conda-forge -y
mkdir Data
mkdir Data/Twitter
