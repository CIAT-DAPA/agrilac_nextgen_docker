# Usa una imagen base de conda
FROM continuumio/miniconda3:latest

# Establece el directorio de trabajo
WORKDIR /home

# Create input and output directories
RUN mkdir input && mkdir output

# Crea los volúmenes para inputs y outputs
VOLUME ["/home/input", "/home/output"]

RUN apt-get update && apt-get install -y curl && apt-get clean

# Actualiza conda y limpia cache
RUN conda update -n base -c defaults conda && \
    conda clean --all -y


# Crea un nuevo entorno conda y activa el entorno
RUN conda create -n xcast_env python=3.9.19 -y && \
    conda clean --all -y

# Instala los paquetes necesarios en el nuevo entorno
RUN /bin/bash -c "source activate xcast_env && \
    conda install -n xcast_env -c conda-forge -c hallkjc01 \
    proj xcast xarray netcdf4 matplotlib cartopy cfgrib \
    jupyter ipykernel -y && \
    conda clean --all -y"

# Descarga el último release del repositorio
RUN wget $(curl -s https://api.github.com/repos/CIAT-DAPA/agrilac_nextgen_packages/releases/latest | grep "tarball_url" | cut -d '"' -f 4) -O latest_release.tar.gz

# Extrae el contenido del release
RUN mkdir agrilac_nextgen_packages && \
    tar -xzf latest_release.tar.gz -C agrilac_nextgen_packages --strip-components 1

# Instala los requisitos del código
RUN /bin/bash -c "source /opt/conda/etc/profile.d/conda.sh && \
    conda activate xcast_env && \
    pip install -r /home/agrilac_nextgen_packages/requirements.txt"

# Establece el comando por defecto
CMD ["bash"]
