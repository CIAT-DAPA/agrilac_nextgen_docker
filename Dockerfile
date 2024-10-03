# Usa una imagen base de conda
FROM continuumio/miniconda3:latest

# Establece el directorio de trabajo
WORKDIR /home

# Crea los directorios input y output
RUN mkdir -p /home/input /home/output

# Crea los volúmenes para inputs y outputs
VOLUME ["/home/input", "/home/output"]

# Actualiza apt, instala curl, wget y cron, y limpia cache
RUN apt-get update && apt-get install -y curl wget cron tzdata vim && apt-get clean

# Establece la zona horaria a Honduras
RUN ln -sf /usr/share/zoneinfo/America/Tegucigalpa /etc/localtime && \
    echo "America/Tegucigalpa" > /etc/timezone

# Actualiza conda y limpia cache
RUN conda update -n base -c defaults conda && conda clean --all -y

# Crea un nuevo entorno conda
RUN conda create -n xcast_env python=3.9.19 -y && conda clean --all -y

# Instala los paquetes necesarios en el nuevo entorno
RUN /bin/bash -c "source activate xcast_env && \
    conda install -n xcast_env -c conda-forge -c hallkjc01 \
    proj xcast xarray netcdf4 matplotlib cartopy cfgrib \
    jupyter ipykernel -y && \
    conda clean --all -y"

# Descarga el último release del repositorio de GitHub
RUN wget $(curl -s https://api.github.com/repos/CIAT-DAPA/agrilac_nextgen_packages/releases/latest | grep "tarball_url" | cut -d '"' -f 4) -O latest_release.tar.gz

# Extrae el contenido del release
RUN mkdir agrilac_nextgen_packages && tar -xzf latest_release.tar.gz -C agrilac_nextgen_packages --strip-components=1

# Instala los requisitos del código
RUN /bin/bash -c "source /opt/conda/etc/profile.d/conda.sh && \
    conda activate xcast_env && \
    pip install -r /home/agrilac_nextgen_packages/requirements.txt"

# Crea un archivo .cdsapirc en la ruta $HOME/.cdsapirc
RUN echo '#!/bin/bash\n' \
         'if [ -z "$CDSAPI_URL" ] || [ -z "$CDSAPI_KEY" ]; then\n' \
         '  echo "Error: Las variables CDSAPI_URL y CDSAPI_KEY no están establecidas."\n' \
         '  exit 1\n' \
         'fi\n' \
         'echo "url: $CDSAPI_URL" > $HOME/.cdsapirc\n' \
         'echo "key: $CDSAPI_KEY" >> $HOME/.cdsapirc' \
         > /home/create_cdsapirc.sh

# Dar permisos de ejecución al script
RUN chmod +x /home/create_cdsapirc.sh

# Crear el script que ejecutará Python y guardará el log
RUN echo '#!/bin/bash\n' \
         'source /opt/conda/etc/profile.d/conda.sh\n' \
         'conda activate xcast_env\n' \
         'mkdir -p /home/output/logs\n' \
         'log_file="/home/output/logs/$(date +'%Y-%m-%d_%H-%M-%S').log"\n' \
         'python /home/agrilac_nextgen_packages/src/main.py -i /home/input -o /home/output >> "$log_file" 2>&1' \
         > /home/run_with_logging.sh

# Da permisos de ejecución al nuevo script
RUN chmod +x /home/run_with_logging.sh

# Añadir el cron job que se ejecuta el día 15 de cada mes a las 8:00 AM en la zona horaria de Honduras
RUN echo "0 8 15 * * /home/run_with_logging.sh" > /etc/cron.d/mycron

# Da permisos correctos al archivo cron
RUN chmod 0644 /etc/cron.d/mycron

# Apuntar al cron de forma correcta
RUN crontab /etc/cron.d/mycron

# Asegúrate de que el servicio cron esté activo
RUN touch /var/log/cron.log

# Comando para ejecutar cron en segundo plano y mantener el contenedor vivo
CMD /home/create_cdsapirc.sh && cron && tail -f /var/log/cron.log
