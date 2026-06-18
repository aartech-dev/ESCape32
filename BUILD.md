# Build on Apple Silicon

Wth docker instaalled and from a bash terminal

   ./docker/build.sh image   
   docker run --rm -v "$(pwd):/workspace" --user 501:20 aart/escape32-builder   bash -c "cmake -B build -D LIBOPENCM3_DIR=\$LIBOPENCM3_DIR && make -C build"  

The build directory contains the images
