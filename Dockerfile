FROM ubuntu

MAINTAINER Eric Fairbanks <ericpfairbanks@gmail.com>

# Install dependencies and audio tools
RUN apt-get update

# Install jackd by itself first without extras since installing alongside other tools seems to cause problems
RUN apt-get -y install jackd

# Install pretty much everything we need here
RUN DEBIAN_FRONTEND='noninteractive' apt-get -y install build-essential supercollider xvfb git yasm supervisor libsndfile1-dev libsamplerate0-dev liblo-dev libasound2-dev wget ghc emacs-nox haskell-mode zlib1g-dev xz-utils htop screen openssh-server cabal-install curl sudo

# Install jack libs last
RUN apt-get -y install libjack-jackd2-dev

# Build Dirt synth
WORKDIR /repos
RUN git clone --recursive https://github.com/tidalcycles/Dirt.git
WORKDIR Dirt
RUN make

# Build & Install libmp3lame
WORKDIR /repos
RUN git clone https://github.com/rbrito/lame.git
WORKDIR lame
RUN ./configure --prefix=/usr
RUN make install
WORKDIR /repos
RUN rm -fr lame

# Build & Install ffmpeg, ffserver
WORKDIR /repos
RUN git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
WORKDIR ffmpeg
RUN ./configure --enable-indev=jack --enable-libjack --enable-libmp3lame --enable-nonfree --prefix=/usr
RUN make install
WORKDIR /repos
RUN rm -fr ffmpeg

# Initialize and configure sshd
RUN mkdir /var/run/sshd
RUN echo 'root:algorave' | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Expose sshd service
EXPOSE 22

# Expose ffserver streaming service
EXPOSE 8090

# Pull Tidal Emacs binding
RUN mkdir /repos/tidal
WORKDIR /repos
WORKDIR tidal
RUN wget https://raw.githubusercontent.com/tidalcycles/Tidal/master/tidal.el

ENV HOME /root
WORKDIR /root

RUN ln -s /repos /root/repos
RUN ln -s /work /root/work

# Install tidal
RUN cabal update
RUN cabal install tidal

# Install supercollider plugins
WORKDIR /usr/share/SuperCollider/Extensions
RUN git clone https://github.com/musikinformatik/SuperDirt
RUN git clone https://github.com/tidalcycles/Dirt-Samples
RUN git clone https://github.com/supercollider-quarks/Vowel


# Install default configurations
COPY configs/emacsrc /root/.emacs
COPY configs/screenrc /root/.screenrc
COPY configs/ffserver.conf /root/ffserver.conf

# Install default Tidal files
COPY tidal/init.tidal /root/init.tidal
COPY tidal/hello.tidal /root/hello.tidal

# Prepare scratch workspace for version control
RUN sudo mkdir /work
WORKDIR /work
RUN mkdir /root/.ssh
ADD https://raw.githubusercontent.com/DoubleDensity/scratchpool/master/id_rsa-scratchpool /root/.ssh/id_rsa
COPY configs/sshconfig /root/.ssh/config
RUN ssh-keyscan -H github.com >> ~/.ssh/known_hosts
RUN git clone https://github.com/DoubleDensity/scratchpool.git
WORKDIR /work/scratchpool
RUN git config user.name "SuperTidebox User"
RUN git config user.email "supertidal@jankycloud.com"

# Install Tidebox supervisord config
COPY configs/tidebox.ini /etc/supervisor/conf.d/tidebox.conf

# Copy supercollider/superdirt startup file
COPY configs/startup.scd /root/.sclang.sc
#COPY configs/startup.scd /root/.local/share/SuperCollider/startup.scd

# set root shell to screen
RUN echo "/usr/bin/screen" >> /etc/shells
RUN usermod -s /usr/bin/screen root

CMD ["/usr/bin/supervisord"]
