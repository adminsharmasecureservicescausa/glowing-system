FROM python:3.10

RUN pip install chocolate_app

RUN apt-get update && apt-get install -y yasm pkg-config gcc make diffutils git unrar-free

RUN mkdir -p /usr/local/include/AMF
RUN git clone https://github.com/GPUOpen-LibrariesAndSDKs/AMF.git amf
RUN cp -r amf/public/include/* /usr/local/include/AMF

RUN git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg

RUN cd ffmpeg
RUN ./configure --enable-amf

RUN make -j

EXPOSE 8888

RUN echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc

CMD ["chocolate_app"]
