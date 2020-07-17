# How to pull and run this image
# > docker pull jreades/gsa:1.0
# > docker run --rm -ti -p 8888:8888 -v ${PWD}:/home/jovyan/work jreades/gsa:1.0
#
# How to build
# > docker build -t jreades/gsa:2020 --compress .
# How to push an updated image
# > docker tag jreades/gsa:2020 jreades/gsa:latest
# > docker login docker.io
# > docker push jreades/gsa:2020 jreades/gsa:latest
#
#--- Build from Jupyter-provided Minimal Install ---#
# https://github.com/jupyter/docker-stacks/blob/master/docs/using/selecting.md
FROM jupyter/minimal-notebook:ea01ec4d9f57

LABEL maintainer="jonathan.reades@kcl.ac.uk"

ENV yaml_nm environment
ENV env_nm notebooks
ENV kernel_nm GSA2020

# https://github.com/ContinuumIO/docker-images/blob/master/miniconda3/Dockerfile
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

#--- Python ---#
RUN echo "Building $kernel_nm"

# Get conda updated and set up before installing
# any packages
RUN conda update -n base conda --yes \
    && conda config --add channels conda-forge \
    && conda config --set channel_priority strict

# Now install the packages then tidy up 
COPY ${yaml_nm}.yml /tmp/
#RUN conda activate ${env_nm} \ 
RUN conda env update -n ${env_nm} -f /tmp/${yaml_nm}.yml \ 
    && conda clean --all --yes --force-pkgs-dirs \
    && find /opt/conda/ -follow -type f -name '*.a' -delete \
    && find /opt/conda/ -follow -type f -name '*.pyc' -delete \
    && find /opt/conda/ -follow -type f -name '*.js.map' -delete \
    && conda list

# Set paths for conda and PROJ
ENV PATH /opt/conda/envs/${env_nm}/bin:$PATH
ENV PROJ_LIB /opt/conda/envs/${env_nm}/share/proj/
# And configure the bash shell params 
COPY init.sh /tmp/
RUN cat /tmp/init.sh > ~/.bashrc 
RUN echo "export PROJ_LIB=/opt/conda/envs/${env_nm}/share/proj/" >> ~/.bashrc

# Install jupyterlab extensions, but don't build
# (saves some time over install and building each)
RUN jupyter lab clean \
# These should work, but can be commented out for speed during dev
    && jupyter labextension install --no-build @jupyter-widgets/jupyterlab-manager \
    && jupyter labextension install --no-build jupyter-matplotlib \ 
    && jupyter labextension install --no-build @jupyterlab/mathjax3-extension \ 
    && jupyter labextension install --no-build jupyterlab-plotly \ 
    && jupyter labextension install --no-build @jupyterlab/geojson-extension \ 
    && jupyter labextension install --no-build @krassowski/jupyterlab_go_to_definition \
    && jupyter labextension install --no-build @ryantam626/jupyterlab_code_formatter \ 
    && jupyter labextension install --no-build @bokeh/jupyter_bokeh \ 
    && jupyter labextension install --no-build @pyviz/jupyterlab_pyviz \ 
    && jupyter labextension install --no-build jupyter-leaflet \
    && jupyter labextension install --no-build nbdime-jupyterlab \
    && jupyter labextension install --no-build @jupyterlab/toc \
    && jupyter labextension install --no-build ipysheet \ 
    && jupyter labextension install --no-build @lckr/jupyterlab_variableinspector \ 
    #&& jupyter labextension install --no-build @rmotr/jupyterlab-solutions \
    && jupyter labextension install --no-build qgrid  
# Don't work currently
#    && jupyter labextension install --no-build @krassowski/jupyterlab-lsp
#    && jupyter labextension install --no-build pylantern \ 
#    && jupyter labextension install --no-build @oriolmirosa/jupyterlab_materialdarker \ 
#    && jupyter labextension install --no-build @jpmorganchase/perspective-jupyterlab \ 

# Build the jupyterlab extensions
RUN jupyter lab build \
    && jupyter labextension enable jupyterlab-manager \ 
    && jupyter labextension enable jupyter-matplotlib \
    && jupyter labextension enable mathjax3-extension \ 
    && jupyter labextension enable jupyterlab-plotly \ 
    && jupyter labextension enable geojson-extension \ 
    && jupyter labextension enable jupyterlab_go_to_definition \
    && jupyter labextension enable jupyterlab_code_formatter \
    && jupyter labextension enable jupyter_bokeh \
    && jupyter labextension enable jupyterlab_pyviz \
    && jupyter labextension enable jupyter-leaflet \ 
    && jupyter labextension enable nbdime-jupyterlab \
    && jupyter labextension enable toc \ 
    && jupyter labextension enable ipysheet \ 
    && jupyter labextension enable jupyterlab_variableinspector \ 
    #&& jupyter labextension enable jupyterlab_rmotr_solutions \
    && jupyter labextension enable qgrid 

#--- JupyterLab config ---#
# Need to add these if rmotr/solutions ever works:
# c.JupyterLabRmotrSolutions.is_enabled = True # True, False
# c.JupyterLabRmotrSolutions.role = 'teacher' # 'teacher', 'student'
SHELL ["/bin/bash", "-c"]
RUN echo $'\n\
    c.NotebookApp.default_url = \'/lab\' \n\
    c.JupyterLabRmotrSolutions.is_enabled = True \n\
    c.JupyterLabRmotrSolutions.role = \'student\'\n' >> /home/$NB_USER/.jupyter/jupyter_notebook_config.py

# Clean up
RUN npm cache clean --force \
    && rm -rf $CONDA_DIR/share/jupyter/lab/staging\
    && rm -rf /home/$NB_USER/.cache/yarn

#--- Preload the NLTK/Spacy libs ---#
RUN python -c "import nltk; nltk.download('wordnet'); nltk.download('stopwords'); nltk.download('punkt'); nltk.download('city_database')"
# This may bloat the Docker image massively
#RUN python -m spacy download en \ 
#    && python -m spacy download en_core_web_sm 

#--- Set up Kernelspec so name visible in chooser ---#
USER root
SHELL ["/bin/bash", "-c"]
RUN . /opt/conda/etc/profile.d/conda.sh \
    && python -m ipykernel install --display-name ${kernel_nm} \
    && ln -s /opt/conda/bin/jupyter /usr/local/bin

#--- htop ---#
RUN apt-get update \
    && apt-get install -y --no-install-recommends software-properties-common htop

# Switch back to user to avoid accidental container runs as root
USER $NB_UID

RUN echo "Build complete."
