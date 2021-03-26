# This image provides a Python 3.8 environment you can use to run your Python
# applications.
FROM registry.access.redhat.com/ubi8/s2i-base

LABEL maintainer="Subin Modeel <smodeel@redhat.com>"
EXPOSE 8080

# TODO(Spryor): ensure these are right, add Anaconda versions
ENV PYTHON_VERSION=3.8 \
    PATH=$HOME/.local/bin/:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    PIP_NO_CACHE_DIR=off

# RHEL7 base images automatically set these envvars to run scl_enable. RHEl8
# images, however, don't as most images don't need SCLs any more. But we want
# to run it even on RHEL8, because we set the virtualenv environment as part of
# that script
#ENV BASH_ENV=${APP_ROOT}/etc/scl_enable \
#    ENV=${APP_ROOT}/etc/scl_enable \
#    PROMPT_COMMAND=". ${APP_ROOT}/etc/scl_enable"

# Ensure we're enabling Anaconda by forcing the activation script in the shell
ENV BASH_ENV="/opt/anaconda/bin/activate ${APP_ROOT}" \
    ENV="/opt/anaconda/bin/activate ${APP_ROOT}" \
    PROMPT_COMMAND=". /opt/anaconda/bin/activate ${APP_ROOT}"

ENV SUMMARY="" \
    DESCRIPTION="" \
    USE_CUDA=0 \
    USE_CUDNN=0 \
    USE_TENSORRT=0 \
    USE_FBGEMM=0 \
    USE_MKLDNN=0 \
    USE_NNPACK=0 \
    USE_QNNPACK=0 \
    USE_XNNPACK=0 \
    USE_PYTORCH_QNNPACK=0 \
    USE_LMDB=1 \
    USE_LEVELDB=1 \
    USE_OPENMP=1 \
    USE_NINJA=0 \
    USE_MPI=0 \
    DEE_ENABLED=1


LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Anaconda Python 3.8" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,python,python38,python-38,anaconda-python38" \
      com.redhat.component="python-38-container" \
      name="ubi8/anaconda-38" \
      version="1" \
      usage="" \
      maintainer="Subin Modeel <smodeel@redhat.com>"

RUN INSTALL_PKGS="nss_wrapper \
        httpd httpd-devel mod_ssl mod_auth_gssapi mod_ldap \
        mod_session atlas-devel gcc-gfortran libffi-devel libtool-ltdl enchant" && \
    curl https://repo.anaconda.com/miniconda/Miniconda3-py38_4.9.2-Linux-x86_64.sh > Miniconda3-4.9.2-Linux-x86_64.sh && \
    chmod +x Miniconda3-4.9.2-Linux-x86_64.sh && \
    ./Miniconda3-4.9.2-Linux-x86_64.sh -b -p /opt/anaconda && \
    rm ./Miniconda3-4.9.2-Linux-x86_64.sh && \
    yum -y module disable python38:3.8 && \
    yum -y module enable httpd:2.4 && \
    yum -y install git-lfs unzip vim wget git tar sudo tree mlocate gdb gcc-c++ make && \
    yum -y install curl-devel gettext-devel openssl-devel zlib-devel && \
    yum -y --setopt=tsflags=nodocs install $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    # Remove redhat-logos-httpd (httpd dependency) to keep image size smaller.
    rpm -e --nodeps redhat-logos-httpd && \
    yum -y clean all --enablerepo='*'

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH.
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# - Create a Python virtual environment for use by any application to avoid
#   potential conflicts with Python packages preinstalled in the main Python
#   installation.
# - In order to drop the root user, we have to make some directories world
#   writable as OpenShift default security model is to run the container
#   under random UID.
RUN \
    /opt/anaconda/bin/conda create -y --prefix ${APP_ROOT} python=${PYTHON_VERSION} && \
    source /opt/anaconda/bin/activate ${APP_ROOT} && /opt/anaconda/condabin/conda update -n base -c defaults conda -y && \
    /opt/anaconda/condabin/conda install numpy ninja pyyaml mkl mkl-include setuptools cmake cffi typing_extensions future six requests dataclasses ca-certificates certifi -y && \
    /opt/anaconda/condabin/conda install -c conda-forge/label/cf202003 lark-parser -y && \
    chown -R 1001:0 ${APP_ROOT} && \
    fix-permissions ${APP_ROOT} -P && \
    fix-permissions /opt/anaconda -P && \
    rpm-file-permissions

USER 1001

# Set the default CMD to print the usage of the language image.
CMD $STI_SCRIPTS_PATH/usage
