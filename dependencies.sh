#!/bin/bash
# Installs all dependencies for SVT

# Install system packages
echo "Installing system dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install gedit -y
sudo apt install libglfw3-dev libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libxext-dev libxfixes-dev libgl1-mesa-dev libglu1-mesa-dev libsoil-dev
sudo apt install mesa-utils -y
sudo apt install freeglut3-dev -y
sudo apt install libglfw3-dev -y
sudo apt install nvidia-cuda-toolkit -y
sudo apt install build-essential -y
sudo apt install ffmpeg -y


echo "Dependencies installation completed!"
