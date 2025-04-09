# Use the specified base image
FROM ghcr.io/saladtechnologies/comfyui-api:comfy0.3.27-api1.8.2-torch2.6.0-cuda12.4-devel

# Set working directory
WORKDIR /opt/ComfyUI

# Install git and other necessary tools
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    python3-pip \
    # Add these packages for OpenCV/OpenGL support
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Create directories for custom models if they don't exist
RUN mkdir -p /opt/ComfyUI/models/checkpoints \
    /opt/ComfyUI/models/clip \
    /opt/ComfyUI/models/clip_vision \
    /opt/ComfyUI/models/configs \
    /opt/ComfyUI/models/controlnet \
    /opt/ComfyUI/models/diffusers \
    /opt/ComfyUI/models/diffusion_models \
    /opt/ComfyUI/models/embeddings \
    /opt/ComfyUI/models/gligen \
    /opt/ComfyUI/models/hypernetworks \
    /opt/ComfyUI/models/loras \
    /opt/ComfyUI/models/photomaker \
    /opt/ComfyUI/models/style_models \
    /opt/ComfyUI/models/text_encoders \
    /opt/ComfyUI/models/unet \
    /opt/ComfyUI/models/upscale_models \
    /opt/ComfyUI/models/vae \
    /opt/ComfyUI/models/vae_approx

# Install custom nodes from GitHub
# ComfyUI Manager (node manager)
RUN cd /opt/ComfyUI/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git

RUN cd /opt/ComfyUI/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    cd ComfyUI-KJNodes && \
    pip install -r requirements.txt

RUN cd /opt/ComfyUI/custom_nodes && \
    git clone https://github.com/logtd/ComfyUI-Fluxtapoz.git && \
    cd ComfyUI-Fluxtapoz && \
    pip install -r requirements.txt

RUN cd /opt/ComfyUI/custom_nodes && \
    git clone https://github.com/city96/ComfyUI-GGUF.git && \
    cd ComfyUI-GGUF && \
    pip install -r requirements.txt

RUN cd /opt/ComfyUI/custom_nodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    cd rgthree-comfy && \
    pip install -r requirements.txt

RUN cd /opt/ComfyUI/custom_nodes && \
    git clone https://github.com/chrisgoringe/cg-use-everywhere.git

# Create directories for input and output
RUN mkdir -p /opt/ComfyUI/input && mkdir -p /opt/ComfyUI/output

# Download unet model
RUN wget -O /opt/ComfyUI/models/unet/flux1-dev-Q8_0.gguf https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q8_0.gguf

# Download the Clip models
RUN wget -O /opt/ComfyUI/models/clip/clip_l.safetensors https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors
RUN wget -O /opt/ComfyUI/models/clip/t5-v1_1-xxl-encoder-Q8_0.gguf https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q8_0.gguf

# Download the VAE model
RUN wget -O /opt/ComfyUI/models/vae/ae.safetensors https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors

# Download the Style Model
RUN wget -O /opt/ComfyUI/models/style_models/flux1-redux-dev.safetensors https://huggingface.co/second-state/FLUX.1-Redux-dev-GGUF/resolve/c7e36ea59a409eaa553b9744b53aa350099d5d51/flux1-redux-dev.safetensors

# Download the Clip Vision model
RUN wget -O /opt/ComfyUI/models/clip_vision/sigclip_vision_patch14_384.safetensors https://huggingface.co/Comfy-Org/sigclip_vision_384/resolve/main/sigclip_vision_patch14_384.safetensors

# Download the Ghibli model
RUN wget -O /opt/ComfyUI/models/loras/studiochatgpt-ghibli-v1.safetensors https://civitai.com/api/download/models/1595505?type=Model&format=SafeTensor

# Install any additional Python dependencies needed for custom nodes
RUN pip install opencv-python transformers accelerate

# Setup a workflow directory
# RUN mkdir -p /workflows
# COPY ./my-workflows/ /workflows/

# Ensure proper permissions
RUN chmod -R 755 /opt/ComfyUI/custom_nodes
RUN chmod -R 755 /opt/ComfyUI/models

# Set CMD to launch the comfyui-api binary
CMD ["./comfyui-api"]