# Ubuntu Base Image
FROM ubuntu:18.04

# Set the front-end to noninteractive for any installations in case we missed one
# this variable needs to change but with the amount of PyQt packages I'm keeping this
# line here and will come back to make sure yes is installed in each command.
ENV DEBIAN_FRONTEND=noninteractive

# We need apt-get, sudo (for users, and also wget to retrieve conda.
RUN apt-get update
RUN apt-get install -y sudo
RUN apt-get install -y wget && rm -rf /var/lib/apt/lists/*

# We add the user qtuser and add it to the audio group G. This is the user
# that will be placed for PyQT. Add that user to the sudoers list.
RUN adduser --quiet --disabled-password qtuser && usermod -a -G audio qtuser
RUN echo "qtuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/qtuser \
        && chmod 0440 /etc/sudoers.d/qtuser

# Now we switch to the user.
USER qtuser

# Translation from the opengl to x11
ENV LIBGL_ALWAYS_INDIRECT=1

# Set the work directory of the qtuser
WORKDIR /home/qtuser

# Fetch Conda
RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && mkdir /home/qtuser/.conda \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh 

# Set the conda path to the user
ENV PATH="/home/qtuser/miniconda3/bin:$PATH"

# Check Version
RUN conda --version

# Activate Conda environment and install python3.7
SHELL ["/bin/bash", "-c"]
RUN conda create -n ffpenv python=3.7 

# Sequence of conda installations are important here because conda's internal
# resolver barfs and stalls the installation. They found if they install in
# this precise sequence it installs. This is bad practice and should be ported
# into actual requirements.
RUN conda install -n ffpenv -c psi4 psi4 --update-specs
RUN conda install -n ffpenv -c conda-forge rdkit freeglut libblas liblapack
RUN conda install -n ffpenv -c anaconda paramiko pillow
RUN conda install -n ffpenv -c omnia openmm

# Port in necessary files for ffparam
# Add the necessary software executables
COPY --chown=qtuser:qtuser software/cgenff/ cgenff/ 
COPY --chown=qtuser:qtuser software/ffparam_v1.0.0/ ffparam_v1.0.0/

# Inheritance of run
SHELL ["conda", "run", "-n", "ffpenv", "/bin/bash", "-c"]

# Pain to find this, there is a conflict dependency here on ffparam and pyopengl
# The version needs to be less than 3.1.4. It gets installed in the sequence 
# above but will be a pain to find. Again, proper requirements needs to be installed.
WORKDIR /home/qtuser/ffparam_v1.0.0
RUN python setup.py install
RUN python -m pip uninstall pyopengl --yes
RUN python -m pip install pyopengl==3.1.0

# This is unverified installation and can take some serious work to make sure this 
# is all installed correctly and whats necessary for installation. XCB is required
# for the translation pf pyqt to talk to the xquartz server running locally outside
# of the container. Mountain of installations.
RUN sudo apt-get update
RUN sudo apt install -y python3-opengl
RUN sudo apt-get install -y libglib2.0-0
RUN sudo apt install -y libgssapi-krb5-2
RUN sudo apt-get update && sudo apt-get install -y apt-transport-https
RUN sudo apt-get update
RUN sudo apt-get --reinstall install -y libqt5dbus5 \
libqt5widgets5 libqt5network5 libqt5gui5 libqt5core5a \
libdouble-conversion1 libxcb-xinerama0
RUN sudo apt-get install -y libxcb-render-util0 libxcb-image0 libxcb-keysyms1 libxcb-icccm4

# RUN sudo apt-get install -y libqt5x11extras5

# Install this after previous installations for now
RUN sudo apt-get install -y libxcb-xinerama0
ENV QT_DEBUG_PLUGINS=1

# ENV QT_QPA_PLATFORM=minimal
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

